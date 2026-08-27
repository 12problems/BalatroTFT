-- Broadcast by the host (ui/lobby.lua's tft_start_game) once ready to begin.
-- MPAPI broadcasts loop back to the sender too (confirmed pattern from
-- BalatroMultiplayerSpeedrun), so every client -- host included -- starts the
-- real run from this same on_receive, all off the same shared seed. No ready-
-- check/countdown/ban-pick ceremony this session -- starts immediately.
MPAPI.ActionType({
	key = 'tft_start_game',
	on_receive = function(action_type, from_player_id, params)
		G.FUNCS.start_run(nil, { seed = params.seed, stake = 1 })
	end,
})
