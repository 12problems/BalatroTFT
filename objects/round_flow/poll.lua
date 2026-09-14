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

	-- Trait Stickers (objects/traits/stickers.lua): keeps every owned
	-- Joker's sticker set in sync with its live trait tags every frame --
	-- cheap given a small owned-Joker count, and covers every real
	-- tag-changing event (a new Joker bought, Grand Emblem/Apprentice's
	-- Charm/Trait Heart picked) without a dedicated hook per call site.
	pcall(TFT.sync_all_trait_stickers)

	-- Level/XP HUD display (objects/round_flow/hud.lua) -- same "defer until
	-- the real object exists" pattern as the traits engine injection just
	-- above, since attaching a UIBox child to G.deck from inside
	-- Game:start_run itself is exactly the kind of thing that already hung
	-- this game once (hooks.lua's own comment on that real crash).
	if not state.deck_level_display_attached and G.deck then
		state.deck_level_display_attached = true
		pcall(TFT.attach_deck_level_display)
	end

	-- Host-configured match settings (next-session-plan-4.md item 5) --
	-- deferred the same way, since bonus money needs G.GAME.dollars to
	-- already be initialized by the real start_run flow. Consumed exactly
	-- once per run (TFT._pending_match_settings cleared immediately) --
	-- state.timer_enabled itself persists as real run state for every later
	-- round's TFT.restart_round_timer call to read.
	if TFT._pending_match_settings and not state.match_settings_applied then
		state.match_settings_applied = true
		local settings = TFT._pending_match_settings
		TFT._pending_match_settings = nil
		state.timer_enabled = settings.timer_enabled
		if settings.bonus_money and settings.bonus_money > 0 then
			ease_dollars(settings.bonus_money)
		end
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
			-- Buy XP button (objects/round_flow/shop_xp_buy.lua): cost escalates
			-- per purchase within a visit, same as vanilla's own reroll_cost --
			-- reset on every fresh shop entry.
			state.xp_buy_count_this_visit = 0
			-- Real shop timer (domain/round_timers.lua, full timer
			-- functionality 2026-08-28) -- multiplayer only, same scope as
			-- the hand-playing round timer above.
			if state.is_multiplayer and state.timer_enabled ~= false then
				state.shop_deadline_at = love.timer.getTime() + TFT.SHOP_TIMER_SECONDS
				state.shop_timed_out = false
			else
				state.shop_deadline_at = nil
			end
		elseif prev_state == G.STATES.SHOP then
			state.shop_deadline_at = nil
		end
		state.last_seen_state = cur_state
	end

	-- Real round-timer enforcement (domain/round_timers.lua, full timer
	-- functionality 2026-08-28): once time's up for a real hand-playing
	-- (PvE/PvP) round, force it to end RIGHT NOW with whatever chips are
	-- currently banked -- reuses the exact same safe end_round() mechanism
	-- (objects/round_flow/hooks.lua's own end_round hook, already proven for
	-- real wins/losses/PvP-miss suppression) so every downstream system
	-- (round_result broadcast, elimination, round advance) picks this up
	-- completely normally, with zero special-casing needed -- the player's
	-- TRUE banked score (G.GAME.chips) is exactly what gets broadcast,
	-- matching the design doc's own "currently-banked score stands, never
	-- auto-played or zeroed" rule for free.
	if state.round_deadline_at and love.timer.getTime() >= state.round_deadline_at
		and state.round_timed_out_for_index ~= state.round_index
		and G.GAME.blind and G.GAME.blind.in_blind then
		state.round_timed_out_for_index = state.round_index
		state.round_deadline_at = nil
		TFT.sendDebugMessage('Round timer expired at round_index ' .. state.round_index
			.. ' -- forcing round end with ' .. tostring(G.GAME.chips) .. ' chips banked')
		pcall(end_round)
	end

	-- Real shop-timer enforcement: force-leave the shop the same way the real
	-- "Next Round" button does (G.FUNCS.toggle_shop) once time's up. Guarded
	-- to the SHOP state itself so this can't fire on some later screen still
	-- holding a stale shop_deadline_at.
	if state.shop_deadline_at and love.timer.getTime() >= state.shop_deadline_at
		and not state.shop_timed_out and cur_state == G.STATES.SHOP then
		state.shop_timed_out = true
		state.shop_deadline_at = nil
		TFT.sendDebugMessage('Shop timer expired -- leaving shop automatically')
		pcall(function() G.FUNCS.toggle_shop({}) end)
	end

	-- Real Augment Checkpoint timer enforcement (domain/round_timers.lua):
	-- auto-picks the first offered option once time's up, same
	-- "least-punishing, never leaves the player stuck" spirit as the
	-- Carousel draft's own established timeout-auto-pick
	-- (objects/actions/carousel_draft.lua) -- checkpoint offers are
	-- per-player/local (no shared pool to contend over), so this needs no
	-- host authority or broadcast at all, unlike Carousel's real draft.
	if state.pending_augment_offer and state.pending_augment_offer.deadline_at
		and love.timer.getTime() >= state.pending_augment_offer.deadline_at then
		TFT.sendDebugMessage('Augment Checkpoint timer expired -- auto-picking option 1')
		pcall(function() G.FUNCS.tft_pick_augment_1() end)
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

	-- Perfect Game (objects/augments/perfect_game.lua): same "read G.GAME.chips
	-- before it resets" timing constraint as the PvP broadcast just below.
	pcall(TFT.check_perfect_game, just_completed)

	if state.is_multiplayer and just_completed and just_completed.round_type == TFT.RoundType.PVP then
		pcall(TFT.broadcast_round_result, G.GAME.chips or 0)
	end

	-- Ghost-board snapshot (objects/actions/round_result.lua): kept fresh
	-- after every real scored round (PvE or PvP -- not Carousel, which has no
	-- chip score at all), so whoever ends up ghosted on a future odd-lobby
	-- PvP round has a reasonably recent score on file to play against.
	if state.is_multiplayer and just_completed and just_completed.round_type ~= TFT.RoundType.CAROUSEL then
		pcall(TFT.broadcast_ghost_snapshot, G.GAME.chips or 0)
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
		pcall(TFT.refresh_stage_roadmap_display)
		pcall(TFT.restart_round_timer)
	end
end

-- Shared by passive per-round XP and any other real XP source (the shop's
-- Buy XP button, objects/round_flow/shop_xp_buy.lua) -- extracted so both
-- go through the identical level-up-check-and-apply path rather than
-- duplicating it.
function TFT.grant_xp(amount)
	local state = TFT.get_state()
	if not state then return end
	state.xp = state.xp + amount
	local new_level = TFT.level_for_xp(state.xp)
	if new_level > state.level then
		local from_level = state.level + 1
		-- Set BEFORE apply_level_up (which may open a real picker overlay,
		-- objects/round_flow/level_rewards.lua) rather than after, so the HUD
		-- level text and any reward-eligibility check made while that overlay
		-- is up already reflects the new level, not the stale one.
		state.level = new_level
		TFT.apply_level_up(from_level, new_level)
		if state.is_multiplayer then
			pcall(TFT.broadcast_xp_level_change, new_level)
		end
	end
end

function TFT.grant_passive_xp()
	TFT.grant_xp(TFT.PASSIVE_XP_PER_ROUND)
end

-- Checkpoint (augment pick): opens the real picker (objects/augments/
-- checkpoint.lua). Called right as round_index moves onto the checkpoint
-- round, before the player plays it -- matches architecture.md's "before round
-- 2-1" phrasing.
--
-- DEFERS instead of opening immediately if a level-up reward picker
-- (objects/round_flow/level_rewards.lua) is already queued/showing -- both
-- use the same one-at-a-time G.FUNCS.overlay_menu, and a level-up can
-- coincide with a checkpoint round on the same round transition (checkpoints
-- are fixed to stages 2/4/6; level-ups are XP-paced and can land anywhere).
-- TFT.show_next_level_reward() calls TFT.open_deferred_checkpoint_if_any()
-- once its own queue drains, which is what actually opens this checkpoint.
function TFT.announce_checkpoint_if_due()
	local round_def = TFT.current_round_def()
	if not round_def or not round_def.is_checkpoint then return end
	local state = TFT.get_state()
	if state and state.pending_level_reward_queue and #state.pending_level_reward_queue > 0 then
		state.pending_checkpoint_round_def = round_def
		return
	end
	TFT.sendDebugMessage('Augment checkpoint ' .. round_def.checkpoint_tier_index
		.. ' due at stage ' .. round_def.stage .. '-' .. round_def.round_in_stage)
	TFT.open_augment_checkpoint(round_def)
end

function TFT.open_deferred_checkpoint_if_any()
	local state = TFT.get_state()
	local round_def = state and state.pending_checkpoint_round_def
	if round_def then
		state.pending_checkpoint_round_def = nil
		TFT.sendDebugMessage('Augment checkpoint ' .. round_def.checkpoint_tier_index
			.. ' due at stage ' .. round_def.stage .. '-' .. round_def.round_in_stage .. ' (deferred for a level reward)')
		TFT.open_augment_checkpoint(round_def)
	end
end
