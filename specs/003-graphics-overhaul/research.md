# Research: Graphics Overhaul

## Toon shading

- **Decision**: `StandardMaterial3D` with `diffuse_mode = DIFFUSE_TOON`,
  `specular_mode = SPECULAR_TOON`, `rim_enabled` (rim 0.35, tint 0.6) and roughness 0.7, applied
  centrally in `Shapes.mat()` / `Art.mat()`.
- **Rationale**: it's built in, works on Forward+ and Compatibility, and needs no custom shader for
  hundreds of materials.
- **Alternatives considered**: a custom cel shader (more control, but a lot of duplicated work and
  risk across both renderers).

## Ink outlines

- **Decision**: an inverted-hull outline using one shared `StandardMaterial3D` (unshaded, near-black
  albedo, `cull_mode = CULL_FRONT`, `grow = true`, `grow_amount` scaled per size), assigned as
  `GeometryInstance3D.material_overlay` on character parts and key props. It's skipped at Low
  quality and on the viewmodel.
- **Rationale**: one material and one extra draw per outlined mesh. It works on both renderers.
- **Alternatives considered**: a screen-space edge-detect post shader (Forward+-only depth/normal
  tricks, and it outlines everything indiscriminately).

## Procedural textures

- **Decision**: 128×128 `Image`s built pixel by pixel in GDScript from a hash-based value noise,
  then turned into `ImageTexture` with mipmaps and cached by name. The materials use
  `uv1_triplanar = true` and `uv1_world_triplanar = true` with `uv1_scale` per texture, so tiling
  is in world units.
- **Patterns**:
  - grass: two-tone noise with blade streaks;
  - asphalt: dark speckle;
  - tiles: square grid with grout and subtle per-tile tint;
  - wood: stretched noise grain with plank seams;
  - brick: offset rows with mortar;
  - carpet: a busy party pattern (dots and squiggles);
  - concrete: soft blotches with cracks.

  Textures are greyscale or light, and the material color tints them, so one texture serves many
  colors.
- **Rationale**: there are no import steps (Constitution X). 7 × 16k pixels is about 110k
  `set_pixel` calls, roughly 40 ms, done once.
- **Alternatives considered**: `NoiseTexture2D` (generated asynchronously, which complicates
  headless tests and gives less control over patterns like brick).

## Lighting moods

- **Decision**: `Art.MOODS[id]` holds sun rotation, color and energy, sky top/horizon/ground
  colors, ambient energy, fog (enabled, color, density), adjustments (contrast, saturation,
  brightness), glow intensity and tonemap exposure. `Art.apply_mood(env, sun, id)` runs at raid
  start, and the hub uses "default".

  | Location | Mood |
  |---|---|
  | playground | sunny noon |
  | locals | golden-hour orange sun, warm fog |
  | pizza | magenta/teal party sky, high saturation |
  | mall | cool white, light fog |

## Grass

- **Decision**: a MultiMesh of tuft meshes (3 crossed blade triangles in an `ArrayMesh` with vertex
  colors). A tiny shader sways each tuft's vertices by height with `sin(TIME + world position)`.
  Tufts are scattered over grass rects, avoiding solid props via a simple exclusion list. Counts
  come from the quality profile.

## Effects

- **Decision**: `CPUParticles3D` builders in `Art`:
  - `spark` (one-shot burst, star quads);
  - `dizzy_stars` (a rotating node with 3 emissive star meshes; not particles, for clarity);
  - `tears` (emitting blue drops while crying);
  - `sparkles` (gold, looping);
  - `dust_motes` (a box emitter, slow drift).

  Amounts are multiplied by `Art.q("particles")`. The extract beam pulse is a looping tween on the
  beam material's alpha and the ring scale.

## Expressions

- **Decision**: the rig keeps references to the brows and mouth. `set_mood("neutral"|"angry"|"sad")`
  tweens the brow roll and height and swaps the mouth shape (scale/rotation). Parents set "angry"
  when `awareness() == 2` or when fighting, and "neutral" otherwise. Kids are "sad" while crying or
  scammed and "neutral" otherwise.

## Quality setting

- **Decision**: `GameState.graphics_quality` ("high"/"low") is saved in settings. `Art.q(key)`
  reads `Art.QUALITY[quality][key]`. It's applied at raid start (moods, shadows, grass, outlines and
  particles are built per raid).
