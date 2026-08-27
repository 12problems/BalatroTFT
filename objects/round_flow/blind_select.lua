-- Replaces the earlier popup-overlay-based stage roadmap (which sat ON TOP of
-- vanilla's own blind-select screen, duplicating it -- caught live via
-- screenshot, 2026-08-25 session correction #1) with a compact strip PREPENDED
-- directly into vanilla's real screen construction.
--
-- Deliberately does NOT rebuild the interactive blind card itself: vanilla's
-- create_UIBox_blind_select() has a real side effect this depends on --
-- G.blind_select_opts.small/big/boss, which button_callbacks.lua's actual
-- select_blind click handler reads directly (`G.blind_select_opts[string.lower
-- (e.config.id)]`). Rebuilding that card ourselves would mean either
-- reimplementing correct click handling from scratch or risking it silently
-- not working. Instead: call vanilla's real function (gets a correctly-sized,
-- correctly-clickable single card for whichever slot is actually active --
-- Small for PvE-based rounds, Boss for PvP-based, per hooks.lua's
-- TFT.slot_type_for_round), then prepend our own compact roadmap row above it.
-- Vanilla's create_UIBox_blind_choice calls create_UIBox_blind_tag() for
-- Small/Big slot types UNCONDITIONALLY (independent of blind_states) -- that's
-- what renders the Skip Blind button. Since PvE-based rounds now use the Small
-- slot (to avoid a boss ability, per session correction #2), that would have
-- silently reintroduced a skip option -- caught live via screenshot, directly
-- contradicting "blinds should not offer skip tags". Suppressed outright
-- whenever a TFT run is active, regardless of slot type.
local _tft_orig_create_UIBox_blind_tag = create_UIBox_blind_tag
function create_UIBox_blind_tag(blind_choice, run_info)
	if TFT.is_run_active() then return nil end
	return _tft_orig_create_UIBox_blind_tag(blind_choice, run_info)
end

local _tft_orig_create_UIBox_blind_select = create_UIBox_blind_select
function create_UIBox_blind_select()
	-- Re-arms the correct slot (Small/Boss) fresh on every render of this
	-- screen -- see hooks.lua's TFT.apply_current_round_blind_state doc
	-- comment for why this can't just rely on reset_blinds() having already
	-- run: vanilla only calls that at run-start or after a real Boss defeat,
	-- never between two same-slot-type rounds (e.g. Stage 1's 3 PvE rounds),
	-- and vanilla's OWN builder below recomputes blind_on_deck from whatever
	-- blind_states was last left at, independent of our chip/round logic.
	TFT.apply_current_round_blind_state()
	local vanilla_tree = _tft_orig_create_UIBox_blind_select()
	-- The roadmap row used to be prepended directly onto this screen -- per
	-- explicit user feedback on a live screenshot (2026-08-26), "the stage UI
	-- gets covered by the blinds a little" -- it's now relocated to the
	-- persistent HUD's Ante box instead (objects/round_flow/hud.lua), which is
	-- never crowded by a blind card. No longer duplicated here.
	return vanilla_tree
end

-- CORRECTED via live 2-instance PvP test, 2026-08-25: the blind-select card's
-- displayed "Score at least N" number is NOT read from the real Blind object
-- at all on this screen (that only gets set correctly by our Blind:set_blind
-- hook once the blind is actually SELECTED) -- functions/UI_definitions.lua's
-- create_UIBox_blind_choice(type, run_info) computes it independently, at
-- build time, as a plain static text node:
--   get_blind_amount(G.GAME.round_resets.blind_ante) * blind_choice.config.mult
--   * G.GAME.starting_params.ante_scaling
-- entirely from vanilla's own Ante-N curve, never touching our chip_target.
-- Caught live: Stage 1 Round 1 (chip_target=100) displayed "Score at least
-- 300" -- vanilla's real Ante-1 Small Blind amount. Worse than just "wrong
-- number": `round_resets.blind_ante` itself only gets resynced to the current
-- `ante` by a real vanilla click handler gated on `blind_states.Boss ==
-- 'Defeated'` (button_callbacks.lua) -- which never fires for our PvE-slotted
-- rounds (they use 'Small', not 'Boss') -- so for Stage 1's 3 PvE rounds in
-- particular, blind_ante stays frozen at its game.lua initial default (1) for
-- literally the whole stage, showing the same stale number on all 3 rounds
-- regardless of each one's real, different target.
--
-- Fixed the least invasive way: temporarily scale
-- G.GAME.starting_params.ante_scaling so vanilla's own formula multiplies out
-- to exactly our real chip_target, then restore it immediately after --
-- reuses vanilla's real render code (correct font/scale/localization/`$`
-- reward line) rather than reaching into the returned node tree to
-- string-replace a number. Only applies to the primary (run_info=false)
-- preview -- that's the actual "which blind am I about to fight" screen the
-- user is looking at. run_info=true (the pause-menu run-info overview, which
-- previews Small/Big/Boss simultaneously) is NOT corrected: multiple PvP
-- rounds in a stage all share the 'Boss' slot type, so there's no single
-- unambiguous round to attribute that number to -- flagged as a known,
-- deliberately out-of-scope gap on that secondary surface, not silently
-- glossed over.
local _tft_orig_create_UIBox_blind_choice = create_UIBox_blind_choice
function create_UIBox_blind_choice(type, run_info)
	if run_info or not TFT.is_run_active() then
		return _tft_orig_create_UIBox_blind_choice(type, run_info)
	end

	local round_def = TFT.current_round_def()
	if not round_def or not round_def.chip_target or round_def.round_type == TFT.RoundType.CAROUSEL then
		return _tft_orig_create_UIBox_blind_choice(type, run_info)
	end

	local center = G.P_BLINDS[G.GAME.round_resets.blind_choices[type]]
	local blind_ante = G.GAME.round_resets.blind_ante or G.GAME.round_resets.ante
	local vanilla_base = center and get_blind_amount(blind_ante) * center.mult

	local saved_scaling = G.GAME.starting_params.ante_scaling
	if vanilla_base and vanilla_base > 0 then
		G.GAME.starting_params.ante_scaling = round_def.chip_target / vanilla_base
	end
	local node = _tft_orig_create_UIBox_blind_choice(type, run_info)
	G.GAME.starting_params.ante_scaling = saved_scaling
	return node
end

local STATUS_COLOUR = { cleared = G.C.GREEN, current = G.C.GOLD, upcoming = G.C.UI.BACKGROUND_INACTIVE }

-- One compact pip per round in the current stage -- round number, coloured by
-- status, with the [A] marker for checkpoint rounds. No blind name/description
-- here (that's what the single real card below it is for) -- keeping this row
-- small is the direct fix for "the window on screen is far too big".
function TFT.build_stage_roadmap_row()
	local state = TFT.get_state()
	local sequence = TFT.ensure_sequence()
	if not state or not sequence then return nil end
	local current = sequence[state.round_index]
	if not current then return nil end

	local pips = {}
	for _, round_def in ipairs(sequence) do
		if round_def.stage == current.stage then
			local status = (round_def.round_index < state.round_index) and 'cleared'
				or (round_def.round_index == state.round_index) and 'current'
				or 'upcoming'
			local label = (round_def.round_type == TFT.RoundType.CAROUSEL) and 'C' or tostring(round_def.round_in_stage)
			table.insert(pips, {
				n = G.UIT.C, config = { align = 'cm', minw = 0.5, minh = 0.5, r = 0.5, colour = STATUS_COLOUR[status], padding = 0.04, outline = status == 'current' and 2 or 0, outline_colour = G.C.WHITE },
				nodes = {
					{ n = G.UIT.T, config = { text = label, scale = 0.3, colour = G.C.WHITE } },
				},
			})
			if round_def.is_checkpoint then
				table.insert(pips, { n = G.UIT.T, config = { text = 'A', scale = 0.25, colour = G.C.GOLD } })
			end
		end
	end

	return {
		n = G.UIT.R, config = { align = 'cm', padding = 0.05, minw = 3 },
		nodes = {
			{ n = G.UIT.T, config = { text = 'Stage ' .. current.stage .. ':  ', scale = 0.28, colour = G.C.UI.TEXT_LIGHT } },
			{ n = G.UIT.R, config = { align = 'cm' }, nodes = pips },
		},
	}
end
