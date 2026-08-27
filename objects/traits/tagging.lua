-- Vanilla-Joker -> trait-tag membership, keyed by the real vanilla card key
-- (verified against Balatro Source/localization/en-us.lua, not guessed at).
--
-- ASSUMPTION (flagged): traits.md gives population COUNTS per trait (e.g.
-- "Financiers ~10-12") but never an exact enumerated vanilla-Joker list except
-- for the Suit Guilds' one named legacy Joker each and Encore's explicit 6.
-- Everywhere else below, I picked a specific, real, thematically-defensible set
-- of vanilla Jokers myself to reach a working roster -- this is my own content
-- call, not a transcription of something the docs specified, and is worth a
-- review pass rather than treated as locked.
--
-- A Joker can carry more than one tag (see traits.md's "Multi-Trait Jokers").
TFT.TraitTagsByJokerKey = {
	-- Financiers (Economy) -- doc: ~10-12 natural candidates
	j_golden = { 'Financiers' },
	j_rocket = { 'Financiers' },
	j_egg = { 'Financiers' },
	j_satellite = { 'Financiers' },
	j_bull = { 'Financiers' },
	j_business = { 'Financiers' },
	j_cloud_9 = { 'Financiers' },
	j_delayed_grat = { 'Financiers' },
	j_reserved_parking = { 'Financiers' },
	j_todo_list = { 'Financiers' },

	-- Scholars (Consumable-synergy) -- doc: ~7-8 natural, buffered to ~10-11 by
	-- new-jokers.md's Scholars buffer (see objects/jokers/scholars.lua)
	j_astronomer = { 'Scholars' },
	j_sixth_sense = { 'Scholars' },
	j_constellation = { 'Scholars', 'Multipliers', 'Scalers' }, -- Planet-triggered AND permanently accumulating xMult
	j_vagabond = { 'Scholars' }, -- already Rare/Ascendants via power_tier -- multi-trait

	-- Suit Guilds -- doc names exactly one legacy vanilla Joker each; the rest of
	-- each pool comes from objects/jokers/suit_guilds.lua's new custom Jokers.
	j_wrathful_joker = { 'SpadesGuild' },
	j_gluttenous_joker = { 'ClubsGuild' },
	j_greedy_joker = { 'DiamondsGuild' },
	j_lusty_joker = { 'HeartsGuild' },
	j_bloodstone = { 'HeartsGuild', 'Multipliers' }, -- explicit multi-trait call in traits.md

	-- Multipliers (xMult-granting) -- doc: "very healthy", ~12-14
	j_hologram = { 'Multipliers', 'Scalers' }, -- permanently accumulates xMult per card added
	j_blackboard = { 'Multipliers' },
	j_vampire = { 'Multipliers', 'Scalers' }, -- permanently accumulates xMult, removes enhancements
	j_cavendish = { 'Multipliers' },
	j_supernova = { 'Multipliers' },

	-- Scalers (permanently grow/scale) -- doc: best-populated, ~15-17
	j_obelisk = { 'Scalers' },
	j_campfire = { 'Scalers' },
	j_castle = { 'Scalers' },
	j_trousers = { 'Scalers' }, -- Spare Trousers
	j_ride_the_bus = { 'Scalers' },
	j_green_joker = { 'Scalers' },
	j_red_card = { 'Scalers' },
	j_fortune_teller = { 'Scalers' },
	j_ceremonial = { 'Scalers' },
	j_flash = { 'Scalers' }, -- Flash Card

	-- Encore (retrigger) -- doc's explicit, exact population of 6, no slack
	j_hack = { 'Encore' },
	j_sock_and_buskin = { 'Encore' },
	j_selzer = { 'Encore' }, -- Seltzer (real vanilla key is misspelled)
	j_dusk = { 'Encore' },
	j_hanging_chad = { 'Encore' },
	j_mime = { 'Encore' },
}

-- Returns the full set of trait tags a Joker card currently carries: explicit
-- vanilla tagging above, any tag a new custom Joker declares directly on its own
-- SMODS definition (config.trait_tags), plus the automatic Ascendants tag for
-- any Joker whose power_tier is Rare/Strong/Legendary (joker-ranking.md).
function TFT.get_trait_tags(card)
	if not card or not card.config or not card.config.center then return {} end
	local key = card.config.center.key
	local tags = {}

	for _, t in ipairs(TFT.TraitTagsByJokerKey[key] or {}) do
		tags[#tags + 1] = t
	end

	-- New custom Jokers declare tags directly on their own SMODS.Joker
	-- definition (see objects/jokers/*.lua's `trait_tags` field), rather than
	-- needing an entry in the table above.
	local own_tags = card.config.center.trait_tags
	if own_tags then
		for _, t in ipairs(own_tags) do
			tags[#tags + 1] = t
		end
	end

	local power_tier = TFT.get_power_tier(key, card.config.center.rarity)
	if power_tier >= TFT.PowerTier.RARE then
		tags[#tags + 1] = 'Ascendants'
	end

	-- Apprentice's Charm (Silver, Trait & Emblem): one specific Joker also
	-- counts as having a chosen trait -- stored ON that card (stays attached
	-- through the run, gone if the card is sold, matching augments.md's own
	-- wording), not on shared state.
	if card.ability and card.ability.tft_extra_trait_tags then
		for _, t in ipairs(card.ability.tft_extra_trait_tags) do
			tags[#tags + 1] = t
		end
	end

	-- Grand Emblem (Prismatic, Trait & Emblem): every Joker owned OR acquired
	-- for the rest of the run counts as having the chosen trait -- modeled as
	-- a blanket addition read live from state here (applies automatically to
	-- every future acquisition too, with zero extra bookkeeping needed per
	-- card), rather than stamping every existing AND future card individually.
	local state = TFT.get_state()
	if state and state.grand_emblem_target and key ~= 'j_tft_traits_engine' then
		tags[#tags + 1] = state.grand_emblem_target
	end

	return tags
end

-- Trait Heart (Gold, Trait & Emblem): a chosen trait's owned-count is treated
-- as +2 higher than actual, for breakpoint purposes only -- applied in
-- TFT.count_trait_tags (engine.lua) after the real per-card scan, so it never
-- affects the Ascendants/Scalers auto-tagging or trait-tagged Joker lists
-- themselves, only the final tier lookup.
function TFT.trait_heart_bonus(trait_key)
	local state = TFT.get_state()
	if state and state.trait_heart_target == trait_key then return 2 end
	return 0
end

-- Shared "choose a trait" roll for Apprentice's Charm/Trait Heart/Grand
-- Emblem -- ASSUMPTION (flagged repeatedly at each call site too): rolls a
-- random trait from ALL traits (matching augments.md's own "random subset of
-- 4" framing loosely -- picks 1 of the full roster rather than building a
-- dedicated 4-option sub-picker UI for these three augments specifically,
-- consistent with this pass's scope-down on every "choose X" augment -- see
-- objects/augments/definitions.lua's closing note).
function TFT.random_trait_key(opts)
	opts = opts or {}
	local exclude = opts.exclude or {}
	local candidates = {}
	for trait_key, _ in pairs(TFT.Traits) do
		if not exclude[trait_key] then table.insert(candidates, trait_key) end
	end
	table.sort(candidates) -- stable order before the seeded shuff-pick, so the
	-- same seed always yields the same result regardless of pairs() iteration order
	if #candidates == 0 then return nil end
	return pseudorandom_element(candidates, pseudoseed('tft_trait_choice' .. G.GAME.round_resets.ante))
end

-- Apprentice's Charm's apply(): picks a random trait AND a random currently-
-- owned Joker to attach it to (both auto-rolled, see TFT.random_trait_key's
-- own note). No-ops harmlessly if the player owns no eligible Jokers yet
-- (the Traits Engine pseudo-Joker is always present but excluded).
function TFT.grant_random_extra_trait_tag()
	if not G.jokers or not G.jokers.cards then return end
	local eligible = {}
	for _, c in ipairs(G.jokers.cards) do
		if c.config and c.config.center and c.config.center.key ~= 'j_tft_traits_engine' then
			table.insert(eligible, c)
		end
	end
	if #eligible == 0 then return end
	local target_card = pseudorandom_element(eligible, pseudoseed('tft_apprentices_charm_card' .. G.GAME.round_resets.ante))
	local trait_key = TFT.random_trait_key()
	if not trait_key then return end
	target_card.ability.tft_extra_trait_tags = target_card.ability.tft_extra_trait_tags or {}
	table.insert(target_card.ability.tft_extra_trait_tags, trait_key)
end

-- Convenience for the single-tag membership checks the Multipliers/Scalers
-- hooks (objects/traits/engine.lua) need on every Card:calculate_joker call --
-- avoids each call site re-building the full tag list just to test one key.
function TFT.card_has_trait_tag(card, tag)
	for _, t in ipairs(TFT.get_trait_tags(card)) do
		if t == tag then return true end
	end
	return false
end
