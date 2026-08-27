-- Suit Guild content debt: new-jokers.md's 16 new Jokers (+3 Spades, +3 Clubs,
-- +4 Diamonds, +2 Hearts... doc's own count says +2 Hearts even though it also
-- lists Bloodstone as a "bringing the pool to 5" note -- Bloodstone itself is
-- vanilla, tagged in objects/traits/tagging.lua, not redefined here).
--
-- Rarity: 1=Common, 2=Uncommon, 3=Rare (SMODS numeric rarity).
-- `trait_tags` is this mod's own field (read by objects/traits/tagging.lua's
-- TFT.get_trait_tags), not a SMODS-native one.
--
-- Hearts Guild's life-total effects (Field Medic, The Nurse's Aide) reference
-- TFT.get_state().life_total, which nothing else sets yet this session (life
-- total is PvP/multiplayer-scope, scaffolded but not tested this session per
-- the session's own scope decision) -- shape is correct, effect is UNTESTED in
-- practice since there's no live life total to observe it against.

-- ===== Spades Guild =====

SMODS.Joker {
	key = 'ace_of_spades',
	trait_tags = { 'SpadesGuild' },
	loc_txt = {
		name = 'Ace of Spades',
		text = { 'Played {C:spades}Spade{} {C:attention}Aces{} give', '{C:chips}+200 Chips{} when scored' },
	},
	rarity = 2, cost = 4,
	unlocked = true, discovered = true, blueprint_compat = true, eternal_compat = true,
	pos = { x = 0, y = 0 }, atlas = 'Joker', -- see traits/engine.lua's atlas-bug comment; 'ChangeStake' isn't real
	prefix_config = { atlas = false }, -- opt out of atlas-prefixing (SMODS default), 'Joker' is vanilla's real unprefixed atlas key
	calculate = function(self, card, context)
		if context.individual and context.cardarea == G.play and context.other_card then
			local base = context.other_card.base
			if base and base.suit == 'Spades' and base.value == 'Ace' then
				return { chips = 200, message = localize('k_chips_ex') }
			end
		end
	end,
}

SMODS.Joker {
	key = 'spade_fisher',
	trait_tags = { 'SpadesGuild' },
	loc_txt = {
		name = 'Spade Fisher',
		text = { '{C:mult}+5 Mult{} if played hand', 'contains {C:spades}3 or more Spades{}' },
	},
	rarity = 1, cost = 5,
	unlocked = true, discovered = true, blueprint_compat = true, eternal_compat = true,
	pos = { x = 0, y = 0 }, atlas = 'Joker', -- see traits/engine.lua's atlas-bug comment; 'ChangeStake' isn't real
	prefix_config = { atlas = false }, -- opt out of atlas-prefixing (SMODS default), 'Joker' is vanilla's real unprefixed atlas key
	calculate = function(self, card, context)
		if context.joker_main then
			local count = 0
			for _, c in ipairs(context.full_hand or {}) do
				if c.base and c.base.suit == 'Spades' then count = count + 1 end
			end
			if count >= 3 then
				return { mult = 5, message = localize('k_mult_ex') }
			end
		end
	end,
}

SMODS.Joker {
	key = 'pike_commander',
	trait_tags = { 'SpadesGuild', 'Scalers' },
	loc_txt = {
		name = 'Pike Commander',
		text = { '{C:spades}Spade{} cards permanently gain', '{C:chips}+3 Chips{} each time they score' },
	},
	rarity = 3, cost = 8,
	unlocked = true, discovered = true, blueprint_compat = true, eternal_compat = true,
	pos = { x = 0, y = 0 }, atlas = 'Joker', -- see traits/engine.lua's atlas-bug comment; 'ChangeStake' isn't real
	prefix_config = { atlas = false }, -- opt out of atlas-prefixing (SMODS default), 'Joker' is vanilla's real unprefixed atlas key
	config = { extra = { chip_bonus = 0 } },
	calculate = function(self, card, context)
		if context.individual and context.cardarea == G.play and context.other_card then
			local base = context.other_card.base
			if base and base.suit == 'Spades' then
				card.ability.extra.chip_bonus = card.ability.extra.chip_bonus + 3
				return { chips = card.ability.extra.chip_bonus, message = localize('k_chips_ex') }
			end
		end
	end,
}

-- ===== Clubs Guild =====

SMODS.Joker {
	key = 'lucky_clover',
	trait_tags = { 'ClubsGuild' },
	loc_txt = {
		name = 'Lucky Clover',
		text = { '1 in 4 chance a scored', '{C:clubs}Club{} gives {C:money}+$2{}' },
	},
	rarity = 1, cost = 4,
	unlocked = true, discovered = true, blueprint_compat = true, eternal_compat = true,
	pos = { x = 0, y = 0 }, atlas = 'Joker', -- see traits/engine.lua's atlas-bug comment; 'ChangeStake' isn't real
	prefix_config = { atlas = false }, -- opt out of atlas-prefixing (SMODS default), 'Joker' is vanilla's real unprefixed atlas key
	calculate = function(self, card, context)
		if context.individual and context.cardarea == G.play and context.other_card then
			local base = context.other_card.base
			if base and base.suit == 'Clubs' and pseudorandom('lucky_clover') < 0.25 then
				return { dollars = 2, message = localize('k_plus_dollars') }
			end
		end
	end,
}

SMODS.Joker {
	key = 'clover_field',
	trait_tags = { 'ClubsGuild' },
	loc_txt = {
		name = 'Clover Field',
		text = { 'If {C:clubs}3+ Clubs{} held in hand', 'at round end, {C:attention}+1 discard{} next round' },
	},
	rarity = 2, cost = 6,
	unlocked = true, discovered = true, blueprint_compat = true, eternal_compat = true,
	pos = { x = 0, y = 0 }, atlas = 'Joker', -- see traits/engine.lua's atlas-bug comment; 'ChangeStake' isn't real
	prefix_config = { atlas = false }, -- opt out of atlas-prefixing (SMODS default), 'Joker' is vanilla's real unprefixed atlas key
	calculate = function(self, card, context)
		if context.end_of_round and not context.blueprint and G.hand then
			local count = 0
			for _, c in ipairs(G.hand.cards or {}) do
				if c.base and c.base.suit == 'Clubs' then count = count + 1 end
			end
			if count >= 3 then
				G.GAME.round_resets.discards = (G.GAME.round_resets.discards or 0) + 1
			end
		end
	end,
}

SMODS.Joker {
	key = 'the_cudgel',
	trait_tags = { 'ClubsGuild' },
	loc_txt = {
		name = 'The Cudgel',
		text = { '{X:mult,C:white}X1.2{} Mult if the final hand', 'played this round contains a {C:clubs}Club{}' },
	},
	rarity = 3, cost = 8,
	unlocked = true, discovered = true, blueprint_compat = true, eternal_compat = true,
	pos = { x = 0, y = 0 }, atlas = 'Joker', -- see traits/engine.lua's atlas-bug comment; 'ChangeStake' isn't real
	prefix_config = { atlas = false }, -- opt out of atlas-prefixing (SMODS default), 'Joker' is vanilla's real unprefixed atlas key
	calculate = function(self, card, context)
		if context.joker_main and G.GAME.current_round.hands_left == 0 then
			for _, c in ipairs(context.full_hand or {}) do
				if c.base and c.base.suit == 'Clubs' then
					return { x_mult = 1.2, message = localize('k_mult_ex') }
				end
			end
		end
	end,
}

-- ===== Diamonds Guild =====

SMODS.Joker {
	key = 'petty_thief',
	trait_tags = { 'DiamondsGuild' },
	loc_txt = {
		name = 'Petty Thief',
		text = { 'Playing a pair of {C:diamonds}Diamond{} cards', 'gives you {C:money}$3{}' },
	},
	rarity = 1, cost = 4,
	unlocked = true, discovered = true, blueprint_compat = true, eternal_compat = true,
	pos = { x = 0, y = 0 }, atlas = 'Joker', -- see traits/engine.lua's atlas-bug comment; 'ChangeStake' isn't real
	prefix_config = { atlas = false }, -- opt out of atlas-prefixing (SMODS default), 'Joker' is vanilla's real unprefixed atlas key
	calculate = function(self, card, context)
		if context.joker_main and next(context.poker_hands['Pair'] or {}) then
			local diamonds = 0
			for _, c in ipairs(context.scoring_hand or {}) do
				if c.base and c.base.suit == 'Diamonds' then diamonds = diamonds + 1 end
			end
			if diamonds >= 2 then
				return { dollars = 3, message = localize('k_plus_dollars') }
			end
		end
	end,
}

SMODS.Joker {
	key = 'diamond_dealer',
	trait_tags = { 'DiamondsGuild' },
	loc_txt = {
		name = 'Diamond Dealer',
		text = { 'End of round: {C:money}+$1{} per', '{C:diamonds}Diamond{} held in hand' },
	},
	rarity = 1, cost = 5,
	unlocked = true, discovered = true, blueprint_compat = true, eternal_compat = true,
	pos = { x = 0, y = 0 }, atlas = 'Joker', -- see traits/engine.lua's atlas-bug comment; 'ChangeStake' isn't real
	prefix_config = { atlas = false }, -- opt out of atlas-prefixing (SMODS default), 'Joker' is vanilla's real unprefixed atlas key
	calculate = function(self, card, context)
		if context.end_of_round and not context.blueprint and G.hand then
			local count = 0
			for _, c in ipairs(G.hand.cards or {}) do
				if c.base and c.base.suit == 'Diamonds' then count = count + 1 end
			end
			if count > 0 then
				return { dollars = count, message = localize('k_plus_dollars') }
			end
		end
	end,
}

SMODS.Joker {
	key = 'appraiser',
	trait_tags = { 'DiamondsGuild' },
	loc_txt = {
		name = 'Appraiser',
		text = { 'Selling a Joker while holding', '{C:diamonds}2+ Diamonds{} gives {X:mult,C:white}+200%{} sell value' },
	},
	rarity = 2, cost = 6,
	unlocked = true, discovered = true, blueprint_compat = true, eternal_compat = true,
	pos = { x = 0, y = 0 }, atlas = 'Joker', -- see traits/engine.lua's atlas-bug comment; 'ChangeStake' isn't real
	prefix_config = { atlas = false }, -- opt out of atlas-prefixing (SMODS default), 'Joker' is vanilla's real unprefixed atlas key
	calc_dollar_bonus = function(self, card)
		local count = 0
		for _, c in ipairs(G.hand and G.hand.cards or {}) do
			if c.base and c.base.suit == 'Diamonds' then count = count + 1 end
		end
		if count >= 2 then
			return card.sell_cost * 2 -- +200% of the card being sold's own sell value
		end
	end,
}

SMODS.Joker {
	key = 'kimberley_baron',
	trait_tags = { 'DiamondsGuild', 'Financiers' },
	loc_txt = {
		name = 'Kimberley Baron',
		text = { 'Selling this Joker permanently', 'raises the {C:money}interest cap{} by the number of', '{C:diamonds}Diamonds{} held in hand when sold' },
	},
	rarity = 3, cost = 9,
	unlocked = true, discovered = true, blueprint_compat = true, eternal_compat = true,
	pos = { x = 0, y = 0 }, atlas = 'Joker', -- see traits/engine.lua's atlas-bug comment; 'ChangeStake' isn't real
	prefix_config = { atlas = false }, -- opt out of atlas-prefixing (SMODS default), 'Joker' is vanilla's real unprefixed atlas key
	-- Applying the actual interest-cap raise needs the Financiers interest hook
	-- (not wired this session, see traits/engine.lua's scope note) -- this only
	-- records the intent so that future hook can read it.
	calculate = function(self, card, context)
		if context.selling_card == card then
			local count = 0
			for _, c in ipairs(G.hand and G.hand.cards or {}) do
				if c.base and c.base.suit == 'Diamonds' then count = count + 1 end
			end
			G.GAME.tft_state = G.GAME.tft_state or {}
			G.GAME.tft_state.interest_cap_bonus = (G.GAME.tft_state.interest_cap_bonus or 0) + count
		end
	end,
}

-- ===== Hearts Guild =====

SMODS.Joker {
	key = 'field_medic',
	trait_tags = { 'HeartsGuild' },
	loc_txt = {
		name = 'Field Medic',
		text = { 'Heal {C:red}1 life{} when a {C:hearts}Heart{} scores,', 'capped at {C:attention}3{} heals per round' },
	},
	rarity = 1, cost = 4,
	unlocked = true, discovered = true, blueprint_compat = true, eternal_compat = true,
	pos = { x = 0, y = 0 }, atlas = 'Joker', -- see traits/engine.lua's atlas-bug comment; 'ChangeStake' isn't real
	prefix_config = { atlas = false }, -- opt out of atlas-prefixing (SMODS default), 'Joker' is vanilla's real unprefixed atlas key
	config = { extra = { healed_this_round = 0 } },
	calculate = function(self, card, context)
		if context.individual and context.cardarea == G.play and context.other_card then
			local base = context.other_card.base
			if base and base.suit == 'Hearts' and card.ability.extra.healed_this_round < 3 then
				card.ability.extra.healed_this_round = card.ability.extra.healed_this_round + 1
				local state = TFT.get_state()
				if state then state.life_total = (state.life_total or 100) + 1 end
				return { message = '+1 Life' }
			end
		end
		if context.end_of_round and not context.blueprint then
			card.ability.extra.healed_this_round = 0
		end
	end,
}

SMODS.Joker {
	key = 'cardiologist',
	trait_tags = { 'HeartsGuild' },
	loc_txt = {
		name = 'Cardiologist',
		text = { 'Heal {C:red}2 life{} at the', 'end of every round' },
	},
	rarity = 2, cost = 6,
	unlocked = true, discovered = true, blueprint_compat = true, eternal_compat = true,
	pos = { x = 0, y = 0 }, atlas = 'Joker', -- see traits/engine.lua's atlas-bug comment; 'ChangeStake' isn't real
	prefix_config = { atlas = false }, -- opt out of atlas-prefixing (SMODS default), 'Joker' is vanilla's real unprefixed atlas key
	calculate = function(self, card, context)
		if context.end_of_round and not context.blueprint then
			local state = TFT.get_state()
			if state then state.life_total = (state.life_total or 100) + 2 end
		end
	end,
}

SMODS.Joker {
	key = 'nurses_aide',
	trait_tags = { 'HeartsGuild' },
	loc_txt = {
		name = "The Nurse's Aide",
		text = { 'Once per stage, reduce incoming', '{C:attention}PvP damage{} by {C:red}5{}, flat' },
	},
	rarity = 3, cost = 9,
	unlocked = true, discovered = true, blueprint_compat = true, eternal_compat = true,
	pos = { x = 0, y = 0 }, atlas = 'Joker', -- see traits/engine.lua's atlas-bug comment; 'ChangeStake' isn't real
	prefix_config = { atlas = false }, -- opt out of atlas-prefixing (SMODS default), 'Joker' is vanilla's real unprefixed atlas key
	-- Consumed by future PvP-damage-resolution code (not wired this session --
	-- no PvP damage formula is implemented yet, scaffold-only per session scope).
	config = { extra = { used_this_stage = false } },
}
