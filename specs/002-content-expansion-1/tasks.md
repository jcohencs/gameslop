---
description: "Task list for Content Expansion 1"
---

# Tasks: Content Expansion 1

**Input**: Design documents from `/specs/002-content-expansion-1/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ui-and-content.md, quickstart.md

**Tests**: Included. Constitution XII makes smoke checks mandatory for every feature.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [X] T001 Confirm the baseline smoke test passes: `godot --headless --path . res://tests/smoke.tscn` (repo root)

---

## Phase 2: Foundational (blocks the stories)

- [X] T002 Add `RAID_MODIFIERS` (bake_sale `sight: 0.7`, report_card `heat_decay: 0.5`, free_refills `kid_respawn: 0.5`, holo_hype `rarity_bonus: 1.0`, each with name and desc), `var raid_modifier := ""` and `func mod(key, default)` to scripts/game_state.gd
- [X] T003 Move tactic definitions into `GameState.TACTICS` in scripts/game_state.gd (junk, sticker, ufo with their current values) and make `main._tactics_for()` / `do_trade()` in scripts/main.gd read from the table, using `junk_cost` / `sticker_cost` fields
- [X] T004 Add optional per-type `reach` (default 1.75), `windup` (default 0.5) and `min_stars` (default 0) to the adult types in scripts/parent.gd, and replace the uses of `ATTACK_RANGE` / `WINDUP_TIME` with per-instance values

**Checkpoint**: the game behaves exactly as before, and the smoke test is green.

---

## Phase 3: User Story 1 - Collector Orders (P1) 🎯 MVP

**Independent Test**: stash cards → fulfill → cash ≥ 1.5× value and the cards are removed; the
orders reroll after any raid end; they persist through save/load.

- [X] T005 [US1] Add order generation in scripts/game_state.gd: `var orders: Array`, `roll_orders()` making 3 orders. Kinds are `rarity` ("2 (Rare), 3 (Holo) or 4 (Legendary)… or better"; count "1–3 for Rare, 1–2 for Holo, 1 for Legendary") and `name` (one of CARD_NAMES). `reward = ceil5(1.6 × expected sell)`, floor $40 for name orders
- [X] T006 [US1] Add `order_matches(order)` (the cheapest qualifying stash cards, or [] if the stash can't fill it), `order_have(order)` and `fulfill_order(i)` in scripts/game_state.gd. Fulfilling removes those cards, pays `max(reward, ceil5(1.5 × removed sell value))`, marks the order `filled` and saves
- [X] T007 [US1] Persist `orders` in `save_game()` / `load_game()` in scripts/game_state.gd. Roll a fresh board if a save has none, and roll on `reset()`
- [X] T008 [US1] Call `GameState.roll_orders()` in `_end_raid()` in scripts/main.gd for every outcome, and add `hub_fulfill_order(i)` with a report message and cash sound
- [X] T009 [US1] Add an ORDERS tab to scripts/hub.gd per contracts/ui-and-content.md: title `ORDERS (n ready)`, tiles with title, reward and have/need, and a `FULFILL +$X` / `NEED n MORE` / `FILLED` button, plus the "New orders after every raid." footer
- [X] T010 [US1] Smoke checks in tests/smoke_test.gd: 3 orders exist; a fulfilled order pays ≥ 1.5× and removes the cards; an unfillable order can't be fulfilled; orders change after extract, knockout and abandon; orders survive a save/load

---

## Phase 4: User Story 2 - Pizza Party Palace (P1)

**Independent Test**: deploy pizza → 12 kids, 2 extracts, Cheesy, a navmesh path; the ball pit
caps speed at 2.5 and hides the player beyond 2.5 m.

- [X] T011 [US2] Add `pizza` to `LOCATIONS` in scripts/game_state.gd (name "Pizza Party Palace", fee 25, time 300, kids 12, rarity_bonus 1.6, heat_floor 1, guard "cheesy", difficulty 2, plus a description mentioning the ball pit)
- [X] T012 [US2] Add a `cheesy` guard type in scripts/parent.gd (hp 170, speed 5.0, damage 15, attack_cd 1.2, guard true, mascot look: gray costume, big ears, party hat, taunts)
- [X] T013 [US2] Write `_pizza()` in scripts/levels.gd: building shell, arcade cabinet rows, party tables, prize counter, stage, a ball pit with knee-high wall colliders that have entry gaps and about 400 balls in one MultiMeshInstance3D, extracts Kitchen Back Door / Parking Lot / Ball Pit Slide, patrol, POIs, parent spawns, and `ball_pits: [AABB]`. Route "pizza" in `build()`
- [X] T014 [US2] Add `in_ball_pit` to scripts/player.gd: while true, horizontal speed is capped at 2.5 m/s and noise is ×0.5
- [X] T015 [US2] In scripts/main.gd, set `player.in_ball_pit` each frame from `layout.get("ball_pits", [])` and show "HIDING IN THE BALL PIT" in the prompt area
- [X] T016 [US2] In `_can_see_player()` in scripts/parent.gd, return false when the player is in a ball pit and more than 2.5 m away
- [X] T017 [US2] Smoke checks in tests/smoke_test.gd: the pizza raid has 12 kids, 2 extracts, the Cheesy guard and a navmesh path; in the pit speed ≤ 2.5; an adult 4 m away can't see the player in the pit, while one at 1.5 m can

---

## Phase 5: User Story 3 - New Scam Tactics (P2)

**Independent Test**: five tactics shown; Sob Story never adds heat or makes a kid cry; Bundle
Deal spends 3 junk and is disabled below 3.

- [X] T018 [US3] Add `bundle` (base 0.80, heat 5, cry 0.15, junk_cost 3, "Costs 3 junk cards") and `sob` (base 0.35, heat 0, cry 0, gentle, "Free · no heat · never cries") to `TACTICS` in scripts/game_state.gd, in the order junk, sticker, bundle, sob, ufo
- [X] T019 [US3] In `do_trade()` in scripts/main.gd: spend `junk_cost` / `sticker_cost` either way; for `gentle` tactics on failure add no heat and no crying, make the kid wary, and show "<name> isn't buying it."
- [X] T020 [US3] Smoke checks in tests/smoke_test.gd: 5 tactics listed; 20 Sob Story attempts leave heat unchanged with no crying kids; Bundle Deal is unavailable with 2 junk and spends 3 junk when used

---

## Phase 6: User Story 4 - Whale Kid and Raid Modifiers (P2)

**Independent Test**: 10 raid starts each have exactly 1 whale (Legendary) and 1 announced
modifier, and each modifier changes its system.

- [X] T021 [US4] Add a `whale` flag to scripts/kid.gd: force a Legendary card, a gold OmniLight3D and emissive halo ring, and a "WHALE — name" gold label
- [X] T022 [US4] In `start_raid()` in scripts/main.gd: roll one modifier into `GameState.raid_modifier`, spawn the first kid as the whale, and spawn a chaperone Soccer Mom 2 m away in PATROL with a small loop around the whale. Announce "Modifier: NAME. A WHALE is here!" and clear the modifier in `_end_raid()`
- [X] T023 [US4] Apply the modifier effects in scripts/main.gd (heat decay × `mod("heat_decay", 1)`, kid respawn delay × `mod("kid_respawn", 1)`, kid rarity bonus + `mod("rarity_bonus", 0)`) and in scripts/parent.gd (sight range × `mod("sight", 1)`)
- [X] T024 [US4] Show the modifier name and description under the timer in scripts/hud.gd
- [X] T025 [US4] Smoke checks in tests/smoke_test.gd: 10 raid starts each have exactly 1 whale with rarity 4, a chaperone, and a non-empty modifier; each modifier's `mod()` value changes its system

---

## Phase 7: User Story 5 - Nana (P3)

**Independent Test**: never below 3 stars; appears at 5 stars; reach and wind-up beat the defaults.

- [X] T026 [US5] Add `nana` to TYPES in scripts/parent.gd (hp 230, speed 3.6, damage 22, attack_cd 1.9, reach 2.8, windup 0.8, min_stars 3; lavender cardigan, gray bun hair, glasses, a cane prop in the right hand, taunts)
- [X] T027 [US5] Add Nana to `_parent_type_for_heat()` in scripts/main.gd at 3+ stars, respecting `min_stars`
- [X] T028 [US5] Smoke checks in tests/smoke_test.gd: no Nana in 30 rolls at ≤ 2 stars; Nana appears in 30 rolls at 5 stars; her reach > 2.5 and wind-up ≥ 0.75

---

## Phase 8: Polish & Cross-Cutting

- [X] T029 [P] Update README.md (new location, tactics, orders, raid events, Nana) and the pause help if needed in scripts/hud.gd
- [X] T030 Run the smoke test 3+ times, all green (Constitution XII)
- [X] T031 Take screenshots of the Pizza Party Palace (ball pit, cabinets, Cheesy), the whale glow, the HUD modifier line, the ORDERS tab and the trade screen with 5 tactics, and fix any visual problems

---

## Implementation Notes

- **T031 found an existing AI bug:** patrolling guards (and now chaperones) attacked a player who
  had done nothing, which goes against Constitution V ("guards react to scams they actually see").
  Fix: patrollers ignore the player below 15 heat unless they witness a scam or get hit
  (`PATROL_TOLERANCE_HEAT` in scripts/parent.gd), with two new smoke checks.
- **T031 also found** the arcade screens faced away from the player. Cabinets now have screens on
  both faces and a glowing marquee.
- **T030 found a rare test hang:** after 20 Sob Story attempts there could be no tradeable kid
  left. The test now spawns one, per Constitution XII (fix the setup, never delete the check).
- The ball-pit speed cap lives in `GameState.MOVEMENT.ball_pit_speed` (Constitution XI).

## Dependencies & Execution Order

- T001 → Foundational (T002–T004) → stories. US1 needs only T001. US2 needs T004 (guard type
  fields). US3 needs T003. US4 needs T002. US5 needs T004.
- Every story touches scripts/main.gd or scripts/game_state.gd, so in practice they run in
  sequence by priority: US1 → US2 → US3 → US4 → US5.
- [P]: T029 (docs) can run alongside T030 prep.

## Parallel Example

```text
T012 scripts/parent.gd (cheesy type)   ‖   T013 scripts/levels.gd (_pizza builder)
```

## Implementation Strategy

- **MVP**: Phase 3 (Collector Orders) gives immediate economy depth on the existing maps.
- Then the Pizza Party Palace, the tactics, the raid events and Nana, with each story's smoke
  checks green before moving on.
