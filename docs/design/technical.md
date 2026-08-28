# Technical Architecture

First draft, grounded in a real analysis of
[BalatroMultiplayerSpeedrun](https://github.com/Balatro-Multiplayer/BalatroMultiplayerSpeedrun) —
a shipped, working MPAPI-based gamemode mod that supports **more than 2 players**, which
is exactly the reference point we needed. Findings below are quoted/paraphrased from its
actual source, not guessed at.

## What the reference mod taught us

- **MPAPI has a real matchmaking layer**, not just the raw `create_lobby`/`join_lobby`
  primitives found earlier: `MPAPI.matchmaking.queue({mod_id, game_mode, min_players,
  max_players})` returns a handle with lifecycle events (`queued`, `match_found`,
  `lobby_ready`, `match_resolved`, `left`, `error`). Per-gamemode max player counts go up
  to **16** (`gamemode.max_players.public` / `.ranked`), so an 8-player lobby is
  comfortably within what the API already supports — we don't need to invent N-player
  lobby handling from scratch.
- **N-player comparison pattern, proven in production:** each client broadcasts its own
  result via a dedicated `MPAPI.ActionType` (their `spdrn_player_result`, `on_receive`
  keyed by `from_player_id`), every client collects incoming results into a local table
  keyed by player ID (`SPDRN._collected_results`), and **each client independently
  computes rankings/outcomes once all expected results have arrived** — no server-side
  authority needed, consistent with the deterministic-shared-seed architecture we already
  committed to. **This is the pattern we'll reuse for PvP round score comparison,
  Carousel draft order, and end-of-match placement.**
- **No clean win/loss callback exists in base Balatro.** The reference mod's own comment:
  *"Balatro has no single 'you lost' callback."* It works around this by hooking
  `Game:update(dt)` and polling every frame for `_check_run_lost()` and
  `_check_pending_run_transition()`. **We'll need the same polling approach** to detect
  blind-cleared/blind-failed/shop-entered transitions, rather than assuming a clean hook
  exists.
- **Version floors it actually ships with:** Steamodded `>=1.0.0~BETA-1221a`, Lovely
  `>=0.8`, Balatro `>=1.0.1o`, MultiplayerAPI (unconstrained). It also declares a
  `conflicts` entry against the base `Multiplayer` mod — expected, since both hook the
  same core game-mode surface (`win_game()`, the update loop) for mutually incompatible
  rulesets. **We should do the same**: declare a conflict with both `Multiplayer` and
  `MultiplayerSpeedrun`, since we're hooking the same surface for a third, incompatible
  ruleset.
- **File/folder pattern**, which we're adopting almost directly:
  - `domain/` — pure data/enum definitions, no MPAPI calls (their `gamemode.lua` is
    genuinely just a table of string constants).
  - `objects/actions/` — one file per `MPAPI.ActionType`, e.g. `player_ready.lua`,
    `player_result.lua`, `start_game.lua`, `forfeit.lua`.
  - `objects/matchmaking/` (their name) — queue/handle management, progress tracking,
    result collection.
  - `objects/gamemodes/` — one file per concrete ruleset variant.
  - `ui/` — UI builder functions registered into MPAPI's `main_menu_ui`/`lobby_ui` hooks.
  - `core.lua` — entry point: grabs `SMODS.current_mod`, a recursive dir-loader, calls
    `MPAPI.register_mod({...})` inside `MPAPI.on_loaded()`, then hooks `win_game()` and
    `Game:update(dt)`.

## Proposed file/folder layout for this mod

Adapted from the above, renamed for our domain:

```
BalatroTFT/
├── BalatroTFT.json          -- manifest (id, deps, conflicts — see below)
├── core.lua                 -- entry point, mirrors SPDRN's core.lua pattern
├── domain/                  -- pure data: enums, constant tables, no MPAPI calls
│   ├── stage_layout.lua     -- the 7-stage/33-round table from architecture.md
│   ├── rarity_odds.lua      -- Joker/Tarot/Spectral odds-by-level tables
│   ├── xp_curve.lua         -- the level cost table
│   └── banned_jokers.lua    -- Luchador/Mr. Bones/Chicot + future audit additions
├── objects/
│   ├── actions/             -- one MPAPI.ActionType per file
│   │   ├── round_result.lua     -- broadcast a player's score for the round just played
│   │   ├── xp_state.lua         -- broadcast level/XP changes
│   │   ├── augment_pick.lua     -- broadcast an augment choice
│   │   ├── carousel_pick.lua    -- broadcast a carousel draft pick
│   │   ├── player_eliminated.lua
│   │   └── match_complete.lua
│   ├── traits/               -- one file per Trait (breakpoint tables + calc hooks)
│   ├── augments/              -- one file per Augment, grouped by the 8 categories
│   ├── jokers/                 -- new custom Jokers (Suit Guild fillers, etc.)
│   └── round_flow/             -- stage/round state machine, PvP pairing computation
├── ui/                        -- lobby UI, HUD additions (XP bar, life totals, etc.)
└── localization/
```

## Round-flow & sync architecture (proposed)

Following the reference mod's proven pattern directly:

1. **Pairing is computed locally, not networked.** Since PvP pairing is deterministic
   (shared match seed + round number + the current list of alive players, which is
   already common knowledge from prior broadcasts), every client computes the *same*
   pairings independently — no round-trip needed just to determine who plays whom.
2. **Round outcomes use the broadcast-then-locally-compute pattern**, exactly like
   `spdrn_player_result`: after a player finishes their hand for a PvP or PvE round, they
   broadcast a `round_result` action (final score, hands/discards remaining, relevant
   trait/augment flags). Every client collects results into a table keyed by player ID.
   Once a client has both halves of its own pairing (its own result + its opponent's),
   it computes the damage/outcome locally using the formula from architecture.md.
3. **State detection is polling-based**, via a `Game:update(dt)` hook, checking each
   frame for blind-cleared/blind-failed/shop-entered/round-transition — matching the
   reference mod's documented workaround for Balatro having no clean win/loss callback.
4. **Desync/disagreement handling — resolved: host-authoritative reconciliation.** The
   lobby host's independently-computed state is treated as the source of truth; if a
   client's local computation disagrees with what the host broadcasts (e.g. it missed a
   `round_result` broadcast), it discards its own version and re-syncs from the host's.
   Simple, and consistent with how the reference mod already special-cases the host
   elsewhere (match start coordination, lobby metadata ownership).

## Matchmaking model — resolved: private lobby-code only

Joining a match is **invite-by-code only**, the same as the base `Multiplayer` duel mod —
no public matchmaking queue for v1. This means we build directly on the lower-level
`MPAPI.create_lobby()` / `MPAPI.join_lobby()` primitives rather than
`MPAPI.matchmaking.queue()`'s public/ranked queue system, though the queue system's
*patterns* (lifecycle events, handle-based state) are still worth mirroring in our own
lobby-handle design even without using the queue itself. A public queue mode is a
plausible future addition that this choice doesn't foreclose.

## Deferred — Spectral shop odds

Raised while researching the consumable-odds question and **explicitly parked, not
decided**: vanilla Balatro isn't strictly "Spectral never appears in shop slots" the way
technical.md's first draft assumed — there's an internal **Spectral shop weight rate**
that can be increased, which is exactly what the **Ghost Deck** starting deck does to
enable Spectral cards showing up in the shop at all. So "keep vanilla" vs. "add Spectral
to shop slots" isn't really a binary vanilla-vs-deviation question — it's a matter of
what that weight is set to, and Ghost Deck is the existing in-game reference point for a
non-zero value. **Per instruction, not touching this now** — noting the corrected
understanding here so whoever picks this up later doesn't have to rediscover it. Tier-1
checklist item "consumable category split by level" stays open, deferred rather than
blocking.

## Proposed Action List

One `MPAPI.ActionType` per file under `objects/actions/`, mirroring the reference mod's
granularity:

| Action | Broadcast when | Carries |
|---|---|---|
| `match_start` | Host starts the match | Shared seed, player count, config (stage layout, damage formula constants) |
| `round_result` | A player finishes their hand for a PvE/PvP round | Final score, hands/discards remaining |
| `xp_level_change` | A player's level changes | New level, current XP — mainly for other players' info augments (Open Book, Danger Sense) and the shared HUD, not needed for the damage formula itself since that's pure score-ratio now |
| `augment_pick` | A player locks in an augment choice | Which augment, which tier |
| `carousel_pick` | A player claims a Carousel item | Which item, so it's removed from everyone else's view of the pool |
| `life_total_change` | PvP/PvE damage resolves | New life total |
| `player_eliminated` | A player hits 0 life | Final placement number |
| `match_complete` | Last player standing (or Sudden Death resolves) | Full placement list |
| `ghost_snapshot` | A player finishes any round, for use if they become a ghost later | Board/score snapshot for the ghost-board mechanic |

Augment/Carousel **offers** (the 3 choices shown to a player) are deliberately **not**
broadcast — they're generated locally from a per-player-seeded RNG chain (match seed +
player ID + checkpoint number), so they're deterministic and reproducible without needing
network traffic for something only one player ever needs to see. Only the final **pick**
gets broadcast.

## Round/Stage State Machine

The open problem: Balatro hands take real, variable human time to play — unlike TFT's
auto-resolved combat. With up to 8 players, waiting for the single slowest player every
one of 33 rounds would blow way past the ~45-60 min match target and feels bad. But full
asynchrony (everyone on their own independent timeline) breaks almost everything already
designed — Carousel needs everyone present together, augment checkpoints are tied to
specific stage numbers, ghost boards assume "the round everyone just played" is a
coherent shared concept.

**Proposed resolution: a soft barrier with a host-timestamped timer**, not a hard wait
and not free-running asynchrony:

- The **host broadcasts a single `round_start` timestamp** when a round begins. Every
  client independently computes its own countdown from that shared timestamp — no
  continuous network chatter needed for the timer itself, consistent with the
  broadcast-once/compute-locally pattern used everywhere else.
- A round ends for the lobby when **either** all still-alive players have submitted a
  `round_result`, **or** the timer expires — whichever comes first.
- **A secondary "hurry up" timer** kicks in once ≥75% of alive players have already
  finished: the remaining stragglers get a shorter bonus window (proposed 20s) rather
  than the full base timer, so one slow player doesn't cost the whole lobby the maximum
  possible time on every single round, while a still bounding a worst case.
- If a player's timer runs out before they've finished, **their currently-banked score
  stands** (whatever hands they'd already played that round) rather than being auto-played
  or zeroed — least punishing option, and avoids needing to simulate "what would this
  player have done."
- The **host is responsible for detecting round-complete and broadcasting the
  advance-to-next-round signal** — a single clear trigger point, rather than every client
  independently guessing when to transition (which risked round-numbering desync).

**Per-round-type timer defaults** -- IMPLEMENTED 2026-08-28 (domain/round_timers.lua),
values confirmed as the real, shipped numbers (not just a first draft anymore):

| Round type | Base timer | Notes |
|---|---|---|
| PvE / PvP (hand-playing) | **45s at Stage 1, 65s at Stage 2, 90s from Stage 3 onward** | Real countdown, real enforcement: time running out forces the round to end right now via the same safe `end_round()` mechanism a real win/loss uses, banking whatever chips the player had scored so far (never auto-played or zeroed, per this section's own rule above) |
| Carousel | Own real per-turn timer, unchanged | Already implemented separately (objects/actions/carousel_draft.lua, `CAROUSEL_PRE_TIMER_SECONDS`/`CAROUSEL_TURN_TIMER_SECONDS`) as a host-authoritative shared-pool turn timer, not a per-player solo countdown -- materially different shape from the other rows here, so not unified with them. Now has a real live-ticking on-screen countdown too (previously static "Your turn!" text). |
| Shop | 60s | Force-leaves the shop the same way the real "Next Round" button does once time's up; a player can of course still leave earlier |
| Augment pick | 30s | Auto-picks the first offered option once time's up (checkpoint offers are per-player/local, so no host authority needed, unlike Carousel's shared pool) |

**Scope reduction versus the original proposal above, flagged explicitly**: the
host-broadcast shared `round_start` timestamp / lobby-wide soft-barrier design described
earlier in this section was NOT implemented -- it depends on a real, shared,
host-authoritative notion of "which round is everyone on right now," which this
project's actual round-flow architecture doesn't have (every client advances its own
`state.round_index` independently the instant THEY personally clear their own blind --
this was true before the timer work and remains true now; PvP pairing has always just
assumed players roughly keep pace). What's implemented instead: each client runs its
own honest, real countdown against its own current round/shop/checkpoint, using the
budgets above, with real enforcement. The secondary "hurry-up" window (a shorter bonus
timer once ≥75% of the alive lobby has already finished) is NOT implemented for the
same reason -- it needs a shared "who else has finished THIS round" signal that doesn't
exist. Building the full host-authoritative round-advance barrier this table originally
envisioned is a materially larger architectural change than "add a timer" and would be
a good candidate for its own dedicated session.

## Trait & Augment Calculation Hooks

How Traits (breakpoint bonuses) and Augments (permanent run-modifiers) actually plug into
SMODS's `calculate_context` scoring pipeline, given neither is a real Joker that occupies
a slot.

**Proposed pattern: invisible "system" pseudo-Jokers** — a well-worn pattern in the
Balatro modding space for always-active passive logic that shouldn't consume a slot,
appear in shop, or be sellable. Concretely:

- **One hidden "Traits Engine" pseudo-Joker per player**, always present, invisible,
  slot-free. Its `calculate()` runs on every relevant context tick and applies whatever
  bonuses the player's *current* trait breakpoints entitle them to. One centralized
  object rather than ten separate hook registrations, since trait logic is fairly
  uniform/tabular (check breakpoint, apply effect) and benefits from being in one place.
- **One hidden pseudo-Joker per picked Augment** (so up to 3 per player, created at pick
  time), rather than folding all ~50 augments into the same engine. Augment effects are
  much more bespoke/varied than trait effects, so keeping each one as its own small,
  independently testable module seemed better than one large conditional block.
- **Trait membership** is data, not per-Joker logic: each Joker we tag with a Trait
  carries it as a plain field (e.g. `trait_tags = {"Financiers"}`) in its definition,
  and a single lookup table maps Joker key → tags. Vanilla Jokers we're tagging get
  patched into this table; new custom Jokers declare it directly.
- **Trait counts are cached, not recomputed every scoring event** — recalculated only
  when the Joker collection actually changes (bought/sold/created), via whatever
  add/remove hooks SMODS exposes for that, rather than re-scanning `G.jokers.cards` on
  every single card score. Scoring-time reads are just a cached table lookup.

This is a specific implementation choice, not a game-design fork — flagging it clearly
rather than asking about it, since I don't think it's the kind of thing that needs a
product decision, but correct me if you'd rather see the alternative (many individual
small hook registrations instead of centralized pseudo-Jokers).

**Confirmed — going with this pattern.**

## Player State Schema

Splitting what's genuinely global match state (one copy, host-broadcast) from what's
per-player (each player owns and broadcasts their own):

**Global match state** (host-broadcast, via `match_start` and the round-advance signal):
`match_seed`, `current_stage`, `current_round`, `round_type`, `round_start_timestamp`,
`alive_player_ids`. Notably **not** included: PvP pairings — those are still computed
locally and identically by every client from the above, per the earlier decision, so
broadcasting them would be redundant.

**Per-player state** (each player broadcasts their own via the action list above):
`level`, `current_xp`, `life_total`, `alive` / `eliminated_at_placement`, a **cached**
`traits_owned` summary (trait name → count, not the raw Joker list — cheaper for other
players' info augments like Open Book/Danger Sense to consume), `augments_picked` (up to
3 keys), and a `ghost_snapshot` (this player's most recent board/score, kept fresh every
round in case they're needed as a ghost for an odd-lobby pairing).

**Explicitly NOT synced:** shop contents/rolls, augment/Carousel *offers* before they're
picked — private to the player who's looking at them, per the earlier decision.

## Host Disconnect / Migration

MPAPI already handles host-role migration automatically (2-minute disconnect grace
period, automatic role transfer, from the earlier research). Because `round_start`
timestamps and round-advance signals are broadcast to **every** client rather than kept
host-private, and because every client is already independently building the same
`_collected_results`-style table per the broadcast-then-locally-compute pattern, a
mid-round host disconnect doesn't require restarting the round: whichever client MPAPI
promotes next simply resumes round-advance responsibility using data every client already
had. The only new responsibility it picks up is detecting round-complete and broadcasting
the advance signal from that point forward — nothing needs to be reconstructed.

## Single-Player Fallback (technical)

A single branch point at the top of the round-flow controller, not scattered
conditionals throughout: if there's no active lobby (solo play), the controller reads the
same `stage_layout` domain table but swaps every `PvP` round type to `PvE` before
anything else runs, skips MPAPI entirely (no actions, no host-authority/timer logic —
nothing to reconcile with), and Carousel resolves as an instant free pick. Everything
downstream (shop, leveling, augments, traits) runs completely unaware it's in
single-player mode, since it only ever sees the already-substituted round type.

## Version targeting (proposed)

Matching the reference mod's floors as sane, already-proven defaults: Steamodded
`>=1.0.0`, Lovely `>=0.8`, Balatro `>=1.0.1o`, MultiplayerAPI (latest, unconstrained
unless we hit a specific compatibility issue). **Conflicts** declared against `Multiplayer`
and `MultiplayerSpeedrun` (and any other Balatro-Multiplayer gamemode mod that hooks
`win_game()`/the core update loop), since we're doing the same for an incompatible ruleset.
