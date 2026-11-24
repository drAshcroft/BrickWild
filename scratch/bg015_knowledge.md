BG-015-STREET-PLINTH (BrickWild dev, 2026-11-23): the village's 3D street mesh (VillageWalk3D, `walk.navmesh_3d`) ran into buildings' plinths, foundations and walls; VoxelGames cast its walkers' steps against the shells and 10 of 87 street paths hit a building.

Root cause:
- VillageWalk3D cut each building out of the Recast bake by `VillageMeasure.footprint_poly(b)` = `placement.footprint`. For the plan families (house, shop, hotel) `PlanFamily.footprint` is `HouseGeometry.storey_rect(top).grow(-wall_thickness)`: the CLEAR FLOOR inside the walls (its base doc says "the walls' own outline"). A timber wall is 0.35 m and the plinth stands PLINTH_EXTRA 0.04 proud (its water-table moulding 0.06), so the footprint was 0.39-0.41 m short of the built face all round. The consumer read 0.39 as `look.plinth` [0.39, 0.62] -- that is the plinth's HEIGHT range, a coincidence.
- Recast eroded 0.25 m from that, so the mesh edge stood ~0.1 m INSIDE every house's wall face (old Wuunafu export: 1298 boundary edges of 24 houses/shops inside walls+plinth). `stitch_links._walled` tested gap links against the same clear floor. `buildings[].poly_m` is the same number (left alone; owner todo BG-015-POLY-M).

What worked:
- `BuildingFamilyAdapter.ground_outline(building)` (local XZ polygons; default footprint): for PlanFamily the ground storey's site rect + PLINTH_EXTRA + 0.02, quoin squares (0.56 boxes centred on the corners, so really 0.28 proud), chimney_rect, porch_rect, veranda_rect, engawa/steps, piles deck. NOT put into `placement`: BuildingDocument encodes the whole placement dict into its `state`, so a key there changes documents.
- The lot planner's commit (terrain branch only) stores it in the plan frame as `lots[i].ground_fit.built_outline` (VillageLotGround.built_outline, from the job's measured building, which a house/shop on ground always keeps). Flat plans never reach that branch: byte-identical by construction (and diffed).
- VillageWalk3D: building = built outline grown by HALF a cell (BUILT_GROW) before the baker's radius, plus a CARVED (carve=true, after erosion) square the radius each way at every convex corner (corner_pads), not grown near its entry-flight landings (there the true outline less the landing, no pads). Gap links also refused within gap_clear() = radius - half a cell's diagonal (0.073) of a built outline (exact segment-polygon distance).

What didn't work (three tries):
- Half a cell, no pads: the floor came 0.064 m from a chimney's corner (Manarola).
- A whole cell, no pads: 0.19 m everywhere, but it shut a 1.25 m strip in front of a shop (vstepswalk Manarola) -- too much street lost.
- Growing a porch that IS an entry landing with the rest walled the deck in (door island). Fixed by not growing near landings.

Recast facts (scratch/bg015_recast_probe.gd, Godot 4.5.2): `add_projected_obstruction(carve=false)` IS grown by the agent radius (floor 0-0.37 m off a square; carve=true 0-0.12). Erosion crosses only cell EDGES (radius 1 cell -> thr 2: a cell touching a stopped one at a corner stays), so at a convex corner turned off the grid the floor comes to 0.00-0.08 m of the obstruction. Carved corner pads fix the diagonal without narrowing straight passages.

The check (qa/village_walk_clearance.gd, in lane:village-terrain's Manarola walk): build each house/shop AS PLACED (the measured job's building with the request's fall set, yard pieces held aside like placement), take every shell triangle under 1.8 m over the floor clipped there, measure exact plan distance from mesh edges (0.5 m pieces) and gap links; skip triangles inside the walls' inner face and count walk polygons inside the walls instead; exclude the building's own entry-flight prisms and points within radius + a cell of them. Control: VillageWalk3D.bake(plan, {"footprints": true}). Six lane fixtures: nearest 0.117-0.168 m vs 0.000 (970-1353 pieces too near) before.

Doors: an honest walk loses doors the old one reached only through a wall's foot (plane_30 b-002, Masouleh b-004, vstepswalk Manarola green b-001): planning faults (access flight crowding a porch; a house 0.63 m behind its lot's retaining wall) -> BG-015-ACCESS-CLEAR.

Note for next time: in BrickWild a plan family's "footprint" is the clear floor, not the walls. Measure a walk against the emitted shell; give Recast extra at convex corners (carved pads) rather than trusting agent_radius; and A/B every door's reachability, built vs old outline, in one process (scratch/bg015_doors_ab.gd) -- a walk that reached doors through walls loses some when fixed.
