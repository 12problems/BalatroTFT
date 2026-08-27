-- Minimal real lobby flow -- create/join a private lobby, see the roster (via
-- MPAPI's own MPAPI.create_lobby_ui, reused as-is rather than reimplementing a
-- player-card grid), host starts the match. Deliberately skips SPDRN's ban-
-- pick/countdown/matchmaking ceremony entirely -- this session's bar is "a
-- multiplayer setup with 2 players is able to be tested", not full lobby UX
-- polish. Clipboard-based join (no text-input UI) for the same reason.
TFT.lobby = TFT.lobby or { ref = nil }

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
				UIBox_button({ button = 'tft_join_lobby_from_clipboard', label = { 'Join Lobby (from clipboard)' }, colour = G.C.GREEN, minw = 4 }),
			} },
		},
	}
end

TFT.build_in_lobby_ui = function()
	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	local nodes = {
		{ n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
			{ n = G.UIT.T, config = { text = 'BalatroTFT Lobby', scale = 0.5, colour = G.C.UI.TEXT_LIGHT } },
		} },
	}
	if lobby then
		table.insert(nodes, { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
			{ n = G.UIT.T, config = { text = 'Code: ' .. tostring(lobby.code), scale = 0.4, colour = G.C.GOLD } },
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
		table.insert(nodes, { n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
			lobby_ui_ref.node,
		} })
		if lobby.is_host then
			table.insert(nodes, { n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
				UIBox_button({ button = 'tft_start_game', label = { 'Start Game' }, colour = G.C.RED, minw = 4 }),
			} })
		else
			table.insert(nodes, { n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
				{ n = G.UIT.T, config = { text = 'Waiting for host to start...', scale = 0.35, colour = G.C.UI.TEXT_LIGHT } },
			} })
		end
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

G.FUNCS.tft_join_lobby_from_clipboard = function()
	local code = love.system and love.system.getClipboardText and love.system.getClipboardText()
	if not code or code == '' then
		TFT.sendWarnMessage('tft_join_lobby_from_clipboard: clipboard is empty')
		return
	end
	local lobby = MPAPI.join_lobby(TFT.id, code)
	if not lobby then
		TFT.sendWarnMessage('tft_join_lobby_from_clipboard: MPAPI.join_lobby failed for code ' .. tostring(code))
		return
	end
	TFT.setup_lobby_events(lobby)
end

function TFT.setup_lobby_events(lobby)
	TFT.lobby.ref = lobby
	lobby:on('player_joined', function(player_id)
		TFT.sendDebugMessage('Player joined: ' .. tostring(player_id))
		if MPAPI.refresh_current_view then MPAPI.refresh_current_view() end
	end)
	lobby:on('player_left', function(player_id)
		TFT.sendDebugMessage('Player left: ' .. tostring(player_id))
	end)
	lobby:on('disconnected', function()
		TFT.sendDebugMessage('Disconnected from lobby')
		TFT.lobby.ref = nil
	end)
	lobby:on('error', function(err)
		TFT.sendWarnMessage('Lobby error: ' .. tostring(err))
	end)
end

-- Host-only: broadcasts a shared seed so every client's round-flow (Carousel/
-- Augment RNG, boss picks) derives from the same source, then everyone
-- (including the host, via the same on_receive -- MPAPI broadcasts loop back
-- to the sender too, matching the pattern already confirmed working in
-- BalatroMultiplayerSpeedrun) starts the real run.
G.FUNCS.tft_start_game = function()
	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	if not lobby or not lobby.is_host then return end
	lobby:action(MPAPI.ActionTypes['tft_start_game']):broadcast({ seed = tostring(os.time()) })
end
