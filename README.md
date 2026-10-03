# Card Shark: Extraction Hustle

A goofy low-poly, first-person extraction game made in Godot 4. You're a shady card dealer: deploy to a local hangout, "trade" kids out of their best trading cards, fight off the angry parents with fists and swords, and **extract** before time runs out. Then sell your haul from the Shady Van and gear up for the next run.

![Parents chasing you down](screenshot.png)

| The hideout | Trading |
| --- | --- |
| ![Stash](screenshot_hideout.png) | ![Trade](screenshot_trade.png) |

## Running

1. Install [Godot 4.3+](https://godotengine.org/download) (standard build, not .NET).
2. Open Godot → **Import** → pick this folder's `project.godot`.
3. Press **F5** (Play).

Everything (art, animation, sound) is generated in code, so there are no asset files to import. Progress saves automatically.

## Controls

| Input | Action |
| --- | --- |
| WASD | Move (run, about 5 m/s) |
| Shift | Sprint (about 6.8 m/s). Free, and it **carries through bunny hops** |
| Space | Jump. **Hold it to bunny hop**: you jump again the instant you land, with no ground friction. Hold Shift + Space to sprint-hop |
| Ctrl / C | Crouch-walk (quiet: parents hear you from less far away). **At speed you slide** with a small boost (once per second); jump out of a slide to keep the momentum |
| Mouse | Look (sensitivity, FOV and invert Y are in Settings) |
| Left click | Attack (click repeatedly for a 3-hit combo; the 3rd hit is a finisher) |
| Hold left click | Charge a heavy attack (uppercut / lunge), release when the ring fills. Costs stamina |
| Right click (hold) | Block: takes 75% less damage |
| Right click (just before a hit) | **Parry**: no damage, and the attacker is stunned |
| Q | Throw **Pocket Sand** with any weapon equipped (if you own it) |
| 1-7 / mouse wheel | Switch weapon |
| E | Trade with the kid you're looking at |
| Esc | Pause / close menu |

## Movement (STRAFTAT / Quake style)

Grounded, readable speeds: run about 5 m/s, sprint about 6.8 m/s, hard cap 12 m/s. All the numbers
live in `GameState.MOVEMENT`; see `specs/001-movement-retune/` for the spec and design.

- Ground movement has friction and acceleration, like Quake and Source.
- **Sprint + bunny hop:** hold Shift + Space to chain hops at sprint speed.
- **Air strafing:** in the air, hold A or D and turn the mouse the same way to gain a little speed
  each hop, up to the cap.
- **Sliding:** crouch while moving fast for a short slide with a small boost (at most once per
  second). Landing with crouch held turns straight into a slide, and jumping out of a slide keeps
  the speed.
- **Stealth:** crouch-walking is quiet, and sprinting is loud.
- Speed raises your FOV, and a speedometer appears under the crosshair. Hitting someone at speed
  adds bonus damage and knockback.
- Stamina is only used by **charged heavy attacks**. Movement is free.

## The loop

**Title → Hideout.** Continue a saved game or start a new one. The Shady Van has four tabs:

- **Deploy:** pick a location.
- **Stash:** see your extracted cards and sell them one at a time or all at once.
- **Shop:** buy supplies and weapons.
- **Upgrades:** permanent upgrades.

| Location | Entry | Guard | Notes |
| --- | --- | --- | --- |
| Sunnyvale Playground | free | Recess Monitor | Lots of kids, mostly junk cards. |
| Friday Night Locals @ Dragon's Den | $15 | Gary (Store Owner) | Tournament kids with holos. Starts at higher heat. |
| Galleria Mall Food Court | $40 | Mall Cop | Rich kids with Legendaries. Gym coaches show up fast. |

**Raid.** Look at a kid and press **E** to see their card and pick a tactic:

- *"Super rare" junk card*: costs 1 junk card. Decent odds, low heat.
- *Holo-sticker forgery*: costs 1 junk card + 1 sticker. Great odds, very low heat.
- *"Is that a UFO?!"*: free, but the kid always cries.

Rarer cards are harder to scam. Kids who **witness** a scam get wary (-20% odds), and if the patrolling **guard** sees you do it, they come after you.

**Extract.** Two of each level's three extraction points are open per raid. They show as green beams and as markers on the compass. Stand inside one for 5 seconds. Unblocked hits set the countdown back.

**What's at risk.** Your binder and the supplies you carry are lost if you're knocked out, run out of time, or abandon the raid. Cash, your stash and upgrades are always safe.

**Win** by buying your own Card Shop Empire for $3000.

## The AI

- Parents and guards have a **vision cone with line of sight** and can **hear** you sprinting and fighting. Hoodie upgrades shrink how far they can see you.
- They move between **patrol → investigate → chase → engage → search** states, and they path around obstacles on a baked navmesh. The compass status shows HIDDEN, SEARCHING or SPOTTED.
- Only 2-3 parents attack at once. The rest **circle** you, waiting their turn, and back off after swinging.
- They **wind up** before every swing, so you can block, parry or back off. Getting hit interrupts them, and heavies and parries stagger them.
- Crying kids run to the nearest grown-up, and nearby adults come to check on them. Once heat is up, parents radio each other ("the mom group chat").
- Kids hang out at tables and play spots, chat with each other, cheer when a fight breaks out nearby, and flee if it gets too close.
- Soccer Moms sometimes flee at low health ("I'm calling my LAWYER!").

## Weapons

| Weapon | Type | Notes |
| --- | --- | --- |
| Bare Knuckles | fist | Fast jabs and hooks |
| Brass Knuckles | fist | Hits hard |
| Foam LARP Sword | sword | Cheap, long reach, wide slashes |
| Boxing Gloves | fist | Huge knockback and stun |
| Mall Kiosk Katana | sword | Big damage, slashing combo, lunge heavy |
| Power Gauntlet (1989) | fist | Hits everything in a wide arc |
| Pocket Sand | thrown | "POCKET SAND!" Blinds every parent in a cone for 3.5s. They rub their eyes, stumble and lose track of you. Uses sand packets (3 for $8), which you lose if you don't extract |

**Upgrades:** Silver Tongue, Light-Up Sneakers, Fat Binder, Puffy Vest, Protein Shake, Gym Membership (stamina for heavies), Shady Hoodie (heat + stealth), Fake Grading Slabs.

## Spec-driven development (Spec Kit)

This repo has [GitHub Spec Kit](https://github.com/github/spec-kit) installed for Claude Code. Start a Claude Code session in this folder and use:

1. `/speckit-constitution` to set the project's principles (written to `.specify/memory/constitution.md`).
2. `/speckit-specify <feature description>` to write a spec for a new feature.
3. `/speckit-plan` to turn the spec into a technical plan.
4. `/speckit-tasks` to break the plan into tasks.
5. `/speckit-implement` to build it.

There are also some optional skills: `/speckit-clarify`, `/speckit-analyze`, `/speckit-checklist`, `/speckit-converge` and `/speckit-taskstoissues`. Templates and helper scripts live in `.specify/`, and the skills live in `.claude/skills/`.

## Project layout

- `scripts/game_state.gd`: autoload with meta progress, raid state, all tuning tables, save/load, settings and the input map.
- `scripts/sfx.gd`: autoload with procedurally synthesized sound effects.
- `scripts/main.gd`: hideout and raid lifecycle, spawning, scams and witnesses, AI coordination (attack tokens, radio), extraction.
- `scripts/levels.gd`: level geometry plus a navmesh baked at runtime; spawn, extract, patrol and hangout points.
- `scripts/rig.gd`: jointed humanoid with procedural walk/run cycles and blended action poses.
- `scripts/player.gd`: first-person controller with Quake-style movement (air strafe, bhop, slide), combos, heavies, block/parry, pocket sand and camera feel.
- `scripts/viewmodel.gd`: first-person arms, fists and swords, attack animations, sway and sword trails.
- `scripts/parent.gd`, `scripts/kid.gd`: AI state machines.
- `scripts/hud.gd`: in-raid UI. `scripts/hub.gd`: title screen and hideout.
- `scripts/ui/`: shared theme and widgets (compass, crosshair, trading card renderer, settings).
- `tests/smoke_test.gd`: headless smoke test. Run it with `godot --headless --path . res://tests/smoke.tscn` (exits 0 on pass).
