-- Minimal real lobby flow -- create/join a private lobby, see the roster (via
-- MPAPI's own MPAPI.create_lobby_ui, reused as-is rather than reimplementing a
-- player-card grid), host starts the match. Deliberately skips SPDRN's ban-
-- pick/countdown/matchmaking ceremony entirely -- this session's bar is "a
-- multiplayer setup with 2 players is able to be tested", not full lobby UX
-- polish.
--
-- EXPANDED (next-session-plan-4.md item 5): host-configurable match settings
-- (deck/stake/bonus money/timer toggle), synced via MPAPI's real
-- lobby:set_metadata/get_metadata + metadata_changed event -- confirmed real,
-- existing, host-only mechanism (api/lobby/state.lua), no new networking
-- primitive needed. A typed text-input join field (create_text_input, a real
-- vanilla widget, confirmed via source read) now sits alongside the existing
-- one-click clipboard join, per explicit instruction to keep both.
TFT.lobby = TFT.lobby or { ref = nil }

-- Real vanilla deck (Back) keys, b_challenge excluded (not a normal
-- player-selectable deck). Cycled through by index rather than offering all
-- 15 as separate rows -- matches this project's existing "simple cycle
-- button" convention (e.g. augment tier rows) better than a long list would.
TFT.SelectableDecks = {
	'b_red', 'b_blue', 'b_yellow', 'b_green', 'b_black', 'b_magic', 'b_nebula',
	'b_ghost', 'b_abandoned', 'b_checkered', 'b_zodiac', 'b_painted', 'b_anaglyph',
	'b_plasma', 'b_erratic',
}
TFT.BONUS_MONEY_STEP = 5
TFT.BONUS_MONEY_MAX = 50

-- Host's own working copy of the settings -- kept in a plain TFT-level table
-- (not G.GAME.tft_state) since it's pre-run lobby UI state, not run state,
-- same category as TFT.lobby itself. Mirrors the last-synced value on guests
-- too (updated from the metadata_changed handler below), so both host and
-- guest UI code can read from the same place -- only the host's own edit
-- buttons are ever shown/wired.
TFT.LobbySettings = TFT.LobbySettings or {
	deck_index = 1,
	stake = 1,
	bonus_money = 0,
	timer_enabled = true,
}

-- Plain typed-text-input state -- create_text_input needs a stable
-- {ref_table, ref_value} pair to bind to, same requirement DynaText's own
-- {ref_table, ref_value} binding has elsewhere in this project.
TFT.join_code_input = TFT.join_code_input or { code = '' }

TFT.build_pre_lobby_ui = function()
	return {
		n = G.UIT.ROOT,
		config = { align = 'cm', colour = G.C.CLEAR },
		nodes = {
			{ n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
				{ n = G.UIT.T, config = { text = 'BalatroTFT', scale = 0.6, colour = G.C.UI.TEXT_LIGHT } },
			} },
			{ n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
				UIBox_button({ button = 'tft_create_lobby', label = { 'Create Lobby' }, colour = G.C.BLUE, minw = 4 }),
			} },
			{ n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
				create_text_input({ ref_table = TFT.join_code_input, ref_value = 'code', max_length = 12, prompt_text = 'Lobby Code', id = 'tft_join_code_input', all_caps = true }),
			} },
			{ n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
				UIBox_button({ button = 'tft_join_lobby_from_input', label = { 'Join Lobby' }, colour = G.C.GREEN, minw = 4 }),
			} },
			{ n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
				UIBox_button({ button = 'tft_join_lobby_from_clipboard', label = { 'Join Lobby (from clipboard)' }, colour = G.C.GREEN, minw = 4, scale = 0.35 }),
			} },
		},
	}
end

-- Plain horizontal gap between two bottom-bar pill widgets -- matches
-- BalatroMultiplayer's own ui/_common/spacer.lua convention (a blank
-- G.UIT.C/R node of fixed size) rather than leaning on row padding, since
-- padding here needs to stay small for the row's own outer edges.
local function spacer(w)
	return { n = G.UIT.C, config = { minw = w or 0.15 }, nodes = {} }
end

local function deck_display_name(key)
	local center = G.P_CENTERS[key]
	return (center and center.name) or key
end

-- One settings row: a label, and (host only) "<"/">" or toggle buttons.
-- Guests see the same label with the current value but no buttons -- the
-- config table's own `nodes` just omits the button column entirely for them,
-- rather than showing disabled buttons that would invite clicking.
--
-- `accent_colour` (optional) draws the value as a small filled chip in that
-- colour instead of plain gold text -- used for the Deck row so it reads as
-- its own pill-button, echoing the real BalatroMultiplayer lobby's separate
-- purple "Deck" button (docs/design/next-session-plan-6.md's lobby-UI pass,
-- 2026-09-04) without having to pull Deck out into its own standalone widget.
local function build_setting_row(label_text, value_text, is_host, prev_button, next_button, accent_colour)
	local nodes = {
		{ n = G.UIT.C, config = { minw = 2.2, align = 'cl' }, nodes = {
			{ n = G.UIT.T, config = { text = label_text, scale = 0.35, colour = G.C.UI.TEXT_LIGHT } },
		} },
	}
	if is_host and prev_button then
		table.insert(nodes, { n = G.UIT.C, config = { padding = 0.03 }, nodes = { UIBox_button({ button = prev_button, label = { '<' }, colour = G.C.GREY, minw = 0.4, scale = 0.35 }) } })
	end
	table.insert(nodes, { n = G.UIT.C, config = { minw = 2, align = 'cm', padding = accent_colour and 0.05 or nil, r = accent_colour and 0.08 or nil, colour = accent_colour }, nodes = {
		{ n = G.UIT.T, config = { text = value_text, scale = 0.35, colour = accent_colour and G.C.WHITE or G.C.GOLD } },
	} })
	if is_host and next_button then
		table.insert(nodes, { n = G.UIT.C, config = { padding = 0.03 }, nodes = { UIBox_button({ button = next_button, label = { '>' }, colour = G.C.GREY, minw = 0.4, scale = 0.35 }) } })
	end
	return { n = G.UIT.R, config = { align = 'cm', padding = 0.04 }, nodes = nodes }
end

local function build_settings_panel(lobby)
	local is_host = lobby.is_host
	local s = TFT.LobbySettings
	-- Tightened paddings/scale (real bug fix, 2026-08-28 -- see the layout
	-- note on TFT.build_in_lobby_ui below): this panel used to cost ~2.7
	-- vertical units on its own; at 8 real players that was the difference
	-- between fitting on screen and overlapping the roster grid.
	return { n = G.UIT.C, config = { align = 'cm', padding = 0.06, r = 0.1, colour = G.C.BLACK, emboss = 0.05 }, nodes = {
		{ n = G.UIT.R, config = { align = 'cm', padding = 0.02 }, nodes = {
			-- Orange text nods to the real BalatroMultiplayer lobby's orange
			-- "Lobby Options" button -- this panel stays inline (always visible,
			-- no separate overlay) rather than gated behind a button, so the
			-- colour is the cheapest way to borrow that visual language.
			{ n = G.UIT.T, config = { text = 'Lobby Options', scale = 0.35, colour = G.C.ORANGE } },
		} },
		build_setting_row('Deck', deck_display_name(TFT.SelectableDecks[s.deck_index]), is_host, 'tft_cycle_deck_prev', 'tft_cycle_deck_next', G.C.PURPLE),
		build_setting_row('Stake', 'Stake ' .. s.stake, is_host, 'tft_cycle_stake_prev', 'tft_cycle_stake_next'),
		build_setting_row('Bonus Money', '+$' .. s.bonus_money, is_host, 'tft_cycle_bonus_money_prev', 'tft_cycle_bonus_money_next'),
		is_host
			and { n = G.UIT.R, config = { align = 'cm', padding = 0.02 }, nodes = {
				UIBox_button({ button = 'tft_toggle_timer', label = { 'Round Timer: ' .. (s.timer_enabled and 'ON' or 'OFF') }, colour = G.C.GREY, minw = 3, scale = 0.3 }),
			} }
			or build_setting_row('Round Timer', s.timer_enabled and 'ON' or 'OFF', false),
	} }
end

-- LAYOUT FIX (real bug, confirmed reproducible live 2026-08-28 -- see
-- docs/design/4-8-player-test-plan.md's "Finding 1"): the original layout
-- stacked title / code / roster grid / settings panel / start-button as 5
-- separate full-width G.UIT.R rows. At 8 real players -- the permanent worst
-- case, since MPAPI's own card grid (ui/lobby_card_grid.lua, COLS=4) always
-- wraps to a 2nd row once player_count > 4, and TFT's lobby is always created
-- with max_players=8 -- the total stack height exceeded G.ROOM.T.h (confirmed
-- live: 11.5 units available), so the layout engine's vertical centering
-- pushed the title off the top of the screen and visually overlapped the
-- settings panel with the grid's 2nd row.
--
-- Two changes close the gap with real margin (re-measured live afterward,
-- see build_in_lobby_ui's own caller-side verification note in
-- next-session-plan-5.md): (1) merge the title+code line into one row and
-- shrink every TFT-added row's own padding/text scale -- the roster grid's
-- real Joker-card rows are the one thing here that CAN'T be shrunk (MPAPI
-- gives no scale hook, cards render at full G.CARD_W/G.CARD_H), so all the
-- savings have to come from TFT's own chrome around it; (2) put the settings
-- panel and the start/waiting row side by side as columns instead of two
-- more stacked rows -- there's ample unused horizontal space (grid width is
-- ~8.2 of the room's 20 units), so trading unused width for saved height is
-- free here.
-- Non-clickable "pill" used where the real BalatroMultiplayer lobby shows a
-- greyed-out Disableable_Button (e.g. Start disabled until 2+ players/guest
-- ready) -- confirmed via that mod's real ui/_common/disableable_button.lua:
-- a disabled button there is recoloured to exactly G.C.UI.BACKGROUND_INACTIVE
-- with G.C.UI.TEXT_INACTIVE text, not just plain unstyled text. Reusing those
-- same two colours here keeps our "not ready yet" states visually consistent
-- with theirs instead of looking like plain UI copy.
local function build_status_badge(text)
	return { n = G.UIT.R, config = { align = 'cm', padding = 0.1, r = 0.1, minw = 3, minh = 1, colour = G.C.UI.BACKGROUND_INACTIVE }, nodes = {
		{ n = G.UIT.T, config = { text = text, scale = 0.3, colour = G.C.UI.TEXT_INACTIVE } },
	} }
end

-- View/Copy Code as their own small pill buttons -- replaces the old plain
-- "Code: XXXX" text line, matching the real BalatroMultiplayer lobby's own
-- ui/lobby/lobby_code_buttons.lua (green "View Code" + purple "Copy Code",
-- stacked). View Code toggles reveal via G.FUNCS.tft_view_code below, same
-- toggle-in-place pattern as that mod's real G.FUNCS.view_code.
local function build_lobby_code_buttons()
	return { n = G.UIT.C, config = { align = 'cm', padding = 0.02 }, nodes = {
		{ n = G.UIT.T, config = { text = 'Lobby Code', scale = 0.25, colour = G.C.UI.TEXT_LIGHT } },
		UIBox_button({ id = 'tft_view_code_button', button = 'tft_view_code', label = { 'View Code' }, colour = G.C.PALE_GREEN, minw = 2, minh = 0.5, scale = 0.3 }),
		UIBox_button({ button = 'tft_copy_code', label = { 'Copy Code' }, colour = G.C.PURPLE, minw = 2, minh = 0.5, scale = 0.3 }),
	} }
end

TFT.build_in_lobby_ui = function()
	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	local nodes = {}
	if lobby then
		-- The code itself no longer sits here as plain text -- it's now behind
		-- the View/Copy Code pill buttons in the bottom bar (build_lobby_code_
		-- buttons), matching the real BalatroMultiplayer lobby's own layout.
		table.insert(nodes, { n = G.UIT.R, config = { align = 'cm', padding = 0.03 }, nodes = {
			{ n = G.UIT.T, config = { text = 'BalatroTFT Lobby', scale = 0.4, colour = G.C.UI.TEXT_LIGHT } },
		} })
		-- CORRECTED via live crash diagnosis: MPAPI.create_lobby_ui()'s return
		-- value is a wrapper with a `.node` field that's a real node tree meant
		-- to go directly into a `nodes` array -- it is NOT itself embeddable as
		-- a G.UIT.O node's `object` (confirmed against
		-- BalatroMultiplayerSpeedrun's own real usage: `L.ui_ref.node` inserted
		-- straight into `nodes`). The wrong wrapper crashed engine/ui.lua's
		-- calculate_xywh with "attempt to index field 'T' (a nil value)" --
		-- the layout engine tried to treat it as a positioned UI element
		-- lacking the Transform (`.T`) a real one has.
		local lobby_ui_ref = MPAPI.create_lobby_ui(lobby)
		table.insert(nodes, { n = G.UIT.R, config = { align = 'cm', padding = 0.03 }, nodes = {
			lobby_ui_ref.node,
		} })

		-- Bottom bar reworked to visually match the real BalatroMultiplayer
		-- lobby screen (explicit reference screenshot, 2026-09-04): one dark
		-- rounded panel (colour=L_BLACK, r=0.1, emboss=0.1, same convention
		-- that mod's own lobby row uses) holding a left-to-right sequence of
		-- pill buttons -- Start/status, Lobby Options (settings), Lobby Code
		-- (view/copy), Leave Lobby -- instead of the old plain stacked rows.
		local bottom_row_nodes = {}
		if lobby.is_host then
			local player_count = 0
			for _ in pairs(lobby._players or {}) do player_count = player_count + 1 end
			if player_count >= 2 then
				table.insert(bottom_row_nodes, UIBox_button({ button = 'tft_start_game', label = { 'Start Game' }, colour = G.C.RED, minw = 3, minh = 1 }))
			else
				table.insert(bottom_row_nodes, build_status_badge('Need 2+ players'))
			end
		else
			table.insert(bottom_row_nodes, build_status_badge('Waiting for host...'))
		end
		table.insert(bottom_row_nodes, spacer(0.2))
		table.insert(bottom_row_nodes, build_settings_panel(lobby))
		table.insert(bottom_row_nodes, spacer(0.2))
		table.insert(bottom_row_nodes, build_lobby_code_buttons())
		table.insert(bottom_row_nodes, spacer(0.2))
		table.insert(bottom_row_nodes, UIBox_button({ button = 'tft_leave_lobby', label = { 'Leave', 'Lobby' }, colour = G.C.RED, minw = 2, minh = 1, scale = 0.35, col = true }))
		table.insert(nodes, { n = G.UIT.R, config = { align = 'cm', padding = 0.15, r = 0.1, emboss = 0.1, colour = G.C.L_BLACK }, nodes = bottom_row_nodes })
	end
	return { n = G.UIT.ROOT, config = { align = 'cm', colour = G.C.CLEAR }, nodes = nodes }
end

G.FUNCS.tft_create_lobby = function()
	local lobby = MPAPI.create_lobby(TFT.id, { max_players = 8 })
	if not lobby then
		TFT.sendWarnMessage('tft_create_lobby: MPAPI.create_lobby failed')
		return
	end
	TFT.setup_lobby_events(lobby)
	lobby:on('connected', function()
		TFT.sendDebugMessage('Lobby created: ' .. tostring(lobby.code))
		if love.system and love.system.setClipboardText then
			love.system.setClipboardText(lobby.code)
		end
	end)
end

local function join_with_code(code)
	if not code or code == '' then
		TFT.sendWarnMessage('join_with_code: no code given')
		return
	end
	local lobby = MPAPI.join_lobby(TFT.id, code)
	if not lobby then
		TFT.sendWarnMessage('join_with_code: MPAPI.join_lobby failed for code ' .. tostring(code))
		return
	end
	TFT.setup_lobby_events(lobby)
end

G.FUNCS.tft_join_lobby_from_clipboard = function()
	local code = love.system and love.system.getClipboardText and love.system.getClipboardText()
	join_with_code(code)
end

G.FUNCS.tft_join_lobby_from_input = function()
	join_with_code(TFT.join_code_input.code)
end

-- View Code: toggles the button's own label between "View Code" and the real
-- code in place -- exact same toggle-in-place pattern as BalatroMultiplayer's
-- own real G.FUNCS.view_code (confirmed via source read: it swaps
-- e.children[1].children[1].config.text and e.config.colour directly, then
-- calls e.UIBox:recalculate() rather than rebuilding the whole lobby UI).
G.FUNCS.tft_view_code = function(e)
	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	if not lobby then return end
	local text_config = e.children[1].children[1].config
	if text_config.text ~= tostring(lobby.code) then
		e.config.colour = G.C.ETERNAL
		text_config.text = tostring(lobby.code)
	else
		e.config.colour = G.C.PALE_GREEN
		text_config.text = 'View Code'
	end
	e.UIBox:recalculate()
end

G.FUNCS.tft_copy_code = function()
	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	if not lobby or not lobby.code then return end
	if love.system and love.system.setClipboardText then
		love.system.setClipboardText(lobby.code)
	end
end

-- Real functional gap this pass closes, not just cosmetic: there was
-- previously no way to leave a lobby from the UI at all short of alt-tabbing
-- out. lobby:leave() (api/lobby/state.lua) is MPAPI's own real teardown --
-- it fires MPAPI.LobbyEvent.DISCONNECTED, which TFT.setup_lobby_events above
-- already handles (clears TFT.lobby.ref), so no extra cleanup is needed here.
G.FUNCS.tft_leave_lobby = function()
	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	if lobby and lobby.leave then
		lobby:leave()
	end
end

function TFT.setup_lobby_events(lobby)
	TFT.lobby.ref = lobby
	lobby:on('player_joined', function(player_id)
		TFT.sendDebugMessage('Player joined: ' .. tostring(player_id))
		if MPAPI.refresh_current_view then MPAPI.refresh_current_view() end
	end)
	lobby:on('player_left', function(player_id)
		TFT.sendDebugMessage('Player left: ' .. tostring(player_id))
		if MPAPI.refresh_current_view then MPAPI.refresh_current_view() end
	end)
	lobby:on('disconnected', function()
		TFT.sendDebugMessage('Disconnected from lobby')
		TFT.lobby.ref = nil
	end)
	lobby:on('error', function(err)
		TFT.sendWarnMessage('Lobby error: ' .. tostring(err))
	end)
	-- Host-authored settings sync -- MPAPI.LobbyEvent.METADATA_CHANGED fires
	-- on every client (including the host itself, per this file's other
	-- broadcast-loops-back-to-sender confirmed pattern) whenever
	-- lobby:set_metadata succeeds. Guests mirror the synced values into their
	-- own TFT.LobbySettings so their (read-only) settings panel shows the
	-- real current settings, not local stale defaults.
	lobby:on(MPAPI.LobbyEvent.METADATA_CHANGED, function(metadata)
		if metadata and metadata.tft_settings then
			TFT.LobbySettings = metadata.tft_settings
		end
		if MPAPI.refresh_current_view then MPAPI.refresh_current_view() end
	end)
end

local function host_update_settings(mutator)
	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	if not lobby or not lobby.is_host then return end
	mutator(TFT.LobbySettings)
	lobby:set_metadata({ tft_settings = TFT.LobbySettings })
	if MPAPI.refresh_current_view then MPAPI.refresh_current_view() end
end

G.FUNCS.tft_cycle_deck_prev = function()
	host_update_settings(function(s)
		s.deck_index = s.deck_index - 1
		if s.deck_index < 1 then s.deck_index = #TFT.SelectableDecks end
	end)
end
G.FUNCS.tft_cycle_deck_next = function()
	host_update_settings(function(s)
		s.deck_index = s.deck_index + 1
		if s.deck_index > #TFT.SelectableDecks then s.deck_index = 1 end
	end)
end
G.FUNCS.tft_cycle_stake_prev = function()
	host_update_settings(function(s) s.stake = math.max(1, s.stake - 1) end)
end
G.FUNCS.tft_cycle_stake_next = function()
	host_update_settings(function(s) s.stake = math.min(8, s.stake + 1) end)
end
G.FUNCS.tft_cycle_bonus_money_prev = function()
	host_update_settings(function(s) s.bonus_money = math.max(0, s.bonus_money - TFT.BONUS_MONEY_STEP) end)
end
G.FUNCS.tft_cycle_bonus_money_next = function()
	host_update_settings(function(s) s.bonus_money = math.min(TFT.BONUS_MONEY_MAX, s.bonus_money + TFT.BONUS_MONEY_STEP) end)
end
G.FUNCS.tft_toggle_timer = function()
	host_update_settings(function(s) s.timer_enabled = not s.timer_enabled end)
end

-- Host-only: broadcasts a shared seed + the settings panel's current values
-- so every client's round-flow (Carousel/Augment RNG, boss picks, deck/
-- stake/bonus-money/timer setup) derives from the same source, then everyone
-- (including the host, via the same on_receive -- MPAPI broadcasts loop back
-- to the sender too, matching the pattern already confirmed working in
-- BalatroMultiplayerSpeedrun) starts the real run. Blocked below 2 players --
-- "should be able to start as long as there are 2-8 people," explicit
-- instruction -- this file's own UI already hides the button below 2, this
-- is the actual enforcement (a stale/cached UI shouldn't be the only guard).
G.FUNCS.tft_start_game = function()
	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	if not lobby or not lobby.is_host then return end
	local player_count = 0
	for _ in pairs(lobby._players or {}) do player_count = player_count + 1 end
	if player_count < 2 then
		TFT.sendWarnMessage('tft_start_game: need at least 2 players, have ' .. player_count)
		return
	end
	local s = TFT.LobbySettings
	lobby:action(MPAPI.ActionTypes['tft_start_game']):broadcast({
		seed = tostring(os.time()),
		deck = TFT.SelectableDecks[s.deck_index],
		stake = s.stake,
		bonus_money = s.bonus_money,
		timer_enabled = s.timer_enabled,
	})
end
