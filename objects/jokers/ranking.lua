-- Joker Ranking -- the "stay low level" incentive (docs/design/joker-ranking.md).
-- Duplicate copies of an already-owned Joker merge into a single Ranked copy
-- (max Rank 3) instead of taking a second slot; Rank applies a flat multiplier
-- (domain/rarity_odds.lua's TFT.PowerTierRankMultiplier, already authored) to
-- whatever numeric values that Joker already outputs, rather than a bespoke
-- hand-written upgrade per Joker -- the whole point being ONE curve to tune,
-- not ~150.
--
-- SCOPE, flagged up front: this session implements the core loop (Showman-
-- baseline duplicate visibility, merge-on-acquire, rank multiplier on scoring
-- output, sell-value bonus) end to end. The Shared Joker Pool (lobby-wide
-- scarcity, TFT's own bag mechanic) is a materially bigger networking feature
-- -- broadcasting owned-Joker snapshots and filtering shop rolls against
-- remaining lobby-wide copies -- and is NOT wired in this pass; without it,
-- every player currently rolls duplicates from an independent, uncapped
-- probability space. domain/rarity_odds.lua's TFT.SharedJokerPoolSize/
-- TFT.pool_size_scaler already exist as pure data for whenever that gets
-- built. Flagged here, not silently skipped.

TFT.MAX_JOKER_RANK = 3

-- CORRECTED per explicit user direction, 2026-08-26: Rank is NOT "+1 per
-- duplicate merged" (my original reading of joker-ranking.md's prose) --
-- it's TOTAL-COPIES-EVER-MERGED thresholds, house-ruled simpler than TFT's
-- own exponential 3-then-9 curve: 3 total copies reaches Rank 2, 6 total
-- copies reaches Rank 3 (i.e. 3 MORE beyond the 3 that got you to Rank 2, not
-- 9 more TFT-style). The 1st copy (no merge yet) is Rank 1. Copies 4 and 5
-- don't do anything new -- still Rank 2 -- until the 6th arrives.
local RANK_COPIES_THRESHOLD = { [2] = 3, [3] = 6 }

-- Real state is TOTAL COPIES ever merged into this card, stored on the
-- surviving card's own ability table (starts at 1 -- the card itself counts
-- as its own first copy). Rank is a pure, derived function of that count, not
-- separately-stored state -- one source of truth, can't drift out of sync.
function TFT.get_joker_copies(card)
	return (card and card.ability and card.ability.tft_copies) or 1
end

function TFT.get_joker_rank(card)
	local copies = TFT.get_joker_copies(card)
	if copies >= RANK_COPIES_THRESHOLD[3] then return 3 end
	if copies >= RANK_COPIES_THRESHOLD[2] then return 2 end
	return 1
end

-- Copies still needed (merging one more duplicate in) to reach the NEXT
-- rank -- always exactly 1 short of the next threshold, i.e. this is really
-- "how many of the next 3 have you already got," not a flat "+1." Returns 0
-- once already at Rank 3 (nothing more to reach).
function TFT.copies_to_next_rank(card)
	local copies = TFT.get_joker_copies(card)
	local rank = TFT.get_joker_rank(card)
	if rank >= TFT.MAX_JOKER_RANK then return 0 end
	return RANK_COPIES_THRESHOLD[rank + 1] - copies
end

-- Records one more merged duplicate and refreshes sell_cost. Returns the new
-- rank so callers can tell whether this specific merge actually crossed a
-- threshold (vs. just incrementing 4->5 copies with no rank change).
function TFT.add_joker_copy(card)
	if not card or not card.ability then return 1 end
	card.ability.tft_copies = TFT.get_joker_copies(card) + 1
	if card.set_cost then card:set_cost() end -- refreshes sell_cost with the new rank bonus
	return TFT.get_joker_rank(card)
end

-- Real rank multiplier for a card at its CURRENT rank -- looks up power_tier
-- the same way shop odds/trait tagging already do (TFT.get_power_tier), so a
-- Joker's classification is one single source of truth across odds, traits,
-- and ranking.
function TFT.joker_rank_multiplier(card)
	if not card or not card.config or not card.config.center then return 1 end
	local key = card.config.center.key
	local tier = TFT.get_power_tier(key, card.config.center.rarity)
	local curve = TFT.PowerTierRankMultiplier[tier] or TFT.PowerTierRankMultiplier[1]
	local rank = TFT.get_joker_rank(card)
	return curve[math.min(rank, #curve)] or 1
end

-- 1. Showman-baseline: CORRECTED via live testing, 2026-08-25 -- my first
-- attempt hooked `find_joker("Showman")` per docs/design/joker-ranking.md's
-- own description of vanilla's exclusion mechanism, sourced from a Balatro
-- Source reference checkout that turned out to be a different build than
-- what's actually installed here. Verified live that hook was a complete
-- no-op: instrumented find_joker and confirmed it's called ZERO times during
-- a real get_current_pool('Joker', ...) invocation. Reading the ACTUAL
-- installed game's patched source (Mods/lovely/dump/functions/
-- common_events.lua, this Steamodded build) shows the real, current
-- exclusion check is
--   `not (G.GAME.used_jokers[v.key] and not pool_opts.allow_duplicates and
--    not SMODS.showman(v.key))`
-- -- a Steamodded-provided `SMODS.showman(key)` function (src/utils.lua),
-- itself checking `SMODS.create_card_allow_duplicates`,
-- `SMODS.poll_object_allow_duplicates`, or owning a card named 'j_ring_master'
-- (this build's real internal key for the Showman-role Joker -- confirmed via
-- SMODS.find_card, not vanilla's own find_joker at all). Hooking THIS
-- function is both the correct fix and simpler than the original attempt --
-- one function, no side effects on unrelated Soul/Black Hole exclusion logic
-- (which in this build doesn't route through the same check at all).
local _tft_orig_smods_showman = SMODS.showman
function SMODS.showman(card_key)
	if TFT.is_run_active() then return true end
	return _tft_orig_smods_showman(card_key)
end

-- 2. Merge-on-acquire: CardArea:emplace (cardarea.lua) is the real, single
-- choke point every Joker source (shop buy, booster pack, tag reward, voucher
-- grant) funnels through to actually land a card in G.jokers -- confirmed by
-- cardarea.lua's OWN body already special-casing `if self == G.jokers then`
-- for its own bookkeeping right inside this same function. Deliberately lets
-- the REAL emplace happen first (so every other bit of purchase-flow code
-- that keeps referencing the just-bought card object afterward -- e.g.
-- button_callbacks.lua's buy_from_shop scheduling a delayed
-- `c1:calculate_joker(...)` call post-purchase -- still finds a fully normal,
-- still-valid Card), then immediately checks for a same-key duplicate and, if
-- found, folds it into the EXISTING copy's Rank and removes the new card from
-- the area a moment later. A card that already reached Rank 3 (the cap) is
-- left as a genuine second physical copy instead -- simplest, safest fallback
-- rather than blocking/refunding a real purchase.
local _tft_orig_emplace = CardArea.emplace
function CardArea:emplace(card, location, stay_flipped)
	local ret = _tft_orig_emplace(self, card, location, stay_flipped)
	if self == G.jokers and TFT.is_run_active() and card and card.ability and card.ability.set == 'Joker' then
		pcall(TFT.try_merge_duplicate_joker, card)
		-- Shared Joker Pool (objects/actions/joker_ownership.lua, may not exist
		-- yet if MPAPI never finished loading -- guarded, matching hooks.lua's
		-- own TFT.restart_round_timer guard): every Joker landing here changes
		-- this player's owned-copy summary, whether it merged into an existing
		-- copy or took a fresh slot.
		if TFT.broadcast_joker_ownership then pcall(TFT.broadcast_joker_ownership) end
	end
	return ret
end

function TFT.try_merge_duplicate_joker(new_card)
	if not new_card.config or not new_card.config.center then return end
	local key = new_card.config.center.key
	if key == 'j_tft_traits_engine' then return end -- never merge our own internal pseudo-joker

	local existing
	for _, c in ipairs(G.jokers.cards) do
		if c ~= new_card and c.config and c.config.center and c.config.center.key == key then
			existing = c
			break
		end
	end
	if not existing then return end

	if TFT.get_joker_rank(existing) >= TFT.MAX_JOKER_RANK then return end -- already maxed; let the dupe sit as a real 2nd copy

	local new_rank = TFT.add_joker_copy(existing)
	TFT.sendDebugMessage('Joker merged: ' .. key .. ' -> ' .. TFT.get_joker_copies(existing) .. ' copies (Rank ' .. new_rank .. ')')

	G.jokers:remove_card(new_card)
	new_card:remove()

	-- Small juice: bump the surviving card so the merge is visible, same
	-- pattern vanilla uses for "this card just changed" (e.g. edition polish).
	if existing.juice_up then existing:juice_up(0.8, 0.5) end
end

-- 3. Rank multiplier on scoring output: Card:calculate_joker(context) is the
-- same real per-Joker dispatch method objects/traits/engine.lua's Multipliers/
-- Scalers hook already wraps -- loaded AFTER traits (core.lua's load order),
-- so this wrap sits OUTERMOST, applying Rank to the traits-adjusted result.
-- That's the intended order: joker-ranking.md describes Rank as "a flat
-- multiplier to whatever numeric values that Joker already outputs," i.e. the
-- final effective output, not a base-only bonus that other systems then stack
-- on top of. Deliberately uniform across every numeric field below -- no
-- special-casing x_mult/Xmult_mod as "more dangerous to scale" -- per the
-- design's own explicit point of this whole system being ONE curve applied
-- everywhere, with the real danger (repeatable-xMult combo pieces) instead
-- reclassified into higher power tiers (Strong/Legendary) gated by pool
-- scarcity, not by a carve-out here.
--
-- CORRECTED via live verification, 2026-08-26: my first pass only listed
-- {chips, mult, x_mult, dollars} -- confirmed live that vanilla's base Joker
-- (a flat "+4 Mult" once-per-hand effect) still returned `mult_mod = 4`
-- UNSCALED at Rank 3 (should have been 8). Reading state_events.lua's real
-- effect-application code shows TWO separate field-name conventions
-- depending on which context fired: the context.individual (per-scoring-
-- card) pass our own Suit Guild code already uses real plain `chips`/`mult`/
-- `x_mult`/`dollars` (state_events.lua ~line 727), but the context.joker_main
-- (once-per-hand Joker effect) pass -- what base Joker, and the vast
-- majority of vanilla Jokers' own flat/conditional bonuses, actually use --
-- returns `chip_mod`/`mult_mod`/`Xmult_mod` (capital X) instead
-- (state_events.lua ~line 892). Missing the second set meant Rank was
-- silently not reaching most vanilla Jokers' real contribution at all.
-- Scaling both sets uniformly here, since Card:calculate_joker is the same
-- function for both context types and there's no reason Rank should treat
-- one naming convention differently from the other.
local RANK_SCALED_FIELDS = { 'chips', 'mult', 'x_mult', 'dollars', 'chip_mod', 'mult_mod', 'Xmult_mod' }

local _tft_orig_calculate_joker_rank = Card.calculate_joker
function Card:calculate_joker(context)
	local ret = _tft_orig_calculate_joker_rank(self, context)
	if not ret or not TFT.is_run_active() or self.debuff then return ret end
	if not self.config or not self.config.center or self.config.center.key == 'j_tft_traits_engine' then return ret end

	local mult = TFT.joker_rank_multiplier(self)
	if mult == 1 then return ret end

	for _, field in ipairs(RANK_SCALED_FIELDS) do
		if type(ret[field]) == 'number' then
			ret[field] = ret[field] * mult
		end
	end
	return ret
end

-- 4. Sell value: joker-ranking.md proposes +50% sell value per Rank above 1
-- (Rank 1 = normal, Rank 2 = 1.5x, Rank 3 = 2.0x). Card:set_cost() (card.lua)
-- is vanilla's real, named function computing both buy cost and sell_cost in
-- one place -- hooked here rather than touching sell_card() directly so the
-- displayed sell price (sell_cost_label) and the actual payout
-- (Card:sell_card reads self.sell_cost) both stay in sync automatically.
local _tft_orig_set_cost = Card.set_cost
function Card:set_cost()
	_tft_orig_set_cost(self)
	if not TFT.is_run_active() or not self.ability or self.ability.set ~= 'Joker' then return end
	if not self.config or not self.config.center or self.config.center.key == 'j_tft_traits_engine' then return end

	local rank = TFT.get_joker_rank(self)
	if rank <= 1 then return end

	self.sell_cost = math.max(1, math.floor(self.sell_cost * (1 + 0.5 * (rank - 1))))
	self.sell_cost_label = self.facing == 'back' and '?' or self.sell_cost
end
