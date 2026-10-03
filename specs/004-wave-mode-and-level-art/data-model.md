# Data Model: Wave Mode, Smarter Adults and a Level Art Pass

## Blaster (`GameState.BLASTERS`, order `BLASTER_ORDER`)

| id | name | kind | dmg | rate s | mag | reserve | reload s | spread ° | pellets | range m | knock | special | cost |
|----|------|------|-----|--------|-----|---------|----------|----------|---------|---------|-------|---------|------|
| dart | Foam Dart Pistol | hitscan | 20 | 0.2 | 12 | -1 (infinite) | 1.0 | 0.8 | 1 | 60 | 1.5 | stuck darts | 0 |
| soaker | Super Soaker 3000 | stream | 5 | 0.06 | 80 | 240 | 1.6 | 4 | 1 | 10 | 3.0 | soak 2.5 s (speed ×0.6) | 150 |
| paint | Paintball Rifle | hitscan, auto | 13 | 0.09 | 30 | 150 | 1.8 | 2.2 | 1 | 50 | 0.8 | mark 4 s (+20% damage taken) | 300 |
| bubble | Bubble Blunderbuss | hitscan | 10 | 0.8 | 6 | 30 | 2.2 | 7 | 8 | 18 | 9.0 | big knockback | 350 |
| chicken | Rubber Chicken Launcher | projectile | 110 | 1.1 | 3 | 12 | 2.4 | 0.5 | 1 | - | 12.0 | splash radius 4, arcs | 600 |

Common rules: aiming multiplies spread by 0.35 and narrows the FOV by 15°. A headshot (hit point
above 82% of the adult's height) multiplies damage by 1.5.

Player state: `blasters_owned` {id: bool} (dart always owned), `blaster_id`, and per-run ammo
`{id: {mag, reserve}}` held by Gunplay.

## Wave configuration (`GameState.WAVE_CONFIG`)

| key | value | meaning |
|-----|-------|---------|
| budget_base | 4 | wave 1 budget = base + per_wave |
| budget_per_wave | 3 | budget(n) = 4 + 3n (strictly increasing) |
| max_alive | 14 | live adult cap |
| spawn_interval | 1.1 | seconds between queued spawns |
| intermission | 8.0 | seconds between waves |
| first_delay | 2.0 | seconds before wave 1 |
| boss_every | 5 | boss waves |
| boss_add_frac | 0.5 | boss waves spend this share of the budget on adds |
| hp_growth | 0.06 | adult HP × (1 + 0.06 × (wave − 1)) |
| clear_bonus | 15 | cash × wave number |
| clear_heal | 35 | health restored on clear |
| clear_ammo | 0.5 | reserve refilled by this share of max reserve |
| ko_cash_mult | 0.25 | share of the raid KO reward |
| drop_ammo / drop_health | 0.22 / 0.1 | pickup drop chances |
| pickup_life | 20.0 | seconds |
| max_throwers | 2 | throw tokens (+1 from wave 6) |

## Wave enemies (`GameState.WAVE_ENEMIES`)

| type | cost | first wave |
|------|------|-----------|
| mom | 1 | 1 |
| dad | 2 | 1 |
| pitcher | 3 | 2 |
| balloon | 3 | 3 |
| pta | 4 | 4 |
| nana | 4 | 6 |
| coach | 6 | 7 |

Boss: `principal` on every 5th wave. Its summon is `monitor`.

## New adult types (`parent.gd` TYPES)

- **pitcher** "Little League Coach": hp 70, speed 5.0; ranged fastball: damage 10, speed 24,
  straight, windup 0.55, band 7-18 m, cooldown 2.2 s.
- **balloon** "Water Balloon Mom": hp 60, speed 5.2; ranged lob: damage 12, splash 2.2 m, flight
  time 0.9 s, windup 0.7, band 9-20 m, cooldown 2.6 s.
- **principal** "Principal Grimsby" (boss): hp 1400, speed 3.8, melee damage 30, reach 2.6, windup
  0.9; megaphone cone 11 m / 50°, damage 15, knock 14, telegraph 1.0 s, every 8 s; summons 2
  monitors every 14 s (while under the cap).

Status on any adult: `soak_t` (slowed), `mark_t` (+20% damage taken), `dodge_cd`, `stuck_t`,
`flank_slot`.

## Arena layout (`Arena.build` return dict)

`half`, `spawn`, `spawn_yaw`, `doors` (spawn positions), `cover` (points behind cover), `balcony`
(AABB), `scoreboard` (Label3D), `parent_spawns` (= doors), `extracts` = [], `pois` = [],
`kid_bounds`.

## Prop kit (`Props`)

At least 20 kinds; each prop root is in group `props` with meta `prop_kind`: picnic_table,
trash_can, bench, fence, hoop, car, bus, vending, arcade, storefront, plant, ceiling_light, window,
door, roof, bike_rack, hydrant, cone, flagpole, bus_shelter, gym_mats, vault_box, ball_cart,
bleachers, hanging_light, banner.

## Quality profile additions (`Art.QUALITY`)

| key | high | low |
|-----|------|-----|
| ssr | true | false |
| volumetric | true | false |
| decals | 120 | 40 |
