# BalatroTFT — Design Plan

A Balatro mod that reworks the run structure around TFT's design: player Level (drives
shop rarity odds and grants passive benefits), Augments (run-defining picks at fixed
checkpoints), and Traits (Joker synergy tags with breakpoint bonuses) — built for 8-player
(2-8 configurable) free-for-all multiplayer on top of Steamodded (smods) and
BalatroMultiplayerAPI, with a single-player fallback that swaps PvP rounds for normal
boss-blind PvE.

This is a living document, built incrementally as design decisions get locked in. See:
- [traits.md](traits.md) — Joker synergy Trait roster + population audit
- [augments.md](augments.md) — Augment library, by category
- [architecture.md](architecture.md) — stage/round layout, leveling, economy, PvP damage formula
- [technical.md](technical.md) — code architecture, file layout, MPAPI sync patterns
- [new-jokers.md](new-jokers.md) — custom Jokers authored to fill out thin Trait pools
- [joker-ranking.md](joker-ranking.md) — duplicate-merge Rank system, the "stay low level" incentive

## Locked architecture decisions

| Decision | Choice | Notes |
|---|---|---|
| Round/timeline structure | **Full TFT-style rebuild** | Replace Ante/Blind with TFT's stage-and-round format. ~6-7 stages, target ~30-40 total rounds. |
| Match length target | **Compact, ~45-60 min** | PvE rounds trimmed/simplified vs. a 1:1 TFT round-count port, since every round is played by a real human, not auto-resolved. |
| PvP pairing (up to 8p) | **Rotating round-robin pairs** | Deterministic pairing each PvP round (shared-seed derived, no repeat opponents until everyone's been faced once). |
| Odd-numbered lobbies | **Ghost boards** | Unpaired player faces a snapshot of another player's board/score that round, like TFT. |
| Win condition | **TFT-style life totals + scaling damage** | Everyone starts at a life total; losing a PvP round costs life scaled by stage + a "board strength" stat (TBD — see open items). 0 life = eliminated; last player standing wins. |
| Vanilla systems | **Layer on top / repurpose** | Vouchers become level-up rewards instead of shop RNG. Boss Blinds still occur as PvE rounds (and are the sole PvE mechanic in single-player fallback). Existing Joker/Consumable pools reused, re-weighted by Level. |
| Carousel-equivalent | **Turn-order snake draft by life total** | Lowest life picks first each carousel checkpoint. Deterministic, latency-fair — no real-time click racing over the relay network. |
| Augment cadence | **3 checkpoints, TFT-standard** | At Stages 2/4/6. **Tier is rolled per checkpoint, not guaranteed** — a real TFT-sourced conditional-odds table (updated, supersedes the original "guaranteed Silver→Gold→Prismatic" framing) lives in [architecture.md](architecture.md#augment-tier-odds-supersedes-the-earlier-guaranteed-silvergoldprismatic-assumption). |
| Augment offer reroll | **1 free reroll per offer, built into the base UI** | Not an augment itself — confirmed while cutting the now-redundant "Second Opinion" augment idea. Every augment choice (all 3 checkpoints) lets the player discard their 3 offered choices once for 3 new ones from the same tier. |
| Player count | **2-8 configurable, default 8** | Matches TFT's own cap. |
| Stage/round layout | **7 stages, 33 rounds total** (3 PvE in stage 1, then 6 stages of PvP/PvP/Carousel/PvP/PvE) | See [architecture.md](architecture.md). Sized so a reasonably-performing player is eliminated around stage 6-7, per your pacing note. |
| Repeated-action costs | **Scale with uses-this-round, not fixed** | Per your note: staying with Balatro's own reroll-cost-scaling precedent (cost climbs each use, resets next round) rather than TFT's fixed prices. Applied to both shop rerolls and Buy XP. |
| PvE vs. PvP value | **PvE is the primary value source** | PvE rounds guarantee money + a consumable + a scaling chance at a bonus Joker. PvP rounds mainly govern the life-total contest, with smaller win money and a streak bonus — real value, deliberately harder to get than PvE's guaranteed haul. |
| Networking | **BalatroMultiplayerAPI directly** (not the higher-level `BalatroMultiplayer` duel mod) | MPAPI is networking-only (lobby/actions/events/player-state via MQTT relay, deterministic shared-seed clients). We build our own N-player round-robin pairing, damage, and round-flow logic in userspace on top of it, since the reference 1v1 duel mod's game rules don't fit an 8-player TFT structure. |
| Mod dependency | **Steamodded (smods) required**, MPAPI required for multiplayer | Custom Rarities, Jokers, Consumables, Vouchers, calc-context hooks all come from smods. |
| Matchmaking model | **Private lobby-code only** | Built on `MPAPI.create_lobby()`/`join_lobby()`, not the public `matchmaking.queue()` system — no stranger-matchmaking for v1. See [technical.md](technical.md). |
| Desync handling | **Host-authoritative reconciliation** | If a client's independently-computed state disagrees with the host's broadcast, it re-syncs from the host. See [technical.md](technical.md). |

## Open items still needing a decision

- First-draft numbers in [architecture.md](architecture.md) (XP curve, shop odds, PvP
  damage formula, PvE/PvP reward amounts) all need a playtesting/tuning pass — drafted,
  not final.
- Consumable-pool odds by level (Tarot/Planet/Spectral ratio) — not designed yet.
- ~~Per-level passive benefits beyond shop odds~~ ✅ drafted — see [architecture.md](architecture.md#per-level-passive-benefits).
- Repo/code architecture (file layout, how Traits/Augments hook into SMODS calc_context).

## Pre-Implementation Checklist

Full gap analysis across all three docs, done before moving to code. Grouped by how much
each one actually blocks starting implementation.

### Tier 1 — blocks writing real game-loop code
1. ~~**Technical/code architecture**~~ ✅ solid first draft in [technical.md](technical.md) —
   file layout, sync/desync patterns, matchmaking model, action list, round/stage state
   machine (timer-based soft barrier, host-driven advance), and Trait/Augment calc-hook
   design (invisible pseudo-Joker pattern) are all drafted. Grounded in a real analysis of
   the shipped `BalatroMultiplayerSpeedrun` mod rather than guessed at. Still wants a
   pass once actual smods API references are checked against current docs, and the
   timer numbers need playtesting like everything else numeric in this plan.
2. ~~**PvE chip requirement curve**~~ ✅ drafted — see
   [architecture.md](architecture.md#pve-chip-requirements--boss-blind-assignment).
3. ~~**Boss Blind assignment per stage**~~ ✅ drafted, same section as above.
4. ~~**Starting money & shop price baseline**~~ ✅ drafted — see
   [architecture.md](architecture.md#starting-money--shop-prices).
5. **Consumable category split by level** (Tarot vs. Planet vs. Spectral ratio) —
   **explicitly deferred by request, not a blocking unknown.** Correction worth keeping:
   vanilla Balatro has an adjustable Spectral shop weight rate (Ghost Deck uses a
   non-zero value to enable Spectral in the shop), so this isn't a strict vanilla-vs-not
   binary — see [technical.md](technical.md#deferred--spectral-shop-odds).

### Tier 2 — blocks specific already-designed content, not the engine itself
6. Perfect Game's reward pool (Combat & Stats, Prismatic) — still undesigned.
7. ~~**New custom Jokers to author**~~ ✅ 19 Jokers drafted (16 across the four Suit
   Guilds, 3 for Scholars) — see [new-jokers.md](new-jokers.md).
8. Systematic audit for other Boss-Blind-bypass/death-prevention cards beyond the 3
   already banned (Luchador, Mr. Bones, Chicot).
9. **Vanilla-mechanic verification flags** (5 tracked across the docs): Omen Globe's
   exact wording, Aura's edition-weighting table, Negative consumables' "not consumed on
   use," Negative Jokers' slot-free/slot-granting behavior, reroll's exact base cost.
10. Playtesting/tuning pass on every first-draft number (XP curve, shop odds, PvP damage
    formula, PvE rewards, Sudden Death) — needs either simulation tooling or actual
    playtests once there's a playable alpha.

### Tier 3 — systems not designed at all yet
11. **Placement/ranking & end-of-match flow** — does each eliminated player get a
    placement (1st-8th) like TFT? Results screen?
12. **Spectator behavior** for eliminated players — watch the rest of the match live, or leave?
13. **Lobby/match setup flow** — host config UI, player-count setting, mod-version
    compatibility checks, what happens with fewer players than configured.
14. **Voucher eligibility pool** for the level 5/9 picks — are all vanilla Tier-1
    Vouchers eligible, or are any excluded as thematically broken under this system?
15. **UI/UX** for new HUD elements — level/XP bar, Trait breakpoint progress panel,
    all-8-players' life totals (not just your current PvP pairing), augment pick screen,
    round-type indicator.
16. **Settings/config surface** — full list of what's player-configurable beyond player
    count (match-length variant? single-player toggle? balance-tuning knobs?).
17. **Version targeting** — target Balatro version, Steamodded version pin, MPAPI version pin.

### Tier 4 — production needs, can run in parallel with the above
18. Art assets for new custom Jokers/Traits/Augment icons.
19. Audio/SFX for new events (PvP round start, elimination, level-up, augment pick).
20. Localization scope (smods supports `SMODS.Language` — English-only for v1, or plan
    for translations from the start?).

## Design gap: incentive to stay low level

Raised concern: shop-odds-by-level was the only lever pulling against just racing to max
level, once a player finds their key pieces. Resolved with two additions, both of which
grew substantially past their original scope:

- **[joker-ranking.md](joker-ranking.md)** — duplicate copies of a Joker merge into a
  Ranked (2★/3★) version instead of taking a second slot, recreating TFT's "slow roll"
  as a real competing strategy against leveling fast. Grew from a simple Common/Uncommon
  idea into a full **5-tier Power Tier system parallel to vanilla rarity**
  (Common/Uncommon/Rare/**Strong**/**Legendary**, each with its own rank-multiplier
  curve, every tier now reaching Rank 3), plus a **Shared Joker Pool** (TFT bag
  mechanic, snapshot-refreshed per shop-open rather than live-tracked) that's what
  actually gatekeeps Rank 3 at the top end instead of a hard cap. Depends on vanilla's
  Showman ("duplicates may appear") becoming this mod's baseline. **Resolved since:**
  Shared Joker Pool sizes now use TFT's own bag numbers directly (29/22/18/10/9 copies
  per unique Joker by tier), exposed behind a single `pool_size_scaler` for easy
  retuning later; unclassified Jokers default 1:1 to vanilla rarity, so the "full
  150-Joker audit" is no longer a blocker — Strong-tier is a curated allowlist that
  grows incrementally. Still open: the rank-multiplier curve remains the single
  highest-uncertainty number set in the whole plan, and the ported TFT pool sizes
  haven't been sanity-checked against the fact that Balatro's pool exists within one
  match rather than refilling between games.
- **Multi-trait Jokers** — see [traits.md](traits.md#multi-trait-jokers). Mostly already
  solved: Ascendants auto-tags every Rare/Strong/Legendary Joker by power tier, so
  they're multi-trait for free. Added deliberate 2nd/3rd tags to a few
  Common/Uncommon/Rare Jokers on top of that.
- **Ascendants itself now needs a full revisit** (not just a numbers tweak) now that the
  5-tier system exists — membership is updated, but breakpoint thresholds and some
  breakpoint effects are stale against the new rarity shape. Explicitly deferred by
  request — see [traits.md](traits.md#ascendants--redefined-by-rarity-membership-expanded-to-a-4-tier-trait).

## Content status

- **Traits:** revised twice, population audit done, Scalers/Ascendants expanded to 5-tier
  and 4-tier capacity-gated traits. See [traits.md](traits.md) — has a short "still open"
  list of interpretation calls needing sign-off.
- **Augments:** all 8 categories drafted and at least one revision pass deep — Economic,
  Combat & Stats, Shop & Items, Trait & Emblem, Deck & Cards, Utility & Information,
  Risky & Situational, Defensive & PvP. See [augments.md](augments.md). First full content
  pass is essentially complete; still needs a consistency/balance read-through once the
  architecture numbers (leveling curve, PvP damage formula) are locked, since several
  augments were explicitly written "provisional until that formula exists" (all of
  Defensive & PvP, for instance).
- **Perfect Game** (Combat & Stats, Prismatic) needs a reward-pool brainstorm — "choose a
  permanent bonus effect on precision-clearing a blind," effect list TBD.
- **Known implementation-verification flags scattered through the docs** (not blocking,
  but tracked): Omen Globe's exact vanilla wording, Aura's edition-weighting table,
  whether Negative consumables are still "not consumed on use," whether Negative Jokers
  are still slot-free/slot-granting, Card Shark's behavior when consumable slots are full.
