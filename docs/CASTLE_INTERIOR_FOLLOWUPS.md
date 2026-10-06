# Remaining castle interior work

The original findings date from INT-007 on 2026-09-13. Plans now exist for
ridge ranges, tower houses and motte keeps. Their existence did not establish
complete castle occupancy: the independent inventory added on 2 October found
whole missing interiors and windows above the rooms actually represented.
The broad CASTLE-INTERIOR-FORMS task remains open.

## Status after the 6 October 2026 pass (CASTLE-INTERIOR-FORMS)

Every form named in the inventory (`CastleOccupancyCheck.expected_ids`) now has
a planner. What changed, and what is still red, measured with
`artifacts/castle_todo/sweep_occ.gd`-style sweeps (build, occupancy, route and
per-plan HouseQA over the canonical style x tier x size grid):

Done and green on the bounded lane (`lane:castle-change`, `cridgeoccupancy`,
`coccupancy`, `cmotteaccess`, `cmotteroute`, `cgatestairs`, `ctowerhouse`):

- Walled castles: mural towers, gatehouse chamber and apse are planned for every
  enclosed plan, not only the motte (`castle_mural_plan.gd`, `castle_gate_plan.gd`,
  `castle_apse_plan.gd`). A slender tower coarsens its facets (12, 8, 6, 4) until
  a facet takes a door; the door floor is fitted to the coping; a tower lower
  than the coping, or one no gallery reaches, is entered from the ward.
- Manors and houses: `castle_manor_plan.gd` plans wings (a ridge range turned to
  the court), the courtyard front range (guard bay, passage, guard bay, one room
  above), the annexe, the front towers and the tower-house jogs. A wing starts
  at its tower's rear face and masonry cheeks fill the strip beside the tower.
- Ridge castles: `castle_ridge_plan.gd` trims each range at its vertex towers
  (mitre-safe cut), fills the old overlap with solid cheeks, and plans the vertex
  towers and the dark spire (the castle's `keep`). Dormers over a planned mass
  are shuttered blind gablets: a window must open into a room.
- Sky castles: each turret-island is a stack of rooms entered a storey up from
  the bridge that leaves it.
- QA: `_check_room_floor` counts samples outside stair wells (dais measured at
  its rise) and wants half of them supported; the mutation harness removes every
  floor triangle that reaches the room.

Found and fixed on the way (each one made a whole family read red):

- A flat-topped tower house has no roof slot, so `commit()` slid its glazing
  from surface 3 to surface 2 and every opening check read it as masonry.
  `_keep_surface_slots` now holds every empty slot below a populated one.
- `tower_door_sill`: a 5.7 m storey could not hold a 2.6 m door above a 4 m
  sill; the head went through the ceiling.

Still open (this is why the task stays pending):

- Tight ridge zigzags (every `dark` castle, 40 to 55 m): the ranges are as wide
  as the pitch between vertices, so the mitre-safe cut leaves no room; the
  ranges and towers stay solid blocks and their required records are missing.
  A real answer clips the end bays to mitred polygons (convex room outlines).
- Tower-house shaft (not the jogs): the roof-platform room is emitted as a full
  storey of walls above the deck and fills the stair opening; the platform room
  sticks out of its interior and is reached only through a lord's chamber; the
  approach steps block `lords_walk`; jog windows can face the approach steps.
  `ctowerplan` (wizard oval) and `cforms` were red before this pass.
- Castles whose towers are shorter than the curtain walk (the smallest tier of
  every walled style): ground doors meet the 0.65 m wall footing; stairs do not
  reach the upper storeys of the small rooms (nav).
- Polygon and rect keeps: planned windows are filled by sliver wall pieces
  (tiered or polygonal keep outlines against `extend_upper_walls`); the motte
  shell keep's windows on seeds other than 8856.
- Gate chamber routes in some rect and fortress cases are crossed by masonry
  (`access_routes[gate_N]`), and some side-tower walk routes have no floor.
- `hall` has no plan in a few fortress/crusader cases (too large or too small a
  range), so its required record is missing.

## Plans for ridge castles, tower houses and motte shell keeps

Current entry points:

- `src/castle/castle_interiors.gd::primary` dispatches ridge ranges and tower
  houses to their local plans. Inventory coverage still needs to include ridge
  defensive towers, tower-house jogs, manor annexes/wings and sky towers.
- Ridge ranges use `CastleInteriorPlans.ridge_range_plan` in each segment's
  rotated frame. Seed 8805 exposed upper facade windows without upper rooms;
  the multistorey repair and its emitted-floor evidence are still in progress.
- Tower-house plans represent the main tapered storeys and raised entrance.
  `tower_jog_aabbs` still require independent occupied plans and real access.
- Motte plans use the mound-fitted oval at `shell_keep_aabb`. The seed 8856
  furnished fixture now passes full CastleQA: its keep, hall, chapel, sanctuary,
  gate chamber and six mural towers have room-backed openings. Seven defensive
  entrances reach courtyard ground through two real wall stairs. Fresh renders
  are being inspected separately; this fixture does not close the broad task.

Implementation requirements:

1. Add pure, local plan generators for each supported form. Derive dimensions,
   per-floor outlines, origins and rotations from the same geometry records the
   builder consumes. Plan records must own openings, floors, stairs, furniture
   and explicit omissions; keep model loading in the assembler.
2. For ridge ranges, generate each rotated range in its own frame and represent
   doors/connections between touching ranges. Do not treat the world AABB as the
   local floor or as the opening surface.
3. For tower houses, represent the actual storey count, floor heights, tapered
   floors and jogs. Model the elevated exterior entrance plus its actual approach
   and stairs. Replace the ground-only entrance rule only with a stricter family
   rule that proves this route, never a blanket exemption.
4. For the motte, use `shell_keep_aabb` and the oval inner floor at the correct
   mound height. Decide explicitly whether its centre is an open court or an
   occupied building. Cut real doorway geometry and prove the route up the mound.
5. Replace the corresponding solid bodies with stone shells, preserve top-level
   mass records, and group HouseQA reports by stable building ID. Extend the
   castle walk across the actual terrain and connected building entrances.

Acceptance and reproduction:

- Use canonical `CastleLandmarkSuite` fixtures for the ridge castle, tower house
  and motte at the suite's small/default/large scales; preserve their shape and
  top-level mass assertions.
- Compare each local room outline and transformed opening against emitted mesh
  triangles. A rectangular-room/AABB substitution must fail for rotated and oval
  hosts. A filled doorway or upper stair opening must fail a ray-based check.
- Assert that every stair landing fits both adjacent actual floor polygons and
  that the terrain/entrance route reaches all occupied rooms.
- Require grouped HousePlanCheck, HouseFurnishCheck and HouseNavCheck reports;
  any genuine plan, furnishing or access failure must fail CastleQA.
- Run `tests/run_all.gd -- castle cnormals cmassing clandmark cvoxelqa` plus the
  castle interior/plan-shell suites. Render each new form with roofs on and off.

## Polygon wall indices in furniture affinity and secondary QA

The core wall placer already uses `HouseGeometry.room_walls`. Several affinity
and secondary-check helpers still assume four AABB walls in the order front,
back, left, right. A polygon's walls instead follow its outline; even a four-point
square has a different order. A 14-sided keep makes indices above three valid.

Confirmed remaining locations:

- `HouseFurnisher._back_wall_index`, `_wall_normal`, `_window_crowding`,
  `_wall_has_window`, `_over_bonus` and the other `_wall_normal`
  callers in `src/house/house_furnisher.gd`.
- `HouseFurnishCheck._fs_back_wall`, `_fs_wall_normal`, `_fs_wall_lit`, the
  four-wall loop in `_check_bed_window`, and remaining `_fs_wall_normal` callers
  in `qa/house_furnish_check.gd`.
- INT-007 already fixed `HouseFurnishCheck._wall_of` for fireplace/chimney
  agreement. Preserve its new polygon-normal lookup and regression tests.
- INT-007 also fixed paired lamps: `_flank_wall`, `_flank_anchor`,
  `_flank_station` and `_flank_bonus` now use actual facets, as do the independent
  `_fs_pair_wall`, `_check_sconce_pair` and `_fs_pair_fits` checks. Adjacent
  14-gon faces must remain distinct; their normals have a dot product just over
  0.9, which is too loose a same-wall threshold. Preserve the oblique pair,
  adjacent-facet, off-symmetry and beyond-facet regressions in
  `tests/suites/polygon_sconce_suite.gd`; pairing is complete, not new work.
- Rotated prop footprints, polygon overhang detection, and four-corner bounds
  for access/window strips are also fixed. Preserve
  `tests/suites/castle_keep_furnishing_suite.gd`; do not defer or duplicate these
  physical corrections.

Replace AABB wall identification with measured distance/facing against actual
room edges, and retrieve normals from those same wall records. Update producers
and independent checks together while preserving the existing rectangular
results. Review projections onto diagonal walls; `.abs()` of a tangent can
destroy its signed direction. Do not use the placement's declared wall index as
the check's only evidence.

Acceptance:

- Construct the same square both as a rectangle and as a polygon with rotated
  starting vertex and reversed winding. Physical placement preferences and QA
  outcomes must agree regardless of numeric wall labels.
- Add an octagon and 14-gon with windows, a blind bed wall, a fireplace and
  shelving on edges whose indices exceed three. Preserve the existing paired
  lamp regressions while changing shared wall helpers.
- Mutate a bed onto a glazed wall, a bookcase onto the fireplace wall and a shelf
  away from its host. Each relevant check must detect its physical defect.
- Run shaped-room, keep, house-furnishing and asset suites. Review room renders
  to confirm that furniture faces the actual wall and remains navigable.

## Generation and QA performance

Large castle generation and validation remain expensive. The
[CASTLE-INTERIOR-PERF task](tasks/castle_interior_performance.json) records the
observed suite timings, representative fixtures, and required phase profiles.
Those timings were collected under concurrent load and are not isolated
generation benchmarks. Preserve complete plans, RNG state, furniture and
navigation resolution while identifying the cost. The implementation and
[verification commands](CASTLE_INTERIORS.md#verification) include `hassembly`
to protect the measured model-pivot, wall-mount and bed-headboard corrections.
