-- Round-robin PvP pairing, deterministic from the shared match seed + round
-- number + current alive-player list -- computed independently and identically
-- by every client (architecture.md's "PvP Pairing" section), no network
-- round-trip needed. Circle-method tournament scheduling: a solved problem,
-- not invented here -- fixes player 1, rotates everyone else around them each
-- round so nobody repeats an opponent until the full pool has been faced once.
--
-- alive_ids: array of player_id strings, already sorted the SAME way on every
-- client (the caller's job -- table.sort on the raw id strings works, since
-- every client has the same set of ids to sort identically).
-- round_number: which PvP round this is *within the pairing cycle* (1-based,
-- resets each time the alive-player set changes size, since the circle method
-- needs a stable N to rotate against).
--
-- Returns: { pairs = {{a,b}, ...}, ghost = player_id_or_nil } -- `ghost` is set
-- when there's an odd number of alive players; that player has no real
-- opponent this round (architecture.md's ghost-board mechanic -- they face a
-- snapshot of someone else's board instead, handled by whoever calls this).
function TFT.compute_pvp_pairing(alive_ids, round_number)
	local ids = {}
	for i, id in ipairs(alive_ids) do ids[i] = id end
	table.sort(ids)

	local ghost = nil
	if #ids % 2 == 1 then
		-- Deterministic ghost pick: rotates through the roster round to round
		-- rather than always picking the same player, using round_number as
		-- the offset into the sorted id list.
		local ghost_index = ((round_number - 1) % #ids) + 1
		ghost = ids[ghost_index]
		local remaining = {}
		for _, id in ipairs(ids) do
			if id ~= ghost then table.insert(remaining, id) end
		end
		ids = remaining
	end

	local n = #ids
	if n == 0 then
		return { pairs = {}, ghost = ghost }
	end
	if n == 1 then
		-- Only one non-ghost player left (e.g. 2-player lobby, one already
		-- ghosted this round is impossible since n started even -- this really
		-- only hits at n=1 total alive, a match that should already be over).
		return { pairs = {}, ghost = ids[1] }
	end

	-- Standard circle method: fix ids[1], rotate the rest by (round_number-1)
	-- positions around a circle of the remaining n-1 seats.
	local fixed = ids[1]
	local rotating = {}
	for i = 2, n do rotating[i - 1] = ids[i] end
	local m = #rotating
	local offset = (round_number - 1) % m
	local rotated = {}
	for i = 1, m do
		rotated[i] = rotating[((i - 1 + offset) % m) + 1]
	end

	local pairs_out = {}
	table.insert(pairs_out, { fixed, rotated[1] })
	local lo, hi = 2, m
	while lo < hi do
		table.insert(pairs_out, { rotated[lo], rotated[hi] })
		lo = lo + 1
		hi = hi - 1
	end

	return { pairs = pairs_out, ghost = ghost }
end

-- Given a computed pairing and a player_id, returns that player's opponent id
-- (or nil if they're the ghost this round).
function TFT.find_pvp_opponent(pairing, player_id)
	if pairing.ghost == player_id then return nil end
	for _, pair in ipairs(pairing.pairs) do
		if pair[1] == player_id then return pair[2] end
		if pair[2] == player_id then return pair[1] end
	end
	return nil
end
