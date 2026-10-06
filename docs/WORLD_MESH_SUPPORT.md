# World mesh support: stepwell, temple mountain, Dravida

Sits beside `HAMMAM_MESH_SUPPORT.md` and `NAGARA_MESH_SUPPORT.md`. Those two
proved the pattern; this one finishes the family set (WORLD-MESH-VERIFY).

A mass log says what a builder meant to emit. These checks ask the finished
triangles. Each takes an optional `emitted_mesh`; without one it reads the
builder's own SurfaceTools. Every suite also deletes (or, for an aperture,
inserts) real triangles while the logs stay, and the production check must fail.

## One shared helper

`qa/mesh_probe.gd` (`MeshProbe`) is the single copy of the triangle utilities:
`surface_triangles`, `has_upward_support`, `ray_blocked` (any face, any
orientation, with a box reject), `rect_samples`, and the mutation helpers
`remove_triangles`, `top_face_in`, `any_face_in`, `add_box`. `ShikharaCheck` and
the Nagara suite now delegate to it instead of carrying their own. `HammamCheck`
still has its own roof-only reader; fold it in next time that file is open.

## What each family checks

| Family | Check | Suite | Support | Apertures | Volume |
|---|---|---|---|---|---|
| Stepwell | `VavCheck.check(plan, builder, mesh)` | `stepwellmesh` | every landing, grade apron, tank edge, every tread top, tank water | draw shaft core open from sky to bottom; every flight open to the sky | each pavilion roof and its four columns; three tank walls stop a walk |
| Mountain | `MountainCheck.check_mountain(plan, builder, mesh)` | `mountainmesh` | causeway, every gallery side of three rings, every stair step, summit, moat water | each axial gopura open at body height | five wall sides per ring stop a walk; wall tops; five tower roofs and bodies |
| Dravida | `PrakaraCheck.check(plan, builder, mesh)` | `dravidamesh` | colonnade strips, mandapa floor | both gopuram passages, sanctum door | mandapa/sanctum roofs, gopuram roofs, vimana crown; prakara, sanctum and mandapa walls |

There is no plan-only mode for these three: their existing checks already
required a builder. The probes run for every caller.

Mutations in each suite: landing/gallery/tread/step floor top removed, roof top
removed, pavilion column removed, wall removed, water removed (support or
enclosure rule fires); a box inserted into the shaft, a flight, a gate or the
sanctum door (aperture rule fires). Logs are compared before and after.

## Defect found

The aperture rays found a real geometry bug. `DravidaBuilder._emit_colonnade`
placed inner-gallery columns at `i/4` for `i` in 1..3, so `i == 2` landed on
x = 0: a 0.52 m column stood in the middle of the processional axis, one at the
front and one at the rear, just behind each gopuram passage. The mass log
listed them as ordinary columns and no rule looked at the axis. The middle bay
is now left open (`dravida_builder.gd`, the `if i == 2: continue` in the
north/south column loop).

## Not covered

The stepwell is mostly below grade and the Dravida sanctum has no emitted floor
(it relies on the assembler's ground), so neither is probed for a floor under
those interiors. The moat water is probed by its logged rectangles.

## Run

```powershell
godot --headless --path . --script res://tests/run_all.gd -- stepwellmesh mountainmesh dravidamesh
godot --headless --path . --script res://tests/run_all.gd -- wld011 wld014 wld016
godot --path . --script res://tools/render_world_mesh.gd   # -> artifacts/world_todo/
```
