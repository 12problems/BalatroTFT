-- Shows every round of the CURRENT stage as one list (Stage 1: 3 rows, Stages
-- 2-7: 7 rows each), each rendered as the REAL blind it is (icon, name, real
-- description) rather than a placeholder label -- per the 2026-08-25 session
-- correction. Depends on hooks.lua's TFT.ensure_stage_bosses_rolled having
-- already pre-rolled real bosses for the whole stage, so what's shown here is
-- exactly what the player will actually fight, not a guess. Carousel rounds
-- have no boss, so they get a distinct, simpler row instead.
--
-- Underlying mechanism is otherwise unchanged: every round is still played in
-- full, in order, one at a time (Option A from the original blind_select_
-- redesign.md design -- real vanilla boss blinds under the hood, only the
-- front-end changes). This overlay is purely informational (Continue/ESC-
-- dismissible, NOT no_esc) since it makes no choice.
--
-- ASSUMPTION (flagged): shown automatically every round transition within a
-- stage (not just once per stage) -- the design doc's own open question
-- ("does the overlay need to persist/update across the whole stage or is a
-- one-shot popup acceptable") was never resolved before the data loss; picked
-- "every round, dismissible" as the more informative default.

local STATUS_COLOUR = { cleared = G.C.GREEN, current = G.C.GOLD, upcoming = G.C.GREY }
local STATUS_PREFIX = { cleared = '[x] ', current = '>> ', upcoming = '' }

local function blind_row_node(round_def, status, boss_key)
	local blind_conf = G.P_BLINDS[boss_key]
	local loc_name = blind_conf and localize({ type = 'name_text', key = boss_key, set = 'Blind' }) or 'Blind'
	local loc_desc = blind_conf and localize({
		type = 'raw_descriptions', key = boss_key, set = 'Blind',
		vars = { localize(G.GAME.current_round.most_played_poker_hand or 'High Card', 'poker_hands') },
	}) or {}

	local desc_nodes = {}
	for _, line in ipairs(loc_desc) do
		table.insert(desc_nodes, { n = G.UIT.R, config = { align = 'cm' }, nodes = {
			{ n = G.UIT.T, config = { text = line, scale = 0.28, colour = G.C.UI.TEXT_LIGHT } },
		} })
	end

	local chip_text = round_def.chip_target and ('Score at least ' .. number_format(round_def.chip_target)) or ''

	-- Built via table.insert rather than a literal-table `unpack(desc_nodes)`
	-- spread -- CORRECTED via live testing: Balatro runs on LuaJIT (Lua 5.1
	-- semantics), where `table.unpack` doesn't exist at all (that's a Lua 5.2+
	-- addition) -- the global `unpack` is the real one, but building the list
	-- imperatively sidesteps the whole global-vs-table.unpack ambiguity.
	local middle_nodes = {
		{ n = G.UIT.R, config = { align = 'cl' }, nodes = {
			{ n = G.UIT.T, config = { text = STATUS_PREFIX[status] .. 'Round ' .. round_def.round_in_stage .. ':', scale = 0.32, colour = STATUS_COLOUR[status] } },
			{ n = G.UIT.T, config = { text = ' ' .. loc_name, scale = 0.34, colour = G.C.WHITE } },
			round_def.is_checkpoint and { n = G.UIT.T, config = { text = '  [Augment]', scale = 0.3, colour = G.C.GOLD } } or nil,
		} },
	}
	for _, node in ipairs(desc_nodes) do
		table.insert(middle_nodes, node)
	end
	table.insert(middle_nodes, { n = G.UIT.R, config = { align = 'cl' }, nodes = {
		{ n = G.UIT.T, config = { text = chip_text, scale = 0.28, colour = G.C.UI.TEXT_LIGHT } },
	} })

	return {
		n = G.UIT.R, config = { align = 'cm', padding = 0.08, r = 0.1, colour = G.C.BLACK, outline = 1, outline_colour = STATUS_COLOUR[status], minw = 6.8 },
		nodes = {
			blind_conf and { n = G.UIT.C, config = { align = 'cm', minw = 1.1, padding = 0.05 }, nodes = {
				{ n = G.UIT.O, config = { object = AnimatedSprite(0, 0, 1, 1, G.ANIMATION_ATLAS['blind_chips'], blind_conf.pos) } },
			} } or { n = G.UIT.C, config = { minw = 0.1 }, nodes = {} },
			{ n = G.UIT.C, config = { align = 'cl', padding = 0.05, minw = 4.8 }, nodes = middle_nodes },
		},
	}
end

local function carousel_row_node(round_def, status)
	return {
		n = G.UIT.R, config = { align = 'cm', padding = 0.08, r = 0.1, colour = G.C.BLACK, outline = 1, outline_colour = STATUS_COLOUR[status], minw = 6.8, minh = 0.8 },
		nodes = {
			{ n = G.UIT.T, config = { text = STATUS_PREFIX[status] .. 'Round ' .. round_def.round_in_stage .. ': Carousel', scale = 0.34, colour = STATUS_COLOUR[status] } },
		},
	}
end

function TFT.render_stage_overview_overlay()
	local state = TFT.get_state()
	local sequence = TFT.ensure_sequence()
	if not state or not sequence then return end

	local current = sequence[state.round_index]
	if not current then return end

	TFT.ensure_stage_bosses_rolled(current.stage)
	local boss_assignments = state.stage_boss_assignments[current.stage] or {}

	local rows = {}
	for _, round_def in ipairs(sequence) do
		if round_def.stage == current.stage then
			local status = (round_def.round_index < state.round_index) and 'cleared'
				or (round_def.round_index == state.round_index) and 'current'
				or 'upcoming'
			local node
			if round_def.round_type == TFT.RoundType.CAROUSEL then
				node = carousel_row_node(round_def, status)
			else
				node = blind_row_node(round_def, status, boss_assignments[round_def.round_in_stage])
			end
			table.insert(rows, { custom_node = node })
		end
	end

	TFT.show_picker_overlay({
		title = 'Stage ' .. current.stage,
		subtitle = 'Round ' .. current.round_in_stage .. ' of ' .. #TFT.StageLayout[current.stage].rounds,
		subtitle_colour = G.C.UI.TEXT_LIGHT,
		rows = rows,
		footer_rows = { { label = { 'Continue' }, button = 'tft_close_stage_overview', colour = G.C.BLUE } },
		no_esc = false, -- informational only, not a choice -- ESC-dismissible
	})
end

G.FUNCS.tft_close_stage_overview = function()
	TFT.close_picker_overlay()
end
