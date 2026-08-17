# New Custom Jokers

Content debt tracked since the Traits population audit ([traits.md](traits.md)): the four
Suit Guilds only had ~1 natural vanilla Joker each (the classic Wrathful/Gluttonous/
Greedy/Lusty quartet), nowhere near enough to reliably hit even a 2-breakpoint. This is
the first pass at closing that gap — 4 new Jokers per Guild (16 total) plus a 3-Joker
buffer for Scholars, which was merely "thin," not broken.

Rarity/cost follows vanilla convention (Common ~$4-6, Uncommon ~$6-8, Rare ~$8-10). Suit
Guild Jokers deliberately **don't** all copy their vanilla counterpart's exact flavor
(chips/mult/money/utility are all fair game) — they just need to plausibly "care about"
the suit, since the trait tag is what matters for breakpoints, not effect uniformity.

## Spades Guild (+3, bringing the pool to 4)

| Joker | Rarity | Cost | Effect |
|---|---|---|---|
| Ace of Spades | Uncommon | $4 | Spade Aces give +200 Chips when scored |
| Spade Fisher | Common | $5 | +5 Mult if the played hand contains 3+ Spades |
| Pike Commander | Rare | $8 | Spade cards permanently gain +3 Chips each time they're scored (stacks across ALL spade cards, scaling flavor — also a Scaler-eligible design, which is fine, cross-trait membership is normal) |

## Clubs Guild (+3, bringing the pool to 4)

| Joker | Rarity | Cost | Effect |
|---|---|---|---|
| Lucky Clover | Common | $4 | 1-in-4 chance a scored Club gives +$2 |
| Clover Field | Uncommon | $6 | If 3+ Clubs are held in hand at round end, gain +1 discard next round |
| The Cudgel | Rare | $8 | Gains x1.2 Mult if the final hand played this round contains a Club (also a possible scaling synergy) | 

## Diamonds Guild (+4, bringing the pool to 5)

| Joker | Rarity | Cost | Effect |
|---|---|---|---|
| Petty Thief | Common | $4 | Playing a pair of diamond cards gives you $3 |
| Diamond Dealer | Common | $5 | End of round: +$1 per Diamond held in hand (held, not scored) |
| Appraiser | Uncommon | $6 | Selling a Joker while holding 2+ Diamonds in hand gives +200% sell value |
| Kimberley Baron | Rare | $9 | Selling this joker permanently increases interest cap by the amount of diamonds held in hand when sold. (stacks with Financiers trait and the Compound Interest augment) |

## Hearts Guild (+2, bringing the pool to 5) (bloodstone is a heart synergy)

| Joker | Rarity | Cost | Effect |
|---|---|---|---|
| Field Medic | Common | $4 | Heal 1 life when a Heart scores, capped at 3 heals/round (uncapped healing burned us once already on the trait itself — not repeating that mistake here) |
| Cardiologist | Uncommon | $6 | Heal 2 life at the end of every round |
| The Nurse's Aide | Rare | $9 | Once per stage, reduce incoming PvP damage by 5 flat |

## Scholars buffer (+3, bringing the pool to ~10-11)

| Joker | Rarity | Cost | Effect |
|---|---|---|---|
| Apprentice Scribe | Common | $5 | 1-in-5 chance a used Tarot/Planet/Spectral card isn't consumed |
| Curator | Uncommon | $6 | Tarot/Planet/Spectral shop prices -$1 (floored at $0) |
| The Archivist | Rare | $8 | At the start of each PVP round, create a negative copy of a random planet, random tarot, and a random spectral card |

## Updated population estimates

| Trait | Old pool | New pool | Verdict |
|---|---|---|---|
| Spades/Clubs/Diamonds/Hearts Guilds | ~1 each | **~5 each** | Comfortably supports the 2/3 breakpoint structure now — a single run has real odds of collecting 2-3 without needing every copy of the one legacy Joker. |
| Scholars | ~7-8 | **~10-11** | Top breakpoint (6) now has real slack instead of being thin. |

Still first-pass — flavor text, art, and exact numbers all need a balance/playtesting look
once these exist in code, same as everything else numeric in this plan.
