# Implementation Plan: STRAFTAT-Style Movement Retune

**Branch**: `claude/determined-gates-4azszv` (spec dir `001-movement-retune`) | **Date**: 2026-10-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-movement-retune/spec.md`

## Summary

Bring sprint back on Shift, let sprint carry through bunny hops, and bring every movement speed
down to a grounded STRAFTAT-like range: run about 5 m/s, sprint about 6.8 m/s, hard cap 12 m/s,
small slide boost limited to once per second, and gentler air-strafe gain. The quiet option moves
to crouch-walking. The existing Quake/Source movement model in `scripts/player.gd` stays. The
change is a retune plus sprint-state handling, and every movement number moves into one
`GameState.MOVEMENT` table (Constitution III).

## Technical Context

**Language/Version**: GDScript, Godot 4.3+

**Primary Dependencies**: Godot engine only (CharacterBody3D, Input map)

**Storage**: N/A (no save-format changes)

**Testing**: Headless smoke test `tests/smoke_test.gd` (`godot --headless --path . res://tests/smoke.tscn`)

**Target Platform**: Desktop (Linux/Windows/macOS), Forward+ and Compatibility renderers

**Project Type**: Single-player 3D game (single project)

**Performance Goals**: 60 physics ticks/s; movement math stays O(1) per frame

**Constraints**: Stamina never spent by movement; inputs stay unaccumulated and responsive

**Scale/Scope**: Two scripts change (`player.gd`, `game_state.gd`), plus HUD/README text and the tests

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Everything generated in code | PASS | No assets involved. |
| II. Headless smoke test gate | PASS (planned) | New checks: run speed, sprint speed, sprint-bhop speed retention, hard cap, slide boost size and cooldown, stamina untouched by movement. |
| III. Data-driven tuning | PASS (planned) | All movement numbers move from `player.gd` constants into `GameState.MOVEMENT`. |
| IV. Extraction loop integrity | PASS | No change to meta or raid state or saves. |
| V. Responsive, readable combat | PASS | Sprint binding defined in `GameState._setup_input()`; movement stays stamina-free; enemy telegraphs untouched. |
| VI. Cartoon tone, kids never targets | PASS | Unaffected. |

No violations, so Complexity Tracking stays empty.

**Post-design re-check (after Phase 1)**: still PASS. The design adds one data table and no new
singletons, layers or assets.

## Project Structure

### Documentation (this feature)

```text
specs/001-movement-retune/
├── plan.md              # This file
├── research.md          # Phase 0: tuning decisions
├── data-model.md        # Phase 1: MOVEMENT profile fields + movement states
├── quickstart.md        # Phase 1: how to validate
├── contracts/
│   └── controls.md      # Phase 1: player-facing input contract
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
scripts/
├── game_state.gd        # + MOVEMENT table; input map: "walk" → "sprint"
├── player.gd            # read MOVEMENT; sprint state; sprint survives bhops; crouch is quiet
└── hud.gd               # speedometer threshold + pause-menu help text
tests/
└── smoke_test.gd        # movement checks per Constitution II
README.md                # controls + movement section
```

**Structure Decision**: Single Godot project. The change stays inside the existing scripts above.
No new files under `scripts/`.

## Complexity Tracking

No constitution violations to justify.
