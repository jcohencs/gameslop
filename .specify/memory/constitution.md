# Card Shark: Extraction Hustle Constitution

## Core Principles

### I. Everything Is Generated in Code

All art, animation, UI and audio MUST be produced procedurally from GDScript (primitive meshes,
`Rig` joint animation, `_draw()` widgets, `Sfx` synthesized samples). Imported binary assets
(models, textures, audio files, fonts) MUST NOT be added. Scenes (`.tscn`) stay minimal: a root
node plus a script. Exceptions require a constitution amendment.

Rationale: the project opens and runs from a fresh clone with zero import steps, diffs stay
reviewable as text, and anyone can change the look by editing code.

### II. Headless Smoke Test Gate (NON-NEGOTIABLE)

Every feature or bug fix MUST add or update checks in `tests/smoke_test.gd` that exercise the new
behavior through the real game objects (spawning, input actions, state transitions). Before any
push, `godot --headless --path . res://tests/smoke.tscn` MUST exit 0 on several consecutive runs,
with no `SCRIPT ERROR` lines. Flaky checks MUST be fixed (timing, setup) rather than deleted or
skipped. Changes that affect visuals MUST also be checked with a rendered screenshot.

Rationale: the game has no manual QA loop; the smoke test is what proves a change works and keeps
earlier features working.

### III. Data-Driven Tuning

Gameplay numbers (weapons, upgrades, locations, rarities, enemy types, prices) MUST live in the
constant tables in `scripts/game_state.gd` or the `TYPES` table in `scripts/parent.gd`, not as
scattered literals. New content of an existing kind (a weapon, an upgrade, a location, a parent
type) MUST be addable by adding a table entry plus only the code its new behavior needs.

Rationale: balance passes happen often, and one place to tune keeps them fast and safe.

### IV. Extraction Loop Integrity

Cash, stash, upgrades and owned weapons are meta progress and MUST never be lost by any in-raid
outcome. The binder and carried supplies (junk cards, stickers, sand packets) are at risk and MUST
be lost on knockout, timeout or abandoning, and kept only on a successful extraction. Save data
MUST stay backward compatible: loading an older save MUST merge in defaults for new keys rather
than failing or wiping progress.

Rationale: the risk/reward of extraction is the core loop; breaking it, or a player's save,
breaks the game.

### V. Responsive, Readable Combat

Player input MUST feel immediate: mouse look is handled in `_input` with unaccumulated input,
early attack clicks are buffered rather than dropped, and any new input binding MUST be defined in
`GameState._setup_input()`. Enemy attacks MUST be telegraphed (a visible wind-up before damage)
so the player can block, parry or move away. Stamina gates only charged heavy attacks; movement
(run, bhop, slide, jump) MUST stay free.

Rationale: the movement-shooter-style feel (Quake/STRAFTAT) and fair melee are what make fights
fun.

### VI. Cartoon Tone, Kids Are Never Targets

The game is a comedic satire. Violence MUST stay non-graphic: knockouts tip over and fade out, with
no blood or gore. Kids MUST NOT be damageable or targetable by any weapon or ability; only adults
(parents and guards) can be hit, blinded or knocked out.

Rationale: keeps the premise silly rather than mean and keeps the game shareable.

## Technical Constraints

- Engine: Godot 4.3+ (standard build), GDScript only. It MUST run on both Forward+ and the
  Compatibility renderer.
- Autoloads: `GameState` (state, tables, saves, input map) and `Sfx` (sound). New global
  singletons require justification in the feature's plan.
- Collision layers: 1 = world, 2 = player, 4 = kids, 8 = parents. New layers MUST be documented
  here.
- AI pathing uses the navmesh baked at runtime by `Levels.build()`. New level geometry that blocks
  movement MUST be a static collider under the level's `NavigationRegion3D`.
- Prefer explicit types where GDScript cannot infer them (`var x: float = dict["k"]`).
  Multi-line lambdas inside call arguments MUST be avoided; use named methods.

## Development Workflow

- New features go through Spec Kit: `/speckit-specify` → `/speckit-plan` (its Constitution Check
  MUST reference these principles) → `/speckit-tasks` → `/speckit-implement`.
- Work happens on a feature branch; commits describe the behavior change and why.
- The README MUST be updated whenever controls, weapons, locations or the core loop change.
- Before pushing: smoke test green on repeated runs (Principle II), screenshots reviewed for
  visual changes, and the diff re-read for stray debug code.

## Governance

This constitution takes precedence over other project conventions. Amendments are made in a pull
request that edits this file, explains the change, and updates any affected code or docs in the
same change. Versioning follows semantic versioning: MAJOR for removing or redefining a principle,
MINOR for adding a principle or section or materially expanding guidance, PATCH for wording
clarifications. Every implementation plan MUST include a Constitution Check, and reviews MUST flag
violations. Any justified exception MUST be recorded in that plan's Complexity Tracking table.

**Version**: 1.0.0 | **Ratified**: 2026-10-03 | **Last Amended**: 2026-10-03
