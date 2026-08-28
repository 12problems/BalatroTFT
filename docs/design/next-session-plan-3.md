# Next Development Session — Plan #3 (consolidated)

Written 2026-08-27, superseding next-session-plan.md and next-session-plan-2.md as the
single place to start from — those two are still valid history/reasoning records (don't
delete them), but everything actionable from them is summarized here. Same standing
operating instructions apply across all three docs: assume-and-note on open design
questions, verify against the actual installed `Mods/lovely/dump/` source (not a reference
checkout) when a hook doesn't fire as expected, test live not just "it compiled," and
prefer rigorous forced-input verification (exact expected-vs-actual, not "looks right").

## Repo status — read this first

**All of the work described below as "done" is UNCOMMITTED on the `main` branch.**
`git status` (current as of the fixing-pass + verification-debt pass that closed
Priorities 1 and 2 and attempted Priority 3.1) shows real, substantial changes not yet
committed:
```
 M docs/design/next-session-plan.md
 M objects/actions/round_result.lua
 M objects/augments/deck_effects.lua
 M objects/augments/definitions.lua
 M objects/augments/shop_effects.lua
 M objects/jokers/ranking.lua
 M objects/round_flow/hooks.lua
 M objects/round_flow/hud.lua
 M objects/round_flow/poll.lua
 M objects/round_flow/pvp.lua
 M objects/round_flow/shop_odds.lua
?? docs/design/next-session-plan-2.md
?? docs/design/next-session-plan-3.md
?? objects/actions/joker_ownership.lua
?? objects/augments/deck_picker.lua
?? objects/augments/perfect_game.lua
```
The user has not asked for a commit this cycle — don't commit/push without being asked,
but don't lose track of this either: if a fresh session starts from a clean checkout of
`main` on GitHub, it will NOT see any of this work (elimination/victory UI, Shared Joker
Pool, cross-client PvP effects, Perfect Game, the real-card-art deck picker, Cosmic
Alignment) — only what was already merged in commit `b6738f7`. Check `git status` before
assuming a fresh session's starting point matches what's described here.

## What's DONE this development arc (live-verified, mostly with exact forced-input matches)

1. **PvP life/elimination UI** — HUD relocation (stage roadmap in the Ante slot, a real
   round timer in the Round slot, a Life/Opp life row), elimination detection with correct
   TFT-style placement numbers, cross-client victory detection, both end screens. Verified
   with a real 2-instance match (forced elimination → correct placement, survivor got a
   real victory screen, life totals mirrored correctly on both clients).
2. **Shared Joker Pool** — lobby-wide scarcity, `objects/actions/joker_ownership.lua`
   broadcasts owned-copy summaries, `objects/round_flow/shop_odds.lua` filters exhausted
   keys out of real shop rolls. Verified: pool-exhaustion A/B test, real cross-client
   ownership broadcast. **Not independently reproduced**: the sell-path broadcast's exact
   timing under a REAL UI-driven sell click (only verified in isolation — see Open Items).
3. **Cross-client PvP effects** — Counterpunch, Iron Wall's outgoing half, High Roller's
   credit, Eye for an Eye's redirect. All ride the existing `tft_round_result` broadcast
   (no new network action needed). Verified via forced-`pseudorandom`/forced-score synthetic
   `on_receive` calls, exact matches (e.g. redirect+credit: life −10, dollars +20 exactly;
   Counterpunch+Iron Wall stacked: life −14 exactly).
4. **Perfect Game** — designed a 3-option permanent-bonus reward pool (was previously
   totally undesigned), wired to trigger on an exact-chip-target win. Verified live.
5. **Deck Surgeon / Seal Artisan** — a real multi-select picker using vanilla's own card
   rendering (`copy_card`, confirmed to preserve editions/seals/enhancements) in real
   per-suit `CardArea`s with native click-to-highlight, **not** a text/button grid (that
   was the first draft; rebuilt per explicit user feedback: "players will want to see
   their enhancements and such while selecting"). A global `CardArea:add_to_highlighted`
   hook (gated to a no-op for every other card area in the game) enforces one shared
   selection cap across all 4 suit areas. Verified live: real enhancements visibly
   rendered during selection, exact-count enforcement provably can't be bypassed in either
   direction (tested selecting too few AND confirmed the eviction cap prevents too many),
   real card removal/seal-application confirmed.
6. **Cosmic Alignment** — previously skipped as blocked ("`poll_edition` has no rarity
   context"); un-blocked by moving the check to the `CardArea:emplace` hook Lucky Star
   already uses (which DOES know rarity, post-creation) instead of intercepting
   `poll_edition` itself. Adds one independent ~0.6% roll on top of vanilla's ~0.3%
   baseline to approximate a 3x total. Verified via forced-`pseudorandom` tests extracted
   into a standalone `TFT.maybe_apply_cosmic_alignment(card, tier)` function (kept separate
   specifically so it's testable without contaminating `create_card`'s own unrelated
   edition roll — that contamination produced a wrong-looking first result before the test
   was corrected).
7. **Full augment testing sweep** — all 73 augments now individually reasoned about or
   live-verified (a handful deferred for side-effect-risk reasons, see below). Full
   per-augment results are in next-session-plan-2.md; the actionable output is the bug list
   in the next section.

## Priority 1 — Fixing pass — CLOSED, all 3 items live-verified

1. **Odd Couple's King/Queen bug — FIXED.** `objects/augments/deck_effects.lua`'s
   `TFT.odd_couple_deck()` now calls `p_card('Hearts', 'Q')`. Re-verified live in a real
   run's own deck: 24 became 2 of Clubs, 28 became Queen of Hearts, 0 King of Hearts, 0
   other.
2. **Early Warning — implemented for real, not just commented.** Added
   `TFT.upcoming_pvp_opponents(count)` (`objects/round_flow/pvp.lua`), which runs
   `domain/pvp_pairing.lua`'s existing pure pairing function forward against today's
   alive-player set for the next N PvP rounds. Surfaced as a new always-present (usually
   empty) "Next: ..." HUD row (`objects/round_flow/hud.lua`'s
   `TFT.build_hud_early_warning_row`/`update_hud_display_texts`), gated on
   `TFT.has_augment('early_warning')`, resolving opponent ids to `lobby._players[id]
   .displayName`. Verified live in a real 2-player lobby: real pairing computed correctly,
   HUD text read exactly `"Next: Player002, Player002"` with the augment on and `""` with
   it off. Also verified the underlying multi-round lookahead genuinely varies (not just a
   2-player degenerate case) via a synthetic 4-player `TFT.compute_pvp_pairing` call: 3
   different opponents across 3 rounds, correct round-robin order.
3. **Stale "NOT WIRED" comments — corrected.** All 4 (`iron_wall`, `counterpunch`,
   `high_roller`, `eye_for_an_eye`) now describe the real, already-verified cross-client
   mechanism (rides the existing `tft_round_result` broadcast) instead of claiming gaps
   that were closed earlier in this arc.

## Priority 2 — Verification debt — CLOSED, and it did its job: found 4 more real bugs

Sent 2 real instances through an actual lobby → run → shop, driving every action via real
UI clicks (not raw `eval`), per the standing "verify against real behavior, not just
plausible code" rule. This is exactly what the debt was for — it wasn't clean:

1. **Golden Touch was a complete no-op — FOUND & FIXED.** `objects/augments/shop_effects.lua`'s
   `G.FUNCS.reroll_shop` hook set `G.GAME.current_round.free_rerolls += 1` on every 3rd
   reroll, but read of the real installed `functions/button_callbacks.lua` shows vanilla's
   `reroll_shop` deducts `ease_dollars(-reroll_cost)` using whatever cost was already
   calculated from the *previous* click, before it ever looks at `free_rerolls` — that flag
   only affects the cost of the *next* reroll via `calculate_reroll_cost`, and gets
   decremented back to 0 in the same click's own event, so it never actually zeroed
   anything. Confirmed live: 3 real reroll clicks through the actual shop UI all charged
   full price. Fixed by directly zeroing `G.GAME.current_round.reroll_cost` on the
   triggering click (so vanilla's own `if cost > 0` guard skips the charge). Re-verified:
   with cost forced to 0 immediately before a real click, dollars were unchanged.
2. **Frequent Buyer only ever counted Joker purchases — FOUND & FIXED.** Its own comment
   said "any item type," but `G.FUNCS.buy_from_shop` (the only thing the augment hooked) is
   never used for Vouchers or Booster packs — confirmed live (a real $10 voucher purchase
   didn't move the counter) and via source read of `card.lua`: Vouchers/Boosters dispatch
   through `G.FUNCS.use_card` into `Card:redeem()`/`Card:open()`, which each do their own
   independent `ease_dollars(-self.cost)`, entirely bypassing `buy_from_shop`. Fixed by also
   hooking `Card.open`/`Card.redeem` (gated on `self.cost > 0` so pack-drawn/tag-granted
   items, which carry cost 0, can't accidentally consume a count) with the same
   mutate-cost-before-the-real-charge pattern. Re-verified live: the 5th real purchase (a
   Buffoon Pack) charged exactly half its listed price ($3 → $1, `floor(3*0.5)`), and the
   counter advanced correctly.
3. **Shared Joker Pool's sell-broadcast was silently late/lost — FOUND & FIXED (twice; see
   the code comment for why the first fix attempt was itself wrong).** A real sell-button
   click's ownership update never reached the other client, even several seconds later.
   Root cause, found by instrumenting the broadcast itself rather than guessing: the
   existing fixed 0.6s deferral (`objects/actions/joker_ownership.lua`'s `Card:sell_card`
   hook) is shorter than vanilla's own real dissolve-then-remove animation — reading
   `card.lua`'s `Card:start_dissolve`, the actual `self:remove()` call is scheduled at
   `1.05 * 0.7 * dissolve_time_fac` (~0.735s under default conditions), already longer than
   the 0.6s guess, before any destroy-context scaling above 1x. Fixed by not guessing a
   delay at all: poll the sold card's own `removed` flag (set synchronously inside
   `Card:remove()`) once per tick via a self-rescheduling event, broadcasting only once it's
   actually true (capped at 5s so a pathological case can't poll forever). Re-verified live,
   twice, with different jokers: the other client's `TFT.copies_owned_lobby_wide` read the
   correct post-sale count within roughly a second of a real sell click.
4. **Deck picker doesn't work on a controller** — unchanged from before, still noted-only.
   `objects/augments/deck_picker.lua` reuses vanilla's real card-highlight system with
   `type = 'joker'` CardAreas; confirmed by reading `cardarea.lua`'s
   `CardArea:can_highlight` that gamepad/controller input only permits highlighting when
   `type == 'hand'`. Fails safe (nothing happens, not a wrong selection) but the picker is
   simply unusable without a mouse/keyboard. Not investigated further per explicit user
   instruction to leave this for a future bug pass.

All 6 code changes above (odd_couple, early_warning + HUD row, the 4 definitions.lua
comments, golden_touch, frequent_buyer, joker_ownership's sell hook) are live in the repo
files but — same standing caveat as everything else in this doc — **uncommitted**. Both
Balatro test instances used for this pass were stopped cleanly at the end of it (no
leftover processes), but a fresh session should still check `Get-Process Balatro` before
assuming a clean slate, per this doc's own standing recipe.

## Priority 3 — Still genuinely unimplemented (real gaps, not bugs)

1. **Double Pack** (`double_pack` augment) — attempted this pass, deliberately left
   disabled (`should_double` hardcoded `false` in `objects/augments/shop_effects.lua`'s
   `Card:open` hook) after finding a 3rd real bug that would make it worse than doing
   nothing if shipped. Full blow-by-blow is in that file's own comment above the hook, kept
   in detail since 2 of the 3 bugs found along the way WERE fixed live and the fix is
   sitting right there ready to re-enable once bug #3 is solved:
   - **Bug #1 (fixed):** calling a cloned pack card's `:open()` directly (bypassing
     `G.FUNCS.use_card`) skipped `G.GAME.PACK_INTERRUPT` bookkeeping that
     `end_consumeable` needs to restore `G.STATE` correctly on close — left the game
     genuinely stuck (`G.STATE` went `nil`, pack-choice panel frozen) after skipping the
     second pack. Confirmed via a real UI-driven repro, twice.
   - **Bug #2 (fixed):** routing the correction through `G.FUNCS.use_card` (a synthetic
     `{config={ref_table=clone}}`, exactly the shape a real click passes) fixed the freeze
     and also turned out to fix a second issue — `G.pack_cards.VT.y` staying above
     `G.ROOM.T.h` (vanilla's own gate on whether newly-created pack contents actually get
     emplaced anywhere visible) because `use_card` does its own shop/booster-pack
     repositioning that raw `:open()` skips entirely.
   - **Bug #3 (NOT fixed, why this is disabled):** even with #1 and #2 fixed,
     `G.pack_cards.cards` stayed `nil` for the second pack — real `CardArea` (confirmed
     `:is(CardArea)` true), positioning correct, just never populated. Circumstantial
     evidence points at `functions/UI_definitions.lua`'s `create_UIBox_*_pack()` builders
     (each constructs a fresh `G.pack_cards`) only running on a genuine `G.STATE`
     transition EDGE, which the second pack's own `Card:open()` (re-setting `G.STATE` to a
     value it may already be sitting at) might not trigger — not confirmed against the
     actual dispatch code, which wasn't located before time ran out. **Next step for
     whoever picks this up:** find where `create_UIBox_*_pack()` is actually called from
     (grep `functions/state_events.lua` and the engine files for a `G.STATE`-keyed
     UI-build dispatch) and confirm/fix the edge-detection theory. Once fixed, re-enabling
     is a one-line change (drop the `false and` in the hook).
2. **Momentum Keeper** — confirmed (re-confirmed this cycle, not just carried over)
   genuinely intractable without per-Joker special-casing: vanilla's scaling Jokers
   (Obelisk, Constellation, Castle, etc.) each reset their own `self.ability` fields inside
   their own distinct `card.lua` branches, with no single generic choke point the way
   `Card:calculate_joker`'s return value is one for scoring output. This is the literal
   "~150 bespoke upgrades" problem `joker-ranking.md`'s whole design exists to avoid.
   Skip unless a future session specifically wants to take that on.
3. **Ranked Joker visual treatment** (border/glow per rank) — investigated and explicitly
   NOT attempted: no raw `love.graphics` precedent anywhere in `card.lua` (every visual
   effect goes through a Sprite/shader abstraction whose actual `.fs` shader source isn't
   available to inspect, just compiled). One promising lead (Joker-card seal stamps,
   confirmed to render) was rejected after finding `Card:get_p_dollars`/
   `Card:get_end_of_round_effect` both check `self.seal` unconditionally with no visible
   playing-card-only gate — a real, unverified risk of a "cosmetic" stamp silently handing
   out money/items. The existing colour-coded rank text (white/blue/gold,
   `objects/jokers/rank_display.lua`) stands as the treatment for now. Revisit only with
   real budget to find/read the actual compiled shader files first.

## Open design question still on the table (unchanged from next-session-plan.md)

Round timer scope, eliminated-player UX, and match-end condition were all resolved with
defensible defaults already (visual-only stopwatch; a placement screen with a menu button;
last-player-standing) and are working as built — no longer open, listed here only so a
fresh session doesn't re-litigate them without reason.

## Suggested order for the next session

1. ~~Priority 1's fixing pass~~ — CLOSED, all 3 items live-verified.
2. ~~Priority 2's verification debt~~ — CLOSED, and found 4 more real bugs (Golden Touch,
   Frequent Buyer x2, Shared Joker Pool's sell broadcast), all fixed and live-verified. Only
   the controller-input note carries forward, unchanged, for a future bug pass.
3. ~~Double Pack~~ — ATTEMPTED, disabled pending bug #3 (see Priority 3.1 above for the
   full account and the concrete next step). **Start here** if picking this back up: the
   fix for bug #3 is narrowly scoped (find the real `G.STATE`-keyed UI-build dispatch for
   `create_UIBox_*_pack()`), and 2 of 3 bugs are already fixed and waiting.
4. Momentum Keeper and the rank visual treatment stay explicitly deprioritized — only pick
   either up if asked for by name, given the real infra cost each carries.
5. Consider committing this arc's work to git — nothing has been committed yet (see "Repo
   status" above) and the diff is now substantial across many files.
