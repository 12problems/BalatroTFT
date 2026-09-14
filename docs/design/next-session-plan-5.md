# Session 2026-08-28 — bug-pass fixes + full round timer

Scope: the 4 findings from `4-8-player-test-plan.md`'s Results section (renumbered
1-4 below), plus building out real round/shop/checkpoint timer functionality per
`technical.md`'s own "Round/Stage State Machine" design (previously cosmetic-only).

## 1. Lobby UI overlap at 5+ players — FIXED, verified live

[ui/lobby.lua](../../ui/lobby.lua)'s `TFT.build_in_lobby_ui`/`build_settings_panel`.
Root cause: at 5-8 players the roster grid wraps to 2 real rows (MPAPI's own
`COLS=4` card grid), and the original layout stacked title/code/grid/settings/button
as 5 full-width rows that together exceeded `G.ROOM.T.h` (11.5 units, confirmed live).
Fixed by merging the title+code into one row, tightening every TFT-added row's own
padding/scale, and putting the settings panel and the start/waiting row side by side
as columns instead of two more stacked rows. Verified live at a real 8-player lobby
(7 fake injected players + 1 real, since the MPAPI card grid only reads
`lobby._players`): title fully on-screen, no overlap between the grid and the panel.
A separate, pre-existing cosmetic quirk (a rotating background deck-preview card
bleeding through main-menu-built content) is visible in the same screenshots but is a
vanilla main-menu decoration unrelated to this fix, not something touched.

## 2. Ghost-board snapshot mechanic — FIXED, verified live

architecture.md promises a ghosted player (odd alive-count PvP round) plays against
"a snapshot of another player's board/score" — the actual code only ever logged a
debug message and skipped resolution entirely. Implemented:
- [domain/pvp_pairing.lua](../../domain/pvp_pairing.lua): `TFT.compute_pvp_pairing`
  now also returns `ghost_opponent_snapshot_of` — deterministically the circle
  method's own "fixed" anchor player among the remaining (non-ghost) alive ids, so
  every client picks the same one with no extra broadcast.
- [objects/round_flow/poll.lua](../../objects/round_flow/poll.lua): every player now
  broadcasts a `tft_ghost_snapshot` (their own latest score) at the end of every real
  scored round (PvE or PvP, not Carousel), collected into `TFT._ghost_snapshots`.
- [objects/actions/round_result.lua](../../objects/actions/round_result.lua): the
  win/loss logic was extracted into a shared `TFT.resolve_pvp_outcome` function, now
  called both by the normal two-real-players path AND a new ghost path (fires on the
  ghost's own broadcast looping back to them) that resolves against
  `TFT._ghost_snapshots[snapshot_of]` (falling back to the ghost's own score — a
  no-damage tie — if no snapshot exists yet).
- ASSUMPTION (flagged): a snapshot carries only a raw score, no augment flags — so
  Counterpunch/Iron Wall/High Roller/Eye for an Eye never trigger FROM a snapshot
  opponent (the ghost's OWN augments still apply normally, since those are read via
  `TFT.has_augment` inside `resolve_pvp_outcome`, not from `opp_aug`).

Verified live (real 3-instance lobby): forced a real odd-alive-count PvP round,
confirmed all 3 clients computed the identical ghost + snapshot-source assignment,
then had the ghost broadcast a losing score against the snapshot — real damage was
applied (100 → 93.5 life), and the other two clients were confirmed unaffected.

## 3. Double Pack — FIXED and re-enabled (closed 2026-09-01)

[objects/augments/shop_effects.lua](../../objects/augments/shop_effects.lua)'s
`Card:open` hook — full blow-by-blow is in that file's own comments. Six real bugs
were found and fixed live across two passes:
- **Bug #3**: `SMODS.Booster.update_pack` (the real per-frame pack-UI builder) is
  gated on `G.STATE_COMPLETE`, which something races back to `true` before it can
  re-fire for the second pack. Fixed by re-asserting `G.STATE_COMPLETE = false`
  defensively right after triggering the second pack.
- **Bug #4**: triggering the second pack's `G.FUNCS.use_card` call from inside ANY
  `G.E_MANAGER:add_event` callback (tried both `immediate` and `after` triggers)
  reproducibly hung the whole game solid. Fixed by hooking `Game:update` directly
  instead (same pattern MultiplayerAPI's own focus.lua uses), so the second open call
  starts a clean top-level call stack rather than nesting inside an event callback
  already in progress.
- **Bug #5** (flagged by the user watching the test live): the first pack's own
  physical card object was left behind as a real, visible, mid-dissolve leftover.
  Fixed by force-removing it explicitly before opening the second pack.
- **Bug #6, FIXED 2026-09-01** (also flagged by the user watching the test live):
  with #1-#5 fixed, the two packs' contents ended up MERGED into one 6-card choice
  instead of two separate 3-card ones. Root cause: the first pack's own delayed
  card-creation chain — scheduled back when it was first opened, entirely
  independent of anything this file does — isn't cancelled by bug #5's force-remove
  (removing the card object doesn't cancel its already-queued events), and if it
  fires AFTER bug #3's fix has already rebuilt `G.pack_cards` for the second pack,
  both packs' cards land in the same CardArea. Fixed by requiring real elapsed time
  since the FIRST pack's own open() call (not just since it visually closed via
  `G.booster_pack` going nil) to be comfortably past that pack's own full
  open-to-populate window (`0.4 + 1.3·√GAMESPEED + TFT.DOUBLE_PACK_SAFE_MARGIN_SECONDS`)
  before ever triggering the second pack's open — guarantees pack 1's own delayed
  chain has already landed its cards in pack 1's own (still-valid) CardArea first.
  Verified live with the worst-case timing (skipping pack 1 as fast as possible,
  the exact scenario that used to trigger the merge): pack 2 correctly showed
  exactly 3 cards, no hang, no `G.STATE` corruption, picking from it correctly
  returned to the shop, and a screenshot confirmed no leftover visual artifacts.
  `should_double` is back to its real condition — the augment is live again.

## 4. Carousel draft live countdown — FIXED

[ui/picker.lua](../../ui/picker.lua)'s `TFT.build_picker_node_tree` gained a
`timer_ref` option (a live DynaText binding, same pattern the persistent HUD timer
already used) — [objects/actions/carousel_draft.lua](../../objects/actions/carousel_draft.lua)
now shows a real ticking countdown during a player's turn instead of static
"Your turn!" text, reading `TFT.carousel_timer_text` (refreshed every frame in
`TFT.update_hud_display_texts`, hud.lua) against the draft's own existing
`turn_started_at`/`CAROUSEL_TURN_TIMER_SECONDS`. No change to the underlying
(already-real, already-tested) turn-timeout enforcement.

## 5. Full round/shop/checkpoint timer — IMPLEMENTED, core mechanism verified live

New [domain/round_timers.lua](../../domain/round_timers.lua) holds the real budgets
(45/65/90s by stage for PvE/PvP hand-playing rounds, 60s shop, 30s Augment
Checkpoint — see technical.md's own table, now marked implemented). Previously the
on-screen "timer" was purely a cosmetic elapsed-time stopwatch with zero gameplay
effect (hud.lua's own long-standing note). Now, for real multiplayer matches:

- **Hand-playing rounds** ([hud.lua](../../objects/round_flow/hud.lua),
  [poll.lua](../../objects/round_flow/poll.lua)): a real countdown; hitting zero
  while actually in a blind (`G.GAME.blind.in_blind`) force-ends the round right now
  via the same safe `end_round()` mechanism a real win/loss already uses — the
  player's true banked score is exactly what gets broadcast as their result, "never
  auto-played or zeroed" per the design doc's own rule, for free. **Real,
  significant consequence worth knowing**: for a PvE round specifically, forcing
  `end_round()` with insufficient chips triggers the exact same real, permanent
  game-over a normal "ran out of hands" miss would (this mod's own PvP-loss-only
  damage model only suppresses that outcome for PvP rounds, per hooks.lua's existing
  `end_round` hook) — confirmed live (accidentally, mid-test): a Stage-1 PvE round
  timing out with 0 banked chips ended the run for real. This is consistent with
  the mod's own pre-existing PvE win/loss rules (the timer just adds a new way to
  reach the same "missed the target" outcome that could already happen), not a new
  risk invented by the timer, but the 45s Stage-1 budget is worth real playtesting
  given how punishing a miss already is.
- **Shop**: a real 60s countdown; hitting zero calls the same `G.FUNCS.toggle_shop`
  a real "Next Round" click does.
- **Augment Checkpoint** ([checkpoint.lua](../../objects/augments/checkpoint.lua)):
  a real 30s countdown with a live on-screen ticker (via #4's `timer_ref`
  mechanism); hitting zero auto-picks the first offered option (checkpoint offers
  are per-player/local, so no host authority or broadcast is needed here, unlike
  Carousel's shared draft pool).
- All of the above are gated to real multiplayer matches (`state.is_multiplayer`)
  and respect the existing lobby "Round Timer" on/off setting, matching this
  project's existing scope for that toggle.

**Scope reduction versus technical.md's original proposal, flagged explicitly** (see
that doc's own updated section for the full explanation): this is a real, honestly
enforced PER-CLIENT countdown, not the lobby-wide host-broadcast synchronized soft
barrier the design doc originally sketched (that would need real host-authoritative
round-advance sync, which this project's round-flow architecture doesn't have and
wasn't attempted this pass) — and the secondary "hurry-up" window once ≥75% of the
lobby has finished is not implemented, for the same reason.

**Verified live** (real 2-instance multiplayer): a real PvP round's timer, shortened
for the test, was allowed to expire while the player had only 50 of 1000 required
chips banked — confirmed the round was force-ended, the run correctly did NOT
game-over (PvP suppression working), `round_index` correctly advanced, and the
broadcast round result correctly carried the banked 50-chip score. Code-reviewed but
not independently live-verified this same pass: the shop and checkpoint timers (same
enforcement pattern, lower complexity — no PvP suppression edge case, no banked-score
semantics) — a stray screen-corruption artifact from the test session's own
too-rapid back-to-back state manipulation (confirmed by the user watching the
instance) interrupted that specific follow-up check before it completed; recommend a
clean, unhurried re-verification pass before considering it fully closed.

## What's left

1. ~~Double Pack bug #6~~ — FIXED 2026-09-01, see above.
2. Shop/checkpoint timer: code-reviewed, not independently re-verified live after the
   test session's own screen-corruption interruption (see above).
3. The hurry-up window and full host-broadcast round-sync barrier remain
   unimplemented by design-scope decision, not oversight — see both scope-reduction
   notes above. A real host-authoritative round-advance system would be a good
   candidate for a dedicated future session in its own right, not a quick add-on.
4. As always: nothing in this session is committed to git.

## Addendum, 2026-08-30: mod deployment no longer uses junctions

Unrelated to the fixes above, but a real standing project rule as of this date: mods
are no longer junctioned into the real `%AppData%\Roaming\Balatro\Mods` (a junction
there has silently wiped the real source checkout before, and a third-party mod
manager on this machine actively cycles that same folder). Deployment now uses real
per-instance copies under `dev-mods\inst<N>\`, launched via lovely-injector's own
`LOVELY_MOD_DIR` env var. See `CLAUDE.md` and `claudecontrol-guide.md`'s own
"Multi-instance launch" section for the full recipe, and
`W:\Stuff\Programming\Balatro\BMPGithub\deploy-dev-mods.ps1` — **run this after every
code edit, before relaunching**, since there's no junction anymore to make edits take
effect automatically.
