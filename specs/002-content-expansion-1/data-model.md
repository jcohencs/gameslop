# Data Model: Content Expansion 1

## CollectorOrder (persisted in `GameState.orders`, an array of 3)

| Field | Type | Rules |
|-------|------|-------|
| `kind` | String | `"rarity"` or `"name"` |
| `rarity` | int | For `rarity` orders: 2 (Rare), 3 (Holo) or 4 (Legendary). Cards of this rarity **or better** qualify. |
| `count` | int | 1–3 for Rare, 1–2 for Holo, 1 for Legendary, 1 for `name` |
| `card_name` | String | For `name` orders: one of `CARD_NAMES` |
| `reward` | int | Multiple of $5. Paid as `max(reward, ceil5(1.5 × sell value of removed cards))`. |
| `title` | String | Display text, e.g. "Deliver 2 Holo+ cards" |

Lifecycle: rolled on new game, on loading a save without orders, and after every raid ends.
Fulfilled orders are removed until the next roll (the board shows them as "FILLED").

## RaidModifier (`GameState.RAID_MODIFIERS`)

| id | name | effect keys |
|----|------|-------------|
| `bake_sale` | Bake Sale | `sight: 0.7` |
| `report_card` | Report Card Day | `heat_decay: 0.5` |
| `free_refills` | Free Refills | `kid_respawn: 0.5` |
| `holo_hype` | Holo Hype | `rarity_bonus: 1.0` |

`GameState.raid_modifier`: the active id, set in `start_raid` and cleared when the raid ends.
`GameState.mod(key, default)` gives the multiplier or addend.

## Tactic (`GameState.TACTICS`, in display order)

| id | base | heat | cry | junk | sticker | special |
|----|------|------|-----|------|---------|---------|
| junk | 0.60 | 8 | 0.25 | 1 | 0 | none |
| sticker | 0.90 | 4 | 0.10 | 1 | 1 | none |
| bundle | 0.80 | 5 | 0.15 | 3 | 0 | none |
| sob | 0.35 | 0 | 0.00 | 0 | 0 | `gentle`: no heat on fail, no crying; on fail the kid becomes wary |
| ufo | 0.75 | 22 | 1.00 | 0 | 0 | none |

The final chance is `clamp(base + scam_bonus − 0.07 × rarity − 0.2 (if wary), 0.05, 0.97)`.

## Location `pizza` (`GameState.LOCATIONS`)

fee 25, time 300, kids 12, rarity_bonus 1.6, heat_floor 1, guard `cheesy`, difficulty 2.
The layout adds `ball_pits: Array[AABB]`.

## Kid

Adds `whale: bool`. A whale's card has `rarity = 4` (Legendary). It has a gold light and halo, and
its label reads "WHALE".

## Adult types (`parent.gd` TYPES)

New optional fields: `reach` (default 1.75), `windup` (default 0.5), `min_stars` (default 0).

- **nana**: hp 230, speed 3.6, damage 22, attack_cd 1.9, reach 2.8, windup 0.8, min_stars 3.
- **cheesy** (guard): hp 170, speed 5.0, damage 15, mascot look.

## Player

Adds `in_ball_pit: bool`. When true, horizontal speed ≤ 2.5 m/s and noise × 0.5.
