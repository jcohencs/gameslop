---
description: "Task list for Wave Mode, Smarter Adults and a Level Art Pass"
---

# Tasks: Wave Mode, Smarter Adults and a Level Art Pass

**Input**: Design documents from `/specs/004-wave-mode-and-level-art/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/wave-mode-contract.md, quickstart.md

**Tests**: Included (Constitution XII).

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [ ] T001 Confirm the baseline smoke test passes (repo root)

---

## Phase 2: Foundational

- [ ] T002 Add `BLASTERS` and `BLASTER_ORDER` (values from data-model.md, dart cost 0 with reserve -1), `WAVE_CONFIG` and `WAVE_ENEMIES` to scripts/game_state.gd
- [ ] T003 Add `blasters_owned` (dart always true), `blaster_id`, `best_wave`, `wave_runs` with save/load merge, `buy_blaster(id)`, `equip_blaster(id)`, `cycle_blaster(step)`, and the `reload` input (R) in scripts/game_state.gd
- [ ] T004 Add `var mode := "raid"` to scripts/main.gd and guard every `LOCATIONS[location_id]` use (main, hud, kid spawning) so a run with `location_id == ""` works
- [ ] T005 Add Art quality keys `ssr`, `volumetric`, `decals` and the `arena` mood (indoor, warm, low sun) in scripts/art.gd; `apply_mood` sets SSR and volumetric fog from the profile and mood

**Checkpoint**: the game runs exactly as before, and the tests are green.

---

## Phase 3: User Story 2 - Toy Blasters (P1)

- [ ] T006 [US2] Create scripts/gunplay.gd: per-run ammo, fire (hitscan with spread and pellets, mask 1|8, headshot ×1.5), soaker stream ticks, chicken projectile launch, reload, aim (spread ×0.35, FOV −15), switch cancels reload
- [ ] T007 [US2] Rewrite scripts/rocket.gd as the rubber chicken: ballistic arc, sweep against mask 1|8, splash on parents only, feather burst + "BWAK!" via `main.spawn_explosion`
- [ ] T008 [US2] Viewmodel blaster models (5, primitives) with `set_blaster`, `fire_kick`, `set_aim`, `reload_anim`, and a `muzzle` node in scripts/viewmodel.gd
- [ ] T009 [US2] Shooter VFX in scripts/art.gd: `muzzle_flash`, `tracer` (dart/paint/bubble visuals flying to the hit point), `splat` and `stuck_dart` (ring buffers capped by `q("decals")` / 60), `water_stream`, `impact_puff`, `feathers`, `splash`
- [ ] T010 [US2] Sounds in scripts/sfx.gd: dart, soak, paint, bubble, chicken, boom, reload, empty, horn, pickup
- [ ] T011 [US2] Route player input in wave mode (scripts/player.gd): LMB → gunplay fire (hold for auto/stream), RMB → aim, R → reload, 1-5/wheel → blasters; no block, sand or melee in wave mode
- [ ] T012 [US2] Parent status hooks in scripts/parent.gd: `shot(amount, dir, knock, headshot, effect)` applying mark ×1.2 and soak slow, with paint blobs and drips

---

## Phase 4: User Story 1 - Wave Mode Loop (P1) 🎯 MVP

- [ ] T013 [US1] Create scripts/waves.gd: `budget(n)`, `compose(n, rng)` (eligible by first wave, boss every 5th), spawn queue with interval and live cap, door choice (far, preferably out of sight), HP scaling, intermission, clear rewards, KO tracking, pickups, run result
- [ ] T014 [US1] Create scripts/pickup.gd (bobbing ammo box / juice box, collected within 1.5 m, expires)
- [ ] T015 [US1] main.gd: `start_waves()` / `end_waves(reason)`, wave-mode `_process` branch, `spawn_parent_at(type, pos)`, KO hook to the director, pause menu "Quit run", `spawn_explosion`
- [ ] T016 [US1] HUD wave mode in scripts/hud.gd: wave/remaining/intermission, ammo and reload bar, KOs and cash, banner, boss bar; hide heat/binder/timer
- [ ] T017 [US1] Hub: Wave Mode deploy tile (best wave, owned blasters) and BLASTERS shop section in scripts/hub.gd; results report on return

---

## Phase 5: User Story 3 - Smarter Adults (P1)

- [ ] T018 [US3] Surround slots: `main.flank_bearing(p)` and slot assignment; CHASE paths to the slot point when over 6 m away (scripts/main.gd, scripts/parent.gd)
- [ ] T019 [US3] Weave when aimed at (over 6 m), sidestep dodge after a shot (30%, 3 s cooldown, not the boss), stuck detection and detour (scripts/parent.gd)
- [ ] T020 [US3] Ranged types `pitcher` and `balloon`: distance band, line-of-fire check, throw tokens in main.gd, THROW wind-up state, lead prediction; scripts/thrown.gd projectile (mask 1|2, balloon splash)
- [ ] T021 [US3] Boss `principal`: megaphone SHOUT state (1.0 s telegraph, cone), summons, stagger resistance, rig tie and megaphone props (scripts/parent.gd)
- [ ] T022 [US3] Wave mode awareness: adults always track the player in wave mode

---

## Phase 6: User Story 4 - Showcase Arena (P2)

- [ ] T023 [US4] Create scripts/props.gd prop kit (≥ 20 kinds; group `props`, meta `prop_kind`)
- [ ] T024 [US4] Create scripts/arena.gd: gym shell with ceiling, glossy court with lines, hoops, balcony track with ramps and railings, bleachers with net and cheering spectator rigs, stage with curtains, cover props, doors with signs, hanging lights (omni), window spot lights (High), banners, scoreboard; dispatch "arena" in scripts/levels.gd

---

## Phase 7: User Story 5 - Raid Level Prop Pass (P2)

- [ ] T025 [US5] Playground: chain-link fence, school roof/trim/windows/doors/steps, flagpole, bike rack, picnic tables, trash cans, hoop + court lines, detailed bus (scripts/levels.gd)
- [ ] T026 [US5] Locals: store roof + AC units, storefront glass, interior ceiling lights, detailed cars, sidewalk/curb, bus shelter, vending machine, trash cans (scripts/levels.gd)
- [ ] T027 [US5] Pizza: ceiling with light panels, better arcade cabinets, stage curtains, trash cans, plants (scripts/levels.gd)
- [ ] T028 [US5] Mall: storefront glass and awnings, skylight frame, benches, plants, trash cans, vending machines (scripts/levels.gd)

---

## Phase 8: User Story 6 - Polish (P3)

- [ ] T029 [US6] Glossy floors (arena court, mall tiles) and SSR/volumetric on High only

---

## Phase 9: Tests and Polish

- [ ] T030 Smoke checks in tests/smoke_test.gd for every quickstart item (SC-001 … SC-008)
- [ ] T031 Run the smoke test 3+ times, all green
- [ ] T032 Screenshot review (arena High/Low, each blaster, ranged wind-up, boss telegraph, each raid location); fix issues
- [ ] T033 README: Wave Mode section, controls, blasters table, screenshots; pause help text

## Dependencies & Execution Order

- T001 → Foundational (T002-T005) → US2 blasters (needed to play waves) → US1 loop → US3 AI →
  US4 arena (US1 can run on a temporary flat arena until T024) → US5 → US6 → tests and polish.
- props.gd (T023) is independent of the gameplay work and can run in parallel with T006-T022.

## Parallel Example

```text
T023 scripts/props.gd   ‖   T006 scripts/gunplay.gd   ‖   T010 scripts/sfx.gd
```

## Implementation Strategy

- **MVP**: Foundational + blasters + the wave loop in the arena shell.
- Then the AI upgrade, the full arena, the raid prop pass, the High polish, tests and screenshots.
