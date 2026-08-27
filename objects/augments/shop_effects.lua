-- Shop & Items category augments that need a hook beyond the pick-time
-- `apply()` -- reroll cost/free-reroll tracking, purchase discounts, and pack
-- choice count, each on the real vanilla function that already owns that
-- specific piece of state.

-- Golden Touch (Gold): every 3rd reroll is free. Reroll Refund (Gold): track
-- money actually spent on rerolls this stage, paid out at stage end from
-- round_flow/poll.lua's stage-change hook.
local _tft_orig_reroll_shop = G.FUNCS.reroll_shop
G.FUNCS.reroll_shop = function(e)
	local state = TFT.get_state()
	if state and TFT.is_run_active() then
		local was_free = (G.GAME.current_round.free_rerolls or 0) > 0
		local cost = G.GAME.current_round.reroll_cost or 0

		if TFT.has_augment('golden_touch') then
			state.golden_touch_count = (state.golden_touch_count or 0) + 1
			if state.golden_touch_count % 3 == 0 then
				G.GAME.current_round.free_rerolls = (G.GAME.current_round.free_rerolls or 0) + 1
				was_free = true
			end
		end

		if TFT.has_augment('reroll_refund') and not was_free and cost > 0 then
			state.reroll_spend_this_stage = (state.reroll_spend_this_stage or 0) + cost
		end
	end
	return _tft_orig_reroll_shop(e)
end

-- Frequent Buyer (Silver): every 5th shop purchase (any item type) is 50%
-- off. Mutates c1.cost BEFORE calling the original buy_from_shop -- confirmed
-- via source read that the real cost deduction (`ease_dollars(-c1.cost)`)
-- happens later in the SAME closure, reading c1.cost fresh at that point, and
-- nothing in between re-derives it from base_cost -- so this lands cleanly.
local _tft_orig_buy_from_shop = G.FUNCS.buy_from_shop
G.FUNCS.buy_from_shop = function(e)
	local state = TFT.get_state()
	if state and TFT.is_run_active() and TFT.has_augment('frequent_buyer') then
		local c1 = e.config.ref_table
		if c1 and c1:is(Card) then
			state.frequent_buyer_count = (state.frequent_buyer_count or 0) + 1
			if state.frequent_buyer_count % 5 == 0 then
				c1.cost = math.max(0, math.floor(c1.cost * 0.5))
			end
		end
	end
	return _tft_orig_buy_from_shop(e)
end

-- Clearance Rack (Silver): all Common-power_tier shop Jokers are 50% off.
-- Scoped to Jokers specifically (power_tier is a Joker-only concept in this
-- mod) -- Tarot/Planet/Spectral/Voucher pricing is untouched, flagged rather
-- than inventing an equivalent "common" notion for non-Joker card types.
local _tft_orig_set_cost_clearance = Card.set_cost
function Card:set_cost()
	_tft_orig_set_cost_clearance(self)
	if not TFT.is_run_active() or not TFT.has_augment('clearance_rack') then return end
	if not self.ability or self.ability.set ~= 'Joker' then return end
	if not self.config or not self.config.center or self.config.center.key == 'j_tft_traits_engine' then return end

	local tier = TFT.get_power_tier(self.config.center.key, self.config.center.rarity)
	if tier == TFT.PowerTier.COMMON then
		self.cost = math.max(1, math.floor(self.cost * 0.5))
	end
end

-- Pack Rat (Gold): booster packs always offer 1 extra card choice.
-- Card:open() sets G.GAME.pack_choices itself (card.lua) -- bumping it right
-- after the real open() runs is the minimal, correct hook.
local _tft_orig_card_open = Card.open
function Card:open()
	local ret = _tft_orig_card_open(self)
	if TFT.is_run_active() and TFT.has_augment('pack_rat') and self.ability and self.ability.set == 'Booster' then
		G.GAME.pack_choices = (G.GAME.pack_choices or 1) + 1
	end
	return ret
end

-- Lucky Star (Gold, Trait & Emblem): the next Rare or Legendary Joker
-- obtained is guaranteed Negative edition, one-time. Hooked onto the same
-- CardArea:emplace choke point objects/jokers/ranking.lua already uses for
-- merge-on-acquire -- runs AFTER ranking.lua's own emplace wrap (loaded
-- later, core.lua's directory order is traits -> jokers -> augments), so by
-- the time this fires a just-merged duplicate has already been folded away
-- and this only ever sees a genuinely new physical card.
local _tft_orig_emplace_lucky_star = CardArea.emplace
function CardArea:emplace(card, location, stay_flipped)
	local ret = _tft_orig_emplace_lucky_star(self, card, location, stay_flipped)
	if self == G.jokers and TFT.is_run_active() and TFT.has_augment('lucky_star')
		and card and card.ability and card.ability.set == 'Joker' and card.config and card.config.center then
		local state = TFT.get_state()
		if state and not state.lucky_star_used then
			local tier = TFT.get_power_tier(card.config.center.key, card.config.center.rarity)
			if tier >= TFT.PowerTier.RARE and card.config.center.key ~= 'j_tft_traits_engine'
				and #G.jokers.cards > 0 and G.jokers.cards[#G.jokers.cards] == card then
				state.lucky_star_used = true
				card:set_edition({ negative = true }, true)
			end
		end
	end
	return ret
end

-- Cosmic Alignment (Prismatic, Trait & Emblem): NOT WIRED. Its effect needs to
-- apply only to Rare/Legendary items' edition rolls specifically, but
-- poll_edition(_key, _mod, _no_neg, _guaranteed) (functions/common_events.lua,
-- also hooked in objects/traits/engine.lua for Ascendants) carries no rarity
-- context in its signature at all -- there's no way to tell from inside that
-- hook whether the roll in progress belongs to a Rare/Legendary item or a
-- Common one. Applying it as a blanket boost regardless of rarity would be a
-- real behavior change beyond what the augment describes, not a faithful
-- simplification, so it's left unimplemented and flagged rather than guessed.
