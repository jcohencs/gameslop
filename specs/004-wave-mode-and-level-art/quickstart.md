# Quickstart: Validate Wave Mode and the Level Art Pass

## Automated

```sh
godot --headless --path . res://tests/smoke.tscn   # exit 0, three or more consecutive runs
```

The new checks cover:

- Wave Mode starts from the hideout and wave 1 adults spawn within 5 s (SC-001)
- each of the 5 blasters damages an adult, uses ammo and reloads; a shot through a kid's position
  leaves the kid untouched (SC-002)
- wave budgets strictly increase; waves 5 and 10 include the boss (SC-003)
- four far-away chasers get evenly spread surround slots (SC-004)
- a ranged adult winds up at least 0.5 s, its projectile can hurt the player, and it misses a
  player who sidesteps after the release (SC-005)
- a stuck adult moves again within 2 s (SC-006)
- prop kit kinds ≥ 15; each raid location ≥ 8 props of ≥ 4 kinds; arena ≥ 60 props (SC-007)
- splats and stuck darts stay within their caps (SC-008)
- clearing a wave triggers the intermission and then the next wave; a knockout ends the run, keeps
  cash and saves the best wave
- all earlier checks still pass (SC-009)

## Visual (xvfb or the editor)

Screenshot the arena on High and Low, a wave fight with each blaster firing, a ranged adult mid
wind-up, the boss megaphone telegraph, and each raid location after the prop pass. Compare against
[contracts/wave-mode-contract.md](contracts/wave-mode-contract.md).
