# Data Model: Graphics Overhaul

## QualityProfile (`Art.QUALITY`)

| key | high | low | rule |
|-----|------|-----|------|
| outlines | true | false | FR-017 |
| shadows | true | false | FR-017 |
| grass | 3500 | 700 | low ≤ 25% of high (SC-005) |
| particles | 1.0 | 0.4 | low ≤ 50% of high (SC-005) |
| ssao | true | false | Forward+ only |

`GameState.graphics_quality`: "high" (default) or "low", persisted in `settings.cfg` under
`video/graphics_quality`.

## Mood (`Art.MOODS`, keyed by location id plus "default")

Fields: `sun_rot` (Vector3, degrees), `sun_color`, `sun_energy`, `sky_top`, `sky_horizon`,
`ground`, `ambient`, `fog` (bool), `fog_color`, `fog_density`, `contrast`, `saturation`, `glow`,
`exposure`.

Validation: no two moods may share both `sun_color` and `sky_top` (SC-002).

## Texture (`Art.TEXTURES`)

Names: `grass`, `asphalt`, `tiles`, `wood`, `brick`, `carpet`, `concrete` (7, SC-003). Each entry
has a world `scale` (meters per repeat). The textures are generated 128×128 with mipmaps and cached.

## Character look (Rig)

- `opts.hair_style`: one of `none`, `bowl`, `spiky`, `bun`, `ponytail` (plus the existing
  `cap`/`hair`).
- Details: a collar ring at the neck base, a belt on the hips, shoe soles under the shoes, eye
  whites with pupils, a nose, a mouth, and cheeks (kids).
- `mood`: `neutral` | `angry` | `sad`. `set_mood()` tweens the brows and mouth.

## Effects

| effect | trigger | owner |
|--------|---------|-------|
| spark | a player hit lands | main.spawn_hit_spark |
| dizzy stars | parent state STAGGER or KO | parent |
| tears | kid CRYING | kid |
| sparkles | kid.whale | kid |
| dust motes | indoor location (locals, pizza, mall) | main at raid start |
| beam pulse | each active extract | main._add_extract |
