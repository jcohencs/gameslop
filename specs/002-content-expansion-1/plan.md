# Implementation Plan: Content Expansion 1

**Branch**: `claude/determined-gates-4azszv` (spec dir `002-content-expansion-1`) | **Date**: 2026-10-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/002-content-expansion-1/spec.md`

## Summary

This feature adds five content systems through data tables, plus the minimum code behind each:

- **Collector Orders:** a new `GameState` order logic and a new hideout tab.
- **Pizza Party Palace:** a new level builder with a ball-pit zone that adds a sight and speed
  rule, and a new guard type.
- **Two scam tactics:** all tactics move into a `GameState.TACTICS` table, adding Sob Story and
  Bundle Deal.
- **Raid events:** one Whale kid plus a chaperone each raid, and one `RAID_MODIFIERS` entry rolled
  per raid, with effects read through a single `GameState.mod()` accessor.
- **Nana:** a new adult type that uses new per-type `reach` and `windup` fields.

## Technical Context

**Language/Version**: GDScript, Godot 4.3+

**Primary Dependencies**: Godot engine (NavigationRegion3D baking, MultiMeshInstance3D for ball-pit balls)

**Storage**: `user://save.cfg` (ConfigFile). Adds an `orders` key and stays backward compatible.

**Testing**: headless smoke test `tests/smoke_test.gd`, plus xvfb screenshots for the new location and UI

**Target Platform**: Desktop, Forward+ and Compatibility renderers

**Project Type**: single-player 3D game (single project)

**Performance Goals**: 60 fps. The ball pit uses one MultiMesh (about 400 balls) instead of
hundreds of nodes. The adult cap stays at 12.

**Constraints**: kids never targetable; all tuning in tables; no imported assets

**Scale/Scope**: about 8 scripts touched, 1 new level builder, about 25 new smoke checks

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. The Extraction Loop Is Sacred | PASS | Orders pay from the stash (meta). Pizza has 3 extracts, 2 active. The `orders` save key merges with defaults. |
| II. Scams Are the Heart of the Game | PASS | New tactics show odds, cost and heat, and differ in at least 2 dimensions. The whale and orders add scam goals. Each tactic gets a smoke run. |
| III. Readable, Responsive Melee | PASS | Nana's longer reach comes with a longer, visible wind-up. Telegraphing is preserved. |
| IV. Movement Is a Skill | PASS | The ball pit is a local speed cap (2.5 m/s), a level twist that doesn't change the global profile. |
| V. Smart Adults, Living Kids | PASS | The ball-pit rule is a perception rule (adults can't see beyond 2.5 m), so they still search. Cheesy patrols and witnesses scams. The chaperone is a normal parent. |
| VI. Every Location Is a Hustle | PASS | Pizza Party Palace has a theme, cover, 3 extracts, a guard and patrol, hangouts, spawns, and a twist (the ball pit). The navmesh is checked in the smoke test. |
| VII. Progression Respects Time | PASS | Orders give extra value from existing cards, and their effects are shown in plain numbers. |
| VIII. Feel Before Features | PASS | The modifier is shown on the HUD. The whale glows. The orders tab uses the shared UI and shows fill state. |
| IX. Cartoon Tone, Kids Never Targets | PASS | The mascot and Nana are cartoon adults. The whale kid is a normal untargetable kid. |
| X. Generated in Code | PASS | The new level, mascot costume and balls are all primitives. |
| XI. Data-Driven Tuning | PASS | `TACTICS`, `RAID_MODIFIERS`, `ORDER_*` and the location entry live in `game_state.gd`; Nana and Cheesy live in `parent.gd` `TYPES`. |
| XII. Smoke Test Gate | PASS (planned) | Checks for each SC, plus a navmesh path check for pizza and screenshots. |

No violations.

**Post-design re-check**: PASS. The design adds no singletons, layers or assets.

## Project Structure

### Documentation (this feature)

```text
specs/002-content-expansion-1/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── ui-and-content.md
└── tasks.md
```

### Source Code (repository root)

```text
scripts/
├── game_state.gd   # LOCATIONS.pizza, TACTICS, RAID_MODIFIERS, ORDER config, orders + save/load,
│                   # raid_modifier + mod(), orders logic (roll/can_fill/fill)
├── levels.gd       # _pizza() builder (cabinets, tables, counter, stage, ball pit), "ball_pits" layout key
├── parent.gd       # TYPES: nana, cheesy; per-type reach/windup; ball-pit + modifier sight rule
├── kid.gd          # whale flag: legendary card, gold glow, WHALE label
├── player.gd       # in_ball_pit: 2.5 m/s cap, half noise
├── main.gd         # tactics via GameState.TACTICS, sob-story/bundle rules, whale + chaperone,
│                   # modifier roll/announce/effects, ball-pit check, Nana in heat pool, orders reroll
├── hud.gd          # modifier line under the timer
└── hub.gd          # ORDERS tab
tests/smoke_test.gd
README.md
```

**Structure Decision**: single Godot project. Everything fits into the existing scripts, and there
are no new files under `scripts/` beyond the level builder function.

## Complexity Tracking

No constitution violations to justify.
