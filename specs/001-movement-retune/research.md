# Research: STRAFTAT-Style Movement Retune

All Technical Context items were known, so there were no NEEDS CLARIFICATION entries. The decisions
below cover the tuning and design choices.

## 1. Target speeds

- **Decision**: run 5.0 m/s, sprint 6.8 m/s, crouch-walk 2.6 m/s, hard cap 12 m/s.
- **Rationale**: the spec asks for "way less" than run 7.5 / cap 24. About 2/3 of the old run and
  half the old cap keeps fights readable. Parents move at 4.4–6.4 m/s, so sprinting still out-runs
  them, but not by enough to trivialize chases.
- **Alternatives considered**: keeping a 9 m/s sprint (still felt "zoomy" relative to parents);
  removing the cap entirely and relying on friction (lets air-strafe abuse run away).

## 2. Sprint through bunny hops

- **Decision**: sprint is a held state ("sprint held + moving forward"), checked every frame on the
  ground and in the air. While sprinting, the ground wish speed is the sprint speed. A bhop landing
  jumps immediately with no friction, so speed carries. Air strafing uses the same wish speed
  basis, so it never pulls speed down.
- **Rationale**: in the current code a landing-frame jump already skips friction. The bug is that
  there is no sprint, so ground speed settles at run speed between hops whenever the jump buffer
  misses. Holding Space plus held-sprint keeps the hop chain at sprint speed (FR-002).
- **Alternatives considered**: a "momentum preservation" multiplier on landing (hides the
  mechanic, harder to tune).
- **Amendment (found during implementation)**: one frame of normal ground acceleration per hop
  wasn't enough to build speed from a standstill (about 3.4 m/s after 1.6 s). The takeoff frame
  now raises speed along the input direction to the wish speed instantly, without ever lowering
  it. Air strafing is untouched, so speed above sprint still has to be earned.

## 3. Air strafing gain

- **Decision**: air accel 10, air wish cap 0.6 m/s (was 14 and 1.0).
- **Rationale**: a smaller cap means each frame of good strafing adds less, so gaining from sprint
  (6.8) to the cap (12) takes several well-strafed hops instead of one or two (FR-007, US3).
- **Alternatives considered**: per-hop speed bonuses (less skill-based); disabling air strafe (the
  spec requires keeping it).

## 4. Slide

- **Decision**: boost +2.0 m/s, boost cooldown 1.0 s, slide friction 1.4 (was 0.9), slide start
  speed 4.5 m/s, slide exit speed 2.5 m/s.
- **Rationale**: SC-005 needs at most 2.5 m/s per slide and no stacking within a second. Slightly
  more friction makes slides end sooner, so they're a burst rather than a glide.

## 5. Ground feel

- **Decision**: ground accel 10, friction 6, stop speed 2.0, jump velocity 6.2.
- **Rationale**: lower top speeds need slightly softer accel to avoid twitchiness. Sprint should
  still be reached within about 0.5 s (US1 scenario 1). With Quake-style accelerate, time to top
  speed is about 1/(accel·dt) frames, and accel 10 reaches more than 95% in about 0.35 s.

## 6. Quiet movement

- **Decision**: crouch-walk is the quiet option (noise factor 0.35×), and sprint is louder (1.0×)
  than running (0.8×).
- **Rationale**: Shift becomes sprint (FR-001), so stealth moves to crouch (FR-008). Making sprint
  louder adds a trade-off for being fast.

## 7. Where the numbers live

- **Decision**: a `GameState.MOVEMENT` dictionary. The player copies it into typed vars in `_ready`.
- **Rationale**: Constitution III says tuning belongs in GameState tables, and one place to tune
  matches the spec's "Movement profile" entity.
