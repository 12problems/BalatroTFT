-- Leveling: XP costs and per-level passive benefits. Source: architecture.md's
-- "Leveling & XP" and "Per-Level Passive Benefits" sections -- first-draft
-- numbers, flagged there for a playtesting pass, transcribed as-is.

TFT.XP_LEVEL_CAP = 10
TFT.PASSIVE_XP_PER_ROUND = 2

-- Buy XP: base $4 for 4 XP, +$1 per additional Buy XP action taken *that round*,
-- resetting to base at the start of the next round (mirrors vanilla's own reroll
-- cost-scaling precedent).
TFT.BUY_XP_BASE_COST = 4
TFT.BUY_XP_AMOUNT = 4
TFT.BUY_XP_COST_INCREMENT = 1

-- XP cost to go FROM (level-1) TO level, i.e. TFT.XPCost[4] is the cost of the
-- 3->4 transition. Level 1 has no entry (starting level, costs nothing).
TFT.XPCost = {
	[2] = 4,
	[3] = 2,
	[4] = 10,
	[5] = 14,
	[6] = 16,
	[7] = 16,
	[8] = 30,
	[9] = 40,
	[10] = 55,
}

-- Cumulative passive-XP total required to REACH a given level from level 1,
-- derived from TFT.XPCost rather than hand-transcribed a second time (avoids the
-- two tables silently drifting out of sync).
TFT.XPCumulative = { [1] = 0 }
do
	local running = 0
	for level = 2, TFT.XP_LEVEL_CAP do
		running = running + TFT.XPCost[level]
		TFT.XPCumulative[level] = running
	end
end

-- Given a total XP amount, returns the level it corresponds to (capped at
-- TFT.XP_LEVEL_CAP) and the XP progress into the next level.
function TFT.level_for_xp(total_xp)
	local level = 1
	for l = 2, TFT.XP_LEVEL_CAP do
		if total_xp >= TFT.XPCumulative[l] then
			level = l
		else
			break
		end
	end
	local into_next = total_xp - TFT.XPCumulative[level]
	local needed_for_next = (level < TFT.XP_LEVEL_CAP) and TFT.XPCost[level + 1] or 0
	return level, into_next, needed_for_next
end

-- Per-level passive benefits, every player gets these just from leveling
-- (separate from Trait/Augment bonuses). `money_per_round` entries are additive
-- and cumulative across levels (level 5's +$5 and level 8's +$5 both apply once
-- a player has reached level 8, for +$10/round total) -- summed at read time via
-- TFT.passive_money_per_round below rather than restating the running total here,
-- so this table only ever states each level's own new bonus.
TFT.LevelBenefits = {
	[2] = { hands_played = 1 },
	[3] = { discards = 1 },
	[4] = { hand_size = 1 },
	[5] = { voucher_choice_tier1_count = 1, money_per_round = 5 },
	[6] = { consumable_slots = 1 },
	[7] = { joker_slots = 1 },
	[8] = { deck_refinement_remove_up_to = 5, money_per_round = 5 },
	[9] = { voucher_choice_level9 = true }, -- resolved at pick time: 2 tier-2 upgrades OR 3 fresh tier-1 vouchers
	[10] = { joker_slots = 1, consumable_slots = 1, legendary_shop_odds_unlocked = true },
}

-- Sums every money_per_round bonus unlocked at or below `level`.
function TFT.passive_money_per_round(level)
	local total = 0
	for l = 2, level do
		local benefit = TFT.LevelBenefits[l]
		if benefit and benefit.money_per_round then
			total = total + benefit.money_per_round
		end
	end
	return total
end

-- Sums a non-money additive stat (hand_size, hands_played, discards, joker_slots,
-- consumable_slots) unlocked at or below `level`.
function TFT.passive_stat_total(level, stat_key)
	local total = 0
	for l = 2, level do
		local benefit = TFT.LevelBenefits[l]
		if benefit and benefit[stat_key] then
			total = total + benefit[stat_key]
		end
	end
	return total
end
