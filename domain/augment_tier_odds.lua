-- Real TFT-sourced conditional Augment tier odds, ported directly from
-- architecture.md's "Augment Tier Odds" section. 3 checkpoints (rounds 2-1,
-- 3-2, 4-2 per the locked schedule). Tier is rolled, not guaranteed.
TFT.AugmentTier = { SILVER = 1, GOLD = 2, PRISMATIC = 3 }
TFT.AugmentTierName = { [1] = 'Silver', [2] = 'Gold', [3] = 'Prismatic' }
TFT.AugmentTierColour = {
	[1] = { 0.75, 0.75, 0.8, 1 }, -- Silver
	[2] = { 0.9, 0.7, 0.15, 1 }, -- Gold
	[3] = { 0.7, 0.35, 0.9, 1 }, -- Prismatic
}

-- Checkpoint 1 (Stage 2): base odds.
TFT.AugmentCheckpoint1Odds = { [1] = 0.28, [2] = 0.62, [3] = 0.10 }

-- Checkpoint 2 (Stage 4): conditional on Checkpoint 1's result.
TFT.AugmentCheckpoint2Odds = {
	[1] = { [1] = 0.36, [2] = 0.61, [3] = 0.03 }, -- prior was Silver
	[2] = { [1] = 0.32, [2] = 0.40, [3] = 0.28 }, -- prior was Gold
	[3] = { [1] = 0.50, [2] = 0.30, [3] = 0.20 }, -- prior was Prismatic
}

-- Checkpoint 3 (Stage 6... this mod's Stage 4 is checkpoint 3 per our locked
-- 2-1/3-2/4-2 schedule): conditional on Checkpoints 1 AND 2 together.
TFT.AugmentCheckpoint3Odds = {
	[1] = { [1] = { [1] = 0.50, [2] = 0.00, [3] = 0.50 }, [2] = { [1] = 0.00, [2] = 0.71, [3] = 0.29 }, [3] = { [1] = 0.00, [2] = 0.00, [3] = 1.00 } },
	[2] = { [1] = { [1] = 0.00, [2] = 0.90, [3] = 0.10 }, [2] = { [1] = 0.00, [2] = 0.88, [3] = 0.12 }, [3] = { [1] = 0.35, [2] = 0.59, [3] = 0.06 } },
	[3] = { [1] = { [1] = 0.00, [2] = 0.80, [3] = 0.20 }, [2] = { [1] = 0.00, [2] = 0.67, [3] = 0.33 }, [3] = { [1] = 0.00, [2] = 0.50, [3] = 0.50 } },
}

local function weighted_pick(odds_by_tier, seed)
	local roll = pseudorandom(seed)
	local cumulative = 0
	for tier = 1, 3 do
		cumulative = cumulative + (odds_by_tier[tier] or 0)
		if roll <= cumulative then return tier end
	end
	return 3
end

-- Rolls the tier for a given checkpoint_index (1/2/3), given the prior
-- checkpoints' already-rolled tiers (nil for checkpoint 1).
function TFT.roll_augment_tier(checkpoint_index, prior_tier_1, prior_tier_2, seed)
	if checkpoint_index == 1 then
		return weighted_pick(TFT.AugmentCheckpoint1Odds, seed or 'tft_aug_cp1')
	elseif checkpoint_index == 2 then
		local odds = TFT.AugmentCheckpoint2Odds[prior_tier_1 or 2]
		return weighted_pick(odds, seed or 'tft_aug_cp2')
	else
		local odds = TFT.AugmentCheckpoint3Odds[prior_tier_1 or 2][prior_tier_2 or 2]
		return weighted_pick(odds, seed or 'tft_aug_cp3')
	end
end
