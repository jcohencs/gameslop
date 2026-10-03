# Feature Specification: Content Expansion 1

**Feature Branch**: `claude/determined-gates-4azszv`

**Created**: 2026-10-03

**Status**: Draft

**Design pillars**: Hustle (orders, tactics), Escape (raid events, ball pit), Brawl (Nana), Silly (Pizza Party Palace)

**Input**: User description: "Content expansion 1 to flesh out the game: (1) Collector Orders bounty board in the hideout - 3 orders like "deliver 2 Holo cards" or "deliver a Charzard" that pay bonus cash when fulfilled from the stash, refreshed after each raid; (2) new location "Pizza Party Palace" (birthday-party pizza arcade) with a ball pit twist that slows movement but hides the player from adults, arcade cabinets as cover, and a mascot guard "Cheesy the Rat"; (3) two new scam tactics: Sob Story (free, low odds, no heat, kid never cries) and Bundle Deal (costs 3 junk, good odds, low heat); (4) raid events: a Whale kid with a guaranteed Legendary card shown with a gold glow, plus one random raid modifier per raid (e.g. Bake Sale - adults slower to notice; Report Card Day - heat decays slower; Free Refills - kids respawn faster) announced at raid start; (5) new adult type Nana: slow, tanky, long-reach telegraphed cane swing, appears at 3+ heat stars."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Collector Orders (Priority: P1)

At the Shady Van, the player sees a board of three collector orders, such as "Deliver 2 Holo
cards: $260" or "Deliver any Charzard: $90". If their stash holds qualifying cards, they fulfill
the order and get more cash than they would by selling those cards normally. After each raid, the
board refreshes with new orders.

**Why this priority**: it gives every raid a goal beyond "grab the most expensive card" and deepens
the economy (Hustle). It also works with all the existing locations.

**Independent Test**: put qualifying cards in the stash, fulfill an order, and confirm the cards
leave the stash and the bonus cash is paid. Finish a raid and confirm the orders change.

**Acceptance Scenarios**:

1. **Given** the hideout is open, **When** the player opens the Orders view, **Then** exactly
   three orders are shown, each with its requirement, reward, and whether the stash can fill it now.
2. **Given** the stash holds enough qualifying cards, **When** the player fulfills an order,
   **Then** the cheapest qualifying cards are removed, the reward is added to cash, and the order
   is marked complete.
3. **Given** the stash cannot fill an order, **When** the player looks at it, **Then** the fulfill
   action is disabled and the order shows what's missing.
4. **Given** any raid ends (extract or loss), **When** the player returns to the hideout, **Then**
   the board shows three newly rolled orders.
5. **Given** the game is saved and reloaded, **When** the hideout opens, **Then** the same orders
   are shown.

---

### User Story 2 - Pizza Party Palace (Priority: P1)

A new location: a birthday-party pizza arcade full of kids, with arcade cabinets, party tables, a
prize counter, a stage, and a big ball pit. The ball pit slows the player down but hides them from
adults, so it becomes a place to lose a chase. A costumed mascot guard, "Cheesy the Rat," patrols
the party.

**Why this priority**: it's a new place to hustle with its own mechanic (Escape, Silly), as the
constitution's level-design principle requires.

**Independent Test**: deploy to the Pizza Party Palace. Confirm kids, extracts, the mascot guard and
the navmesh all work. Confirm that standing in the ball pit slows the player and makes adults lose
sight of them.

**Acceptance Scenarios**:

1. **Given** the hideout's deploy screen, **When** the player looks at locations, **Then** Pizza
   Party Palace is listed with its entry fee, danger, loot, timer, kid count and guard.
2. **Given** the player deploys there, **When** the raid starts, **Then** there are 12 kids, two of
   three extracts are active, and Cheesy the Rat is patrolling.
3. **Given** the player is in the ball pit, **When** they move, **Then** their speed is at most
   half of normal and they cannot bunny hop out at speed.
4. **Given** an adult is chasing the player, **When** the player is in the ball pit more than
   2.5 m from that adult, **Then** the adult cannot see them and must search.
5. **Given** adults are pathing around the level, **When** they chase the player, **Then** they
   route around cabinets and tables instead of getting stuck.

---

### User Story 3 - New Scam Tactics (Priority: P2)

The trade screen gains two tactics:

- **Sob Story:** free, low odds, no heat, and the kid never cries.
- **Bundle Deal:** costs 3 junk cards, good odds, low heat.

**Why this priority**: more choices make each trade a real decision (Hustle).

**Independent Test**: open a trade, check both tactics show odds, cost and heat, then run each one
and check the outcome rules.

**Acceptance Scenarios**:

1. **Given** a trade is open, **When** the player reviews tactics, **Then** five tactics are shown,
   each with odds, cost and heat.
2. **Given** Sob Story succeeds or fails, **When** the result resolves, **Then** heat does not
   change and the kid does not cry (on failure the kid just walks off unimpressed).
3. **Given** the player has fewer than 3 junk cards, **When** they view Bundle Deal, **Then** it is
   unavailable and says why.
4. **Given** Bundle Deal is used, **When** it resolves, **Then** 3 junk cards are spent whether it
   succeeds or not.

---

### User Story 4 - Raid Events: Whale Kid and Modifiers (Priority: P2)

Every raid has one Whale: a kid holding a guaranteed Legendary card who glows gold, is marked
"WHALE", and has a chaperone Soccer Mom hanging out nearby. Every raid also rolls one random
modifier that changes the rules for that run. It's announced when the raid starts and shown on the
HUD.

**Why this priority**: it adds variety and a reason to take risks (Escape).

**Independent Test**: start several raids and confirm exactly one Whale kid with a Legendary card
and a chaperone each time, plus exactly one modifier that's announced, shown, and affects its system.

**Acceptance Scenarios**:

1. **Given** a raid starts, **When** the kids spawn, **Then** exactly one is a Whale with a
   Legendary card and a gold glow, and an adult chaperone patrols near them.
2. **Given** a raid starts, **When** the HUD appears, **Then** one modifier name and a one-line
   description are shown for the whole raid, and the start message announces it.
3. **Given** the Bake Sale modifier, **When** adults look for the player, **Then** their sight range
   is 30% shorter.
4. **Given** the Report Card Day modifier, **When** heat decays, **Then** it decays at half the
   normal rate.
5. **Given** the Free Refills modifier, **When** kids leave, **Then** replacements arrive twice as
   fast.
6. **Given** the Holo Hype modifier, **When** cards are rolled, **Then** Rare-or-better cards are
   noticeably more common.

---

### User Story 5 - Nana (Priority: P3)

A new adult, Nana, appears once heat reaches 3 or more stars. She is slow and tanky. Her cane swing
reaches further than any other adult's and has a longer, clearly visible wind-up.

**Why this priority**: a new kind of melee threat (Brawl), on top of the existing adults.

**Independent Test**: raise heat to 3+ stars and confirm Nana can appear. Fight her and confirm her
reach, wind-up and toughness.

**Acceptance Scenarios**:

1. **Given** heat is below 3 stars, **When** adults spawn, **Then** Nana never appears.
2. **Given** heat is 3 stars or higher, **When** adults spawn, **Then** Nana can appear.
3. **Given** Nana attacks, **When** she winds up, **Then** the wind-up lasts noticeably longer than
   other adults' and her hit lands from about 2.8 m.
4. **Given** Nana is fought, **When** her health is compared, **Then** she is tougher than a PTA
   President but slower than every other adult.

### Edge Cases

- **Order needs more of a rarity than the stash has:** the order stays unfillable, nothing is
  removed, and it rolls away after the next raid.
- **Several orders could use the same card:** fulfilling one removes cards, and the other orders
  re-check what's left.
- **Old save without orders:** a fresh board of three is created on load. No progress is lost.
- **Whale kid scammed:** the kid behaves like any other scammed kid. The chaperone reacts to the
  crying like any parent.
- **Whale kid leaves and is replaced:** respawned kids are never Whales. There is only one Whale
  per raid.
- **Ball pit while a parent is within 2.5 m:** the parent can still see and hit the player. The pit
  hides you, it doesn't make you invulnerable.
- **Jumping into the ball pit at speed:** speed is reduced to the pit cap on entry.
- **Free Refills with the kid cap:** kids still never exceed the location's kid count.

## Requirements *(mandatory)*

### Functional Requirements

**Collector Orders**

- **FR-001**: The hideout MUST show three collector orders at all times.
- **FR-002**: Each order MUST be one of these types: (a) N cards of a given rarity or better (Rare,
  Holo, Legendary; N of 1–3), or (b) one card with a specific name.
- **FR-003**: An order's reward MUST be at least 1.5× the normal sell value of the cheapest
  qualifying cards, rounded to the nearest $5.
- **FR-004**: Fulfilling an order MUST remove the cheapest qualifying stash cards and pay the
  reward immediately.
- **FR-005**: All three orders MUST be re-rolled after every raid ends, whatever the outcome.
- **FR-006**: Orders MUST persist in the save. Saves without orders MUST load with a fresh board.

**Pizza Party Palace**

- **FR-007**: A new location, Pizza Party Palace, MUST be deployable from the hideout. It has a
  $25 entry fee, a 5:00 timer, 12 kids, loot between the Locals and the Mall, and danger 2.
- **FR-008**: The location MUST include arcade cabinets, party tables, a prize counter, a stage and
  a ball pit. All blocking props MUST be navigable around by adults.
- **FR-009**: It MUST have three extracts in different areas (Kitchen Back Door, Parking Lot, Ball
  Pit Slide).
- **FR-010**: Inside the ball pit the player's speed MUST be capped at 50% of run speed, and adults
  MUST NOT see the player beyond 2.5 m. Player noise MUST be halved while in the pit.
- **FR-011**: Cheesy the Rat MUST patrol the location as its guard, with unique stats and look
  (mascot costume), and react to scams he witnesses like other guards.

**Scam tactics**

- **FR-012**: Sob Story MUST cost nothing, have low base odds (35%), add no heat, and never make the
  kid cry. On failure, the kid leaves the trade without crying.
- **FR-013**: Bundle Deal MUST cost 3 junk cards (spent either way), have good base odds (80%),
  add low heat (5), and have a low cry chance (15%).
- **FR-014**: Both tactics MUST follow the existing rules: rarity and wary penalties, upgrade
  bonuses, the binder-full block, and visible odds, cost and heat.

**Raid events**

- **FR-015**: Every raid MUST spawn exactly one Whale kid with a Legendary card, a gold glow and a
  "WHALE" tag, plus a chaperone adult (Soccer Mom) placed near them in an unaware state.
- **FR-016**: Every raid MUST roll exactly one modifier from: Bake Sale, Report Card Day, Free
  Refills, Holo Hype. The modifier is announced at raid start and shown on the HUD all raid.
- **FR-017**: Modifier effects: Bake Sale gives adults 0.7× sight range. Report Card Day gives
  0.5× heat decay. Free Refills gives 0.5× kid respawn delay. Holo Hype adds +1.0 to the
  location's rare-card bonus.

**Nana**

- **FR-018**: Nana MUST be added as an adult type: health above the PTA President's, the slowest
  move speed of all adults, an attack reach of about 2.8 m, and a wind-up at least 1.5× the normal
  length.
- **FR-019**: Nana MUST appear in the spawn pool only at 3+ heat stars.

**Cross-cutting**

- **FR-020**: The README, pause-menu help and hideout descriptions MUST cover the new location,
  tactics, orders and events.

### Key Entities

- **Collector Order**: type (rarity count or named card), requirement (rarity and count, or card
  name), reward, and a check for whether the stash can fill it.
- **Raid Modifier**: id, display name, one-line description, and its effect on sight, heat decay,
  kid respawn or rarity.
- **Whale**: a flag on one kid per raid, with a guaranteed Legendary card and a linked chaperone.
- **Location (Pizza Party Palace)**: the same fields as existing locations, plus ball-pit zones.
- **Adult type (Nana, Cheesy the Rat)**: the same fields as existing adult types, plus a per-type
  reach and wind-up length.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The hideout always shows 3 orders. Fulfilling any order pays at least 1.5× the
  removed cards' sell value.
- **SC-002**: After every raid outcome (extract, knockout, timeout, abandon), 3 new orders are
  shown.
- **SC-003**: In 10 consecutive raid starts, each raid has exactly 1 Whale kid with a Legendary
  card and exactly 1 announced modifier.
- **SC-004**: In the ball pit, the player's speed never exceeds 2.5 m/s, and an adult more than
  2.5 m away loses sight of them.
- **SC-005**: The Pizza Party Palace raid starts with 12 kids, 2 active extracts, 1 mascot guard,
  and a working AI path from the player spawn to the kid areas.
- **SC-006**: Sob Story never changes heat and never makes a kid cry, across 20 attempts.
- **SC-007**: Nana never appears below 3 stars, and appears at least once in 30 spawns at 5 stars.

## Assumptions

- Order rewards scale with the card values the existing economy rolls, so they stay balanced as the
  sell-price upgrade grows.
- The chaperone is a regular Soccer Mom that starts unaware next to the Whale. She is not a new
  adult type.
- Holo Hype and Free Refills are "good" modifiers and Report Card Day is a "bad" one. Bake Sale
  favors the player. The mix is intentional: modifiers add variety, not just difficulty.
- The ball pit hides the player only from sight. Adults can still hear loud actions nearby
  (fighting).
- Cheesy the Rat's stats sit between Gary and the Mall Cop, matching the location's difficulty.
