-- Scholars buffer: new-jokers.md's +3 Jokers, closing the Scholars trait's
-- population thinness (see traits.md's population audit).

SMODS.Joker {
	key = 'apprentice_scribe',
	trait_tags = { 'Scholars' },
	loc_txt = {
		name = 'Apprentice Scribe',
		text = { '1 in 5 chance a used', '{C:tarot}Tarot{}/{C:planet}Planet{}/{C:spectral}Spectral{} card', 'is not consumed' },
	},
	rarity = 1, cost = 5,
	unlocked = true, discovered = true, blueprint_compat = true, eternal_compat = true,
	pos = { x = 0, y = 0 }, atlas = 'Joker', -- see traits/engine.lua's atlas-bug comment; 'ChangeStake' isn't real
	prefix_config = { atlas = false }, -- opt out of atlas-prefixing (SMODS default), 'Joker' is vanilla's real unprefixed atlas key
	-- Needs a consumable-use hook (SMODS's `use_card`/`before_use` context on the
	-- consumable itself, or a global before-consume check) not confirmed/wired
	-- this session -- present for the effect text/trait tag, mechanically stubbed.
}

SMODS.Joker {
	key = 'curator',
	trait_tags = { 'Scholars' },
	loc_txt = {
		name = 'Curator',
		text = { '{C:tarot}Tarot{}/{C:planet}Planet{}/{C:spectral}Spectral{}', 'shop prices {C:money}-$1{} (min $0)' },
	},
	rarity = 2, cost = 6,
	unlocked = true, discovered = true, blueprint_compat = true, eternal_compat = true,
	pos = { x = 0, y = 0 }, atlas = 'Joker', -- see traits/engine.lua's atlas-bug comment; 'ChangeStake' isn't real
	prefix_config = { atlas = false }, -- opt out of atlas-prefixing (SMODS default), 'Joker' is vanilla's real unprefixed atlas key
	-- Needs a shop-price-generation hook not wired this session -- stubbed, same
	-- reasoning as Apprentice Scribe above.
}

SMODS.Joker {
	key = 'the_archivist',
	trait_tags = { 'Scholars' },
	loc_txt = {
		name = 'The Archivist',
		text = { 'At the start of each PvP round,', 'create a {C:attention}Negative{} copy of a random', '{C:planet}Planet{}, {C:tarot}Tarot{}, and {C:spectral}Spectral{} card' },
	},
	rarity = 3, cost = 8,
	unlocked = true, discovered = true, blueprint_compat = true, eternal_compat = true,
	pos = { x = 0, y = 0 }, atlas = 'Joker', -- see traits/engine.lua's atlas-bug comment; 'ChangeStake' isn't real
	prefix_config = { atlas = false }, -- opt out of atlas-prefixing (SMODS default), 'Joker' is vanilla's real unprefixed atlas key
	-- Fires on PvP round start -- no PvP round-start hook exists yet this
	-- session (PvP itself is single-player-substituted-to-PvE this session, see
	-- domain/stage_layout.lua), so this has no live trigger point yet. Present
	-- for the trait tag/definition, mechanically stubbed until PvP rounds exist.
}
