-- Real PvP round resolution. Broadcast-then-locally-compute (technical.md's
-- proven pattern, confirmed against BalatroMultiplayerSpeedrun's source): each
-- client broadcasts its own score once it finishes a PvP round, collects
-- incoming results into a local table, and once it has BOTH halves of its own
-- pairing, computes the outcome itself -- no server authority needed given the
-- deterministic shared-seed pairing (domain/pvp_pairing.lua) every client
-- already agrees on independently.
--
-- CLOSED, 2026-08-25: vanilla's own "missed the chip target" game-over
-- trigger IS now suppressed for real multiplayer PvP rounds -- see hooks.lua's
-- end_round() hook, which temporarily zeroes G.GAME.blind.chips for exactly
-- this round type so vanilla's own game_over check always resolves false,
-- while leaving G.GAME.chips (the player's TRUE score, read below) untouched.
-- Verified live: two real instances both scored under the vanilla target
-- (400/1000 and 900/1000) in the same real PvP round, neither hit game-over,
-- and the loser took exactly the damage this file's formula predicts.
MPAPI.ActionType({
	key = 'tft_round_result',
	on_receive = function(action_type, from_player_id, params)
		TFT._collected_round_results = TFT._collected_round_results or {}
		TFT._collected_round_results[from_player_id] = params

		local state = TFT.get_state()
		if not state or not state.current_pairing then return end
		local my_id = MPAPI.get_current_lobby and MPAPI.get_current_lobby() and MPAPI.get_current_lobby().player_id
		if not my_id then return end

		local opponent_id = TFT.find_pvp_opponent(state.current_pairing, my_id)
		if not opponent_id then return end -- we're the ghost this round, nothing to resolve

		local my_result = TFT._collected_round_results[my_id]
		local opp_result = TFT._collected_round_results[opponent_id]
		if not my_result or not opp_result then return end -- still waiting on one side

		if state.pvp_resolved_for_round == state.round_index then return end -- already resolved
		state.pvp_resolved_for_round = state.round_index

		local round_def = TFT.current_round_def()
		local stage = round_def and round_def.stage or 2
		local my_score, opp_score = my_result.score or 0, opp_result.score or 0

		if my_score >= opp_score then
			TFT.sendDebugMessage('PvP round won vs ' .. opponent_id .. ' (' .. my_score .. ' vs ' .. opp_score .. ')')

			-- Defensive & PvP / Economic augments whose WIN-side effect is
			-- fully self-contained (the winner's own client already knows
			-- both scores, via the same public formula, so no opponent-state
			-- broadcast is needed for either of these).
			if TFT.has_augment('vampiric') then
				-- ASSUMPTION: augments.md says "a percentage" without a number
				-- -- 50% of the damage the loser took, healed to the winner.
				local dealt = TFT.compute_pvp_damage(stage, my_score, opp_score)
				state.life_total = math.min(TFT.STARTING_LIFE, (state.life_total or TFT.STARTING_LIFE) + dealt * 0.5)
			end
			if TFT.has_augment('the_house_always_wins') and opp_score > 0 then
				local margin_pct = (my_score - opp_score) / opp_score * 100
				local bonus = math.min(50, math.floor(margin_pct / 5))
				if bonus > 0 then ease_dollars(bonus) end
			end
		else
			local damage = TFT.compute_pvp_damage(stage, opp_score, my_score)

			-- Damage-reduction augments stack additively, capped so a real hit
			-- can never be reduced to (or below) zero by a defensive pick alone.
			local reduction = 0
			if TFT.has_augment('thick_skin') then reduction = reduction + 0.10 end
			if TFT.has_augment('iron_wall') then reduction = reduction + 0.20 end
			if TFT.has_augment('fortress') then reduction = reduction + 0.50 end
			damage = damage * (1 - math.min(0.9, reduction))

			-- Glass Cannon: extra damage on a real loss (see definitions.lua's
			-- own note on interpreting augments.md's "lose an extra life
			-- beyond normal" against this mod's PvP-only life model) -- a full
			-- extra base-damage hit for the stage, not a percentage of the
			-- (already-reduced) roll.
			if TFT.has_augment('glass_cannon') then
				damage = damage + (TFT.PvPBaseDamageByStage[stage] or 0)
			end

			-- Padded Walls: the first damage instance THIS STAGE is halved.
			if TFT.has_augment('padded_walls') and state.padded_walls_stage_used ~= stage then
				state.padded_walls_stage_used = stage
				damage = damage * 0.5
			end

			-- High Roller: losing this round also costs half your money
			-- (capped $100) on top of life -- ASSUMPTION: only the self-cost
			-- half is wired; crediting the winner would need broadcasting this
			-- to their client, not built this pass (see this file's own gap
			-- note further down).
			if TFT.has_augment('high_roller') then
				local transfer = math.min(100, math.floor(G.GAME.dollars * 0.5))
				if transfer > 0 then ease_dollars(-transfer) end
			end

			-- An Eye for An Eye: self-side only (you take no damage this
			-- round) -- see this file's own closing note on why the "redirect
			-- to your opponent" half isn't wired.
			if TFT.has_augment('eye_for_an_eye') and not state.eye_for_an_eye_used then
				state.eye_for_an_eye_used = true
				damage = 0
			end

			local new_life = (state.life_total or TFT.STARTING_LIFE) - damage

			-- All or Nothing overrides Second Wind outright ("no Second Wind-
			-- type saves apply") -- checked first so both being owned at once
			-- resolves to the harsher rule, matching augments.md's own wording.
			if new_life <= 0 and TFT.has_augment('second_wind') and not TFT.has_augment('all_or_nothing')
				and not state.second_wind_used then
				state.second_wind_used = true
				new_life = 1
			end
			state.life_total = new_life

			TFT.sendDebugMessage('PvP round lost vs ' .. opponent_id .. ' (' .. my_score .. ' vs ' .. opp_score .. '), took ' .. string.format('%.1f', damage) .. ' damage, life now ' .. state.life_total)

			-- CLOSED, next-session-plan.md priority #1: elimination/placement
			-- (objects/round_flow/elimination.lua). Placement is read BEFORE
			-- state.eliminated flips true, so this player still counts as
			-- alive for their own number (TFT convention: last to die = 1st
			-- place, so the Nth player eliminated out of the lobby gets
			-- placement = however many were still standing at that instant,
			-- themselves included).
			if state.life_total <= 0 and not state.eliminated then
				state.placement = TFT.count_alive_players()
				state.eliminated = true
				TFT.sendDebugMessage('Eliminated -- placement #' .. state.placement)
				TFT.broadcast_life_total_change(state.life_total, true)
				TFT.show_elimination_screen(state.placement)
			else
				TFT.broadcast_life_total_change(state.life_total)
			end
		end
	end,
})

-- Cross-client augment effects NOT wired this pass, flagged rather than
-- silently half-done -- each needs the effect to land on the OPPONENT's own
-- client/life-total, which needs a new broadcast action (an "impose an extra
-- effect on my opponent" message) that this pass didn't add:
--   * Counterpunch (winner deals bonus damage to the loser)
--   * Iron Wall's own "-10% outgoing damage you deal" half
--   * High Roller's "money is... given to the winner" half (the loser's own
--     half-money loss above IS wired)
--   * Eye for an Eye (redirect your own damage onto your opponent instead)

-- Called once a player finishes scoring a real (multiplayer, not
-- solo-substituted) PvP round -- see objects/round_flow/pvp.lua.
function TFT.broadcast_round_result(score)
	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	if not lobby then return end
	lobby:action(MPAPI.ActionTypes['tft_round_result']):broadcast({ score = score })
end
