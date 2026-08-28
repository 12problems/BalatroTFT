-- Carousel offers pair a "unit" (a Joker, drawn from a power_tier range that
-- scales up stage-by-stage) with a consumable (Tarot or Spectral, ALL of them
-- except Black Hole and The Soul -- explicitly no Planets at all). Source:
-- 2026-08-25 session instruction. Keys verified against
-- Balatro Source/localization/en-us.lua.

-- All 22 Tarots + all 18 Spectrals, minus c_black_hole and c_soul (36 total).
-- No Planets (c_ceres..c_venus) anywhere in this list, per instruction.
TFT.CarouselConsumablePool = {
	-- Tarots (22)
	'c_fool', 'c_magician', 'c_high_priestess', 'c_empress', 'c_emperor',
	'c_heirophant', 'c_lovers', 'c_chariot', 'c_strength', 'c_hermit',
	'c_wheel_of_fortune', 'c_justice', 'c_hanged_man', 'c_death', 'c_temperance',
	'c_devil', 'c_tower', 'c_star', 'c_moon', 'c_sun', 'c_judgement', 'c_world',
	-- Spectrals (16 -- Black Hole and The Soul excluded per instruction)
	'c_familiar', 'c_grim', 'c_incantation', 'c_talisman', 'c_aura', 'c_wraith',
	'c_sigil', 'c_ouija', 'c_ectoplasm', 'c_immolate', 'c_ankh', 'c_deja_vu',
	'c_hex', 'c_trance', 'c_medium', 'c_cryptid',
}

-- Unit (Joker) power_tier range offered per Carousel round, keyed by stage.
-- ASSUMPTION (flagged): "moving from tier 1-3s to tier 3-5s by the end" wasn't
-- given exact per-stage numbers -- this is a clean linear ramp across the 6
-- Carousel rounds (stages 2-7), hitting both stated endpoints exactly.
TFT.CarouselTierRangeByStage = {
	[2] = { 1, 3 },
	[3] = { 1, 3 },
	[4] = { 2, 4 },
	[5] = { 2, 4 },
	[6] = { 3, 5 },
	[7] = { 3, 5 },
}

function TFT.carousel_tier_range(stage)
	return TFT.CarouselTierRangeByStage[stage] or { 1, 3 }
end

-- Power-level bias within a stage's own tier range (next-session-plan-4.md
-- item 2.4a: "bias it according to stage" using the existing Power Tier
-- system, NOT a new metric and NOT pre-Ranked copies -- explicitly rejected
-- alternatives, see the plan doc). First-draft linear ramp, same flagged-
-- assumption convention as the tier range table above (which was itself an
-- unspecified "clean linear ramp" the first time this file was written):
-- 0 bias at stage 2 (uniform across the range) up to a flat max at stage 7
-- (heavily favouring the top tier in range).
TFT.CAROUSEL_BIAS_MAX = 3
function TFT.carousel_bias_factor(stage)
	local progress = (stage - 2) / (7 - 2)
	progress = math.max(0, math.min(1, progress))
	return progress * TFT.CAROUSEL_BIAS_MAX
end

-- Weighted version of TFT.random_joker_in_tier_range (rarity_odds.lua) --
-- same repeated-candidate-list technique domain/consumable_odds.lua's
-- TFT.apply_consumable_weights uses (build a list with each tier's jokers
-- repeated proportional to its weight, then one uniform pick over the
-- expanded list), rather than a second, different weighting mechanism.
TFT.CAROUSEL_BIAS_RESOLUTION = 10
function TFT.random_joker_in_tier_range_biased(min_tier, max_tier, stage, seed)
	local by_tier = TFT.jokers_by_power_tier()
	local bias = TFT.carousel_bias_factor(stage)
	local candidates = {}
	for tier = min_tier, max_tier do
		local weight = 1 + bias * (tier - min_tier)
		local copies = math.floor(weight * TFT.CAROUSEL_BIAS_RESOLUTION + 0.5)
		for _, key in ipairs(by_tier[tier] or {}) do
			for _ = 1, copies do
				table.insert(candidates, key)
			end
		end
	end
	if #candidates == 0 then
		return TFT.random_joker_in_tier_range(min_tier, max_tier, seed)
	end
	return pseudorandom_element(candidates, pseudoseed(seed or 'tft_carousel_joker_biased'))
end
