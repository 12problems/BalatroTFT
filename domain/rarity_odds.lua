-- Joker shop rarity odds by level, and the Power Tier / Rank system.
-- Source: architecture.md's "Shop Rarity Odds by Level" and joker-ranking.md's
-- "Power Tier" + "Shared Joker Pool" sections. First-draft numbers, flagged there
-- for playtesting.

-- Power tiers, parallel to vanilla `rarity` (1-4) but a distinct mod-specific
-- field -- see joker-ranking.md for why this isn't just reusing vanilla rarity.
TFT.PowerTier = {
	COMMON = 1,
	UNCOMMON = 2,
	RARE = 3,
	STRONG = 4,
	LEGENDARY = 5,
}

-- Shop odds by level, keyed by power tier number, summing to 1.0 per level.
TFT.JokerRarityOddsByLevel = {
	[1] = { [1] = 1.00, [2] = 0.00, [3] = 0.00, [4] = 0.00, [5] = 0.00 },
	[2] = { [1] = 0.90, [2] = 0.10, [3] = 0.00, [4] = 0.00, [5] = 0.00 },
	[3] = { [1] = 0.75, [2] = 0.25, [3] = 0.00, [4] = 0.00, [5] = 0.00 },
	[4] = { [1] = 0.55, [2] = 0.30, [3] = 0.15, [4] = 0.00, [5] = 0.00 },
	[5] = { [1] = 0.45, [2] = 0.33, [3] = 0.20, [4] = 0.02, [5] = 0.00 },
	[6] = { [1] = 0.30, [2] = 0.30, [3] = 0.35, [4] = 0.05, [5] = 0.00 },
	[7] = { [1] = 0.19, [2] = 0.26, [3] = 0.40, [4] = 0.14, [5] = 0.01 },
	[8] = { [1] = 0.12, [2] = 0.18, [3] = 0.30, [4] = 0.35, [5] = 0.05 },
	[9] = { [1] = 0.07, [2] = 0.12, [3] = 0.20, [4] = 0.40, [5] = 0.21 },
	[10] = { [1] = 0.03, [2] = 0.07, [3] = 0.15, [4] = 0.40, [5] = 0.35 },
}

-- Rank multiplier curve (Rank 1 -> 2 -> 3) by power tier. Applied to whatever
-- numeric values a Joker already outputs when duplicate copies merge into a
-- single Ranked copy -- see joker-ranking.md.
TFT.PowerTierRankMultiplier = {
	[1] = { 1.0, 1.4, 2.0 },
	[2] = { 1.0, 1.6, 2.5 },
	[3] = { 1.0, 1.9, 3.2 },
	[4] = { 1.0, 2.4, 4.0 },
	[5] = { 1.0, 3.0, 6.0 },
}

-- Shared Joker Pool: copies of a given unique Joker available across the whole
-- lobby (snapshot-refreshed per shop-open, not live-decremented -- see
-- joker-ranking.md's "Confirmed: option 1" resolution: pool overrun is allowed,
-- no host-side validation). TFT's own Set 17 bag sizes, ported directly.
TFT.SharedJokerPoolSize = {
	[1] = 29,
	[2] = 22,
	[3] = 18,
	[4] = 10,
	[5] = 9,
}

-- Single global scaler applied to every pool size above, for easy retuning.
TFT.pool_size_scaler = 1.0

function TFT.shared_pool_size(power_tier)
	return math.floor((TFT.SharedJokerPoolSize[power_tier] or TFT.SharedJokerPoolSize[1]) * TFT.pool_size_scaler)
end

-- power_tier overrides for specific vanilla Jokers, keyed by their real vanilla
-- card key (verified against Balatro Source/localization/en-us.lua, not guessed
-- at -- note j_selzer, not j_seltzer, is Seltzer's real key, a vanilla typo).
-- Any vanilla Joker NOT listed here defaults 1:1 to its own vanilla `rarity`
-- field (Common=1, Uncommon=2, Rare=3, Legendary=5) -- see
-- TFT.get_power_tier below. This list is a curated allowlist, not a required
-- exhaustive audit (joker-ranking.md).
TFT.PowerTierOverrides = {
	-- Uncommon -> Uncommon (explicit, per joker-ranking.md's reclassification table)
	j_hanging_chad = TFT.PowerTier.UNCOMMON,
	j_mail = TFT.PowerTier.UNCOMMON, -- Mail-In Rebate
	j_ticket = TFT.PowerTier.UNCOMMON, -- Golden Ticket
	j_photograph = TFT.PowerTier.UNCOMMON,

	-- Pulled up to Rare
	j_mime = TFT.PowerTier.RARE,
	j_dusk = TFT.PowerTier.RARE,
	j_ancient = TFT.PowerTier.RARE, -- Ancient Joker
	j_bloodstone = TFT.PowerTier.RARE,
	j_duo = TFT.PowerTier.RARE, -- The Duo
	j_trio = TFT.PowerTier.RARE, -- The Trio
	j_family = TFT.PowerTier.RARE, -- The Family
	j_obelisk = TFT.PowerTier.RARE,
	j_drivers_license = TFT.PowerTier.RARE,
	j_vagabond = TFT.PowerTier.RARE,
	j_baseball = TFT.PowerTier.RARE, -- Baseball Card
	j_campfire = TFT.PowerTier.RARE,
	j_hit_the_road = TFT.PowerTier.RARE,
	j_order = TFT.PowerTier.RARE, -- The Order
	j_tribe = TFT.PowerTier.RARE, -- The Tribe
	j_stuntman = TFT.PowerTier.RARE,
	j_burnt = TFT.PowerTier.RARE, -- Burnt Joker
	j_selzer = TFT.PowerTier.RARE, -- Seltzer (real vanilla key is misspelled)

	-- Pulled up to Strong (previously vanilla-Rare)
	j_baron = TFT.PowerTier.STRONG,
	j_hack = TFT.PowerTier.STRONG,
	j_sock_and_buskin = TFT.PowerTier.STRONG,
	j_dna = TFT.PowerTier.STRONG,
	j_blueprint = TFT.PowerTier.STRONG,
	j_brainstorm = TFT.PowerTier.STRONG,
	j_invisible = TFT.PowerTier.STRONG,
	j_idol = TFT.PowerTier.STRONG, -- The Idol
}

local VANILLA_RARITY_TO_POWER_TIER = {
	[1] = TFT.PowerTier.COMMON,
	[2] = TFT.PowerTier.UNCOMMON,
	[3] = TFT.PowerTier.RARE,
	[4] = TFT.PowerTier.LEGENDARY, -- vanilla rarity 4 is Legendary (there is no vanilla 5)
}

-- Resolves a Joker's power_tier: explicit override first, else 1:1 from its
-- vanilla `rarity` field (works for both vanilla Jokers and any of our own new
-- Jokers that don't set power_tier explicitly on their SMODS.Joker definition).
function TFT.get_power_tier(card_key, vanilla_rarity)
	if TFT.PowerTierOverrides[card_key] then
		return TFT.PowerTierOverrides[card_key]
	end
	return VANILLA_RARITY_TO_POWER_TIER[vanilla_rarity] or TFT.PowerTier.COMMON
end

-- Every real, obtainable Joker key (vanilla + modded), grouped by power_tier.
-- Built lazily from G.P_CENTERS (not available until the game's actually
-- loaded run objects exist) and cached -- excludes banned Jokers
-- (domain/banned_jokers.lua) and our own internal Traits Engine pseudo-Joker.
TFT._jokers_by_power_tier = nil
function TFT.jokers_by_power_tier()
	if TFT._jokers_by_power_tier then return TFT._jokers_by_power_tier end
	local by_tier = { [1] = {}, [2] = {}, [3] = {}, [4] = {}, [5] = {} }
	for key, center in pairs(G.P_CENTERS or {}) do
		if center.set == 'Joker' and not TFT.is_joker_banned(key) and key ~= 'j_tft_traits_engine' then
			local tier = TFT.get_power_tier(key, center.rarity)
			table.insert(by_tier[tier], key)
		end
	end
	TFT._jokers_by_power_tier = by_tier
	return by_tier
end

-- A random Joker key with power_tier in [min_tier, max_tier] (inclusive),
-- falling back to the nearest non-empty tier if the requested range happens to
-- be empty (shouldn't normally happen given vanilla's own pool sizes, but
-- guards against a thin custom-content pool).
function TFT.random_joker_in_tier_range(min_tier, max_tier, seed)
	local by_tier = TFT.jokers_by_power_tier()
	local candidates = {}
	for tier = min_tier, max_tier do
		for _, key in ipairs(by_tier[tier] or {}) do
			table.insert(candidates, key)
		end
	end
	if #candidates == 0 then
		for tier = 1, 5 do
			for _, key in ipairs(by_tier[tier] or {}) do
				table.insert(candidates, key)
			end
		end
	end
	if #candidates == 0 then return nil end
	return pseudorandom_element(candidates, pseudoseed(seed or 'tft_carousel_joker'))
end
