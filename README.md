# Card Shark: Playground Hustle

A goofy low-poly 3D Godot 4 game. You're a shady card dealer working a school playground: "trade" kids out of their best trading cards, flip them at your Shady Van, buy upgrades and guns, and fight off the angry parents who show up when a kid cries.

![screenshot](screenshot.png)

## Running

1. Install [Godot 4.3+](https://godotengine.org/download) (standard build, not .NET).
2. Open Godot → **Import** → pick this folder's `project.godot`.
3. Press **F5** (Play).

All art is built from primitive shapes in code, so there are no asset files to import.

## Controls

| Key | Action |
| --- | --- |
| WASD | Move |
| Shift | Sprint |
| Space | Jump |
| Mouse | Aim |
| Left click | Shoot |
| R | Reload |
| 1-4 | Switch guns |
| E | Trade with a kid / open the van shop |
| Esc | Pause / close menu |

## How to play

- **Scam kids.** Every kid has a card floating above their head, color-coded by rarity (Common → Uncommon → Rare → Holo → Legendary). Walk up and press **E** to pick a tactic:
  - *"Super rare" junk card*: costs 1 junk card. Decent odds, low heat.
  - *Holo-sticker forgery*: costs 1 junk card + 1 sticker. Great odds, very low heat.
  - *"Is that a UFO?!"*: free, but the kid always cries.
  Rarer cards are harder to scam.
- **Heat.** Scams raise heat (shown top-left, 0-5 levels). Each crying kid sends a parent after you, and tougher parents show up at higher heat: Soccer Moms, Angry Dads, PTA Presidents, Gym Coaches. At max heat the **PTA raids**.
- **Fight back.** Shoot the parents. When you knock one out you loot their wallet.
- **Shady Van shop.** Sell your cards, restock junk cards and stickers, heal, and buy:
  - Upgrades: Silver Tongue (scam odds), Light-Up Sneakers (speed), Fat Binder (card capacity), Puffy Vest (HP), Shady Hoodie (less heat), Fake Grading Slabs (sell price).
  - Guns: Boomstick shotgun, Recess SMG, Bake-Sale Bazooka.
- **Getting caught.** If your HP hits 0 you're GROUNDED: you lose half your cash and every card you're carrying.
- **Win** by buying your own Card Shop Empire for $3000.

## Project layout

- `scripts/game_state.gd`: autoload holding cash, cards, upgrades, weapon stats and the input map.
- `scripts/main.gd`: builds the world, spawns kids and parents, handles the trade, heat, shop and death loop.
- `scripts/player.gd`: third-person controller and guns.
- `scripts/kid.gd`, `scripts/parent.gd`, `scripts/rocket.gd`: the other characters and the rocket projectile.
- `scripts/hud.gd`: all UI.
- `scripts/shapes.gd`: helpers for building meshes in code.
- `tests/smoke_test.gd`: headless smoke test. Run it with `godot --headless --path . res://tests/smoke.tscn` (exits 0 on pass).
