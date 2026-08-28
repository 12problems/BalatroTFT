# Next Development Session — Plan #4 (Level rewards, real Carousel draft, lobby/HUD work)

Written 2026-08-27, scoped entirely to 5 items the user picked from next-session-plan-3.md's
"what's not yet completed" review, with the user's own detailed answers to every
clarifying question folded in as locked decisions below. Doesn't touch anything from
plan-3 (Double Pack bug #3, Momentum Keeper, rank visuals, controller support) — those
stay exactly as documented there.

## STATUS: all 5 items implemented and live-verified (2026-08-27)

Items 6, 1, 4, 5, and 2 are all done, in that order, each verified live against real
2-instance multiplayer (not just "compiled/didn't crash"). Per-item verification notes are
inline below each section. The one deviation from the original sequencing plan: the
4-instance/8-instance load test was NOT run this pass (see "What's left" at the bottom) —
everything else, including the full real-networking Carousel draft, was verified with the
standard 2-instance rig.

**Real bug found and fixed along the way, worth flagging prominently:** the Run Info
"Standings" tab (item 4) initially failed to render AT ALL on a real stake-1 lobby — a
classic Lua gotcha, not a logic error. The tabs array had `G.GAME.stake > 1 and {...} or
nil` (vanilla's own pre-existing conditional Stake tab) sitting BEFORE the new Standings
entry; when stake is 1 that slot evaluates to a literal `nil`, and `ipairs` (which
`create_tabs` uses to walk the array) stops dead at the first nil hole, silently dropping
every tab after it. Fixed by moving the conditional tab to the end of the array. Confirmed
live before the fix (tab genuinely missing from a real Run Info screen) and after
(Standings tab renders and both players' real data show correctly, sorted by life).

## Sequencing

Per the user's own instruction: build everything, but **save the 4-client and 8-client
live Carousel draft test for the very end**, batched with whatever else needs >2 real
instances (the Item 5 8-player lobby screenshot). Implementation order:

1. Item 6 — consumable-odds wiring (smallest, self-contained, no new UI)
2. Item 1 — level-up rewards (Voucher Choice, Deck Refinement) + HUD level/XP display
3. Item 4 — Run Info "Standings" tab
4. Item 5 — lobby settings (deck/stake/bonus money/timer toggle) + typed join field
5. Item 2 — real multiplayer Carousel draft (biggest, most novel networking code)
6. **Final verification pass**: 4-instance test, then 8-instance test (Carousel draft +
   8-player lobby screenshot for Item 5), done together since both need a big lobby.
   **NOT done this pass** — see "What's left" at the bottom of this doc.

## Item 6 — Wire consumable-odds weighting — DONE, verified live

Implemented via a repeated-slot-array technique (each key gets `round(weight * 10)` copies
in the pool array instead of 1, so a plain uniform pick reproduces the intended
proportions) applied to both `get_current_pool('Tarot'/'Spectral', ...)` (the real shop)
and Carousel's own consumable pick. Verified live against a running instance at levels 1,
8, and 10: Justice fully absent at level 1 (weight 0.0) and present at the expected ~0.66
weight at level 8; the Tarot phase-out group (Empress etc.) fully absent at level 8 (weight
0.0, confirmed correct even though it's present at level 1); the Spectral boost group
correctly boosted at level 10. Also confirmed the weighting reaches the REAL pick, not just
the array shape (200 sampled picks from a level-8 weighted pool never once landed on the
zero-weight Empress).

**Locked:** applies to both regular shop generation AND Carousel's consumable pick.

- Hook the same choke point `shop_odds.lua` already uses for Joker rarity, but for
  Tarot/Spectral selection — likely needs a `create_card`/`get_current_pool` weighted-pick
  wrap, or a `pseudorandom_element`-with-weights helper if vanilla's own consumable
  generation doesn't already route through `get_current_pool` the way Jokers do (needs
  checking against the real installed source — Jokers and Consumables may use different
  vanilla generation paths).
- `carousel.lua`'s consumable pick (currently a flat `pseudorandom_element` over
  `TFT.CarouselConsumablePool`) gets the same weighting applied via
  `TFT.consumable_weight(key, level)` as a per-candidate multiplier.
- Test: verify a real shop's Tarot/Spectral distribution shifts appropriately at a
  low vs. high level (e.g. Justice essentially never appears before level 7, phase-out
  group thins out by level 8) via a real, large-sample forced-input test (not just "shop
  opened, didn't crash").

## Item 1 — Level-up rewards + HUD level/XP — DONE, verified live

All three reward levels tested live end-to-end (real pickers, real granting, real UI):
Level 5 offered 3 real Tier-1 vouchers excluding Hieroglyph/Petroglyph, picking one
correctly set `G.GAME.used_vouchers` and applied the real vanilla effect (Seed Money's
`interest_cap` 25→50). Level 8's Deck Refinement reused `deck_picker.lua` unmodified
(`exact=false` already supported "0 to N" natively) — confirmed 0 selected removes
nothing, and a clean isolated test removed exactly 3 of 3 selected. Level 9's two paths
both work: "Upgrade an existing Voucher" correctly listed only eligible Tier-2s (hidden
entirely when none are eligible) and granted the real doubled effect on pick (Money Tree's
`interest_cap` 50→100); "3 Tier-1 Vouchers, Randomly" granted exactly 3 distinct fresh
vouchers with no further sub-choice. The bounded reward-queue/checkpoint-deferral system
was also directly verified: forced a level-up reward and an Augment Checkpoint onto the
same round transition, confirmed the checkpoint stayed closed while the reward was up and
opened immediately after, no stomping. The deck-mounted "Lv. X  Y/Z XP" HUD text needed a
real fix along the way (see below) and was confirmed rendering correctly afterward.

**Real bug found and fixed:** the Level/XP text was invisible on the first attempt despite
being correctly attached as a `G.deck.children` entry. Root cause, found by reading the
real installed `cardarea.lua`: `CardArea:draw()` only ever explicitly draws ONE hardcoded
child (`self.children.area_uibox`, its own card-count display) — never a generic loop over
`self.children` the way `Card:draw()` does. Fixed by hooking `CardArea:draw` itself to
additionally draw the new child specifically for `self == G.deck`.

**Locked decisions:**
- **Level 5:** offer 3 random Tier-1 vouchers (from the eligible pool, see exclusion
  below), pick 1. Same picker shape as the Augment Checkpoint (3 rows, pick one).
- **Voucher eligibility:** all vouchers EXCEPT ones that change Ante. Balatro's
  `v_hieroglyph`/`v_petroglyph` pair does this (needs a live check against
  `G.P_CENTERS` to confirm — going from memory, not a verified source read yet) — a real
  technical conflict, not just thematic, since `hooks.lua`'s
  `TFT.apply_current_round_blind_state` already force-pins `G.GAME.round_resets.ante` to
  match our stage every round; an Ante-modifying voucher would fight that pin directly.
  `TFT.VoucherExcluded` table, checked wherever the eligible pool is built.
- **Level 9:** a 2-row top-level choice: **"Upgrade an existing voucher"** (only enabled/
  shown if the player owns at least one Tier-1 voucher whose Tier-2 pair isn't already
  owned; picking it opens a second picker listing every currently-eligible Tier-2 upgrade,
  pick exactly 1) vs. **"3 tier-1 vouchers, randomly"** (picking this immediately grants 3
  random fresh Tier-1 vouchers, no further sub-choice). If zero Tier-2 upgrades are
  eligible, hide/disable the first option entirely rather than showing an empty list.
- **Tier-2 gating:** never offer a Tier-2 voucher whose Tier-1 pair isn't owned — build
  the eligible-upgrades list by walking `G.GAME.used_vouchers` against each voucher's real
  vanilla `requires` field (confirmed real field on vanilla Voucher centers) rather than
  hand-maintaining a tier-1/tier-2 pairing table — matches this codebase's existing
  convention of deriving from `G.P_CENTERS` at runtime (e.g. `jokers_by_power_tier()`)
  instead of transcribing vanilla data by hand.
- **Level 8 Deck Refinement:** reuse `deck_picker.lua`'s real-card-art `CardArea` picker,
  but change the selection-count contract from "exactly N" to "0 to N" (N=5) — drop the
  "must reach N to confirm" gate, keep the existing shared-cap eviction (still can't
  exceed 5), add a visible "Confirm" button that works with 0 selected (a real "skip the
  refinement" option) up through 5.
- **HUD:** new text row, `"Lv. 7  —  12/16 XP"` style (level + fraction into next level),
  placed near the deck sprite (right side of the screen, separate from the existing
  left-side HUD panel) rather than folded into the existing Life/Opp row. Needs finding
  the real deck-sprite UI construction site (`G.deck`'s wrapper, likely in
  `create_UIBox_HUD` or a separate deck-count UI builder) to splice above it, the same
  "hook the real vanilla UI builder" pattern as every other HUD change this project has
  made.

**Open implementation detail I'll resolve live, not asking about:** the exact vanilla
voucher keys for the Ante-changing pair, and the real `requires` field's exact shape —
both need a live `eval` check against a running instance before I trust them, per this
project's own standing "verify against real source/state, don't guess" rule.

## Item 4 — Run Info "Standings" tab — DONE, verified live (see the nil-hole bug in the STATUS section above)

After the tab-ordering fix, confirmed live in a real 2-player match: the tab renders both
players by real display name, level, and life total, sorted descending by life (forced one
player's tracked life to 40 vs the other's 100 and confirmed the higher-life player sorted
first). Player level is now broadcast for real too (`objects/actions/xp_level_change.lua`,
a gap technical.md had named — `xp_level_change` — but never actually built before this).

**Locked:** life total + level only, sorted by life total (I'll default to descending —
highest-alive first, i.e. "who's winning" — flagging that specific direction as my own
call since it wasn't specified, cheap to flip if wrong).

- Hook `G.UIDEF.run_info` (confirmed real, tab-based: `create_tabs({tabs = {...}})`) and
  insert a new tab (label "Standings" or similar) built from `TFT._opponent_life_totals`
  + `TFT._eliminated_players` + each player's last-broadcast level — checking whether
  level is actually being broadcast anywhere yet (technical.md's action list names an
  `xp_level_change` action; need to confirm it exists in
  `objects/actions/` or whether this item requires adding it) before assuming the data is
  already available.

## Item 5 — Lobby settings + typed join — DONE, verified live (2-instance; 8-player screenshot still pending, see "What's left")

Verified live: the typed join field (`create_text_input`) accepts real typed characters
and successfully joined a real lobby by its code. The settings panel's cycle
buttons/toggle correctly mutate `TFT.LobbySettings` on the host and sync to the guest via
`lobby:set_metadata`/the real `metadata_changed` event (confirmed both clients read
identical `deck_index`/`bonus_money`/`timer_enabled` values after the host cycled them).
Starting a real match correctly applied every setting on BOTH clients identically: deck
selection took effect via `G.GAME.viewed_back` (confirmed a real deck change, Red → Yellow,
with Yellow Deck's own real vanilla money bonus correctly stacking additively with our
bonus money -- $4 base + $10 Yellow Deck + $5 configured bonus = $19 on both clients
exactly), stake passed through correctly, and the timer toggle applied
(`state.timer_enabled`, gating the cosmetic stopwatch display). The existing
"Join Lobby (from clipboard)" button was kept alongside the new field per instruction.

**Locked decisions:**
- **No player-count cap enforcement** — host can start with anywhere from 2-8 players,
  any time. Add a minimum-of-2 guard to `tft_start_game` (currently has no player-count
  check at all).
- **Host-configurable settings, exactly these 4, nothing else for now:** deck selection,
  stake (difficulty), bonus starting money, timer enable/disable.
- Built on `lobby:set_metadata(tbl)` / `lobby:get_metadata()` / the `metadata_changed`
  event — confirmed real, existing MPAPI host-only mechanism, no new networking primitive
  needed. Settings UI: host gets real edit controls in the lobby screen, guests see the
  current values read-only.
- At match start, `tft_start_game`'s broadcast payload grows to carry the resolved
  settings (deck key, stake, bonus money, timer_enabled) alongside the existing seed, and
  every client's `on_receive` applies them uniformly — deck via setting
  `G.GAME.viewed_back` before calling `start_run` (confirmed real vanilla mechanism,
  since `Game:start_run` has no direct deck-override arg), stake via the existing
  `args.stake` (already wired, just hardcoded to 1 today), bonus money via `ease_dollars`
  right after run start, timer_enabled by gating the existing round-timer/hurry-up display
  and logic entirely off when disabled.
- **Typed join field:** replace the invisible clipboard-only join with a real
  `create_text_input` field (confirmed real vanilla widget) that accepts normal typed
  input and OS paste (Ctrl+V) — the existing one-click "Join from clipboard" button stays
  too, side by side, per your answer.
- **8-player lobby screenshot** — deferred to the final verification pass alongside the
  Carousel load test, per your sequencing instruction.

## Item 2 — Real multiplayer Carousel draft — DONE, verified live (2-instance; 4/8-instance load test still pending, see "What's left")

Every mechanic verified live against 2 real instances: the shared 8-pair pool broadcasts
and lands identically on both clients; turn order is genuinely ascending by life total
(forced one player's life to 50 vs the other's 100, confirmed the lower-life player got
turn 1 for real); the per-turn auto-timeout correctly grants a random remaining pair to
whoever doesn't act in time, confirmed by letting two full turns time out and checking both
clients ended up with exactly one real, distinct Joker each; a real manual pick resolves
IMMEDIATELY (not waiting for the timeout) and only grants the picked cards to the picking
client's own board, confirmed via an isolated single-turn test. The stage-based power-level
bias was checked directly against its own math (not just "a joker appeared"): the top tier
in a stage's range goes from an even ~33% share at stage 2 (no bias) to ~58% at stage 7
(full bias), confirming the weighting genuinely shifts as designed.

**Testing note for whoever picks this up next:** this environment runs at `G.SPEEDFACTOR /
G.SETTINGS.GAMESPEED = 4` by default (some existing testing-convenience setting, unrelated
to this feature) -- the 10s pre-timer and 10s per-turn timer both resolve in real
wall-clock time divided by that factor (~2.5s each), which is easy to mistake for a timing
bug if you don't know to check `G.SPEEDFACTOR` first. Set both to 1 via eval for a test
that needs the real, full-length timer windows.

**Locked decisions:**
- Single pick per player per Carousel event, sequential by ascending life total (lowest
  first) — confirmed not a multi-round snake.
- **Pool size is always 8** regardless of alive-player count (not scaled down as players
  are eliminated) — a smaller lobby simply leaves some of the 8 pairs unclaimed at
  round's end.
- **Timing:** a 10s pre-timer (a "look at the pool" window before picking starts) once
  the offer is broadcast, then each player's own turn gets 10s to pick before the turn
  auto-resolves to a random remaining pair for them.
- **Power-level bias, using the existing Power Tier system (not a new metric, not
  pre-Ranked copies):** within a stage's already-existing tier range
  (`TFT.CarouselTierRangeByStage`), weight the random pick toward the top of that range
  more heavily as stage increases, instead of today's uniform pick across the range.
  Concrete first-draft formula (flagged as an assumption, same convention as the tier
  range itself): `weight(tier) = 1 + bias_factor(stage) * (tier - min_tier)`, with
  `bias_factor` scaling linearly from 0 at stage 2 to some flat max (e.g. 3) at stage 7 —
  exact numbers are a first-draft placeholder, functionally verified (does the bias
  actually shift the distribution in the right direction) rather than tuned this pass.

**Design/implementation, following technical.md's already-drafted action list:**
- New actions: `carousel_offer` (host broadcasts the shared 8-pair pool once, seeded
  identically to what every client would compute anyway — sent explicitly rather than
  trusting independent computation, since the DRAFT PROGRESS itself, not just the offer,
  needs a shared source of truth), `carousel_turn_start` (host broadcasts whose turn it
  is + a timestamp, same soft-timer pattern as the existing round-timer design), and
  `carousel_pick` (a player claims a pair, broadcast to remove it from everyone's pool
  view and advance the turn).
- **Host authority:** matches this project's existing "host detects round-complete and
  broadcasts advance" pattern (technical.md) — the host is responsible for sequencing
  turns and firing the auto-random-pick timeout, not each client racing to decide when a
  turn has expired.
- Reuses `ui/picker.lua`'s overlay machinery for the actual pick UI (grid of 8 pairs,
  taken ones shown disabled/greyed rather than removed from layout, so the picker doesn't
  visually reflow mid-draft).

**Verification plan:** normal 2-instance testing for the core logic (offer broadcast,
turn sequencing, pick removal, timeout-to-random) first, since that's enough to prove
correctness. The 4-instance and then 8-instance live tests are the LAST thing done this
whole plan, batched with Item 5's 8-player lobby screenshot, per your instruction.

## What I'm explicitly NOT re-asking about

Every open question from my last message has an answer above except pure implementation
plumbing I'll resolve live against real game state (exact voucher keys, exact UI
node IDs to splice into) — those get verified against the running instance as I build,
not guessed at, per this project's standing methodology.

## What's left

All 5 items are functionally complete and live-verified on real 2-instance multiplayer.
Not done this pass:

1. ~~The 4-instance and 8-instance load test~~ — **DONE 2026-08-27**, see
   [4-8-player-test-plan.md](4-8-player-test-plan.md)'s own "Results" section for full
   pass/fail evidence. All 4/8-instance launches, N=4/N=8 PvP pairing rotation, and the
   Carousel draft (including the N=8 pool-exhaustion path) passed. The 8-player lobby
   screenshot for Item 5 was captured and sent to the user — **but it surfaced a real,
   reproducible layout bug**: at 5+ players the roster grid wraps to 2 rows and visually
   overlaps the Match Settings panel (root cause likely in how `MPAPI._new_card_grid`
   reports its own height for 2+ rows back to `ui/lobby.lua`'s vertical stack; full
   writeup in the test plan's "Finding 1"). Left unfixed per this project's own
   "document and leave alone for bigger, riskier changes" convention rather than
   improvise a layout fix mid-test. The run also surfaced a second, unrelated finding:
   the ghost-board mechanic's pairing/selection logic is correct and safe at real N=7,
   but the actual "snapshot of another player's board/score" architecture.md promises
   was never built — a ghost round currently just skips PvP resolution entirely for that
   player (see the test plan's "Finding 2"). Neither finding blocks normal 2-4 player
   play; both are real gaps worth a dedicated follow-up session.
2. **No live-updating on-screen countdown** during a Carousel turn — the timeout
   enforcement itself is fully real and verified, but the picker overlay shows static
   "Your turn!" text rather than a ticking number the way the existing round timer HUD
   element does. Minor UX polish gap, not a functional one — flagged rather than silently
   skipped.
3. As previously noted in Item 5's own section, the settings panel only exposes exactly
   the 4 settings asked for (deck/stake/bonus money/timer) — no scope creep beyond that.
