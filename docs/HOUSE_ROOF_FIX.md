House roof and exterior repair - 9 September 2026
================================================

The farmhouse's crossed hip slabs have been replaced by joined polygon faces. Main roofs, wall-head closures, half-hip cuts, bargeboards and dormer intersections now use the same local roof geometry. Dormers cut through both sides of the host slab and their cheeks and rooflets meet its slope. The roof follows the longer footprint dimension; rotating a footprint preserves dormer capacity.

`core/roof_shape.gd` defines convex faces at the slab mid-plane. `RoofShape.DEPTH` is a vertical thickness: this makes the upper and lower edges of adjacent hip faces meet. `HouseGeometry.roof_layout(plan)` returns the transform, faces and accepted dormer records without modifying the plan. It deliberately recomputes from the current spec; callers that edit a spec after generation cannot leave a stale cached roof. `HouseBuilder.roof_components` records emitted roof/closure/dormer polygons. Broader facade-component logging and a serialized plan-level roof-opening contract remain in HOUSE-EXT-005/007; extend this geometry rather than introducing another dormer cutter.

Door clearance also required three fixes. Timber sills now use the existing opening interval clipper. Plinth openings no longer generate a second short door frame, whose lintel crossed the real doorway. The plinth's water-table moulding is split at doors too. The regression measures both trim and masonry triangles at the original cottage 4412 obstruction heights.

Exterior props now work through `HouseExterior.dress(plan)`, `plan.exterior` and `HouseAssembler.dress_exterior`. Recipes place an entrance lantern, seating and small storage groups, with produce for farms, an anvil and crate for smiths, and cauldron/pots for alchemists and witch huts. All models are the existing measured Quaternius Fantasy Props MegaKit assets under the Standard licence recorded in `assets/props/fantasy/README.md` and `License_Standard.txt`. No asset files were changed or imported.

Each record includes a stable ID, role, facade host, storey, origin, yaw, scale, measured AABB and footprint. Placement reserves doors/porches, glazing, shutter/hood space, the chimney and other props. `WalkGrid` verifies the exterior approach, including chimney and porch-post obstacles. Items that cannot fit are omitted with a reason in `plan.exterior_omissions`. Rectangular houses are supported; shaped/courtyard houses currently report an explicit omission. Set `spec.exterior_props = false` before generation to disable dressing. Interior furniture remains a separate list.

The public placement bounds and the house camera distance include enabled exterior props. `BuildingDocument` exports the new records as JSON-compatible numeric data. The older spec-only `HouseGeometry.total_height/plan_extent` estimates still need the comprehensive correction described in HOUSE-EXT-009; do not use them as exact final mesh bounds.

Reproduction and validation
---------------------------

```powershell
$godotExe = 'C:/Projects/godot/Godot_v4.5.2-stable_mono_win64/Godot_v4.5.2-stable_mono_win64.exe'
& $godotExe --headless --path C:/Projects/BigGlade --editor --quit
& $godotExe --headless --path C:/Projects/BigGlade --script res://tests/run_all.gd -- hroof hexterior
# Include the real interior furnishing decisions in the four roof fixtures:
& $godotExe --headless --path C:/Projects/BigGlade --script res://tests/house_roof_test.gd -- --full
# Rendering must not be headless:
& $godotExe --path C:/Projects/BigGlade --script res://tools/render_house_roofs.gd -- --full
```

The focused runner exits nonzero on a failure. It covers gable/hip/half-hip roofs, both orientations, square/near-square hips, low/high pitches, deterministic rebuilding and cutaways. Negative fixtures recreate the old crossed slabs, lower a gable, block a door/window, overlap props, corrupt bounds and specify an invalid facade host. Prop tests load the real models through the assembler and compare their transformed bounds and lamp positions with the plan. Public placement and JSON serialization are also checked.

Rendered evidence is in `artifacts/roof_fix/`: five angles each for town 4411, cottage 4412, farm 4413, hall 4414 and smith 4415. The four original fixtures retain the dimensions in the evaluation. Smith is cottage/smith, 9 x 11 m, height 2.7 m, one storey. These images were regenerated using full furnished plans. Original evidence, when present, is retained in `artifacts/house_rules_eval/`.

Completed validation results follow. Stopped sweeps are not passes.

- `hroof hexterior`: **1,303 checks, zero failures or warnings** (344 roof and 959 exterior checks, `artifacts/roof_exterior_final_test.log`). After adding the invalid-host guard, the six mutation diagnostics also passed (`artifacts/roof_final_mutations.log`). Final editor import had no parse errors.
- `hmultistory`: **210 checks, zero failures**, two existing furnishing-compromise warnings. `harchetype`: 34 checks, one failure and 32 warnings (`artifacts/roof_multistory_archetype.log`). The failure is the already tracked missing bed in `one_room_cottage`, scale 1.00, seed **21637**, cottage/none, **5.5 x 7 m**, height **2.4 m**. Re-running the generator from pre-roof commit `1e0f302` reproduced the missing bed and **identical interior furniture** (`artifacts/cottage_baseline.log`); planner/furnisher/catalogue source is unchanged from that commit. Existing task `e7607125-c9dd-4791-a060-38e515e98942` owns this furnishing defect.
- Shared `church normals massing castle cnormals cmassing temple`: **862 checks, zero failures**, 260 warnings from the existing broader rules (`artifacts/roof_shared_tests.log`).
- `assets`: **488 checks, zero failures**, 31 catalogue floor-offset warnings (`artifacts/roof_asset_regression.log`).
- Full furnished roof fixtures: **343 checks, zero failures** before adding the lowered-gable negative fixture (`artifacts/roof_full_fixture.log`).
- The basic `house` suite completed without failures in the broader run. The subsequent full `houseqa` sweep was stopped; `hmultistory` and `harchetype` were then run separately. The cross-family `placement` sweep was also stopped after the focused roof/exterior suites passed; dedicated exterior placement assertions cover the changed API behavior.
- Addon installer validation fails at its pre-existing hardcoded script count (expects 40; manifest now contains 46, including the two new roof/exterior classes). A dependency audit also found 21 existing omitted runtime scripts, including `BuildingFamilyAdapter`, `BuildingLibrary`, `BuildingDocument`, assemblers and village dependencies. HOUSE-EXT-016 retains this packaging work. The addon smoke test did not run; addon compatibility is not claimed.

Remaining work
--------------

HOUSE-EXT-003/004 have their geometry repairs and focused tests, but retain the incomplete broad validation requirements. HOUSE-EXT-005/007 retain complete facade logging and a durable serialized roof-opening interface. HOUSE-EXT-010/011 have working measured placement and recipes; their remaining handoff checks are called out in task notes. Exact spec-only bounds, actual projecting jetties, separate glazing/roof materials, roof courses and style proportion tuning remain explicit follow-ups in HOUSE-EXT-009/012-016. Those visual improvements should build on the repaired roof geometry.
