-- The actual monkey-patches that turn vanilla's Ante/Small/Big/Boss structure
-- into our Stage/Round structure. Deliberately minimal-intervention: reuse
-- vanilla's own blind_states machinery, boss-eligibility formula, and chip-amount
-- field, just fed our own numbers, rather than replacing any of those systems
-- outright. See docs/design/technical.md's "Round/Stage State Machine" section
-- and architecture.md's "PvE Chip Requirements & Boss Blind Assignment".
--
-- ASSUMPTION (flagged, not confirmed with you): every run started while this mod
-- is loaded becomes a TFT run unconditionally -- there's no mode-select menu this
-- session, so there's no other signal to gate on. Revisit before this ever ships
-- alongside other gamemodes.

-- 1. Run start: initialize our state and pin G.GAME.win_ante to our stage count
-- so vanilla's own boss-eligibility formula (get_new_boss, common_events.lua)
-- naturally gates the 5 finisher bosses to our real Stage 7, with zero
-- reimplementation of that eligibility logic.
local _tft_orig_start_run = Game.start_run
function Game:start_run(args)
	_tft_orig_start_run(self, args)
	local state = TFT.get_state()
	if state then
		state.initialized = true
		state.round_index = 1
		state.round_advanced_for_index = 0
		state.level = 1
		state.xp = 0
		-- Real multiplayer detection: true once MPAPI has this mod's lobby
		-- active (set as soon as MPAPI.create_lobby/join_lobby succeeds for our
		-- id, per ui/lobby.lua -- NOT gated on the run having started yet).
		-- Solo play (no lobby at all) still works: MPAPI.is_active returns
		-- false with no current lobby, same as before this session's
		-- multiplayer work.
		state.is_multiplayer = MPAPI.is_active(TFT.id)
		state.sequence = TFT.build_round_sequence(state.is_multiplayer)
		-- CAUGHT via live 2-instance PvP test, 2026-08-25: objects/actions/
		-- round_result.lua only ever sets state.life_total on a player's FIRST
		-- loss (`state.life_total = (state.life_total or TFT.STARTING_LIFE) -
		-- damage`) -- a player who never loses a round keeps a nil life_total
		-- for the entire run, confirmed live (the round's winner's life_total
		-- read back as nil/undefined after a real PvP round). Initialized
		-- explicitly here instead so it's always a well-defined 100 from turn
		-- one, for any future HUD display that reads it before a first loss.
		state.life_total = TFT.STARTING_LIFE

		-- CAUGHT while wiring the HUD's opponent-life display: this is a plain
		-- mod-level global, not scoped to a run/lobby at all -- without a reset
		-- here, a second run in the same session could show a PAIRED player's
		-- life total left over from a completely different match (a different
		-- lobby that happened to reuse the same player id slot, or just this
		-- player's OWN previous match). Cheap and safe to just clear it whenever
		-- a fresh run actually starts.
		TFT._opponent_life_totals = {}
		TFT._eliminated_players = {}
		state.eliminated = nil
		state.match_won = nil
		state.placement = nil
	end
	G.GAME.win_ante = #TFT.StageLayout -- 7
	state.traits_engine_injected = false

	-- Round timer HUD (objects/round_flow/hud.lua): starts counting from this
	-- run's very first round. Subsequent rounds restart it from poll.lua's
	-- TFT.round_flow_advance, the same real per-round-transition hook point.
	if TFT.restart_round_timer then TFT.restart_round_timer() end

	-- Caught via live testing: reset_blinds()'s only two real call sites
	-- (game.lua, button_callbacks.lua) both fire on ante-ADVANCE, after a Boss
	-- is cleared -- neither ever runs for a fresh run's very first blind-select
	-- screen (that initial Small/Select state comes straight from
	-- init_game_object's own defaults). Without this explicit call, Round 1 of
	-- Stage 1 would show vanilla's normal Small/Big/Boss flow instead of our
	-- ante-forced, boss-only, chip-overridden one. Safe to call here since
	-- state.initialized is already true above, so is_run_active() reads correctly.
	reset_blinds()

	-- NOT called here. See objects/traits/engine.lua's TFT.ensure_traits_engine_joker
	-- doc comment: calling create_card/emplace synchronously nested inside
	-- Game:start_run's own call chain hung the game (no crash logged -- a real
	-- timing issue, not the earlier nil-.ability bug). Deferred to
	-- objects/round_flow/poll.lua's per-frame poll instead, which is a normal,
	-- already-settled frame context (matching how ClaudeControl's own
	-- spawn_joker action is normally invoked standalone between frames).
end

-- Which vanilla blind SLOT a round uses. Per the 2026-08-25 session correction:
-- only PvP-type rounds (or their single-player PvE substitutes) are Boss
-- blinds (a real boss ability affecting play) -- genuinely-PvE-typed rounds
-- (Stage 1's 3 rounds, and each stage's 7th round) use the plain Small Blind
-- instead (no ability, just a chip check). Keyed off `base_round_type` (the
-- PRE-substitution type from domain/stage_layout.lua), not the post-
-- substitution `round_type`, since that's what actually distinguishes "this
-- was always PvE" from "this is standing in for a PvP fight."
function TFT.slot_type_for_round(round_def)
	if round_def.base_round_type == TFT.RoundType.PVE then
		return 'Small'
	end
	return 'Boss'
end

-- Pre-rolls the real blind for EVERY scoring round in a stage, all at once,
-- the first time that stage is touched -- rather than lazily picking one per
-- round as it's reached. This is what lets the roadmap/blind-select screen
-- show each upcoming round's REAL blind (icon/name/description), not a
-- placeholder. PvP-based rounds get a real rolled boss (reusing vanilla's own
-- get_new_boss(), so its least-used-boss tracking and finisher-pool gating
-- keep working with zero reimplementation); PvE-based rounds just get the
-- plain Small Blind key, every time.
function TFT.ensure_stage_blinds_rolled(stage)
	local state = TFT.get_state()
	if not state then return end
	state.stage_blind_assignments = state.stage_blind_assignments or {}
	if state.stage_blind_assignments[stage] then return end

	local assignments = {}
	local saved_ante = G.GAME.round_resets.ante
	G.GAME.round_resets.ante = stage
	for _, round_def in ipairs(TFT.ensure_sequence()) do
		if round_def.stage == stage and round_def.round_type ~= TFT.RoundType.CAROUSEL then
			local slot_type = TFT.slot_type_for_round(round_def)
			local key = (slot_type == 'Boss') and get_new_boss() or 'bl_small'
			assignments[round_def.round_in_stage] = { slot_type = slot_type, key = key }
		end
	end
	G.GAME.round_resets.ante = saved_ante
	state.stage_blind_assignments[stage] = assignments
end

-- 2. Every blind-state reset (new stage's Small/Big/Boss slots coming up):
-- force the Ante to match our current TFT stage (vanilla's own ease_ante climbs
-- Ante once per Boss clear, i.e. once per TFT ROUND -- since every TFT round is
-- Boss-shaped, that's a real mismatch with a per-STAGE Ante; this stomps it back
-- into sync), and select straight into whichever slot this round actually uses
-- (Small for PvE-based rounds, Boss for PvP-based -- see TFT.slot_type_for_round).
--
-- CORRECTED via live screenshot review, 2026-08-25: the other two slots were
-- being marked 'Skipped', but create_UIBox_blind_select still renders a full
-- column for ANY state other than 'Hide' -- 'Skipped' still builds a real
-- (greyed-out, stamped) column. Since we swap which slot type is "active"
-- round to round (Small for one round, Boss for the next), the INACTIVE
-- slot's state was also carrying over stale from whenever it was last
-- actually used (e.g. Small showing "Defeated" from 2 rounds ago, while Boss
-- is the real current round) -- three confusing ghost columns instead of one
-- clean card. 'Hide' makes vanilla skip building that column at all, exactly
-- matching how vanilla itself hides Big Blind... never, actually (vanilla
-- always shows exactly 3) -- but 'Hide' is a real, supported state vanilla's
-- own code already checks for (`blind_states['Small'] ~= 'Hide'` gates
-- whether that column is even constructed), just never used by vanilla's own
-- flow. No Tag/reward is granted for the never-shown slots (unlike vanilla's
-- real skip_blind button), since this isn't a player choice. Also assigns the
-- round's PRE-ROLLED blind (see TFT.ensure_stage_blinds_rolled above) rather
-- than letting get_new_boss() pick one lazily/independently, so the round
-- actually played always matches what the roadmap showed.
--
-- CORRECTED AGAIN via live 2-instance PvP test, 2026-08-25: this used to be
-- ONLY a reset_blinds() hook, on the assumption reset_blinds() runs at every
-- round transition. Confirmed false by grepping vanilla source -- it has
-- exactly two real call sites (game.lua's run-start path, and
-- button_callbacks.lua's cash-out handler, ITSELF gated on
-- `blind_states.Boss == 'Defeated'`). Vanilla only ever plays one Small blind
-- per real Ante, so it never needs to re-arm the Small slot without a Boss
-- clearing first -- our design reuses the SAME slot type across MULTIPLE
-- rounds in a stage (three PvE-typed rounds in Stage 1 alone, several PvP/
-- Boss-typed rounds in every other stage), which vanilla's own call sites
-- never anticipated. Caught live: Stage 1 Round 2 (PvE, should show Small
-- Blind/100... 200 chips) instead showed a real Boss card ("The Head") --
-- because Small was left stuck at 'Defeated' from Round 1, nothing re-armed
-- it, and functions/UI_definitions.lua's own create_UIBox_blind_select()
-- recomputes `blind_on_deck` itself every time it builds the screen (Small
-- Defeated -> check Big -> Big Hide -> falls through to Boss), independent of
-- whatever reset_blinds() last set. Fixed by extracting this whole
-- resolve-and-stamp block into TFT.apply_current_round_blind_state(), called
-- from BOTH reset_blinds() (still correct/needed for run-start and the real
-- Boss-defeat case) AND directly from the create_UIBox_blind_select() hook
-- (objects/round_flow/blind_select.lua), immediately before it calls
-- vanilla's real builder -- so the exact right slot is freshly re-armed on
-- every single render of that screen, regardless of whether reset_blinds()
-- happened to run first. Also dropped the old "preserve Defeated" branch on
-- the active slot: with the round already advanced by the time this runs,
-- there is never a case where re-arming the CURRENT round's slot back to
-- 'Select' is wrong -- that branch was the actual bug (it was written for a
-- vanilla-style one-shot-per-slot-per-ante model our reused-slot design
-- doesn't fit).
function TFT.apply_current_round_blind_state()
	if not TFT.is_run_active() then return end

	local round_def = TFT.current_round_def()
	local slot_type = 'Boss'
	if round_def then
		G.GAME.round_resets.ante = round_def.stage
		-- Keeps functions/UI_definitions.lua's create_UIBox_blind_choice
		-- reading the right Ante for its OWN internal get_blind_amount()
		-- call -- doesn't by itself fix the displayed chip amount (that
		-- still needs blind_select.lua's ante_scaling correction, since
		-- vanilla's Ante-curve number is never actually our chip_target),
		-- but keeps blind_ante from free-floating stale for stages this
		-- round's slot type never happens to trigger the vanilla Boss-
		-- Defeated resync branch on (i.e. PvE-slotted rounds).
		G.GAME.round_resets.blind_ante = round_def.stage
		if round_def.round_type ~= TFT.RoundType.CAROUSEL then
			TFT.ensure_stage_blinds_rolled(round_def.stage)
			local state = TFT.get_state()
			local assignment = state.stage_blind_assignments[round_def.stage][round_def.round_in_stage]
			if assignment then
				slot_type = assignment.slot_type
				G.GAME.round_resets.blind_choices[slot_type] = assignment.key
			end
		end
	end

	for _, t in ipairs({ 'Small', 'Big', 'Boss' }) do
		G.GAME.round_resets.blind_states[t] = (t == slot_type) and 'Select' or 'Hide'
	end
	G.GAME.blind_on_deck = slot_type
end

local _tft_orig_reset_blinds = reset_blinds
function reset_blinds()
	_tft_orig_reset_blinds()
	TFT.apply_current_round_blind_state()
end

-- 3. Blind chip requirement: override with our own per-round chip_target,
-- ignoring vanilla's Ante-based curve/self.mult entirely -- see
-- domain/stage_layout.lua's TFT.get_chip_target. Only applies on a real blind
-- assignment (mirrors vanilla's own `if not reset then ... end` gate around this
-- same block in blind.lua), and only for scoring rounds (Carousel rounds have no
-- chip_target and are handled as their own thing in poll.lua, not as a Blind at
-- all).
local _tft_orig_set_blind = Blind.set_blind
function Blind:set_blind(blind, reset, silent)
	_tft_orig_set_blind(self, blind, reset, silent)
	if reset or not TFT.is_run_active() then return end

	local round_def = TFT.current_round_def()
	if round_def and round_def.chip_target then
		self.chips = round_def.chip_target
		self.chip_text = number_format(self.chips)
	end
end

-- 4. Suppress vanilla's automatic win_game() -- with Ante pinned to the current
-- stage for that stage's full 7 rounds, vanilla's own win check (Ante == win_ante
-- and a Boss just cleared) would otherwise fire on the FIRST round of Stage 7,
-- not the last. Only let the real win_game() proceed once our own round_index
-- has actually reached the last round of the whole sequence. Mirrors
-- BalatroMultiplayerSpeedrun's own documented reason for suppressing this same
-- global (see technical.md).
local _tft_orig_win_game = win_game
function win_game(...)
	if TFT.is_run_active() then
		local state = TFT.get_state()
		local sequence = TFT.ensure_sequence()
		if state and sequence and state.round_index < #sequence then
			return -- not really done yet, just the end of a mid-stage round
		end
	end
	return _tft_orig_win_game(...)
end

-- 5. Closes the gap flagged in objects/actions/round_result.lua: real
-- multiplayer PvP rounds must NOT end the run just because the player missed
-- the chip target -- per architecture.md, that should cost life via the
-- damage formula (objects/actions/round_result.lua resolves that once both
-- players' scores are in), not trigger vanilla's own GAME_OVER outright.
--
-- Real mechanism (state_events.lua's end_round()): `game_over` starts true,
-- and is cleared only if `G.GAME.chips - G.GAME.blind.chips >= 0`. There's no
-- separate hookable "did you clear it" function to intercept -- that
-- comparison happens inline inside end_round() itself. Rather than
-- reimplementing end_round()'s considerable surrounding logic (joker
-- end-of-round saves, high-score tracking, game_won detection) just to change
-- one comparison, this temporarily lowers `G.GAME.blind.chips` to 0 (never
-- negative) immediately before calling the real end_round(), guaranteeing
-- `chips - 0 >= 0` so game_over resolves false -- then restores the real
-- value right after. The player's TRUE score (G.GAME.chips) is never touched,
-- so poll.lua's round_result broadcast (which reads G.GAME.chips directly)
-- still reports what they actually scored; only the pass/fail gate is bent.
-- A normal win (already >= target) is unaffected -- forcing the bar to 0 when
-- you'd already cleared the real one changes nothing.
local _tft_orig_end_round = end_round
function end_round()
	local round_def = TFT.is_run_active() and TFT.current_round_def()
	local is_real_pvp_round = round_def
		and TFT.get_state().is_multiplayer
		and round_def.round_type == TFT.RoundType.PVP

	if not is_real_pvp_round then
		return _tft_orig_end_round()
	end

	local real_target = G.GAME.blind.chips
	G.GAME.blind.chips = 0
	local result = _tft_orig_end_round()
	-- Restored via an immediate event rather than right here -- end_round()
	-- itself queues its OWN delayed event (0.2s) that reads blind.chips at
	-- that later time, not synchronously, so restoring instantly would race it.
	G.E_MANAGER:add_event(Event({
		trigger = 'after',
		delay = 0.3,
		func = function()
			G.GAME.blind.chips = real_target
			return true
		end,
	}))
	return result
end
