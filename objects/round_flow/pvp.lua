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

-- Early Warning augment support (closes next-session-plan-3.md priority #1.2:
-- this function genuinely did not exist before -- the comment in
-- definitions.lua claiming it did was itself the bug). Returns an array of
-- the caller's next `count` PvP opponents AFTER the current round, i.e. a
-- real lookahead beyond what's already visible from state.current_pairing.
--
-- Computed against TODAY's alive-player set, the only information any client
-- can have right now -- if someone else is eliminated between now and then,
-- a real future round's alive_ids (and therefore its actual pairing) could
-- differ from this prediction. That's an inherent property of round-robin
-- pairing depending on who's still alive, not a bug in this function: it's
-- the same "best available forecast" every other round-robin lookahead
-- (sports brackets, etc.) makes, and a wrong forecast just means a real
-- surprise for a round that already happens without Early Warning anyway.
--
-- Each returned entry is a player_id, or the string 'ghost' for a
-- hypothetical round that would leave the caller in the ghost slot.
function TFT.upcoming_pvp_opponents(count)
	local state = TFT.get_state()
	if not state or not state.is_multiplayer then return {} end
	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	if not lobby then return {} end

	local my_id = lobby.player_id
	local alive_ids = {}
	for player_id, _ in pairs(lobby._players or {}) do
		local eliminated = (player_id == my_id) and state.eliminated or TFT._eliminated_players[player_id]
		if not eliminated then
			table.insert(alive_ids, player_id)
		end
	end

	local base_round = state.pvp_round_number or 0
	local out = {}
	for i = 1, (count or 2) do
		local pairing = TFT.compute_pvp_pairing(alive_ids, base_round + i)
		out[i] = TFT.find_pvp_opponent(pairing, my_id) or 'ghost'
	end
	return out
end
