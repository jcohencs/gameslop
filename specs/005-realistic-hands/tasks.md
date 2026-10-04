---
description: "Task list for Realistic First-Person Hands"
---

# Tasks: Realistic First-Person Hands

## Phase 1: Setup

- [X] T001 Confirm the baseline smoke test passes

## Phase 2: User Story 1 - Real Hands (P1) 🎯 MVP

- [X] T002 [US1] Create scripts/hand.gd: palm, 4 × 3-segment fingers, 3-segment thumb, knuckles, nails, fingerless glove with knuckle armor and wrist strap, mirrored by `side`
- [X] T003 [US1] Materials in scripts/hand.gd: skin (pore normal map from generated noise, subsurface scattering, roughness 0.55), leather glove, armor plates; cached
- [X] T004 [US1] scripts/viewmodel.gd: sleeved forearm with cuff and wrist skin, a persistent Hand per arm (never cleared with weapon props), a watch on the left wrist

## Phase 3: User Story 2 - Hands That Act (P1)

- [X] T005 [US2] `POSES` table (open, relaxed, fist, tight, grip, trigger, support, throw) with blending, `squeeze()`, `pulse()` and idle motion in scripts/hand.gd
- [X] T006 [US2] Per-weapon poses and grip orientation in scripts/viewmodel.gd (fists, brass/gauntlet accessories on the knuckles, boxing gloves, sword grip, sand pouch, blaster trigger/support); punches pulse, sand throws open, fire squeezes
- [X] T007 [US2] Smoke checks in tests/smoke_test.gd: 30 segments, fist vs open ≥ 2.5 rad per finger, trigger squeeze returns within 0.3 s, all weapons and blasters equip

## Phase 4: Polish

- [X] T008 Run the smoke test 3+ times, all green
- [X] T009 Screenshot review (fists, sword, sand, each blaster); fix issues; README note and screenshot

## Implementation Notes

- **The forearm lives inside the hand model.** Grips re-orient the whole model (thumb-up for
  sword and pistol, palm-up for the support hand) around the fist center, and the sleeve would
  otherwise detach from the wrist.
- **The sword handle tilt changed from −1.1 to −0.85 rad.** A natural thumb-up grip holds the
  handle roughly perpendicular to the forearm.
- **Fists are rolled 0.75 rad inward and the hands scaled 1.25×.** The first screenshots showed
  only the backs of small fists. Now the curled fingers and thumb read, at chunky action-game
  proportions.
- **The skin pore normal map and fabric weave are generated from `Art._vnoise` with
  `Image.bump_map_to_normal_map()`.** Subsurface scattering only shows on Forward+.
- **Smoke checks** cover 30 jointed segments, 10 nails, every melee weapon, ≥ 2.5 rad of fist vs
  open curl (measured 3.87), and the trigger squeeze returning within 0.3 s. Blasters are
  exercised by the Wave Mode block. All green on 3 consecutive runs.
