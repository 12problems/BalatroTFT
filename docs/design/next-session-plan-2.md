# Next Development Session — Plan #2

Written 2026-08-27, continuing from next-session-plan.md (that doc's priorities 1-3 are
now DONE, see below). Same standing operating instructions as that doc apply here
unchanged (assume-and-note, verify against `Mods/lovely/dump/` not a reference checkout,
test live not just "it compiled," prefer rigorous forced-input verification) — not
repeated in full here, read that doc's intro if this is a fresh context.

---

## What got done this cycle (all live-verified, 2-instance where the feature needs it)

1. **PvP life/elimination UI** (priority 1) — confirmed complete. Real 2-instance test:
   forced one player's life to 0, both clients correctly resolved elimination (placement
   #2), the survivor got a real "Victory! Last one standing" screen, both screens showed
   correct mirrored life totals. HUD relocation (stage roadmap in the Ante slot, timer in
   the Round slot) verified across a real stage boundary and a real Boss-blind clear —
   also caught and fixed a real crash bug in the process: vanilla's own `ease_ante`/
   `ease_round` read HUD elements this relocation deletes; both are now hooked to skip
   the dead UI work during a TFT run while keeping the real state mutation.

2. **Shared Joker Pool** (priority 2) — confirmed complete. `objects/actions/
   joker_ownership.lua` broadcasts each player's owned-Joker-copy summary on
   acquire/merge/sell; `objects/round_flow/shop_odds.lua`'s `TFT.filter_pool_by_shared_
   availability` excludes exhausted keys from real shop rolls. Verified: (a) an isolated
   pool-exhaustion A/B test (`get_current_pool` stops returning a key once its shared pool
   reads 0, resumes once cleared); (b) real cross-client broadcast (spawn on instance A,
   instance B's `TFT._lobby_joker_ownership` updates within a second); (c) the sell-path
   broadcast's underlying logic (once a card is actually removed from `G.jokers.cards`,
   the broadcast correctly reflects 0) — **NOT independently reproduced**: a raw
   eval-triggered `Card:sell_card()` call outside its real UI-click context never
   completed its dissolve animation in testing (the card stayed in `G.jokers.cards`
   indefinitely), so the exact deferred-broadcast timing (0.6s delay) under a REAL
   sell-button click was never actually exercised. Worth a spot-check via an actual UI
   click next time instances are up, though there's no specific reason to suspect it's
   broken — vanilla's own dissolve is core, extremely well-worn functionality.

3. **Flagged gaps** (priority 3) — confirmed complete except the two explicitly-skipped
   items:
   - Counterpunch, Iron Wall's outgoing half, High Roller's credit, Eye for an Eye's
     redirect: all wired via extending the existing `tft_round_result` broadcast payload
     (each player's own augment flags + dollar total, all knowable before the outcome is
     decided) rather than a new action — avoids a second broadcast round-trip. Rigorously
     verified via forced-input synthetic `on_receive` calls: Eye-for-an-Eye redirect + High
     Roller credit matched exactly (life -10, dollars +20 as predicted); Counterpunch +
     Iron Wall stacked matched exactly (life -14 as predicted). See `objects/actions/
     round_result.lua`'s header comment for the full design (a shared
     `TFT.apply_own_defensive_reductions`/`TFT.apply_life_loss` pair factors out the
     common damage-application logic both the normal loss path and the redirect path use).
   - Perfect Game's reward pool: designed (3 fixed permanent bonuses — +1 hand, +1
     discard, +$25 — an explicit, documented scope-down rather than a bespoke new
     mechanic) and wired in `objects/augments/perfect_game.lua`, triggered from
     `poll.lua`'s `TFT.round_flow_advance` at the exact "G.GAME.chips still holds the
     final score" moment. Verified live: forced an exact-chip-target win, the picker
     opened with all 3 options, picking one applied correctly ($25 credited).
   - Deck Surgeon / Seal Artisan: a real multi-select deck-browsing picker
     (`objects/augments/deck_picker.lua`). **Revised mid-cycle per explicit user
     feedback**: the first version was a compact rank/suit text-grid (small toggle
     buttons); the user asked for real card art instead ("players will want to see their
     enhancements and such while selecting"), so it was rebuilt on vanilla's own real
     deck-viewing machinery — one `CardArea` per suit populated with `copy_card()`
     copies (confirmed by reading it: copies real editions AND seals), using
     `type = 'joker'` instead of vanilla's own `view_deck`'s `type = 'title'` so the
     copies are natively clickable/highlightable (`CardArea:can_highlight` only allows
     hand/joker/consumeable/shop types — confirmed by reading it, not guessed) — real
     vanilla card-selection UX (the same "lifted" highlight look as selecting cards in
     hand), not custom buttons. A global `CardArea:add_to_highlighted` hook (gated to a
     complete no-op for every card area except this picker's own tagged ones) enforces
     one shared selection cap ACROSS all 4 suit areas together, since vanilla's own
     `highlight_limit` is per-CardArea and would otherwise allow 5 *per suit*. Verified
     live end-to-end: real enhancements/editions/seals visibly rendered during selection
     (screenshot: Polychrome shimmer, Gold seal stamp, Glass shine all visible
     simultaneously on different cards), clicking toggles the native highlight look,
     selecting a 6th card correctly evicts the globally-oldest selection instead of
     exceeding the cap, Confirm correctly maps the copies back to their real
     `G.playing_cards` originals (52→47 after Deck Surgeon's removal), and the screen
     returns to a fully clean state afterward (no leftover overlay/`G.VIEWING_DECK`
     artifacts). Traded away in the rebuild: the live "X/N selected" counter (it required
     rebuilding the whole overlay on every click in the old button-grid version; this
     version's selection state lives entirely in vanilla's own `CardArea.highlighted`
     lists with no render hook to piggyback a live count on — a stale count would be
     worse than none, so the subtitle is now static instructions instead).
     ASSUMPTION (flagged): Seal Artisan's
     seal TYPE is auto-rolled per card (Red/Blue/Gold/Purple), not a second per-card
     choice — the hard, novel UI problem (picking WHICH cards) is real; a second nested
     picker for seal colour was scoped out as disproportionate additional UI for a
     cosmetic-vs-mechanical choice among 4 well-understood effects.
   - **Cosmic Alignment — un-skipped and implemented this cycle.** The original blocker
     ("poll_edition carries no rarity context") turned out to be solvable by moving the
     check to a *different* choke point instead of chasing rarity into `poll_edition`
     itself: `objects/augments/shop_effects.lua`'s existing `CardArea:emplace` hook (the
     same one Lucky Star already uses for its own post-hoc edition change) knows the
     card's real rarity directly. Rather than reverse-engineering an exact analytic
     tripling of `poll_edition`'s internal formula, it adds one independent extra
     ~0.6% roll on top of the ~0.3% vanilla baseline (P(A or B) ≈ p1+p2 at this scale),
     landing close to the target 3x. Rigorously verified via a forced-`pseudorandom`
     test extracted into its own `TFT.maybe_apply_cosmic_alignment(card, tier)` function
     (kept separate from the emplace hook specifically so it's callable in isolation —
     overriding the global `pseudorandom` to force pass/fail, tested through a *real*
     `create_card` call, also contaminates vanilla's own unrelated edition roll, since
     both draw from the same RNG function; caught this by getting a wrong-looking first
     result before isolating the test correctly): forced-pass-with-augment → Negative;
     forced-fail-with-augment → unchanged; forced-pass-without-the-augment → correctly
     stays unchanged (proves the gate, not just the roll, works); forced-pass against the
     internal Traits Engine pseudo-joker → correctly excluded. Re-verified Lucky Star
     (whose emplace hook this shares) still works unchanged after the refactor.
   - **Momentum Keeper — still explicitly skipped**, re-confirmed this cycle rather than
     just carried over: "scaling Jokers never lose their bonus, even from effects that
     would normally reset them" needs intercepting *each specific vanilla Joker's own*
     reset logic (Obelisk, Constellation, Castle, etc. each reset their own
     `self.ability` fields inside their own distinct `card.lua` branches) — there is no
     single generic choke point the way `Card:calculate_joker`'s return value is one for
     scoring output. This is the literal "~150 bespoke upgrades" problem
     `joker-ranking.md`'s whole design exists to avoid, and unlike Cosmic Alignment there
     was no alternate single hook point found to sidestep it with.

## What was investigated and deliberately NOT done

**Priority 4, Ranked Joker visual treatment (border/glow per rank) — skipped after real
investigation, not silently dropped.** Checked three approaches:
- Raw `love.graphics` primitives for a border: **no precedent anywhere in `card.lua`** —
  every visual effect goes through the Sprite/shader abstraction layer, confirmed by
  grepping the whole file for `love.graphics.*` (zero hits). Attempting this cold, without
  understanding the coordinate/transform system those abstractions hide, was judged too
  likely to produce something subtly broken (wrong position/scale/rotation under tilt,
  drag, or camera state) for a cosmetic feature that isn't a stated priority.
- Layering an extra shader pass (`Sprite:draw_shader('holo', ...)` or similar) with a
  custom rank colour: the actual `.fs` shader source isn't available to inspect (compiled
  resources, not in the Lua dump), so there's no way to confirm a custom colour parameter
  would even be honored by `holo`'s real shader code without live-experimenting blind on a
  real rendering path — same risk profile as the above.
- **A real, concrete finding worth remembering**: `Card:set_seal(seal_key)` visually
  renders a small colored corner stamp on a JOKER card too (not just playing cards,
  confirmed live via screenshot — this looked like exactly the "low-risk corner badge"
  this session wanted). **Rejected after reading card.lua further**: `Card:get_p_dollars`
  and `Card:get_end_of_round_effect` both check `self.seal` unconditionally (Gold seal
  +$3, Blue seal spawns a Planet card) with no visible playing-card-only gate at the
  METHOD level — meaning if any code path ever calls either method on a Joker (not
  confirmed impossible in the time available), a "cosmetic" rank stamp could silently
  hand out real money or consumables. Not worth shipping without fully tracing every
  caller of both methods first, which is a same size verification.
- **Net result**: the existing color-coded rank text (white/blue/gold via `RANK_COLOUR`
  in `objects/jokers/rank_display.lua`, live-verified in a prior session) stands as this
  pass's visual treatment. A real border/glow is a good candidate for a session with
  budget to actually read/decompile the relevant `.fs` shader files first, rather than
  guessing at their uniform interface live.

**Priority 5, per-augment testing sweep — partially done, not exhaustive.** Rigorously
verified (forced inputs, exact expected-vs-actual match) the 5 augments flagged as
highest-risk (anything touching `Card:calculate_joker`'s return table): Glass Cannon (x2),
Boom or Bust (x3 first hand / x0.75 after), All or Nothing (x10), their stacking (x20,
correctly multiplicative), Fundamentals (per-card escalation 1→2→3 across repeated
scorings of the same physical card), and Adrenaline (correctly gated on
`hands_left==0 and chips<blind.chips`, 0 vs 1 extra repetition). Also re-ran the
all-73-simultaneous stress test (joker_main/individual/repetition contexts, shop pool
filtering, HUD text updates) after all of this cycle's changes — still clean, no crash.

**Second pass, same cycle — a further batch individually verified**, all exact
expected-vs-actual matches: Lucky Star (guaranteed Negative on next Rare+, one-time —
confirmed unaffected by the Cosmic Alignment refactor sharing its hook), King's Court
(52/52 cards became King of Hearts), Alchemist's Dream (52/52 un-enhanced cards got a
real enhancement), Gilded Deck (52/52 cards got a real edition), Card Shark (correctly
capped at the real consumable-slot limit rather than overflowing past it, both granted
copies confirmed as Negative Aura), Print Money (money halved correctly, floor-of-half
removed leaving the ceiling half — e.g. 40→20, 21→11), Double or Nothing (both branches
via a forced-`pseudorandom` win/lose roll — wager doubled to net +wager on a win, lost
outright on a loss), Monopoly (tier roll formula `floor(roll*5)+1` verified across all 5
tier boundaries). **A useful methodology note for whoever continues this**: `ease_dollars`
defers its actual mutation through `G.E_MANAGER` (an 'immediate'-trigger queued event, not
a synchronous write) — checking `G.GAME.dollars` in the SAME `cctl eval`/script call that
triggered it reads the STALE pre-mutation value; always check in a separate call after a
short real-time gap (a plain `sleep 1` between two `cctl eval` calls is enough). This is
not a bug in the mod, it's how vanilla's own dollar-mutation functions all work — but it
produced two false "looks broken" results in this cycle's own testing before being
accounted for (caught immediately, not shipped as a false bug report).

**Still not individually re-verified this cycle** (~55 more): most were spot-checked in
an earlier session either individually or via the group stress test, or are simple flat
modifiers (a single `+N` to some field) judged low-risk by inspection. Real standing debt
if a subtle bug is hiding in one of them, but diminishing returns per augment at this
point relative to the flagged-highest-risk and now-second-batch coverage above. Worth
noting one REAL gap surfaced while reading through the roster for this pass, not
previously flagged: **Double Pack** (`double_pack` augment, "buying a booster pack opens
2 packs of that type instead of 1") is explicitly commented `NOT WIRED` in
`objects/augments/definitions.lua` — needs a hook into `Card:open`'s real pack-opening
flow (`functions/common_events.lua`) to run its contents-grant twice, distinct from Pack
Rat's already-wired "extra choice within one pack" effect. Not attempted this cycle;
flagged for the next one.

## Testing sweep, completed — full 73-augment pass, issues found (NOT fixed yet, per
## explicit user instruction: "note things that need fixing... then we will do a fixing
## pass after the rest are tested")

Went through every remaining augment not covered by the earlier two batches. Methodology
note that bit twice more this pass (same class as the `ease_dollars` lesson already
recorded): several apply()-driven field mutations (`G.hand.config.card_limit`,
`G.jokers.config.card_limit`, `G.consumeables.config.card_limit`) don't read back correctly
in the SAME `cctl eval`/script call that set them — a real ~1-frame settle delay, not a
bug — always re-check in a separate call after a short sleep. A batch test that checked
several augments back-to-back in one script also produced a false "no change" for
`extra_pocket`/`portfolio_diversification` for an unrelated reason: two tests in the same
run both touched `consumable_limit` in opposite directions, netting to the same displayed
number — checked each in true isolation afterward and both are correct.

**Real bugs found, confirmed live, not yet fixed:**

1. **Odd Couple produces the wrong card.** `objects/augments/deck_effects.lua`'s
   `TFT.odd_couple_deck()` (line ~156) calls `p_card('Hearts', 'K')` — **King** of Hearts —
   but the augment's own name/description is "2 of Clubs or **Queen** of Hearts." Confirmed
   live: after applying, 23 cards were King of Hearts and 0 were Queen of Hearts. One-line
   fix (`'K'` → `'Q'`), not attempted this pass per the user's instruction to note-not-fix.
2. **Early Warning is a complete no-op.** Its own comment in `definitions.lua` claims
   "data-available-on-request (`TFT.upcoming_pvp_opponents`)" — that function **does not
   exist anywhere in the codebase**, confirmed by grepping the whole project (only the one
   comment mentions it). `TFT.has_augment('early_warning')` is also never called anywhere.
   Picking this augment currently does literally nothing — worse than the comment implies
   (it claims partial functionality that doesn't actually exist). Needs either a real
   implementation of the lookahead function + a way to surface it, or at minimum an honest
   comment update if it's staying unimplemented for now.
3. **Four stale "NOT WIRED" comments in `definitions.lua`** left over from before this
   session's cross-client PvP effects work (`objects/actions/round_result.lua`) actually
   closed these gaps — the CODE is correct and was rigorously verified earlier this same
   cycle (exact forced-input matches), only the augment-roster comments next to `iron_wall`,
   `counterpunch`, `high_roller`, and `eye_for_an_eye` still say things like "the outgoing
   -10% half isn't applied" / "NOT WIRED" / "only the loser's half-money-loss is wired" /
   "the redirect-TO-your-opponent half isn't wired". Purely a documentation staleness issue
   (misleading to a future reader, not a functional bug) — worth cleaning up in the same
   pass since it's trivial once found.

**Everything else in this pass verified correct** (forced-input or direct-application
checks, exact expected-vs-actual matches unless noted): Warm Up, Steady Hands, Growth
Spurt, Iron Will, Portfolio Diversification, Second Look, Extra Pocket, Bargain Bin,
Compound Interest, Everything's For Sale, Fire Sale, Unstoppable, The Whole Store, Speed
Round, Nest Egg, All In, Overdraft, Omen Globe (grants the voucher, confirmed no
unwanted cost deduction), Grand Astronomer (all 12 hand types incl. secret ones →
level 11, all made visible), Point of No Return (the wired +20-levels half only, per its
own already-documented scope), Thin the Herd, Lucky Break, Fresh Coat, Seal the Deal
(exactly 4 distinct real seal types), Reshuffle, Suit Yourself, Tip Jar, Rainy Day Fund
(incl. the once-per-stage gate holding on a second trigger attempt), Level Up (incl. the
first-hand-type-only gate), Encore Performance (incl. the once-per-hand-type-per-round
gate), Apprentice's Charm, Trait Heart (+2 exactly), Grand Emblem (applies to existing AND
freshly-acquired Jokers), Everything's Wild (correctly gated on/off), Clearance Rack
(after catching my own test contamination from a leftover `discount_percent` — see
methodology note above), Reroll Refund (exact 25% payout across a real stage boundary,
correctly zeroes the tracker after), The Big Score (forces an all-Legendary pool, correctly
one-time), Vintage Collection (once-per-visit gate holds), The House Always Wins (exact
$1-per-5%-margin math, and the $50 cap), Vampiric (exact 50%-of-damage-dealt heal),
Padded Walls (first-hit-halved, second-hit-full, confirmed as an exact 2:1 ratio), Second
Wind (saves exactly once, second fatal hit goes through), Pack Rat (confirmed via a real
booster pack open, `pack_choices` 1→2), Card Shark, King's Court, Alchemist's Dream,
Gilded Deck (all re-confirmed from the prior batch).

**Not independently live-fired this pass** (both use the identical modulo-counter pattern
already proven correct elsewhere — Frequent Buyer's own counter was live-verified in an
earlier batch — deferred rather than risking a real shop-reroll/purchase side effect in an
already-running test instance): Golden Touch ("every 3rd reroll free"), Frequent Buyer
("every 5th purchase 50% off" — the counter logic is identical in shape to what was
already verified; only the live click-through wasn't independently re-fired this pass).

**Still-known, unchanged gaps** (not new findings, already documented): Double Pack
(genuinely `NOT WIRED`), Momentum Keeper (genuinely intractable per its own note),
Cosmic Alignment (already closed earlier this cycle), Critical Mass (simple boolean gate,
verified by inspection only, not a dedicated live test — low complexity/risk).

## Known bugs (for a future bug-pass session, not blocking otherwise)

1. **Deck Surgeon/Seal Artisan's card picker doesn't work on a controller.**
   `objects/augments/deck_picker.lua` reuses vanilla's real card-highlight system by
   building its own `CardArea`s with `type = 'joker'` (to get native click-to-select for
   free — see that file's header comment). Confirmed by reading `cardarea.lua`'s
   `CardArea:can_highlight`: under gamepad/controller input (`G.CONTROLLER.HID.
   controller`), highlighting is only permitted when `self.config.type == 'hand'` — every
   other type, including `'joker'`, returns false. **Effect: on a controller, the cards in
   this picker cannot be selected at all** (Card:click() no-ops silently — this fails
   safe, not silently-wrong, but the picker is simply unusable without a mouse/keyboard).
   Not investigated further this cycle per explicit user instruction ("note it for later,
   continue on other implementations"). A fix would need either its own controller-input
   handling bolted on, or finding whatever real mechanism vanilla's own `type='hand'`
   areas use for controller card-selection and adapting it here.

## Open items carried forward

1. Live-verify the Shared Joker Pool sell-broadcast under a REAL UI-driven sell click
   (not raw eval) — see priority 2's note above.
2. A full per-augment individual sweep (not just the 5 highest-risk ones) is still real
   debt, lower priority than shipping features per this project's own established
   ordering.
3. Cosmic Alignment, Momentum Keeper: still unimplemented, still judged not worth the
   disproportionate infra per the original plan's own reasoning — revisit only if there's
   a session with nothing higher-value to do.
4. Rank visual treatment: revisit only with real time budgeted to read the compiled
   shader files first (find them under the game's install directory, not the Lua dump).
