# Research: Content Expansion 1

There were no NEEDS CLARIFICATION items. These are the design decisions.

## Order generation and rewards

- **Decision**: three order kinds, picked at random:
  - `rarity`: N cards of rarity R or better. R is Rare (N 1–3), Holo (N 1–2) or Legendary (N 1).
  - `name`: one card with a given name.

  The reward is `ceil5(1.6 × expected_sell)`, where `expected_sell` is the average value of that
  rarity × N × the current sell multiplier. For `name` orders, the "rarity" is Uncommon-average,
  with a floor of $40. Fulfilling removes the cheapest qualifying cards.
- **Rationale**: 1.6× on the expected value clears the 1.5× floor in FR-003 for typical cards. To
  guarantee the floor for any specific cards, the payout is `max(reward, ceil5(1.5 ×
  actual_value_removed))`.
- **Alternatives considered**: fixed rewards per order type (they break as the grading upgrade
  scales sell value).

## Ball pit hiding

- **Decision**: the level returns `ball_pits` as a list of AABBs. `main` checks each frame whether
  the player is inside one and sets `player.in_ball_pit`. In `parent._can_see_player()`, if the
  player is in a pit and more than 2.5 m away, the result is false. The player caps horizontal
  speed at 2.5 m/s and halves noise while in a pit.
- **Rationale**: a perception rule keeps the AI honest (Constitution V), and the adults' existing
  search state handles losing the player.
- **Alternatives considered**: an Area3D with signals (more nodes and signals, and the same result).

## Ball pit visuals

- **Decision**: a MultiMeshInstance3D of about 400 small colored spheres with per-instance colors,
  in a low-walled, non-blocking pit (the walls are knee-high colliders with gaps).
- **Rationale**: one draw call, which looks busy and costs little.

## Tactics table

- **Decision**: move tactic definitions from `main._tactics_for` into `GameState.TACTICS` (id,
  label, base, heat, cry, junk_cost, sticker_cost, cost_text, flags such as `no_cry_on_fail` and
  `no_heat`). `main` turns them into per-kid options.
- **Rationale**: Constitution XI. It also lets the smoke test go through every tactic.

## Raid modifiers

- **Decision**: `RAID_MODIFIERS` maps id → name, desc and effect keys (`sight`, `heat_decay`,
  `kid_respawn`, `rarity_bonus`). `GameState.mod(key, default)` returns the active modifier's value
  or the default. There is one modifier per raid, rolled in `start_raid`.

## Whale and chaperone

- **Decision**: the first kid spawned in each raid is the Whale (`kid.whale = true` before
  `add_child`). Its card is forced to Legendary, and it gets a gold OmniLight plus an emissive halo
  ring. A Soccer Mom spawns 2 m away in PATROL with a tiny patrol loop around the whale.
- **Rationale**: PATROL is the existing unaware state, so the chaperone reacts to crying and
  witnessing naturally.

## Nana and Cheesy

- **Decision**: `TYPES` entries gain optional `reach` (default 1.75) and `windup` (default 0.5).
  - Nana: hp 230, speed 3.6, damage 22, reach 2.8, windup 0.8, `min_stars` 3.
  - Cheesy: a guard with hp 170, speed 5.0, damage 15, a big round head (mascot) and a party hat.
- **Rationale**: per-type fields keep the attack code shared. The wind-up scales with reach, so it
  stays fair.
