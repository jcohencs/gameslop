# Implementation Plan: Graphics Overhaul

**Branch**: `claude/determined-gates-4azszv` (spec dir `003-graphics-overhaul`) | **Date**: 2026-10-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/003-graphics-overhaul/spec.md`

## Summary

A new `scripts/art.gd` (`class_name Art`) holds every visual building block:

- a toon material factory with rim light;
- a shared inverted-hull outline material;
- procedurally generated, triplanar-tiled textures;
- per-location lighting moods;
- grass, cloud and particle effect builders;
- High and Low quality profiles.

Existing code is changed in a few places:

- **Materials:** `Shapes.mat()` becomes toon-shaded, so the whole game switches style at once.
- **Characters:** `Rig` gains faces, hair styles, clothing details and expressions.
- **Levels:** `Levels` applies textures and adds dressing.
- **Effects:** `main`, `parent` and `kid` call `Art` for effects and moods.
- **Settings:** a Graphics Quality option persists alongside the existing settings.

## Technical Context

**Language/Version**: GDScript, Godot 4.3+

**Primary Dependencies**: Godot built-ins only:

- `StandardMaterial3D` (toon diffuse and specular, rim, triplanar UVs, `grow` for outlines via
  `material_overlay`);
- `Image` / `ImageTexture` (procedural textures);
- `CPUParticles3D`, `MultiMeshInstance3D`;
- a small grass-sway `Shader`;
- `Environment` (fog, glow, adjustments).

**Storage**: `user://settings.cfg` gains `video/graphics_quality`.

**Testing**: smoke test (outlines on/off, textures, moods, expressions, effects, quality scaling) and xvfb screenshots of every location.

**Target Platform**: desktop, Forward+ and Compatibility (SSAO/SSIL/volumetric fog are Forward+
only and are ignored on Compatibility).

**Project Type**: single-player 3D game

**Performance Goals**: 60 fps at High on a mid-range GPU and on integrated graphics at Low.
Specific budgets:

- grass: 3500 High / 700 Low instances, all in one MultiMesh draw;
- textures: about 7 images at 128², generated once and cached (under 50 ms total);
- particles: CPU, short-lived, and scaled at Low.

**Constraints**: no imported assets (Constitution X); gameplay unchanged; the first-person arms have no outline

**Scale/Scope**: 1 new script, about 9 modified scripts, about 20 new smoke checks

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Extraction Loop | PASS | No gameplay change. |
| II. Scams | PASS | Rarity colors are kept and the whale sparkles reinforce its value. |
| III. Melee | PASS | Hit sparks and dizzy stars make outcomes more readable. The windup telegraph is kept and the angry face adds to it. |
| IV. Movement | PASS | Unaffected. |
| V. AI | PASS | Expressions mirror AI state (angry = alerted), which helps readability. Decor that blocks movement is navmesh-baked. |
| VI. Locations | PASS | Each location gets a mood, textures and themed dressing. |
| VII. Progression | PASS | Unaffected. |
| VIII. Feel Before Features | PASS | It's the core of the feature. The new setting persists, and the UI keeps the shared theme. |
| IX. Cartoon Tone | PASS | Cartoon style, dizzy stars, no gore. Kids' tears are comedic. |
| X. Generated in Code | PASS | Textures, particles and shaders are all created in code. No files are imported. |
| XI. Data-Driven | PASS | `Art.MOODS`, `Art.QUALITY` and `Art.TEXTURES` are data tables, and the quality setting lives in `GameState`. |
| XII. Smoke Gate | PASS (planned) | The new checks are listed in quickstart.md. |

No violations.

**Post-design re-check**: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/003-graphics-overhaul/
├── plan.md, research.md, data-model.md, quickstart.md, tasks.md
└── contracts/visual-contract.md
```

### Source Code (repository root)

```text
scripts/
├── art.gd             # NEW: toon mats, outline, textures, moods, grass, clouds, FX, quality
├── shapes.gd          # mat() -> toon; box()/solid_box() accept a texture name
├── rig.gd             # faces, hair styles, collars/belts/soles, set_mood(), outlines
├── viewmodel.gd       # toon (no outline)
├── levels.gd          # textures on ground/walls/floors + per-location dressing
├── parent.gd          # angry face when alerted, dizzy stars on stun/KO
├── kid.gd             # sad face + tears when crying, whale sparkles
├── main.gd            # apply mood + shadows per quality, hit sparks, beam pulse, dust motes
├── hud.gd             # subtle constant vignette
├── game_state.gd      # graphics_quality setting (save/load)
└── ui/settings_panel.gd  # Graphics Quality toggle
tests/smoke_test.gd
```

**Structure Decision**: one new script, `art.gd`, so the visual vocabulary has a single home.
Everything else is incremental.

## Complexity Tracking

No violations.
