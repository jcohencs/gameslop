# Research: Wave Mode, Smarter Adults and a Level Art Pass

## R1. What does "shooter" mean in this game?

- **Decision**: cartoon toy blasters (foam darts, water, paintballs, bubbles, a rubber chicken
  launcher), in a separate Wave Mode only.
- **Rationale**: Constitution IX (non-graphic cartoon satire) and the earlier switch from guns to
  fists. Toy blasters keep the tone and still deliver shooter feel. The constitution was amended
  (v2.1.0, Principle XIII) to allow ranged toys in Wave Mode.
- **Alternatives**: realistic guns (violates IX and the pitch); blasters in raids (would undercut
  the melee-and-stealth raid design).

## R2. Hit registration

- **Decision**: hitscan rays from the camera (mask: world + adults) decide damage instantly; a
  visual dart, paintball or bubble flies from the muzzle to the hit point. The rubber chicken is a
  real simulated projectile (it arcs and splashes).
- **Rationale**: instant feedback, cheap, deterministic in tests. Masking out layer 4 makes kids
  physically unhittable.

## R3. Surround behavior

- **Decision**: the controller hands each chasing adult a slot index. Slot angles are spread evenly
  around the player starting from the first chaser's bearing. Far from the player (over 6 m), an
  adult paths to a point on its slot's bearing (ring radius shrinking with distance); close in, it
  chases directly and the existing attack tokens take over.
- **Rationale**: deterministic spread (testable), works with the navmesh, cheap.
- **Alternatives**: boids-style steering (unpredictable), random flank offsets (can cluster).

## R4. Ranged adults

- **Decision**: ranged types keep a distance band, require line of fire (ray to the player's
  chest), take a "throw token" (max 2, +1 from wave 6), wind up 0.55-0.7 s, then throw at the
  predicted position (player position + velocity × flight time). Fastballs fly straight; water
  balloons arc (ballistic velocity solved for the flight time) and splash.
- **Rationale**: telegraph + lead = fair and dodgeable; a player who changes direction after the
  release makes the prediction miss.

## R5. Stuck recovery

- **Decision**: if an adult wants to move (> 1 m/s) but its real speed stays under 0.4 m/s for
  1 s, it walks toward a random side detour point for 0.8 s, then resumes.

## R6. Arena lighting

- **Decision**: a ceilinged gym lit by ambient sky light plus 6 shadowless omni lights under the
  hanging lamps. On High: 4 spot lights through the high windows feed volumetric fog light shafts,
  and SSR makes the glossy court reflect. Low: no spots, no SSR, no volumetric fog.
- **Rationale**: Compatibility ignores SSR and volumetric fog, so Low and Compatibility look the
  same and stay fast.

## R7. Decals

- **Decision**: paint splats are small flat discs aligned to the hit normal, and stuck darts are
  small meshes along the shot direction. Both live in capped ring buffers in `Art` (120 / 60);
  the oldest is freed first.
- **Alternatives**: `Decal` nodes (not available on Compatibility in 4.3).

## R8. Economy

- **Decision**: KOs in Wave Mode pay 25% of the raid reward; each cleared wave pays 15 × wave
  number. A wave-10 run earns roughly $1,000-1,300, compared with $200-600 for a good raid at the
  same skill, but it takes about 15-20 minutes and is much riskier, so raids stay competitive.
