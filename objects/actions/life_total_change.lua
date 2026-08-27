-- Broadcasts a player's own life total whenever it changes, so every other
-- client's HUD/elimination-tracking can stay in sync without polling.
--
-- CLOSED, next-session-plan.md priority #1: elimination detection now rides
-- along on this same broadcast (an `eliminated` flag alongside life_total,
-- rather than a separate action) -- every elimination is necessarily
-- preceded by a life-total change (round_result.lua only ever marks someone
-- eliminated in the same branch that computes their new life total), so a
-- second broadcast round-trip would just be redundant. See
-- objects/round_flow/elimination.lua for TFT._eliminated_players/
-- TFT.count_alive_players and the actual placement/victory-screen wiring.
MPAPI.ActionType({
	key = 'tft_life_total_change',
	on_receive = function(action_type, from_player_id, params)
		TFT._opponent_life_totals = TFT._opponent_life_totals or {}
		TFT._opponent_life_totals[from_player_id] = params.life_total
		TFT._eliminated_players = TFT._eliminated_players or {}
		TFT._eliminated_players[from_player_id] = params.eliminated or nil

		-- Last-player-standing win check (objects/round_flow/elimination.lua's
		-- documented default for next-session-plan.md's open question #3):
		-- someone ELSE just went out, so re-check whether that leaves this
		-- client as the sole survivor. Only matters if we're not already out
		-- ourselves and haven't already been shown the victory screen.
		local state = TFT.get_state()
		if params.eliminated and state and not state.eliminated and not state.match_won then
			if TFT.count_alive_players() <= 1 then
				state.match_won = true
				TFT.show_victory_screen()
			end
		end
	end,
})

function TFT.broadcast_life_total_change(life_total, eliminated)
	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	if not lobby then return end
	lobby:action(MPAPI.ActionTypes['tft_life_total_change']):broadcast({ life_total = life_total, eliminated = eliminated or nil })
end
