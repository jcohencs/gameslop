# Feature Specification: Wave Mode, Smarter Adults and a Level Art Pass

**Feature Branch**: `claude/determined-gates-4azszv`

**Created**: 2026-10-03

**Status**: Draft

**Design pillars**: Brawl and Silly (Wave Mode, blasters, smarter adults); Silly and Escape
(richer, more readable levels)

**Input**: User description: "I WANT THE GRAPHICS AND LEVELS TO BE SUPER GOOD ALSO ADD WAVE BASED
SHOOTER MODE WITH BETTER AI AND STUFF"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Hold the Rec Center Against Waves of Parents (Priority: P1)

From the hideout, the player picks **Rec Center Showdown (Wave Mode)**. They spawn in a school
gymnasium with a toy blaster. Adults pour in through the gym doors in waves. Clearing a wave gives
a short breather, a cash bonus and some health and ammo back, and then a bigger, nastier wave
arrives. Every fifth wave brings a boss. The run ends when the player is knocked out or quits, and
a results report shows the wave reached, KOs and cash earned.

**Why this priority**: it is the headline request ("wave based shooter mode") and the container
for everything else in this feature.

**Independent Test**: start Wave Mode, KO every adult in wave 1, and confirm wave 2 starts after
the intermission with a larger budget; get knocked out and confirm the hideout shows the results
and the best wave is saved.

**Acceptance Scenarios**:

1. **Given** the hideout, **When** the player deploys to Wave Mode, **Then** the arena loads and
   wave 1 begins within 5 seconds, with the wave number and adults remaining on the HUD.
2. **Given** all adults of a wave are knocked out, **When** the wave ends, **Then** a "WAVE
   CLEARED" banner, a clear bonus, a health top-up and an ammo top-up are given, and the next wave
   starts after the intermission countdown.
3. **Given** wave 5 (and every fifth wave), **When** it starts, **Then** a boss adult spawns with a
   boss health bar.
4. **Given** the player is knocked out, **When** the run ends, **Then** cash already earned is
   kept, nothing owned is lost, and the best wave is updated if beaten.

---

### User Story 2 - Toy Blasters with Distinct Roles (Priority: P1)

Wave Mode is played with cartoon toy blasters bought at the van: a Foam Dart Pistol (free,
precise, never runs dry), a Super Soaker (short-range stream that slows and pushes), a Paintball
Rifle (full-auto, paint-marked adults take extra damage), a Bubble Blunderbuss (close-range burst
with huge knockback) and a Rubber Chicken Launcher (slow, arcing splash). Each has a magazine,
reload, recoil, a muzzle effect, a visible projectile or tracer, impact effects and its own sound.
Aiming down sights (right mouse) tightens spread and zooms slightly. Headshots "BONK" for bonus
damage.

**Why this priority**: the blasters are what make it a shooter, and their feel decides whether
the mode is fun.

**Independent Test**: fire each blaster at an adult in front of the player and confirm damage,
ammo use and reload; fire through a kid's position and confirm the kid is never hit.

**Acceptance Scenarios**:

1. **Given** a blaster with ammo, **When** the player fires at an adult, **Then** the adult takes
   damage, a hit marker and impact effect appear, and the magazine count drops.
2. **Given** an empty magazine, **When** the player fires or presses R, **Then** the blaster
   reloads (an animation plays, input to fire is ignored until done) and refills from reserve.
3. **Given** a kid between the player and a wall, **When** the player fires at the kid, **Then**
   the shot passes through the kid and the kid takes no effect of any kind.
4. **Given** the hideout shop, **When** the player has enough cash, **Then** blasters can be bought
   and the owned ones are available in Wave Mode via number keys and the mouse wheel.

---

### User Story 3 - Smarter, Scarier Adults (Priority: P1)

Adults stop forming a conga line. They spread out to surround the player, zigzag when the player
aims at them, sometimes sidestep after being shot, and route around obstacles when stuck. New
ranged adults (a Little League Coach who throws fastballs and a Water Balloon Mom who lobs
balloons) keep their distance, look for a clear line of fire, wind up visibly and lead their
throws, so a player who keeps moving can dodge. A boss (Principal Grimsby) mixes a slow heavy
swing, a telegraphed megaphone blast and calls for hall-monitor backup.

**Why this priority**: "better AI" was explicitly requested, and a horde mode lives or dies on
enemy behavior.

**Independent Test**: put four chasers on the player and confirm they approach from spread-out
angles; aim at a distant chaser and confirm it zigzags; have a ranged adult throw at a strafing
player and confirm the projectile can miss; block a chaser against a wall and confirm it recovers.

**Acceptance Scenarios**:

1. **Given** four or more adults chasing the player from far away, **When** they close in,
   **Then** they take different approach angles (spread over at least 180 degrees).
2. **Given** the player is aiming at an approaching adult more than 6 m away, **When** the adult
   notices, **Then** it weaves side to side while closing in.
3. **Given** a ranged adult with a clear line of fire, **When** it attacks, **Then** it winds up
   for at least 0.5 s (visible pose and sound), throws at the predicted player position, and the
   projectile hurts only the player (never kids, never other adults).
4. **Given** an adult whose path is blocked, **When** it has barely moved for over a second,
   **Then** it picks a detour and gets moving again.
5. **Given** the boss, **When** it charges its megaphone blast, **Then** there is at least 0.8 s of
   telegraph before a cone of knockback and damage.

---

### User Story 4 - A Showcase Arena (Priority: P2)

The Sunnyvale Rec Center gym is the best-looking place in the game: a glossy wood court with
painted lines, basketball hoops, a raised running-track balcony reached by ramps, bleachers full of
cheering kid spectators behind a railing, a stage with curtains, stacked gym mats and vaulting
boxes as cover, hanging gym lights, high windows with light shafts, banners, and a live scoreboard
showing the current wave.

**Why this priority**: the user asked for "super good" levels, and a new arena designed for
shooting needs cover, verticality and sightlines that the raid maps don't have.

**Independent Test**: build the arena and confirm the navmesh reaches the balcony, the cover
props exist, the scoreboard shows the wave number, and the kid spectators are present but
unreachable.

**Acceptance Scenarios**:

1. **Given** the arena, **When** adults path to a player on the balcony, **Then** they use the
   ramps.
2. **Given** wave N starts, **When** the scoreboard is visible, **Then** it reads WAVE N.

---

### User Story 5 - Richer Raid Levels (Priority: P2)

The four raid locations get a prop and architecture pass from a shared prop kit: real roofs with
trim, framed windows and doors, chain-link fences, picnic tables, trash cans, benches with slats,
bike racks, basketball hoops, detailed cars and a school bus, bus shelters, vending machines,
better arcade cabinets, storefronts with glass and awnings, potted plants, ceiling lights indoors
and more.

**Why this priority**: "graphics and levels super good" covers the existing locations, which is
where most play time goes.

**Independent Test**: build each location and confirm it has at least 8 new prop instances of at
least 4 kinds, and that every earlier navmesh and gameplay check still passes.

**Acceptance Scenarios**:

1. **Given** any raid location, **When** it is built, **Then** it contains props of at least 4
   kinds from the prop kit, and blocking props are solid while small decor is not.

---

### User Story 6 - Extra Visual Polish on High (Priority: P3)

On High quality (with the Forward+ renderer), glossy floors show screen-space reflections and the
arena gets volumetric light shafts. Low turns these off. Shooting leaves paint splats and stuck
foam darts on surfaces (capped so they never pile up endlessly).

**Why this priority**: it is polish on top of the rest.

**Independent Test**: start the arena on High and Low and compare the environment flags; fire
paintballs at a wall and confirm splats appear and stay within the cap.

**Acceptance Scenarios**:

1. **Given** High quality, **When** the arena loads, **Then** reflections and volumetric fog are
   enabled; on Low they are disabled.
2. **Given** a long firefight, **When** splats and darts exceed their caps, **Then** the oldest
   ones are removed first.

### Edge Cases

- The player pauses during an intermission: the countdown pauses too.
- All spawn doors are near the player: adults still spawn from the farthest door rather than not
  at all.
- More adults are queued than the live cap: they arrive as others are knocked out.
- A ranged adult has no line of fire from anywhere nearby: it closes in until it does.
- The player quits mid-wave: the run ends like a knockout (cash earned so far is kept).
- The player owns no blasters but the free pistol: Wave Mode still works with the pistol.
- A shot hits an adult who is already knocked out: nothing happens.
- Switching blasters during a reload cancels the reload without losing ammo.

## Requirements *(mandatory)*

### Functional Requirements

**Wave Mode**

- **FR-001**: The hideout MUST offer Wave Mode as a deploy option showing the best wave reached.
- **FR-002**: A run MUST be a sequence of waves. Each wave has a spawn budget that grows with the
  wave number. Adult types have a budget cost and a first wave they can appear in.
- **FR-003**: Every fifth wave MUST include a boss.
- **FR-004**: No more than a capped number of adults may be alive at once; the rest MUST queue.
- **FR-005**: Adults MUST spawn at arena doors away from the player, preferring doors out of the
  player's sight.
- **FR-006**: Clearing a wave MUST give a cash bonus, a health top-up and an ammo top-up, then an
  intermission countdown before the next wave.
- **FR-007**: Knocked-out adults MAY drop ammo or health pickups that expire after a while.
- **FR-008**: The run MUST end on a knockout or when the player quits, and report the wave
  reached, KOs and cash earned. The best wave MUST be saved.
- **FR-009**: Health, ammo and the run are the only things at risk; cash is banked as earned.

**Blasters**

- **FR-010**: Five toy blasters MUST exist with distinct roles: precise pistol (infinite reserve),
  short-range slowing stream, full-auto marker rifle, close-range spread burst, arcing splash
  launcher.
- **FR-011**: Each blaster MUST have damage, fire rate, magazine, reserve, reload time, spread and
  range in a data table.
- **FR-012**: Shots MUST only be able to hit world geometry and adults. Kids MUST never be hit.
- **FR-013**: Aiming (right mouse) MUST reduce spread and zoom the view.
- **FR-014**: Hits above an adult's shoulders MUST deal bonus damage with a distinct marker.
- **FR-015**: Firing MUST show a muzzle effect, recoil, a projectile or tracer, an impact effect
  and play a blaster-specific sound. Reloading MUST animate.
- **FR-016**: Blasters MUST be bought in the hideout shop and persist in the save.

**Smarter adults**

- **FR-017**: Chasing adults MUST spread around the player instead of following one line.
- **FR-018**: Adults being aimed at from range MUST weave while approaching.
- **FR-019**: Adults MAY sidestep after being shot (with a cooldown).
- **FR-020**: Adults that are stuck MUST detour.
- **FR-021**: Ranged adults MUST keep a preferred distance, need a line of fire, wind up for at
  least 0.5 s, lead their throws, and their projectiles MUST only hurt the player.
- **FR-022**: The number of adults throwing at once MUST be capped.
- **FR-023**: The boss MUST have a heavy melee swing, a telegraphed megaphone cone attack and
  summon backup on a timer.

**Levels and graphics**

- **FR-024**: A new arena level (the Rec Center gym) MUST provide cover, a raised balcony reachable
  by ramps, spawn doors, kid spectators behind a barrier and a live wave scoreboard.
- **FR-025**: A shared prop kit MUST provide at least 15 prop kinds.
- **FR-026**: Each raid location MUST gain at least 8 prop instances of at least 4 kinds.
- **FR-027**: On High, glossy floors MUST use screen-space reflections and the arena MUST use
  volumetric fog light shafts; Low MUST disable both.
- **FR-028**: Paint splats and stuck darts MUST persist on surfaces up to a cap, oldest removed
  first.
- **FR-029**: The HUD in Wave Mode MUST show wave number, adults remaining, ammo (magazine and
  reserve), reload progress, the intermission countdown and a boss health bar; raid-only HUD parts
  (heat, binder, timer) are hidden.

### Key Entities

- **Blaster**: a toy ranged weapon with role, stats, cost and visuals.
- **Wave**: a number, a budget, a composition of adult types and an optional boss.
- **Wave enemy entry**: an adult type with budget cost and first wave.
- **Arena layout**: spawn doors, cover points, balcony, spectator area and scoreboard.
- **Prop kind**: a named, reusable piece of level dressing.
- **Run result**: wave reached, KOs, cash earned and whether it is a new best.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: From pressing deploy, wave 1 adults are in the arena within 5 seconds.
- **SC-002**: 5 of 5 blasters damage an adult, use ammo and reload; 0 of 5 can affect a kid.
- **SC-003**: Wave budgets strictly increase, and waves 5 and 10 contain a boss.
- **SC-004**: Four approaching chasers take approach angles spanning at least 180 degrees.
- **SC-005**: Every ranged throw is preceded by at least 0.5 s of wind-up, and a thrown projectile
  misses a player who changes direction right after the release.
- **SC-006**: A stuck adult starts moving again within 2 seconds.
- **SC-007**: The prop kit has at least 15 kinds; each raid location has at least 8 new prop
  instances of at least 4 kinds; the arena has at least 60 prop instances.
- **SC-008**: Splats and stuck darts never exceed their caps.
- **SC-009**: All previously passing smoke checks still pass, on 3 or more consecutive runs.

## Assumptions

- "Shooter" means cartoon toy blasters, per the constitution's tone rule (amended to v2.1.0 to
  allow ranged toys in this mode only). Realistic guns stay out of scope.
- Wave Mode has no extraction, timer, heat or scamming. Kids appear only as spectators.
- Wave Mode cash is deliberately lower per KO than raids so raids stay the main way to earn.
- Blasters don't affect raids: raids stay melee-only.
- The arena is indoors with a real ceiling. The existing raid locations keep their open sky except
  where an interior ceiling clearly helps (the store and the pizza place).
- The first-person viewmodel shows the blaster held in both hands; no third-person player model.
