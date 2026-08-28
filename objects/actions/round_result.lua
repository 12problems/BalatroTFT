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
--
-- CLOSED, next-session-plan.md priority #3: the cross-client augment effects
-- flagged below (Counterpunch, Iron Wall's outgoing half, High Roller's
-- credit, Eye for an Eye's redirect) all need to know something about the
-- OTHER player at resolution time that isn't visible locally -- which
-- augments they hold, and (for High Roller) their exact money total.
-- Resolved WITHOUT a second broadcast round-trip: this data doesn't depend on
-- who wins (a player's own augments/dollars are known before the outcome is
-- decided), so it rides along on the SAME tft_round_result broadcast both
-- players already send the instant their own round finishes. By the time
-- either client resolves (has both my_result and opp_result), it already has
-- everything needed to compute the FULL bidirectional outcome -- both scores,
-- both dollar totals, both relevant augment flags -- so both clients run the
-- identical deterministic computation and each just applies their OWN side of
-- it, exactly like the score comparison itself already worked.
-- Shared by both the normal two-real-players resolution below and the
-- ghost-board path (a ghost has no real opponent broadcast to pair against,
-- so it resolves against a snapshot instead -- see TFT._ghost_snapshots and
-- the tft_ghost_snapshot action further down). `opponent_label` is just for
-- the debug message; `opp_aug` is `{}` for a snapshot opponent (a snapshot
-- only ever carries a score, not augment flags -- see that section's own
-- ASSUMPTION note).
function TFT.resolve_pvp_outcome(state, stage, my_score, opp_score, my_aug, opp_aug, opponent_label)
	if my_score >= opp_score then
		TFT.sendDebugMessage('PvP round won vs ' .. opponent_label .. ' (' .. my_score .. ' vs ' .. opp_score .. ')')

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

		-- High Roller's credit half: the loser (opponent here) already
		-- halves their OWN money in the loss branch below, using this
		-- exact formula against their OWN `dollars` snapshot -- crediting
		-- the identical amount here keeps both sides of the transfer
		-- exactly matched, not just "some money to each side."
		if opp_aug.high_roller then
			local transfer = math.min(100, math.floor((opp_aug.dollars or 0) * 0.5))
			if transfer > 0 then ease_dollars(transfer) end
		end

		-- Eye for an Eye's redirect half: the opponent (loser) was
		-- eligible (had the augment, hadn't used it yet as of THEIR
		-- broadcast) and lost, so per the deterministic rule below they
		-- take 0 and I take their hit instead. ASSUMPTION (flagged): the
		-- redirected hit is the plain base+margin damage with no
		-- attacker-side modifiers from EITHER side folded in (no
		-- Counterpunch/Iron-Wall-outgoing from me, since I'm not really
		-- "attacking" here -- this damage was never mine to begin with --
		-- and none of the opponent's own defensive picks either, since
		-- they're not the one taking it) -- but MY OWN defensive augments
		-- still apply, via the same TFT.apply_own_defensive_reductions
		-- helper the normal loss branch below uses, since a hit landing
		-- on me should still respect picks I made to protect myself,
		-- regardless of where it came from.
		if opp_aug.eye_for_an_eye_available then
			local redirected = TFT.compute_pvp_damage(stage, my_score, opp_score)
			redirected = TFT.apply_own_defensive_reductions(state, redirected, stage)
			TFT.apply_life_loss(state, redirected)
		end
	else
		local damage = TFT.compute_pvp_damage(stage, opp_score, my_score)

		-- Counterpunch / Iron Wall's outgoing half: the WINNER's (opponent
		-- here) own augments, read from their broadcast flags -- applied
		-- to the base/margin damage BEFORE my own defensive reductions,
		-- same order vanilla-style damage pipelines use elsewhere in this
		-- file (compute the raw hit, then let the target's own defenses
		-- reduce it).
		if opp_aug.iron_wall then damage = damage * 0.9 end
		if opp_aug.counterpunch then
			-- ASSUMPTION: augments.md's "bonus damage scaled to your
			-- margin of victory" isn't a concrete number -- reusing the
			-- SAME margin-scaling term compute_pvp_damage already derives
			-- (base * log10(ratio)) as the bonus, i.e. Counterpunch
			-- roughly doubles the margin-based portion of a normal hit
			-- without touching the flat base, rather than inventing a
			-- second, unrelated formula.
			local base = TFT.PvPBaseDamageByStage[stage] or TFT.PvPBaseDamageByStage[7]
			damage = damage + (TFT.compute_pvp_damage(stage, opp_score, my_score) - base)
		end

		damage = TFT.apply_own_defensive_reductions(state, damage, stage)

		-- High Roller: losing this round also costs half your money
		-- (capped $100) on top of life -- the winner's matching credit is
		-- applied on their own client in the win branch above, using this
		-- exact same formula against the `dollars` value broadcast below.
		if TFT.has_augment('high_roller') then
			local transfer = math.min(100, math.floor(G.GAME.dollars * 0.5))
			if transfer > 0 then ease_dollars(-transfer) end
		end

		-- An Eye for An Eye: redirect now fully wired -- the winner's own
		-- client (processing this identical broadcast pair) independently
		-- reaches the same "opponent had it available and lost" fact via
		-- opp_aug.eye_for_an_eye_available in their own win branch above,
		-- and applies the redirected hit to themselves there. This side
		-- just zeroes out and marks it used, same as before.
		if my_aug.eye_for_an_eye_available then
			state.eye_for_an_eye_used = true
			damage = 0
		end

		TFT.apply_life_loss(state, damage)
		TFT.sendDebugMessage('PvP round lost vs ' .. opponent_label .. ' (' .. my_score .. ' vs ' .. opp_score .. '), took ' .. string.format('%.1f', damage) .. ' damage, life now ' .. state.life_total)
	end
end

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
		if not opponent_id then
			-- We're the ghost this round (architecture.md's ghost-board
			-- mechanic) -- resolve against a snapshot of another player's
			-- board/score instead of a real paired opponent, once OUR OWN
			-- broadcast loops back to us (from_player_id == my_id; every
			-- other client's copy of this same broadcast is a no-op for them
			-- too, since nobody else is paired against the ghost either).
			if from_player_id ~= my_id then return end
			if state.current_pairing.ghost ~= my_id then return end
			if state.pvp_resolved_for_round == state.round_index then return end
			state.pvp_resolved_for_round = state.round_index

			local round_def = TFT.current_round_def()
			local stage = round_def and round_def.stage or 2
			local my_score = params.score or 0
			local snapshot_of = state.current_pairing.ghost_opponent_snapshot_of
			-- ASSUMPTION (flagged, see docs/design/4-8-player-test-plan.md's
			-- "Finding 2" and this project's own next-session-plan-5.md):
			-- architecture.md specifies "a snapshot of another player's
			-- board/score" without saying which player, which round of
			-- theirs, or whether it's frozen at pairing time -- this uses
			-- that other player's MOST RECENT tft_ghost_snapshot (their own
			-- last completed round's score, of any round type, kept fresh
			-- every round by the broadcast below), and no augment flags at
			-- all for the snapshot side (a snapshot only ever carries a raw
			-- score, not augment state) -- so Counterpunch/Iron
			-- Wall/High Roller/Eye for an Eye never trigger FROM a snapshot
			-- opponent, though the ghost's OWN augments (checked inside
			-- resolve_pvp_outcome via TFT.has_augment, not via opp_aug)
			-- still apply normally. Falls back to the ghost's own score
			-- (a no-damage tie) if no snapshot is available yet (e.g. the
			-- very first PvP round of a match somehow started with an odd
			-- lobby) rather than defaulting to 0, which would always deal
			-- the ghost free damage for no real reason.
			local opp_score = (snapshot_of and TFT._ghost_snapshots and TFT._ghost_snapshots[snapshot_of]) or my_score
			TFT.resolve_pvp_outcome(state, stage, my_score, opp_score, params.augments or {}, {}, 'a ghost-board snapshot')
			return
		end

		local my_result = TFT._collected_round_results[my_id]
		local opp_result = TFT._collected_round_results[opponent_id]
		if not my_result or not opp_result then return end -- still waiting on one side

		if state.pvp_resolved_for_round == state.round_index then return end -- already resolved
		state.pvp_resolved_for_round = state.round_index

		local round_def = TFT.current_round_def()
		local stage = round_def and round_def.stage or 2
		local my_score, opp_score = my_result.score or 0, opp_result.score or 0
		local my_aug, opp_aug = my_result.augments or {}, opp_result.augments or {}
		-- Folded into opp_aug so resolve_pvp_outcome's High Roller credit
		-- branch (which needs the OPPONENT's dollar total) doesn't need a
		-- separate parameter just for this one field.
		opp_aug.dollars = opp_result.dollars
		TFT.resolve_pvp_outcome(state, stage, my_score, opp_score, my_aug, opp_aug, opponent_id)
	end,
})

-- Ghost-board support: every player broadcasts their own latest score at the
-- end of EVERY round (not just PvP -- a PvE or Carousel round is just as
-- valid a "most recent board" snapshot), so there's always a reasonably
-- fresh score on file for whoever might need it as a ghost's snapshot
-- opponent later. See TFT.resolve_pvp_outcome's ghost branch above and
-- TFT.round_flow_advance (objects/round_flow/poll.lua) for the broadcast
-- call site.
TFT._ghost_snapshots = TFT._ghost_snapshots or {}
MPAPI.ActionType({
	key = 'tft_ghost_snapshot',
	on_receive = function(action_type, from_player_id, params)
		TFT._ghost_snapshots[from_player_id] = params.score or 0
	end,
})

function TFT.broadcast_ghost_snapshot(score)
	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	if not lobby then return end
	lobby:action(MPAPI.ActionTypes['tft_ghost_snapshot']):broadcast({ score = score })
end

-- Shared damage-reduction stack (Thick Skin/Iron Wall's own incoming half/
-- Fortress additively, Glass Cannon's extra hit, Padded Walls' once-per-stage
-- halving) -- factored out so BOTH the normal loss path above and Eye for an
-- Eye's redirect-received path (a player taking damage that didn't originate
-- from their own PvP loss) apply identically: a defensive pick should protect
-- its owner regardless of why they're taking a hit.
function TFT.apply_own_defensive_reductions(state, damage, stage)
	local reduction = 0
	if TFT.has_augment('thick_skin') then reduction = reduction + 0.10 end
	if TFT.has_augment('iron_wall') then reduction = reduction + 0.20 end
	if TFT.has_augment('fortress') then reduction = reduction + 0.50 end
	damage = damage * (1 - math.min(0.9, reduction))

	-- Glass Cannon: extra damage on a real loss (see definitions.lua's own
	-- note on interpreting augments.md's "lose an extra life beyond normal"
	-- against this mod's PvP-only life model) -- a full extra base-damage hit
	-- for the stage, not a percentage of the (already-reduced) roll.
	if TFT.has_augment('glass_cannon') then
		damage = damage + (TFT.PvPBaseDamageByStage[stage] or 0)
	end

	-- Padded Walls: the first damage instance THIS STAGE is halved.
	if TFT.has_augment('padded_walls') and state.padded_walls_stage_used ~= stage then
		state.padded_walls_stage_used = stage
		damage = damage * 0.5
	end

	return damage
end

-- Applies a final damage number to this player's own life total -- the
-- Second Wind/All or Nothing floor logic and elimination/placement/broadcast
-- wiring (objects/round_flow/elimination.lua) are shared between the normal
-- loss path and Eye for an Eye's redirect-received path, so this is the one
-- place either of them needs to call.
function TFT.apply_life_loss(state, damage)
	local new_life = (state.life_total or TFT.STARTING_LIFE) - damage

	-- All or Nothing overrides Second Wind outright ("no Second Wind-type
	-- saves apply") -- checked first so both being owned at once resolves to
	-- the harsher rule, matching augments.md's own wording.
	if new_life <= 0 and TFT.has_augment('second_wind') and not TFT.has_augment('all_or_nothing')
		and not state.second_wind_used then
		state.second_wind_used = true
		new_life = 1
	end
	state.life_total = new_life

	-- next-session-plan.md priority #1: elimination/placement
	-- (objects/round_flow/elimination.lua). Placement is read BEFORE
	-- state.eliminated flips true, so this player still counts as alive for
	-- their own number (TFT convention: last to die = 1st place, so the Nth
	-- player eliminated out of the lobby gets placement = however many were
	-- still standing at that instant, themselves included).
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

-- Called once a player finishes scoring a real (multiplayer, not
-- solo-substituted) PvP round -- see objects/round_flow/pvp.lua. Carries this
-- player's own money total and the augment flags every cross-client effect
-- above needs to see from the OTHER side -- all of it knowable before the
-- outcome itself is, so no extra broadcast round-trip is needed once both
-- sides' results are collected (see this file's header note).
function TFT.broadcast_round_result(score)
	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	if not lobby then return end
	local state = TFT.get_state()
	lobby:action(MPAPI.ActionTypes['tft_round_result']):broadcast({
		score = score,
		dollars = G.GAME.dollars,
		augments = {
			counterpunch = TFT.has_augment('counterpunch') or nil,
			iron_wall = TFT.has_augment('iron_wall') or nil,
			high_roller = TFT.has_augment('high_roller') or nil,
			eye_for_an_eye_available = (TFT.has_augment('eye_for_an_eye') and not (state and state.eye_for_an_eye_used)) or nil,
		},
	})
end
