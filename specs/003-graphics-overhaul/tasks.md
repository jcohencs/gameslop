---
description: "Task list for the Graphics Overhaul"
---

# Tasks: Graphics Overhaul

**Input**: Design documents from `/specs/003-graphics-overhaul/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/visual-contract.md, quickstart.md

**Tests**: Included (Constitution XII).

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [X] T001 Confirm the baseline smoke test passes (repo root)

---

## Phase 2: Foundational

- [X] T002 Create scripts/art.gd (`class_name Art`) with the `QUALITY` table ("high": outlines true, shadows true, grass 3500, particles 1.0, ssao true; "low": outlines false, shadows false, grass 700, particles 0.4, ssao false) and `q(key)` reading `GameState.graphics_quality`
- [X] T003 Add `graphics_quality := "high"` to scripts/game_state.gd, persisted under `video/graphics_quality` in save_settings/load_settings
- [X] T004 Add `Art.toon(m)` (toon diffuse and specular, rim 0.35, rim tint 0.6) and route `Shapes.mat()` in scripts/shapes.gd through it, so every material becomes toon-shaded

**Checkpoint**: the whole game renders with cel shading, and the tests are green.

---

## Phase 3: User Story 1 - Cohesive Cartoon Look (P1) 🎯 MVP

- [X] T005 [US1] Add a shared outline material (`unshaded`, near-black, `CULL_FRONT`, `grow`) and `Art.outline(mi, amount)` that sets `material_overlay` only when `q("outlines")`, in scripts/art.gd
- [X] T006 [US1] Outline every body-part mesh in `Rig._part()` (scripts/rig.gd) with a size-scaled grow amount. The first-person arms (scripts/viewmodel.gd) are never outlined
- [X] T007 [US1] Add `Art.MOODS` (default, playground, locals, pizza, mall) and `Art.apply_mood(env, sky_mat, sun, id)` in scripts/art.gd. "No two moods share both sun_color and sky_top"
- [X] T008 [US1] In scripts/main.gd, keep references to the env, sky material and sun; apply the location's mood and the quality's shadows and SSAO in `start_raid()`, and "default" when returning to the hub
- [X] T009 [US1] Smoke checks in tests/smoke_test.gd: High raid kids and adults have outline overlays; every location applies a distinct mood

---

## Phase 4: User Story 2 - Textured Surfaces (P1)

- [X] T010 [US2] Add procedural texture generation in scripts/art.gd: value noise plus `grass`, `asphalt`, `tiles`, `wood`, `brick`, `carpet` and `concrete` at 128×128 with mipmaps, cached, with per-texture world scale in `TEXTURES`. Add `Art.textured(color, name)` returning a toon material with world-triplanar UVs
- [X] T011 [US2] Let `Shapes.box()` / `Shapes.solid_box()` take an optional `tex` name in scripts/shapes.gd, and let `Levels._ground()` / `_perimeter()` take a texture in scripts/levels.gd
- [X] T012 [US2] Apply textures per location in scripts/levels.gd: Playground (grass ground, asphalt court, brick school, wood benches), Locals (asphalt lot, wood store floor, brick walls), Pizza (tile floor, carpet stage, brick perimeter), Mall (tile floor, concrete walls)
- [X] T013 [US2] Smoke checks in tests/smoke_test.gd: 7 textures are generated (128 px, cached), and each location's level uses at least 2 distinct textures

---

## Phase 5: User Story 3 - Characters with Personality (P2)

- [X] T014 [US3] Upgrade the faces in scripts/rig.gd: eye whites + pupils, a nose, and a mouth (pivot node). Cheeks when `opts.kid`. Brows are always built and kept as references
- [X] T015 [US3] Add hair styles to scripts/rig.gd: `opts.hair_style` ∈ none, bowl, spiky, bun, ponytail (the existing `hair` color becomes bowl by default). Add clothing details: a collar ring, a belt, shoe soles
- [X] T016 [US3] Add `Rig.set_mood("neutral"|"angry"|"sad")` that tweens the brows (tilt/height) and the mouth (frown/smile/flat), in scripts/rig.gd
- [X] T017 [US3] Drive the expressions: in scripts/parent.gd, "angry" while awareness is 2 or fighting, otherwise "neutral" (checked in the think tick). In scripts/kid.gd, "sad" while crying or scammed, random hair styles, and `kid: true` for cheeks
- [X] T018 [US3] Smoke checks in tests/smoke_test.gd: an adult turns angry within 0.5 s of chasing; a crying kid is sad; at least 3 hair styles appear among the kids

---

## Phase 6: User Story 4 - Living Environments (P2)

- [X] T019 [US4] Add `Art.grass(parent, rects, count, exclude)` in scripts/art.gd: a MultiMesh tuft with vertex colors and a sway shader
- [X] T020 [US4] Add `Art.clouds(parent)` (drifting cloud clusters on a slow rotation) and fuller tree/bush builders in scripts/art.gd
- [X] T021 [US4] Dress each location in scripts/levels.gd:
  - Playground: grass, fuller trees, bushes, lamp posts, trash cans.
  - Locals: lot lamp posts, posters, chairs.
  - Pizza: balloons, streamers.
  - Mall: planters, bushes.

  Blocking props are solid; decor is not
- [X] T022 [US4] Smoke checks in tests/smoke_test.gd: the Playground grass instance count equals `q("grass")`; every location has clouds; the navmesh path checks still pass

---

## Phase 7: User Story 6 - Graphics Quality Setting (P2)

- [X] T023 [US6] Add a Graphics Quality toggle (High/Low) to scripts/ui/settings_panel.gd with the note "Applies from the next raid", saved via `GameState.save_settings()`
- [X] T024 [US6] Smoke checks in tests/smoke_test.gd: in a Low raid, no outline overlays, no sun shadows, grass ≤ 25% of High, particle multiplier ≤ 0.5; the quality survives save/load of settings

---

## Phase 8: User Story 5 - Juicy Effects (P3)

- [X] T025 [US5] Add effect builders in scripts/art.gd: `spark(parent, pos)`, `dizzy_stars(node, height)`, `tears(node, height)`, `sparkles(node)`, `dust_motes(parent, aabb)`. Particle amounts scale with `q("particles")`
- [X] T026 [US5] Wire the effects in scripts/main.gd (hit sparks via `spawn_hit_spark`, dust motes in indoor locations, a beam/ring pulse tween in `_add_extract`), scripts/parent.gd (stars while STAGGER/KO), and scripts/kid.gd (tears while crying, sparkles for the whale)
- [X] T027 [US5] Smoke checks in tests/smoke_test.gd: a hit spawns a spark; stun and KO show stars; a crying kid has tears; the whale has sparkles; an indoor raid has dust; extract beams have a running pulse tween

---

## Phase 9: Polish

- [X] T028 Add a subtle constant vignette in scripts/hud.gd (on top of the low-HP pulse)
- [X] T029 Run the smoke test 3+ times, all green
- [X] T030 Screenshot all 4 locations at High, one at Low, and close-ups (angry adult, crying kid, whale, hit spark); fix issues; update the README screenshots and the Graphics section

## Dependencies & Execution Order

- T001 → T002–T004 → US1 → US2 → US3 → US4 → US6 → US5 → Polish.
- Most tasks touch scripts/art.gd, so they run in sequence. T012 (levels) and T014–T016 (rig) are
  in different files and could run in parallel once T010 and T005 are done.

## Parallel Example

```text
T012 scripts/levels.gd (textures per location)   ‖   T014 scripts/rig.gd (faces)
```

## Implementation Strategy

- **MVP**: Foundational + US1 (toon, outlines, moods) changes the whole game's look in one step.
- Then textures, characters, environments, the quality setting, effects, and polish with
  screenshots.

## Implementation Notes

- Smoke test: 118 checks, green on 3+ consecutive runs (≈28 s each).
- The kid hair-variety check reads `Rig.look` across all 41 kids from the four raids, not the
  mesh counts of one raid, so it is deterministic in practice.
- Screenshot review (T030) found and fixed:
  - concrete crack lines read as squiggles (now short, faint hairlines);
  - the Playground and Mall were overexposed (lower sun, exposure and ambient; darker grounds);
  - the plain white ice cream truck blew out (now has stripes, a window, wheels and a cone);
  - edge-on disc "stars" (now billboarded five-point stars);
  - hit sparks skipped their burst with `explosiveness = 1.0` (now 0.95, larger, with a soft
    round dot texture shared by all particles).
- The headless dummy renderer logs `mesh_get_surface_count` null errors. The baseline did too,
  before this feature. They are not from this change.
