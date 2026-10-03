# Card Shark: Extraction Hustle

A goofy low-poly, first-person 3D game made in Godot 4. You're a shady card dealer: deploy to a local hangout, "trade" kids out of their best trading cards, punch out the angry parents who come after you, and **extract** before time runs out. Then sell your haul from the Shady Van and gear up for the next run.

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
| Mouse | Look |
| Left click | Punch |
| Right click (hold) | Block (takes 70% less damage, moves slower) |
| 1-4 | Switch fists |
| E | Trade with a kid |
| Esc | Pause / close menu |

## The loop

**Hideout (the Shady Van).** Sell your stash, buy supplies, fists and upgrades, then choose where to deploy:

| Location | Entry | Notes |
| --- | --- | --- |
| Sunnyvale Playground | free | Lots of kids, mostly junk cards. Moms and dads only. |
| Friday Night Locals @ Dragon's Den Games | $15 | Tournament kids with holos. Starts at higher heat. |
| Galleria Mall Food Court | $40 | Rich kids with Legendaries. Gym coaches show up fast. |

**Raid.** Every kid has a card floating over their head, color-coded by rarity (Common → Uncommon → Rare → Holo → Legendary). Walk up and press **E** to pick a tactic:

- *"Super rare" junk card*: costs 1 junk card. Decent odds, low heat.
- *Holo-sticker forgery*: costs 1 junk card + 1 sticker. Great odds, very low heat.
- *"Is that a UFO?!"*: free, but the kid always cries.

Each crying kid sends a parent after you: Soccer Moms, Angry Dads, PTA Presidents and Gym Coaches. Parents pull back their arm before they swing, so block or back off. Punches stun them and interrupt the swing. Knock one out and you loot their wallet. At max heat the PTA raids.

**Extract.** Two of each level's three extraction points are open each raid. They show as green beams and are listed top-right with distances. Stand inside one for 5 seconds to escape. An unblocked hit knocks your countdown back.

**What's at risk.** Your binder and the junk cards and stickers you carry are lost if you get knocked out or the timer runs out. Cash, your stash and upgrades are always safe.

**Win** by buying your own Card Shop Empire for $3000.

## Fists and upgrades

- **Fists:** Bare Knuckles, then Brass Knuckles (hard hitter), Boxing Gloves (huge knockback and stun) and the Power Gauntlet (1989), which hits everything in a wide swing.
- **Upgrades:** Silver Tongue (scam odds), Light-Up Sneakers (speed), Fat Binder (capacity), Puffy Vest (HP), Protein Shake (punch damage), Shady Hoodie (less heat), Fake Grading Slabs (sell price).

## Project layout

- `scripts/game_state.gd`: autoload with meta progress (cash, stash, upgrades, fists), raid state (binder, health, heat, timer), all tuning tables and the input map.
- `scripts/main.gd`: hideout and raid lifecycle, spawning, scams, heat and extraction.
- `scripts/levels.gd`: procedural geometry and layout (spawn, extracts, parent spawns) for each location.
- `scripts/player.gd`: first-person controller, punching and blocking.
- `scripts/kid.gd`, `scripts/parent.gd`: the kids and the parents.
- `scripts/hud.gd`: in-raid UI. `scripts/hub.gd`: hideout UI.
- `scripts/shapes.gd`: helpers for building meshes in code.
- `tests/smoke_test.gd`: headless smoke test. Run it with `godot --headless --path . res://tests/smoke.tscn` (exits 0 on pass).
