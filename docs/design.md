# Lucky Larry: Design

Living document. Numbers are placeholders until we tune them by playing.

## Vision
A darkly funny gambling life sim in Las Vegas. Simple mobile game, not cutting-edge graphics or physics, but energetic and hard to put down.

- **Look (Clash of Clans):** cartoony, colourful, isometric top-down. Larry walks the map and enters places. Gambling is shown on screen (the wheel spins, the cockroaches race).
- **Day to day (simulator games):** every activity is hands-on: spin the wheel, wash the dishes, train the cockroach.
- **Long term (Travian):** build an "empire": better home, investments that earn over time, reputation.
- Endless life sim, no story. Fixed character. Prototype with ready-made asset packs.
- Languages: English + Turkish.

## World
Bright Strip mixed with dirty back streets. Larry starts in the back streets, climbs to the Strip when winning, falls back when losing.

**Back streets:** Motel (home), Pawn shop, Sports betting shop, Illegal animal races (garage: cockroaches, chickens, turtles; police raid risk), Vinnie's (back room of a laundromat), Diner (dishwashing job).

**Strip:** Casino (roulette, blackjack, slots), Private poker nights (hotel penthouse, invitation only), Luxury shops and clubs (spending, hanging out).

## Characters
- **Lucky Larry:** overconfident, full of excuses, somehow likeable.
- **Vinnie:** loan shark, always polite, always scary.
- **Joey:** Vinnie's nephew and collector.
- **Sal:** pawnbroker, says everything is junk.
- **Dolores:** croupier who has known Larry for years and now pities him.
- **Eddie:** Larry's gambling buddy, always has a "sure tip" that never works.
- **Tiny:** casino bouncer.

## Dress code
Outfit level gates the Strip, checked by Tiny.
- Tracksuit: back streets only.
- Second-hand blazer (~$80): casino floor.
- Suit (~$400): penthouse poker (also needs an invitation).
- Implemented: Tiny turns Larry away from the casino without a blazer. Suit gate comes with poker nights.
- The blazer is a sellable item. Selling it to bet and then getting turned away at the casino is intended.

## Vinnie
- Loans have a due date (e.g. 5 days, +20%). A text the day before: "See you tomorrow. Uncle Vinnie."
- On the due day Joey appears on the map and walks toward Larry. Options:
  1. **Pay** in full or in part (partial buys a few days on the rest).
  2. **Negotiate** (below).
  3. **Collateral:** Vinnie takes an item at half its value.
  4. **Run:** short chase on the map. Escape = +1 day. Caught = one step up the ladder.
- **Negotiation:** Larry picks one of 3 lines, Vinnie counters ("2 more days, 15% more"), Larry can push back ("3 days, 10%"); push too hard and Vinnie walks away.
  - "Sure tip, I'll double it tomorrow": depends on Vinnie's mood.
  - "My mom's in hospital": works once. Second time: "Your mom was in hospital last month, Larry."
  - Flattery: small but safe gain.
- **Reputation with Vinnie:** paying on time raises it, lies and running lower it. High = bigger loans, softer deals. Low = cash up front.

### Patience ladder (one step per missed deadline)
1. **Reminder:** Joey "says hi from uncle" and takes the cash in Larry's pocket.
2. **Property:** an item vanishes from the motel room. Note left: "Thanks. V."
3. **Favours:** work off debt with missions: walk Vinnie's aggressive poodle, drive a car with a suspicious trunk to the desert, fix a cockroach race.
4. **Shadow:** Joey follows Larry everywhere; bouncers won't let him in.
5. **Desert trip:** Larry wakes up in the desert in his underwear with a shovel. All cash and items gone, debt wiped. Not game over: he starts again from the bottom.

## Motel room
- Tapping the motel takes Larry inside. Every item he owns is in the room (iron on its board, TV playing horse races, the car outside the window...).
- Sold items leave a dusty outline. Items Vinnie's people took leave a sticky note: "Thanks. V."
- Calendar on the wall circles rent day. Sleeping happens here.

## Pawn shop (Sal)
- Larry chooses which item to sell (no fixed order). Sal also has a clothes rack: blazer $80, suit $400.
- Selling an item puts it on Sal's shelf. Larry can buy it back for +50% of what Sal paid.
- Sal keeps it for 5 days, then sells it to a tourist.
- Items taken by Joey (collateral, ladder step 2) or lost in the desert trip are gone for good.

## Roach derby (back-alley garage)
- 5 roaches per race, each with a speed (2-7). Win chance ~ speed², odds = 0.85 / chance (house edge).
- Bet on any number of roaches; a new field after every race. 8% police raid: all bets lost.
- Stable (first investment): buy your own roach ($150, speed 3), train once a day ($20, +1 speed, 25% it watches TV instead), enter it once a day ($25). If it wins, purse = $120 + speed × 10.

## Betting shop (Lucky Shot Bets)
- Smoky shop with a TV. Tap a team to bet the chosen chip; the match plays live on the TV (clock, score bug, GOAL! flashes) with a score that agrees with the result.

## Game over
Only eviction: can't pay rent, ends up on the street.

## First release scope
One neighbourhood (motel, pawn shop, betting shop, Vinnie), one casino with roulette, first investment: cockroach stable. Everything else after.
