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
