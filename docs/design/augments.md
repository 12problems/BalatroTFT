# Augments

Offered at 3 checkpoints per match (Stages 2/4/6). Choice of 1-of-3, permanent for the
rest of the run. **Tier at each checkpoint is rolled, not guaranteed** — see
[architecture.md](architecture.md#augment-tier-odds-supersedes-the-earlier-guaranteed-silvergoldprismatic-assumption)
for the real TFT-sourced conditional odds table (Checkpoint 1 defaults toward Gold,
Checkpoint 3 rarely offers Silver at all). The category/tier breakdown below still holds
either way — every augment still needs a tier label, it's just no longer true that
Checkpoint 1 = Silver / Checkpoint 2 = Gold / Checkpoint 3 = Prismatic by default.

## Category map (8 total)

1. **Economic** — gold, interest, rerolls, streaks ✅ drafted, revised
2. **Combat & Stats** — mult, chips, hand size, hands/discards per round ✅ drafted, revised
3. **Shop & Items** — odds, guarantees, vouchers, reroll mechanics ✅ drafted, revised
4. **Trait & Emblem** — grant/boost trait breakpoints directly (TFT's literal "Emblem" items) ✅ drafted
5. **Deck & Cards** — add/remove/enhance specific cards, deck thinning ✅ drafted
6. **Utility & Information** — extra slots, scouting opponents, QoL ✅ drafted
7. **Risky & Situational** — high-risk/high-reward, conditional triggers ✅ drafted
8. **Defensive & PvP** — life total, damage mitigation, opponent interaction ✅ drafted

---

## 1. Economic

**Silver**
- *Nest Egg* — Gain **$50** immediately.
- *Tip Jar* — +$1 every time you play a scoring hand.
- *Rainy Day Fund* — Once per stage, if you'd hit $0, gain **$10** grace.

**Gold**
- *Bargain Bin* — Reroll cost -$1 (min $1). *(moved from Silver)*
- *Compound Interest* — Interest **rate** doubles: earn **$2 per $5 saved** (still capped at the vanilla $25 savings threshold → max $10/round instead of $5). No change to the cap itself.
- *Loan Shark* — Can go into debt down to **-$25** on rerolls/purchases. No other drawback (interest is no longer affected).
- *Portfolio Diversification* — +1 Joker slot / -1 consumable slot (or the reverse — your pick at augment time).
- *Golden Touch* — Every 3rd shop reroll is free.

**Prismatic**
- *Fire Sale* — Reroll cost **-$2** (min $1). *(the prismatic version of Bargain Bin)*
- *Monopoly* — Pick a rarity: its shop odds double, all others halve, for the rest of the match.
- *Everything's For Sale* — All shop prices -25%. *(no other drawback — removed the reroll-cost-scaling penalty)*
- *Print Money* — Gain **$1 for every card scored** (across all hands played this round), but starting money is halved this run.
- *The House Always Wins* — Winning a PvP round grants $1 for every 5% your score exceeded your opponent's by, **capped at $50 per round**. *(percentage-based so it scales sanely whether scores are in the hundreds or the millions — flag if you'd rather this be a flat points-per-dollar ratio instead)*

---

## 2. Combat & Stats

Pure scoring-power and hand-economy augments. Consumable- and deck-modification augments
are deliberately excluded here — those live in category 5 (Deck & Cards) and get
addressed after we've covered consumables/deck-building separately, per your note.

**Silver**
- *Warm Up* — +1 hand played per round (permanent).
- *Steady Hands* — +1 discard per round (permanent).
- *Growth Spurt* — +1 hand size (permanent).
- *Fundamentals* — Every time a card is played and scores, it **permanently** gains +1 Chip and +1 Mult, stacking each time that specific card scores again (uncapped, same precedent as the vanilla Hiker Joker). ~~First Impressions~~ *(removed)*

**Gold**
- *Level Up* — Each blind, the first hand type you play **permanently** gains +2 levels — confirmed intentional despite the large raw total by game's end: hand levels have steeply diminishing *proportional* impact as they climb, so keeping this permanent is what keeps it meaningful late-game instead of trailing off into irrelevance. Strategically this means players will tend to always open with the same hand type to concentrate the leveling.
- *Encore Performance* — Play the same poker hand type twice in a row to gain +1 hand that round. Triggers once per distinct hand type per round (chaining a different hand type back-to-back can trigger it again).
- *Iron Will* — +2 hand size, but -1 discard per round.
- *Adrenaline* — On your final hand of the round, if your score is behind your opponent's, all played cards retrigger once. *(PvP-native — during non-PvP rounds there's no opponent score to compare against, so I'm defaulting to comparing against the blind's chip requirement instead, so the augment still does something outside PvP rounds. Flag if you'd rather it simply never trigger in PvE.)*

**Prismatic**
- *Grand Astronomer* *(renamed from Grand Slam)* — Grants **10 levels to every poker hand type**, including secret hands (Five of a Kind, Flush House, Flush Five) you haven't discovered yet — which this also unlocks/reveals as a side effect, since they need to exist in your level table to hold a level at all.
- *Unstoppable* — +2 hands played, +2 discards, **and +2 hand size** per round. *(Downside removed per your note — no chip-requirement penalty anymore.)*
- *Perfect Game* — Beat a non-PvP blind by scoring **exactly** the chip requirement (not a single chip over) to immediately choose a permanent bonus effect from a small pool, picked at the moment you trigger it. **Reward pool not designed yet — open item, flagged below rather than guessed at.**

---

---

## 3. Shop & Items

General shop-manipulation augments — odds, pricing, rerolls, slot count. Deliberately
staying rarity/economy-general here; trait-specific shop manipulation (e.g. "guaranteed
Financier in shop") belongs in category 4 (Trait & Emblem) instead.

**Silver**
- *Frequent Buyer* — Every 5th shop purchase (any item type — Joker, consumable, voucher, pack) is 50% off.
- *Clearance Rack* — All Common-rarity shop items are 50% off.

**Gold**
- *Second Look* — +1 **shop** slot (an extra Joker/consumable card appears in the shop). *(moved from Silver)*
- *Pack Rat* — Booster packs always offer 1 extra card choice.
- *Reroll Refund* — Reworked: rerolls always cost money when used, so "refund unused spending" didn't make sense. Now: **at the end of each stage, gain back 25% of all money spent on rerolls during that stage.**
- *Extra Pocket* — +1 **consumable** slot (carrying capacity for Tarot/Planet/Spectral cards — distinct from the shop-slot effects above).
- *Omen Globe* — Literally grants the player the real, vanilla **Omen Globe voucher** — no reimplementation, whatever that voucher natively does is what happens. Since Vouchers are level-up rewards in this mod rather than shop RNG, this is a way to hand out a specific strong one directly. **This is the pattern going forward:** any future augment whose effect is "give the player a voucher" should grant the actual vanilla voucher object, not a restated/hardcoded copy of its effect — keeps it accurate for free and never goes stale if vanilla balance changes.

~~Guaranteed Rare~~ *(removed — too strong)*, ~~Direct Deposit~~ *(removed)*

**Prismatic**
- *Vintage Collection* — Reworked to fire **once per shop visit** (i.e. once per blind you see a shop after), not once per stage, and rerolling within that same visit doesn't grant a second copy of the effect: one Joker slot offers a rarity tier above what your level odds allow.
- *The Big Score* — Your next reroll is guaranteed to surface a Legendary-rarity item. One-time use, consumed the moment it triggers.
- *The Whole Store* — +1 consumable slot, +1 shop slot, **and** +1 booster pack slot (an extra pack appears in the shop), all at once.
- *Double Pack* — Buying a booster pack opens **2 packs of that type** instead of 1. *(replaces Everything Twice, which doesn't map onto how Balatro's shop actually works)*

---

## 4. Trait & Emblem

TFT has both generic trait augments (Hearts/Emblems/Crests that any trait can slot into,
player picks the target trait) and a handful of bespoke augments built around one specific
trait's fantasy. Following the same split here: a small generic toolkit that works across
the whole roster, plus bespoke ones for **Scalers** and **Ascendants** specifically, since
their bigger breakpoint curves (5-tier and 4-tier) create the richest design space for
this. Other traits can get their own bespoke entries in a later content pass — same
"tracked debt" status as the Suit Guilds needing new Jokers.

**Generic (choose the target trait when picked/triggered)**

Whenever one of these says "choose a trait," the player picks from **a random subset of 4
traits** rolled at that moment — not the full roster. Keeps it from being an auto-pick of
whatever the objectively strongest trait happens to be every time.

- *Apprentice's Charm* (Silver) — Choose 1 of 4 randomly offered traits, and one Joker you own; that Joker also counts as having the chosen trait. The tag stays attached to that specific Joker — sell it, and the bonus goes with it.
- *Trait Heart* (Gold) — Choose 1 of 4 randomly offered traits; your count toward it is treated as **+2 higher** than what you actually own, for breakpoint purposes only.
- *Grand Emblem* (Prismatic) — Choose 1 of 4 randomly offered traits, **drawn from a pool that never includes Ascendants or Scalers** — every Joker you currently own **or acquire for the rest of the run** counts as having the chosen trait. *(Ascendants and Scalers excluded: Ascendants is defined by actual Joker rarity, not an arbitrary tag, and Scalers' bonus only means something on a Joker that actually has a scaling effect to accelerate — granting either as a free tag would be incoherent or exploitable.)*

**Scalers-specific**

- *Momentum Keeper* (Gold) — Scaling Jokers never lose their accumulated bonus, even from effects that would normally reset them (e.g. Obelisk, Castle).
- *Critical Mass* (Prismatic) — The Scalers half-slot unlock (normally requires 6 owned) instead applies starting from your **very first** Scaler.

**Ascendants-specific**

- *Lucky Star* (Gold) — The next Rare or Legendary Joker you obtain is **guaranteed** to roll Negative edition. One-time use, consumed on trigger.
- *Cosmic Alignment* (Prismatic) — Negative-edition odds **on Rare and Legendary items specifically** (including Ascendants' own trait bonus) are **tripled** for the rest of the match — no longer touches Common/Uncommon odds. *(Leans further into the intended RNG-gamble fantasy rather than removing it — higher variance, not a guarantee.)*

~~Ascended Crest~~ *(removed — doesn't generalize cleanly across the roster: some breakpoint effects, like Ascendants' "Legendaries can appear in the shop" or Scalers' half-slot unlock, don't have a sane meaning when "applied twice.")*

---

## 5. Deck & Cards

Physical playing-card manipulation — enhancements, editions, seals, suits, removal,
duplication. Distinct from Combat & Stats (which is pure scoring/hand-economy) and from
Trait & Emblem (which is about the Joker trait system).

**Silver**
- *Thin the Herd* — Remove **10** random cards from your deck.
- *Lucky Break* — Randomly select **5** cards in your deck that **don't already have an Enhancement**; each gains a random Enhancement.
- *Fresh Coat* — Randomly select **3** cards in your deck that **don't already have an Edition**; each gains a random Edition, using the **same weighting the vanilla Aura Spectral card uses**. *(Recommend implementing this by literally calling Aura's own weighting logic rather than re-deriving the odds independently, same reasoning as the Omen Globe voucher pattern — never drifts from vanilla. Need to confirm Aura's exact weights against current game source before this ships.)*
- *Seal the Deal* — *(moved down from Gold)* Randomly give **4 different cards** in your deck one each of the four Seals (Red, Blue, Gold, Purple) — fully random, no player choice.
- *Reshuffle* — Every card in your deck is randomly reassigned to a **different rank and suit**. Existing Enhancement/Edition/Seal on each card are untouched.

**Gold**
- *Deck Surgeon* — Remove any **5** cards of your choice from your deck (player-picked, not random).
- *Card Shark* — Grants **5 copies of the Aura Spectral card, each with the Negative edition** (a Negative consumable isn't consumed when used, per vanilla rules). *(Two open implementation questions: (1) confirming Negative still means "not consumed on use" for consumables in the current game version — same category of assumption as the Ascendants/Negative-Joker note earlier; (2) what happens if the player doesn't have 5 free consumable slots to receive them — needs a decision, not guessed at here.)*
- *Seal Artisan* — The player-choice counterpart to Seal the Deal: choose up to 4 cards in your deck and assign each a Seal of your choice (can repeat Seal types).
- *Suit Yourself* — *(moved down from Prismatic)* Choose a suit; every card in your deck becomes that suit.
- *Odd Couple* — Every card in your deck is randomly reassigned to be either a **2 of Clubs** or a **Queen of Hearts** (assuming ~50/50 per card — flag if you want a different split). Existing Enhancement/Edition/Seal untouched.

**Prismatic**
- *Alchemist's Dream* — Every card in your deck that **doesn't already have an Enhancement** is randomly given one, **independently per card** — not the same Enhancement across the whole deck.
- *Gilded Deck* — Every card in your deck is randomly given an Edition, independently per card. *(Unlike Fresh Coat/Alchemist's Dream, this one does **not** exempt cards that already have an Edition — the Prismatic "brute force" version, can overwrite. Flag if you'd rather it respect existing Editions too, for consistency.)*
- *Everything's Wild* — Every card counts as every suit for all scoring and Joker checks. **Implemented as a global suit-equivalence rule** — the same technique the vanilla Smeared Joker uses to merge Hearts/Diamonds and Spades/Clubs, extended to all four suits at once — rather than applying the literal Wild Card Enhancement to every card, so it never overwrites or conflicts with a card's existing Enhancement.
- *King's Court* — Every card in your deck becomes the **King of Hearts** (rank and suit only). *(Assuming Enhancement/Edition/Seal are preserved per-card, same rule as Reshuffle — you didn't restate it for this one specifically, flag if you actually want it to wipe those too.)*

---

## 6. Utility & Information

Slot-granting augments already live in Shop & Items (Second Look, Extra Pocket, The Whole
Store), so this category stays focused on **scouting/information** and **QoL** effects
that don't fit anywhere else. TFT itself keeps scouting mostly free (tab to see anyone's
board anytime), so these lean into privileged information *beyond* that baseline rather
than re-granting something already free.

**Silver**
- *Early Warning* — See your next **2** PvP opponents in the round-robin pairing order, instead of just the next 1.

~~Price Check~~ *(removed)*, ~~Second Opinion~~ *(removed — redundant: augment offers already include 1 free reroll of the 3 choices as a base UI feature, not something that needs its own augment. Noted as a locked baseline mechanic in [README.md](README.md).)*

**Gold**
- *Open Book* — Freely scout **any** player's full board/Joker lineup at any time, not just whoever you're currently paired against.
- *Danger Sense* — Before each PvP round begins, see your opponent's current life total and their total Joker count/rarity breakdown.
- *Free Sample* — The first consumable you use each round isn't consumed — it returns to your inventory afterward.

**Prismatic**
- *Open Hand* — During PvP rounds, see your opponent's hand, their active Jokers, and their hands/discards remaining, live.

~~Crystal Ball~~ *(removed — doesn't make sense in a PvP-centric mod)*, ~~Mulligan~~ *(removed — too complex to implement cleanly)*

*(Implementation note: Open Book, Danger Sense, and Open Hand all require broadcasting more player state over MPAPI than bare score-comparison needs — architecturally fine, since `player_state` is designed for arbitrary payloads, but worth flagging as extra bandwidth/state surface to design for.)*

*(This category is now thin — 1 Silver, 3 Gold, 1 Prismatic. Fine to leave uneven across categories; flag if you want it padded back out later.)*

---

## 7. Risky & Situational

Real trade-offs — a genuine downside attached to real upside, or a payoff that only
lands if a specific condition is met. This is the category TFT uses to punish
one-size-fits-all "just take the best augment" thinking, so nothing here should be a
strictly-better pick with no cost or no risk of whiffing entirely.

**Silver**
- *All In* — +**$50** immediately, for the cost of **1 hand size**.
- *Speed Round* — +1 hand played per round, but -1 discard per round.
- *Glass Cannon* — **x2 Mult** on every hand, but if you ever fail to clear a blind, you lose an extra life beyond the normal loss. *(Bumped from +15% additive to a full x2 multiplier — a flat +15% would've been weaker than Polychrome's baseline x1.5 on a single card, which felt wrong for a dedicated risk pick.)*

**Gold**
- *Double or Nothing* — Immediately wager half your current money: 50% chance to double the wagered amount, 50% chance to lose it. One-time, resolved the moment you pick it.
- *Boom or Bust* — Your first hand played each round scores **x3 Mult**, but every hand after the first that round scores **-25% Mult**.
- *Overdraft* — Immediately gain $40, but at the end of every future round, pay $3 upkeep (stacks with normal shop spending — doesn't stop until the match ends).

~~Short Fuse~~ *(removed)*

**Prismatic**
- *All or Nothing* — Permanent **x10 Mult** on every hand, but if you're ever eliminated, you're eliminated instantly regardless of remaining life (no grace, no "Second Wind"-type saves apply).
- *High Roller* — Every PvP round becomes winner-takes-all: the loser's money is halved and given to the winner (capped at **$100** transferred), on top of normal life loss.
- *Point of No Return* — Choose a single poker hand type; you can no longer play any other hand type for the rest of the match. **Reworked reward, since locking your entire run to one hand type wasn't adequately compensated by the original +5 levels/2x scaling:** it now permanently gains **20 levels** immediately, scales **5x** as fast for the rest of the run (up from 2x), and any card that scores as part of it is **immune to boss-blind debuffs**. *(First pass at "big enough" — compensating for a full-match hard-lock is hard to size blind, so treat this as a starting point to react to rather than a final number.)*

---

## 8. Defensive & PvP

Life total, damage mitigation, and direct opponent interaction. This is the category
that most needs the final PvP damage formula locked down before numbers here can be
fully trusted — everything below is written against the "life total + scaling damage"
model from the architecture doc, but the actual damage-per-loss formula is still an open
item, so treat percentages here as provisional until that's nailed down.

**Silver**
- *Thick Skin* — Reduce all incoming PvP damage by 10%.
- *Padded Walls* — The first time you'd take PvP damage each stage, reduce that instance by half.
- *Steady Heart* — Heal 3 life at the end of every stage (independent of the Hearts Guild trait — stacks with it).

**Gold**
- *Counterpunch* — When you win a PvP round, deal a small amount of bonus damage beyond the normal formula, scaled to how badly you beat your opponent.
- *Iron Wall* — Reduce all incoming PvP damage by 20%, but reduce all outgoing PvP damage you deal by 10% too (a real defensive trade-off, not a free upgrade on Thick Skin).
- *Second Wind* *(the classic TFT-style "survive lethal once" augment, mentioned back in the very first preview list — formally slotting it in here)* — The first time you would be eliminated, survive at 1 life instead. Once per match.

**Prismatic**
- *Vampiric* — Winning a PvP round heals you for a percentage of the damage you dealt.
- *Fortress* — Reduce all incoming PvP damage by **50%**, and ghost-board rounds (odd-lobby byes) never deal you damage even if you'd lose to the ghost.
- *An Eye for An Eye* — Once per match, when you lose a PvP round, instead of taking damage, **redirect that damage to your opponent instead** (you take none, they take what you would have).

---

*(All 8 augment categories now drafted. Full content status in [README.md](README.md).)*
