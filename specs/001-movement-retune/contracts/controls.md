# Contract: Player Movement Controls

These are the player-facing input bindings and guaranteed behaviors after this feature. The input
actions are defined in `GameState._setup_input()`.

| Action | Default keys | Behavior guarantee |
|--------|--------------|--------------------|
| `move_*` | WASD / arrows | Ground movement toward run speed (5 m/s). |
| `sprint` | Shift | While held and moving forward: sprint speed (6.8 m/s). Carries through bunny hops. Free. |
| `jump` | Space | Jump. Held: bunny hop (jump again on landing, no ground slowdown). Free. |
| `crouch` | Ctrl, C | Crouch-walk (quiet, 2.6 m/s). At ≥ 4.5 m/s: slide (+2 m/s, at most once per second). Free. |

Removed: the `walk` action (Shift as quiet walk). Its role moves to crouch-walking.

Guarantees:

- Horizontal speed never exceeds 12 m/s.
- None of these actions spend stamina.
- The pause menu help, the HUD hint and the README describe these exact bindings.
