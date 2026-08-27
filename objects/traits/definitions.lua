-- The 9-trait roster. Source: docs/design/traits.md. `breakpoints` is an ordered
-- list of owned-count thresholds; `effects[i]` describes (for our own reference/
-- debug text) what unlocks at breakpoints[i]. Ascendants has no static tag list
-- here -- membership is computed at runtime from power_tier (see
-- domain/rarity_odds.lua), not hand-tagged, per joker-ranking.md.
TFT.Traits = {
	Financiers = { breakpoints = { 2, 4, 6 } },
	Scholars = { breakpoints = { 2, 4, 6 } },
	SpadesGuild = { breakpoints = { 2, 3 } },
	ClubsGuild = { breakpoints = { 2, 3 } },
	DiamondsGuild = { breakpoints = { 2, 3 } },
	HeartsGuild = { breakpoints = { 2, 3 } },
	Multipliers = { breakpoints = { 2, 4, 6 } },
	Scalers = { breakpoints = { 2, 4, 6, 8, 10 } },
	Encore = { breakpoints = { 2, 4, 6 } },
	Ascendants = { breakpoints = { 2, 5, 8, 10 } },
}

-- Given a trait's breakpoint list and an owned count, returns the highest
-- breakpoint index reached (0 if none), i.e. how many tiers of that trait's
-- effect currently apply.
function TFT.trait_tier_reached(trait_key, count)
	local trait = TFT.Traits[trait_key]
	if not trait then return 0 end
	local tier = 0
	for i, threshold in ipairs(trait.breakpoints) do
		if count >= threshold then tier = i end
	end
	return tier
end
