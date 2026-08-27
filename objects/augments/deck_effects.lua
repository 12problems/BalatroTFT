-- Deck & Cards category augments -- physical playing-card manipulation, all
-- operating on G.playing_cards (the real, flat array of every card in the
-- player's deck this run, confirmed against button_callbacks.lua's own
-- `table.insert(G.playing_cards, c1)` on card purchase). Real vanilla Card
-- methods used throughout (set_ability/set_edition/set_seal/Card:is_suit) --
-- no custom card-state reimplementation.

local ENHANCEMENT_KEYS = { 'm_bonus', 'm_mult', 'm_wild', 'm_glass', 'm_steel', 'm_stone', 'm_gold', 'm_lucky' }
local EDITION_KEYS = { 'foil', 'holo', 'polychrome' } -- negative excluded: a downgrade-feeling roll for a "random edition" reward
local SEAL_NAMES = { 'Red', 'Blue', 'Gold', 'Purple' }
-- G.P_CARDS keys are compact vanilla card codes: single-letter suit prefix +
-- underscore + rank ('T' for ten, not '10') -- confirmed against card.lua's
-- own Strength-tarot implementation (`suit_prefix..rank_suffix`,
-- `string.sub(card.base.suit, 1, 1)..'_'`), NOT the full suit name I first
-- assumed. SUIT_NAMES keeps the real, full vanilla suit name (needed
-- elsewhere, e.g. Card:is_suit checks), SUIT_PREFIX maps it to the P_CARDS
-- key prefix.
local SUIT_NAMES = { 'Spades', 'Hearts', 'Clubs', 'Diamonds' }
local SUIT_PREFIX = { Spades = 'S', Hearts = 'H', Clubs = 'C', Diamonds = 'D' }
local RANK_KEYS = { '2', '3', '4', '5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K', 'A' }

local function p_card(suit_name, rank_key)
	return G.P_CARDS[SUIT_PREFIX[suit_name] .. '_' .. rank_key]
end

-- Fisher-Yates over a shallow index list, seeded off the game's own
-- pseudorandom so augment rolls are reproducible per-seed like everything
-- else in this mod, not love.math.random.
local function shuffled_indices(n, seed)
	local idx = {}
	for i = 1, n do idx[i] = i end
	for i = n, 2, -1 do
		local j = math.floor(pseudorandom(seed .. i) * i) + 1
		idx[i], idx[j] = idx[j], idx[i]
	end
	return idx
end

function TFT.remove_random_deck_cards(count)
	if not G.playing_cards or #G.playing_cards == 0 then return end
	local n = math.min(count, #G.playing_cards)
	local idx = shuffled_indices(#G.playing_cards, 'tft_thin_herd' .. G.GAME.round_resets.ante)
	local to_remove = {}
	for i = 1, n do to_remove[#to_remove + 1] = G.playing_cards[idx[i]] end
	for _, card in ipairs(to_remove) do
		if card.area then card.area:remove_card(card) end
		for i = #G.playing_cards, 1, -1 do
			if G.playing_cards[i] == card then table.remove(G.playing_cards, i) end
		end
		card:remove()
	end
end

-- count = nil means "every eligible card" (Alchemist's Dream); a number means
-- "that many random eligible cards" (Lucky Break).
function TFT.enhance_random_deck_cards(count)
	if not G.playing_cards then return end
	-- "No enhancement yet" = the card's real center is still the plain 'c_base'
	-- Playing Card center (set_ability sets self.config.center to whatever
	-- center is applied, base included) -- checking that field directly rather
	-- than a specific effect name, since 'c_base' is the one real key common
	-- to every un-enhanced playing card, unlike enumerating every possible
	-- enhancement effect name to exclude.
	local eligible = {}
	for _, card in ipairs(G.playing_cards) do
		if card.config and card.config.center and card.config.center.key == 'c_base' then
			table.insert(eligible, card)
		end
	end
	if #eligible == 0 then return end
	local n = count and math.min(count, #eligible) or #eligible
	local idx = shuffled_indices(#eligible, 'tft_lucky_break' .. G.GAME.round_resets.ante)
	for i = 1, n do
		local card = eligible[idx[i]]
		local key = pseudorandom_element(ENHANCEMENT_KEYS, pseudoseed('tft_enh' .. i .. G.GAME.round_resets.ante))
		local center = G.P_CENTERS[key]
		if center then card:set_ability(center) end
	end
end

-- count = nil means "every card" (Gilded Deck, overwrite = true); a number
-- means "that many random cards without an existing Edition" (Fresh Coat).
function TFT.edition_random_deck_cards(count, overwrite)
	if not G.playing_cards then return end
	local eligible = {}
	for _, card in ipairs(G.playing_cards) do
		if overwrite or not card.edition then table.insert(eligible, card) end
	end
	if #eligible == 0 then return end
	local n = count and math.min(count, #eligible) or #eligible
	local idx = shuffled_indices(#eligible, 'tft_fresh_coat' .. G.GAME.round_resets.ante)
	for i = 1, n do
		local card = eligible[idx[i]]
		local key = pseudorandom_element(EDITION_KEYS, pseudoseed('tft_edi' .. i .. G.GAME.round_resets.ante))
		card:set_edition({ [key] = true }, true)
	end
end

function TFT.seal_random_deck_cards()
	if not G.playing_cards or #G.playing_cards == 0 then return end
	local n = math.min(4, #G.playing_cards)
	local idx = shuffled_indices(#G.playing_cards, 'tft_seal_deal' .. G.GAME.round_resets.ante)
	for i = 1, n do
		G.playing_cards[idx[i]]:set_seal(SEAL_NAMES[i], true)
	end
end

-- card.base.id ranges 2-14 (14 = Ace) -- confirmed against card.lua's own
-- Strength-tarot rank-shift code, which builds its target key from this exact
-- id, not from any display/localized value field.
local function rank_key_from_id(id)
	if id == 14 then return 'A' end
	if id == 13 then return 'K' end
	if id == 12 then return 'Q' end
	if id == 11 then return 'J' end
	if id == 10 then return 'T' end
	return tostring(id)
end

function TFT.reshuffle_deck_ranks_suits()
	if not G.playing_cards then return end
	for i, card in ipairs(G.playing_cards) do
		local rank = pseudorandom_element(RANK_KEYS, pseudoseed('tft_reshuffle_r' .. i .. G.GAME.round_resets.ante))
		local suit = pseudorandom_element(SUIT_NAMES, pseudoseed('tft_reshuffle_s' .. i .. G.GAME.round_resets.ante))
		if card.set_base then card:set_base(p_card(suit, rank) or card.base) end
	end
end

function TFT.random_suit()
	return pseudorandom_element(SUIT_NAMES, pseudoseed('tft_suit_yourself' .. G.GAME.round_resets.ante))
end

function TFT.set_deck_suit(suit)
	if not G.playing_cards then return end
	for _, card in ipairs(G.playing_cards) do
		if card.base and card.set_base then
			local target = p_card(suit, rank_key_from_id(card.base.id))
			if target then card:set_base(target) end
		end
	end
end

function TFT.set_deck_rank_suit(rank, suit)
	if not G.playing_cards then return end
	local target = p_card(suit, rank == 'King' and 'K' or rank)
	if not target then return end
	for _, card in ipairs(G.playing_cards) do
		if card.set_base then card:set_base(target) end
	end
end

function TFT.odd_couple_deck()
	if not G.playing_cards then return end
	for i, card in ipairs(G.playing_cards) do
		local roll = pseudorandom(pseudoseed('tft_odd_couple' .. i .. G.GAME.round_resets.ante))
		local target = roll < 0.5 and p_card('Clubs', '2') or p_card('Hearts', 'K')
		if target and card.set_base then card:set_base(target) end
	end
end

-- 5 Negative Auras (Tarot). Negative consumables aren't consumed on use in
-- this build (ASSUMPTION, flagged consistent with augments.md's own note --
-- not independently re-verified against current source this pass). Overflow
-- past available consumable slots is simply dropped -- augments.md flags this
-- exact question as open and unresolved; "drop the overflow" is the least
-- surprising default (no forced sell, no blocked grant) until a real decision
-- is made.
function TFT.grant_negative_auras(count)
	if not G.consumeables then return end
	for i = 1, count do
		if #G.consumeables.cards >= G.consumeables.config.card_limit then break end
		local card = create_card('Tarot', G.consumeables, nil, nil, nil, nil, 'c_aura')
		card:add_to_deck()
		card:set_edition({ negative = true }, true)
		G.consumeables:emplace(card)
	end
end

-- Everything's Wild: global suit-equivalence, same technique vanilla's own
-- Smeared Joker uses (Card:is_suit already special-cases Smeared Joker
-- exactly this way -- see card.lua) -- extended here to ALL suits at once
-- rather than just merging Hearts/Diamonds and Spades/Clubs, so it never
-- overwrites or conflicts with a card's real Enhancement (unlike applying a
-- literal Wild Card enhancement to every card would).
local _tft_orig_is_suit = Card.is_suit
function Card:is_suit(suit, bypass_debuff, flush_calc)
	if TFT.is_run_active() and TFT.has_augment and TFT.has_augment('everythings_wild') then
		if self.debuff and not bypass_debuff then return end
		if self.ability.effect == 'Stone Card' then return false end
		return true
	end
	return _tft_orig_is_suit(self, suit, bypass_debuff, flush_calc)
end
