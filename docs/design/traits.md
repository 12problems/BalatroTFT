# Traits

TFT traits are tags on champions; owning enough champions of a tag crosses a breakpoint
for a scaling bonus. Balatro has no champions, so **Traits here are tags on Jokers**:
own enough Jokers carrying a given tag (duplicates count, same as TFT counts multiple
copies of a champion) and you cross a breakpoint for a passive, permanent-for-the-run bonus.

**Joker slot ceiling matters for this design.** Base Joker slots in vanilla Balatro is 5
(6 with certain vouchers/effects). Any trait whose top breakpoint exceeds that needs an
explicit capacity mechanic, or the top breakpoint is unreachable. Watch for this on every
high-breakpoint trait, not just the ones that already ran into it below.

## Roster (current)

| Trait | Jokers tagged | Breakpoints | Effects |
|---|---|---|---|
| **Financiers** | Economy Jokers | 2 / 4 / 6 | Interest cap → $30 / $50 / $100 (vanilla cap is $25, i.e. max $5 interest/round) |
| **Scholars** | Consumable-synergy Jokers | 2 / 4 / 6 | +1 consumable slot → Tarot/Planet/Spectral -25% price → 25% chance a used consumable isn't consumed |
| **Spades Guild** | Spade-focused Jokers | 2 / 3 | +20 chips when a Spade scores → +40 chips **and** +2 Mult when a Spade scores |
| **Clubs Guild** | Club-focused Jokers | 2 / 3 | +4 Mult when a Club scores → +8 Mult when a Club scores, **and** x1.5 Mult once per hand if 3+ Clubs scored together |
| **Diamonds Guild** | Diamond-focused Jokers | 2 / 3 | +$2 when a Diamond scores → +$3 when a Diamond scores, **and** 25% chance a Diamond isn't consumed when discarded |
| **Hearts Guild** | Heart-focused Jokers | 2 / 3 | Heal 2 life at round end → *(adds)* 50% chance to heal 1 life per Heart scored, capped at 10 healed/round |
| **Multipliers** | xMult-granting Jokers | 2 / 4 / 6 | Your xMult effects apply +20% / +40% / +60% stronger |
| **Scalers** | Jokers that permanently grow/scale over time | 2 / 4 / 6 / 8 / 10 | See below — capacity-gated |
| **Encore** | Retrigger-effect Jokers | 2 / 4 / 6 | See below |
| **Ascendants** | Any Joker that *is* Rare or Legendary rarity (auto-tagged by rarity, not hand-picked) | 2 / 5 / 8 / 10 | See below — capacity-gated |

**Cut:** ~~Gamblers~~, ~~Reapers~~.

### Scalers — expanded to a 5-tier trait

Population (~15-17 candidates) is easily the deepest in the game, so per your call this
became a bigger, more ambitious trait instead of staying at 2/4.

| Breakpoint | Effect |
|---|---|
| 2 | Scaling Jokers accumulate their bonus **2x** as fast |
| 4 | **4x** as fast |
| 6 | **6x** as fast, **and Scaler-tagged Jokers now take up only half a Joker slot each** |
| 8 | **8x** as fast |
| 10 | **10x** as fast |

The half-slot unlock is what makes 8 and 10 physically reachable (5 base slots would
otherwise hard-cap you at 5 Scalers). **I put the unlock at breakpoint 6, not 5** — you
mentioned "5" but 5 isn't one of the reward tiers in a 2/4/6/8/10 progression, and 6 is a
real tier, so I attached it there. Flag it if you actually wanted a non-tier trigger at
exactly 5 owned.

### Encore (retrigger trait — this is "Retriggers" renamed back per your note)

Population ~6 (Hack, Sock and Buskin, Seltzer, Dusk, Hanging Chad, Mime) — tight against
the 6-breakpoint with zero slack, flagged previously, kept at 2/4/6 per your call.

| Breakpoint | Effect |
|---|---|
| 2 | Your first played card and your last played card each retrigger once |
| 4 | Your last played card also gains **x2 Mult** (still just the one retrigger from tier 2) |
| 6 | Every played card retriggers once, **and every played card gains x2 Mult** |

*(Confirmed: "x2" means an x2 Mult multiplier on the card, not a second retrigger.)*

### Ascendants — redefined by rarity membership, expanded to a 4-tier trait

**Membership updated for the 5-tier power system** (see joker-ranking.md): auto-tags any
Joker with `power_tier` **3 (Rare), 4 (Strong), or 5 (Legendary)** — no hand-tagging
needed. Previously this was just Rare+Legendary; Strong is now included too, on the
reasoning that it's a rarer, more curated tier than ordinary Rare and clearly belongs in
the same "owns exceptional Jokers" bucket the trait is built around.

**This isn't just an additive change to the pool — it's a full membership realignment.**
Several Jokers that used to qualify by being vanilla-Rare (Baron, Hack, Sock and Buskin,
DNA, Blueprint, Brainstorm, Invisible Joker, The Idol) still qualify, just via Strong
instead of Rare now. But a large batch of former vanilla-Uncommons got pulled *up* into
our Rare tier in the reclassification pass (Mime, Dusk, Ancient Joker, Bloodstone, The
Duo/Trio/Family/Order/Tribe, Obelisk, Driver's License, Vagabond, Baseball Card,
Campfire, Hit the Road, Stuntman, Burnt Joker, Seltzer — 18 of them), which are all
newly Ascendants-eligible where they weren't before. **Net effect: the qualifying pool is
meaningfully larger than the original ~18**, exactly the kind of thing that could make
the breakpoints (currently 2/5/8/10) too easy to hit.

**Per your instruction, not fully re-solving this now** — flagged as a **deferred full
revisit**, not just a numbers tweak, because more than the breakpoint thresholds may need
to change:
- Breakpoint thresholds likely need to scale up to compensate for the larger pool —
  exact numbers deferred.
- The breakpoint-5 effect ("Legendary Jokers can now appear in the shop, at half Rare's
  odds") is now partly redundant — Legendary already has its own real level-based odds
  column in architecture.md's 5-tier table, independent of this trait, which wasn't true
  when this effect was originally written.
- The tier-8/10 effects reference "Rare shop odds," which no longer means "the top
  tier" the way it did before Strong and the rank system existed — worth reconsidering
  what these effects should even target now.

Everything below this note is the **pre-revisit version**, kept as-is until that
dedicated pass happens rather than partially patched now.

| Breakpoint | Effect |
|---|---|
| 2 | +5% Rare shop odds, +1 Joker slot |
| 5 | +1 more Joker slot (2 total so far); Legendary Jokers can now appear in the shop, at half the odds of Rares; +10% Rare shop odds (15% total); +5% Negative-edition odds |
| 8 | Retrigger all played-card effects, held-in-hand effects, and Joker effects **twice**; Legendary shop odds raised to match Rare odds; +5% Negative-edition odds (10% total) |
| 10 | **x10 Mult** on all scored cards |

**No artificial slot-halving mechanic** (removed per your call) — 8 and 10 Ascendants are
meant to be *hard*, RNG-gated by luck, not guaranteed through investment alone. The
capacity actually resolves itself through a vanilla rule already baked into the trait:
**Negative-edition Jokers don't take up a Joker slot at all, and separately grant +1 slot
each.** Since Ascendants' own breakpoints push Negative odds up to 10%, a run where the
RNG blesses you with several Negative Rare/Legendary Jokers can organically blow past the
normal slot ceiling "for free," while an unlucky run simply can't reach 8-10 — exactly the
"very hard to pull off, extremely strong when the stars align" feel you're going for.
*(Flagging the underlying assumption — that Negative Jokers are slot-free and slot-granting
in vanilla — in case that's changed or I'm misremembering; worth a quick verification
against current game code before this ships.)*

## Population audit

| Trait | Natural vanilla candidates (rough) | Verdict |
|---|---|---|
| Financiers | ~10-12 | Healthy. |
| Scholars | ~7-8, **now ~10-11** | ✅ Buffer authored — see [new-jokers.md](new-jokers.md). |
| Spades/Clubs/Diamonds/Hearts Guilds | ~1 dedicated each (Wrathful/Gluttonous/Greedy/Lusty Joker), **now ~5 each** | ✅ Content debt closed — 4 new custom Jokers per Guild authored, see [new-jokers.md](new-jokers.md). |
| Multipliers | ~12-14 | Very healthy. |
| Scalers | ~15-17 | Best-populated trait in the game — comfortably supports the new 5-tier structure. |
| Encore | ~6 | Exactly meets the 6-breakpoint, no slack. |
| Ascendants | ~18 (all Rare+Legendary Jokers, by the new membership definition) | Healthy after redefinition. |

## Multi-Trait Jokers

TFT champions commonly carry 2+ traits, which is where a lot of its deckbuilding
combinatorics comes from. Everything we'd tagged so far was single-trait. Two things
worth separating here: **what already gets us most of the way there for free**, and
**what still needs deliberate tagging**.

**Already solved, mostly by accident:** Ascendants auto-tags by rarity, not by hand — so
*every* Rare or Legendary Joker we've designed or will design is automatically
Ascendants **on top of** whatever "normal" trait(s) it has. Pike Commander (Spades,
Rare) is already Spades + Ascendants. Kimberley Baron (Diamonds, Rare) is already
Diamonds + Ascendants. The Cudgel, Nurse's Aide, The Archivist — all already 2-trait
pieces the moment they're Rare, with zero manual tagging. This wasn't designed for that
purpose but it directly answers the question for the entire upper half of the rarity
curve.

**Needs deliberate tagging for everything else** (Common/Uncommon Jokers, or stacking a
*third* tag onto an already-Rare one). The data model already supports it — a Joker's
`trait_tags` field is a list, not a single value, so this is a content decision, not a
technical one. A few concrete ones to lock in now:

| Joker | Rarity | Existing tag(s) | New tag | Why |
|---|---|---|---|---|
| Bloodstone *(vanilla)* | Rare | *(none yet)* | **Hearts Guild + Multipliers** | "Each played Heart has a 1-in-2 chance to give x1.5 Mult" is genuinely both — heart-triggered *and* xMult. Also corrects the Hearts Guild population count: the natural vanilla pool is 2 (Lusty Joker + Bloodstone), not 1. |
| Pike Commander | Rare | Spades Guild, *(Ascendants, automatic)* | **+ Scalers** | It permanently accumulates +3 Chips per Spade scored — a real fit for Scalers' "grows over time" definition, not just a flavor gesture. Becomes a 3-trait piece: Spades + Ascendants + Scalers. |
| Kimberley Baron | Rare | Diamonds Guild, *(Ascendants, automatic)* | **+ Financiers** | Its own effect (permanently raising the interest cap) *is* Financiers' domain. Becomes Diamonds + Ascendants + Financiers. |

**Deliberately not tagging** The Cudgel with Scalers despite its own note about "possible
scaling synergy" — it's a static conditional (x1.2 Mult if the last hand has a Club), not
something that accumulates, so it doesn't actually fit Scalers' definition. Flavor text
suggesting scaling isn't the same as a mechanic that scales — didn't want to tag it just
because it sounds thematically close.

**Going forward:** aiming for roughly 15-25% of Common/Uncommon trait-Jokers to carry a
second tag (keeping most as "pure" single-trait pieces, same as most TFT champions), with
Rares getting their automatic Ascendants tag as a baseline plus an occasional deliberate
third. Multi-trait Jokers should generally be a little weaker for their rarity than a
single-trait piece would be, to pay for their combinatorial value — same principle TFT
uses to keep flexible multi-trait champions from just being strictly better.

## Still open

0. **Ascendants needs a full revisit** (breakpoint thresholds, the tier-5/8/10 effect
   text) now that the 5-tier power system exists — explicitly deferred, not forgotten.
   Membership itself is already updated (Rare/Strong/Legendary). See the note above.
1. Scalers half-slot unlock at tier 6 vs. a literal "at 5 owned" trigger — not yet confirmed.
2. Encore top breakpoint (6) has zero population slack — keep as aspirational "collect them all," drop to 5, or plan buffer Jokers?
3. ~~Scholars/Suit Guilds need new custom Jokers authored~~ ✅ done — see [new-jokers.md](new-jokers.md).
4. Verify in-code that Negative-edition Jokers are still slot-free + slot-granting in the current Balatro version — Ascendants' 8/10 breakpoints depend on this vanilla behavior.
