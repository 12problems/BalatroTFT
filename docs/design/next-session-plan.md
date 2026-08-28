# STATUS UPDATE (2026-08-27): priorities 1-3 below are now DONE and live-
# verified (2-instance where relevant). See docs/design/next-session-plan-2.md
# for what's actually left: priority 4 (rank visuals) was deliberately SKIPPED
# after investigation found no safe precedent in this codebase for it (see
# that doc for why, and what was tried); priority 5 (testing sweep) is
# partially done (the 5 flagged highest-risk augments rigorously verified via
# forced-input tests, plus a full-73-simultaneous no-crash regression check),
# not every one of the 73 individually. Read next-session-plan-2.md first.

# Next Development Session — Plan for an Unmanaged/Autonomous Run

Written 2026-08-26, at the end of a long supervised session that built: the full round/
stage/leveling engine, real MPAPI multiplayer (lobby create/join/start, verified live with
2 real instances), the PvP pairing/damage/life-total loop (verified live, including the
`end_round()` game-over-suppression fix), all 9 Trait breakpoints mechanically wired, the
Joker Ranking system (Showman-baseline, merge-on-acquire, rank multiplier, sell-value
bonus — verified live with a rigorous forced-hand A/B scoring test), 73 augments across
all 8 categories, and a JokerDisplay-mod integration showing Rank/multiplier info on
cards. See git history and this file's sibling docs (`architecture.md`, `technical.md`,
`traits.md`, `joker-ranking.md`, `augments.md`) for the full design record.

**Standing operating instructions for whoever/whatever runs this next** (carried over from
this project's established working pattern — not new rules, just written down since this
is unmanaged):

- **Keep assuming answers to open design questions and note every assumption** at the end
  of each work cycle, the same way this whole project has been built. Don't block on
  design ambiguity — pick the most defensible interpretation, implement it, flag it in a
  code comment AND in your own summary.
- **Verify against the actual installed source, not a reference checkout**, when the two
  might differ. This bit twice this session (`find_joker("Showman")` vs the real
  `SMODS.showman()`, and `Balatro Source`'s `get_current_pool` vs the live SMODS-patched
  version in `Mods/lovely/dump/functions/common_events.lua`). When a hook doesn't seem to
  fire, check `Mods/lovely/dump/` for the REAL patched source before assuming your own
  logic is wrong.
- **Test live, not just "it compiled."** The multi-instance launch recipe, ClaudeControl
  (`cctl`) usage patterns, and DebugPlus gotchas are documented in this machine's Claude
  memory (`claudecontrol-testing-setup.md`, `balatro-multi-instance-launch.md`) — read
  those before starting. Key reminders: clear `Mods/lovely/dump` + `game-dump` on every
  relaunch, never clear `Mods/lovely/log`; DebugPlus's `tab` key can crash if pressed while
  MPAPI's lobby UI is mid-churn (use direct `cctl eval` state manipulation for testing
  instead, mirroring `DT_win_blind`'s own logic:
  `G.GAME.chips = G.GAME.blind.chips; G.STATE = G.STATES.HAND_PLAYED; G.STATE_COMPLETE = true; end_round()`).
- **A rigorous verification beats a plausible one.** The `mult_mod`/`Xmult_mod` bug in the
  Ranking system's scaling (it was scaling the wrong field names for ~most vanilla Jokers)
  was only caught because a forced-identical-hand A/B test was run — an isolated function
  call returning a "plausible-looking" number had passed a shallower check earlier in the
  same session. When verifying a numeric system, prefer: force identical inputs, compute
  the expected output by hand, compare exactly — not "did it crash" or "does this look
  about right."

---

## Priority order

### 1. PvP life total UI + elimination/match-end logic (HIGHEST PRIORITY)

**Why this is first:** `state.life_total` is fully computed and broadcast correctly
(`objects/actions/round_result.lua`, `objects/actions/life_total_change.lua`), but it is
**never shown anywhere in the game's UI** — a player has no way to see their own or an
opponent's life total without a console. Worse, there is **no elimination/placement
tracking at all**: a player who hits 0 life just keeps playing with a negative number
forever. This is the single biggest gap blocking the mode from being a real, finishable
multiplayer match. (Cross-reference: `objects/actions/round_result.lua`'s own comments
already flag this; Second Wind's and All or Nothing's "eliminated" clauses in
`objects/augments/definitions.lua` are explicitly stubbed pending this.)

**Concrete sub-tasks, roughly in build order:**

1. **Life total HUD display.** Needs a real, always-visible UI element (not a popup) —
   the natural home is the same persistent left-sidebar HUD vanilla builds in
   `functions/UI_definitions.lua`'s `create_UIBox_HUD()` (~line 1274 in the reference
   checkout — **verify against `Mods/lovely/dump/functions/UI_definitions.lua`, the real
   installed version, per the standing instruction above**). That function builds the
   Ante box (`id='hud_ante'`, live-bound via `DynaText{ref_table=G.GAME.round_resets,
   ref_value='ante'}`) and the Round box (`id='row_round_text'`, bound to
   `{ref_table=G.GAME, ref_value='round'}`) side by side. Both are real, live
   `ref_table`/`ref_value`-bound UI elements — the same idiomatic pattern JokerDisplay
   uses (see `objects/jokers/rank_display.lua` for a worked example already in this
   codebase). Hook `create_UIBox_HUD()`, find the built tree's Ante/Round node pair
   (matching by `id`), and either replace their contents in place or splice in a new life
   total box using the identical structural pattern (`DynaText` bound to
   `state.life_total`). Show opponent life too if reasonably possible (their value is
   already received into `TFT._opponent_life_totals`, keyed by player id — resolving
   "current opponent" needs `TFT.find_pvp_opponent(state.current_pairing, their_id)` run
   the other direction, or just read `state.current_pairing` directly).
   - **User's explicit follow-up request on this exact screen** (given while reviewing a
     screenshot of the blind-select UI): the "Stage N: [pips]" roadmap row
     (`objects/round_flow/blind_select.lua`'s `TFT.build_stage_roadmap_row`) currently
     gets visually crowded by the blind card next to it. **Move it to replace the "Ante"
     box** in the persistent HUD (same `create_UIBox_HUD()` hook as above — our own
     Ante is already stage-pinned via `hooks.lua`'s `reset_blinds()` override, so
     vanilla's Ante number is redundant with the stage number anyway). **Replace the
     "Round" box with a round timer**, to match the visual convention other multiplayer
     Balatro mods use for their "ready up"/round-timer systems — reference
     `BalatroMultiplayerSpeedrun/ui/timer/` (`clock_ui.lua`, `appearance.lua`,
     `format.lua`, `lifecycle.lua`) for the real, working pattern to mirror rather than
     inventing one from scratch. **Open design question this touches but wasn't
     resolved this session: does BalatroTFT actually have (or need) a real per-round
     timer/ready-up mechanic yet?** The original design mentions "'ready up' systems...
     to facilitate timers of rounds (and advancing early)" but this was never built —
     if it doesn't exist, decide whether to (a) build a minimal real timer this session
     (a shared countdown broadcast at round start, advance-early on all-ready), or
     (b) show a simpler round-elapsed stopwatch with no gameplay effect for now, as a
     visual placeholder consistent with the ask without inventing the full ready-up
     system in the same pass. Pick one, document the choice.

2. **Elimination detection.** When a player's `state.life_total <= 0` (after
   `round_result.lua`'s damage resolution — respecting Second Wind/All or Nothing's
   existing life-floor logic already in that file), mark them eliminated. This needs:
   - A new plain-data state field (`state.eliminated = true`, safe for save/broadcast)
     and a broadcast so OTHER clients learn a given player is out (extend
     `objects/actions/life_total_change.lua`'s existing broadcast, or add a small new
     `tft_player_eliminated` action following the same `MPAPI.ActionType` pattern already
     used throughout `objects/actions/`).
   - `domain/pvp_pairing.lua`'s `TFT.compute_pvp_pairing` currently takes `alive_ids` as
     a param already (per the existing doc comment) but `objects/round_flow/pvp.lua`'s
     `TFT.setup_pvp_pairing_if_needed` currently derives "alive" from
     `lobby._players` (everyone in the lobby), NOT real elimination state — this is
     explicitly flagged as a known gap in that file already. Fix it to exclude
     eliminated players once this exists.
   - Decide and implement what actually happens to an eliminated player's OWN client:
     do they keep playing solo (spectator-adjacent), get dropped to a "you were
     eliminated, rank N" screen, or something else? No precedent exists in this codebase
     yet — this is a real design decision to make and document, not one to leave
     ambiguous.
   - Decide match-end: does the match end when only 1 player remains, or does it run
     until every player finishes the full round sequence regardless of elimination
     (i.e., elimination just means "no longer takes PvP damage/participates in pairing"
     rather than "kicked from the run")? The architecture docs lean toward last-player-
     standing (TFT-style), but this was never locked down — pick one and document it.

3. **A real end-of-match screen** for multiplayer (win/lose/placement), reusing vanilla's
   `create_UIBox_win()`/`create_UIBox_game_over()` patterns
   (`functions/UI_definitions.lua` ~lines 2749/2862) as a structural reference the same
   way this project has reused other vanilla UI builders throughout, rather than
   building one from scratch.

**Acceptance bar:** a real 2-instance PvP match, played to actual completion, where both
players can SEE their life total and their opponent's throughout, and something coherent
and visible happens the moment one of them would hit 0 life — verified live, the same way
every other system this session was verified (screenshots + `cctl eval` state checks, not
just "no crash").

---

### 2. Shared Joker Pool (lobby-wide scarcity)

**Why second:** explicitly named as the next priority after life/elimination. This is the
mechanism that makes Joker Ranking a genuinely contested, TFT-like resource across a real
lobby rather than an independent, uncapped per-player roll — without it, Ranking's whole
"stay low, slow-roll for copies" tension (the actual point of the system, per
`joker-ranking.md`'s own framing) only exists for a solo player.

**The design is already fully worked out** in `docs/design/joker-ranking.md`'s "Shared
Joker Pool" section — this is an implementation task, not a design task. Key resolved
decisions already in that doc (don't re-litigate these, they're settled):
- Pool sizes are TFT's own bag numbers, ported directly, **already coded** in
  `domain/rarity_odds.lua` (`TFT.SharedJokerPoolSize`, `TFT.pool_size_scaler`,
  `TFT.shared_pool_size(power_tier)`) — unused by anything yet, ready to consume.
- **Snapshot-refresh, not live-decrementing**: available copies of Joker X = pool size
  minus the sum of copies currently owned across all alive players, recomputed only at
  the moment a player opens their own shop. No real-time locking needed.
- **Pool overrun is explicitly allowed** (confirmed in the doc, "Confirmed: option 1") —
  two players' shops both reading "1 left" and both buying it is an accepted, rare,
  low-stakes edge case. Do NOT build host-side purchase validation for this; the doc is
  explicit that this was a deliberate simplicity choice.

**Concrete sub-tasks:**

1. **Broadcast each player's owned-Joker-and-copy-count summary.** `technical.md`'s
   Player State Schema (check that doc for the exact existing shape) is supposedly
   already designed to carry this — verify what's actually broadcast today via
   `objects/actions/` and extend it if the owned-Joker list isn't already in there. Keep
   the payload small (key + copy count per owned Joker, not full card objects — same
   "broadcast plain summaries, not live objects" pattern already used for round results).
2. **Compute "copies available" per Joker key** at shop-open time: pool size (via
   `TFT.shared_pool_size`) minus the sum of every alive player's owned-copy-count for
   that key, using the received summaries above plus your own.
3. **Filter `get_current_pool`'s Joker candidate list** (the same real function
   `objects/round_flow/shop_odds.lua` already hooks) to exclude any key with 0 copies
   remaining, in addition to the existing rarity-bucket logic already there. Be careful
   about interaction with the Showman-baseline fix from this session
   (`objects/jokers/ranking.lua`'s `SMODS.showman` override) — that override is what lets
   an ALREADY-OWNED Joker reappear at all; the shared pool is an independent, additional
   cap on top of that, not a replacement for it.
4. **Live-test with 2+ real instances**: verify that buying enough copies of one Joker
   across two clients' shops genuinely shrinks what the other sees, using the same
   `cctl eval`-based verification style established this session (read `G.jokers.cards`
   on both instances directly, don't infer from screenshots alone).

---

### 3. Remaining flagged augment/trait gaps — use judgment, prioritize by value

Every one of these already has a clear "why it's not done" comment in the code — read
that comment first, it's the actual technical constraint, not a placeholder:

- **Perfect Game** (`objects/augments/definitions.lua`) — the reward pool was never
  designed (flagged in `augments.md` itself, not just this codebase). This needs an
  actual small design pass (what permanent bonus, or short list of bonuses, does beating
  a blind by the exact chip requirement grant?) before it's implementable — do that
  design work yourself if no better answer is available, document the choice, then wire
  it the same way other pick-time augments work (`state.pending_augment_offer` pattern
  in `objects/augments/checkpoint.lua`, though this one triggers on a gameplay event, not
  a checkpoint — closer to a one-shot `TFT.open_picker` call from a new hook on
  `end_round()`'s exact-score-match case).
- **Deck Surgeon / Seal Artisan** (`objects/augments/definitions.lua`) — both need a
  real deck-browsing multi-select picker UI, which doesn't exist in this codebase yet.
  `ui/picker.lua`'s existing helper is single-row-select only (see how
  `objects/augments/checkpoint.lua` uses it) — extending it to a scrollable grid of ~52
  cards with toggle-select-N is real, novel UI work, not a small addition. Worth
  attempting given "prioritize by value" — these are two real, requested augments — but
  budget real time for it and don't let it block everything else.
- **Cosmic Alignment** — genuinely blocked without more infra: `poll_edition`'s real
  signature carries no rarity context at all (see `objects/augments/shop_effects.lua`'s
  closing note). The only way to make this work correctly is to find or add a rarity-
  aware call site further up the chain (wherever `poll_edition` gets CALLED for a
  specifically-Rare/Legendary shop roll, which may need chasing through
  `create_card`/`create_card_for_shop`'s own call sites to find a point where the
  rarity is already known before `poll_edition` fires). Reasonable to skip unless there's
  clear time for it.
- **Momentum Keeper** — also genuinely blocked: needs per-Joker special-casing to
  intercept "this Joker's own reset logic is about to fire" for specific named vanilla
  Jokers (Obelisk, Castle, etc.), which is exactly the "~150 bespoke upgrades" problem
  the whole Ranking system's design was built to avoid. Reasonable to skip.
- **Counterpunch / Iron Wall's outgoing-damage half / High Roller's credit-to-winner /
  Eye for an Eye's redirect** (`objects/actions/round_result.lua`'s closing note) — all
  need a new cross-client "impose an effect on my opponent" broadcast action. This is a
  bounded, well-understood addition (same `MPAPI.ActionType` pattern as every other
  action in `objects/actions/`) — worth doing as a batch once the life-total UI/
  elimination work above is done and fresh in mind, since it touches the exact same
  `round_result.lua` resolution code.

### 4. Ranked Joker visual treatment (border/glow per rank)

Confirmed wanted: a colored card border or glow scaling with Rank 1/2/3, matching the
colors already established in `objects/jokers/rank_display.lua`'s `RANK_COLOUR` table
(white/blue/gold). Real vanilla precedent to study and reuse rather than reinvent: how
Polychrome/Holographic/Foil editions apply their own card-level shader/border effect
(`Card:set_edition` in `card.lua`, and whatever draw-time shader logic reads
`self.edition`). Ideally implemented as something that layers alongside a real edition
(a Foil AND Rank-3 Joker should show both, not have one clobber the other) — check
`Card:get_edition()`/the render/draw path before assuming there's a single free "border
colour" slot to reuse. Add it in the same file (`objects/jokers/rank_display.lua`) or a
sibling, hooked off the same rank-change moments already established
(`objects/jokers/ranking.lua`'s `TFT.add_joker_copy`).

### 5. Thorough per-augment testing sweep

Lower priority than the above (not one of the two explicitly-named top priorities), but
real debt: the 73 augments from this session were verified as a group (all 73 active
simultaneously, no crash) and a handful were spot-checked individually (Ranking's
multiplier via a rigorous forced-hand test; a few PvP augments via a live 2-instance
round). Most were NOT individually verified for correctness. Worth a systematic pass —
one augment at a time, `state.augments_picked = {'key'}`, exercise its specific trigger
condition, verify the specific expected numeric/behavioral outcome — whenever there's
spare time between the higher-priority items above, especially for the ones with the
most room for a subtle field-name-style bug like the `mult_mod`/`Xmult_mod` one already
caught this session (anything touching `Card:calculate_joker`'s return table is the
highest-risk category: Fundamentals, Boom or Bust, Glass Cannon, Adrenaline, All or
Nothing).

---

## Open questions worth surfacing back to the user if this session can pause to ask,
## and defensible default answers to proceed with if it can't:

1. **Round timer / ready-up system**: does a real one need to be built now (shared
   countdown, advance-early on all-ready), or is a visual-only elapsed-time display
   sufficient for this pass? **Default if unasked: visual-only stopwatch**, since
   building the full ready-up sync is a bigger scope than "replace one HUD box" and
   wasn't itself named as a priority this round.
2. **What happens to an eliminated player's client** — solo continuation, a placement
   screen, spectate? **Default if unasked: a simple "You were eliminated — Placement #N"
   screen** (closest to TFT's own behavior, and the least likely to leave the player
   stuck in a confusing state).
3. **Match-end condition** — last player standing, or everyone finishes the sequence
   regardless of elimination? **Default if unasked: last player standing**, matching the
   TFT-style framing the whole mode is built around and this doc's own architecture
   notes.

Note every assumption actually made (not just these three) at the end of the work cycle,
per the standing instruction at the top of this file.
