# Feature Specification: Realistic First-Person Hands

**Feature Branch**: `claude/determined-gates-4azszv`

**Created**: 2026-10-04

**Status**: Draft

**Design pillars**: Brawl (the hands are the player's main feedback for every punch, swing, throw
and shot)

**Input**: User description: "i wanna make the hands really realistic like doom for the player"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Real Hands, DOOM-style (Priority: P1)

The player's first-person hands look like real, chunky action-game hands instead of colored balls.
Each hand has a palm, four jointed fingers with knuckles and nails, and an opposable thumb. They
wear fingerless tactical gloves with armored knuckle plates and a wrist strap, and sit on sleeved
forearms with a visible wrist. The left wrist has a digital watch.

**Why this priority**: it is the whole request, and the hands are on screen 100% of the time.

**Independent Test**: start a raid and confirm each hand has 5 digits of 3 segments, a palm, nails
and glove parts.

**Acceptance Scenarios**:

1. **Given** any weapon or blaster, **When** it is equipped, **Then** both hands are built with 5
   digits of 3 segments each, plus palm, glove and forearm.

---

### User Story 2 - Hands That Act (Priority: P1)

The fingers move like a real grip: tight fists for fists (clenching harder on each punch), fingers
wrapped around a sword handle, a pistol grip with the index finger on the trigger, a support hand
cupping the blaster's fore-grip, a pouch held in a fist that flings open on a pocket-sand throw.
The trigger finger squeezes on every shot. At rest, fingers breathe with tiny idle movements.

**Why this priority**: realistic geometry with frozen fingers still reads as fake.

**Independent Test**: switch between fist, sword and blaster and compare finger joint angles;
fire a blaster and confirm the index finger curls and returns.

**Acceptance Scenarios**:

1. **Given** fists equipped, **When** compared with an open hand, **Then** every finger is curled
   at least 2.5 radians in total across its joints.
2. **Given** a blaster equipped, **When** the player fires, **Then** the right index finger curls
   further for a moment and then returns.
3. **Given** pocket sand, **When** it is thrown, **Then** the throwing hand opens.

### Edge Cases

- Boxing gloves still show big boxing gloves (the hand is inside them).
- Brass knuckles and the Power Gauntlet attach to the knuckles of the new hands.
- Switching weapons mid-animation snaps the hands to the new grip.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Each hand MUST be built in code with a palm, four three-segment fingers, a
  three-segment thumb, knuckle bumps and fingernails.
- **FR-002**: Hands MUST wear fingerless gloves with knuckle armor and a wrist strap; forearms MUST
  have a sleeve and cuff with visible skin at the wrist; the left wrist MUST have a watch.
- **FR-003**: Skin MUST use a non-cartoon material with fine surface detail (a generated pore
  normal map) and, where supported, subsurface scattering.
- **FR-004**: Hand poses (open, relaxed, fist, tight fist, sword grip, trigger, support, throw)
  MUST be data, and changes MUST blend smoothly.
- **FR-005**: Every weapon and blaster MUST use a fitting pose for each hand; punches clench, shots
  squeeze the trigger, sand throws open the hand.
- **FR-006**: The first-person hands are still never outlined (this supersedes "toon-shaded" for
  the arms in specs/003's visual contract).

### Key Entities

- **Hand**: side (left or right), segments, materials, current and target pose.
- **Hand pose**: curl per finger joint, thumb curl, finger spread.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 2 hands × 5 digits × 3 segments = 30 jointed finger segments on screen.
- **SC-002**: Fist vs open: every finger's total curl differs by at least 2.5 radians.
- **SC-003**: The trigger finger's curl rises on a shot and is back within 0.3 s.
- **SC-004**: All 7 melee weapons and 5 blasters equip without errors and use their poses.
- **SC-005**: All previous smoke checks still pass.

## Assumptions

- "Like DOOM" means chunky, detailed, gloved action-game hands with expressive grips, not
  photoreal scanned hands. Everything is still generated in code (Constitution X).
- Character hands (adults and kids) stay cartoon; only the player's first-person hands change.
