# Architecture — Stages, Leveling, Economy, PvP

First full draft. Uses TFT as the base reference throughout, adapted for two explicit
constraints: (1) **scaling costs for repeated same-action-in-a-round spending**, staying
with Balatro's own reroll-cost-scaling precedent instead of TFT's fixed prices, and (2)
**PvE rounds are the primary value source**; PvP rounds are about the life-total contest
first, with real but harder-to-get value on top. Everything numeric here is a first pass —
flagged for playtesting, not treated as final.

## Stage & Round Layout

| Stage | Rounds | Sequence | Notes |
|---|---|---|---|
| 1 | 3 | PvE, PvE, PvE | No eliminations possible — pure deck/economy setup, mirrors TFT's all-PvE stage 1. |
| 2 | 5 | PvP, PvP, Carousel, PvP, PvE | **Augment checkpoint (Silver)** before round 2-1. |
| 3 | 5 | PvP, PvP, Carousel, PvP, PvE | |
| 4 | 5 | PvP, PvP, Carousel, PvP, PvE | **Augment checkpoint (Gold)** before round 4-1. |
| 5 | 5 | PvP, PvP, Carousel, PvP, PvE | |
| 6 | 5 | PvP, PvP, Carousel, PvP, PvE | **Augment checkpoint (Prismatic)** before round 6-1. |
| 7 | 5 | PvP, PvP, Carousel, PvP, PvE | Final stage. See Sudden Death below if 2+ players remain after it. |

**Total: 33 rounds** (18 PvP, 9 PvE, 6 Carousel) across 7 stages — inside the ~30-40 round
/ ~45-60 min compact target. Per-stage ratio (3 PvP : 1 Carousel : 1 PvE) mirrors TFT's own
ratio (which is PvP-heavy in round *count* — TFT is roughly 5:1:1 — but PvE-heavy in
per-round *value*, which is exactly the split requested). Trimmed from TFT's 7-round
stage to 5 by cutting one mid-stage PvP round, keeping Carousel and PvE each still
guaranteed once per stage.

**Shop:** appears after every PvE and PvP round (a "scoring" round), not after Carousel.
27 shop visits across a full match.

**Sudden Death:** if stage 7 finishes with 2+ players still alive, overtime continues the
same PvP round structure, but the stage-based damage component (below) doubles every
overtime round until one player remains. Needed for a hard pacing cap — without it a
close 8-player game could theoretically run indefinitely.

## Leveling & XP

- **Passive XP:** +2 every round, regardless of round type (PvE/PvP/Carousel all grant it).
- **Buy XP:** base **$4 for 4 XP**, and — per your note — **this scales the same way
  Balatro's own reroll cost already does**: +$1 for each additional Buy XP action taken
  *that round*, resetting back to $4 at the start of the next round. Confirmed vanilla
  reroll behavior this mirrors: base $5, +$1 per reroll used within a shop visit, reset
  at the next shop. *(Flagging for a source check — going off memory for the exact base
  reroll number.)*
- **Level cap: 10**, matching TFT.

**Reference — actual TFT (best recollection, flagged as memory not a verified source):**
per-level cost 2 / 2 / 6 / 20 / 36 / 48 / 72 / 84 / 100 (cumulative 2 / 4 / 10 / 30 / 66 /
114 / 186 / 270 / 370 to reach levels 2 through 10). That shape is where your three
benchmarks come from: level 3 lands right around passive XP's 4-round mark (start of
stage 2), the 4→5 jump (20) is the first real spike after two cheap early levels, and
5→6 (36, your "~30") continues escalating from there.

**Rescaled for this mod**, keeping that same shape but fit to our numbers — 2 XP/round
passive (unchanged) and a 33-round match where a well-performing player is typically
still alive around round 28-33 (stage 6-7, per the pacing target).

**Retuned again** to hit exact early-game timing: level 2 lands precisely at the end of
round 1-2, level 3 precisely at the end of round 1-3 (end of Stage 1), and by round 2-1
a player sits at level 3 with exactly 2 of the 10 XP needed for level 4:

| Round | 1-1 | 1-2 | 1-3 | 2-1 |
|---|---|---|---|---|
| Passive XP total | 2 | 4 | 6 | 8 |
| Level reached | 1 | **2** | **3** | 3 (2/10 toward 4) |

| Level | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|
| XP cost for this level | 4 | 2 | 10 | 14 | 16 | 16 | 30 | 40 | 55 |
| Cumulative | 4 | 6 | 16 | 30 | 46 | 62 | 92 | 132 | 187 |

Level 2 costing more than level 3 (4 vs. 2) looks unusual on paper but is intentional —
it's what makes level 2 land exactly on round 1-2 and level 3 land exactly on round 1-3
simultaneously, both against a flat 2 XP/round passive rate. Level 7 still lands at
cumulative 62, reachable by round 31 on pure passive — a 1-round drift from the previous
draft's round 30, well within noise, so "level 7 on pure passive by game's end" still
holds against the stage-6-7 pacing target. Levels 8-10 are unchanged (30/40/55) and still
land at a much saner 187 cumulative for level 10, vs. the original draft's 548.

## Shop Rarity Odds by Level

**Rebuilt as a full 5-tier table** (Common/Uncommon/Rare/Strong/Legendary), directly
mirroring the structure of TFT's own Set 17 shop-odds table (levels 3-10, bag sizes
included) rather than our earlier 4-tier version — Strong now has its own odds column
(superseding the "shares Rare's column" idea floated in joker-ranking.md, which this
supersedes). Per your instruction, Rare (tier 3) is shifted to be the **plurality tier at
both level 6 and level 7** — in the real TFT table, tier 2 is still the plurality at
level 6 and tier 3 only takes over at level 7; here that transition is pulled one level
earlier, with the rest of the curve adjusted to scale accordingly afterward.

| Level | Common | Uncommon | Rare | Strong | Legendary |
|---|---|---|---|---|---|
| 1 | 100% | 0% | 0% | 0% | 0% |
| 2 | 90% | 10% | 0% | 0% | 0% |
| 3 | 75% | 25% | 0% | 0% | 0% |
| 4 | 55% | 30% | 15% | 0% | 0% |
| 5 | 45% | 33% | 20% | 2% | 0% |
| 6 | 30% | 30% | **35%** | 5% | 0% |
| 7 | 19% | 26% | **40%** | 14% | 1% |
| 8 | 12% | 18% | 30% | 35% | 5% |
| 9 | 7% | 12% | 20% | 40% | 21% |
| 10 | 3% | 7% | 15% | 40% | 35% |

**Confirmed: full TFT shape, including the 35% Legendary endpoint at level 10** —
supersedes the earlier 10% figure from before Strong/Legendary got their own ranking
system. Legendary is now meant to be a real, reachable sight at max level, not a rare
curiosity.

### Joker Rarity Pools

How many actual Jokers exist at each rarity — this is what the odds % above draws from,
and it matters separately from the odds themselves: a high odds% spread across a small
pool means you'll see the *same handful* of Jokers often, while a big pool at low odds%
means rare, varied sightings. Vanilla Balatro's counts (150 Jokers total):

| Rarity | Vanilla pool size | Odds spread across it (at level 10) |
|---|---|---|
| Common | 61 | 3% ÷ 61 ≈ 0.05% per specific Common, per slot roll |
| Uncommon | 64 | 7% ÷ 64 ≈ 0.11% per specific Uncommon |
| Rare | ~13-15 *(shrunk — the Strong-tier reclassification pulled ~7 Jokers, including Baron, Hack, Sock and Buskin, DNA, Blueprint, Brainstorm, Invisible Joker, out of this pool — see [joker-ranking.md](joker-ranking.md))* | 15% ÷ ~14 ≈ 1.1% per specific Rare |
| **Strong** *(new)* | ~7, curated (Baron, Hack, Sock and Buskin, DNA, Blueprint, Brainstorm, Invisible Joker) | 40% ÷ 7 ≈ 5.7% per specific Strong Joker — deliberately the *highest* per-card odds of any tier, since the pool is so small |
| Legendary | 5 | 35% ÷ 5 = 7% per specific Legendary *(only reachable via level 10 or Ascendants — see above; this 35% figure is exactly the open tension flagged above)* |

Worth noting for later: **these pools will grow once we author our own custom Jokers** —
tracked debt already exists for the Suit Guilds (~3-5 new Jokers each) and Scholars
(~2-3 buffer Jokers) from the Traits audit. Every new custom Joker we add shifts these
pool sizes and therefore the effective per-Joker odds, so this table will need
revisiting once that content actually exists, not just once at the end.

## Consumable Odds by Level

Scope, per your note: **only individual-card weight changes within the existing Tarot
and Spectral pools** — not a restructure of the Tarot/Planet/Spectral category split
itself (that's still a separate open question, not addressed here). **Planet cards are
completely unchanged** — all 12 stay uniformly weighted at every level.

Presented as a **weight multiplier relative to a normal/unlisted card's baseline weight**
(1.0 = normal), rather than hand-computing exact renormalized percentages for all 22
Tarots × 10 levels — that renormalization is mechanical once there's code to do it, and a
worked example below shows how it plays out at one level for concreteness.

### Tarots

**The phase-out group** — The Empress, The Hierophant, The High Priestess, The World,
The Star, The Moon, The Sun, The Magician (8 cards) — ramps down to fully removed by
level 8:

| Level | 1-3 | 4 | 5 | 6 | 7 | 8-10 |
|---|---|---|---|---|---|---|
| Weight (each of the 8) | 1.0 | 0.8 | 0.6 | 0.4 | 0.2 | **0.0 (removed)** |

**Justice** — impossible until level 7, ramps in, reaches parity at 9, boosted at 10:

| Level | 1-6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|
| Weight | **0.0 (impossible)** | 0.33 | 0.66 | 1.0 (equal to others) | 1.5 (boosted) |

**Death** — a single step up starting at level 6, not a gradual ramp:

| Level | 1-5 | 6-10 |
|---|---|---|
| Weight | 1.0 | 1.5 |

**The remaining 12 Tarots** (The Fool, The Emperor, The Lovers, The Chariot, The Hermit,
Wheel of Fortune, Strength, The Hanged Man, Temperance, The Devil, The Tower, Judgement)
stay at a constant 1.0 weight the entire match — untouched by any of the above.

**Worked example — level 8 odds**, to show the redistribution mechanism concretely: the 8
phase-out cards are at 0, Justice is at 0.66, Death is at 1.5, and the 12 untouched cards
are at 1.0 each. Total weight = `0.66 + 1.5 + (12 × 1.0)` = **14.16**. So at level 8:
each untouched Tarot ≈ `1.0 ÷ 14.16` ≈ **7.06%** (up from the vanilla uniform ~4.55%,
since the phased-out cards' probability mass flows into everything still active),
Justice ≈ `0.66 ÷ 14.16` ≈ **4.66%**, Death ≈ `1.5 ÷ 14.16` ≈ **10.59%**, and the 8
phase-out cards sit at exactly **0%**.

### Spectrals

**Ankh, Ectoplasm, Wraith, and The Soul** get a modest, flat boost starting the level
right after your stated threshold — no gradual ramp, since you didn't ask for one here:

| Level | 1-6 | 7-10 |
|---|---|---|
| Weight (each of the 4) | 1.0 | **1.3** |

Chose 1.3x as "not too much" — noticeably better than baseline without dominating the
Spectral pool. All 4 are thematically Joker-granting/upgrading cards (Ankh consolidates
into a copy of a random Joker, Ectoplasm grants Negative edition, Wraith grants a random
Rare Joker, The Soul grants a random Legendary Joker), so this modest boost reinforces
the same "richer late-game shop" theme as the Joker rarity curve and ties in with the
Ascendants trait's own Negative/Legendary focus. All other Spectral cards stay at 1.0
throughout. Flag if 1.3x reads as too much or too little once this is actually playable.

## Per-Level Passive Benefits

Baseline progression every player gets just from leveling, separate from build-specific
Traits/Augments on top. Covers every category the original brief called out (hand size,
vouchers, money per turn, Joker slots, consumable slots, deck effects), reordered per
your latest pass so utility, economy, and slots interleave rather than clustering.

| Level | Benefit |
|---|---|
| 1 | *(start — no bonus)* |
| 2 | +1 hand played per round |
| 3 | +1 discard per round |
| 4 | +1 hand size |
| 5 | **Voucher Choice:** pick 1 of 2 free Tier-1 Vouchers, **and** +$5 at the end of every round |
| 6 | +1 consumable slot |
| 7 | +1 Joker slot |
| 8 | **Deck Refinement:** choose up to 5 cards to remove from your deck, free, one-time, **and** +$5 more at the end of every round (total +$10/round with level 5's bonus) |
| 9 | **Voucher Choice:** choose one — **(a)** 2 Tier-2 upgrades for Vouchers you already own, or **(b)** 3 fresh Tier-1 Vouchers |
| 10 | +1 Joker slot, +1 consumable slot, **and** Legendary shop odds unlock (see odds table above) |

Totals if a player reaches level 10: **+2 Joker slots** (base 5 → 7), **+2 consumable
slots** (base 2 → 4), **+1 hand size**, **+1 discard**, **+1 hand played/round**,
**+$10/round passive income**, up to **5 free Vouchers**, one free deck-thinning event
(up to 5 cards), and Legendary shop access. Stacks on top of whatever Traits/Augments add.

## PvE Chip Requirements & Boss Blind Assignment

Never actually defined until now — we'd designed what clearing a PvE round *rewards*
without ever setting the score target itself.

**Chip requirements** (first draft, loosely tracking vanilla Balatro's own Ante chip
curve so the early game feels familiar and the late game reaches comparable
hundred-thousands-range numbers by the final stage):

| Round | 1-1 | 1-2 | 1-3 | 2 PvE | 3 PvE | 4 PvE | 5 PvE | 6 PvE | 7 PvE |
|---|---|---|---|---|---|---|---|---|---|
| Chip target | 100 | 200 | 300 | 1,000 | 3,000 | 8,000 | 20,000 | 50,000 | 120,000 |

**Boss Blind assignment:** stages 2-6 draw randomly from the **full standard vanilla Boss
Blind pool**, minus the 5 "finisher" bosses vanilla itself reserves for Ante 8 (The Amber
Acorn, The Verdant Leaf, The Crimson Heart, The Cerulean Bell, The Violet Vessel).
**Stage 7 draws exclusively from those 5 finisher bosses**, mirroring how vanilla already
gates them to its final ante — reusing an existing vanilla tiering rule rather than
inventing a new one.

## Starting Money & Shop Prices

- **Starting money: $4**, matching vanilla Balatro's own default rather than inventing a
  new number — no strong reason to diverge given how much other economy tuning is
  already happening elsewhere (Buy XP, streaks, PvE rewards).
- **Shop prices (Jokers/Consumables/Vouchers/Packs): unchanged from vanilla**, consistent
  with the "layer on top" architecture philosophy — reusing vanilla's existing
  rarity-based pricing rather than authoring a parallel price table.
- PvE reward formula (`$10 + stage×2`) now confirmed to also apply at **Stage 1** (i.e.
  $12 per Stage-1 PvE clear) — wasn't explicit before since Stage 1 predates any PvP
  contrast, but there's no reason it should behave differently.

## PvE vs. PvP value split

Per your note: PvE is where players should get most of their value; PvP value is real but
harder to access.

**PvE round clear (guaranteed):**
- Money: `$10 + (stage × 2)`
- 1 free consumable card (Tarot/Planet/Spectral)
- Small chance of a bonus free Joker: `5% × stage` (so 10% at stage 2, up to 35% at stage 7)

**PvP round win:**
- Small money reward only: **$3-5**, well below PvE's guaranteed haul
- Feeds the win/loss streak bonus (below)
- No guaranteed consumable or Joker — that stays PvE's domain. (Augments like
  *Counterpunch*, *Vampiric*, *The House Always Wins* can add PvP-specific value on top,
  but that's an augment investment, not baseline.)

**Win/loss streaks (PvP-only, not counted from PvE):** 2-streak +$1, 3-streak +$2,
4+-streak +$3/round, for both win streaks *and* loss streaks (TFT-style comeback
mechanic — a bad stretch isn't just damage, it's also a small economic cushion). Kept
PvP-only rather than counting PvE clears, since PvE is close to an auto-win and would
inflate streaks trivially otherwise.

## PvP Pairing

Round-robin, deterministic from the shared match seed (circle-method tournament
scheduling — a solved problem, not something to invent from scratch): across a stage's 3
PvP rounds you face 3 different opponents, and pairing avoids repeating anyone until the
full remaining pool has been faced once, then reshuffles. Odd-numbered-alive lobbies give
the unpaired player a **ghost board** (a snapshot of another player's board/score) per the
earlier locked decision.

## PvP Damage Formula (revised — score-margin based, not Board Strength)

Dropped "Board Strength" (Joker-rarity counting) entirely per your note. Replaced with a
formula based on how much the two scores actually differed in that round:

- **Starting life:** 100.
- **Base damage by stage** (PvP starts at stage 2, since stage 1 is pure PvE) — unchanged:

  | Stage | 2 | 3 | 4 | 5 | 6 | 7 |
  |---|---|---|---|---|---|---|
  | Base damage | 5 | 8 | 12 | 16 | 20 | 25 |

- **Score ratio:** `ratio = winner's score ÷ loser's score`, clamped to the range **[1, 10]**
  (a barely-won round sits at ~1; winning by 10x or more all hits the same ceiling). If the
  loser scored 0, ratio is treated as the max (10), same as any other divide-by-zero case.
- **Bonus damage:** `Base(stage) × log₁₀(ratio)`. This is the "logarithmic curve from equal
  score to 10x" you described — log₁₀(1) = 0, so a razor-thin win adds no bonus; log₁₀(10) = 1,
  so a 10x-or-greater blowout adds a full extra Base worth of damage.
- **Total damage on a PvP loss** = `Base(stage) + Bonus`, which by construction ranges
  from **1x Base** (bare win) up to **2x Base** (10x-or-greater blowout) — matching "0 to
  double the flat amount, capped at 2x for anything beyond 10x." Reduced multiplicatively
  afterward by any damage-mitigation augments the loser holds (Thick Skin, Iron Wall,
  Fortress, etc.).

Example at stage 4 (Base = 12): winning 1.5x → `12 + 12×log₁₀(1.5) ≈ 14.1` damage. Winning
10x+ → capped at `24` damage (2x Base).

*(The stage-6-7 elimination-pacing sanity check I ran previously was against the old
Board-Strength formula and no longer applies as-is — this version's damage range is
tighter and more predictable (always within 1x-2x Base rather than open-ended), which
seems directionally fine but genuinely needs a fresh pass, ideally simulated rather than
eyeballed, once there's code to actually run scenarios through.)*

## Single-player fallback

Confirmed from the original brief, made concrete against this stage layout:

- Every PvP round slot becomes a **PvE (Boss Blind) round** instead.
- Carousel becomes a free guaranteed pick from the rotating pool — no draft race needed
  with no one else to race against.
- Win condition becomes **clear all 7 stages**, matching vanilla Balatro's own "beat the
  run" framing, instead of last-player-standing.
- Failing to clear a PvE round's chip requirement deals a flat **15 damage** to life total
  (instead of the opponent-based PvP formula, which has no meaning solo).
- Explicitly **not balanced** against multiplayer, per your original note — this mode
  exists so the mod is playable at all without a lobby, not to be tuned as its own format.

## Augment Tier Odds (supersedes the earlier "guaranteed Silver→Gold→Prismatic" assumption)

**Correction to an earlier locked decision.** "3 checkpoints, TFT-standard: Silver → Gold
→ Prismatic" was written assuming each checkpoint *guarantees* that tier. Real TFT
doesn't work that way — every checkpoint independently rolls a tier from a weighted
table, conditional on what tier you got at prior checkpoints, so sequences like
Gold-Gold-Gold or Silver-Silver-Prismatic are genuinely possible, not just the "one of
each" default we'd assumed. Porting TFT Set 17's actual published table directly, applied
to our 3 checkpoints (Stage 2 / Stage 4 / Stage 6):

**Checkpoint 1 (Stage 2) — base odds:** 28% Silver / 62% Gold / 10% Prismatic

**Checkpoint 2 (Stage 4) — conditional on Checkpoint 1's result:**

| Checkpoint 1 was... | → Silver | → Gold | → Prismatic |
|---|---|---|---|
| Silver (28%) | 36% | 61% | 3% |
| Gold (62%) | 32% | 40% | 28% |
| Prismatic (10%) | 50% | 30% | 20% |

**Checkpoint 3 (Stage 6) — conditional on Checkpoints 1 and 2 together:**

| Checkpoint 1 | Checkpoint 2 | Checkpoint 3 odds | Joint probability of this exact path |
|---|---|---|---|
| Silver | Silver | 50% Gold / 50% Prismatic | 5% / 5% |
| Silver | Gold | 71% Gold / 29% Prismatic | 12% / 5% |
| Silver | Prismatic | 100% Prismatic | 1% |
| Gold | Silver | 90% Gold / 10% Prismatic | 18% / 2% |
| Gold | Gold | 88% Gold / 12% Prismatic | 22% / 3% |
| Gold | Prismatic | 35% Silver / 59% Gold / 6% Prismatic | 6% / 10% / 1% |
| Prismatic | Silver | 80% Gold / 20% Prismatic | 4% / 1% |
| Prismatic | Gold | 67% Gold / 33% Prismatic | 2% / 1% |
| Prismatic | Prismatic | 50% Gold / 50% Prismatic | 1% / 1% |

*(Joint probabilities across all 18 paths sum to 100%, checked.)* Note Checkpoint 3
almost never offers Silver again — it only reappears on the Gold→Prismatic branch — which
matches TFT's own late-game philosophy that the last augment pick should trend toward
real power rather than still handing out entry-level options. This is a **direct port of
real TFT numbers**, not an original design — no reason to reinvent odds TFT already
tuned across multiple sets, especially since our 3-checkpoint structure maps onto theirs
directly.

## Banned Jokers

**Luchador, Mr. Bones, and Chicot are banned** from this mode. Consistent with existing
precedent elsewhere in the Balatro-Multiplayer ecosystem — these three are already
disabled in existing PvP implementations for the same underlying reason: each one lets a
player bypass a mechanic this mod's stakes depend on.

| Joker | Vanilla effect | Why it's banned here |
|---|---|---|
| **Luchador** | Sell it to disable the current Boss Blind's ability | Boss Blind effects are the core identity of every PvE round (and *all* rounds in single-player fallback) — a sellable "skip the boss mechanic" button undermines that entirely. |
| **Chicot** *(Legendary)* | Disables all Boss Blind abilities for the rest of the run | Same problem as Luchador, but permanent and free instead of a one-time sell. |
| **Mr. Bones** | Prevents a loss once (if chips scored ≥25% of requirement), then self-destructs | Directly undermines the life-total/elimination stakes the whole PvP system is built on — a built-in "cheat death once" trivializes exactly the tension the damage formula exists to create. |

Treat this as a starting list, not necessarily exhaustive — more Jokers/Vouchers/Spectral
cards that bypass Boss Blinds or prevent a loss outright likely need the same treatment
once we're deeper into implementation and can audit the full card pool systematically.

## Still open

1. All numeric values above (XP curve, shop odds, damage formula, PvE/PvP rewards) are
   first-draft and need a playtesting pass — flagged throughout rather than presented as
   final.
2. Consumable-pool odds (Tarot/Planet/Spectral ratio) by level — not designed yet.
3. Reroll's exact vanilla base cost — going off memory, needs a source check.
4. Whether Sudden Death's damage-doubling is the right overtime mechanic, or too swingy.
5. Level 10's 5% Legendary odds is a placeholder — needs a real number.
7. The rescaled XP curve's exact per-level numbers (2/4/8/14/16/16/30/40/55) are a first
   pass that hits the stated benchmarks — still wants real playtesting, especially
   whether $10/round passive income by level 8 makes Buy XP spending feel worthwhile
   relative to just banking money for the shop.
6. A systematic audit for other Jokers/cards that bypass Boss Blinds or prevent a loss
   outright, beyond the 3 banned so far.
