-- Hooks vanilla's real Joker rarity roll (common_events.lua's get_current_pool)
-- to use our level-based odds table (domain/rarity_odds.lua's
-- TFT.JokerRarityOddsByLevel) instead of vanilla's flat, ante-independent
-- 70/25/5 Common/Uncommon/Rare split.
--
-- SCOPE GAP, flagged not glossed over: this only reaches vanilla's native
-- 3-roll-tier structure (Common/Uncommon/Rare -- vanilla's own rarity roll
-- here never produces Legendary at all; that's gated by a completely separate
-- `_legendary` flag passed in from elsewhere, not part of this random roll).
-- Our Strong tier isn't a real, separately-pooled SMODS rarity -- it's our own
-- `power_tier` metadata layered on top of vanilla's native 4-rarity scale (see
-- rarity_odds.lua) -- so there's no real "Strong pool" for a shop roll to
-- select into yet. Giving Strong (and Legendary, on a normal roll) their own
-- real, separately-weighted shop appearance needs registering actual
-- SMODS.Rarity objects, which is a real, separate task, not done here. For
-- now: our level table's Strong/Legendary percentages are folded into the
-- Rare bucket (a Strong-tier Joker can still be individually PULLED via
-- Rare's pool -- its power_tier override already routes it there -- it just
-- doesn't get its own distinct odds column the way the design intends yet).
local _tft_orig_get_current_pool = get_current_pool
function get_current_pool(_type, _rarity, _legendary, _append)
	local state = TFT.get_state()

	-- The Big Score (Prismatic, Shop & Items): next reroll guaranteed
	-- Legendary. Consumed here rather than at the reroll button itself --
	-- create_card_for_shop's own Joker branch calls create_card('Joker',
	-- area, nil, nil, ...), which funnels straight into THIS function with
	-- `_rarity`/`_legendary` both nil, so intercepting here reaches the real
	-- shop-card roll regardless of which UI action triggered it. Forces
	-- `_legendary=true` on the real original rather than reimplementing
	-- legendary selection ourselves.
	if _type == 'Joker' and not _rarity and not _legendary and TFT.is_run_active()
		and state and state.big_score_pending then
		state.big_score_pending = nil
		return _tft_orig_get_current_pool(_type, nil, true, _append)
	end

	-- Consumable-odds-by-level (next-session-plan-4.md item 6, domain/
	-- consumable_odds.lua): applies independently of the Joker-rarity logic
	-- below, which this function otherwise exists for -- Tarot/Spectral pools
	-- have no "rarity" concept at all (_rarity/_legendary are always nil for
	-- them), so this branch has to come before the Joker-only early return.
	if (_type == 'Tarot' or _type == 'Spectral') and TFT.is_run_active() then
		local pool, pool_key = _tft_orig_get_current_pool(_type, _rarity, _legendary, _append)
		local level = state and state.level or 1
		return TFT.apply_consumable_weights(pool, level), pool_key
	end

	if _type ~= 'Joker' or _rarity or _legendary or not TFT.is_run_active() then
		return _tft_orig_get_current_pool(_type, _rarity, _legendary, _append)
	end

	local odds = TFT.JokerRarityOddsByLevel[state and state.level or 1]
	if not odds then
		return _tft_orig_get_current_pool(_type, _rarity, _legendary, _append)
	end

	-- 3 buckets: Common | Uncommon | Rare (Strong+Legendary folded into Rare,
	-- per the scope note above).
	local bucket = { odds[1], odds[2], odds[3] + odds[4] + odds[5] }

	-- Monopoly (Prismatic, Economic): a randomly-rolled target power_tier
	-- (state.monopoly_tier, 1-5) doubles its own bucket's share and halves
	-- the other two, for the rest of the match. Tiers 3/4/5 all land in the
	-- same folded "Rare" bucket here (the same pre-existing Strong/Legendary
	-- scope gap noted above), so a Monopoly roll of Strong or Legendary still
	-- reads as "double the Rare bucket" -- consistent with how those tiers
	-- already share one bucket for every other purpose in this file.
	if state and state.monopoly_tier then
		local target = state.monopoly_tier <= 2 and state.monopoly_tier or 3
		for i = 1, 3 do
			bucket[i] = bucket[i] * (i == target and 2 or 0.5)
		end
	end

	local total = bucket[1] + bucket[2] + bucket[3]
	local common_edge = bucket[1] / total
	local uncommon_edge = common_edge + bucket[2] / total
	-- (anything above uncommon_edge, up to 1.0, is Rare)

	-- Ascendants trait tier 1: +5% Rare shop odds (traits/engine.lua). Shrinks
	-- the Uncommon bucket's upper edge, growing Rare's share by the same
	-- amount -- Common's own share is untouched.
	if TFT.ascendants_rare_odds_bonus then
		uncommon_edge = math.max(common_edge, uncommon_edge - TFT.ascendants_rare_odds_bonus())
	end

	local roll = pseudorandom('rarity' .. G.GAME.round_resets.ante .. (_append or ''))
	local rarity = (roll > uncommon_edge and 3) or (roll > common_edge and 2) or 1

	-- Vintage Collection (Prismatic, Shop & Items): once per shop visit, bump
	-- the rolled tier up by one (capped at this file's own 3-bucket ceiling --
	-- see the Strong/Legendary scope note above for why "one tier above Rare"
	-- isn't a distinct destination yet). Reset per shop visit from
	-- round_flow/poll.lua's SHOP-state-entry detection.
	if TFT.has_augment('vintage_collection') and state and not state.vintage_collection_used_this_visit then
		state.vintage_collection_used_this_visit = true
		rarity = math.min(3, rarity + 1)
	end

	-- CORRECTED via live testing: get_current_pool does NOT treat a passed-in
	-- `_rarity` as a final tier -- it re-thresholds it against its OWN
	-- hardcoded 0.7/0.95 breakpoints (`rarity = (rarity>0.95 and 3) or
	-- (rarity>0.7 and 2) or 1`), even when _rarity is already an integer.
	-- Passing 1, 2, or 3 directly collapsed EVERY roll to Rare (1 and 2 are
	-- both > 0.95 too!) -- confirmed live via a level-1 test that should have
	-- been 100% Common and instead returned a Rare card every time. Fixed by
	-- passing a representative float that lands in the correct vanilla bucket
	-- instead of the tier number itself.
	local representative_roll = ({ [1] = 0.5, [2] = 0.8, [3] = 0.96 })[rarity]
	local pool, pool_key = _tft_orig_get_current_pool(_type, representative_roll, _legendary, _append)
	return TFT.filter_pool_by_shared_availability(pool), pool_key
end

-- Shared Joker Pool (docs/design/joker-ranking.md, next-session-plan.md
-- priority #2): lobby-wide scarcity, multiplayer only -- solo play has no
-- lobby to share a pool across, so it's left untouched (every existing
-- rarity/odds/augment logic above still applies as-is). Real vanilla/SMODS
-- code throughout this same pool system (SMODS.get_clean_pool,
-- SMODS.get_next_vouchers, etc. -- functions/common_events.lua,
-- SMODS/_/src/utils.lua) already treats the literal string 'UNAVAILABLE' as
-- "skip and resample" for exactly this kind of slot exclusion -- reusing that
-- existing, sanctioned convention rather than inventing a second one.
--
-- Snapshot-refresh, not live-tracked (the design doc's own resolved choice):
-- this reads whatever TFT._lobby_joker_ownership currently holds (last
-- broadcast from each player, objects/actions/joker_ownership.lua) at the
-- moment THIS shop roll happens -- no live decrementing, no purchase-time
-- locking. Two players' shops opening close together in time can both see
-- "copies available" and both actually buy the last one or two -- an
-- accepted, rare pool overrun (the doc's own "Confirmed: option 1"), not a
-- bug to guard against here.
function TFT.filter_pool_by_shared_availability(pool)
	local state = TFT.get_state()
	if not state or not state.is_multiplayer or not pool then return pool end

	for i, key in ipairs(pool) do
		if key ~= 'UNAVAILABLE' and G.P_CENTERS[key] and G.P_CENTERS[key].set == 'Joker'
			and key ~= 'j_tft_traits_engine' then
			local tier = TFT.get_power_tier(key, G.P_CENTERS[key].rarity)
			local available = TFT.shared_pool_size(tier) - TFT.copies_owned_lobby_wide(key)
			if available <= 0 then
				pool[i] = 'UNAVAILABLE'
			end
		end
	end
	return pool
end
