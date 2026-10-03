# Quickstart: Validate the Graphics Overhaul

## Automated

```sh
godot --headless --path . res://tests/smoke.tscn   # exit 0, three or more consecutive runs
```

The new checks cover:

- 7 generated textures exist, are 128×128 with mipmaps, and are cached (SC-003)
- every location applies a mood, and all moods are pairwise distinct (SC-002)
- High: a raid's kids and adults have outline overlays; Low: none, no sun shadows, grass ≤ 25% and
  particle multiplier ≤ 0.5 (SC-001, SC-005)
- an adult that spots the player turns "angry" within 0.5 s; a crying kid is "sad" with tears
  (SC-004)
- stunned and KO'd adults get dizzy stars; the whale has sparkles; indoor raids have dust motes;
  extract beams pulse; a landed hit spawns sparks (SC-006)
- the quality setting survives save_settings/load_settings
- all earlier checks still pass (SC-007)

## Visual (xvfb or the editor)

Screenshot each location at High and one at Low, plus close-ups of an angry adult, a crying kid,
the whale and a hit spark. Compare against [contracts/visual-contract.md](contracts/visual-contract.md).
