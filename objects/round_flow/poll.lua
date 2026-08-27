-- Balatro has no single "round advanced" callback (confirmed against
-- BalatroMultiplayerSpeedrun's own source -- see technical.md). Called every
-- frame from core.lua's Game:update hook. Detects the two ways a TFT round ends
-- (a normal scored Blind via G.STATES.ROUND_EVAL, or an instant Carousel pick,
-- which never becomes a real Blind at all) and drives TFT.get_state().round_index
-- forward, applying passive XP and (stub, this session) checkpoint detection.
function TFT.round_flow_poll()
	if not G.GAME or G.STAGE ~= G.STAGES.RUN then return end

	local state = TFT.get_state()
	if not state or not state.initialized then return end

	-- Deferred here from Game:start_run (see hooks.lua's comment) -- a normal
	-- per-frame context, unlike nested-inside-start_run which hung the game.
	if not state.traits_engine_injected and G.jokers then
		state.traits_engine_injected = true
		pcall(TFT.ensure_traits_engine_joker)
	end

	local prev_state = state.last_seen_state
	local cur_state = G.STATE

	if cur_state ~= prev_state then
		-- A normal PvE/PvP round just finished being scored: ROUND_EVAL is the
		-- animation state that plays right after a Blind is cleared, before
		-- SHOP/NEW_ROUND/BLIND_SELECT.
		if prev_state == G.STATES.ROUND_EVAL then
			TFT.round_flow_advance()
		end
		-- Vintage Collection (Prismatic, Shop & Items): "once per shop visit"
		-- -- reset the per-visit flag the instant we actually enter the shop,
		-- not merely once per round, so leaving and re-entering (a fresh
		-- SHOP-state transition) correctly re-arms it.
		if cur_state == G.STATES.SHOP then
			state.vintage_collection_used_this_visit = false
		end
		state.last_seen_state = cur_state
	end

	-- Rainy Day Fund (Silver, Economic): once per stage, if you'd hit $0,
	-- gain $10 grace. Checked every frame (cheap: two field reads + a
	-- has_augment scan) rather than hooked onto every possible money-losing
	-- call site (reroll, buy, sell, PvP upkeep...), which would mean finding
	-- and wrapping each one individually for the same net effect.
	do
		local round_def = TFT.current_round_def()
		local stage = round_def and round_def.stage
		if stage and G.GAME.dollars <= 0 and TFT.has_augment('rainy_day_fund')
			and state.rainy_day_used_stage ~= stage then
			state.rainy_day_used_stage = stage
			ease_dollars(10)
		end
	end

	-- Carousel rounds aren't real Blinds -- open the picker (objects/round_flow/
	-- carousel.lua) the instant we'd otherwise be sitting at blind-select for
	-- one, before the player ever sees a (nonsensical, chip-target-less)
	-- blind-select screen for it. Guarded so it only opens once per round_index
	-- (the player closing/re-triggering a frame shouldn't reopen it).
	local round_def = TFT.current_round_def()
	if round_def and round_def.round_type == TFT.RoundType.CAROUSEL
		and cur_state == G.STATES.BLIND_SELECT
		and state.round_advanced_for_index ~= state.round_index
		and not state.carousel_opened_for_index then
		state.carousel_opened_for_index = state.round_index
		TFT.open_carousel(round_def)
	end
	if round_def and round_def.round_type ~= TFT.RoundType.CAROUSEL then
		state.carousel_opened_for_index = nil
	end

	-- HUD live-text refresh (objects/round_flow/hud.lua): round timer text and
	-- life totals are cheap per-frame string rebuilds (a couple table field
	-- reads each), same cost class as the money-loss check just above -- no
	-- need to gate this behind a state-transition check.
	pcall(TFT.update_hud_display_texts)

	-- The stage roadmap is no longer a separate popup trigger here -- per the
	-- 2026-08-25 session correction, it's now prepended directly into vanilla's
	-- own blind-select screen construction (objects/round_flow/blind_select.lua's
	-- create_UIBox_blind_select hook), not layered on top of it as a second
	-- overlay. objects/round_flow/stage_overview.lua's popup-based renderer is
	-- superseded/unused -- kept in the tree for now, not deleted, but nothing
	-- calls it anymore.
end

-- Applies the round-complete side effects (passive XP, checkpoint stub) and
-- moves to the next round descriptor. reset_blinds() (already hooked, see
-- hooks.lua) picks up the new current_round_def() the next time vanilla calls
-- it naturally -- we don't need to force that here.
function TFT.round_flow_advance()
	local state = TFT.get_state()
	local sequence = TFT.ensure_sequence()
	if not state or not sequence then return end
	if state.round_advanced_for_index == state.round_index then return end -- already handled
	state.round_advanced_for_index = state.round_index

	-- Real multiplayer PvP round just scored: broadcast the result before
	-- anything else touches G.GAME.chips (it resets for the next round almost
	-- immediately after this point). See objects/round_flow/pvp.lua and
	-- objects/actions/round_result.lua for the collection/damage side.
	local just_completed = TFT.current_round_def()
	if state.is_multiplayer and just_completed and just_completed.round_type == TFT.RoundType.PVP then
		pcall(TFT.broadcast_round_result, G.GAME.chips or 0)
	end

	TFT.grant_passive_xp()
	TFT.grant_passive_money_for_level(state.level)
	pcall(TFT.trait_round_reset)

	-- Overdraft (Gold, Risky & Situational): $3 upkeep at the end of every
	-- round for the rest of the match, once picked. Applied here (once per
	-- real round transition) rather than per-stage, matching augments.md's
	-- own "end of every future round" wording exactly (not "every stage").
	if TFT.has_augment('overdraft') then
		ease_dollars(-3)
	end

	-- Stage just changed (Steady Heart's heal, Reroll Refund's payout, both
	-- explicitly "per stage" in augments.md, unlike Overdraft's per-round
	-- upkeep above). just_completed is the round def BEFORE this function's
	-- round_index increment below, so comparing its stage against the new
	-- current_round_def() (after the increment) reliably detects the exact
	-- moment a stage boundary is crossed, not just any round advance.
	local next_round_def = state.round_index < #sequence and sequence[state.round_index + 1] or nil
	if next_round_def and just_completed and next_round_def.stage ~= just_completed.stage then
		if TFT.has_augment('steady_heart') then
			state.life_total = math.min(TFT.STARTING_LIFE, (state.life_total or TFT.STARTING_LIFE) + 3)
		end
		if TFT.has_augment('reroll_refund') and (state.reroll_spend_this_stage or 0) > 0 then
			ease_dollars(math.floor(state.reroll_spend_this_stage * 0.25))
		end
		state.reroll_spend_this_stage = 0
	end

	if state.round_index == #sequence then
		-- The true final round just cleared. Vanilla's own win_game() call site
		-- (state_events.lua) is gated on `blind:get_type() == 'Boss'` -- since
		-- the 2026-08-25 PvE/Boss correction means the true final round (each
		-- stage's 7th, PvE-based) is now a Small Blind, not Boss, that call
		-- site would never fire on its own. Trigger it explicitly here instead.
		win_game()
	elseif state.round_index < #sequence then
		state.round_index = state.round_index + 1
		TFT.announce_checkpoint_if_due()
		pcall(TFT.setup_pvp_pairing_if_needed)
		-- HUD refresh (objects/round_flow/hud.lua): the stage roadmap's pip
		-- colours and the round timer both depend on the round that JUST
		-- became current, so both refresh here rather than waiting on the
		-- next screen render.
		pcall(TFT.refresh_hud_stage_display)
		pcall(TFT.restart_round_timer)
	end
end

function TFT.grant_passive_xp()
	local state = TFT.get_state()
	if not state then return end
	state.xp = state.xp + TFT.PASSIVE_XP_PER_ROUND
	local new_level = TFT.level_for_xp(state.xp)
	if new_level > state.level then
		TFT.apply_level_up(state.level + 1, new_level)
		state.level = new_level
	end
end

-- Checkpoint (augment pick): opens the real picker (objects/augments/
-- checkpoint.lua). Called right as round_index moves onto the checkpoint
-- round, before the player plays it -- matches architecture.md's "before round
-- 2-1" phrasing.
function TFT.announce_checkpoint_if_due()
	local round_def = TFT.current_round_def()
	if not round_def or not round_def.is_checkpoint then return end
	TFT.sendDebugMessage('Augment checkpoint ' .. round_def.checkpoint_tier_index
		.. ' due at stage ' .. round_def.stage .. '-' .. round_def.round_in_stage)
	TFT.open_augment_checkpoint(round_def)
end
