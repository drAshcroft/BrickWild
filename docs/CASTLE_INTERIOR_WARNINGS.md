# Castle interior warning handoff

The final INT-007 sweep on 2026-09-13 passed **84 canonical CastleQA fixtures with 0 failures and 204 warnings**. Evidence: [castle_voxel_final.log](../artifacts/castle_voxel_final.log); its stderr file is empty. The same run passed 97 focused castle-walk checks, and the separately recorded connected-component helper passed 3 more. These counts describe that recorded run, not every possible seed or unsupported castle form. See [interior eligibility](CASTLE_INTERIORS.md#eligibility-and-remaining-work).

The 204 entries are warning occurrences, not 204 independent defects. Eight explicitly record a furnishing fallback in the plan. Other warnings come from general-purpose rules, secondary placement preferences, or measured unused floor. None is being suppressed or declared waived here. Classification below follows the current source and logged messages; it does not substitute for a render or a detailed placement inspection.

| Category | Count | Logged building IDs | What the warning establishes |
| --- | ---: | --- | --- |
| `seating` | 158 | `chapel` | Pew benches are not associated with, or close to, a table under the generic seating rule. Repeated across 24 chapel fixtures. |
| `nav` | 12 | `yard_stable` | The walking grid contains 0.9 or 1.1 m2 of standable floor disconnected from the entrance. |
| `focus` | 10 | `chapel` | The door-to-altar sightline intersects the `CandleStick_Stand` placement's bounding box. |
| `shelf_over` | 10 | `yard_blacksmith` (4), `yard_general_store` (6) | Shelves do not cover their host bench/counter; the current availability probe finds no usable station above it. |
| `against` | 8 | `keep` | A Cabinet placement carries the explicit `free_standing` fallback flag. |
| `shape` | 4 | `hall` | The great hall's measured floor-rectangle aspect ratio exceeds its room-kind limit. |
| `sconce_pair` | 2 | `keep` | Two lamps share an actual wall facet but are not symmetric about the checked anchors. |
| **Total** | **204** | | |

There are no `programme` or missing-bed warnings in this final log. Earlier diagnostic logs contain failures from intermediate versions; do not use them as the current result.

**Existing task ownership checked on 2026-09-13**

WaterFree searches for `seating`, `CandleStick_Stand`, `shelf_over`, `sconce_pair`, `nav pockets`, `stranded`, `pews`, `chapel`, `focus`, `symmetry`, `corridor` and `castle warnings` found no single task covering this warning inventory. Relevant overlaps must be preserved:

| Existing item | Status at audit | Relationship |
| --- | --- | --- |
| `INT-005`, `9b822ee0-3f71-40ad-b169-952dd56de7df` | executing | Already owns chapel axis/sightline work. Its notes distinguish intentional pew rows and altar seating from ordinary dining seating. Route chapel follow-up through this work instead of duplicating it. |
| `HOUSE-POLYGON-AFFINITY`, `c658d3e0-66b8-45f1-846d-b4102caf02d8` | pending | Owns remaining four-AABB-wall affinity/checker assumptions; see the [confirmed scope](CASTLE_INTERIOR_FOLLOWUPS.md#polygon-wall-indices-in-furniture-affinity-and-secondary-qa). It is not an explanation for every shop warning. |
| Alchemist shelf failure, `20ad71a4-5c54-4805-9fc2-9877aafb24f4` | pending | A different fixture: longhall/alchemist, 12 x 16 m, one storey, seed 60068, `shelf_over` failure at 0% cover and 2.43 m. Shared shelf-helper changes must preserve or resolve its independently reproduced failure; the ten castle warnings do not close it. |
| `INT-001` row placement; `INT-002` focus; `LAY-003` affinity QA | complete | Existing mechanics and coverage to preserve, not new implementation tasks. |

[castle_interior_warning_triage.json](tasks/castle_interior_warning_triage.json) records the pending P2 task `CASTLE-INTERIOR-WARNINGS`, live ID `8e41759c-ef3f-4b57-9910-3c32078f25de`. Root reviewed the overlap above before registering the remaining cross-category triage.

**Reproducing a named fixture**

Use [CastleSweep](../tests/suites/castle_sweep.gd)::`spec_at(style, tier, index)`, then `CastleBuilder.build(spec)` and `CastleQA.check(spec, mesh, builder)`. The fixture key below is `style/tier/index`; the seed is included to catch accidental changes to the sweep. The variant name printed in the log is descriptive; style, tier, index and seed are the reliable lookup fields.

| Tier/index | Width x length x height (m) | Seed |
| --- | --- | ---: |
| `castle/0` | 40 x 55 x 14 | 9249 |
| `castle/1` | 60 x 90 x 18 | 9250 |
| `castle/2` | 80 x 145 x 22 | 9251 |
| `fortress/0` | 90 x 140 x 20 | 9117 |
| `fortress/1` | 140 x 200 x 24 | 9118 |

Find the building by its stable `id` in `builder.interiors`; its `plan` is the local HousePlan. The composed report is `report.buildings[id]`. Inspect the plan's furniture, room outlines, openings and compromise records before changing a checker. For navigation, run `HouseNavCheck.check(row.plan)` and print `HouseNavCheck.ascii_map(0)` on that same checker instance. Preserve the measured prop catalogue and current walking resolution.

The full reproduction command from the project root is:

```powershell
$env:BIG_GLADE_TEST_TRACE = '1'
& 'C:\Projects\godot\Godot_v4.5.2-stable_mono_win64\Godot_v4.5.2-stable_mono_win64.exe' --headless --path . --script res://tests/run_all.gd -- cvoxelqa
```

The recorded voxel sweep took 1949.20 seconds while other suites ran concurrently. This is not an isolated performance benchmark; use the existing [performance follow-up](tasks/castle_interior_performance.json).

**Recorded furnishing compromise: `against` (8)**

Representative fixture: `edwardian/castle/0`, seed 9249, `keep`:

> against: Cabinet in room 1 (hall) stands free -- no wall in the room would take it

The same fixture reports room 3 (`lords_chamber`). Other occurrences are Edwardian castle/1 room 1; Edwardian castle/2 rooms 1 and 3; Edwardian fortress/0 room 1; Crusader castle/1 room 1; and Crusader fortress/0 room 1.

Source: [HouseFurnisher](../src/house/house_furnisher.gd)::`_place_one` first attempts wall placement, then permits a nonessential wall item to stand free and writes `free_standing = true`. [HouseFurnishCheck](../qa/house_furnish_check.gd)::`_check_against_wall` explicitly recognizes that flag. Its ordinary back-gap measurement already uses actual room walls and the prop's own depth.

This is recorded fallback behavior, not an unreported cabinet-placement failure. A follow-up should inspect which door, window, stair, required furnishing or physical wall length prevents a wall placement, then compare a feasible alternative without losing required furniture or access. Do not remove the flag or downgrade the ordinary wall-gap failure just to change the warning count. The log alone does not prove every alternative arrangement was impossible.

**Chapel rule semantics: `seating` (158)**

Representative fixture: `norman/castle/0`, seed 9249, `chapel`:

> seating: Bench in room 0 (nave) is not at any table

All 158 occurrences are Bench warnings in chapel nave room 0, across 24 distinct castle fixtures. [HouseFurnisher](../src/house/house_furnisher.gd)'s `nave` recipe intentionally places two groups of pew rows beside a central aisle. [CastleGenerator](../src/castle/castle_generator.gd)::`chapel_plan` supplies a distant altar/focus and sanctuary. These pews are not dining benches around the altar.

`HouseFurnishCheck._check_seating` nevertheless checks every `seat`/`bench`, and `_nearest_table` only associates one with a table/workbench/counter whose centre is within 1.6 m. There is no row or nave exception in that check. This confirms a mismatch between pew semantics and the general table-seat rule, but does not prove every pew's physical orientation is correct. Review row metadata, aisle clearance, altar direction and a room render together. Any future role-aware rule must retain strict checks for dining seating and prove pew alignment/access rather than silence all benches or all chapels.

**Chapel sightline investigation: `focus` (10)**

Representative fixture: `norman/castle/0`, seed 9249, `chapel`:

> focus: the table in room 0 cannot be seen from the door past the CandleStick_Stand

Other occurrences: Edwardian castle/1; Crusader castle/2; French ch?teau castle/2; Bavarian castle/0, /1 and /2; Japanese castle/1 and /2; Moorish castle/2. Each names the same candle stand, not a lost altar or a reversed stable stall.

Source: `HouseFurnishCheck._check_focus`. It traces from an eye 1.6 m above the floor, 0.5 m inside the entrance, to 90% of the focus object's height. Unmounted, unhosted furniture is tested with a full `AABB` made from its plan rectangle and catalogue height. A hit produces this warning directly; it does not depend on a recorded plan compromise.

Inspect the actual candle stand silhouette, measured bounds, placement and altar sightline. A slender or open decorative object can have a bounding box wider than its opaque silhouette; conversely it may really obscure the selected target. The current evidence is an AABB intersection, not a mesh-level visibility result. Preserve true opaque-obstruction detection when deciding whether to move the prop or refine the visibility model.

**Measured unused floor: `nav` (12)**

Representative fixtures: `norman/castle/1`, seed 9250, and `norman/fortress/1`, seed 9118, both `yard_stable`:

> nav: 1.1 m2 of floor is walkable but cut off from the rest of the house
>
> nav: 0.9 m2 of floor is walkable but cut off from the rest of the house

The same pair occurs for Edwardian, Crusader, Bavarian, Japanese and Moorish styles. French ch?teau has no occurrence in this run.

Source: [HouseNavCheck](../qa/house_nav_check.gd)::`_check_islands`, using `WalkGrid.stranded_area()`. It sums standable but unreached floor across storeys and warns above `ISLAND_MIN_AREA = 0.6` m2. Required rooms, doors, furniture-use areas, steps and plan clear zones have separate reachability checks; those all pass here.

These are real pockets in the current measured walking grid, not evidence of a failed room entrance and not a table-seating semantic warning. First inspect `ascii_map(0)` for the stable and locate the pocket relative to the measured stall/body footprint. Check whether a small placement change can recover it while preserving the entrance clearance, stall-facing requirement and all furniture-use areas. Do not hide pockets by raising the threshold or shrinking body/prop bounds. A grid pocket need not be a separate unusable room.

**Shelf preference and secondary geometry: `shelf_over` (10)**

Representative fixtures: `norman/fortress/0`, seed 9117, `yard_blacksmith`, and `norman/fortress/1`, seed 9118, `yard_general_store`:

> shelf_over: no shelf in room 0 (workshop) hangs over the bench it serves (0% cover, 2.00m away)
>
> shelf_over: no shelf in room 1 (sales_floor) hangs over the bench it serves (0% cover, 2.17m away)

Blacksmith occurrences: Norman, French ch?teau, Japanese and Moorish fortress/0. General-store occurrences: Norman, Edwardian, Crusader, Bavarian, Japanese and Moorish fortress/1.

`HouseFurnishCheck._check_shelf_over` requires at least 50% coverage. If no shelf covers a host, `_fs_could_hang_over` searches for a usable station, respecting openings, shelf width, end margins and other mounted objects. A station found but unused is a failure; no station found is a warning. This is a rule-derived space constraint, not an explicit `free_standing` or `was_dropped` record.

There is a confirmed source-level concern in these secondary helpers: `_fs_back_wall` infers four AABB walls, while `_fs_could_hang_over` subsequently indexes `HouseGeometry.room_walls`. Producer helpers `_back_wall_index`, `_window_crowding` and `_over_bonus` also retain four-wall assumptions and absolute tangent projections. This is covered by [HOUSE-POLYGON-AFFINITY](CASTLE_INTERIOR_FOLLOWUPS.md#polygon-wall-indices-in-furniture-affinity-and-secondary-qa), task `c658d3e0-66b8-45f1-846d-b4102caf02d8` in the [existing task records](tasks/castle_interior_followups.json).

That confirmed helper limitation does **not** establish that these ten shop warnings are polygon errors. Inspect each actual room outline, host wall, window and mounted-object intervals before attributing its warning. For the blacksmith, preserve the workbench's passing daylight requirement when considering a shelf elsewhere. Fix producer/checker geometry together where a mismatch is demonstrated; retain the failure for a shelf that ignores an available valid station.

**Long hall proportions: `shape` (4)**

All occurrences are `hall`, room 0 (`great_hall`):

| Fixture | Seed | Logged message |
| --- | ---: | --- |
| `edwardian/castle/2` | 9251 | `shape: room 0 (great_hall) is 6.3 x 44.3m -- that is a corridor, not a room` |
| `edwardian/fortress/0` | 9117 | `shape: room 0 (great_hall) is 3.5 x 28.2m -- that is a corridor, not a room` |
| `french_chateau/castle/1` | 9250 | `shape: room 0 (great_hall) is 4.8 x 29.9m -- that is a corridor, not a room` |
| `french_chateau/fortress/1` | 9118 | `shape: room 0 (great_hall) is 10.0 x 60.3m -- that is a corridor, not a room` |

Source: [HousePlanCheck](../qa/house_plan_check.gd)::`_check_shapes`, with `HouseGeometry.room_aspect` and `aspect_max`. This warns on the floor rectangle's long/short ratio; the separate minimum-room-size check passes. It is a plan-proportion concern, not evidence of a roof hole or blocked route. Review `CastleGenerator.hall_plan` and the host range geometry before choosing a wider hall, subdivided programme or another architectural treatment. Preserve the actual courtyard and emitted shell/roof correspondence.

**Sconce symmetry preference: `sconce_pair` (2)**

Fixtures: `edwardian/castle/0` seed 9249 and `edwardian/castle/1` seed 9250, `keep`:

> sconce_pair: the two lamps in room 3 (lords_chamber) are lopsided on wall 10

`HouseFurnishCheck._check_sconce_pair` already identifies actual polygon facets and measures lamp stations along the facet tangent. These messages take the same-wall-but-not-mirrored warning branch. They are not proof that the plan recorded a compromise, and they do not prove a symmetric pair could not fit: the same-wall condition is sufficient to warn.

Inspect lamp centres, room/door/fireplace anchors, openings and actual available wall intervals if improving symmetry. The facet-identification and paired-placement bugs were fixed in INT-007; the [existing polygon follow-up](CASTLE_INTERIOR_FOLLOWUPS.md#polygon-wall-indices-in-furniture-affinity-and-secondary-qa) explicitly excludes that completed work. Preserve the oblique, adjacent-facet, invalid-pair and beyond-facet controls in [polygon_sconce_suite.gd](../tests/suites/polygon_sconce_suite.gd).

Any follow-up should record the exact fixture, room, measured reason, and before/after result. A warning may motivate a placement improvement, a more suitable architectural programme, or a stronger role-specific check; its presence alone does not decide which change is correct. Keep independent physical and navigation failures intact.

## Castle normals warnings from the final required sweep

The separately completed `cnormals` run passed **84 checks, 0 failures and 169 warnings**, with native exit code 0 and empty stderr. Evidence: [int007_cnormals_split.log](../artifacts/int007_cnormals_split.log), [exit record](../artifacts/int007_cnormals_split.exit.txt). It took 915.74 seconds while CastleSuite also ran; this is not an isolated benchmark. The original combined process finished its complete CastleSuite report before being stopped at the next-suite boundary; [split evidence](../artifacts/int007_split_summary.json) records that separately passing 344-check suite.

These 169 warnings are a separate inventory from the 204 CastleQA placement/navigation warnings above. Do not add the two counts and call the result a count of independent defects. This section classifies the current rule branches; it does not establish whether every mass-box warning corresponds to opaque emitted geometry.

| Rule branch | Warning occurrences | What was measured |
| --- | ---: | --- |
| Hall outside probe | 75 | Another shrunken mass AABB contains the outward probe but not the inward probe. |
| Keep outside probe | 60 | The same mass-box condition at a keep opening. |
| Tower outside probe | 6 | The same condition at tower openings. |
| Roof degenerate triangles | 28 | Each affected fixture has two surface-2 triangles below the cross-product magnitude threshold: **56 triangles total**. |
| **Total** | **169** | **54 distinct canonical fixtures** have at least one warning. |

**Outside probe branch: 141 occurrences**

[NormalsSuite.check_openings](../tests/suites/normals_suite.gd:129) considers logged parts whose `kind` is `window`, have a usable horizontal facing vector, and lie within `NEAR = 0.5` m of a structural mass. It normalizes the horizontal facing `f` and probes `pos - f * 0.35` and `pos + f * 0.35`. `_in_solid` tests each mass's AABB shrunk by `SKIN = 0.06` m.

For the outward probe, a mass containing both probe points is ignored so the opening's own box is not mistaken for an exterior blocker. The warning branch is specifically `behind && ahead`: material is behind the opening, but another mass box contains only the outward point. This branch still counts as correctly facing. `ahead && !behind` and neither-point-supported are failures; neither occurred in this run.

This is a mass-envelope test, **not a ray test against actual triangles**. Hollow shells, curved/tapered walls and overlapping bounding boxes can satisfy it without placing opaque material in front of the opening. A warning can also expose a real neighboring wing, curtain, tower or roof obstruction. Do not claim either explanation from the warning alone.

Representative starting fixtures are `norman/manor/0` seed 9074 (two hall warnings), `norman/castle/0` seed 9249 (one keep warning), and `edwardian/fortress/0` seed 9117 (four tower and two keep warnings). The full log gives the world-space opening centre for every occurrence. Before editing, identify the matching `builder.part_log` record by `tag`, `pos` and `facing`; preserve its `planned_opening` metadata when present. Print the names and AABBs of masses containing the two probe points, then inspect intersecting emitted triangles and an exterior render. The correction belongs in opening placement/emission if a real obstacle exists; a probe refinement needs an independent geometry oracle and negative controls for a real opaque blocker.

**Degenerate-triangle branch: 28 occurrences / 56 triangles**

[NormalsSuite.check_mesh](../tests/suites/normals_suite.gd:49) walks the actual surface arrays and index order. It treats a triangle as degenerate when `(c - a).cross(b - a).length() < 1e-6`. That quantity is twice the triangle area. Degenerate triangles are excluded from the winding-ratio calculation and reported separately; finite/unit normals and winding agreement of the remaining triangles still have their own failure branches.

All 28 warnings name surface 2, which [CastleBuilder](../src/castle/castle_builder.gd:16) defines as roof. Every one reports exactly two triangles. This proves tiny/zero-area emitted roof triangles, but does not by itself prove an exposed roof hole, reversed winding or a coincident seam. Start with `norman/castle/0`, seed 9249; dump the two offending triangle indices and all vertices from surface 2, respecting `Mesh.ARRAY_INDEX` when present. Trace those vertices through `CastleBuilder._join_roofs`, its roof emitters and `MeshKit.slab_poly` before deciding which producer to change. Those are investigation entry points, not a confirmed offending emitter.

**Exact reproduction**

The key in the table below is accepted directly by `CastleSweep.spec_at(style, tier, index)`; its authoritative dimensions and seed mapping are in [CastleSweep.SIZES](../tests/suites/castle_sweep.gd:14). In addition to the castle/fortress rows listed earlier, the warning inventory includes `house/2` = 12 x 24 x 6.5 m, seed 9331; `manor/0` = 14 x 24 x 8 m, seed 9074; `manor/1` = 26 x 40 x 10 m, seed 9075; `manor/2` = 32 x 60 x 12 m, seed 9076; and `fortress/2` = 200 x 300 x 28 m, seed 9119.

A single-fixture diagnostic should use the same two functions as the required suite:

```gdscript
extends SceneTree

func _init() -> void:
    var spec := CastleSweep.spec_at(&"norman", &"castle", 0)
    var builder := CastleBuilder.new()
    var mesh := builder.build(spec)
    var result := SuiteResult.new("normals fixture")
    var where := "style=norman tier=castle seed=9249"
    NormalsSuite.check_mesh(result, mesh, where)
    NormalsSuite.check_openings(result, builder, where)
    for warning in result.warnings:
        print("WARN ", warning)
    for failure in result.failures:
        print("FAIL ", failure)
    print(result.summary())
    quit(0 if result.ok() else 1)
```

Save it as `artifacts/repro_castle_normals.gd` and run the executable from AGENTS.md with `--headless --path . --script res://artifacts/repro_castle_normals.gd`. Change both the fixture and descriptive `where` together when investigating another table row. This snippet is an investigation recipe, not a newly executed suite.

Full required reproduction:

```powershell
$env:BIG_GLADE_TEST_TRACE = '1'
& 'C:\Projects\godot\Godot_v4.5.2-stable_mono_win64\Godot_v4.5.2-stable_mono_win64.exe' --headless --path . --script res://tests/run_all.gd -- cnormals
```

| Fixture | Seed | Hall probes | Keep probes | Tower probes | Degenerate warnings / triangles |
| --- | ---: | ---: | ---: | ---: | ---: |
| `norman/manor/0` | 9074 | 2 | 0 | 0 | 0 / 0 |
| `norman/manor/1` | 9075 | 2 | 0 | 0 | 0 / 0 |
| `norman/manor/2` | 9076 | 4 | 0 | 0 | 0 / 0 |
| `norman/castle/0` | 9249 | 0 | 1 | 0 | 1 / 2 |
| `norman/castle/1` | 9250 | 0 | 0 | 0 | 1 / 2 |
| `norman/fortress/1` | 9118 | 0 | 8 | 0 | 0 / 0 |
| `edwardian/house/2` | 9331 | 2 | 0 | 0 | 0 / 0 |
| `edwardian/manor/0` | 9074 | 2 | 0 | 0 | 0 / 0 |
| `edwardian/manor/1` | 9075 | 4 | 0 | 0 | 0 / 0 |
| `edwardian/manor/2` | 9076 | 6 | 0 | 0 | 0 / 0 |
| `edwardian/castle/0` | 9249 | 0 | 1 | 0 | 1 / 2 |
| `edwardian/castle/1` | 9250 | 0 | 1 | 0 | 1 / 2 |
| `edwardian/castle/2` | 9251 | 0 | 1 | 0 | 1 / 2 |
| `edwardian/fortress/0` | 9117 | 0 | 2 | 4 | 0 / 0 |
| `edwardian/fortress/1` | 9118 | 0 | 2 | 0 | 0 / 0 |
| `edwardian/fortress/2` | 9119 | 0 | 0 | 0 | 1 / 2 |
| `crusader/manor/1` | 9075 | 3 | 0 | 0 | 0 / 0 |
| `crusader/manor/2` | 9076 | 4 | 0 | 0 | 0 / 0 |
| `crusader/castle/0` | 9249 | 0 | 1 | 0 | 1 / 2 |
| `crusader/castle/1` | 9250 | 0 | 1 | 0 | 1 / 2 |
| `crusader/castle/2` | 9251 | 0 | 0 | 0 | 1 / 2 |
| `crusader/fortress/0` | 9117 | 0 | 4 | 0 | 1 / 2 |
| `crusader/fortress/1` | 9118 | 0 | 1 | 2 | 0 / 0 |
| `french_chateau/house/2` | 9331 | 2 | 0 | 0 | 0 / 0 |
| `french_chateau/manor/0` | 9074 | 2 | 0 | 0 | 0 / 0 |
| `french_chateau/manor/1` | 9075 | 4 | 0 | 0 | 0 / 0 |
| `french_chateau/manor/2` | 9076 | 6 | 0 | 0 | 0 / 0 |
| `french_chateau/castle/0` | 9249 | 0 | 1 | 0 | 1 / 2 |
| `french_chateau/castle/1` | 9250 | 0 | 1 | 0 | 1 / 2 |
| `french_chateau/castle/2` | 9251 | 0 | 2 | 0 | 1 / 2 |
| `french_chateau/fortress/0` | 9117 | 0 | 4 | 0 | 1 / 2 |
| `french_chateau/fortress/1` | 9118 | 0 | 2 | 0 | 1 / 2 |
| `bavarian/house/2` | 9331 | 2 | 0 | 0 | 0 / 0 |
| `bavarian/manor/1` | 9075 | 4 | 0 | 0 | 0 / 0 |
| `bavarian/manor/2` | 9076 | 8 | 0 | 0 | 0 / 0 |
| `bavarian/castle/0` | 9249 | 0 | 1 | 0 | 1 / 2 |
| `bavarian/castle/1` | 9250 | 0 | 2 | 0 | 1 / 2 |
| `bavarian/castle/2` | 9251 | 0 | 4 | 0 | 1 / 2 |
| `bavarian/fortress/1` | 9118 | 0 | 5 | 0 | 1 / 2 |
| `japanese/house/2` | 9331 | 2 | 0 | 0 | 0 / 0 |
| `japanese/manor/1` | 9075 | 3 | 0 | 0 | 0 / 0 |
| `japanese/manor/2` | 9076 | 4 | 0 | 0 | 0 / 0 |
| `japanese/castle/0` | 9249 | 0 | 0 | 0 | 1 / 2 |
| `japanese/castle/1` | 9250 | 0 | 0 | 0 | 1 / 2 |
| `japanese/castle/2` | 9251 | 0 | 0 | 0 | 1 / 2 |
| `japanese/fortress/2` | 9119 | 0 | 0 | 0 | 1 / 2 |
| `moorish/house/2` | 9331 | 2 | 0 | 0 | 0 / 0 |
| `moorish/manor/1` | 9075 | 3 | 0 | 0 | 0 / 0 |
| `moorish/manor/2` | 9076 | 4 | 0 | 0 | 0 / 0 |
| `moorish/castle/0` | 9249 | 0 | 1 | 0 | 1 / 2 |
| `moorish/castle/1` | 9250 | 0 | 3 | 0 | 1 / 2 |
| `moorish/castle/2` | 9251 | 0 | 4 | 0 | 1 / 2 |
| `moorish/fortress/0` | 9117 | 0 | 2 | 0 | 1 / 2 |
| `moorish/fortress/1` | 9118 | 0 | 5 | 0 | 1 / 2 |

**Follow-up ownership**

`CASTLE-INTERIOR-WARNINGS` owns the seven placement/navigation categories in the first section; roof triangle emission and structural opening probes are materially different. Root registered the separate pending `CASTLE-NORMALS-WARNINGS` task, ID `f3e66523-0e0a-4655-89f4-3898f13a01fa`, from [castle_normals_warning_triage.json](tasks/castle_normals_warning_triage.json). WaterFree searches for `walled in` and `blocked opening` returned no existing task on 2026-09-13.

The existing pending `ROOF-AUDIT-002`, ID `3ef49d68-b9f9-4836-b0cb-c299cc4046ef`, already owns church/temple duplicate-seam and degenerate-triangle classification. Coordinate shared `MeshKit` or roof-probe changes with that task; these new castle fixtures do not close it. Preserve strict opening direction, physical hole, roof coverage, winding and navigation failures. Do not lower thresholds, skip planned openings, or convert an actual failure into a warning to clear this inventory.
