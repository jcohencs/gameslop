# Data Model: STRAFTAT-Style Movement Retune

## MovementProfile (`GameState.MOVEMENT`)

| Field | Type | Value | Meaning / validation |
|-------|------|-------|----------------------|
| `run_speed` | float m/s | 5.0 | Ground wish speed with no modifiers. SC-003: 4.5–5.5 sustained. |
| `sprint_speed` | float m/s | 6.8 | Ground wish speed while sprinting. SC-003: 6.3–7.3 sustained. |
| `crouch_speed` | float m/s | 2.6 | Ground wish speed while crouch-walking (quiet). |
| `ground_accel` | float | 10.0 | Quake-style accelerate factor on the ground. |
| `air_accel` | float | 10.0 | Accelerate factor in the air. |
| `air_cap` | float m/s | 0.6 | Air wish-speed cap. Smaller means slower air-strafe gain. |
| `friction` | float | 6.0 | Ground friction. |
| `stop_speed` | float m/s | 2.0 | Friction floor speed. |
| `slide_start_speed` | float m/s | 4.5 | Minimum speed for crouch to start a slide. |
| `slide_boost` | float m/s | 2.0 | One-shot speed added on slide start. SC-005: ≤ 2.5. |
| `slide_boost_cd` | float s | 1.0 | Minimum time between boosts. SC-005. |
| `slide_friction` | float | 1.4 | Friction while sliding. |
| `slide_min_speed` | float m/s | 2.5 | A slide ends below this. |
| `max_speed` | float m/s | 12.0 | Hard horizontal cap. SC-001. |
| `jump_velocity` | float m/s | 6.2 | Vertical jump impulse. |
| `noise_crouch` / `noise_run` / `noise_sprint` | float | 0.35 / 0.8 / 1.0 | Hearing-distance factors applied to speed. |

Speed modifiers that still apply on top: `GameState.speed_mult()` (sneakers upgrade), blocking
×0.55, charging a heavy ×0.75.

## Movement states (player)

```text
GROUNDED_RUN ──Shift+forward──▶ GROUNDED_SPRINT
     │  ▲                            │
  Space│  └──land, Space not held────┤
     ▼                               ▼ Space (held or buffered)
  AIRBORNE ◀────────────────── jump (no friction on the landing frame)
     │   land + Space held → jump again (bhop keeps sprint if Shift held)
     │   land + crouch held + speed ≥ slide_start_speed → SLIDING
GROUNDED_* ──crouch, speed ≥ slide_start_speed──▶ SLIDING ──speed < slide_min_speed / release──▶ CROUCH or RUN
SLIDING ──Space──▶ AIRBORNE (keeps momentum)
```

Invariant: no state transition changes stamina (FR-003, SC-004).
