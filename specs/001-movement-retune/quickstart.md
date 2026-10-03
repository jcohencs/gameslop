# Quickstart: Validate the Movement Retune

## Automated (required, Constitution II)

```sh
godot --headless --path . res://tests/smoke.tscn   # must exit 0; repeat 3+ times
```

The movement section of the smoke test asserts:

- running settles in 4.5–5.5 m/s and sprinting in 6.3–7.3 m/s (SC-003)
- holding sprint + jump from a sprint for 3 s keeps speed ≥ 6.5 m/s the whole time (SC-002)
- holding forward + sprint + jump from a standstill reaches sprint speed (6.3–7.3 m/s) within 1.5 s
- a slide from a sprint adds ≤ 2.5 m/s, and a second slide within 1 s adds no boost (SC-005)
- forcing a huge velocity is clamped to ≤ 12 m/s (SC-001)
- stamina is unchanged after sprinting, hopping and sliding (SC-004)
- air strafing still gains speed, but less than 1 m/s per 30 frames (FR-007)

## Manual (in the editor, F5)

1. Deploy to Sunnyvale Playground.
2. Hold W + Shift and watch the speedometer under the crosshair: about 7 m/s.
3. Hold Space as well: you hop continuously and stay around 7 m/s.
4. Mid-hop, hold A and turn the mouse left smoothly: speed creeps up toward 12 and stops there.
5. From a sprint, press Ctrl: a short slide with a small boost. Spamming Ctrl doesn't stack it.
6. Crouch-walk past a parent from behind: they don't hear you until you're close.
7. Check that the stamina bar stays full the whole time.

See [contracts/controls.md](contracts/controls.md) for bindings and [data-model.md](data-model.md)
for the tuning values.
