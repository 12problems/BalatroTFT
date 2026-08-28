-- Broadcasts a player's own level whenever it changes -- next-session-plan-4.md
-- item 4's Run Info "Standings" tab needs every player's level, which nothing
-- broadcast before this (technical.md's own action list named this
-- `xp_level_change` but it was never actually built). Same one-way,
-- broadcast-on-change pattern as objects/actions/life_total_change.lua.
--
-- No explicit initial broadcast at run start, matching that same file's own
-- precedent: everyone genuinely starts at level 1, so TFT._opponent_levels
-- simply defaults to 1 for any player id it's never heard from yet (see
-- TFT.opponent_level below) rather than needing a real "hello, I'm level 1"
-- message the instant a run begins.
MPAPI.ActionType({
	key = 'tft_xp_level_change',
	on_receive = function(action_type, from_player_id, params)
		TFT._opponent_levels = TFT._opponent_levels or {}
		TFT._opponent_levels[from_player_id] = params.level
	end,
})

function TFT.broadcast_xp_level_change(level)
	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	if not lobby then return end
	lobby:action(MPAPI.ActionTypes['tft_xp_level_change']):broadcast({ level = level })
end

-- Level 1 default for any player_id not yet heard from -- see header note.
function TFT.opponent_level(player_id)
	return (TFT._opponent_levels and TFT._opponent_levels[player_id]) or 1
end
