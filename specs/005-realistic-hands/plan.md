# Implementation Plan: Realistic First-Person Hands

**Branch**: `claude/determined-gates-4azszv` (spec dir `005-realistic-hands`) | **Date**: 2026-10-04 | **Spec**: [spec.md](spec.md)

## Summary

A new `scripts/hand.gd` builds one procedural hand:

- **Structure:** a palm, finger and thumb pivot chains made of tapered capsule segments, knuckle
  bumps and nails.
- **Glove:** a fingerless glove with knuckle armor and a wrist strap.
- **Materials:** cached skin, leather and armor materials. The skin gets a noise-generated pore
  normal map and subsurface scattering.
- **Poses:** a `POSES` table, blended per frame, with `set_pose()`, `squeeze()` (trigger pulse),
  `pulse()` (punch clench) and subtle idle motion.

`scripts/viewmodel.gd` changes:

- each arm gets a sleeved forearm and one persistent `Hand`;
- `_make_fist` becomes accessory-only (brass bar, gauntlet plates, boxing gloves, sand pouch);
- each weapon or blaster sets per-hand poses and grip orientation;
- attacks, sand throws and shots drive the finger animation.

## Technical Context

- **Language:** GDScript, Godot 4.3+.
- **Built-ins only:** `CapsuleMesh`, `SphereMesh`, `BoxMesh`, `StandardMaterial3D`, and
  `Image.bump_map_to_normal_map()` for the pore normal map.
- **Testing:** smoke checks in `tests/smoke_test.gd`.
- **Performance:** about 45 small meshes per hand, no shadows. This is negligible next to the 14
  adults in Wave Mode.

## Constitution Check

| Principle | Status |
|-----------|--------|
| III / VIII Feel | Improved: grips, clenches, trigger squeeze. |
| IX Tone | Hands are realistic but non-violent props; characters stay cartoon. |
| X Generated in code | Yes, including the pore normal map. |
| XI Data-driven | Poses and finger dimensions are tables in `hand.gd`. |
| XII Smoke test | New checks for structure, poses, squeeze and all weapons. |

No violations.

## Project Structure

```text
scripts/hand.gd        # NEW: procedural hand (geometry, materials, poses)
scripts/viewmodel.gd   # forearms, hands, per-weapon poses, animation hooks
scripts/gunplay.gd     # trigger squeeze on fire (via viewmodel)
tests/smoke_test.gd    # hand checks
```
