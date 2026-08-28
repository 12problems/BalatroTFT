-- Broadcast by the host (ui/lobby.lua's tft_start_game) once ready to begin.
-- MPAPI broadcasts loop back to the sender too (confirmed pattern from
-- BalatroMultiplayerSpeedrun), so every client -- host included -- starts the
-- real run from this same on_receive, all off the same shared seed. No ready-
-- check/countdown/ban-pick ceremony this session -- starts immediately.
--
-- EXPANDED (next-session-plan-4.md item 5): carries the host's configured
-- deck/stake/bonus-money/timer settings alongside the seed, applied
-- identically on every client. Deck: Game:start_run (game.lua) has no direct
-- deck-override argument -- confirmed via source read, its `selected_back`
-- derivation falls back through `self.GAME.viewed_back.name` /
-- `self.GAME.selected_back.name` -- so the real vanilla mechanism is setting
-- G.GAME.viewed_back BEFORE calling start_run, matching what the deck-select
-- screen itself does when a player picks a deck there. Stake: already a real
-- start_run arg, just no longer hardcoded to 1. Bonus money and the timer
-- toggle both need the run to actually exist first, so they're applied from
-- round_flow/poll.lua's one-time-per-run deferred-setup check (the same
-- pattern already used for the traits engine injection and the deck level
-- display -- applying either synchronously here, before start_run's own
-- queued G.E_MANAGER events finish, was the exact class of mistake that hung
-- the game once already this project per hooks.lua's own comment).
MPAPI.ActionType({
	key = 'tft_start_game',
	on_receive = function(action_type, from_player_id, params)
		if params.deck and G.P_CENTERS[params.deck] then
			G.GAME.viewed_back = G.P_CENTERS[params.deck]
		end
		TFT._pending_match_settings = {
			bonus_money = params.bonus_money or 0,
			timer_enabled = params.timer_enabled ~= false,
		}
		G.FUNCS.start_run(nil, { seed = params.seed, stake = params.stake or 1 })
	end,
})
