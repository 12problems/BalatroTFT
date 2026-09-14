# Session 2026-09-01 — Carousel Blind, Buy XP, system-card area, roadmap move

Scope: the 6-item request list from this date (chip-target table, Carousel Blind
type, shop Buy XP button, Traits Engine immunity + general system-card area,
stage-roadmap relocation, Portfolio Diversification investigation). Follows
directly on the full-playthrough-test-plan.md session earlier the same day.

## 1. Round-by-round chip targets, stage-by-stage — answered, no code

Pulled directly from the live `TFT.ensure_sequence()`, not recalled from memory.
Chip targets are stage-uniform (every non-Carousel round in a stage shares one
number) and identical whether that round type is PvE or PvP — only the ROUND
TYPE differs between solo (always PvE, no opponent to PvP against) and
multiplayer (positions 1/2/3/5/6 = PvP, 7 = PvE closer, per hooks.lua's
`TFT.slot_type_for_round`; Stage 1's 3 rounds are always PvE in both modes).

| Stage | Rounds | Chip target | Checkpoint | Carousel |
|---|---|---|---|---|
| 1 | 1-1, 1-2, 1-3 | 100 / 200 / 300 | — | — (Stage 1 has no Carousel; only 3 rounds total) |
| 2 | 2-1..2-7 | 1,000 | 2-1 (tier 1) | 2-4 |
| 3 | 3-1..3-7 | 3,000 | 3-2 (tier 2) | 3-4 |
| 4 | 4-1..4-7 | 8,000 | 4-2 (tier 3) | 4-4 |
| 5 | 5-1..5-7 | 20,000 | — | 5-4 |
| 6 | 6-1..6-7 | 50,000 | — | 6-4 |
| 7 | 7-1..7-7 | 120,000 | — | 7-4 |

Total: 45 rounds (3 + 7×6). Carousel rounds carry no chip_target (never a real
scored blind — see item 2).

## 2. Carousel Blind type — IMPLEMENTED, verified live (solo)

[objects/round_flow/carousel.lua](../../objects/round_flow/carousel.lua) /
[objects/actions/carousel_draft.lua](../../objects/actions/carousel_draft.lua).
Carousel rounds already never involved a real PvP/PvE blind (the picker opens
right at BLIND_SELECT before a blind is ever chosen) -- what was actually
missing, confirmed live before this fix: after the last pick resolved, the
player was dropped straight onto blind-select for the NEXT round with **no
shop stop at all**. Fixed:

- New `TFT.CAROUSEL_POST_PICK_DELAY_SECONDS = 5` -- a flat delay, additive on
  top of the multiplayer draft's own existing `CAROUSEL_PRE_TIMER_SECONDS`/
  `CAROUSEL_TURN_TIMER_SECONDS` (per explicit user clarification: solo AND
  multiplayer both get the new 5s delay; the existing draft timers are
  untouched, not replaced).
- New `TFT.carousel_finish()` / `TFT.carousel_finish_after_delay()`: runs the
  existing round-advance bookkeeping, then transitions into the shop.
  Carousel has no real Blind/ROUND_EVAL screen for vanilla's own
  `G.FUNCS.cash_out` to hand off from -- confirmed by reading the real
  installed `button_callbacks.lua`: cash_out's entire SHOP transition is
  nested inside `if G.round_eval then ... end`, and `G.round_eval` only
  exists after a real scored Blind's ROUND_EVAL animation. So this replicates
  just the actual state-transition lines cash_out performs (round-bonus/
  discard/hand-count reset, `G.STATE = G.STATES.SHOP`, `shop_free`/
  `shop_d6ed`/`STATE_COMPLETE` flips), skipping the animation-only lines that
  don't apply here.
- Both the solo pick handler (`pick_carousel_slot`) and the multiplayer
  `tft_carousel_finish` action (fires once every player's turn is done) now
  call `carousel_finish_after_delay()` instead of advancing immediately.

**Verified live (solo)**: jumped to a real Carousel round (global round_index
7, Stage 2 position 4), picked an option, confirmed round_index/state stayed
UNCHANGED immediately after picking (no more instant-advance), then confirmed
it transitioned into a fully-functional SHOP (real stock, working Buy XP/
Reroll/Next Round buttons) shortly after. Multiplayer not independently
re-verified this pass (2-instance test not run) -- shares the identical
`carousel_finish_after_delay` call in both paths, so no separate solo/
multiplayer logic exists to diverge, but flagging that the real host-broadcast
timing wasn't independently watched live this time.

## 3. Shop "Buy XP" button — IMPLEMENTED, verified live

New [objects/round_flow/shop_xp_buy.lua](../../objects/round_flow/shop_xp_buy.lua).
Spliced into `G.UIDEF.shop()` the same way `standings.lua`/`hud.lua` already
splice other vanilla UIDEF trees -- finds vanilla's real `next_round_button`/
reroll column and adds a third row, shrinking all three (1.5/1.6 -> 1.0 each)
to fit the same vertical space. Cost scales exactly like vanilla's own
`calculate_reroll_cost` (flat +1 per purchase within a shop visit, reset each
visit via `state.xp_buy_count_this_visit`, reset in poll.lua's existing
shop-entry block) -- explicit user choice. `can_buy_xp` mirrors vanilla's own
`can_reroll` enable/disable pattern exactly (greys out + strips the click
handler when unaffordable, rather than silently no-opping a click).

**ASSUMPTIONS (flagged, not confirmed)**: base cost $5, +5 XP per purchase --
neither number was specified by the user, both are reasonable-guess
placeholders pending real playtesting.

**Verified live**: button renders correctly ("Buy XP" / "+N XP" / live "$"
cost text, all present via `cctl ui`), reaching it via a real round win and
also via the new Carousel-Blind shop path. A real purchase deducted $5,
granted +5 XP, and the displayed cost escalated to $6 for the next purchase.
Confirmed the affordability gate: at $2 (below the $6 cost), `press
tft_buy_xp` correctly returned "no node" (button handler nil'd) and neither
dollars nor XP changed.

## 4. Traits Engine immunity + general system-card area — IMPLEMENTED, verified live

New [objects/round_flow/system_cards.lua](../../objects/round_flow/system_cards.lua)
-- a real, independent `CardArea` (same constructor vanilla itself uses for
`G.jokers`/`G.consumeables`), positioned beneath `G.consumeables`, meant as the
general home for every current/future pseudo-Joker "system" card (the Traits
Engine today; up to 3 per-augment pseudo-Jokers per player if technical.md's
original per-augment design is ever actually built as physical cards --
currently it isn't; every implemented augment is a plain `apply()`-style
one-shot mutation, not a persistent card).

**Why a separate CardArea, not just Eternal+Negative stickers**: confirmed by
reading the real installed `card.lua` that Ankh/Wheel of Fortune/Invisible
Joker and the sell-button visibility gate (`self.area == G.jokers`, ~line
4160) all key off `G.jokers` BY IDENTITY, not a type/tag field -- simply not
being in that table defeats all of them at once, including anything else
built the same way in the future, with nothing further to patch per-effect.
Modeled on MultiplayerAPI's own separate "phantom" showcase CardArea
(`BalatroMultiplayerAPI/api/synced/phantom.lua`), not that same file's
alternate masking approach.

**The real cost, and how it's paid**: vanilla's actual scoring dispatch
(`G.FUNCS.evaluate_play`, `functions/state_events.lua`) has `G.jokers`
hardcoded directly into several separate `for k=1,#G.jokers.cards do` loops
for exactly the three `calculate()` contexts the Traits Engine relies on
(`joker_main`, `individual`, `repetition`) -- moving a card out of G.jokers
would silently stop all three from ever firing. Confirmed via the real source
that `evaluate_play`'s entire body runs synchronously in one call (its
internal `delay()`/juice calls only pace already-decided numbers being
displayed, not the calculation). Fixed by wrapping `G.FUNCS.evaluate_play` to
splice the system-card area's cards into `G.jokers.cards` immediately before
calling through, then remove them again immediately after -- vanilla's real
scoring code runs completely unmodified and reaches these cards for exactly
those three contexts, while they're physically absent from `G.jokers`
everywhere else (shop, Ankh/WoF/Invisible Joker's own random-selection code,
sell button, "X/Y Joker slots" display) essentially 100% of the time. **Any
future system card needing a DIFFERENT calculate_joker context** (e.g.
`selling_card`, `end_of_round`) would need this same splice technique
extended to that other `G.FUNCS` entry too -- not automatically covered.

`TFT.add_system_card(center_key)` is the one call site any system-card
creator should use -- applies Eternal + Negative (both real vanilla stickers,
via `Card:set_eternal`/`Card:set_edition`, applied BEFORE `add_to_deck()` to
avoid a real vanilla side effect: setting Negative on an already-added,
non-consumable card bumps `G.jokers.config.card_limit` by +1, which would
have quietly inflated the player's real joker capacity). `eternal_compat` had
to flip from `false` to `true` on the Traits Engine's own definition --
`Card:set_eternal` silently no-ops against `eternal_compat = false`.
`TFT.ensure_traits_engine_joker()` now just calls `TFT.add_system_card(...)`.

**BONUS, discovered live while implementing this**: the Traits Engine living
directly in `G.jokers` this whole time meant it was actually consuming one of
the player's real Joker slots (confirmed live before the fix: `#G.jokers.cards
= 2` with only 1 real Joker owned; `card_limit` did not exclude it). Moving it
out fixes this as a free side effect -- every player effectively gets back one
Joker slot they didn't know they were losing.

**Verified live**: fresh run shows `G.jokers.cards` empty (0/5 slots used,
where it previously would have shown 1/5 immediately) and `TFT.system_cards`
holding exactly the Traits Engine card with `ability.eternal = true` and
`edition.negative = true`. Screenshot confirmed correct visual placement
(negative-edition card rendering below/right of the joker row, in its own
spot). Played a real hand afterward: scoring completed normally (real chips
banked, no errors), and `G.jokers.cards` was confirmed empty again immediately
after -- the splice-in/splice-out around `evaluate_play` leaves no residue.
Did not individually re-verify every one of the 9 traits' specific breakpoint
effects this pass (Suit Guilds, Scalers, etc.) -- the underlying dispatch
mechanism they all share was confirmed working; their own internal logic was
unchanged by this move.

**Follow-up fix, same day (explicit user feedback)**: the "1/11" oddity above
turned out to be exactly the same real cause as a genuine functional bug, not
two separate cosmetic quirks -- root-caused after this feedback prompted a
closer look. `card_limit` was set to 10 originally (a "general home" future-
proofing guess); the user asked for it to be pinned to 1 instead, so nothing
suggests more cards belong there. Doing so surfaced a real, confirmed-live
gotcha: applying the Negative edition (`TFT.add_system_card`) grants +1 to
whatever area the card lives in via a genuine DEFERRED event, not the
hardcoded G.jokers/G.consumeables-only synchronous assignment the static
vanilla source reference suggested (this project's own well-known "deferred
mutation reads stale if checked synchronously" gotcha bit the diagnosis of
this exact bug twice in a row before landing on the real cause -- confirmed
by creating a throwaway, totally unrelated CardArea and watching ITS
card_limit also drift from 1 to 2 only after a real few-second delay).
Applying the edition before `add_to_deck()` does not avoid this. Fixed by
pinning `TFT.system_cards.config.card_limit = 1` unconditionally every frame
in the `Game:draw` hook -- cheap, and immune to whatever the real mutation
path turns out to be. Verified live: reads "1/1" and stays there after a real
delay past when the drift used to occur.

**Also fixed, same feedback**: the stage roadmap was a CardArea-CHILD UIBox
(attached to `TFT.system_cards`, positioned via `parent=`), which read as
"tied to a joker" -- the user's own words -- both structurally (its lifecycle
depended on that CardArea existing) and visually (a bare transparent
`G.C.CLEAR` root with no background chrome, unlike the boxed look the
original pre-2026-09-01 HUD-Ante-box version had for free from vanilla's own
Ante column background). Reworked into a fully standalone `UIBox` with no
`parent`/`major` at all -- confirmed via the real installed `engine/ui.lua`
that `UIBox:init` reads `args.T` directly and defaults `config.major` to
`self` when no parent is given, so a plain absolute `T = {x, y}` positions it
with zero dependency on any other object -- wrapped in its own dark rounded
container (`colour = G.C.BLACK, r = 0.1, emboss = 0.05`) to restore the boxed
look. Position is still derived from `TFT.system_cards.T.x/y/w/h`, but only
as a one-time coordinate lookup (recomputed on `set_screen_positions()`), not
an ongoing structural relationship. Verified live via screenshot: a clearly
separate dark box below the card, no shared chrome.

## 5. Stage roadmap relocation — IMPLEMENTED, verified live

Moved (again) from the persistent HUD's Ante box
([objects/round_flow/hud.lua](../../objects/round_flow/hud.lua), the
2026-08-26 location) to a floating UIBox anchored below the new system-card
area, per explicit user request and dependency on item 4. Reuses
`TFT.build_hud_stage_nodes` verbatim (the narrow pip layout, unchanged) --
only the anchor point and the live-rebuild wiring are new
(`TFT.attach_stage_roadmap_display`/`TFT.refresh_stage_roadmap_display`,
system_cards.lua), built on the same real "float a UIBox as a child of a real
Moveable" + "rebuild one node in place via add_child" primitives this project
already uses for the deck level display and the old HUD-embedded roadmap,
respectively. The Ante box itself is no longer repurposed -- vanilla's own
real Ante number shows through again, which is now an accurate, meaningful
number (hooks.lua keeps it pinned to the current TFT stage), not a stale one.

Refreshed on both real round-advance (`TFT.round_flow_advance`, poll.lua) and
Carousel round-advance (`TFT.carousel_advance`, carousel.lua) -- the OLD
HUD-embedded version only ever refreshed on the former, a real pre-existing
gap (a Carousel round-advance never updated the visible roadmap pips) closed
for free while relocating this display.

**Verified live**: first attempt overlapped the system card's own art (a
naive `T.h + 0.2` offset assumption about the UIBox alignment/offset unit
convention was wrong, confirmed by reading back both elements' actual T.x/y/
w/h side by side) -- corrected empirically via a live screenshot comparison
to `T.h + 1.2`, re-screenshotted to confirm clean separation with no overlap.

## 6. Portfolio Diversification — CONFIRMED WORKING; real unrelated bug found + fixed

Not a bug in the augment itself -- `objects/augments/definitions.lua`'s
`apply` function was confirmed correct both in data (`card_limit` deltas
applied correctly, checked across two separate eval calls to avoid the
same-call-read-back gotcha) and visually (slot-count labels updated
correctly on screen). The user's confusion was very likely caused by a real,
separate, more serious bug found while chasing this down:

**[objects/round_flow/hooks.lua](../../objects/round_flow/hooks.lua)'s
`Game:start_run` hook used to unconditionally reset `state.round_index/level/
xp/etc` to fresh-run defaults on EVERY run start, including real continues**
-- silently discarding a correctly-restored continue's progress (including
any picked augments) every time, while vanilla's own `G.GAME` fields
(dollars, jokers, ante) stayed correctly resumed. Root-caused by reading the
real installed `game.lua`: vanilla's own `Game:start_run(args)` already
correctly restores `G.GAME.tft_state` for free whenever `args.savetext` is
present (a real continue) -- our hook just needed to skip its own reset block
in that case. Fixed via an `is_continue` check. Source-level confidence is
high; a full live continue round-trip re-test was inconclusive for an
unrelated reason (this project's own save-write timing is not synchronous
with `go_to_menu` -- a separate, already-documented complication, not
evidence against the fix).

## Third follow-up pass, same day: double-card visual, roadmap sizing/colour, timer format

Three more pieces of explicit live-screenshot feedback, all fixed and
re-verified live:

1. **Double-joker visual on the system card, FIXED.** Initially suspected
   (wrongly) to be the Negative edition's own real vanilla shadow/parallax
   render -- dropped Negative entirely (kept Eternal) as a first attempt,
   which did NOT fix it (confirmed live via isolation: a plain Eternal,
   non-Negative copy of `j_tft_traits_engine` placed directly in G.jokers
   rendered as a single clean card, ruling out both the edition AND the
   center definition itself). Root cause, found by precisely measuring draw
   call rates against `love.timer.getFPS()`: `TFT.system_cards:draw()` was
   genuinely firing ~2x per real frame (matched exactly 1:1 for the top-level
   `Game:draw` hook and for a real vanilla area, `G.jokers:draw()` -- only
   this one area's draw call came back doubled). The real second caller's
   origin was never identified. A first fix attempt (gating only this file's
   own explicit draw call site) did NOT resolve the visual either, proving
   the mystery caller invokes `TFT.system_cards:draw()` directly, bypassing
   that call site entirely. Fixed for real by wrapping the CardArea
   INSTANCE's own `:draw` method (shadowing the class method just for this
   object) with a per-frame dedup guard (keyed on `G.FRAMES.MOVE`) -- every
   caller, ours or the mystery one, now funnels through the same check. The
   same guard was defensively added to the roadmap's standalone UIBox too
   (not independently confirmed double-drawn, but cheap insurance). Dropping
   Negative is being kept regardless of the real cause turning out to be
   unrelated -- it was never load-bearing for immunity (that's the CardArea
   move itself, per item 4's own header comment) and there's no reason to
   re-add a real vanilla shadow-render effect to a card meant to look like a
   single, unified system element. **Deviation from the user's original item
   4 spec, flagged explicitly**: the card is Eternal only now, not
   "Eternal + Negative" as originally requested -- a direct result of this
   follow-up feedback session.
2. **Stage roadmap too long/too dark, FIXED.** The inner column forced
   `minw = TFT.system_cards.T.w` (the card area's own width), padding the box
   out far beyond what a few small pips actually need -- removed, so it
   sizes snugly to content instead (and is now re-centered under the card
   area using its own resulting T.w, since a left-aligned box would hug the
   edge once it's no longer forced to full width). Background swapped from a
   flat opaque `G.C.BLACK` to `G.C.DYN_UI.BOSS_DARK` -- the same
   semi-transparent tone vanilla's own "Round score" HUD box uses
   (`functions/UI_definitions.lua`'s `contents.dollars_chips`, confirmed via
   the real installed source) and this project's own `build_hud_life_row`
   already reuses elsewhere.
3. **Round timer too long, FIXED.** Replaced the old m:ss.mm elapsed-stopwatch
   format (mirroring BalatroMultiplayerSpeedrun's own convention) with the
   REAL, official BalatroMultiplayer mod's own countdown format instead
   (github.com/Balatro-Multiplayer/BalatroMultiplayer, `ui/game/timer.lua`'s
   `timer_UI_count` DynaText -- fetched and read directly via `gh api
   repos/.../contents/ui/game/timer.lua`, not guessed at): `secs > 9.95` shows
   a bare integer, otherwise one decimal place. Caps the displayed text at 3
   characters for any timer under 1000 seconds (every real budget in
   `domain/round_timers.lua` maxes out at 90s -- those numbers are
   UNCHANGED, only the text rendering them is, per the user's own explicit
   instruction). Verified both via direct function calls (90->"90",
   45.7->"46", 10->"10", 9.94->"9.9", 0.34->"0.3") and live in the HUD.

## Fourth follow-up pass, same day: live trait-status description + a real click-crash fix

New request: make the Traits Engine's own description show each trait's
CURRENT status live, rather than the static internal placeholder text.
Implemented in [objects/traits/engine.lua](../../objects/traits/engine.lua):

- `TFT.build_trait_status_entries()`: only traits with >=1 owned tagged
  Joker (a RAW count, deliberately excluding Trait Heart's +2 bonus -- "has
  at least 1 of" means owns >=1 tagged Joker, not "the bonus alone would
  qualify it"), sorted with every trait whose breakpoint is currently MET
  ("active", tier > 0) above every trait that isn't (tier == 0) regardless of
  raw count -- per the user's own explicit example -- then by tier
  descending within the active group, then by count descending, then
  alphabetically for determinism.
- `TFT.trait_status_line_text(entry)`: e.g. "Spades Guild: Tier 1/2 (2
  owned)" once active, or "Scholars: 1/2 owned" while short of the first
  breakpoint.
- `generate_ui` on the SMODS.Joker definition itself: SMODS's own dynamic-
  tooltip extension point (confirmed via the real installed Steamodded
  lovely patch, `lovely/center.toml`, patching `functions/common_events.lua`'s
  `generate_card_ui` -- this branch is checked FIRST, ahead of the static
  loc_txt fallback), building one line per qualifying trait directly as
  `desc_nodes` entries (colour green if active, grey/`G.C.UI.TEXT_INACTIVE`
  if not) -- the exact per-line node shape was confirmed by reading it
  straight out of `localize()`'s own real line-building loop
  (`functions/misc_functions.lua`) rather than guessed at, so this reuses
  vanilla's own real per-line node convention (same desc_scale formula, same
  shadow flag) without going through the `{C:colour}` markup/`loc_vars`
  templating system at all -- appropriate since colour needs to vary per
  COMPUTED line, not a fixed static template. The old static "(Internal --
  ...)" text is now fully superseded whenever the tooltip is actually shown,
  kept only as a fallback for any code path that reads `loc_txt.text` directly.

**Verified live**: rather than fight cursor-hover timing for a screenshot,
called `card:generate_UIBox_ability_table()` directly (the real function a
hover triggers) and walked its return value for text -- confirmed the exact
expected lines, in the exact expected sorted order, with the exact expected
colours (RGB extracted: active lines came back as `G.C.GREEN`, inactive as
`G.C.UI.TEXT_INACTIVE`), with a 7-joker test spread across 5 different
traits at different counts/tiers (including Ascendants, auto-tagged onto
several of the test Jokers by power tier -- multi-trait tagging working as
designed, not a bug).

**Real crash found and fixed along the way, unrelated to the feature itself
but discovered while testing it**: a plain click landing on or near the
system-card area reproducibly crashed the whole game --
`cardarea.lua:227: attempt to index local 'card' (a nil value)`, inside
vanilla's own real `CardArea:remove_from_highlighted`, confirmed by reading
this instance's actual `lovely/dump/cardarea.lua` (not the static offline
reference, which has different line numbers/content at that point -- a real,
concrete example of why this project's own guide says to check the live
dump when in doubt). The exact vanilla call chain that reaches this with a
nil card was not root-caused; fixed instead by setting
`card.states.collide.can = false` on the system card right after `emplace()`
(has to be AFTER, not before -- `CardArea:emplace`'s own `set_ranks()` call
unconditionally resets `collide.can = true` for every card in a non-deck
area, stomping any earlier override). `states.hover.can` is a SEPARATE flag
left untouched, confirmed still true by default -- this is exactly why the
tooltip itself still works while clicks no longer reach the card at all.
Verified live: the same click that used to crash the game now no-ops
cleanly, immediately after redeploying this fix.

## Fifth follow-up pass, 2026-09-02: TFT-style breakpoint tooltip + real per-trait Stickers

Two more explicit requests, both implemented and verified live:

**1. Traits Engine tooltip reworked to "how TFT does it"** -- every qualifying
trait now shows its FULL breakpoint ladder (every threshold + effect text,
`TFT.TraitBreakpointEffects`, objects/traits/engine.lua), with the row
matching the CURRENTLY-reached tier visually emphasized (gold + slightly
larger scale -- this engine's real equivalent of "bold," confirmed there's no
actual font-weight concept) and every other row (both below-and-superseded
and not-yet-reached) shown grey/inactive -- matching the user's own literal
ask to bold ONLY the current one, not every met breakpoint. Verified live by
calling `card:generate_UIBox_ability_table()` directly and walking its
return value: exact expected lines, in the exact expected order, with the
exact expected colours (RGB-checked). Also found and corrected two real gaps
between the design doc's aspirational text and actual implementation while
building this (Scholars tiers 2/3 never implemented; Ascendants' "Legendary
shop odds" clauses aren't real Ascendants-specific effects, Legendary shop
appearance is governed entirely separately by level) -- marked honestly in
the tooltip rather than promising something the code doesn't do.

**2. Real per-trait visual Stickers**, using SMODS's own first-class Sticker
system (objects/traits/stickers.lua) -- explicit user request, and only
attempted after two rounds of clarifying questions given this project had
never had custom art assets before: the user supplied a real icon sheet,
10 of ~32 icons were picked by thematic fit (flagged, not an exact 1:1
mapping) and composed into a fresh 5x2 atlas (assets/1x+2x/
trait_stickers.png) via a one-off Python/PIL script. Each trait-tagged
Joker's sticker set is kept in sync with its live `TFT.get_trait_tags` every
frame (poll.lua), covering every real tag-changing event without a
dedicated hook per call site. Hovering a stickered card shows a real,
dynamically-computed tooltip (via `loc_vars`, vanilla's own `#1#`/`{V:n}`
value- and colour-substitution markup -- NOT the `generate_ui`
node-building extension point engine.lua's own tooltip uses, since Stickers
don't expose that hook) reusing the identical breakpoint-ladder content and
bolding logic from item 1.

**Two real, non-obvious bugs found and fixed live, both asset-level, not
code bugs**:
- A "2x" atlas variant that's just a duplicate of the "1x" file (rather than
  a genuine double-resolution image) mismatches LÖVE's own `dpiscale`
  handling and made every icon render as a 2x2 block of neighboring atlas
  cells. Fixed by generating a real upscaled 2x file.
- A Sticker's on-card sprite draws at FULL CARD SIZE unconditionally
  (confirmed this is also true of vanilla's own Eternal/Perishable/Rental,
  via the real installed engine/sprite.lua/game.lua) -- vanilla's own
  sticker art is a mostly-transparent border image so this only tints the
  edges; a first version of this atlas filled its whole cell with an OPAQUE
  icon, so every stickered card became completely unrecognizable, its own
  icon fully replacing the real card art. Fixed at the asset level (each
  icon shrunk to a small corner badge with the rest of its cell fully
  transparent), not in code.

**Known remaining gap, not solved this pass**: multiple simultaneous trait
stickers on one multi-trait Joker (e.g. j_bloodstone, HeartsGuild+
Multipliers) all anchor to the same corner and overlap rather than laying
out side by side -- confirmed live, only one of two was visible at once. The
hover tooltip content itself is unaffected (whichever sticker is visually on
top still shows its own correct info) -- this is purely a "more than one
badge visible at once" layout gap, would need each card's own active
stickers positioned at different offsets computed dynamically per card.

## Sixth follow-up pass, 2026-09-05: multi-trait icons fixed + tooltip simplified

Picked up the Fifth pass's "known remaining gap" (multi-trait stickers
overlapping in one corner) plus a new complaint: the Traits Engine's own
tooltip (one giant box listing every owned trait's FULL breakpoint ladder)
had become unreadable with 5+ owned traits -- shadowed, cramped, one big
wall of text.

**1. Traits Engine tooltip simplified back down** (objects/traits/engine.lua)
-- now shows ONE line per qualifying trait, name + numeric owned count only
("Multipliers (2 owned)"), still sorted active-tier-first via the existing
`TFT.build_trait_status_entries`. The full breakpoint-ladder description
(every threshold + effect text, current tier bolded) moved entirely to each
trait's own Sticker badge tooltip -- which already had that exact content
since the Fifth pass, so this was a pure subtraction (removed the
per-breakpoint-row loop from `generate_ui`, removed the now-dead
`TFT.trait_breakpoint_rows` helper), not new UI work.

**2. Multi-trait on-card icons, rebuilt from scratch** (objects/traits/
stickers.lua) -- replaced the Fifth pass's "one SMODS.Sticker sprite per
trait" approach (which only ever showed ONE trait's icon per card, the rest
silently invisible) with: per-trait Stickers now register against a blank
1x1 atlas and exist ONLY to drive the hover-tooltip badge system (unchanged
visual/content from Fifth pass); the actual ON-CARD icon is a single
love.graphics.Canvas per Joker card, pre-composited with all of that card's
currently-active trait icons side by side (up to 4 slots), rebuilt only
when the card's active-tag set changes, then drawn once per frame as a
plain `Sprite` via the same `draw_shader('dissolve', ...)` full-card-stretch
call a real Sticker uses. Verified live: Constellation (Multipliers+Scalers+
Scholars) and Bloodstone (Ascendants+HeartsGuild+Multipliers) both now show
3 distinct, correctly-shaped icons side by side across the card's top edge;
Golden Joker (Financiers only) still shows its single icon correctly.

**The actual bug, after a long detour**: chasing "some trait icons render,
others silently don't" through several plausible-looking rendering-engine
theories (SMODS.Sticker limits, Quad/atlas-position effects, mipmapping --
all tested live, all eventually ruled out) before direct pixel readback on
the SOURCE ASSET FILE ITSELF (`Canvas:newImageData():getPixel()`, not just
querying the runtime atlas object's declared dimensions) revealed several
columns of `assets/2x/trait_icons_strip.png` were genuinely, silently empty
on disk -- a real bug in this session's own multi-step asset-regeneration
pipeline, not an engine limitation. Rebuilt as a clean 2x upscale of the
verified-good 1x file and the "missing" icons appeared immediately, no code
changes needed. See objects/traits/stickers.lua's own header comment for
the full (now corrected) account -- worth reading before touching this
system again, since most of the theories chased along the way sounded
convincing right up until the actual file-level check.

## What's left

0. **New finding, 2026-09-01 (demo screenshot session)**: force-jumping straight
   to a checkpoint round via the usual `state.round_index = N; reset_blinds()`
   testing shortcut (used safely elsewhere all session) crashed the game a few
   seconds after `select_blind` -- `functions/button_callbacks.lua:2581:
   attempt to index field 'UIBox' (a nil value)`, thrown from inside a
   deferred `G.E_MANAGER` event, not synchronously. Round 2-1 (the jump
   target) is a checkpoint round (`is_checkpoint = true`) -- suspect the raw
   jump skips whatever real state a normal `round_flow_advance`/
   `carousel_advance` transition would have armed for the checkpoint announce
   path, but not confirmed. Not chased further: playing 1-1 through 2-1 for
   real (select_blind -> win -> cash_out each round, picking the checkpoint
   offer normally) reached the same round with zero issues. Worth root-
   causing before relying on the jump shortcut against ANY checkpoint round
   again.
1. Multiplayer re-verification of item 2 (Carousel Blind's 5s delay + shop
   transition) via a real 2-instance test -- code-reviewed and structurally
   identical to the solo path (same `carousel_finish_after_delay` call), but
   not independently watched live this pass.
2. The "1/11" system-card-area count-text off-by-one (item 4) -- cosmetic,
   not investigated.
3. Individual re-verification of each of the 9 traits' specific breakpoint
   effects post-move (item 4) -- the shared dispatch mechanism was confirmed
   working; each trait's own internal math wasn't independently re-exercised.
4. A real save/continue round-trip re-test for item 6's hooks.lua fix, once a
   real gameplay-triggered autosave (not an instant field poke) can be
   reliably captured -- see this doc's own note above and the earlier
   full-playthrough-test-plan.md's "save-write timing" finding.
5. As always: nothing in this session is committed to git.
