# 4-player and 8-player playability test plan

Written 2026-08-27. Covers next-session-plan-4.md's deferred "What's left" items (the
4/8-instance Carousel draft load test, the 8-player lobby screenshot) plus a broader
smoke-test of core systems that, so far, this whole project has only ever verified at
N=2 — several mechanics (round-robin PvP pairing rotation, the Carousel pool actually
being exhausted, ghost-board odd-lobby handling) are structurally untested above 2 real
players despite being designed for up to 8. This is a **smoke test**, not a full 33-round
playthrough — each system gets exercised once per phase, not played to completion.

Read [claudecontrol-guide.md](claudecontrol-guide.md) before starting — it's the control
reference this whole plan is built on (entry points, gotchas, the multi-instance launch
recipe). This plan assumes that guide's recipe for launching N instances.

## Real risk to flag up front, not discover mid-test

**8 simultaneous Balatro processes on this machine has never been attempted** — every
prior test this project ran topped out at 2. If performance/stability degrades badly at
8 (or even 4), don't force it: report the actual finding (e.g. "6 instances is the
practical ceiling on this hardware, here's what broke at 7") rather than declaring the
test done at a smaller count without saying so. This is itself useful information for the
design doc's own "player count 2-8 configurable" claim.

## Phase 0 — Launch and lobby formation

1. Launch 4 instances (`BMP_IMPERSONATE_NAME=Player001..004`), ports 34343-34346, using
   the guide's PowerShell retry-loop recipe (not `cctl launch`, confirmed unreliable on
   this machine).
2. Host (`Player001`) creates a lobby (`MPAPI.create_lobby(TFT.id, {max_players=8})`);
   the other 3 join by code via `MPAPI.join_lobby`.
3. Confirm via `eval` (not a screenshot) that the host's `lobby._players` has exactly 4
   entries before proceeding.
4. **This is where the one legitimate screenshot of this whole plan's 4-player phase
   goes**, if wanted: the lobby UI showing all 4 real players' joker-icon rows. Otherwise
   skip straight to starting — the 8-player phase's screenshot (explicitly requested
   earlier) is the one that actually matters to capture.
5. Start the game (`press tft_start_game` on host, or set a couple of `TFT.LobbySettings`
   first to also re-confirm Item 5's settings sync at N=4 while here). Confirm
   `TFT.is_run_active()` and `state.is_multiplayer` true on all 4 clients.

## Phase 1 — Real N=4 PvP pairing (never verified above N=2 before)

`domain/pvp_pairing.lua`'s round-robin was unit-tested with a synthetic 4-id list
(`next-session-plan-3.md`), but never exercised through a **real 4-client PvP round** —
every live PvP test this project has run used exactly 2 real instances. This phase closes
that gap:

1. Advance (or force `state.round_index`) to the first real PvP round.
2. Confirm all 4 clients compute the *same* pairing independently
   (`state.current_pairing`) — should be 2 real pairs, no ghost (4 is even).
3. Force distinct scores per client (`state.life_total`/synthetic round results, same
   forced-input technique used throughout this project) and confirm each pair's win/loss
   resolves correctly and independently of the other pair.
4. Advance to a **second** PvP round and confirm the pairing actually rotates (the whole
   point of round-robin) — same 4 ids, different pairing than round 1.

## Phase 2 — Carousel draft at N=4 (the explicitly deferred item)

1. Force differing life totals across the 4 clients so turn order is meaningful, then
   trigger the Carousel draft for real (`TFT.open_carousel(round_def)` on the host, or
   real play if a Carousel round is naturally next).
2. Confirm the pool broadcasts identically to all 4 (`#carousel_draft.pool == 8`).
3. Confirm turn order is ascending by life across all 4 real ids (not just 2).
4. Exercise **both** a real manual pick (immediate resolution) and a real timeout
   auto-pick within the same draft, across different turns — confirm each of the 4 lands
   on the correct client's own board only.
5. With 4 alive players drafting from an 8-slot pool, exactly 4 of 8 pairs get claimed —
   confirm the other 4 stay `taken_by = nil` and the draft still finishes/advances the
   round correctly once turn 4 completes (`turn_index=5 > #turn_order=4`).

## Phase 3 — Scale to 8 instances

1. Launch 4 more instances (`Player005..008`) — or restart clean with all 8 from the
   start if Phase 0-2 left state messy. Join the SAME or a fresh lobby so
   `lobby._players` has 8 real entries.
2. **The actual requested deliverable**: `cctl shot` of the lobby screen with all 8 real
   players' joker-icon rows visible (Item 5's own "I like the way the lobby currently
   looks... verify with a screenshot" ask). Confirm via `eval` first that all 8 are
   really present before spending the screenshot on it.
3. Start the game, confirm `is_run_active`/`is_multiplayer` true on all 8.
4. Repeat Phase 1's PvP pairing check at N=8 (4 real pairs, no ghost — 8 is even).
5. Repeat Phase 2's Carousel draft check at N=8 — this is the real stress case that's
   fundamentally different from N=4: with 8 alive players drafting from an 8-slot pool,
   **every single pair gets claimed** — the first time this project will have exercised
   the pool-exhaustion path (`remaining` list hitting empty in
   `host_check_carousel_turn_timeout`, and the natural `turn_index=9 > #turn_order=8`
   finish path) rather than always finishing with slots left over.
6. **Ghost-board check (genuinely new — not verified live at any real odd player count
   this project)**: force one of the 8 to elimination (`state.eliminated`/broadcast a
   `tft_life_total_change` with `eliminated=true` for one id) to bring the alive count to
   7 (odd), then confirm `TFT.compute_pvp_pairing` on a live 7-player alive-id set
   actually produces a ghost for the next PvP round, and that the ghosted player's client
   gets a real ghost-board snapshot to play against rather than erroring or hanging.
7. Force a full run-down to 1 remaining player (however fast is reasonable — direct
   elimination broadcasts for 6 of the 8, not real played-out rounds) and confirm the
   real victory screen fires for the survivor and a real placement screen fires for each
   eliminated player, at this larger field size.

## What "done" looks like

- A clear pass/fail (with real `eval`-sourced evidence, not just "looked fine") for each
  numbered check above.
- The one 8-player lobby screenshot, sent to the user.
- An honest note on the actual practical instance-count ceiling this hardware handled,
  even if it's below 8.
- Any new bug found gets the same treatment as every other bug this project has hit:
  fixed live if the fix is bounded and quick, or documented with full repro + root-cause
  reasoning and deliberately left alone if it's a bigger, riskier change — never silently
  patched over or ignored.

## Cleanup

Close every instance (`Get-Process Balatro | Stop-Process -Force`) before ending the
session, per the standing rule in this project's own `CLAUDE.md`.

## Results (run 2026-08-27)

Executed in full, all 8 real instances (never attempted before on this machine).
**No instance-count ceiling found** — both the 4-instance and 8-instance launches
succeeded on the first `Start-Process` retry-loop attempt, no crashes, no degraded
behavior observed at 8. All checks below are real `eval`-sourced evidence from live
instances, not inference.

**Phase 0 (N=4 launch/lobby):** PASS. 4 instances up, `lobby._players` = 4 confirmed via
eval, `is_run_active`/`is_multiplayer` true on all 4 after `tft_start_game`.

**Phase 1 (N=4 PvP pairing):** PASS, previously untested above N=2.
- Round 1 pairing: 2 real pairs, no ghost, byte-identical across all 4 clients.
- Forced distinct scores (900/300 and 200/950) → both pairs resolved correctly and
  independently: winners stayed at 100 life, losers took real damage (92.6/91.6).
- Round 2 pairing rotated correctly (same 4 ids, different pairing), identical across
  all 4 clients.

**Phase 2 (N=4 Carousel draft):** PASS, the explicitly deferred item.
- Pool broadcast identically to all 4 (8 slots).
- Turn order confirmed ascending-by-life across all 4 real ids (forced 80/60/40/20 life
  → turn order 20→40→60→80, exact match).
- Both a real manual pick (immediate resolution, verified via instant turn advance) and
  real timeout auto-picks exercised **within the same draft** (turn 1 manual, turns 2-4
  timed out for real at the widened 25s test window).
- Draft #1 (all-timeout) and draft #2 (mixed) both correctly claimed exactly 4 of 8 pool
  pairs and advanced `round_index` identically on all 4 clients afterward.

**Phase 3 (N=8):** PASS overall, with two real findings below.
- 8-player lobby confirmed via eval (`lobby._players` = 8) before spending the
  screenshot — sent to the user separately.
- `is_run_active`/`is_multiplayer` true on all 8 after start.
- N=8 PvP pairing: 4 real pairs, no ghost, identical across all 8 clients.
- N=8 Carousel draft: **pool-exhaustion path exercised for the first time** — all 8
  pool slots claimed (one per client), draft finished and `round_index` advanced
  identically on all 8 (`turn_index=9 > 8` finish path taken, `remaining` list hit
  empty in the timeout-watchdog path without error).
- Ghost-board pairing at N=7 alive (forced 1 of 8 to elimination): pairing computation
  itself is correct — 3 real pairs + 1 ghost, identical across all 8 clients, and the
  ghosted client's own round-result broadcast is a safe no-op (no crash/hang, life
  total unaffected). **But see Finding 2 below** — the actual ghost-board *snapshot*
  mechanic the design doc promises is not implemented.
- Forced run-down from 8 to 1 (6 direct elimination broadcasts): placements assigned
  correctly and sequentially (8,7,6,5,4,3,2, no gaps/dupes) purely from
  `TFT.count_alive_players()` at each step; the sole survivor's client correctly
  detected itself as last-one-standing and set `match_won=true`. Real victory/placement
  overlay screens confirmed rendering with correct text (`"Victory!" / "Last one
  standing"` and `"Eliminated" / "Placement #2"`) once actually invoked — see the
  methodology note below.

### Finding 1 (real bug, confirmed reproducible on 2 independent instances): lobby UI overlap at N≥5

At 5-8 players the roster grid (`MPAPI.create_lobby_ui`) wraps to 2 rows. BalatroTFT's
own `TFT.build_in_lobby_ui` (`ui/lobby.lua:116-162`) stacks the grid row and the Match
Settings panel as plain sibling rows in a single `align='cm'` vertical list with no
scroll container. At 2 grid rows the stack is taller than whatever height the grid
reports to the layout engine for a single row, so the Match Settings panel visually
overlaps the grid's second row instead of sitting cleanly below it. Confirmed on both
the host (after cleanup from an unrelated test artifact) and a completely untouched
guest instance — same overlap both times, so this is a real bug at real player counts,
not a one-off testing artifact. This mechanism has never been exercised above N=4
before (where the grid still fits in 1 row) so this is the first time it's surfaced.
Root cause is most likely in how `MPAPI._new_card_grid`'s built element reports its own
height for 2+ rows back to BalatroTFT's layout code, not something to improvise a fix
for mid-test — left alone per this project's "document and leave alone for bigger,
riskier changes" convention. Does not affect game state/logic at all (every functional
check above passed); purely a lobby-screen cosmetic issue.

### Finding 2 (real gap, not a crash): ghost-board "snapshot" mechanic was never actually built

`architecture.md`'s own PvP Pairing section promises: "Odd-numbered-alive lobbies give
the unpaired player a **ghost board** (a snapshot of another player's board/score)."
`domain/pvp_pairing.lua`'s own header comment matches this intent exactly. But the only
code that consumes the ghost result (`objects/round_flow/pvp.lua`'s
`setup_pvp_pairing_if_needed`, and `objects/actions/round_result.lua`'s
`on_receive`) does nothing beyond logging a debug message and returning early
("we're the ghost this round, nothing to resolve") — there's no snapshot object, no
opponent score assigned, no damage dealt or received for the ghosted player that round.
Confirmed live: the ghosted client's life total was untouched (100 → 100) after
broadcasting its own round result, and no error/hang occurred, but this is "safely does
nothing" rather than "plays against a real snapshot opponent" as designed. This gap was
structurally impossible to notice before this session since every prior live test used
only 2 real instances (always even, never triggering a ghost round at all). Flagging as
a real, scoped feature gap for a future session — implementing an actual board/score
snapshot (whose board? from which round? does it get frozen at pairing time or picked
retroactively?) is a real design decision, not a quick fix, so deliberately left alone
here rather than improvised.

### Methodology note (not a game bug)

The first elimination-screen check for a non-winning player came back empty — traced to
the test's own shortcut: eliminating a player via direct `state.eliminated`/
`life_total`/`broadcast_life_total_change` field-setting (to move fast through 6
eliminations) replicates everything `TFT.apply_life_loss` does **except** its final
`TFT.show_elimination_screen(state.placement)` call, which only a real PvP-loss path
would trigger. Confirmed by invoking `TFT.show_elimination_screen` directly afterward —
real "Eliminated" / "Placement #2" overlay text rendered correctly. Recorded here so a
future session doesn't mistake this specific shortcut for a real screen-not-showing bug.
