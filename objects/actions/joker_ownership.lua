-- Shared Joker Pool (docs/design/joker-ranking.md's "Shared Joker Pool"
-- section, next-session-plan.md priority #2). Broadcasts this player's
-- owned-Joker-key -> copy-count summary whenever it changes (a Joker lands
-- via CardArea:emplace, objects/jokers/ranking.lua, or is sold, this file's
-- Card:sell_card hook below) so every other client can compute "copies of
-- key X still available" at their own shop-open time -- the snapshot-refresh
-- model the design doc settled on (NOT a live-decrementing counter -- no
-- real-time locking, pool overrun on a rare simultaneous-buy collision is
-- explicitly accepted, per the doc's own "Confirmed: option 1").
--
-- Keyed by copy COUNT, not raw card list -- a Ranked Joker (multiple physical
-- copies merged into one visible card, objects/jokers/ranking.lua) must still
-- count for its full TFT.get_joker_copies() against the shared pool -- those
-- copies really did come out of the shared bag; merging them into one card
-- doesn't give them back to the pool.
TFT._lobby_joker_ownership = TFT._lobby_joker_ownership or {}

MPAPI.ActionType({
	key = 'tft_joker_ownership',
	on_receive = function(action_type, from_player_id, params)
		TFT._lobby_joker_ownership[from_player_id] = params.jokers or {}
	end,
})

-- This client's own current summary -- walks the real G.jokers.cards rather
-- than trusting any cached count, so it's always accurate at broadcast time.
function TFT.compute_own_joker_ownership()
	local summary = {}
	if G.jokers and G.jokers.cards then
		for _, card in ipairs(G.jokers.cards) do
			if card.ability and card.ability.set == 'Joker' and card.config and card.config.center
				and card.config.center.key ~= 'j_tft_traits_engine' then
				local key = card.config.center.key
				summary[key] = (summary[key] or 0) + TFT.get_joker_copies(card)
			end
		end
	end
	return summary
end

function TFT.broadcast_joker_ownership()
	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	if not lobby then return end
	local summary = TFT.compute_own_joker_ownership()
	TFT._lobby_joker_ownership[lobby.player_id] = summary
	lobby:action(MPAPI.ActionTypes['tft_joker_ownership']):broadcast({ jokers = summary })
end

-- Lobby-wide copies of `key` currently held, across every player whose
-- ownership summary we've received (or computed for ourselves) AND who isn't
-- known-eliminated (objects/round_flow/elimination.lua) -- an eliminated
-- player's held copies free back up for the rest of the lobby, matching the
-- design doc's own "across all ALIVE players" wording.
function TFT.copies_owned_lobby_wide(key)
	local total = 0
	for player_id, summary in pairs(TFT._lobby_joker_ownership) do
		if not TFT._eliminated_players[player_id] then
			total = total + (summary[key] or 0)
		end
	end
	return total
end

-- Real vanilla Card:sell_card (card.lua) -- the other place owned-Joker
-- copies change besides CardArea:emplace's merge-on-acquire (ranking.lua).
-- Captured/checked before the real sell so `self.ability` is still valid to
-- read (a sold card gets torn down inside the real call).
--
-- CAUGHT via live 2-instance testing: sell_card's own real removal isn't
-- synchronous -- it queues a dissolve animation (`self:start_dissolve(...)`,
-- card.lua) and the card is still sitting in G.jokers.cards for a beat
-- afterward. Broadcasting immediately (as this first did) captured the
-- PRE-sell count -- confirmed live: the other client still showed the sold
-- Joker as owned after a real sell.
--
-- BUG FOUND & FIXED TWICE (next-session-plan-3.md priority #2.2's own
-- verification debt turned up a real one, and the first fix attempt here was
-- itself wrong -- both corrections kept for the record):
--
-- 1st attempt: deferred via a fixed 0.6s G.E_MANAGER 'after' delay. A real
-- sell click's broadcast never reached the other client even many seconds
-- later. Wrongly diagnosed as an event-queue stall (a couple of persistent,
-- never-completing `immediate` events were sitting in the 'base' queue
-- ahead of ours, and Event defaults both `blocking`/`blockable` to true) --
-- that IS real behavior of engine/event.lua's EventManager:update, but those
-- particular persistent events turned out to be ordinary `no_delete`
-- long-lived vanilla events, not an actual stall (confirmed by clearing the
-- queue and reproducing the exact same failure anyway).
--
-- Real root cause, found by instrumenting the broadcast itself: the deferred
-- event WAS running and WAS succeeding (`pcall` returned true, no error) --
-- but TFT.compute_own_joker_ownership(), called from inside it, still saw
-- the sold card in G.jokers.cards at the 0.6s mark. Read card.lua's real
-- Card:start_dissolve: the actual `self:remove()` call (which detaches the
-- card from its area) is scheduled at `1.05 * dissolve_time`, and
-- `dissolve_time` defaults to `0.7 * dissolve_time_fac` -- i.e. ~0.735s
-- under ordinary conditions, already longer than our 0.6s guess, before
-- accounting for any destroy-context `dissolve_time_fac` scaling above 1x.
-- A fixed delay guessing at an animation's length is inherently fragile.
--
-- Fixed for real by not guessing at all: capture the card reference at sell
-- time and poll its own `removed` flag (set synchronously inside
-- Card:remove(), card.lua) once per tick via a self-rescheduling 'immediate'
-- event, broadcasting only once that flag is actually true (capped so a
-- pathological case can't poll forever). Re-verified live: a real sell
-- click's broadcast reached the other client's TFT.copies_owned_lobby_wide
-- correctly, confirmed against the card's own real removal instant rather
-- than a guessed delay.
local _tft_orig_sell_card = Card.sell_card
function Card:sell_card()
	local was_joker = TFT.is_run_active() and self.ability and self.ability.set == 'Joker'
	local card = self
	local ret = _tft_orig_sell_card(self)
	if was_joker then
		local started_at = G.TIMERS.REAL
		G.E_MANAGER:add_event(Event({
			trigger = 'immediate',
			blocking = false,
			blockable = false,
			func = function()
				if card.removed or (G.TIMERS.REAL - started_at) > 5 then
					pcall(TFT.broadcast_joker_ownership)
					return true
				end
				return false
			end,
		}))
	end
	return ret
end
