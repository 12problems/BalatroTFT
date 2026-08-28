-- Persistent left-side HUD relocation, per the user's explicit screenshot
-- feedback (2026-08-26): the "Stage N: [pips]" roadmap row (blind_select.lua's
-- TFT.build_stage_roadmap_row, previously prepended above the blind-select
-- card) got visually crowded by the blind card next to it. Moved here into the
-- persistent HUD's own Ante box instead -- vanilla's Ante number is redundant
-- with our own stage-pinned Ante anyway (hooks.lua's TFT.apply_current_round_
-- blind_state already forces G.GAME.round_resets.ante to match our stage) --
-- and the roadmap now lives somewhere it's never covered by a card. The Round
-- box is replaced with a round-elapsed timer, matching the visual convention
-- BalatroMultiplayerSpeedrun's own ui/timer/ uses for its run clock (the
-- `string.format('%d:%05.2f', minutes, rem)` -- m:ss.mm -- convention from
-- that mod's format.lua, referenced for the TEXT FORMAT/style consistency the
-- user asked for, not its floating-standalone-box approach: ours replaces an
-- EXISTING HUD box in place, splicing into vanilla's own create_UIBox_HUD()
-- definition tree rather than building a second overlapping UIBox).
--
-- Also adds the still-missing Life Total display (next-session-plan.md
-- priority #1's actual headline ask) as a new row appended below the
-- Ante/Round row, showing both the local player's life and -- when currently
-- paired for a live PvP round -- the opponent's last-known life total.
--
-- ASSUMPTIONS (flagged, not confirmed with you):
--  1. Per next-session-plan.md's own open question #1: this is a VISUAL-ONLY
--     elapsed-time stopwatch, NOT a real ready-up/advance-early sync -- no
--     gameplay effect, resets to 0:00.00 at the start of every real round.
--     Building the full ready-up system is a materially bigger scope than
--     "replace one HUD box" and wasn't itself named a priority this pass.
--  2. Opponent life total defaults to display as TFT.STARTING_LIFE (100)
--     until a real tft_life_total_change broadcast is actually received for
--     that specific opponent -- nobody's true life is ever anything other
--     than 100 before their first PvP loss, so this is an accurate default,
--     not a guess.

-- m:ss.mm, mirroring BalatroMultiplayerSpeedrun/ui/timer/format.lua's own
-- convention so this reads consistently with other multiplayer Balatro mods.
function TFT.format_round_timer(secs)
	if not secs or secs < 0 then secs = 0 end
	local minutes = math.floor(secs / 60)
	local rem = secs - minutes * 60
	return string.format('%d:%05.2f', minutes, rem)
end

-- Plain fields on TFT itself (not G.GAME.tft_state) -- these are purely
-- cosmetic per-frame display strings, refreshed every frame from
-- TFT.round_flow_poll (see poll.lua), not real run state that needs to
-- survive a save/load the way state.life_total etc. do. DynaText's
-- {ref_table, ref_value} binding just needs a STABLE table reference to poll
-- every frame -- TFT (SMODS.current_mod) is that, for the life of the process.
TFT.round_timer_text = TFT.round_timer_text or '0:00.00'
TFT.hud_life_text = TFT.hud_life_text or ('Life ' .. TFT.STARTING_LIFE)
TFT.hud_opponent_life_text = TFT.hud_opponent_life_text or ''
-- Early Warning augment display (closes next-session-plan-3.md priority
-- #1.2 -- previously a complete no-op with a comment claiming otherwise).
-- Empty string renders as a zero-height text row, so this row is always
-- present in the HUD tree (built once per run) but only ever shows real
-- text once the augment is actually picked and a live PvP pairing exists --
-- avoids needing to rebuild the HUD tree mid-run when the augment is
-- acquired at a later checkpoint than run start.
TFT.hud_early_warning_text = TFT.hud_early_warning_text or ''
-- Level/XP display (next-session-plan-4.md item 1) -- attached directly to
-- G.deck (see TFT.attach_deck_level_display below) rather than spliced into
-- create_UIBox_HUD's left-side panel tree, per explicit instruction that this
-- belongs near the always-visible deck sprite instead.
TFT.hud_level_text = TFT.hud_level_text or 'Lv. 1'
-- Live in-overlay countdown text (full timer functionality, 2026-08-28) --
-- refreshed every frame below, bound via ui/picker.lua's `timer_ref` support.
TFT.checkpoint_timer_text = TFT.checkpoint_timer_text or ''
TFT.carousel_timer_text = TFT.carousel_timer_text or ''

-- Timer enable/disable (next-session-plan-4.md item 5): full real
-- functionality as of 2026-08-28 (domain/round_timers.lua) -- for a real
-- PvE/PvP hand-playing round this now counts DOWN from a real per-stage
-- budget and really enforces it (TFT.round_flow_poll forces the round to
-- end once it hits zero); "disabled" (the lobby's Round Timer setting)
-- turns enforcement off entirely, not just the display, same as before.
-- Round types with no hand-playing budget (Carousel, or single-player where
-- state.is_multiplayer is false -- the design doc's own timers are all
-- multiplayer-lobby concepts) fall back to the original cosmetic count-UP
-- stopwatch, unchanged.
function TFT.restart_round_timer()
	local state = TFT.get_state()
	if not state then return end
	state.round_timed_out_for_index = nil
	if state.timer_enabled == false then
		state.round_started_at = nil
		state.round_deadline_at = nil
		TFT.round_timer_text = 'Timer Off'
		return
	end
	local round_def = TFT.current_round_def()
	local budget = state.is_multiplayer and round_def
		and (round_def.round_type == TFT.RoundType.PVE or round_def.round_type == TFT.RoundType.PVP)
		and TFT.hand_playing_timer_seconds(round_def.stage)
	state.round_started_at = love.timer.getTime()
	state.round_deadline_at = budget and (state.round_started_at + budget) or nil
	TFT.round_timer_text = TFT.format_round_timer(budget or 0)
end

-- Called every frame from TFT.round_flow_poll.
function TFT.update_hud_display_texts()
	if not TFT.is_run_active() then return end
	local state = TFT.get_state()
	if not state then return end

	if state.shop_deadline_at then
		-- Shop's own real timer (domain/round_timers.lua) takes over the same
		-- HUD element while browsing -- there's no "round" running to time.
		TFT.round_timer_text = TFT.format_round_timer(math.max(0, state.shop_deadline_at - love.timer.getTime()))
	elseif state.round_deadline_at then
		TFT.round_timer_text = TFT.format_round_timer(math.max(0, state.round_deadline_at - love.timer.getTime()))
	elseif state.round_started_at then
		TFT.round_timer_text = TFT.format_round_timer(love.timer.getTime() - state.round_started_at)
	end

	-- Live in-overlay countdowns (full timer functionality, 2026-08-28) --
	-- see ui/picker.lua's `timer_ref` support for how these actually render.
	if state.pending_augment_offer and state.pending_augment_offer.deadline_at then
		TFT.checkpoint_timer_text = TFT.format_round_timer(
			math.max(0, state.pending_augment_offer.deadline_at - love.timer.getTime()))
	end
	if state.carousel_draft and state.carousel_draft.turn_started_at then
		local remaining = TFT.CAROUSEL_TURN_TIMER_SECONDS - (love.timer.getTime() - state.carousel_draft.turn_started_at)
		TFT.carousel_timer_text = TFT.format_round_timer(math.max(0, remaining))
	end

	TFT.hud_life_text = 'Life ' .. math.floor((state.life_total or TFT.STARTING_LIFE) + 0.5)

	local opp_text = ''
	if state.current_pairing then
		local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
		local my_id = lobby and lobby.player_id
		local opponent_id = my_id and TFT.find_pvp_opponent(state.current_pairing, my_id)
		if opponent_id then
			local opp_life = TFT._opponent_life_totals and TFT._opponent_life_totals[opponent_id]
			opp_text = 'Opp ' .. math.floor((opp_life or TFT.STARTING_LIFE) + 0.5)
		end
	end
	TFT.hud_opponent_life_text = opp_text

	local ew_text = ''
	if TFT.has_augment and TFT.has_augment('early_warning') and state.current_pairing then
		local ok, upcoming = pcall(TFT.upcoming_pvp_opponents, 2)
		if ok and upcoming and #upcoming > 0 then
			local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
			local parts = {}
			for i, opp_id in ipairs(upcoming) do
				if opp_id == 'ghost' then
					parts[i] = 'Ghost'
				else
					local p = lobby and lobby._players and lobby._players[opp_id]
					parts[i] = (p and p.displayName) or opp_id
				end
			end
			ew_text = 'Next: ' .. table.concat(parts, ', ')
		end
	end
	TFT.hud_early_warning_text = ew_text

	-- "Just Lv. X with a fraction showing the progress they have to that
	-- level" -- explicit instruction. TFT.level_for_xp already returns
	-- (level, into_next, needed_for_next); at the level cap needed_for_next
	-- is 0 (domain/xp_curve.lua), shown as a plain level with no fraction
	-- rather than a divide-by-zero-shaped "x/0".
	local level, into_next, needed_for_next = TFT.level_for_xp(state.xp or 0)
	if needed_for_next and needed_for_next > 0 then
		TFT.hud_level_text = 'Lv. ' .. level .. '  ' .. into_next .. '/' .. needed_for_next .. ' XP'
	else
		TFT.hud_level_text = 'Lv. ' .. level .. ' (MAX)'
	end
end

-- Same pip-per-round strip as blind_select.lua's own TFT.build_stage_roadmap_
-- row, but laid out to fit the persistent HUD's narrow Ante-box column (a
-- "Stage N" label row on top, a row of small pips below -- mirrors the Ante
-- box's own two-row shape) rather than that function's single wide row meant
-- to sit above a full-size blind card. Deliberately a SEPARATE function, not a
-- reuse of build_stage_roadmap_row, since the two call sites need genuinely
-- different sizing.
local STATUS_COLOUR = { cleared = G.C.GREEN, current = G.C.GOLD, upcoming = G.C.UI.BACKGROUND_INACTIVE }

function TFT.build_hud_stage_nodes()
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
				n = G.UIT.C, config = { align = 'cm', minw = 0.28, minh = 0.28, r = 0.5, colour = STATUS_COLOUR[status], padding = 0.02, outline = status == 'current' and 1 or 0, outline_colour = G.C.WHITE },
				nodes = {
					{ n = G.UIT.T, config = { text = label, scale = 0.18, colour = G.C.WHITE } },
				},
			})
			if round_def.is_checkpoint then
				table.insert(pips, { n = G.UIT.T, config = { text = 'A', scale = 0.15, colour = G.C.GOLD } })
			end
		end
	end

	return {
		{ n = G.UIT.R, config = { align = 'cm', minh = 0.33, maxw = 1.35 }, nodes = {
			{ n = G.UIT.T, config = { text = 'Stage ' .. current.stage, scale = 0.85 * 0.4, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
		}},
		{ n = G.UIT.R, config = { align = 'cm', r = 0.1, minw = 1.2, padding = 0.03 }, nodes = pips },
	}
end

function TFT.build_hud_timer_object_node()
	return { n = G.UIT.O, config = { id = 'tft_round_timer_UI', object = DynaText({ string = { { ref_table = TFT, ref_value = 'round_timer_text' } }, colours = { G.C.IMPORTANT }, shadow = true, font = G.LANGUAGES['en-us'].font, scale = 2 * 0.4 }) } }
end

function TFT.build_hud_life_spacer_row()
	return { n = G.UIT.R, config = { minh = 0.13 }, nodes = {} }
end

function TFT.build_hud_life_row()
	local scale = 0.4
	return {
		n = G.UIT.R, config = { align = 'cm' }, nodes = {
			{ n = G.UIT.C, config = { align = 'cm', padding = 0.05, minw = 1.45, minh = 0.5, colour = G.C.DYN_UI.BOSS_DARK, emboss = 0.05, r = 0.1 }, nodes = {
				{ n = G.UIT.O, config = { object = DynaText({ string = { { ref_table = TFT, ref_value = 'hud_life_text' } }, colours = { G.C.RED }, shadow = true, font = G.LANGUAGES['en-us'].font, scale = 1.1 * scale }) } },
			}},
			{ n = G.UIT.C, config = { minw = 0.13 }, nodes = {} },
			{ n = G.UIT.C, config = { align = 'cm', padding = 0.05, minw = 1.45, minh = 0.5, colour = G.C.DYN_UI.BOSS_DARK, emboss = 0.05, r = 0.1 }, nodes = {
				{ n = G.UIT.O, config = { object = DynaText({ string = { { ref_table = TFT, ref_value = 'hud_opponent_life_text' } }, colours = { G.C.BLUE }, shadow = true, font = G.LANGUAGES['en-us'].font, scale = 1.1 * scale }) } },
			}},
		},
	}
end

-- Single wide row for the Early Warning augment's opponent-lookahead text --
-- see TFT.hud_early_warning_text above for why this is always present but
-- usually empty.
function TFT.build_hud_early_warning_row()
	local scale = 0.35
	return {
		n = G.UIT.R, config = { align = 'cm' }, nodes = {
			{ n = G.UIT.O, config = { object = DynaText({ string = { { ref_table = TFT, ref_value = 'hud_early_warning_text' } }, colours = { G.C.UI.TEXT_LIGHT }, shadow = true, font = G.LANGUAGES['en-us'].font, scale = scale }) } },
		},
	}
end

-- Attaches the Level/XP text directly above the real G.deck CardArea object,
-- the same "float a UIBox as a child of a real Moveable" technique vanilla's
-- own Card:redeem() uses for its "Voucher / Redeemed!" popup text (card.lua,
-- `self.children.top_disp = UIBox{..., config = {align = 'tm', parent =
-- self}}`) -- rather than hunting for a nonexistent "deck sprite UI builder"
-- to hook the way every other HUD element this project has added does
-- (grepped the real installed source for one; the deck's own "52/52" count
-- render isn't built through any create_UIBox_* function at all, so there's
-- nothing to splice into). `align = 'tm'` positions above the parent's own
-- top edge, matching top_disp's exact convention.
--
-- CAUGHT live: attaching to `self.children` alone isn't enough for a
-- CardArea the way it is for a Card -- confirmed by reading the real
-- installed cardarea.lua's own CardArea:draw(): it only ever calls
-- `self.children.area_uibox:draw()` (that ONE specific, hardcoded name, its
-- own card-count display), never a generic loop over every entry in
-- `self.children`. A plain child attach was silently invisible on a real
-- screenshot (never drawn) before this fix. Card:draw() (a different class)
-- DOES loop its own children generically, which is what makes top_disp/
-- bot_disp above actually work there -- the two classes aren't consistent
-- with each other here. Fixed below by hooking CardArea:draw itself to
-- explicitly draw this one extra child for G.deck specifically, the same
-- "hook the real render function" pattern this project already uses
-- elsewhere rather than fighting a per-type internal convention.
--
-- Called once per run, from round_flow/poll.lua once G.deck actually exists
-- (deferred the same way TFT.ensure_traits_engine_joker is -- attaching
-- inside Game:start_run itself hung the game once already this project,
-- hooks.lua's own comment on that exact mistake).
function TFT.attach_deck_level_display()
	if not G.deck or G.deck.children.tft_level_display then return end
	G.deck.children.tft_level_display = UIBox{
		definition = { n = G.UIT.ROOT, config = { align = 'cm', colour = G.C.CLEAR, padding = 0.1 }, nodes = {
			{ n = G.UIT.O, config = { object = DynaText({ string = { { ref_table = TFT, ref_value = 'hud_level_text' } }, colours = { G.C.GOLD }, shadow = true, font = G.LANGUAGES['en-us'].font, scale = 0.5 }) } },
		} },
		config = { align = 'tm', offset = { x = 0, y = -0.3 }, parent = G.deck },
	}
end

local _tft_orig_cardarea_draw = CardArea.draw
function CardArea:draw()
	_tft_orig_cardarea_draw(self)
	if self == G.deck and self.children.tft_level_display then
		self.children.tft_level_display:draw()
	end
end

-- Plain recursive search over a create_UIBox_HUD-style NODE-DEFINITION tree
-- (the raw {n=..., config=..., nodes=...} tables returned before UIBox:init
-- turns them into live UIElements) -- distinct from (and much simpler than)
-- UIBox:get_UIE_by_ID, which only works on an already-built live tree. Returns
-- the matched node and its immediate parent node (so callers needing a
-- sibling, e.g. the label row above a value row, don't need a second pass).
function TFT.find_hud_def_node(node, id, parent)
	if type(node) ~= 'table' then return nil end
	if node.config and node.config.id == id then return node, parent end
	if node.nodes then
		for _, child in ipairs(node.nodes) do
			local found, found_parent = TFT.find_hud_def_node(child, id, node)
			if found then return found, found_parent end
		end
	end
	return nil
end

-- CAUGHT before this ever ran live, by tracing real call sites rather than
-- assuming: functions/state_events.lua's real end-of-round code calls
-- ease_ante(1) unconditionally whenever `G.GAME.blind:get_type() == 'Boss'`
-- -- and EVERY TFT PvP-slotted round uses the Boss blind slot (hooks.lua's
-- TFT.slot_type_for_round), so this is a normal, frequently-hit vanilla path
-- during ordinary play, not a rare edge case. ease_ante/ease_round
-- (functions/common_events.lua) both read a cached element off
-- G.hand_text_area.ante/.round (set once at HUD-build time, game.lua) and
-- call `.config.object:update()` / use `.parent` for a popup -- both of which
-- point at the exact 'ante_UI_count'/'round_UI_count' nodes this file's
-- create_UIBox_HUD hook below removes from the tree entirely. Left alone,
-- the very first real Boss-blind clear of any TFT run would crash inside
-- vanilla's own ease_ante. Fixed by hooking both functions to skip the
-- now-meaningless UI/sound/popup work during a TFT run (that popup would
-- animate over our stage roadmap/timer content anyway, which would be
-- actively wrong even if it didn't crash) while still applying the real
-- state mutation + high-score bookkeeping other systems may still read
-- (TFT.apply_current_round_blind_state stomps the actual Ante NUMBER back to
-- our stage moments later regardless, but furthest_ante/furthest_round are
-- real vanilla unlock-progression stats worth keeping accurate).
local _tft_orig_ease_ante = ease_ante
function ease_ante(mod)
	if not TFT.is_run_active() then return _tft_orig_ease_ante(mod) end
	G.E_MANAGER:add_event(Event({
		trigger = 'immediate',
		func = function()
			G.GAME.round_resets.ante = G.GAME.round_resets.ante + (mod or 0)
			check_and_set_high_score('furthest_ante', G.GAME.round_resets.ante)
			return true
		end,
	}))
end

local _tft_orig_ease_round = ease_round
function ease_round(mod)
	if not TFT.is_run_active() then return _tft_orig_ease_round(mod) end
	G.E_MANAGER:add_event(Event({
		trigger = 'immediate',
		func = function()
			G.GAME.round = G.GAME.round + (mod or 0)
			check_and_set_high_score('furthest_round', G.GAME.round)
			check_and_set_high_score('furthest_ante', G.GAME.round_resets.ante)
			return true
		end,
	}))
end

-- Splices all of the above into vanilla's real create_UIBox_HUD() -- verified
-- against the actual installed Mods/lovely/dump/functions/UI_definitions.lua
-- (~line 1482): the Ante column carries a stable id='hud_ante', the Round
-- box's value row carries id='row_round_text', and the outer row containing
-- both carries id='row_round'. Deliberately NOT gated on TFT.is_run_active():
-- create_UIBox_HUD() has exactly one real call site anywhere in the installed
-- mod set (Game:start_run, confirmed via a full-Mods-folder grep), which fires
-- WHILE vanilla's own start_run body is still running -- i.e. BEFORE hooks.lua's
-- own post-processing sets state.initialized = true. Gating on is_run_active()
-- here would silently skip customizing the very first HUD build of every run
-- (caught by tracing the actual call order, not live -- flagging the
-- reasoning since it's the kind of gap that only shows up by reading real
-- call order, same category of mistake as this session's find_joker/SMODS.
-- showman lesson). core.lua's own documented assumption ("every run started
-- while this mod is loaded becomes a TFT run unconditionally") makes this
-- safe: there is no other kind of run for this HUD to be wrong about.
local _tft_orig_create_UIBox_HUD = create_UIBox_HUD
function create_UIBox_HUD()
	local tree = _tft_orig_create_UIBox_HUD()

	local ok, err = pcall(function()
		local ante_col = TFT.find_hud_def_node(tree, 'hud_ante')
		if ante_col then
			ante_col.nodes = TFT.build_hud_stage_nodes() or ante_col.nodes
		end

		local timer_row, timer_col = TFT.find_hud_def_node(tree, 'row_round_text')
		if timer_row then
			timer_row.config.id = nil -- no longer vanilla's round box; avoid a stale get_UIE_by_ID('row_round_text') match later
			timer_row.nodes = { TFT.build_hud_timer_object_node() }
			local label_row = timer_col and timer_col.nodes and timer_col.nodes[1]
			local label_text_node = label_row and label_row.nodes and label_row.nodes[1]
			if label_text_node and label_text_node.config then
				label_text_node.config.text = 'Timer'
			end
		end

		local row_round = TFT.find_hud_def_node(tree, 'row_round')
		local round_col
		if row_round and row_round.nodes then
			for _, col in ipairs(row_round.nodes) do
				if TFT.find_hud_def_node(col, 'hud_ante') then
					round_col = col
					break
				end
			end
		end
		if round_col and round_col.nodes then
			table.insert(round_col.nodes, TFT.build_hud_life_spacer_row())
			table.insert(round_col.nodes, TFT.build_hud_life_row())
			table.insert(round_col.nodes, TFT.build_hud_early_warning_row())
		end
	end)
	if not ok then TFT.sendWarnMessage('HUD relocation failed: ' .. tostring(err)) end

	return tree
end

-- The stage roadmap's pip colours (cleared/current/upcoming) depend on
-- state.round_index, but G.HUD is a real, persistent UIBox built ONCE per run
-- (game.lua's Game:start_run) -- other code (G.hand_text_area) caches direct
-- references INTO that same box's other elements (hand_chips/hand_mult/etc,
-- read every frame by vanilla's own score-popup juice code), so rebuilding
-- the WHOLE box on every round transition would silently invalidate those
-- cached refs. Instead this only ever touches the one node this mod owns,
-- using the same add_child/remove-then-rebuild primitive JokerDisplay's own
-- JokerDisplayBox:remove_children/add_child (Mods/JokerDisplay/src/ui.lua)
-- already uses to live-update a card's display after it's built -- itself
-- just vanilla's real UIBox:add_child (engine/ui.lua), which calls
-- set_parent_child (the same recursive node-def-to-UIElement builder
-- UIBox:init uses at construction time) then a full self:recalculate().
function TFT.refresh_hud_stage_display()
	if not TFT.is_run_active() or not G.HUD then return end
	local node = G.HUD:get_UIE_by_ID('hud_ante')
	if not node then return end
	local ok, defs = pcall(TFT.build_hud_stage_nodes)
	if not ok or not defs then return end

	if node.children and #node.children > 0 then
		remove_all(node.children)
		node.children = {}
	end
	for _, def in ipairs(defs) do
		G.HUD:add_child(def, node)
	end
end
