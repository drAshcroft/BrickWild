# Furniture belongs to actual walls

Room wall indices are local edge identifiers. For polygon rooms, they have no relationship to north, south, east or west. Read the inward normal and tangent from `HouseGeometry.room_walls()` before measuring windows, fireplaces or furniture against a wall. Tangent projections must preserve their sign; taking absolute components silently folds opposite directions together.

The furnisher measures an oriented prop footprint from its catalogue dimensions, yaw and scale. Its axis-aligned rectangle remains useful for broad overlap tests, but exaggerates its reach along an oblique wall. Mounted props use their wall-plane anchor. Bed window rules specifically measure the headboard implied by yaw: a bed side alongside a glazed wall is not a headboard against that wall.

The QA checker independently applies the same geometric contract. `tests/polygon_affinity_test.gd` exercises square vertex rotations and both windings, octagons and fourteen-sided rooms, including walls numbered above three. Mutations put headboards against glazing, bookcases against a hearth and shelves away from their host. Existing paired-sconce checks remain in that fixture.

Wall candidates must be recentered for each tested scale. Changing only the rectangle size leaves a scaled prop floating at the full-size wall offset. Beds may shrink by at most twelve percent, and never below two metres long; dimensions continue to come from the measured catalogue. `tests/furnishing_regressions_test.gd` covers the small cottage and the seed-60068 shelf regression.

Seat depth and span must be projected onto the chosen side of the table after
rotation. Reading the rotated footprint's Y component for every side treats a
sideways bench's length as its depth. The full measured body and pull-back zone
remain required. A chair's `host` identifies its table; it still stands on the
floor and must pass room-containment checks.

A table fitting alone does not prove that anybody can sit at it. If a required
dining recipe loses its table because no chair fits, the furnisher makes one
bounded search for a table and full-size chair together, using the existing
allowed table scales, collision rules and use zones. A private seeded RNG keeps
this fallback independent of later recipes. An authored altar/high table keeps
its own contract. The family cottage at seed 21325 now has a 0.76-scale measured
table and a full-size chair in its parlour; ordinary navigation and furnishing
QA pass, and a deliberately displaced chair still fails.
