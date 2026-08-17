# Joker Ranking — the "stay low level" incentive

## The problem

Right now the only cost to leveling aggressively is opportunity cost of money — there's
no actual *reason* to stay low. TFT solves this with star-ups: 3 copies of a cheap unit
combine into a 2-star, 3 two-stars combine into a 3-star (~3.24x a 1-star's stats), which
means committing to a low level and rolling hard for cheap units is a fully competitive
strategy against just leveling for expensive singles. A literal port of that — bespoke
upgrade tiers for every Joker — is exactly the "nightmare of balance" you flagged: ~150
vanilla Jokers (more once our own content ships) would each need hand-authored, balanced
upgrade text.

## Proposed solution: one generic multiplier, not 150 bespoke upgrades

**Duplicate copies of the same Common or Uncommon Joker merge into a single Ranked copy**
instead of taking a second slot, and Rank applies a **flat multiplier to whatever numeric
values that Joker already outputs** — chips, mult, dollars, whatever — rather than a
unique hand-written effect per Joker. This is the load-bearing design choice that avoids
the balance nightmare: we tune **one curve**, not 150 individual ones.

*(The exact multiplier curve went through several revisions below as the design grew from
"one universal curve, Common/Uncommon only" into a full 5-tier system — see **Power
Tier** further down for the final numbers. Short version: every rarity now has its own
curve and its own Rank 3, escalating steeply from Common up through Legendary, gatekept
by the Shared Joker Pool's scarcity rather than a hard cap.)*

## The load-bearing prerequisite this depends on

Vanilla Balatro's shop pool **excludes Jokers you already own from reappearing** by
default — that's specifically what the vanilla Joker **Showman** overrides ("Jokers and
Consumables may appear multiple times"). Without changing that base rule, you'd almost
never actually see a duplicate of a Joker you already hold, and this entire system would
have nothing to work with. **Showman's behavior needs to become this mod's baseline for
Common/Uncommon Jokers specifically**, not a rare Joker you have to find first. Flagging
this explicitly since it's easy to design a "duplicate merge" system on paper and forget
it has a hard dependency on a vanilla exclusion rule most people don't know exists.

## Why this actually recreates the TFT tension

- A player who stops leveling around, say, level 4-5 sees odds concentrated in
  Common/Uncommon (per the shop odds table in architecture.md), which means a much higher
  realistic chance of hitting 2-3 copies of the *same* Joker in one run than a player who
  raced to level 9-10 and is mostly seeing Rares they'll never see twice.
- Money not spent on Buy XP is money available for extra rerolls specifically hunting
  copies — the exact "slow roll" playstyle from TFT, ported without needing to invent a
  new economic lever, since we already built scaling reroll costs.
- It stacks naturally with the Suit Guild content we just authored: those Jokers skew
  Common/Uncommon, so a low-level player chasing a Guild's 2/3 breakpoint is *also* likely
  to duplicate-hunt within that same small set of Jokers — trait breadth and rank depth
  reinforce each other instead of competing for attention.

## How this interacts with existing systems

- **Trait breakpoints still only count 1** per Ranked Joker, regardless of Rank — a
  Rank-3 Joker absorbed 3 physical copies but is still 1 Joker for trait-counting
  purposes. Ranking (depth: one Joker, stronger) and Traits (breadth: many different
  Jokers, shared tag) are meant to be complementary axes, not redundant ones — exactly
  how TFT's 3-starring never counts as "3 units" for trait purposes either.
- **Scalers trait**: Rank multiplies whatever the *current total* effect value is at
  calculation time (base + any accumulated scaling), rather than only the base number —
  simplest rule, and avoids needing to reason about whether Rank affects growth *rate*
  vs. growth *total* separately.
- **Ascendants trait** — *updated, since Rare/Legendary can now rank too*: a Ranked
  Rare/Legendary Joker still counts as exactly 1 toward Ascendants' breakpoint regardless
  of Rank, same as the general trait-counting rule above. Ranking (getting one Rare/
  Legendary very strong) and Ascendants (owning *many* Rare/Legendary) stay complementary
  axes rather than the same investment double-counting itself.
- **Sell value** scales with Rank too (proposed: +50% sell value per Rank above 1) — the
  economy should reflect the real investment, without needing bespoke tuning either.

## Implementation-effort honesty check

This is real engineering work, not zero-touch — but it's a different *kind* of work than
what it replaces. Applying the multiplier cleanly to **new custom Jokers is trivial**
since we control their code and can enforce a convention (source every numeric value from
a config table the multiplier wraps). Retrofitting it onto **vanilla Common/Uncommon
Jokers** (~125 of them) means touching each one's `calculate()` once to route its output
through the same wrapper — repetitive, mechanical, low-risk work, but not literally free.
The distinction that matters: this is **transcription effort**, not **design effort** —
nobody has to invent and balance 125 unique upgrade texts, which was the actual nightmare
being avoided.

## Power Tier — a classification parallel to vanilla rarity, not a replacement for it

Extension per your latest note: some Jokers are strong enough at Rank 1 that a full
Rank 3 (3.24x) would be dangerous — the classic Balatro "repeated xMult trigger" combo
family (Baron's per-King xMult stacking with Mime retriggering held cards, Dusk
retriggering an entire final hand, The Idol's designated-card xMult, Glass cards'
per-score x2 Mult getting retriggered repeatedly) is exactly this: **multiplicative +
repeatable = exponential**, and Rank 3 compounds a multiplier that's already compounding.
Meanwhile flat or linearly-scaling xMult Jokers are strong but not combo-explosive, and
can safely take the full ranking ceiling.

**Mechanism: a new mod-specific `power_tier` field per Joker, separate from vanilla's own
`rarity` field.** Defaults to matching vanilla rarity 1:1 unless explicitly overridden.
This is the "parallel, not overtaking" framing you wanted — we're not globally rewriting
Balatro's rarity system (which could ripple into other mods' compatibility and vanilla
balance expectations), we're layering our own classification on top that mostly agrees
with vanilla but can diverge specifically where *our* ranking mechanic introduces a new
balance concern vanilla itself never had to account for.

**Revised again — every tier gets a real path to Rank 3, no artificial cap.** Your TFT
analogy is the key correction: a 3-star 4-cost *is* a real thing in TFT, and it's a
near-unbeatable board, only topped by an equally-invested 5-cost board. TFT doesn't
achieve that rarity with a hard rule saying "4-costs can only star up once" — it's pool
scarcity (far fewer shared copies of expensive champions) that makes it naturally rare
without needing a mechanical cap at all. **Dropping the "Strong/Legendary capped at 1
level-up" rule entirely** and replacing it with: every tier can reach Rank 3, and the
Shared Joker Pool's small per-Joker copy counts at the top end (Strong ~7 curated
members, Legendary rarer still) are what make actually *doing* it exceptional — the same
mechanism TFT already relies on, not a new one.

Final shape: 5 tiers, each with its own full 3-rank curve, escalating steeply as power
tier increases — matching your explicit anchors (Common Rank 3 ≈ "a little more, maybe
2x," power tier 4 Rank 3 ≈ "much more, like 4x"):

| Power Tier | Multiplier curve (Rank 1 → 2 → 3) |
|---|---|
| Common (1) | 1.0x / 1.4x / **2.0x** |
| Uncommon (2) | 1.0x / 1.6x / **2.5x** |
| Rare (3) | 1.0x / 1.9x / **3.2x** |
| **Strong (4)** | 1.0x / 2.4x / **4.0x** — matches your explicit number |
| **Legendary (5)** | 1.0x / 3.0x / **6.0x** — "stupidly overpowered," pushed further past Strong |

Rare's curve came down from the previous draft's 4.0x-at-Rank-3 to 3.2x, since Strong now
explicitly owns 4.0x and needs to sit clearly above Rare, not tied with it — Rare Rank 3
still lands comfortably above Uncommon Rank 3, just no longer overlapping Strong's ceiling.

**Connects directly to the Shared Joker Pool's small top-end copy counts**, which is
what actually gates this rather than a mechanical rule: if Strong Jokers get roughly
TFT's own 4-cost bag size (TFT: ~10 shared copies per 4-cost champion, out of ~13 unique
4-costs) as a starting reference, then 3-starring a specific Strong Joker means securing
3 of only ~10 total copies shared across up to 8 players — realistically achievable for
maybe one player in a full lobby, exactly matching "3-star 4-cost is a usual game winner,
rare but not impossible." Legendary would sit at an even smaller number (TFT's 5-cost
bag is ~9 copies across only ~9 unique champions). **Not committing to exact pool-size
numbers here** — that's the open item already tracked from the Shared Joker Pool section,
just noting explicitly that it's the same mechanism doing the gatekeeping for both ideas,
so they should be designed together rather than separately.

Does this match what you meant — full 3-rank for every tier, gatekept by pool scarcity
alone rather than a hard cap? That's the interpretation I've implemented; flag it if you
actually wanted Strong/Legendary's Rank-2/3 jump to be steeper *in addition to* keeping
some form of cap, rather than removing the cap outright.

**"Strong" is broader than just repeatable xMult** — your list corrected my mental model.
DNA, Blueprint, Brainstorm, and Invisible Joker are Strong for being independently
build-warping (Blueprint/Brainstorm copy *any* other Joker's ability, DNA permanently
duplicates a card into your deck, Invisible Joker duplicates a random Joker outright) —
none of them are "xMult retriggered multiple times." So the actual governing idea is
closer to **"overpowered in isolation or a broken combo-enabler,"** with repeat-trigger
xMult being the most common pattern, not the only qualifying one. I'm treating your list
as the authoritative classification rather than trying to reverse-engineer one clean
formula from it — recorded below.

**Correcting my own error from last message:** I'd placed Mime and Dusk in Strong. Your
list puts them at **Rare (3)**, not Strong. Re-reading why that's actually right: Mime
only matters when paired with something that gives *held-card* abilities (like Baron) —
it's excellent in a combo but not independently overwhelming, unlike Hack or Sock and
Buskin, which retrigger *played* cards by rank/suit and work in any deck without needing
a specific partner. Baron is the piece that's dangerous on its own; Mime is what makes it
worse, which is a Rare-tier contribution, not a Strong-tier one by itself. Similarly
Seltzer retriggers repeatedly but **self-destructs after a few hands** — bounded, not a
permanent engine — landing at Rare rather than Strong for the same reason.

## Reclassification list (your source of truth, not derived)

| Joker | New `power_tier` |
|---|---|
| Hanging Chad, Mail-In Rebate, Golden Ticket, Photograph | **2 (Uncommon)** |
| Mime, Dusk, Ancient Joker, Bloodstone, The Duo, The Trio, The Family, Obelisk, Driver's License, Vagabond, Baseball Card, Campfire, Hit the Road, The Order, The Tribe, Stuntman, Burnt Joker, Seltzer | **3 (Rare)** |
| Baron, Hack, Sock and Buskin, DNA, Blueprint, Brainstorm, Invisible Joker, **The Idol** | **4 (Strong)** |

*(Confirmed: **The Idol** is a Joker, not the Spectral card I was misremembering — my
mistake, corrected. Exact vanilla effect text still worth a source check when we get to
implementation, but its Strong classification is settled.)*

**Default rule for every Joker not explicitly classified** (resolves what was previously
tracked as a blocking "full pass over ~150 vanilla Jokers"): if a Joker isn't in the
Strong-tier list below or otherwise manually placed, its `power_tier` **defaults 1:1 to
its vanilla rarity** — Common→1, Uncommon→2, Rare→3, Legendary→5. This means the
Strong-tier list is a **curated allowlist, not a required exhaustive audit** — nothing
blocks implementation waiting on a full pass over the vanilla roster. Finding more
Strong-tier candidates (or moving more Uncommons up into Rare, the way the current list
already does for 18 of them) becomes ongoing curation you can do incrementally, same as
adding new custom Jokers.

## Shared Joker Pool (TFT bag mechanic) — sketched, not fully designed

Your extension: if we're already reclassifying by power, we could go further and cap how
many total copies of a given Joker can exist **across the whole lobby at once** — TFT's
bag mechanic, where e.g. 1-cost champions might have ~22-29 shared copies and 5-costs as
few as 9, so contested picks can genuinely run out. This is a great fit conceptually
(makes Ranking up a *contested* resource, not just an independent RNG roll per player)
but it's a real architecture change, not just a numbers table:

- Every player's shop currently rolls from an **independent** probability space (per the
  original multiplayer assumption — 8 players don't compete for the same physical copy).
  A shared bag means shop rolls need to check/decrement a **lobby-wide** counter instead.
- That requires real-time coordination over MPAPI rather than each client rolling
  independently — a materially bigger sync surface than anything in technical.md so far.
- **Race conditions are real**: two clients could both see "1 copy left" and both attempt
  to buy it in the same tick. This needs the same host-authoritative reconciliation
  pattern already established for desync handling — host resolves who actually got it
  (first-request-timestamp, most likely), the loser's purchase gets invalidated/refunded,
  and the UI needs to communicate "someone else got there first" cleanly.
- **Pool sizes, resolved: TFT's own bag sizes, ported directly, per-unique-Joker** (each
  specific Joker gets its own allocation — Baron has its own pool, separate from Hack's —
  exactly how TFT's bag works, not a shared bucket across a whole tier). TFT's numbers
  were already tuned for an 8-player lobby, same as ours, so no player-count rescaling
  needed:

  | Power Tier | Copies per unique Joker (TFT default) |
  |---|---|
  | Common (1) | 29 |
  | Uncommon (2) | 22 |
  | Rare (3) | 18 |
  | Strong (4) | 10 |
  | Legendary (5) | 9 |

  **Exposed behind a single global `pool_size_scaler` multiplier** (defaults to 1.0) per
  your note — every tier's count above gets multiplied by this one value, so a future
  balance pass tightens or loosens scarcity across the board by changing one number
  instead of retuning five. A natural candidate to eventually surface in the Tier 3
  Settings/config surface, not just a hardcoded constant.

**Resolved per your note — snapshot-refresh instead of live-tracked.** Rather than a
continuously-decrementing pool needing real-time coordination, **the pool is only
recomputed at the moment a player opens their own shop**: available copies of Joker X =
(that Joker's total pool size) − (sum of copies currently owned across all alive
players, using state we're already broadcasting for trait-counting). That snapshot
determines what can roll in *that* shop visit. This directly resolves the two things I
was worried about:

- **No continuous sync needed** — this reuses the per-player owned-Joker summary already
  in the broadcast state (technical.md's Player State Schema), just needs the pool-size
  constant added alongside it. No new dedicated real-time messages.
- **No real-time locking** — since nobody's contesting a live-decrementing counter, there's
  nothing to race for *during* a shop visit.

The trade-off you're accepting explicitly: two players who open their shops close
together in time could both see "1 copy left" in their respective snapshots and both get
it offered, occasionally letting both buy it — a harmless, rare **pool overrun** rather
than a hard guarantee. Two ways to handle that rare case, worth your call:

1. **Just let it happen** — no correction, pool briefly reads as "-1 available" until the
   next natural refresh evens it out. Simplest, truest to "don't want to be bogged down
   by race condition items."
2. **Light host-side validation on purchase only** — the host checks the true count at
   the moment of purchase and refunds/blocks the second buyer if the pool's actually
   empty, using the same host-authoritative pattern already built for desync — but
   *only* triggered in this rare collision case, not on every purchase, so it's a much
   lighter version of full real-time locking.

**Confirmed: option 1.** Pool overrun is simply allowed — no host-side validation, no
purchase-time checks, just letting the next snapshot refresh even things out. Simplest
possible answer, zero extra networking or reconciliation logic for what's an
intentionally rare, low-stakes edge case.

## Open items

1. **The 5-tier rank multiplier curve (Common 1.4/1.8x, Uncommon 1.7/2.6x, Rare
   2.2x/4.0x, Strong 2.5x, Legendary 6.0x) is the single highest-uncertainty number set
   in this whole plan** — a defensible first attempt at your described shape, not a
   calculated result. Worth an early priority for playtesting once there's code to test
   against.
2. Whether Ranked Jokers get distinct visual treatment (border/glow, TFT-style) is a
   production/UI question, not addressed here.
3. Whether duplicate odds need their own tuning pass now that Showman's exclusion is
   gone by default for Common/Uncommon — the existing Rarity Pools math in
   architecture.md assumed no duplicates were possible.
4. ~~A full pass over all ~150 vanilla Jokers~~ — resolved, no longer needed: unclassified
   Jokers default 1:1 to their vanilla rarity, Strong-tier is a curated allowlist you can
   grow over time rather than a required exhaustive audit.
5. The Idol's exact vanilla effect text needs a source check (confirmed to be a Joker,
   just not confident in its precise wording from memory).
6. Pool sizes are TFT defaults ported directly (29/22/18/10/9) — not yet sanity-checked
   against Balatro's own deck/shop scale (TFT bags refill between games; Balatro Jokers
   within a single run don't work quite the same way, so "29 copies of a Common Joker
   across one match" may behave differently than intended — worth a close look once
   there's code to test against).
