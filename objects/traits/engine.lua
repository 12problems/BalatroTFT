-- Trait counting + the single invisible "Traits Engine" pseudo-Joker that
-- applies breakpoint effects. Pattern confirmed in technical.md: one hidden,
-- slot-free, always-present Joker per player rather than many scattered hook
-- registrations.
--
-- SCOPE: counting/tier-crossing detection is fully real for all 9 traits (this
-- is the actual "traits system in place to detect them" ask). Mechanical
-- effects for all 9 are now wired: Suit Guilds/Scholars/Financiers via a
-- normal scoring `calculate` context or a simple additive stat (original
-- pass); Multipliers/Scalers via a Card:calculate_joker wrap reaching every
-- OTHER Joker's own return value/persistent accumulator fields generically;
-- Encore's retrigger+xMult via vanilla's real context.repetition/
-- context.individual passes; Ascendants' shop-odds (rare + Negative-edition,
-- via get_current_pool/poll_edition), Joker-slot grants, tier-8 card
-- retrigger, and tier-10 x10 Mult (all added in the 2026-08-25 trait-effects
-- pass, see this file's own hook comments below for exact scope/gaps still
-- flagged on each -- most notably Ascendants tier-8's "Joker effects also
-- retrigger" clause and tier-8's "Legendary shop odds match Rare" clause,
-- neither of which has a clean vanilla mechanism found yet).

-- Recomputes trait tag counts by scanning owned Jokers. NOT cached this session
-- (technical.md recommends caching, invalidated on Joker add/remove) --
-- simplified to a plain recompute-on-call, since a player's Joker count is small
-- (<=7) and this only runs from `calculate`, not every frame. Flagged as a
-- deliberate scope-down from the doc's recommendation.
function TFT.count_trait_tags()
	local counts = {}
	if not G.jokers or not G.jokers.cards then return counts end
	for _, card in ipairs(G.jokers.cards) do
		for _, tag in ipairs(TFT.get_trait_tags(card)) do
			counts[tag] = (counts[tag] or 0) + 1
		end
	end
	return counts
end

-- trait_key -> tier currently reached (0 if below the first breakpoint).
-- Trait Heart (Gold, Trait & Emblem) adds +2 to its chosen trait's count here,
-- AFTER the real per-card scan -- see tagging.lua's TFT.trait_heart_bonus.
function TFT.get_active_trait_tiers()
	local counts = TFT.count_trait_tags()
	local tiers = {}
	for trait_key, _ in pairs(TFT.Traits) do
		local count = (counts[trait_key] or 0) + (TFT.trait_heart_bonus and TFT.trait_heart_bonus(trait_key) or 0)
		tiers[trait_key] = TFT.trait_tier_reached(trait_key, count)
	end
	return tiers
end

local SUIT_TAG = {
	Spades = 'SpadesGuild',
	Clubs = 'ClubsGuild',
	Diamonds = 'DiamondsGuild',
	Hearts = 'HeartsGuild',
}

-- Suit Guild breakpoint effects, applied when a card of that suit scores.
-- tier: 1 or 2 (2/3-owned breakpoints).
local function suit_guild_effect(suit, tier)
	if suit == 'Spades' then
		return tier >= 2 and { chips = 40, mult = 2 } or { chips = 20 }
	elseif suit == 'Clubs' then
		return { mult = tier >= 2 and 8 or 4 }
	elseif suit == 'Diamonds' then
		return { dollars = tier >= 2 and 3 or 2 }
	elseif suit == 'Hearts' then
		-- Tier 2 also adds a 50%-per-Heart heal, capped at 10/round -- healing
		-- is applied directly (not through the chip/mult/dollar return table),
		-- see below.
		return {}
	end
	return {}
end

TFT._hearts_healed_this_round = TFT._hearts_healed_this_round or 0

SMODS.Joker {
	key = 'traits_engine',
	loc_txt = {
		name = 'Traits Engine',
		text = { '{C:inactive}(Internal -- applies TFT Trait breakpoint bonuses. Should never be visible in a real shop/collection.)' },
	},
	config = { extra = {} },
	rarity = 1,
	cost = 0,
	unlocked = true,
	discovered = true,
	blueprint_compat = false,
	eternal_compat = false,
	pos = { x = 0, y = 0 },
	-- CORRECTED via live testing: 'ChangeStake' is not a real Joker spritesheet
	-- -- referencing an invalid atlas broke card construction before
	-- `.ability` got set at all, crashing the whole game the next frame
	-- (card.lua's update_alert indexing self.ability.set) every time this card
	-- was created, regardless of which create_card API was used. 'Joker' is
	-- vanilla's real base Joker spritesheet -- pos={0,0} just means this card
	-- visually looks like the base "Joker" card if it's ever actually seen,
	-- which shouldn't happen given in_pool below, but is a real, valid atlas
	-- reference rather than a broken placeholder.
	atlas = 'Joker',
	prefix_config = { atlas = false }, -- opt out of atlas-prefixing (SMODS default) -- caught live: without this, SMODS looked up 'tft_Joker' (doesn't exist) instead of vanilla's real 'Joker' atlas, throwing an assert that our pcall silently swallowed, leaving a half-constructed Card with nil .ability that crashed the next frame
	in_pool = function(self) return false end, -- never appears in shop/booster pools

	calculate = function(self, card, context)
		local tiers = TFT.get_active_trait_tiers()

		-- context.joker_main fires once per hand played (the same real pass
		-- Tip Jar already used) -- home for every augment whose effect is
		-- "once per hand," not per scoring card.
		if context.joker_main then
			local state = TFT.get_state()

			-- Tip Jar (Silver, Economic): +$1 every scoring hand.
			if TFT.has_augment('tip_jar') then
				ease_dollars(1)
			end

			-- Level Up (Gold, Combat & Stats): the FIRST hand type played each
			-- round permanently gains +2 levels. Tracked via a per-round marker
			-- on state (plain data, save-safe) rather than a bare global, since
			-- it needs to survive exactly one round and reset every round.
			if TFT.has_augment('level_up') and state and context.scoring_name then
				if state.level_up_done_for_round ~= state.round_index then
					state.level_up_done_for_round = state.round_index
					level_up_hand(nil, context.scoring_name, true, 2)
				end
			end

			-- Encore Performance (Gold, Combat & Stats): playing the same hand
			-- type as your immediately-previous hand grants +1 hand that round,
			-- once per distinct hand type per round (a different hand type back-
			-- to-back can trigger it again, per augments.md).
			if TFT.has_augment('encore_performance') and state and context.scoring_name then
				state.encore_triggered_types = state.round_index == state.encore_round_index and state.encore_triggered_types or {}
				state.encore_round_index = state.round_index
				if state.last_hand_type_played == context.scoring_name and not state.encore_triggered_types[context.scoring_name] then
					state.encore_triggered_types[context.scoring_name] = true
					G.GAME.current_round.hands_left = (G.GAME.current_round.hands_left or 0) + 1
				end
				state.last_hand_type_played = context.scoring_name
			end

			-- Glass Cannon (Silver, Risky) and Boom or Bust (Gold, Risky) both
			-- contribute a hand-wide xMult through this same once-per-hand pass
			-- -- merged into one return since both could theoretically be
			-- active at once (a player could pick both across different
			-- checkpoints).
			local hand_x_mult = 1
			if TFT.has_augment('glass_cannon') then
				hand_x_mult = hand_x_mult * 2
			end
			if TFT.has_augment('boom_or_bust') then
				local hands_played = G.GAME.current_round.hands_played or 0
				hand_x_mult = hand_x_mult * (hands_played == 0 and 3 or 0.75)
			end
			if TFT.has_augment('all_or_nothing') then
				hand_x_mult = hand_x_mult * 10
			end
			if hand_x_mult ~= 1 then
				return { x_mult = hand_x_mult }
			end
		end

		-- context.individual fires once per SCORING card -- merges Suit Guilds'
		-- per-suit bonus with Encore's tier4/6 "gains x2 Mult" and Ascendants'
		-- tier10 "x10 Mult on all scored cards", since only one table can be
		-- returned per calculate() call and any/all of these can be active on
		-- the same card simultaneously.
		if context.individual and context.cardarea == G.play and context.other_card then
			local effect = {}
			local has_effect = false

			local suit = context.other_card:get_id() and context.other_card.base and context.other_card.base.suit
			local tag = suit and SUIT_TAG[suit]
			local guild_tier = tag and tiers[tag] or 0
			if guild_tier > 0 then
				local guild_effect = suit_guild_effect(suit, guild_tier)
				if suit == 'Hearts' and guild_tier >= 2 and TFT._hearts_healed_this_round < 10 then
					local heal = math.min(1, 10 - TFT._hearts_healed_this_round)
					if pseudorandom('tft_hearts_heal') < 0.5 then
						TFT._hearts_healed_this_round = TFT._hearts_healed_this_round + heal
						guild_effect.message = 'Heal!'
					end
				end
				if guild_effect.chips or guild_effect.mult or guild_effect.dollars then
					effect.chips, effect.mult, effect.dollars = guild_effect.chips, guild_effect.mult, guild_effect.dollars
					effect.message = guild_effect.message
					has_effect = true
				end
			end

			-- Encore tier 2 (breakpoint index 1): first + last scored card each
			-- retrigger once -- handled below in the context.repetition branch,
			-- not here (retriggers are a separate dispatch pass in vanilla, see
			-- that branch's own doc comment). This block only covers the tier
			-- 4/6 x2-Mult half of Encore's effect.
			local encore_tier = tiers.Encore or 0
			if encore_tier >= 2 then
				local is_last = context.other_card == context.scoring_hand[#context.scoring_hand]
				if encore_tier >= 3 or is_last then
					effect.x_mult = (effect.x_mult or 1) * 2
					has_effect = true
				end
			end

			-- Ascendants tier 10 (breakpoint index 4): x10 Mult on every scored
			-- card. Pre-revisit numbers per traits.md -- see engine.lua's header
			-- comment on the documented, deferred Ascendants rebalance.
			if (tiers.Ascendants or 0) >= 4 then
				effect.x_mult = (effect.x_mult or 1) * 10
				has_effect = true
			end

			-- Fundamentals (Silver, Combat & Stats): a card permanently gains
			-- +1 Chip/+1 Mult every time IT SPECIFICALLY scores, stacking --
			-- same precedent as vanilla Hiker (a per-card persistent
			-- accumulator on the PLAYING CARD's own ability table, not a
			-- global). Applied here (read+increment together) since this pass
			-- doesn't need a separate write-time hook -- the accumulated value
			-- is both stored and scored in the same place.
			if TFT.has_augment('fundamentals') then
				local pc = context.other_card
				pc.ability.tft_fundamentals_chips = (pc.ability.tft_fundamentals_chips or 0) + 1
				pc.ability.tft_fundamentals_mult = (pc.ability.tft_fundamentals_mult or 0) + 1
				effect.chips = (effect.chips or 0) + pc.ability.tft_fundamentals_chips
				effect.mult = (effect.mult or 0) + pc.ability.tft_fundamentals_mult
				has_effect = true
			end

			-- Print Money (Prismatic, Economic): $1 for every card scored this
			-- round (across all hands played). Pure side effect -- doesn't
			-- contribute to the score itself, so it doesn't set has_effect.
			if TFT.has_augment('print_money') then
				ease_dollars(1)
			end

			if has_effect then return effect end
		end

		-- context.repetition is vanilla's real, separate per-card RETRIGGER
		-- dispatch pass (confirmed against card.lua's Hack/Seltzer/Hanging Chad/
		-- Mime/Sock and Buskin/Dusk -- all return {repetitions = N, card = self}
		-- from exactly this context, keyed off context.cardarea and
		-- context.other_card/context.scoring_hand). Reused here verbatim rather
		-- than reimplementing retriggering: Encore (first+last card at tier2,
		-- every card at tier6) and Ascendants tier8 ("retrigger all played/
		-- held-in-hand card effects twice") both just contribute a
		-- `repetitions` count through this same real pass. NOTE: Ascendants
		-- tier8's "and Joker effects" clause is NOT covered here -- no clean
		-- vanilla mechanism for retriggering another Joker's own calculate()
		-- call was found (Blueprint COPIES a Joker, it doesn't retrigger one);
		-- flagged as a real, deliberate scope gap, not silently dropped.
		if context.repetition and context.other_card then
			local reps = 0
			local encore_tier = tiers.Encore or 0
			local ascendants_tier = tiers.Ascendants or 0

			if encore_tier > 0 then
				local hand = context.scoring_hand
				local is_first = hand and context.other_card == hand[1]
				local is_last = hand and context.other_card == hand[#hand]
				if encore_tier >= 3 then
					reps = reps + 1 -- every card, tier 6
				elseif encore_tier >= 1 and (is_first or is_last) then
					reps = reps + 1 -- first + last only, tier 2/4
				end
			end

			if ascendants_tier >= 3 then
				reps = reps + 2 -- tier 8: all played/held-in-hand effects retrigger twice
			end

			-- Adrenaline (Gold, Combat & Stats): on your final hand of the
			-- round, if you're behind, every played card retriggers once.
			-- ASSUMPTION: "behind" always compares against the blind's own
			-- chip requirement (G.GAME.blind.chips), not a live PvP opponent
			-- score -- this mod only learns the opponent's score AFTER a PvP
			-- round fully resolves (objects/actions/round_result.lua), so
			-- there's no real "opponent's current progress" to compare against
			-- mid-hand even during a real PvP round. augments.md itself
			-- explicitly allows this exact fallback for non-PvP rounds; this
			-- pass just uses it unconditionally rather than only outside PvP.
			if TFT.has_augment('adrenaline') and G.GAME.current_round.hands_left == 0
				and G.GAME.chips < G.GAME.blind.chips then
				reps = reps + 1
			end

			if reps > 0 then
				-- CAUGHT via live crash (functions/common_events.lua:1113:
				-- "attempt to call method 'juice_up' (a nil value)"): vanilla's
				-- own card.lua examples write `card = self` because THEIR
				-- `self` param IS the Card (they're real Card:calculate_joker
				-- methods). Our SMODS.Joker{calculate=function(self, card,
				-- context)} signature is different -- `self` here is the
				-- CENTER/definition table, `card` is the actual Card instance.
				-- Whatever consumes this `card` field later calls a real Card
				-- method (:juice_up(), the retrigger bounce animation) on it --
				-- passing the center instead crashed the instant a retrigger
				-- actually fired.
				return { message = localize('k_again_ex'), repetitions = reps, card = card }
			end
		end

		return nil
	end,
}

-- Ensures the player has exactly one copy of the Traits Engine pseudo-Joker,
-- added directly to the Joker area (bypassing shop/pack draw entirely). Called
-- from Game:start_run (hooks.lua). Card key is prefixed by SMODS with this
-- mod's `prefix` field (see BalatroTFT.json) -- resolves to
-- 'j_tft_traits_engine', confirmed live.
--
-- FIXED via live testing: the first attempt used `SMODS.create_card({...})`,
-- which produced a Card with a nil `.ability` and crashed the whole game the
-- next frame (card.lua's update_alert indexing self.ability.set). The real,
-- correct API -- confirmed against ClaudeControl's own api/cheats.lua
-- `spawn_joker` -- is the global `create_card(_type, area, legendary, rarity,
-- skip_materialize, soulable, forced_key)` function, not a SMODS.* method.
function TFT.ensure_traits_engine_joker()
	if not G.jokers then return end
	for _, c in ipairs(G.jokers.cards) do
		if c.config and c.config.center and c.config.center.key == 'j_tft_traits_engine' then
			return -- already present
		end
	end
	local card = create_card('Joker', G.jokers, nil, nil, nil, nil, 'j_tft_traits_engine')
	card:add_to_deck()
	G.jokers:emplace(card)
end

-- Financiers: interest cap 25 (vanilla default) -> 30/50/100 at tiers 1/2/3.
-- Set as an absolute override (not a delta) since it directly replaces
-- vanilla's own G.GAME.interest_cap field -- re-applied every round so
-- selling down out of a tier correctly drops back, not just crossing up.
-- CAVEAT: stomps whatever value real vanilla interest vouchers (e.g. Money
-- Tree tracking, if such a voucher were ever granted) might also want to set
-- -- acceptable for this pass, not layered/additive with other interest_cap
-- sources.
local FINANCIERS_CAP_BY_TIER = { [0] = 25, [1] = 30, [2] = 50, [3] = 100 }

-- Ascendants: rare-shop-odds bonus by tier (traits.md, pre-revisit numbers --
-- tier 1 = +5%, tier 2 = +15% total, tiers 3/4 hold at 15% -- the doc's tier-8
-- "Legendary shop odds raised to match Rare" clause is NOT covered by this
-- number, see shop_odds.lua's own scope note on how narrow vanilla's real
-- Legendary-in-shop mechanism is). Consumed by shop_odds.lua's hook.
local ASCENDANTS_RARE_ODDS_BONUS_BY_TIER = { [0] = 0, [1] = 0.05, [2] = 0.15, [3] = 0.15, [4] = 0.15 }
function TFT.ascendants_rare_odds_bonus()
	local tiers = TFT.get_active_trait_tiers()
	return ASCENDANTS_RARE_ODDS_BONUS_BY_TIER[tiers.Ascendants or 0] or 0
end

-- Ascendants: Negative-edition odds bonus by tier (tier 5 = +5%, tier 8 =
-- +10% total, tier 10 unchanged). Consumed by this file's poll_edition hook,
-- below. Vanilla's own baseline Negative chance is tiny (0.3% * _mod) --
-- these numbers are a deliberate, large buff per traits.md's own "stars
-- align" framing, not a rounding-scale tweak.
local ASCENDANTS_NEGATIVE_ODDS_BONUS_BY_TIER = { [0] = 0, [1] = 0, [2] = 0.05, [3] = 0.10, [4] = 0.10 }
function TFT.ascendants_negative_odds_bonus()
	local tiers = TFT.get_active_trait_tiers()
	return ASCENDANTS_NEGATIVE_ODDS_BONUS_BY_TIER[tiers.Ascendants or 0] or 0
end

-- CORRECTED via live testing, 2026-08-25's trait-effects pass: poll_edition is
-- a real, named global (functions/common_events.lua) called for every shop/
-- pack card's edition roll -- confirmed hookable the same way as
-- get_current_pool. `pseudorandom(pseudoseed(key))` is a pure function of
-- (key, run seed), not a mutating RNG stream, so computing our own extra check
-- with the SAME key before falling through to the real function doesn't
-- desync or double-consume anything -- it just re-derives the identical
-- number vanilla's own call would get.
local _tft_orig_poll_edition = poll_edition
function poll_edition(_key, _mod, _no_neg, _guaranteed)
	local bonus = (TFT.is_run_active() and not _no_neg and not _guaranteed) and TFT.ascendants_negative_odds_bonus() or 0
	if bonus > 0 then
		local edition_poll = pseudorandom(pseudoseed(_key or 'edition_generic'))
		if edition_poll > 1 - bonus then
			return { negative = true }
		end
	end
	return _tft_orig_poll_edition(_key, _mod, _no_neg, _guaranteed)
end

-- Multipliers (tier 1/2/3 = +20%/40%/60% "stronger" xMult effects) and
-- Scalers (tier 1-5 = 2x/4x/6x/8x/10x faster permanent accumulation) both
-- need to react to OTHER Jokers' own calculate() output -- the harder,
-- cross-cutting hook category this session's earlier trait pass explicitly
-- deferred. Card:calculate_joker(context) (card.lua) is the real, named,
-- per-Joker dispatch method EVERY Joker's effect (including vanilla's own
-- giant built-in card.lua branches) runs through -- wrapping it here reaches
-- every Joker generically, without needing to reimplement or enumerate each
-- one's internal logic:
--   * Multipliers: if calculate_joker's return table carries a one-shot
--     `x_mult` (vanilla's real field for a multiplicative Mult contribution,
--     confirmed in functions/state_events.lua's `mult = mod_mult(mult *
--     effects[ii].x_mult)` apply site), scale the multiplier's EXCESS over 1
--     by the tier bonus -- e.g. tier 1 turns a x2 contribution into x2.2, not
--     x2.4 (interpreting "stronger" as amplifying the bonus itself, not the
--     whole multiplier including its neutral baseline). Flagged as my own
--     reading of "apply +20% stronger", not a transcribed spec.
--   * Scalers: most vanilla "grows over time" Jokers (Constellation,
--     Throwback, Glass Joker, Hit the Road, Madness, Vampire, Hologram,
--     Obelisk, Lucky Cat, Ramen, Campfire, Yorick, etc., confirmed via
--     `self.ability.x_mult = self.ability.x_mult + self.ability.extra`-style
--     lines throughout card.lua) accumulate into one of a small set of
--     persistent `self.ability` fields. Rather than enumerating and
--     special-casing every one of the ~15-17 candidates individually,
--     snapshot those fields before calling the original, and amplify
--     whatever positive delta actually occurred by the tier's rate -- a
--     generic mechanism that reaches the whole population uniformly and
--     stays correct if new Scaler-tagged Jokers are added later.
local MULTIPLIERS_BONUS_BY_TIER = { [1] = 0.2, [2] = 0.4, [3] = 0.6 }
local SCALERS_RATE_BY_TIER = { [1] = 2, [2] = 4, [3] = 6, [4] = 8, [5] = 10 }
local SCALER_ACCUMULATOR_FIELDS = { 'x_mult', 'mult', 'chips' }

local _tft_orig_calculate_joker = Card.calculate_joker
function Card:calculate_joker(context)
	if not TFT.is_run_active() or self.debuff then
		return _tft_orig_calculate_joker(self, context)
	end

	local tiers = TFT.get_active_trait_tiers()
	local scalers_tier = tiers.Scalers or 0
	local is_scaler = scalers_tier > 0 and self.ability and TFT.card_has_trait_tag(self, 'Scalers')

	local snapshot
	if is_scaler then
		snapshot = {}
		for _, field in ipairs(SCALER_ACCUMULATOR_FIELDS) do
			snapshot[field] = self.ability[field]
		end
	end

	local ret = _tft_orig_calculate_joker(self, context)

	if is_scaler then
		local rate = SCALERS_RATE_BY_TIER[scalers_tier] or 1
		for _, field in ipairs(SCALER_ACCUMULATOR_FIELDS) do
			local before, after = snapshot[field], self.ability[field]
			if type(before) == 'number' and type(after) == 'number' and after > before then
				self.ability[field] = before + (after - before) * rate
			end
		end
	end

	-- CORRECTED alongside ranking.lua's own matching fix: vanilla's
	-- context.joker_main pass (once-per-hand Joker effects) returns a
	-- multiplicative xMult contribution as `Xmult_mod` (capital X), a
	-- DIFFERENT field than the context.individual (per-scoring-card) pass's
	-- `x_mult` -- both need scaling, not just the lowercase one.
	local mult_tier = tiers.Multipliers or 0
	if ret and mult_tier > 0 and TFT.card_has_trait_tag(self, 'Multipliers') then
		local bonus = MULTIPLIERS_BONUS_BY_TIER[mult_tier] or 0
		if ret.x_mult and ret.x_mult > 1 then
			ret.x_mult = 1 + (ret.x_mult - 1) * (1 + bonus)
		end
		if ret.Xmult_mod and ret.Xmult_mod > 1 then
			ret.Xmult_mod = 1 + (ret.Xmult_mod - 1) * (1 + bonus)
		end
	end

	return ret
end

-- Called once per round-advance (poll.lua) to reset per-round counters, apply
-- the trait effects that are real absolute overrides or slot deltas, and log
-- tier changes for the not-yet-mechanically-wired traits so testing can at
-- least confirm detection/tier-crossing is correct even where the effect
-- itself isn't hooked up yet.
TFT._last_logged_tiers = TFT._last_logged_tiers or {}

-- Ascendants' own cumulative Joker-slot grant by tier (tier 1 = +1, tier 2 =
-- +1 more/+2 total, tiers 3/4 don't add further per traits.md).
local ASCENDANTS_SLOTS_BY_TIER = { [0] = 0, [1] = 1, [2] = 2, [3] = 2, [4] = 2 }

function TFT.trait_round_reset()
	TFT._hearts_healed_this_round = 0
	local tiers = TFT.get_active_trait_tiers()

	if G.GAME then
		G.GAME.interest_cap = FINANCIERS_CAP_BY_TIER[tiers.Financiers or 0] or 25
	end

	-- Scalers tier 6 (breakpoint index 3): "Scaler-tagged Jokers now take up
	-- only half a Joker slot each." No vanilla mechanic grants a fractional
	-- slot cost directly (every purchase/pack-add gate is a plain `#cards <
	-- card_limit` integer comparison across many call sites) -- implemented
	-- as the equivalent real capacity increase instead: +1 actual Joker slot
	-- for every 2 currently-owned Scaler-tagged Jokers, recomputed (as a
	-- delta against the last amount granted, tracked in
	-- TFT._scalers_slots_granted) every round so it stays correct as the
	-- owned count changes, not just on the tier-cross moment.
	TFT._scalers_slots_granted = TFT._scalers_slots_granted or 0
	if G.jokers and G.jokers.config then
		local target_slots = 0
		-- Critical Mass (Prismatic, Trait & Emblem): lowers this gate from
		-- tier>=3 (6 owned) to tier>=1 (2 owned) -- the half-slot unlock
		-- applies starting from your very first Scaler, per augments.md.
		local scalers_gate = TFT.has_augment('critical_mass') and 1 or 3
		if (tiers.Scalers or 0) >= scalers_gate then
			local scaler_count = 0
			for _, c in ipairs(G.jokers.cards) do
				if TFT.card_has_trait_tag(c, 'Scalers') then scaler_count = scaler_count + 1 end
			end
			target_slots = math.floor(scaler_count / 2)
		end
		local slot_delta = target_slots - TFT._scalers_slots_granted
		if slot_delta ~= 0 then
			G.jokers.config.card_limit = (G.jokers.config.card_limit or 0) + slot_delta
			TFT._scalers_slots_granted = target_slots
		end
	end

	for trait_key, tier in pairs(tiers) do
		local prev_tier = TFT._last_logged_tiers[trait_key] or 0
		if tier ~= prev_tier then
			TFT.sendDebugMessage('Trait tier changed: ' .. trait_key .. ' -> tier ' .. tier)
			if trait_key == 'Scholars' and G.consumeables and G.consumeables.config then
				local slot_delta = (tier >= 1 and 1 or 0) - (prev_tier >= 1 and 1 or 0)
				G.consumeables.config.card_limit = (G.consumeables.config.card_limit or 0) + slot_delta
			end
			if trait_key == 'Ascendants' and G.jokers and G.jokers.config then
				local slot_delta = (ASCENDANTS_SLOTS_BY_TIER[tier] or 0) - (ASCENDANTS_SLOTS_BY_TIER[prev_tier] or 0)
				G.jokers.config.card_limit = (G.jokers.config.card_limit or 0) + slot_delta
			end
			TFT._last_logged_tiers[trait_key] = tier
		end
	end
end
