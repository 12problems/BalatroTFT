-- Computes and stores this round's PvP pairing the moment round_index moves
-- onto a real (multiplayer, not solo-substituted) PvP round -- every client
-- does this independently and identically (domain/pvp_pairing.lua is a pure,
-- deterministic function), no broadcast needed for the pairing itself.
function TFT.setup_pvp_pairing_if_needed()
	local state = TFT.get_state()
	local round_def = TFT.current_round_def()
	if not state or not round_def then return end
	if not state.is_multiplayer or round_def.round_type ~= TFT.RoundType.PVP then
		state.current_pairing = nil
		return
	end

	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	if not lobby then return end

	-- CLOSED, next-session-plan.md priority #1: excludes anyone
	-- objects/round_flow/elimination.lua's tracking (broadcast-received via
	-- life_total_change.lua) currently knows is out, plus this client itself
	-- if it's the one eliminated -- rather than "everyone in the lobby"
	-- regardless of elimination state.
	local alive_ids = {}
	local my_id = lobby.player_id
	for player_id, _ in pairs(lobby._players or {}) do
		local eliminated = (player_id == my_id) and state.eliminated or TFT._eliminated_players[player_id]
		if not eliminated then
			table.insert(alive_ids, player_id)
		end
	end

	state.pvp_round_number = (state.pvp_round_number or 0) + 1
	state.current_pairing = TFT.compute_pvp_pairing(alive_ids, state.pvp_round_number)

	local my_id = lobby.player_id
	local opponent_id = TFT.find_pvp_opponent(state.current_pairing, my_id)
	if opponent_id then
		TFT.sendDebugMessage('PvP round ' .. state.pvp_round_number .. ': paired vs ' .. opponent_id)
	else
		TFT.sendDebugMessage('PvP round ' .. state.pvp_round_number .. ': ghost round (odd lobby)')
	end
end
