# Remaining castle interior work

These findings were confirmed while completing INT-007 on 2026-09-13. The new
bridge emits the existing valid hall, keep, chapel and bailey-shop HousePlans.
The forms below need new plan geometry before they can use that bridge.

## Plans for ridge castles, tower houses and motte shell keeps

Current entry points:

- `src/castle/castle_interiors.gd::primary` deliberately excludes ridge and
  tower-house forms. Do not remove this guard until their plans match the mesh.
- `CastleBuilder._build_ridge` emits rotated ranges from
  `CastleGeometry.ridge_ranges`. `CastleGenerator.hall_plan` instead reads
  `CastleGeometry.hall_aabb`, an axis-aligned range unrelated to the actual ridge
  segment. Reusing that plan places floors, doors and props outside their host.
- `CastleBuilder._build_tower_house` emits each `tower_storey_aabb`, the platform
  and `tower_jog_aabbs`. Its entrance is elevated to `tower_door_sill`, and the
  floors can exceed the keep programme's three or four levels. The ordinary hall
  and keep plans do not describe this geometry or its entrance route.
- `CastleBuilder._build_motte` emits an oval ring at `shell_keep_aabb` on the
  mound. The ordinary `keep_aabb` describes a different location in the bailey.
  `castle_keep_plan.gd::generate` therefore returns no plan for motte castles.
  The historic painted doorway in the oval ring is not an enterable opening.

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
