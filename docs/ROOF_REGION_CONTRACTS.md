# Roof regions and occupied space

A material slot is not a roof contract. A ziggurat's load-bearing ceiling is
stone surface 0, a flat castle turret deck is trim surface 1, and ordinary roof
skins are surface 2. State the intended covered polygon, occupied-space top,
surface and intentional sky holes explicitly. Do not infer them from missing
triangles or a whole castle/village bounding box.

`tests/roof_region_fixtures.gd` supplies named contracts for four-range courts,
polygon halls with circular oculi, three ziggurat sizes, four castle tiers at
two sizes, both hotel styles at two sizes, and two actually placed village
buildings. Rigidly transform the native building mesh and its contract together
for placement tests. Keep unsupported registry kinds visible as uncovered.

Use `tools/check_roofs.ps1 -RegionsOnly` for this bounded matrix. JSON records
source, dimensions, seed, numeric polygons, heights, exclusions, all failing
coordinates and each control's result. Every covered polygon has a negative
control which removes actual surface triangles while preserving its spec.
Intentional courtyards, oculi, terrace strips and battlements must remain open.

Coverage alone cannot establish support. Emit a host-only mesh for attachment
tests so a monument cannot count its own bottom face as its bearing surface.
The ziggurat's actual idol base must fit on the summit; hotel cupola rim vertices
and flat turret deck lower edges must coincide with the supporting wall top.
Raise the actual candidate surface in a negative control to prove sensitivity.

Stairs require both exterior contact and interior clearance. Ziggurat stairs
must reach the summit with consistent risers, and their upper masonry must start
at the chamber ceiling. Extending solid ground-floor blocks into the mountain
can make a convincing outside while filling the room below. Check every emitted
tread and the landing with rays; independently isolate emitted stair geometry
and probe the occupied chamber beneath it. Shortened flights and solid-filled
chambers are distinct negative controls. Preserve the original physical toe and
forecourt when the repair should not enlarge native placement bounds.

Actual mesh and mass-log agreement matters: outdoor stair masses stand on
ground; upper masses stand on the real chamber ceiling. Columns and alcove caps
must respect that ceiling too. Fix geometry rather than relaxing overlap rules.

Fit the final longitudinal column run after sanctum and summit changes. A bay
count drawn earlier can compress real capitals into each other even when the
shaft rows fit across the hall. Use full capital diameter, preserve symmetric
pairs, and materialize the authored column records only after this fit.

The full evidence and finite coverage limits live in `docs/ROOF_AUDIT.md` and
`artifacts/p1p2_roof_regions/`. A passing named matrix does not prove arbitrary
outline joins, all castle shapes, unsupported families or tree/roof interference.
