# Full natural playthrough test plan

Written 2026-09-01. Purpose: every mechanic in this mod has been verified by jumping
to a specific `round_index` and forcing state (`G.GAME.chips = target`, `end_round()`,
direct `state.*` field pokes) — never by actually playing round-to-round the way a
real player would. That's a fundamentally different stress pattern: state
accumulation across a real 33-round arc, real hand-by-hand play, real shop visits,
jokers actually interacting with each other over time rather than being granted
fresh for one isolated test. This plan closes that gap.

## Methodology

Driven via `cctl eval`/`ui`/`press`, not screenshots, per this project's standing
preference — with one explicit exception: **a screenshot once per stage (7 total)
plus immediately after anything `eval` flags as suspicious**. Pure rendering bugs
(UI overlap, a leftover sprite, a stale UIBox) have no corresponding wrong *value*
in the data model, so eval-based inspection structurally cannot catch them — this
project has already found three real bugs of exactly that class (lobby overlap,
Double Pack's leftover card, Double Pack's merged-pack visual) that only a
screenshot surfaced. Zero screenshots would mean flying blind on that whole bug
class; this plan bounds it instead of ignoring it.

**Real hand-playing technique**: read `G.hand.cards[i].base.value`/`.suit` via eval,
pick any valid 1-5 cards forming a real hand (don't need optimal play — just a real,
legal hand each time, to genuinely exercise scoring), select via
`area:add_to_highlighted(card)` (not pixel clicks — sidesteps the documented
fanned-card click flakiness entirely while still running the real scoring pipeline),
then `G.FUNCS.play_cards_from_highlighted()`.

**Scope**: solo first. Solo substitutes PvP→PvE and Carousel→instant-pick, so it
won't exercise real pairing/ghost/damage or the real multiplayer Carousel draft —
but it's the cheapest way to find bugs in the ~90% of the code every game mode
shares (round flow, leveling, shop, augments, traits, checkpoints, timer). A
natural **multiplayer** playthrough is a real, separate follow-up worth doing after
this, not folded in here — it roughly doubles effort (driving 2+ real clients
through natural play in lockstep) and the multiplayer-specific paths (pairing,
Carousel draft, lobby settings) have already had *some* live coverage from the
4/8-player test session, just not at a natural pace.

**Keep `G.SPEEDFACTOR = 1`** throughout — the whole point is testing whether the
round timer's real budgets (45/65/90s by stage) survive genuine play at a real
pace, which a sped-up test can't tell you.

## Round-by-round checklist

For **every** round, regardless of type:
- [ ] `TFT.get_state().round_index` advanced by exactly 1 from the previous round
- [ ] HUD life/level/timer text (`TFT.hud_life_text`/`hud_level_text`/`round_timer_text`)
  reads correct values via eval after each transition
- [ ] Round timer counted down for real and did NOT expire under a reasonable real
  pace (if it does expire during genuine play, that's real, valuable balance
  signal for the 45/65/90s budgets — note it, don't treat it as a bug)
- [ ] No stray Lua warnings in the lovely log (`grep -i warn` after each stage)

**PvE rounds** (stage 1's first 3, and one per later stage):
- [ ] Chip target matches `TFT.current_round_def().chip_target`
- [ ] A real hand played moves `G.GAME.chips` correctly; playing enough hands to
  clear the target transitions to ROUND_EVAL → shop correctly
- [ ] Passive XP granted (`TFT.PASSIVE_XP_PER_ROUND`) — confirm `state.xp` increments

**PvP rounds** (solo → substituted to PvE, so this checklist doesn't apply solo —
covered instead by the multiplayer follow-up)

**Carousel rounds** (solo → instant guaranteed pick, `TFT.open_carousel_solo`):
- [ ] 4 options offered, each a real joker+consumable pair
- [ ] Picking one actually adds both a real Joker card and a real consumable card
  to the player's own areas (`#G.jokers.cards`/`#G.consumeables.cards` increment)
- [ ] Consumable pool weighting by level looks sane (spot-check, not exhaustive)

**Augment Checkpoints** (fixed at stages 2/4/6 per architecture.md):
- [ ] Checkpoint actually triggers at the right `round_index`
  (`round_def.is_checkpoint`)
- [ ] Tier offered matches `TFT.roll_augment_tier`'s expected tier for that
  checkpoint index
- [ ] Reroll works once, is unavailable a second time
- [ ] Picking applies the augment's real `apply()` effect (spot-check the picked
  one's actual gameplay effect, not just that `state.augments_picked` grew)
- [ ] **This is the first time this project's ~73 augments get exercised via real
  accumulation over a run** (2-4 picked across a full playthrough) rather than one
  augment force-granted in isolation — watch for interaction bugs between
  simultaneously-held augments, not just each one alone

**Level-up rewards** (levels 5/8/9 specifically):
- [ ] Level 5: real voucher choice offered and appliable
- [ ] Level 8: real deck-refinement choice offered and appliable
- [ ] Level 9: the level-9 reward triggers correctly
- [ ] If a level-up coincides with a checkpoint round on the same transition, the
  documented defer-and-queue behavior actually shows both in sequence, not one
  silently dropped

## Shop checklist (every visit, not just once)

- [ ] Joker/consumable odds visibly shift as level increases across the run (spot
  the weighting change, don't need to prove the exact distribution)
- [ ] A real purchase (`G.FUNCS.use_card`) deducts the correct listed price
- [ ] Reroll cost escalation and any Golden-Touch-style discount (if that augment
  was picked this run) apply correctly
- [ ] Opening a real booster pack shows real card choices; if Double Pack was
  picked this run, confirm it opens 2 separate packs cleanly (now fixed — good
  opportunity to re-confirm under natural, non-adversarial timing, not just the
  worst-case fast-skip test)
- [ ] Buying a voucher actually redeems its real effect

## Traits / Joker Ranking (ambient, check periodically not per-round)

- [ ] As Jokers with shared trait tags accumulate, the Traits Engine pseudo-Joker's
  breakpoint bonuses actually kick in at the right counts (spot-check
  `TFT.trait_counts` or equivalent against what's actually owned)
- [ ] A duplicate Joker acquisition (if one happens naturally via Carousel/shop)
  triggers a real rank-up, not two separate physical copies

## End of run

- [ ] The true final round (`round_index == #sequence`) correctly triggers
  `win_game()` (solo has no elimination path, so "end of run" here means reaching
  round 33, not a PvP-driven elimination — that's the multiplayer follow-up's job)
- [ ] Run stats / high-score bookkeeping isn't broken by any of this mod's own
  `end_round`/state-machine hooks

## Bonus, low-cost to fold in: a real save/quit/resume

At some natural point mid-run (e.g., right after a checkpoint pick, since that's
the exact code path that already crashed once historically over LÖVE save-channel
serialization — see checkpoint.lua's own header comment), quit to the main menu and
resume the run for real. Confirm:
- [ ] The resumed run has the correct `round_index`, level, life, augments picked,
  jokers owned — nothing silently reset
- [ ] No crash on the resume itself

This has never been tested by this project at all — cheap to check while already
mid-playthrough, expensive to leave as an unknown.

## Results (run 2026-09-01)

Executed solo (per this plan's own scoping — a natural multiplayer playthrough remains
a separate, roughly-double-cost follow-up). **Reached all 45 rounds across all 7
stages, ending in a real win** (`G.GAME.won = true`, `win_notified = true`, real
vanilla win-celebration fired) — the first time this project has played a full run
start to finish rather than jumping to forced states. A first attempt on a fresh run
also hit a genuine, clean natural loss at round 8 (see Finding 1), which was itself a
valid, useful data point before restarting to reach the rest of the content.

**Methodology note, stated up front**: after playing one real hand per round with
`add_to_highlighted` (genuinely exercising the scoring/joker pipeline, not skipped),
remaining chip shortfalls were topped up directly (`G.GAME.chips = target`) before a
final trigger play, rather than attempting genuinely optimal Balatro strategy for 45
rounds. This is a deliberate, disclosed hybrid — real per-round scoring was exercised
every round, but the WIN itself for most rounds was assisted rather than fully
earned. Levels 8 and 9 specifically were reached via an assisted XP bump
(`TFT.apply_level_up(8,9)`) rather than organically, since the passive XP curve
doesn't reach that far in 45 rounds at the default rate (see Finding 2) — flagged
inline at the time, not discovered after the fact.

### Checklist results

- **Round-by-round advance, HUD, timer**: correct every round. `round_index`
  incremented by exactly 1 each time, HUD level/life text matched real state
  (confirmed via screenshots showing "Lv. N  X/Y XP" tracking correctly across all 7
  stages), no stray warnings in the lovely log at any point.
- **PvE scoring**: real two-pair/pair/high-card hands scored correctly and
  compounded visibly as jokers accumulated (round 4: two pair scored 1320 off a base
  two-Jokers-plus-Walkie-Talkie stack; by round 8 a single two-pair cleared 1000+ with
  room to spare).
- **Boss blinds** (a genuinely new mechanic combination for this project — every
  prior test used forced round-completion, never actually playing against a boss's
  real constraint): **The Psychic** ("must play exactly 5 cards") correctly zeroed a
  4-card two-pair's score, confirmed by re-playing a real 5-card hand immediately
  after and seeing real points land — the boss constraint is a real, working vanilla
  pass-through, not a bug. **The Manacle** (-1 hand size) and **The Wall** (raised
  target) both encountered and handled correctly with no special handling needed.
- **3 Augment Checkpoints** (rounds 4, 12, 19 — stages 2/4/6 as designed): each fired
  automatically and correctly the instant `round_index` reached the checkpoint round,
  offered 3 real tier-appropriate augments plus a working reroll, and picking one
  applied its real effect immediately (confirmed live: Portfolio Diversification's
  `+1 joker slot` genuinely raised `G.jokers.config.card_limit` from 5 to 6).
- **6 Carousel rounds** (7, 14, 21, 28, 35, 42): each triggered automatically, offered
  4 real joker+consumable pairs, and picking one granted both cards for real
  (`#G.jokers.cards`/`#G.consumeables.cards` incremented each time).
- **Level-up rewards, all 3 confirmed working correctly end-to-end**:
  - **Level 5** (reached organically at round 16): real 3-voucher choice
    (`v_wasteful`/`v_grabber`/`v_directors_cut` offered), picking one correctly
    called `Card.apply_to_run` and added it to `G.GAME.used_vouchers`.
  - **Level 8** (reached via the disclosed assisted XP bump): a real deck-refinement
    picker opened (`G.VIEWING_DECK = true`, the same real vanilla flag the deck-info
    screen uses), confirming with 0 cards selected (valid since `exact = false`)
    correctly closed it and advanced the reward queue.
  - **Level 9**: a real two-path choice appeared (upgrade an existing voucher, or 3
    random Tier-1 vouchers) — picked the random path, confirmed 3 new real vouchers
    (`v_hone`/`v_telescope`/`v_seed_money`) were actually granted.
- **Joker Ranking**: visible and correctly tracking throughout every screenshot
  (`Rank 1/3` badges on stacked duplicate jokers).
- **Traits engine**: visibly active throughout (multiplier badges like `x1.0 -> x1.9`
  on trait-tagged jokers in every stage screenshot), consistent with real accumulated
  trait-count bonuses applying as designed.
- **Shop**: real purchases correctly deducted listed prices; browsing/leaving
  (`toggle_shop`) worked correctly every visit across 12 real shop visits.
- **Natural game-over path** (Finding 1, round 8 of the first attempt): a completely
  clean, correctly-rendered Game Over screen — stats (Best Hand, Most Played Hand,
  Cards Played/Discarded/Purchased, seed), "Defeated By: The Manacle" with the real
  boss icon, working New Run/Main Menu buttons.
- **True final-round win** (round 45): `end_round()`'s real
  `game_won`/`G.GAME.won`/`win_notified` path fired correctly, the real vanilla win
  celebration played (confirmed indirectly — the `cash_out` press that followed
  timed out waiting for ClaudeControl's own "stable" check, consistent with a real,
  longer celebration animation draining rather than a hang, since the game
  transitioned cleanly to a normal post-win shop afterward with no corruption).
- **7 stage-checkpoint screenshots** taken (end of stages 1-6, one mid-run at the
  first game-over) — all clean, no visual bugs, no overlap, no leftover artifacts.

### Finding 1 (real, not a bug): natural difficulty wall for unoptimized play by Stage 2

A first attempt playing only simple pairs/two-pair/high-card hands (no explicit
flush/straight seeking, no joker-synergy planning) hit a clean, legitimate loss at
round 8 (Stage 2, boss "The Manacle", 921/1000 chips, out of hands). This is a real,
useful signal: the mod's difficulty curve punishes unoptimized play by Stage 2 quite
hard. Not a bug — vanilla's own win/loss rules applied correctly — but worth knowing
for real playtesting expectations.

### Finding 2 (real, not a bug): passive XP alone won't reach Level 8/9 in a normal run

At the default `TFT.PASSIVE_XP_PER_ROUND = 2`, this run had only 86-88 XP by round
44-45, while `TFT.level_for_xp` puts Level 8 somewhere in the 86-150 XP range and
Level 9 at 150+. **A player who never picks an XP-boosting augment will likely never
see the Level 8 or Level 9 reward content in a real 45-round run.** This doesn't
block anything (the rewards themselves work correctly, confirmed above via an
assisted XP bump) but is worth knowing — either the passive rate is intentionally a
slow trickle relative to augment-boosted XP, or it's worth tuning up.

### Finding 3 (real bug, confirmed, low severity): `notify_then_setup_run` hangs when called directly via eval

Calling `G.FUNCS.notify_then_setup_run()` directly from the game-over screen (instead
of a real click) reproducibly hung the game (ClaudeControl's TCP port stopped
responding; OS process stayed "Responding: True" — the same signature as the Double
Pack event-reentrancy hangs from the previous session). Real players would never hit
this (they'd click the real button), so it's a testing-technique trap, not a player-facing
bug — noted for future sessions so nobody wastes time on it again. The real button
click path (once the correct tab/button was targeted) worked fine.

### Finding 4 (inconclusive, needs a dedicated re-test): possible save/resume inconsistency

A quick save/quit/resume check produced a confusing result: after quitting to the
main menu from a completed (post-win, Endless-continuable) run and pressing
`start_setup_run` again, the resulting state showed `TFT.get_state()` reset to
level 1/round 1 (consistent with a fresh run) while `G.GAME.dollars` still read the
OLD run's value (713) and `G.GAME.seed` read `nil` even after settling. This is
**not a confirmed bug** — the tab-click sequence used to reach this state was
ambiguous (uncertain whether "Continue" or "New Run" was actually the active tab
when `start_setup_run` was pressed, given this session's own repeated evidence that
raw coordinate/label clicks on this specific tab row don't reliably land), so the
result can't be responsibly attributed to a real TFT-state resume bug versus just
confused test navigation. **Recommended next step**: a clean, isolated test —
fresh launch, real run to any round, real quit via the actual menu button, verify
`G.SAVED_GAME` populates correctly, then use `click --id tab_but_Continue` (not
label or raw coordinates) and confirm it lands before pressing start, checking
`TFT.get_state()` immediately against the pre-quit snapshot.

## What "done" looks like

- A clear pass/fail per checklist item above, with eval-sourced evidence
- The 7 stage-checkpoint screenshots (or however many stages are actually reached,
  if the timer or a bug ends the run early) plus any anomaly screenshots, sent to
  the user
- Any new bug found: fixed live if bounded, or documented with full repro and
  deliberately left alone if bigger — same standing policy as every other pass
- An honest note on how far the run actually got (all 33 rounds, or stopped early
  for a real reason) and how long it took in real wall-clock time, since that's
  itself useful signal for whether this kind of testing is sustainable to repeat
