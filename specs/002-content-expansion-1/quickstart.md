# Quickstart: Validate Content Expansion 1

## Automated (required)

```sh
godot --headless --path . res://tests/smoke.tscn   # exit 0, three or more consecutive runs
```

The new checks cover:

- 3 orders exist; fulfilling pays ≥ 1.5× the removed value and removes the cards; orders reroll
  after extract, knockout, timeout and abandon; orders survive a save/load (SC-001, SC-002)
- 10 raid starts each have exactly 1 whale (Legendary) and exactly 1 modifier (SC-003)
- each modifier changes its system (sight / heat decay / respawn / rarity)
- pizza: 12 kids, 2 extracts, Cheesy guard, a navmesh path (SC-005); in the ball pit the speed
  stays ≤ 2.5 and an adult 4 m away can't see the player, while one at 1.5 m can (SC-004)
- Sob Story ×20: heat unchanged, no crying (SC-006); Bundle Deal spends 3 junk and is disabled
  below 3
- Nana is never in the pool below 3 stars and appears in 30 rolls at 5 stars (SC-007); her reach
  and wind-up beat the defaults

## Manual (F5)

1. New game → ORDERS tab shows 3 orders.
2. Deploy to Pizza Party Palace: look for the ball pit, the cabinets and Cheesy.
3. Scam a kid with UFO so a parent chases you, then dive into the ball pit and watch the status go
   to SEARCHING.
4. Find the gold-glowing WHALE and its chaperone mom.
5. Check the HUD's modifier line.
6. Extract, sell, and fill an order.

See [data-model.md](data-model.md) and [contracts/ui-and-content.md](contracts/ui-and-content.md).
