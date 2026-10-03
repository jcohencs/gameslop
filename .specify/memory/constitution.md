# Card Shark: Extraction Hustle Constitution

## Game Vision & Design Pillars

**The pitch.** You are a small-time card shark in a world of trading-card-obsessed kids. Each run,
you slip into a local hangout (a playground, the Friday Night Locals at a game store, a mall food
court), talk kids out of their best cards with increasingly shameless tricks, and get out before
the grown-ups catch on. Back at the Shady Van you flip the haul, buy upgrades and gear, and go
bigger next time. The long-term dream is owning your own card shop empire.

**The player fantasy.** Being the slickest hustler in town: smooth-talking, fast on your feet,
and able to handle yourself when a Soccer Mom, a PTA President or a Gym Coach comes swinging.

**Design pillars.** Every feature MUST serve at least one pillar, and the feature's spec MUST say
which:

1. **Hustle.** Scamming is clever, varied and readable. The player weighs greed against heat.
2. **Escape.** Everything you carry is at risk until you extract. Tension rises the longer you stay.
3. **Brawl.** Melee is punchy, fair and skill-based. Movement is part of combat.
4. **Silly.** Cartoon satire throughout. The comedy comes from the situation, never from cruelty.

**Out of scope** unless the constitution is amended: multiplayer, guns or ranged firearms,
microtransactions, real-world brands or real card games by name, and photorealistic art.

## Core Principles

### I. The Extraction Loop Is Sacred

The run structure is **Hideout → Deploy → Hustle → Extract (or lose it) → Hideout**.

- Meta progress (cash, stash, upgrades, owned weapons, lifetime stats) MUST never be lost by any
  in-raid outcome.
- Raid state (the binder and carried supplies: junk cards, stickers, sand packets) MUST be lost
  on knockout, timeout or abandoning, and kept only by a successful extraction.
- Every raid MUST have a visible timer. When it runs out, the run fails.
- Every location MUST define at least three extraction points, with a random subset (currently
  two) active each raid. Active extracts MUST be shown on the compass and in the world.
- Extracting MUST take a short, interruptible hold (currently 5 s) that unblocked hits set back.
  Extraction is never instant.
- Risk MUST scale with reward: richer locations cost more to enter, start at higher heat, and
  field tougher adults.
- Save data MUST stay backward compatible. Loading an older save merges defaults for new keys and
  never wipes progress.

Rationale: the risk/reward of carrying loot out is the core of the game. Every other system feeds
it.

### II. Scams Are the Heart of the Game

- Each kid carries one card with a visible name and rarity (Common, Uncommon, Rare, Holo,
  Legendary), color-coded consistently everywhere: world labels, card art, HUD and hideout.
- Every scam tactic MUST show its success chance, cost and heat before the player commits.
  Tactics MUST differ in at least two of: odds, heat, cost, and whether the kid cries.
- Rarer cards MUST be harder to scam. Wary kids (witnesses) MUST be harder to scam, and the reason
  MUST be shown.
- Heat is the single escalation meter (0–5 stars). It rises from scams and failures, decays over
  time, and drives which adults appear. A maxed meter triggers a PTA Raid.
- The economy MUST keep the following true:
  - A careful player can afford their first meaningful upgrade within two or three successful
    raids.
  - The win goal (the Card Shop Empire) stays out of reach of one lucky raid.
  - Supplies stay cheap enough that losing them stings without blocking the next run.
- New scam tactics, card sets and rarities MUST come with odds/heat/value tuning in data tables
  and a smoke test that runs each tactic at least once.

Rationale: scamming is the game's unique verb, so it has to stay a real decision, not a button.

### III. Readable, Responsive Melee

- The player fights with melee and non-lethal gadgets only: fists, swords and throwables like
  Pocket Sand. Firearms are out of scope.
- **Input**:
  - A tap is a light attack. Light attacks chain into a 3-hit combo that ends in a stronger
    finisher.
  - Holding the attack button charges a heavy attack. The charge pose and charge ring MUST appear
    the moment charging starts, and releasing a full charge fires the heavy.
  - Early clicks MUST be buffered rather than dropped.
- **Defense**: block (hold) cuts damage. A parry (raising block just before a hit) negates the
  hit and staggers the attacker.
- **Stamina**: stamina is spent ONLY on charged heavy attacks.
- **Fairness**: every adult attack MUST be telegraphed by a visible wind-up before damage. Hits
  interrupt wind-ups. Heavies and parries stagger.
- **Feedback**: every landed hit MUST produce a hit-stop, sound, hit marker and damage number.
  Getting hit MUST show a direction indicator and screen feedback.
- Each weapon MUST have a distinct role, and the shop MUST show it at a glance:
  - Bare Knuckles: fast and reliable.
  - Brass Knuckles: raw damage.
  - Foam LARP Sword: cheap reach.
  - Boxing Gloves: knockback and control.
  - Mall Kiosk Katana: big slashing combos.
  - Power Gauntlet: crowd control.
  - Pocket Sand: escape and blinding.

  A new weapon that duplicates an existing role MUST NOT be added.

Rationale: fights should be won by timing and positioning, never lost to something the player
couldn't see coming.

### IV. Movement Is a Skill

- Movement is Quake/STRAFTAT-style: ground friction and acceleration, air strafing, bunny
  hopping, crouch-sliding and sprint. All movement is free (no stamina).
- Speeds MUST stay grounded and readable. The current profile: run 5 m/s, sprint 6.8 m/s, hard
  cap 12 m/s, slide boost 2 m/s at most once per second. Changes go through
  `GameState.MOVEMENT` and a spec.
- Holding sprint and jump MUST chain hops at sprint speed. Speed above sprint MUST be earned
  through air strafing and slide timing, and MUST never pass the cap.
- Movement choices MUST have stealth trade-offs: crouch-walking is quiet, and sprinting and
  fighting are loud.
- Moving fast MUST feel fast without breaking readability: FOV widening, a speedometer, and bonus
  damage/knockback for momentum hits.

Rationale: movement is both how you escape and how you win fights. It has to reward skill without
turning into chaos.

### V. Smart Adults, Living Kids

- Adults (parents and guards) MUST perceive the player through a vision cone with line of sight
  and through hearing based on player noise. They MUST NOT react to the player in ways they
  couldn't perceive.
- Adult behavior MUST run through readable states: patrol, investigate, chase, engage, search,
  stagger, blinded, flee and knockout. Each state MUST be visible through animation, labels and
  the HUD's HIDDEN / SEARCHING / SPOTTED status.
- Only a limited number of adults (currently 2–3) attack at once. The rest circle and wait their
  turn. Crowds MUST be dangerous without being unreadable.
- Adults MUST path around level geometry using the navmesh. Getting stuck on obstacles is a bug.
- Each adult type MUST be distinct in speed, health, damage and personality (taunts, look):
  Soccer Mom, Angry Dad, PTA President, Gym Coach, and the per-location guards (Recess Monitor,
  Gary the Store Owner, Mall Cop).
- Kids MUST feel alive: hanging out at points of interest, chatting, witnessing scams (and
  turning wary), cheering fights from a distance, fleeing danger, and running to grown-ups when
  scammed.
- Escalation MUST be communicated. Crying kids summon parents, parents radio each other at higher
  heat, guards react to scams they actually see, and max heat brings a PTA Raid.

Rationale: the world reacting believably is what makes a heist sandbox fun to play again.

### VI. Every Location Is a Hustle

- Each location MUST have:
  - a clear identity and theme (playground, game store, mall);
  - a distinct layout with cover, sight-line blockers and choke points;
  - at least three extracts in different areas;
  - a patrolling guard with a patrol route;
  - kid hangout spots;
  - adult spawn points away from the player's spawn.
- Locations MUST be navigable by AI: all blocking geometry is a static collider under the level's
  navigation region, so the baked navmesh is correct.
- Difficulty and loot MUST be stated up front in the hideout (danger, loot quality, timer, kid
  count, guard, entry fee).
- New locations SHOULD add a twist (a new guard behavior, hazard, kid type or extract condition)
  rather than just being a reskin.

Rationale: places are where the stories happen, and each one should play differently.

### VII. Progression Respects the Player's Time

- Progression is horizontal and vertical: upgrades raise power, while weapons and supplies widen
  options. No upgrade may make an earlier tactic or weapon pointless.
- Upgrade effects MUST be stated in plain numbers in the shop (e.g. "+8% scam success").
- Every raid MUST make some forward progress possible, even a failed one (looted wallets from
  knocked-out adults are cash kept immediately).
- Progress MUST save automatically at safe points: buying, selling, extracting and losing a raid.
- Win conditions (currently buying the Card Shop Empire for $3000) MUST be visible from the start.
  Players MAY keep playing after winning.

Rationale: losing a run should hurt, but never feel like wasted time.

### VIII. Feel Before Features

- Responsiveness is a feature:
  - mouse look reads raw, unaccumulated input;
  - menus never eat gameplay input;
  - settings (sensitivity, FOV, invert Y, volume) MUST exist and persist.
- Every player action MUST have feedback: animation (first-person viewmodel or third-person rig),
  sound, and a UI response. Silent or invisible actions are bugs.
- The HUD MUST show the run-critical information without opening a menu: timer, health, stamina,
  heat, binder value at risk, equipped weapon, compass with extracts, detection status and
  interaction prompts.
- UI MUST use the shared theme and widgets (`scripts/ui/`), with consistent colors for rarity,
  danger (red), safe/good (green) and accent (gold).
- Menus MUST be navigable with the mouse alone, MUST show costs and outcomes before confirming,
  and MUST play UI sounds.
- Animation MUST telegraph intent. Adults wind up, kids cry with their hands to their face, and the
  player's arms show the charge and the guard.
- Audio is synthesized in code. Every distinct event type (hit, block, whoosh, alert, cash, card,
  extract, fail, KO) MUST have its own recognizable sound.

Rationale: a small game feels big when every input gets an immediate, legible response.

### IX. Cartoon Tone, Kids Are Never Targets

- The game is comedic satire. Violence MUST stay non-graphic: knockouts tip over, wobble and fade
  away, with no blood, gore or injury detail.
- Kids MUST NOT be damageable, blindable or targetable by any weapon, gadget or ability. Only
  adults can be hit. Kids react to the player emotionally (crying, wary, cheering, fleeing), never
  physically.
- Humor comes from exaggeration and situation: overprotective parents, PTA bureaucracy, gym-coach
  bravado and absurd scams. Jokes MUST NOT target real groups, real people, or protected
  characteristics.
- Names MUST be parodies (Charzard, Dragon's Den, Galleria) and never real trademarks.

Rationale: it keeps the premise silly rather than mean, and keeps the game shareable.

### X. Everything Is Generated in Code

- All art, animation, UI and audio MUST be produced procedurally in GDScript: primitive meshes,
  `Rig` joint animation, `_draw()` widgets and `Sfx` synthesized samples.
- Imported binary assets (models, textures, audio files, fonts) MUST NOT be added unless the
  constitution is amended.
- Scenes (`.tscn`) stay minimal: a root node plus a script. Content is built in code.

Rationale: the project runs from a fresh clone with zero import steps, every change is a readable
text diff, and the art style stays consistent.

### XI. Data-Driven Tuning

- Gameplay numbers MUST live in data tables, not scattered literals. That means rarities, card
  names, locations, upgrades, weapons, movement, prices and economy constants in
  `scripts/game_state.gd`, and adult types in `scripts/parent.gd` `TYPES`.
- Adding content of an existing kind (a weapon, upgrade, location, card, adult type) MUST take a
  table entry plus only the code its new behavior needs.
- Balance changes MUST state their intent (what should feel different) in the commit or spec, and
  MUST keep the smoke test's balance checks passing.

Rationale: balance passes happen constantly, and one place to tune keeps them fast and safe.

### XII. Headless Smoke Test Gate (NON-NEGOTIABLE)

- Every feature or fix MUST add or update checks in `tests/smoke_test.gd` that exercise the
  behavior through real game objects and real input actions. The checks MUST cover state
  transitions, spawning, AI state, and the numbers in the success criteria.
- Before any push, `godot --headless --path . res://tests/smoke.tscn` MUST exit 0 on at least three
  consecutive runs, with no `SCRIPT ERROR`.
- Flaky checks MUST be fixed by correcting the setup or timing, never by deleting or skipping them.
- Visual or feel changes MUST also be checked with a rendered screenshot, and anything that only
  shows up when rendered MUST be fixed before shipping.

Rationale: there is no manual QA team. The smoke test is what proves a change works and keeps old
features working.

## Content & Feature Standards

- **New weapon**: a distinct role (Principle III), a viewmodel with attack animations, a sound, a
  shop tile with stat bars or a description, a combo and heavy definition, and smoke checks for
  hit and miss.
- **New adult type**: unique stats and a visual silhouette (rig options), taunts, a heat tier or
  location it appears in, a wind-up attack, and smoke checks for perception and knockout.
- **New location**: everything in Principle VI, a baked navmesh path check in the smoke test, a
  hideout deploy tile, and a screenshot review.
- **New scam tactic or supply**: odds/heat/cost data, a trade-screen entry showing all three, a
  risk rule (lost if not extracted), and smoke checks.
- **New UI screen**: the shared theme, mouse-only navigation, Esc to close, pausing if it covers
  gameplay, and a screenshot review.
- **Texts**: every player-facing control or rule change MUST update the README, the pause-menu
  help and the HUD hints in the same change.

## Technical Standards

- Engine: Godot 4.3+ (standard build), GDScript only. The game MUST run on both the Forward+ and
  Compatibility renderers, at 60 physics ticks per second.
- Autoloads: `GameState` (state, tables, saves, settings, input map) and `Sfx` (sound). New global
  singletons need a justification in the feature plan.
- All input actions MUST be defined in `GameState._setup_input()`.
- Collision layers: 1 = world, 2 = player, 4 = kids, 8 = parents/adults. New layers MUST be added
  to this list.
- AI pathing uses the navmesh baked at runtime by `Levels.build()`. Blocking geometry MUST be a
  static collider under the level's `NavigationRegion3D`.
- Pausing uses the scene tree pause. HUD, hub, `Sfx` and the main controller run while paused;
  level content does not.
- Code style:
  - use explicit types where inference fails (`var x: float = dict["k"]`);
  - no multi-line lambdas inside call arguments (use named methods);
  - comments explain why, not what;
  - match the surrounding code's style.
- Performance: no per-frame allocation-heavy work in hot paths, AI perception throttled (currently
  every 0.15 s), and a cap on simultaneous adults (currently 12).

## Quality Gates & Development Workflow

- Features go through Spec Kit:
  1. `/speckit-specify` (the spec names its design pillar).
  2. Optionally `/speckit-clarify`.
  3. `/speckit-plan` (its Constitution Check MUST cite these principles by number and name).
  4. `/speckit-tasks`.
  5. `/speckit-implement`.

  Small fixes MAY skip the spec but MUST still pass the gates below.
- Gates before pushing:
  1. Smoke test green on three or more consecutive runs (Principle XII).
  2. Screenshots reviewed for visual or feel changes.
  3. README, pause help and HUD hints updated if controls or rules changed.
  4. The diff re-read for stray debug code and leftover files.
- Work happens on a feature branch. Commits describe the behavior change and why. Pull requests
  summarize what was verified and how.
- Discoveries during implementation (like a spec assumption that turned out wrong) MUST be written
  back into the feature's research or tasks notes.

## Governance

This constitution takes precedence over other project conventions. It is a living document:
amendments are expected as the game grows.

- **Amending**: open a change that edits this file, explains why, and updates affected code, docs
  or specs in the same change, or lists them as follow-ups.
- **Versioning** (semantic):
  - MAJOR: removing, renumbering or redefining a principle or design pillar.
  - MINOR: adding a principle, section or content standard, or materially expanding guidance.
  - PATCH: wording, clarifications and updated "currently" values that don't change a rule.
- **Compliance**: every implementation plan MUST include a Constitution Check. Reviews MUST flag
  violations. A justified exception MUST be recorded in the plan's Complexity Tracking table, with
  the simpler alternative that was rejected.
- **"Currently" values**: numbers marked "currently" describe today's tuning and may change
  through data tables without amending this document. Rules without that marker need an
  amendment to change.

**Version**: 2.0.0 | **Ratified**: 2026-10-03 | **Last Amended**: 2026-10-03
