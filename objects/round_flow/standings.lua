-- Run Info "Standings" tab (next-session-plan-4.md item 4): life total + level
-- for every player in the lobby, sorted by life total (highest/"winning"
-- first -- not specified explicitly, my own call, cheap to flip).
--
-- G.UIDEF.run_info (functions/UI_definitions.lua) builds its tabs list
-- INLINE inside its own body (`create_tabs({tabs = {...}})`, the tabs array
-- constructed and consumed in the same expression) rather than exposing a
-- hookable seam the way create_UIBox_HUD/create_UIBox_blind_select do
-- elsewhere in this project -- there's no already-built tree to splice a
-- node into after the fact, and hooking create_tabs itself would be a much
-- wider blast radius (it's a generic, widely-reused tab-builder, not
-- run_info-specific). Instead this fully replaces G.UIDEF.run_info, but
-- calls vanilla's own real tab-content builders by name
-- (create_UIBox_current_hands, G.UIDEF.current_blinds, G.UIDEF.used_vouchers,
-- G.UIDEF.current_stake) rather than reimplementing any of their content --
-- only the outer tabs LIST is re-declared, with our own tab appended,
-- confirmed against the real installed UI_definitions.lua's own run_info
-- body so this exactly mirrors vanilla's structure otherwise.
function TFT.build_standings_tab()
	local rows = {}
	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	local state = TFT.get_state()

	if lobby and state then
		local my_id = lobby.player_id
		local players = {}
		for player_id, _ in pairs(lobby._players or {}) do
			local is_me = player_id == my_id
			local life = is_me and (state.life_total or TFT.STARTING_LIFE)
				or (TFT._opponent_life_totals and TFT._opponent_life_totals[player_id]) or TFT.STARTING_LIFE
			local level = is_me and (state.level or 1) or TFT.opponent_level(player_id)
			local eliminated = is_me and state.eliminated or (TFT._eliminated_players and TFT._eliminated_players[player_id])
			local p = lobby._players[player_id]
			local display_name = (p and p.displayName) or player_id
			table.insert(players, {
				name = display_name .. (is_me and ' (You)' or ''),
				life = life,
				level = level,
				eliminated = eliminated,
			})
		end
		table.sort(players, function(a, b) return (a.life or 0) > (b.life or 0) end)

		for _, entry in ipairs(players) do
			local status_text = entry.eliminated and 'Eliminated' or ('Life ' .. math.floor((entry.life or 0) + 0.5))
			table.insert(rows, { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
				{ n = G.UIT.C, config = { minw = 3, align = 'cl' }, nodes = {
					{ n = G.UIT.T, config = { text = entry.name, scale = 0.4, colour = entry.eliminated and G.C.UI.TEXT_INACTIVE or G.C.WHITE } },
				} },
				{ n = G.UIT.C, config = { minw = 1.3, align = 'cm' }, nodes = {
					{ n = G.UIT.T, config = { text = 'Lv. ' .. entry.level, scale = 0.4, colour = G.C.GOLD } },
				} },
				{ n = G.UIT.C, config = { minw = 1.8, align = 'cm' }, nodes = {
					{ n = G.UIT.T, config = { text = status_text, scale = 0.4, colour = entry.eliminated and G.C.UI.TEXT_INACTIVE or G.C.RED } },
				} },
			} })
		end
	end

	if #rows == 0 then
		rows[1] = { n = G.UIT.R, config = { align = 'cm' }, nodes = {
			{ n = G.UIT.T, config = { text = 'Not in a multiplayer match', scale = 0.4, colour = G.C.UI.TEXT_LIGHT } },
		} }
	end

	return { n = G.UIT.ROOT, config = { align = 'cm', colour = G.C.CLEAR, padding = 0.2 }, nodes = rows }
end

local _tft_orig_run_info = G.UIDEF.run_info
function G.UIDEF.run_info()
	if not TFT.is_run_active() or not TFT.get_state() or not TFT.get_state().is_multiplayer then
		return _tft_orig_run_info()
	end

	return create_UIBox_generic_options({ contents = { create_tabs({
		tabs = {
			{
				label = localize('b_poker_hands'),
				chosen = true,
				tab_definition_function = create_UIBox_current_hands,
			},
			{
				label = localize('b_blinds'),
				tab_definition_function = G.UIDEF.current_blinds,
			},
			{
				label = localize('b_vouchers'),
				tab_definition_function = G.UIDEF.used_vouchers,
			},
			{
				label = 'Standings',
				tab_definition_function = TFT.build_standings_tab,
			},
			-- BUG FOUND & FIXED live: this conditional tab MUST be last in the
			-- array. `G.GAME.stake > 1 and {...} or nil` puts a real `nil` in
			-- this slot whenever stake is 1 -- and Lua's `ipairs` (which
			-- create_tabs uses to walk this array) stops at the FIRST nil hole
			-- it hits, silently dropping every entry after it. The Standings
			-- tab above was originally placed AFTER this one and never
			-- rendered at all on a real stake-1 lobby, confirmed live via a
			-- real Run Info screen missing it entirely.
			G.GAME.stake > 1 and {
				label = localize('b_stake'),
				tab_definition_function = G.UIDEF.current_stake,
			} or nil,
		},
		tab_h = 8,
		snap_to_nav = true,
	}) } })
end
