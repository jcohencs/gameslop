---
description: "Task list for the STRAFTAT-style movement retune"
---

# Tasks: STRAFTAT-Style Movement Retune

**Input**: Design documents from `/specs/001-movement-retune/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/controls.md, quickstart.md

**Tests**: Included. Constitution Principle II makes smoke-test checks mandatory for every feature.

**Organization**: Tasks are grouped by user story so each can be implemented and tested on its own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story the task belongs to (US1, US2, US3)

## Phase 1: Setup

- [X] T001 Confirm the baseline: run `godot --headless --path . res://tests/smoke.tscn` and record that it passes before changes (repo root)

---

## Phase 2: Foundational (blocks all stories)

- [X] T002 Add the `MOVEMENT` dictionary to scripts/game_state.gd with exactly these values from data-model.md: run_speed 5.0, sprint_speed 6.8, crouch_speed 2.6, ground_accel 10.0, air_accel 10.0, air_cap 0.6, friction 6.0, stop_speed 2.0, slide_start_speed 4.5, slide_boost 2.0, slide_boost_cd 1.0, slide_friction 1.4, slide_min_speed 2.5, max_speed 12.0, jump_velocity 6.2, noise_crouch 0.35, noise_run 0.8, noise_sprint 1.0
- [X] T003 Rename the input action `walk` to `sprint` (Shift) in `_setup_input()` in scripts/game_state.gd, per contracts/controls.md
- [X] T004 Replace the movement constants in scripts/player.gd (RUN_SPEED, WALK_SPEED, CROUCH_SPEED, GROUND_ACCEL, AIR_ACCEL, AIR_CAP, FRICTION, STOP_SPEED, SLIDE_*, MAX_SPEED, JUMP_VELOCITY) with typed vars loaded from `GameState.MOVEMENT` in `_ready()`

**Checkpoint**: the game runs with the new table, and all speeds come from one place.

---

## Phase 3: User Story 1 - Sprint and bunny hop while sprinting (P1) 🎯 MVP

**Goal**: Shift sprints. Shift + Space chains hops at sprint speed. No stamina is used.

**Independent Test**: hold sprint + forward, then hold jump for 3 s; speed stays ≥ 6.5 m/s and
stamina doesn't change.

- [X] T005 [US1] Add a `sprinting` state in scripts/player.gd: true while the `sprint` action is held, input has a forward component (move.y < 0), and the player is not crouching or sliding. It is evaluated every frame on the ground and in the air
- [X] T006 [US1] Use `sprint_speed` as the ground wish speed while sprinting, and keep air-acceleration wish speed on the same basis, in scripts/player.gd `_physics_process`
- [X] T007 [US1] Make sure the bhop landing path (jump held or buffered on the landing frame) skips friction for that frame while sprinting, so speed carries, in scripts/player.gd. *Implementation note: validation (T020) showed that Shift + Space from a standstill only reached about 3.4 m/s, because hops only got one frame of ground acceleration. The takeoff frame now raises speed along the input direction straight up to the wish speed (never down), and the smoke test gained a "from standstill" check.*
- [X] T008 [US1] Remove the quiet `walking` branch in scripts/player.gd and set noise factors from the `noise_crouch`, `noise_run` and `noise_sprint` profile values (crouch-walking is quiet)
- [X] T009 [US1] Smoke checks in tests/smoke_test.gd: "sustained sprint speed between 6.3 and 7.3 m/s"; "holding sprint + jump for 3 s keeps speed ≥ 6.5 m/s every frame"; "stamina unchanged after sprinting, hopping and sliding"

**Checkpoint**: US1 is testable on its own.

---

## Phase 4: User Story 2 - Lower, controlled overall speeds (P1)

**Goal**: all movement tops out much lower: run about 5, cap 12, small slide boost.

**Independent Test**: run settles at 4.5–5.5 m/s; nothing exceeds 12 m/s; a slide adds ≤ 2.5 m/s
and doesn't stack within 1 s.

- [X] T010 [US2] Clamp horizontal speed to `max_speed` (12.0) after all acceleration and after knockback impulses in scripts/player.gd
- [X] T011 [US2] Apply `slide_boost` (2.0) only when `slide_boost_cd` (1.0 s) has elapsed, and use `slide_friction` / `slide_min_speed` in scripts/player.gd
- [X] T012 [P] [US2] Rescale the speed-based FOV in scripts/player.gd `_update_camera` so it reacts between run speed and the 12 m/s cap (FR-009)
- [X] T013 [P] [US2] Rescale the speedometer fade-in threshold in scripts/hud.gd so it appears just above run speed (FR-009)
- [X] T014 [US2] Smoke checks in tests/smoke_test.gd: "sustained run speed between 4.5 and 5.5 m/s"; "forcing 40 m/s is clamped to ≤ 12 m/s"; "slide from sprint adds ≤ 2.5 m/s"; "second slide within 1 s adds no boost"

**Checkpoint**: US1 and US2 both pass.

---

## Phase 5: User Story 3 - Skill expression stays (P2)

**Goal**: air strafing still gains speed, but gradually and bounded by the cap.

**Independent Test**: simulated air strafing from sprint speed gains speed, gains less than
1 m/s over 30 frames, and never exceeds 12 m/s.

- [X] T015 [US3] Confirm `_air_accelerate` in scripts/player.gd uses `air_cap` (0.6) and `air_accel` (10.0) from the profile
- [X] T016 [US3] Update the air-strafe smoke check in tests/smoke_test.gd: gain > 0 and < 1.0 m/s over 30 frames from 6.8 m/s, and capped at 12 m/s after many frames

---

## Phase 6: Polish & Cross-Cutting

- [X] T017 [P] Update the pause-menu help and the weapon-panel hint in scripts/hud.gd: "Shift sprint · hold Space to bunny hop · Ctrl/C crouch (quiet) & slide"
- [X] T018 [P] Update the README.md controls table and the Movement section to match contracts/controls.md (Shift = sprint, crouch = quiet, new speeds)
- [X] T019 Run the smoke test 3+ times; all green with no SCRIPT ERROR (Constitution II)
- [X] T020 Take a rendered screenshot while sprint-hopping to check the speedometer and FOV look right (Constitution II, visual change)

---

## Dependencies & Execution Order

- Setup (T001) → Foundational (T002–T004) → US1 (T005–T009) → US2 (T010–T014) → US3 (T015–T016) → Polish (T017–T020)
- US2 and US3 only depend on Foundational and could start after it. They're listed in priority
  order because they touch the same file (scripts/player.gd).
- [P] tasks T012/T013 and T017/T018 touch different files and can run in parallel.

## Parallel Example: User Story 2

```text
T012 scripts/player.gd (_update_camera FOV)   ‖   T013 scripts/hud.gd (speedometer threshold)
```

## Implementation Strategy

- **MVP**: Phases 1–3 (sprint + sprint-bhop, stamina-free). This is the user's headline request.
- **Increment 2**: Phase 4 brings all speeds down and caps them.
- **Increment 3**: Phase 5 keeps air-strafe skill depth, then polish and docs.
