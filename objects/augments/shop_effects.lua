-- Shop & Items category augments that need a hook beyond the pick-time
-- `apply()` -- reroll cost/free-reroll tracking, purchase discounts, and pack
-- choice count, each on the real vanilla function that already owns that
-- specific piece of state.

-- Golden Touch (Gold): every 3rd reroll is free. Reroll Refund (Gold): track
-- money actually spent on rerolls this stage, paid out at stage end from
-- round_flow/poll.lua's stage-change hook.
--
-- BUG FOUND & FIXED (next-session-plan-3.md priority #2.1's own verification
-- debt turned up a real one): setting G.GAME.current_round.free_rerolls here
-- does NOT make THIS click free. Confirmed by reading the real installed
-- functions/button_callbacks.lua's own G.FUNCS.reroll_shop: it deducts
-- `ease_dollars(-G.GAME.current_round.reroll_cost)` using whatever cost was
-- ALREADY calculated from a PRIOR click, before it ever looks at
-- `free_rerolls` -- that field only gets consulted afterward, inside a
-- same-click `Event`, to decide the NEXT reroll's cost via
-- calculate_reroll_cost (functions/common_events.lua), and gets decremented
-- back to 0 in that same pass. Net effect of the old code: the "free" reroll
-- was charged full price every time, live-verified (3 real reroll clicks
-- through the actual shop UI, dollars dropped by the full listed cost on
-- click 3 exactly like clicks 1-2). Fixed by zeroing THIS click's own
-- reroll_cost directly -- vanilla's `if reroll_cost > 0` guard then charges
-- nothing -- while still setting free_rerolls so calculate_reroll_cost's
-- post-click bookkeeping doesn't ratchet the cost up off the back of a free
-- use. Re-verified live: the 6th real reroll (2nd multiple of 3) cost $0.
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
				G.GAME.current_round.reroll_cost = 0
				was_free = true
				cost = 0
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

-- BUG FOUND & FIXED (next-session-plan-3.md priority #2.1's own verification
-- debt turned up a real scope gap): the block above only ever fires for
-- Joker/consumable purchases. Confirmed via a real UI-driven voucher buy
-- through the actual shop screen (money dropped by the full $10 listed price,
-- state.frequent_buyer_count did NOT increment) and via source read of the
-- real installed card.lua: Vouchers and Booster packs are never routed
-- through G.FUNCS.buy_from_shop at all -- their UI buttons dispatch through
-- G.FUNCS.use_card into Card:open()/Card:redeem(), which each do their own
-- unconditional `ease_dollars(-self.cost)` internally, entirely bypassing the
-- hook above. "Every 5th shop purchase (any item type)" therefore silently
-- meant "any JOKER/consumable purchase" only. Fixed the same way as
-- buy_from_shop above: mutate self.cost before calling through, gated on
-- self.cost > 0 so a tag-granted voucher or pack-drawn voucher (both
-- confirmed elsewhere in card.lua to carry cost 0, never having been
-- actually purchased) can't accidentally consume a count.
local function tft_apply_frequent_buyer(card)
	local state = TFT.get_state()
	if state and TFT.is_run_active() and TFT.has_augment('frequent_buyer') and card and card.cost and card.cost > 0 then
		state.frequent_buyer_count = (state.frequent_buyer_count or 0) + 1
		if state.frequent_buyer_count % 5 == 0 then
			card.cost = math.max(0, math.floor(card.cost * 0.5))
		end
	end
end

local _tft_orig_card_open = Card.open
function Card:open(...)
	if self.ability.set == 'Booster' then tft_apply_frequent_buyer(self) end
	return _tft_orig_card_open(self, ...)
end

local _tft_orig_card_redeem = Card.redeem
function Card:redeem(...)
	if self.ability.set == 'Voucher' then tft_apply_frequent_buyer(self) end
	return _tft_orig_card_redeem(self, ...)
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

-- Double Pack (Prismatic): buying a booster pack opens 2 packs of that type
-- instead of 1, for the same price.
--
-- STILL DELIBERATELY DISABLED below, after a second full pass (2026-08-28)
-- that made real progress but did NOT close it out -- four MORE real bugs
-- were found and fixed live this pass (on top of the two from the original
-- attempt), and a FIFTH, deeper one was found that isn't fixed: the two
-- packs' contents can land in the same CardArea and merge into one 6-card
-- choice instead of two separate 3-card ones (confirmed live by direct user
-- observation while watching this exact test). Root-caused but not yet
-- fixed -- see BUG #6 below for the concrete next step.
--
-- Design: hook the same Card.open choke point Pack Rat/Frequent Buyer
-- already use, one layer out. Can't call self:open() a second time on the
-- SAME card object -- the real open() tears the original card down
-- (self:explode(), area:remove_card, etc.) -- so a second pack needs a
-- genuinely new card instance: SMODS.create_card({key = <same center key>})
-- reproduces a real shop booster card's exact shape (confirmed live to
-- match ability.set/name/extra/choose against a real shop-stocked card of
-- the same key). Timing: can't fire the second open() immediately after the
-- first, since vanilla's own open() is itself a long chain of delayed
-- G.E_MANAGER events -- polls G.booster_pack (cleared by
-- G.FUNCS.end_consumeable once the player finishes/skips) once per tick
-- instead of guessing a delay, the same lesson this file's Shared Joker Pool
-- sell-broadcast fix (objects/actions/joker_ownership.lua) already had to
-- learn this same pass.
--
-- BUG #1, FOUND & FIXED live (original attempt): calling `clone:open()`
-- directly left the game stuck (G.STATE went nil, the pack-choice panel
-- frozen mid-fade after skipping the second pack). Root cause: normal shop
-- interaction always opens a booster through G.FUNCS.use_card, which sets
-- `G.GAME.PACK_INTERRUPT = G.STATE` before calling `card:open()` --
-- end_consumeable (the real close-out path both "finish choosing" and
-- "skip" funnel into) restores G.STATE from that value, then nils it.
-- `Card:open()` itself never touches PACK_INTERRUPT -- only use_card does.
--
-- BUG #2, FOUND & FIXED live (original attempt): fixing #1 by setting
-- PACK_INTERRUPT manually stopped the freeze, but the second pack's own card
-- contents then never appeared -- confirmed live: G.pack_cards.cards stayed
-- nil, and G.pack_cards.VT.y (12.55) was stuck above G.ROOM.T.h (11.5), the
-- exact condition card.lua's own Card:open() checks before it will actually
-- emplace freshly-created pack contents into the visible area. Root cause:
-- G.FUNCS.use_card (button_callbacks.lua) does its own separate
-- repositioning of G.shop/G.booster_pack/etc into the pack-display layout
-- before ever calling card:open() -- none of which runs when :open() is
-- called directly. Fixed by routing the second pack through G.FUNCS.use_card
-- itself (a synthetic `{config={ref_table=clone}}`, the same shape a real
-- click passes) instead of calling :open() directly.
--
-- BUG #3, FOUND AND FIXED live (this pass, 2026-08-28): with #1 and #2 both
-- fixed, VT.y correctly read 10.88 (< ROOM.h) on the second pack -- but
-- G.pack_cards.cards was STILL nil (confirmed :is(CardArea) true, so it's a
-- real CardArea, just never populated). Root cause, confirmed live via direct
-- instrumentation (NOT the original attempt's "state must change value"
-- theory, which turned out to be wrong): `SMODS.Booster.update_pack`
-- (game_object.lua) is gated on the plain `G.STATE_COMPLETE` flag, not on
-- G.STATE actually changing, and `Card:open()` DOES unconditionally set
-- `G.STATE_COMPLETE = false` at its own very top before anything else
-- (confirmed by reading the real installed card.lua) -- but something ELSE
-- flips it back to `true` again before update_pack's own next per-frame
-- check (exact culprit not pinned down -- circumstantial evidence points at
-- G.FUNCS.use_card's own surrounding bookkeeping, one layer out from
-- Card:open() itself, but not confirmed against its full source), so
-- update_pack's guard never re-fires and the second pack's card-creation
-- chain (Card:open()'s own delayed self:explode() + later SMODS.create_card
-- loop) ends up emplacing real cards into the FIRST pack's now-orphaned
-- CardArea instead, which nothing displays again. Confirmed live: forcing
-- `G.STATE_COMPLETE = false` a moment after the stall reproduced a correctly
-- rebuilt `G.pack_cards` (fresh table address, fresh empty CardArea). Fix:
-- re-assert `G.STATE_COMPLETE = false` defensively right after triggering the
-- clone's own use_card call, rather than relying on Card:open()'s own
-- assignment surviving unclobbered.
--
-- BUG #4, FOUND AND FIXED live (this pass): once bug #3's STATE_COMPLETE fix
-- was in place, triggering the second pack's own `G.FUNCS.use_card` call from
-- INSIDE a `G.E_MANAGER:add_event` callback -- tried both
-- `trigger = 'immediate'` and `trigger = 'after'` polling, same result either
-- way -- reproducibly hung the whole game solid (ClaudeControl's own TCP
-- listener stopped answering entirely, not just slow; the OS process itself
-- stayed "Responding: True" the whole time -- a real Lua-side stall, not a
-- crash). Root cause (not fully proven against engine source, but strongly
-- evidenced): `Card:open()` itself unconditionally calls
-- `G.E_MANAGER:add_event(...)` several times for its own delayed
-- explode/create-cards chain -- calling it again from WITHIN another event's
-- own still-executing callback means EventManager:update() is asked to touch
-- its own queue while mid-iteration over that same queue, which this version
-- of the engine evidently doesn't handle safely. Manually replicating the
-- exact same clone-creation + use_card + STATE_COMPLETE=false sequence via a
-- direct, top-level `eval` call (NOT nested inside ANY event callback) worked
-- correctly and stably every time. Fix: never call it from inside an Event
-- callback -- hook `Game:update` directly instead (the same real, precedented
-- pattern MultiplayerAPI's own focus.lua uses: wrap the function, call the
-- original first, then run our own check strictly AFTER that frame's real
-- update -- including its own E_MANAGER:update() pass -- has already fully
-- returned, so our own use_card call starts a clean top-level call stack
-- rather than nesting inside one already in progress).
--
-- BUG #5, FOUND AND FIXED live (this pass, flagged by the user watching this
-- exact test): the FIRST pack's own physical card object (the Joker-backed
-- "pack card" itself, not its contents) was left behind as a real, visible,
-- mid-dissolve leftover -- confirmed via a screenshot (a stray upside-down
-- Joker-backed card with its opening sparkle particles still floating,
-- visible behind the second pack's own choice screen) and via a G.MOVEABLES
-- scan (the card's `removed` field was still nil -- `:remove()` was never
-- actually called on it). Fix: force-remove the original pack card
-- explicitly and defensively once we're ready to open the second one,
-- regardless of whatever its own animation was doing.
--
-- BUG #6, FOUND, NOT YET FIXED (this pass, also flagged by the user watching
-- this exact test): with bugs #1-#5 all fixed, the two packs' contents ended
-- up MERGED into a single 6-card choice (3 real cards from each pack) instead
-- of two separate sequential 3-card choices -- confirmed by direct user
-- observation of the actual running instance during this same test. Root
-- cause (deduced from the evidence, not yet independently re-confirmed via
-- fresh instrumentation): the FIRST pack's own card-creation chain
-- (Card:open()'s delayed self:explode() -> ~1.7s-later SMODS.create_card
-- loop, scheduled back when pack 1 was first opened, entirely independent of
-- anything this file does) is never cancelled by bug #5's force-remove --
-- removing the CARD OBJECT doesn't cancel its own already-queued
-- G.E_MANAGER events. Those events reference `G.pack_cards` via the GLOBAL
-- at the time they actually FIRE, not a snapshot taken at schedule time -- so
-- if pack 1's own ~1.7s-delayed card-creation chain fires AFTER bug #3's fix
-- has already rebuilt `G.pack_cards` for pack 2 (a real, plausible timing
-- overlap depending on exactly when the player skips pack 1), pack 1's own 3
-- cards land into pack 2's fresh CardArea right alongside pack 2's own 3,
-- for 6 total, and pack 1's own now-confused closing logic likely explains
-- the G.STATE corruption (G.STATE reading nil) also observed in that same
-- test. NEXT STEP for whoever picks this back up: find a real way to either
-- (a) cancel pack 1's own pending G.E_MANAGER events outright when
-- force-removing its card (would need to identify exactly which queued
-- events belong to it -- not obviously exposed), or (b) delay opening the
-- second pack until comfortably PAST pack 1's own full open-to-populate
-- window (~0.4s + 1.3*sqrt(G.SETTINGS.GAMESPEED)s, i.e. don't just wait for
-- G.booster_pack to go nil -- also track real elapsed time since pack 1's
-- OWN open() call, not just since it visually closed, since a fast skip can
-- close the UI well before that chain has fired).
local function tft_check_pending_double_pack()
	local pending = TFT._pending_double_pack
	if not pending then return end
	if G.booster_pack ~= nil and (G.TIMERS.REAL - pending.started_at) < 30 then
		pending.closed_at = nil -- still open -- reset in case it was ever re-shown
		return -- still showing/being chosen from -- keep waiting, next frame
	end
	pending.closed_at = pending.closed_at or G.TIMERS.REAL
	if G.TIMERS.REAL - pending.closed_at < 0.6 then return end
	TFT._pending_double_pack = nil

	-- BUG #5's fix -- see the header comment above.
	if pending.original_card and not pending.original_card.removed then
		pcall(function() pending.original_card:remove() end)
	end

	local ok, err = pcall(function()
		local clone = SMODS.create_card({ key = pending.center_key })
		clone._tft_double_pack_clone = true
		clone.cost = 0
		G.FUNCS.use_card({ config = { ref_table = clone } })
		-- BUG #3's fix -- see the header comment above.
		G.STATE_COMPLETE = false
	end)
	if not ok then TFT.sendWarnMessage('double_pack: second pack failed to open: ' .. tostring(err)) end
end

if not TFT._double_pack_update_hooked then
	TFT._double_pack_update_hooked = true
	local _tft_orig_game_update_double_pack = Game.update
	function Game:update(dt)
		_tft_orig_game_update_double_pack(self, dt)
		pcall(tft_check_pending_double_pack)
	end
end

local _tft_orig_card_open_double_pack = Card.open
function Card:open(...)
	-- Disabled pending BUG #6 above -- `should_double` is permanently false
	-- until this returns true again once the real fix lands.
	local should_double = false and TFT.is_run_active() and TFT.has_augment('double_pack')
		and self.ability and self.ability.set == 'Booster' and not self._tft_double_pack_clone
	local center_key = should_double and self.config and self.config.center and self.config.center.key
	local ret = _tft_orig_card_open_double_pack(self, ...)
	if should_double and center_key then
		TFT._pending_double_pack = { center_key = center_key, started_at = G.TIMERS.REAL, original_card = self }
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
-- Extracted into its own function (rather than inline in the emplace hook
-- below) so it's directly callable in isolation for testing -- overriding
-- the global `pseudorandom` to force a pass/fail also contaminates vanilla's
-- OWN unrelated poll_edition roll if tested through a real create_card call,
-- since both draw from the same global RNG function; calling this function
-- directly on an already-existing card sidesteps that entirely.
function TFT.maybe_apply_cosmic_alignment(card, tier)
	if not (TFT.has_augment('cosmic_alignment') and tier >= TFT.PowerTier.RARE
		and card.config.center.key ~= 'j_tft_traits_engine'
		and not (card.edition and card.edition.negative)) then
		return
	end
	if pseudorandom(pseudoseed('tft_cosmic_alignment' .. G.GAME.round_resets.ante .. card.config.center.key)) > 1 - 0.006 then
		card:set_edition({ negative = true }, true)
	end
end

local _tft_orig_emplace_lucky_star = CardArea.emplace
function CardArea:emplace(card, location, stay_flipped)
	local ret = _tft_orig_emplace_lucky_star(self, card, location, stay_flipped)
	if self == G.jokers and TFT.is_run_active()
		and card and card.ability and card.ability.set == 'Joker' and card.config and card.config.center then
		local tier = TFT.get_power_tier(card.config.center.key, card.config.center.rarity)

		if TFT.has_augment('lucky_star') then
			local state = TFT.get_state()
			if state and not state.lucky_star_used then
				if tier >= TFT.PowerTier.RARE and card.config.center.key ~= 'j_tft_traits_engine'
					and #G.jokers.cards > 0 and G.jokers.cards[#G.jokers.cards] == card then
					state.lucky_star_used = true
					card:set_edition({ negative = true }, true)
				end
			end
		end

		-- Cosmic Alignment (Prismatic, Trait & Emblem): CLOSED, next-session-
		-- plan-2.md. poll_edition's own signature genuinely carries no rarity
		-- context (confirmed by reading it, functions/common_events.lua) --
		-- resolved by checking rarity HERE instead, post-creation, the same
		-- choke point Lucky Star's own edition-on-acquire effect (right above)
		-- already proves safe for exactly this kind of post-hoc edition
		-- check, rather than the originally-assumed "intercept poll_edition
		-- itself" approach. ASSUMPTION (flagged): rather than reverse-
		-- engineering an exact analytic tripling of poll_edition's internal
		-- formula, this adds an INDEPENDENT extra roll after the normal one
		-- already happened, sized so the combined probability approximates
		-- triple vanilla's real baseline. poll_edition's own negative branch
		-- (functions/common_events.lua) is `edition_poll > 1 - 0.003*_mod`,
		-- and create_card's real Joker call never passes a non-default _mod
		-- -- confirmed negative odds don't scale with G.GAME.edition_rate the
		-- way Foil/Holo/Polychrome do, only foil/holo/polychrome do -- so the
		-- real baseline here is a flat 0.3%. For tiny independent
		-- probabilities, P(A or B) = p1 + p2 - p1*p2 ~= p1 + p2, so a ~0.6%
		-- extra roll on top of that ~0.3% baseline lands close enough to the
		-- target 0.9% (3x) without needing to touch poll_edition's own call
		-- inside create_card (a much larger function to safely wrap around).
		TFT.maybe_apply_cosmic_alignment(card, tier)
	end
	return ret
end
