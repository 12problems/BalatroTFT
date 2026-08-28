-- Per-round-type timer budgets (technical.md's "Round/Stage State Machine"
-- section) -- CONFIRMED and implemented for real, 2026-08-28. Previously only
-- a cosmetic count-UP elapsed-time stopwatch existed (see hud.lua's own
-- long-standing ASSUMPTION note, now superseded) with no gameplay effect at
-- all; this is the real thing: a countdown that actually forces the
-- activity to end once time runs out, per round/activity type below.
--
-- SCOPE NOTE (read before assuming this matches technical.md word for word):
-- the design doc's own proposal was a HOST-BROADCAST shared `round_start`
-- timestamp with a secondary "hurry-up" window once >=75% of the alive lobby
-- has already finished a round -- a real, lobby-wide synchronized soft
-- barrier. That depends on a shared, host-authoritative notion of "which
-- round is everyone actually on right now," which this project's round-flow
-- architecture does NOT have: every client advances its own
-- `state.round_index` independently, the instant THEY personally clear their
-- own blind (see objects/round_flow/poll.lua's TFT.round_flow_advance) --
-- round_index itself was never lobby-synced to begin with, PvP pairing just
-- assumes players roughly keep pace. Building real host-authoritative
-- round-advance sync is a materially larger architectural change than "add a
-- timer" and wasn't attempted this pass. What IS implemented: each client
-- runs its OWN honest countdown against its OWN current round, using the
-- budgets below, and really enforces it (time runs out -> the round ends
-- for that player right now with whatever score they've already banked, per
-- the design doc's own "least punishing option" -- never auto-played or
-- zeroed). The secondary hurry-up window is NOT implemented for the same
-- reason (it needs to know how many of the alive lobby have already
-- finished THIS SAME round, and "this same round" isn't a shared concept
-- today).
TFT.PVE_PVP_TIMER_BY_STAGE = {
	[1] = 45,
	[2] = 65,
}
TFT.PVE_PVP_TIMER_DEFAULT = 90 -- stage 3 onward, per technical.md's table

TFT.SHOP_TIMER_SECONDS = 60
TFT.AUGMENT_PICK_TIMER_SECONDS = 30
-- Carousel's own real per-turn timer (host-authoritative, part of the
-- multiplayer draft itself -- objects/actions/carousel_draft.lua) already
-- predates this file and is materially different in shape (a shared draft
-- pool with turn order, not a per-player solo countdown), so it's not
-- reproduced here -- see TFT.CAROUSEL_PRE_TIMER_SECONDS/
-- CAROUSEL_TURN_TIMER_SECONDS in that file instead.

function TFT.hand_playing_timer_seconds(stage)
	return TFT.PVE_PVP_TIMER_BY_STAGE[stage] or TFT.PVE_PVP_TIMER_DEFAULT
end
