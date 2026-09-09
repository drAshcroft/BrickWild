# Church roof joints

The church now builds nave, transept, narthex and aisle roofs as a joined set of polygon slabs in `src/church/church_roofs.gd`. The shared house/castle emitters are unchanged.

- The transept ridge runs across the nave. Intersecting slopes stop at their equal-height valley, with constant vertical slab depth preserving both upper and lower seams.
- Wall heads meet the roof underside, including the nave gables, transverse gables and aisle end wedges.
- Aisle roofs use each ring's actual position and meet the supporting wall below its eave.
- Tower cuts use wall footprints, so a cap overhang cannot leave a gap beside the tower.
- Dome cuts use sections through the shell's tetrahedral volume and its polygonal drum. This handles hemisphere, octagonal and onion profiles without the previous square opening.
- The octagonal dome shell starts at the same radius as its drum, closing the previously open rim.
- The apse roof follows the same ten-segment semicircle as the drum and covers its shoulders.

## Verification

`godot --headless --path . --script res://tests/run_all.gd -- churchroof`

The focused suite checks actual triangles using independent gable equations and ray intersections. It covers nine size/pitch combinations, both aisle rings, gable closure, apse shoulder coverage, tower clearance and three dome profiles at two pitches (5,305 checks).

Existing coverage: `church normals massing blueprint landmark voxelqa`.

`godot --path . --script res://tools/render_church_roofs.gd`

Reference images go to `artifacts/church_roofs/`, with backface culling enabled. The script captures the crossing, double aisles, tower and three dome profiles from both ends and at the joint.

The add-on manifest includes the new helper; its preload is relative so exported church builders can find it.

## Validation results

- Focused roof checks: 5,305 passed, no warnings.
- Church, normals, massing, blueprint and landmark suites: passed. Normals reported 42 warnings about blocked openings and degenerate triangles.
- Voxel QA: 90 variants passed, no warnings.
- Eighteen reference renders generated across six fixtures; joint and exterior views inspected with backface culling.
- Add-on smoke: blocked by an existing packaging omission, `ChurchFurnisher`. The installer test also has an outdated fixed script-count assertion. The new roof helper is included in the manifest and uses a relative preload; unrelated add-on dependencies were not changed.
