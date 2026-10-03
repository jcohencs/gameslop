# Feature Specification: STRAFTAT-Style Movement Retune

**Feature Branch**: `claude/determined-gates-4azszv`

**Created**: 2026-10-03

**Status**: Draft

**Input**: User description: "Movement retune to feel like STRAFTAT: bring back sprinting on Shift and let players bunny hop while sprinting (holding Shift + Space keeps sprint speed through hops); overall movement speed must be way lower than now (current run 7.5 m/s, max 24 m/s, big slide boost feels too fast); keep slide, crouch, bhop and air strafing but with tighter, more controlled speeds and caps so it feels snappy and skill-based rather than floaty and zoomy. Stamina must stay free for movement (only heavy attacks cost stamina)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Sprint and bunny hop while sprinting (Priority: P1)

A player holds Shift to sprint across the level. While still holding Shift they hold Space to chain
bunny hops, and they keep sprint speed from hop to hop instead of dropping back to running speed.

**Why this priority**: This is the change the player explicitly asked for, and sprint plus bhop is the
core of the STRAFTAT feel.

**Independent Test**: Start a raid, hold Shift + forward, then hold Space. Over several hops, ground
speed stays at sprint speed (no slowdown between hops) and never needs stamina.

**Acceptance Scenarios**:

1. **Given** the player is standing still on the ground, **When** they hold Shift and forward,
   **Then** they reach sprint speed within about half a second.
2. **Given** the player is sprinting, **When** they hold Space for 3 seconds, **Then** they hop
   continuously and their horizontal speed stays at or above sprint speed.
3. **Given** the player is sprinting or hopping, **When** they check the stamina bar, **Then** it has
   not dropped. Only charged heavy attacks spend stamina.

---

### User Story 2 - Lower, controlled overall speeds (Priority: P1)

Movement feels snappy and grounded rather than zoomy. Running, sprinting, sliding and hopping all
top out at much lower speeds than before, so fights stay readable and parents can keep up.

**Why this priority**: The player said speed must be "way less". Without this, the retune fails even
if sprint-hopping works.

**Independent Test**: Use every movement option (run, sprint, slide, slide-hop, bhop, air strafe)
and confirm no option exceeds the new hard speed cap, and that each tops out near its target.

**Acceptance Scenarios**:

1. **Given** the player runs normally, **When** they reach top speed, **Then** it is about two
   thirds of the old running speed.
2. **Given** the player chains slides, hops and air strafes as well as possible, **When** they
   measure peak speed, **Then** it never goes over the new cap of about half the old maximum.
3. **Given** the player starts a slide from a sprint, **When** the slide begins, **Then** they get a
   small, noticeable boost, not a big launch.

---

### User Story 3 - Skill expression stays (Priority: P2)

Skilled players can still gain a little speed by air strafing and by timing slide-hops. The gain is
gradual and bounded, so good movement is an edge, not a teleport.

**Why this priority**: Keeps the depth of the system while honoring the lower speeds.

**Independent Test**: Air strafe correctly for several hops and confirm speed rises above sprint
speed a bit, then levels off at the cap.

**Acceptance Scenarios**:

1. **Given** the player bhops with correct air strafing, **When** they hop 5 or more times, **Then**
   their speed rises gradually above sprint speed, reaching the cap after several hops at most.
2. **Given** the player spams crouch to slide repeatedly, **When** they try to stack slide boosts,
   **Then** boosts are rate-limited so spamming does not gain speed.

### Edge Cases

- Releasing Shift mid-hop: the player keeps their current momentum in the air and settles back to
  running speed once on the ground without hopping.
- Sprinting backwards or purely sideways: no sprint bonus. Sprint applies only while moving forward.
- Sprinting while blocking or charging a heavy: those slowdowns still apply over sprint.
- Crouching under a low ceiling and then releasing crouch: the player stays crouched until there is
  room to stand.
- Getting knocked back by a hit while at the speed cap: knockback is still applied, and the result
  is clamped to the cap.
- Since Shift becomes sprint, the old quiet walk moves to crouch-walking, which is the quiet option.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Holding Shift while moving forward MUST make the player sprint at a higher speed
  than running.
- **FR-002**: Holding Shift and Space together MUST chain bunny hops that keep sprint speed. Each
  landing MUST jump again with no ground slowdown.
- **FR-003**: Sprinting, jumping, bunny hopping, sliding and crouching MUST NOT cost stamina.
- **FR-004**: Base running speed MUST drop to about 5 m/s (from 7.5) and sprint speed MUST be about
  6.8 m/s.
- **FR-005**: The absolute horizontal speed cap MUST drop to about 12 m/s (from 24).
- **FR-006**: The slide boost MUST be small (about +2 m/s) and limited to once per second.
- **FR-007**: Air strafing MUST still add speed, but more gradually than before, so reaching the cap
  takes several well-strafed hops.
- **FR-008**: Crouch-walking MUST be the quiet movement option (shorter hearing distance for
  parents), since Shift is no longer the quiet walk.
- **FR-009**: The speed-based camera widening and the on-screen speedometer MUST scale to the new
  speed range, so they react within it instead of only near the old top speeds.
- **FR-010**: The in-game help (pause menu, controls hints) and the README MUST describe Shift as
  sprint and crouch as the quiet option.

### Key Entities

- **Movement profile**: the set of target speeds and limits (run, sprint, crouch, slide boost and
  cooldown, air strafe gain, hard cap), all tunable in one place.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Peak horizontal speed under any combination of movement inputs stays at or below
  12 m/s.
- **SC-002**: Holding Shift + Space for 3 seconds from a sprint keeps horizontal speed at or above
  6.5 m/s the whole time.
- **SC-003**: Sustained running speed is between 4.5 and 5.5 m/s, and sustained sprint speed between
  6.3 and 7.3 m/s.
- **SC-004**: Stamina does not decrease during 10 seconds of continuous sprinting, hopping and
  sliding.
- **SC-005**: A single slide from a sprint adds no more than 2.5 m/s, and two slides within one
  second add boost only once.

## Assumptions

- "Like STRAFTAT" is taken to mean Quake/Source-style movement (ground friction, air strafing,
  bhop, crouch-slide) at grounded, readable speeds. Wall-running and dashes are out of scope.
- Parent and kid speeds are unchanged. With lower player speeds, parents become relatively more
  threatening; that is intended and can be retuned later.
- The quiet-walk role moves from Shift to crouch-walking rather than adding a new key.
- Speeds are given in meters per second as measured by the in-game speedometer.
