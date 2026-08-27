-- A curated subset of augments.md's ~50 augments, picked for this pass because
-- their effect is tractable as either (a) a one-time/permanent stat change
-- applied once at pick time, or (b) a check added to an already-existing hook
-- point (round-advance, or the Traits Engine's scoring calculate()). The full
-- roster is NOT implemented this session -- augments not listed here (or listed
-- with `apply = nil`) are real entries a player could theoretically be offered
-- in a fuller pass, but aren't in THIS curated pool yet.
--
-- Each entry: { key, name, tier (1/2/3), category, desc, apply(state) } --
-- `apply` runs once, at pick time. Ongoing effects (Tip Jar, Thick Skin, etc.)
-- are read directly out of `TFT.get_state().augments_picked` from the relevant
-- hook (see round_flow/poll.lua and traits/engine.lua's calculate()).
TFT.AugmentDefinitions = {
	-- Silver
	{
		key = 'nest_egg', name = 'Nest Egg', tier = 1, category = 'Economic',
		desc = 'Gain $50 immediately.',
		apply = function() ease_dollars(50) end,
	},
	{
		key = 'tip_jar', name = 'Tip Jar', tier = 1, category = 'Economic',
		desc = '+$1 every time you play a scoring hand.',
		-- read in traits/engine.lua's Traits Engine calculate(), context.joker_main
	},
	{
		key = 'warm_up', name = 'Warm Up', tier = 1, category = 'Combat & Stats',
		desc = '+1 hand played per round (permanent).',
		apply = function() G.GAME.round_resets.hands = (G.GAME.round_resets.hands or 0) + 1 end,
	},
	{
		key = 'steady_hands', name = 'Steady Hands', tier = 1, category = 'Combat & Stats',
		desc = '+1 discard per round (permanent).',
		apply = function() G.GAME.round_resets.discards = (G.GAME.round_resets.discards or 0) + 1 end,
	},
	{
		key = 'growth_spurt', name = 'Growth Spurt', tier = 1, category = 'Combat & Stats',
		desc = '+1 hand size (permanent).',
		apply = function() if G.hand then G.hand.config.card_limit = (G.hand.config.card_limit or 0) + 1 end end,
	},
	{
		key = 'thick_skin', name = 'Thick Skin', tier = 1, category = 'Defensive & PvP',
		desc = 'Reduce all incoming PvP damage by 10%.',
		-- read in objects/actions/round_result.lua's loss branch, now that real
		-- PvP resolution exists (it didn't yet when this was first stubbed).
	},
	{
		key = 'rainy_day_fund', name = 'Rainy Day Fund', tier = 1, category = 'Economic',
		desc = "Once per stage, if you'd hit $0, gain $10 grace.",
		-- checked every frame from round_flow/poll.lua's per-round-reset logic
		-- (state.rainy_day_used_this_stage, reset on stage change).
	},

	-- Gold
	{
		key = 'iron_will', name = 'Iron Will', tier = 2, category = 'Combat & Stats',
		desc = '+2 hand size, but -1 discard per round.',
		apply = function()
			if G.hand then G.hand.config.card_limit = (G.hand.config.card_limit or 0) + 2 end
			G.GAME.round_resets.discards = math.max(0, (G.GAME.round_resets.discards or 0) - 1)
		end,
	},
	{
		key = 'portfolio_diversification', name = 'Portfolio Diversification', tier = 2, category = 'Economic',
		desc = '+1 Joker slot / -1 consumable slot.',
		apply = function()
			if G.jokers then G.jokers.config.card_limit = (G.jokers.config.card_limit or 0) + 1 end
			if G.consumeables then G.consumeables.config.card_limit = math.max(0, (G.consumeables.config.card_limit or 0) - 1) end
		end,
	},
	{
		key = 'second_look', name = 'Second Look', tier = 2, category = 'Shop & Items',
		desc = '+1 shop slot.',
		-- FIXED, live-diagnosed: a shop-slot count isn't a plain card_limit poke
		-- like Joker/consumable slots are -- G.shop_jokers.config.card_limit gets
		-- unconditionally OVERWRITTEN from G.GAME.shop.joker_max every time the
		-- shop rebuilds (common_events.lua), so anything setting card_limit
		-- directly gets silently discarded the next shop visit. The real,
		-- correct hook is vanilla's own `change_shop_size(mod)` global (used by
		-- the real Overstock voucher) -- it updates joker_max itself, which
		-- persists correctly.
		apply = function() change_shop_size(1) end,
	},
	{
		key = 'extra_pocket', name = 'Extra Pocket', tier = 2, category = 'Shop & Items',
		desc = '+1 consumable slot.',
		apply = function() if G.consumeables then G.consumeables.config.card_limit = (G.consumeables.config.card_limit or 0) + 1 end end,
	},
	{
		key = 'iron_wall', name = 'Iron Wall', tier = 2, category = 'Defensive & PvP',
		desc = 'Reduce incoming PvP damage by 20%, but reduce your own outgoing PvP damage by 10%.',
		-- read in round_result.lua -- the "outgoing -10%" half isn't applied
		-- (would need broadcasting augment picks to the opponent's client so
		-- THEIR damage-taken calc knows to reduce it; flagged, not silently
		-- dropped -- see this file's own closing note on cross-client gaps).
	},
	{
		key = 'bargain_bin', name = 'Bargain Bin', tier = 2, category = 'Economic',
		desc = 'Reroll cost -$1 (min $1).',
		apply = function()
			G.GAME.round_resets.reroll_cost = math.max(1, (G.GAME.round_resets.reroll_cost or 5) - 1)
		end,
	},
	{
		key = 'compound_interest', name = 'Compound Interest', tier = 2, category = 'Economic',
		desc = 'Interest rate doubles: earn $2 per $5 saved (still capped at the vanilla cap).',
		apply = function() G.GAME.interest_amount = (G.GAME.interest_amount or 1) * 2 end,
	},
	{
		key = 'golden_touch', name = 'Golden Touch', tier = 2, category = 'Economic',
		desc = 'Every 3rd shop reroll is free.',
		-- checked in a G.FUNCS.reroll_shop wrap, objects/augments/shop_effects.lua
	},
	{
		key = 'pack_rat', name = 'Pack Rat', tier = 2, category = 'Shop & Items',
		desc = 'Booster packs always offer 1 extra card choice.',
		-- read in objects/augments/shop_effects.lua's Card:open wrap
	},
	{
		key = 'reroll_refund', name = 'Reroll Refund', tier = 2, category = 'Shop & Items',
		desc = 'At the end of each stage, gain back 25% of all money spent on rerolls that stage.',
		-- tracked in objects/augments/shop_effects.lua's reroll wrap, paid out
		-- from round_flow/poll.lua's stage-change hook
	},
	{
		key = 'omen_globe', name = 'Omen Globe', tier = 2, category = 'Shop & Items',
		desc = 'Grants the real Omen Globe voucher outright.',
		-- CORRECTED via source check: there's no standalone add_voucher(key)
		-- global -- the real grant path is Card:redeem(), which requires a
		-- fully-instantiated, positioned Voucher Card (drives real UI/juice/
		-- hover state) and ALSO deducts its cost via ease_dollars(-self.cost),
		-- neither of which fits "hand the player a free reward" cleanly or
		-- safely without live-verifying the animation sequence doesn't choke
		-- on a card with no real shop-slot position.
		-- Card:apply_to_run(center) is the actual effect dispatch underneath
		-- redeem() (a big if/elseif on the voucher's name -- Omen Globe's
		-- branch is vanilla's own code, so this still never goes stale) --
		-- and, confirmed reading its body, `self` is only ever referenced in
		-- the fallback branch of `center and center.name or self.ability.name`,
		-- so it's safe to call with `self = nil` when `center` is passed
		-- explicitly, skipping the risky UI/cost side entirely. Also marks
		-- used_vouchers directly, matching redeem()'s own bookkeeping, so
		-- anything checking "do I own this voucher" reads correctly.
		apply = function()
			local center = G.P_CENTERS.v_omen_globe
			if not center then return end
			Card.apply_to_run(nil, center)
			G.GAME.used_vouchers['v_omen_globe'] = true
		end,
	},

	-- Prismatic
	{
		key = 'unstoppable', name = 'Unstoppable', tier = 3, category = 'Combat & Stats',
		desc = '+2 hands played, +2 discards, +2 hand size per round.',
		apply = function()
			G.GAME.round_resets.hands = (G.GAME.round_resets.hands or 0) + 2
			G.GAME.round_resets.discards = (G.GAME.round_resets.discards or 0) + 2
			if G.hand then G.hand.config.card_limit = (G.hand.config.card_limit or 0) + 2 end
		end,
	},
	{
		key = 'the_whole_store', name = 'The Whole Store', tier = 3, category = 'Shop & Items',
		desc = '+1 consumable slot, +1 shop slot, +1 booster pack slot.',
		-- Consumable slot and shop slot both fixed (see second_look's comment on
		-- the change_shop_size discovery). The "+1 booster pack slot" third
		-- isn't applied -- searched vanilla source for an equivalent to
		-- change_shop_size for the shop's pack section and found no such
		-- mechanism at all; vanilla's shop pack count may just not be a
		-- variable, moddable quantity the way joker/consumable/voucher slots
		-- are. Flagged rather than guessed at.
		apply = function()
			change_shop_size(1)
			if G.consumeables then G.consumeables.config.card_limit = (G.consumeables.config.card_limit or 0) + 1 end
		end,
	},
	{
		key = 'print_money', name = 'Print Money', tier = 3, category = 'Economic',
		desc = 'Gain $1 for every card scored this round, but your current money is halved on pick.',
		-- ASSUMPTION: augments.md's "starting money is halved this run" only
		-- means something at run start -- picked mid-run at a checkpoint, the
		-- only coherent reading is "halve what you have right now." The
		-- per-card income is read in traits/engine.lua's context.individual
		-- scoring pass (same pass Suit Guilds already use).
		apply = function() ease_dollars(-math.floor(G.GAME.dollars / 2)) end,
	},
	{
		key = 'vampiric', name = 'Vampiric', tier = 3, category = 'Defensive & PvP',
		desc = 'Winning a PvP round heals you for a percentage of the damage you dealt.',
		-- read in round_result.lua's win branch (self-contained: the winner's
		-- own client already computes the loser's damage via the same public
		-- formula, so no opponent-state broadcast is needed for this one).
	},

	-- More Silver
	{
		key = 'fundamentals', name = 'Fundamentals', tier = 1, category = 'Combat & Stats',
		desc = 'Every time a card scores, it permanently gains +1 Chip and +1 Mult (stacks).',
		-- per-card permanent accumulator, same precedent as vanilla Hiker --
		-- read/applied in traits/engine.lua's context.individual pass
	},
	{
		key = 'all_in', name = 'All In', tier = 1, category = 'Risky & Situational',
		desc = '+$50 immediately, for the cost of 1 hand size.',
		apply = function()
			ease_dollars(50)
			if G.hand then G.hand.config.card_limit = math.max(1, (G.hand.config.card_limit or 1) - 1) end
		end,
	},
	{
		key = 'speed_round', name = 'Speed Round', tier = 1, category = 'Risky & Situational',
		desc = '+1 hand played per round, but -1 discard per round.',
		apply = function()
			G.GAME.round_resets.hands = (G.GAME.round_resets.hands or 0) + 1
			G.GAME.round_resets.discards = math.max(0, (G.GAME.round_resets.discards or 0) - 1)
		end,
	},
	{
		key = 'glass_cannon', name = 'Glass Cannon', tier = 1, category = 'Risky & Situational',
		desc = 'x2 Mult on every hand, but take extra PvP damage whenever you lose a round.',
		-- ASSUMPTION: augments.md's downside ("lose an extra life beyond
		-- normal" on failing a blind) only has a coherent meaning against this
		-- mod's real life model on a PvP loss -- PvE rounds don't cost life at
		-- all here. Read as: extra flat damage tacked onto a real PvP loss.
		-- The x2 Mult is read in traits/engine.lua's context.individual pass;
		-- the extra damage in round_result.lua's loss branch.
	},
	{
		key = 'thin_the_herd', name = 'Thin the Herd', tier = 1, category = 'Deck & Cards',
		desc = 'Remove 10 random cards from your deck.',
		apply = function() TFT.remove_random_deck_cards(10) end,
	},
	{
		key = 'lucky_break', name = 'Lucky Break', tier = 1, category = 'Deck & Cards',
		desc = '5 random un-enhanced cards each gain a random Enhancement.',
		apply = function() TFT.enhance_random_deck_cards(5) end,
	},
	{
		key = 'fresh_coat', name = 'Fresh Coat', tier = 1, category = 'Deck & Cards',
		desc = '3 random cards without an Edition each gain a random Edition.',
		apply = function() TFT.edition_random_deck_cards(3, false) end,
	},
	{
		key = 'seal_the_deal', name = 'Seal the Deal', tier = 1, category = 'Deck & Cards',
		desc = '4 different random cards each get one of the four Seals.',
		apply = function() TFT.seal_random_deck_cards() end,
	},
	{
		key = 'reshuffle', name = 'Reshuffle', tier = 1, category = 'Deck & Cards',
		desc = 'Every card in your deck is randomly reassigned a rank and suit.',
		apply = function() TFT.reshuffle_deck_ranks_suits() end,
	},
	{
		key = 'early_warning', name = 'Early Warning', tier = 1, category = 'Utility & Information',
		desc = 'See your next 2 PvP opponents in the round-robin order, not just the next 1.',
		-- read in ui/lobby.lua-adjacent UI (state.augments_picked check) --
		-- pairing lookahead itself is real (domain/pvp_pairing.lua is pure and
		-- stateless per round number), only the extra HUD row surfacing it is
		-- new. Flagged: no dedicated UI panel built this pass, so this is data-
		-- available-on-request (TFT.upcoming_pvp_opponents) rather than an
		-- always-visible display -- a real, live gap on the QoL/display side.
	},

	-- More Gold
	{
		key = 'level_up', name = 'Level Up', tier = 2, category = 'Combat & Stats',
		desc = 'Each round, the first hand type you play permanently gains +2 levels.',
		-- read in traits/engine.lua's context.joker_main pass
	},
	{
		key = 'encore_performance', name = 'Encore Performance', tier = 2, category = 'Combat & Stats',
		desc = 'Play the same poker hand type twice in a row to gain +1 hand that round.',
		-- read in traits/engine.lua's context.joker_main pass
	},
	{
		key = 'adrenaline', name = 'Adrenaline', tier = 2, category = 'Combat & Stats',
		desc = "On your final hand of the round, if you're behind, all played cards retrigger once.",
		-- read in traits/engine.lua's context.repetition pass -- "behind" compares
		-- against the paired opponent's already-in score during a real PvP
		-- round, or the blind's chip requirement otherwise (per augments.md's
		-- own explicit fallback rule).
	},
	{
		key = 'double_or_nothing', name = 'Double or Nothing', tier = 2, category = 'Risky & Situational',
		desc = 'Wager half your money: 50% chance to double it, 50% to lose it. Resolves immediately.',
		apply = function()
			local wager = math.floor(G.GAME.dollars / 2)
			if wager <= 0 then return end
			if pseudorandom(pseudoseed('tft_double_or_nothing' .. G.GAME.round_resets.ante)) < 0.5 then
				ease_dollars(wager)
			else
				ease_dollars(-wager)
			end
		end,
	},
	{
		key = 'boom_or_bust', name = 'Boom or Bust', tier = 2, category = 'Risky & Situational',
		desc = 'Your first hand each round scores x3 Mult; every hand after scores -25% Mult.',
		-- read in traits/engine.lua's context.individual pass, keyed off
		-- G.GAME.current_round.hands_played
	},
	{
		key = 'overdraft', name = 'Overdraft', tier = 2, category = 'Risky & Situational',
		desc = 'Immediately gain $40, but pay $3 upkeep at the end of every round for the rest of the match.',
		apply = function() ease_dollars(40) end,
		-- upkeep paid from round_flow/poll.lua's round-advance hook
	},
	{
		key = 'padded_walls', name = 'Padded Walls', tier = 2, category = 'Defensive & PvP',
		desc = 'The first time you take PvP damage each stage, that instance is halved.',
		-- read in round_result.lua's loss branch (state.padded_walls_used_this_stage)
	},
	{
		key = 'counterpunch', name = 'Counterpunch', tier = 2, category = 'Defensive & PvP',
		desc = "When you win a PvP round, deal bonus damage scaled to your margin of victory.",
		-- NOT WIRED: the bonus damage needs to land on the OPPONENT's own life
		-- total, which lives on THEIR client -- doing this for real needs a new
		-- broadcast action (the winner tells the loser "take N more damage"),
		-- which this pass didn't add (see this file's closing note). Flagged,
		-- not silently half-implemented.
	},
	{
		key = 'second_wind', name = 'Second Wind', tier = 2, category = 'Defensive & PvP',
		desc = 'The first time you would be eliminated, survive at 1 life instead. Once per match.',
		-- read in round_result.lua's loss branch (state.second_wind_used)
	},
	{
		key = 'deck_surgeon', name = 'Deck Surgeon', tier = 2, category = 'Deck & Cards',
		desc = 'Remove any 5 cards of your choice from your deck.',
		-- NOT WIRED: needs a real deck-browsing multi-select picker UI (choose
		-- 5 specific cards from a full 52+ card deck) -- a materially bigger UI
		-- build than this pass's picker helper (ui/picker.lua) supports. Flagged
		-- rather than silently downgraded to "5 random" (that's Thin the Herd's
		-- job, a different augment with a different, intentionally-random
		-- design).
	},
	{
		key = 'seal_artisan', name = 'Seal Artisan', tier = 2, category = 'Deck & Cards',
		desc = 'Choose up to 4 cards in your deck and assign each a Seal of your choice.',
		-- NOT WIRED: same reason as Deck Surgeon -- needs a per-card choice UI.
	},
	{
		key = 'suit_yourself', name = 'Suit Yourself', tier = 2, category = 'Deck & Cards',
		desc = 'Choose a suit; every card in your deck becomes that suit.',
		-- ASSUMPTION (flagged, consistent with this pass's scope-down on
		-- "choose X" augments -- see closing note): the suit is auto-rolled
		-- rather than player-picked, since building a dedicated 4-suit choice
		-- UI for one augment wasn't worth it relative to a random pick that
		-- still delivers the mechanical effect.
		apply = function() TFT.set_deck_suit(TFT.random_suit()) end,
	},
	{
		key = 'odd_couple', name = 'Odd Couple', tier = 2, category = 'Deck & Cards',
		desc = 'Every card becomes either a 2 of Clubs or Queen of Hearts (~50/50).',
		apply = function() TFT.odd_couple_deck() end,
	},
	{
		key = 'card_shark', name = 'Card Shark', tier = 2, category = 'Deck & Cards',
		desc = 'Grants 5 copies of the Aura Spectral card, each Negative (not consumed on use).',
		apply = function() TFT.grant_negative_auras(5) end,
	},

	-- More Prismatic
	{
		key = 'grand_astronomer', name = 'Grand Astronomer', tier = 3, category = 'Combat & Stats',
		desc = 'Grants 10 levels to every poker hand type, including secret ones (which this reveals).',
		apply = function()
			for hand_key, _ in pairs(G.GAME.hands) do
				G.GAME.hands[hand_key].visible = true
				level_up_hand(nil, hand_key, true, 10)
			end
		end,
	},
	{
		key = 'perfect_game', name = 'Perfect Game', tier = 3, category = 'Combat & Stats',
		desc = 'Beat a non-PvP blind by the EXACT chip requirement to choose a permanent bonus.',
		-- NOT WIRED: augments.md itself flags the reward pool as undesigned
		-- ("Reward pool not designed yet — open item"). Nothing to implement
		-- against yet; would need that design decision first.
	},
	{
		key = 'monopoly', name = 'Monopoly', tier = 3, category = 'Economic',
		desc = 'A random rarity gets double shop odds for the rest of the match; all others halve.',
		-- ASSUMPTION: the target power_tier is auto-rolled at pick time rather
		-- than player-chosen, same scope-down as Suit Yourself -- consistent
		-- rather than building a one-off rarity-choice picker. Read in
		-- shop_odds.lua's get_current_pool hook.
		apply = function()
			local state = TFT.get_state()
			state.monopoly_tier = math.floor(pseudorandom(pseudoseed('tft_monopoly' .. G.GAME.round_resets.ante)) * 5) + 1
		end,
	},
	{
		key = 'everythings_for_sale', name = "Everything's For Sale", tier = 3, category = 'Economic',
		desc = 'All shop prices -25%.',
		apply = function() G.GAME.discount_percent = (G.GAME.discount_percent or 0) + 25 end,
	},
	{
		key = 'the_house_always_wins', name = 'The House Always Wins', tier = 3, category = 'Economic',
		desc = "Winning a PvP round grants $1 per 5% your score exceeded your opponent's by, capped at $50/round.",
		-- read in round_result.lua's win branch (self-contained, see vampiric)
	},
	{
		key = 'fire_sale', name = 'Fire Sale', tier = 3, category = 'Shop & Items',
		desc = 'Reroll cost -$2 (min $1).',
		apply = function()
			G.GAME.round_resets.reroll_cost = math.max(1, (G.GAME.round_resets.reroll_cost or 5) - 2)
		end,
	},
	{
		key = 'vintage_collection', name = 'Vintage Collection', tier = 3, category = 'Shop & Items',
		desc = 'Once per shop visit, one Joker slot offers a rarity tier above your level odds.',
		-- read in shop_odds.lua (state.vintage_collection_used_this_visit,
		-- reset whenever the shop is (re)opened)
	},
	{
		key = 'the_big_score', name = 'The Big Score', tier = 3, category = 'Shop & Items',
		desc = 'Your next reroll is guaranteed to surface a Legendary item. One-time use.',
		-- ASSUMPTION: "your next reroll" is read as "the next time a Joker
		-- shop slot rolls" (armed immediately at pick time, consumed by
		-- shop_odds.lua's get_current_pool hook the moment it next fires) --
		-- not literally gated on the reroll BUTTON specifically, since the
		-- very next shop refresh (initial fill or reroll, whichever comes
		-- first) is the more natural reading of "guaranteed on your next look."
		apply = function()
			local state = TFT.get_state()
			if state then state.big_score_pending = true end
		end,
	},
	{
		key = 'double_pack', name = 'Double Pack', tier = 3, category = 'Shop & Items',
		desc = 'Buying a booster pack opens 2 packs of that type instead of 1.',
		-- NOT WIRED: needs a hook into the pack-opening flow (Card:open,
		-- functions/common_events.lua) to run its contents-grant twice --
		-- objects/augments/shop_effects.lua only wired Pack Rat's extra-choice
		-- case this pass, not a second full pack open. Flagged as a real,
		-- separate follow-up, not silently folded into Pack Rat.
	},
	{
		key = 'alchemists_dream', name = "Alchemist's Dream", tier = 3, category = 'Deck & Cards',
		desc = 'Every un-enhanced card in your deck gets an independently-random Enhancement.',
		apply = function() TFT.enhance_random_deck_cards(nil) end, -- nil = every eligible card, not a fixed count
	},
	{
		key = 'gilded_deck', name = 'Gilded Deck', tier = 3, category = 'Deck & Cards',
		desc = 'Every card in your deck gets an independently-random Edition (overwrites existing ones).',
		apply = function() TFT.edition_random_deck_cards(nil, true) end,
	},
	{
		key = 'everythings_wild', name = "Everything's Wild", tier = 3, category = 'Deck & Cards',
		desc = 'Every card counts as every suit, for all scoring and Joker checks.',
		-- global suit-equivalence, same technique as vanilla Smeared Joker --
		-- read in objects/augments/deck_effects.lua's get_suit hook
	},
	{
		key = 'kings_court', name = "King's Court", tier = 3, category = 'Deck & Cards',
		desc = 'Every card in your deck becomes the King of Hearts (rank and suit only).',
		apply = function() TFT.set_deck_rank_suit('King', 'Hearts') end,
	},
	{
		key = 'apprentices_charm', name = "Apprentice's Charm", tier = 1, category = 'Trait & Emblem',
		desc = 'One Joker you own also counts as having a randomly-chosen trait.',
		-- ASSUMPTION (see this file's closing note on "choose X" augments):
		-- both the trait AND the target Joker are auto-rolled rather than
		-- player-picked. Tag is stored on the specific card
		-- (card.ability.tft_extra_trait_tags), read by TFT.get_trait_tags.
		apply = function() TFT.grant_random_extra_trait_tag() end,
	},
	{
		key = 'trait_heart', name = 'Trait Heart', tier = 2, category = 'Trait & Emblem',
		desc = 'A randomly-chosen trait counts your total as +2 higher, for breakpoint purposes only.',
		-- read in traits/engine.lua's TFT.count_trait_tags
		apply = function()
			local state = TFT.get_state()
			state.trait_heart_target = TFT.random_trait_key({ exclude = {} })
		end,
	},
	{
		key = 'grand_emblem', name = 'Grand Emblem', tier = 3, category = 'Trait & Emblem',
		desc = 'A randomly-chosen trait (never Ascendants/Scalers) is granted to every Joker you own or acquire.',
		apply = function()
			local state = TFT.get_state()
			state.grand_emblem_target = TFT.random_trait_key({ exclude = { Ascendants = true, Scalers = true } })
		end,
	},
	{
		key = 'momentum_keeper', name = 'Momentum Keeper', tier = 2, category = 'Trait & Emblem',
		desc = "Scaling Jokers never lose their accumulated bonus, even from effects that would normally reset them.",
		-- NOT WIRED: "reset" Jokers like Obelisk/Castle reset their OWN
		-- self.ability fields inside their own card.lua branches -- there's no
		-- single choke point to intercept "a reset is about to happen" the way
		-- calculate_joker's return value is a choke point for its OUTPUT.
		-- Would need per-Joker-name special-casing (the exact "150 bespoke
		-- upgrades" problem joker-ranking.md's own design explicitly tries to
		-- avoid). Flagged as a real gap, not faked.
	},
	{
		key = 'critical_mass', name = 'Critical Mass', tier = 3, category = 'Trait & Emblem',
		desc = "The Scalers half-slot unlock applies starting from your very first Scaler.",
		-- read directly via TFT.has_augment in traits/engine.lua's
		-- trait_round_reset (lowers the Scalers tier gate on the slot-grant
		-- formula from tier>=3 to tier>=1) -- no apply() needed, it's a pure
		-- ongoing check like Tip Jar/Thick Skin.
	},
	{
		key = 'lucky_star', name = 'Lucky Star', tier = 2, category = 'Trait & Emblem',
		desc = 'The next Rare or Legendary Joker you obtain is guaranteed Negative edition. One-time.',
		-- read in ranking.lua/shop_effects.lua's CardArea:emplace path
	},
	{
		key = 'cosmic_alignment', name = 'Cosmic Alignment', tier = 3, category = 'Trait & Emblem',
		desc = 'Negative-edition odds on Rare/Legendary items are tripled for the rest of the match.',
		-- NOT WIRED -- see objects/augments/shop_effects.lua's closing note:
		-- poll_edition's real signature carries no rarity context to key this
		-- off of, so there's no clean way to scope the boost to Rare/Legendary
		-- items only.
	},

	-- Remaining Shop & Items Silver
	{
		key = 'frequent_buyer', name = 'Frequent Buyer', tier = 1, category = 'Shop & Items',
		desc = 'Every 5th shop purchase (any item type) is 50% off.',
		-- read in objects/augments/shop_effects.lua's buy_from_shop wrap
	},
	{
		key = 'clearance_rack', name = 'Clearance Rack', tier = 1, category = 'Shop & Items',
		desc = 'All Common-rarity shop items are 50% off.',
		-- read in objects/augments/shop_effects.lua's Card:set_cost wrap
	},

	-- Remaining Risky & Situational / Defensive & PvP Prismatic
	{
		key = 'all_or_nothing', name = 'All or Nothing', tier = 3, category = 'Risky & Situational',
		desc = 'Permanent x10 Mult on every hand, but eliminates any life-saving effects if you ever hit 0 life.',
		-- x10 Mult read in traits/engine.lua's context.joker_main pass;
		-- overrides Second Wind in round_result.lua's loss branch. The actual
		-- "eliminated instantly" consequence isn't enforceable yet -- real
		-- elimination/placement tracking is a pre-existing, separately-
		-- flagged gap (see round_result.lua's own note).
	},
	{
		key = 'high_roller', name = 'High Roller', tier = 3, category = 'Risky & Situational',
		desc = "Every PvP round is winner-takes-all: the loser's money is halved (capped $100 transferred) on top of normal life loss.",
		-- read in round_result.lua's loss branch -- see this file's own note
		-- on why only the loser's half-money-loss is wired, not the winner's
		-- credit.
	},
	{
		key = 'point_of_no_return', name = 'Point of No Return', tier = 3, category = 'Risky & Situational',
		desc = 'Locks you to one poker hand type for the rest of the match; it gains +20 levels immediately and scales 5x as fast, and cards scoring as part of it are immune to boss debuffs.',
		-- ASSUMPTION: hand type is auto-rolled (see this file's closing note on
		-- "choose X" augments), weighted toward hand types you've already
		-- played this run if any exist, else fully random. The hard lock
		-- itself (rejecting plays of any OTHER hand type) and the boss-debuff
		-- immunity clause are NOT wired -- both need hooking the actual hand-
		-- evaluation/scoring gate rather than the calculate() dispatch this
		-- pass otherwise relies on, a materially different (and riskier, since
		-- it can block real play) kind of hook. Only the immediate +20 levels
		-- is applied; flagged rather than faking the lock.
		apply = function()
			local candidates = {}
			for k, v in pairs(G.GAME.hands) do
				if v.visible then table.insert(candidates, k) end
			end
			if #candidates == 0 then for k, _ in pairs(G.GAME.hands) do table.insert(candidates, k) end end
			local chosen = pseudorandom_element(candidates, pseudoseed('tft_point_of_no_return' .. G.GAME.round_resets.ante))
			level_up_hand(nil, chosen, true, 20)
		end,
	},
	{
		key = 'fortress', name = 'Fortress', tier = 3, category = 'Defensive & PvP',
		desc = 'Reduce all incoming PvP damage by 50%. Ghost-board rounds never deal you damage.',
		-- The 50% reduction is read in round_result.lua's loss branch. The
		-- ghost-immunity clause isn't applicable as written: domain/
		-- pvp_pairing.lua's real ghost mechanic gives the GHOSTED player no
		-- opponent to resolve at all (they simply skip resolution, see
		-- objects/actions/round_result.lua's `if not opponent_id then return
		-- end`) -- there's no "lose to the ghost" outcome currently modeled to
		-- be immune from.
	},
	{
		key = 'eye_for_an_eye', name = 'An Eye for An Eye', tier = 3, category = 'Defensive & PvP',
		desc = 'Once per match, losing a PvP round redirects your damage to your opponent instead of you taking it.',
		-- Self-side implemented (you take 0 damage that round) in
		-- round_result.lua's loss branch. The redirect-TO-your-opponent half
		-- isn't wired -- same cross-client gap as Counterpunch/High Roller's
		-- credit half, flagged there.
	},
}

function TFT.get_augment(key)
	for _, aug in ipairs(TFT.AugmentDefinitions) do
		if aug.key == key then return aug end
	end
	return nil
end

function TFT.augments_by_tier(tier)
	local list = {}
	for _, aug in ipairs(TFT.AugmentDefinitions) do
		if aug.tier == tier then table.insert(list, aug) end
	end
	return list
end
