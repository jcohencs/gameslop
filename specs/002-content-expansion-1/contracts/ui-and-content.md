# Contract: Player-Facing UI and Content

## Hideout: ORDERS tab

- The tab title is `ORDERS (n ready)`, where n is the number of orders the stash can fill now.
- Each order tile shows: title, reward, the qualifying stash cards (count you have / count needed),
  and a button:
  - `FULFILL +$X` when it can be filled;
  - disabled `NEED n MORE` when it can't;
  - disabled `FILLED` once done.
- A footer says: "New orders after every raid."

## Deploy tab

- Pizza Party Palace tile: name, danger 2, loot pips, timer 5:00, 12 kids, guard "Cheesy the Rat",
  entry $25, and a description that mentions the ball pit.

## Trade screen

- Five tactics in table order (junk, sticker, bundle, sob, ufo). Each shows odds %, cost text and
  heat level.
- Bundle Deal's cost text: "Costs 3 junk cards". Sob Story's: "Free · no heat · never cries".

## Raid HUD

- Under the timer: the modifier name and a one-line description (for example "BAKE SALE: adults
  are distracted (-30% sight)").
- Start message: "Raid started at X. Modifier: NAME. A WHALE is here!"
- The Whale kid's label: "WHALE — <name>" with a gold color, and a gold glow in the world.
- In the ball pit: the prompt area shows "HIDING IN THE BALL PIT".
