-- Individual-card weight multipliers within the existing Tarot/Spectral pools, by
-- level. 1.0 = normal/unlisted card's baseline weight. Does NOT touch the
-- Tarot/Planet/Spectral category split itself (explicitly deferred, see
-- technical.md's "Deferred -- Spectral shop odds"). Planet cards are completely
-- unchanged at every level. Source: architecture.md's "Consumable Odds by Level".
--
-- Runtime wiring (actually applying these weights to shop generation) is lower
-- priority than the round-flow/Traits work this session -- this table exists so
-- it's ready when that wiring happens, per docs/design/README.md's Tier 1 note.

-- The 8-card phase-out group, ramping to 0 (fully removed) by level 8.
TFT.TarotPhaseOutGroup = {
	'c_empress', 'c_heirophant', 'c_high_priestess', 'c_world',
	'c_star', 'c_moon', 'c_sun', 'c_magician',
}
TFT.TarotPhaseOutWeightByLevel = {
	[1] = 1.0, [2] = 1.0, [3] = 1.0,
	[4] = 0.8, [5] = 0.6, [6] = 0.4, [7] = 0.2,
	[8] = 0.0, [9] = 0.0, [10] = 0.0,
}

-- Justice: impossible until level 7, ramps in, boosted at 10.
TFT.JusticeWeightByLevel = {
	[1] = 0.0, [2] = 0.0, [3] = 0.0, [4] = 0.0, [5] = 0.0, [6] = 0.0,
	[7] = 0.33, [8] = 0.66, [9] = 1.0, [10] = 1.5,
}

-- Death: single step up starting at level 6.
TFT.DeathWeightByLevel = {
	[1] = 1.0, [2] = 1.0, [3] = 1.0, [4] = 1.0, [5] = 1.0,
	[6] = 1.5, [7] = 1.5, [8] = 1.5, [9] = 1.5, [10] = 1.5,
}

-- Spectrals: Ankh, Ectoplasm, Wraith, The Soul get a flat boost from level 7 on.
TFT.SpectralBoostGroup = { 'c_ankh', 'c_ectoplasm', 'c_wraith', 'c_soul' }
TFT.SpectralBoostWeightByLevel = {
	[1] = 1.0, [2] = 1.0, [3] = 1.0, [4] = 1.0, [5] = 1.0, [6] = 1.0,
	[7] = 1.3, [8] = 1.3, [9] = 1.3, [10] = 1.3,
}

-- Returns the weight multiplier for a given Tarot/Spectral card key at a level.
-- 1.0 for anything not in one of the special groups above.
function TFT.consumable_weight(card_key, level)
	for _, key in ipairs(TFT.TarotPhaseOutGroup) do
		if key == card_key then return TFT.TarotPhaseOutWeightByLevel[level] or 1.0 end
	end
	if card_key == 'c_justice' then return TFT.JusticeWeightByLevel[level] or 1.0 end
	if card_key == 'c_death' then return TFT.DeathWeightByLevel[level] or 1.0 end
	for _, key in ipairs(TFT.SpectralBoostGroup) do
		if key == card_key then return TFT.SpectralBoostWeightByLevel[level] or 1.0 end
	end
	return 1.0
end

-- Runtime wiring (next-session-plan-4.md item 6): applies the weights above to
-- an already-built card-key pool array, the same array shape/convention
-- get_current_pool itself returns (one slot per eligible card, a single
-- uniform pseudorandom_element pick over the whole array -- confirmed via
-- source read of the real installed functions/common_events.lua, no reroll
-- logic at that call site) and the same one objects/round_flow/shop_odds.lua's
-- Shared Joker Pool filter already mutates for its own exclusion purpose.
-- Weighting via REPETITION rather than a real weighted-random function: each
-- key gets `round(weight * TFT.CONSUMABLE_WEIGHT_RESOLUTION)` copies in the
-- output array instead of exactly 1, so a plain uniform pick over the
-- resulting array reproduces the intended proportions -- consistent with the
-- pool's own existing "array of repeated/removed slots" convention rather
-- than introducing a second, different weighting mechanism. A weight of 0.0
-- means 0 copies, i.e. fully excluded (matches "impossible until level 7"
-- for Justice) -- distinct from vanilla's own 'UNAVAILABLE' sentinel, which
-- this function never emits (it only ever removes/duplicates real keys).
TFT.CONSUMABLE_WEIGHT_RESOLUTION = 10

function TFT.apply_consumable_weights(pool, level)
	if not pool or not level then return pool end
	local out = {}
	for _, key in ipairs(pool) do
		if key == 'UNAVAILABLE' then
			out[#out + 1] = key
		else
			local weight = TFT.consumable_weight(key, level)
			local copies = math.floor(weight * TFT.CONSUMABLE_WEIGHT_RESOLUTION + 0.5)
			for _ = 1, copies do
				out[#out + 1] = key
			end
		end
	end
	-- A pool that weighted-out to nothing (shouldn't normally happen given
	-- weights bottom out at 0.0 only for a handful of specific cards, never
	-- the whole pool at once) falls back to the untouched original rather
	-- than handing the caller an empty array to pick from.
	if #out == 0 then return pool end
	return out
end
