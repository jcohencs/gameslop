# Implementation Plan: Wave Mode, Smarter Adults and a Level Art Pass

**Branch**: `claude/determined-gates-4azszv` (spec dir `004-wave-mode-and-level-art`) | **Date**: 2026-10-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/004-wave-mode-and-level-art/spec.md`

## Summary

Wave Mode is a second game mode run by the existing `main.gd` controller (`mode = "waves"`):

- a **wave director** (`scripts/waves.gd`) builds each wave from a budget table, queues spawns at
  the arena doors, handles intermissions, clear rewards, pickups and the run result;
- **gunplay** (`scripts/gunplay.gd`, a child of the player) fires the five toy blasters from a
  data table: hitscan with spread for darts, paint and bubbles, a short-range tick stream for the
  soaker, and an arcing splash projectile (the old `rocket.gd`, rewritten) for the rubber chicken;
- the **viewmodel** gets blaster models with fire, aim and reload animations;
- **adults** (`parent.gd`) gain surround slots, weaving, dodges, stuck recovery, soak/paint status,
  wave HP scaling, two ranged types that throw projectiles (`scripts/thrown.gd`) and a boss;
- a new **arena** (`scripts/arena.gd`) and a **prop kit** (`scripts/props.gd`) that also dresses
  the four raid levels;
- **Art** gains the arena mood, SSR and volumetric flags in the quality profiles, and shooter
  effects (muzzle flash, tracers, splats, stuck darts with caps, splashes, feathers).

## Technical Context

**Language/Version**: GDScript, Godot 4.3+

**Primary Dependencies**: Godot built-ins only: `PhysicsRayQueryParameters3D` (hitscan and
projectile sweeps), `NavigationAgent3D`, `CPUParticles3D`, `OmniLight3D` / `SpotLight3D`,
`Environment` (SSR, volumetric fog), `Label3D`, primitive meshes.

**Storage**: `user://save.cfg` gains `blasters_owned`, `blaster_id`, `best_wave`, `wave_runs`.

**Testing**: the headless smoke test (`tests/smoke_test.gd`) gains a Wave Mode block and prop
checks.

**Target Platform**: desktop, Forward+ and Compatibility renderers.

**Performance Goals**: 60 fps with 14 adults alive on a mid-range GPU at High; splats capped at
120 and stuck darts at 60.

**Constraints**: everything generated in code; tunables in data tables; kids never hittable; raids
unchanged in rules.

**Scale/Scope**: about 6 new or rewritten scripts, about 2,500 new lines.

## Constitution Check

| Principle | Status |
|-----------|--------|
| I. Extraction loop | Raids are untouched; Wave Mode is a separate deploy option. Meta-safe rewards. |
| II. Scams | Not affected. |
| III. Melee | Raids stay melee; blasters have distinct roles (pistol, stream, auto, burst, splash). |
| IV. Movement | Same controller and movement profile in both modes. |
| V. Smart adults | Improved: surround, weave, dodge, detour, ranged positioning, telegraphs. |
| VI. Locations | Arena gets a twist (balcony, doors, boss); raid levels get the prop pass. |
| VII. Progression | Blasters are bought with the same cash; Wave Mode pays less per KO than raids. |
| VIII. Feel | Muzzle flash, recoil, tracers, impacts, hit markers, headshot BONK, sounds. |
| IX. Tone / kids | Toy blasters only; shot rays mask out layer 4; spectators have no colliders. |
| X. Generated in code | Yes: props, blasters, effects and sounds are all built in code. |
| XI. Data-driven | `BLASTERS`, `WAVE_CONFIG`, `WAVE_ENEMIES`, new `TYPES` entries, `Art.QUALITY`. |
| XII. Smoke test | New checks for every user story; 3+ green runs before commit. |
| XIII. Wave Mode | The whole feature is built to it (amended v2.1.0). |

No violations.

## Project Structure

### Documentation (this feature)

```text
specs/004-wave-mode-and-level-art/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── contracts/wave-mode-contract.md
└── checklists/requirements.md
```

### Source Code (repository root)

```text
scripts/
├── game_state.gd     # BLASTERS, WAVE_CONFIG, WAVE_ENEMIES, saves, "reload" input
├── waves.gd          # NEW: wave director (budget, queue, intermission, pickups, result)
├── gunplay.gd        # NEW: blaster firing, ammo, reload, aim, hitscan, effects
├── rocket.gd         # REWRITTEN: rubber chicken arcing splash projectile
├── thrown.gd         # NEW: adult projectiles (fastball, water balloon)
├── pickup.gd         # NEW: ammo / health pickups
├── arena.gd          # NEW: the Rec Center gym builder
├── props.gd          # NEW: prop kit (20+ kinds)
├── levels.gd         # dispatches "arena"; raid levels use Props
├── parent.gd         # smarter AI, ranged types, boss, status effects
├── player.gd         # wave-mode input routing to gunplay
├── viewmodel.gd      # blaster models + fire/aim/reload animations
├── main.gd           # mode switch, start/end of Wave Mode, effects hooks
├── hud.gd            # wave HUD (wave, remaining, ammo, banner, boss bar)
├── hub.gd            # Wave Mode deploy tile, blaster shop
├── art.gd            # arena mood, SSR/volumetric profile keys, shooter VFX
└── sfx.gd            # blaster, reload, splash, horn, pickup sounds
tests/smoke_test.gd   # Wave Mode + props checks
```

## Complexity Tracking

| Choice | Why | Simpler alternative rejected |
|--------|-----|------------------------------|
| Hitscan damage with a separate visual projectile | Instant, fair hit registration with a visible dart/paintball in flight | Fully simulated projectiles for every shot: laggy feel and more physics cost |
| Spectators are rig-only decor | Guarantees kids can't be hit (no colliders at all) | Real kid nodes behind a wall: relies on masks alone |
