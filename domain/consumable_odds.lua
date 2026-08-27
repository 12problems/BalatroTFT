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
