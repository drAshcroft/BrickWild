# Agent notes

## Godot executable

Not on PATH. Use:

```
C:\Projects\godot\Godot_v4.5.2-stable_mono_win64\Godot_v4.5.2-stable_mono_win64.exe
```

## Running things

```
# full test suite (headless; the voxel sweeps make it a couple of minutes)
godot --headless --path . --script res://tests/run_all.gd
# one or more suites, in this order:
#   churches: church | normals | massing | blueprint | landmark | voxelqa
#   castles:  castle | cnormals | cmassing | clandmark | cvoxelqa
#   houses:   house | assets | houseqa | harchetype
#   temples:  temple | rite | tarchetype
godot --headless --path . --script res://tests/run_all.gd -- normals
godot --headless --path . --script res://tests/run_all.gd -- castle cmassing
# fast roof regression for ordinary roof/emitter changes (target: <30 seconds)
godot --headless --path . --script res://tests/run_all.gd -- roofquick
# bounded house QA lane for ordinary task completion (target: <5 minutes)
godot --headless --path . --script res://tests/run_all.gd -- houseqa
# narrower house QA lanes: shell/core, planning/circulation, furnishing/rules
godot --headless --path . --script res://tests/run_all.gd -- houseqacore
godot --headless --path . --script res://tests/run_all.gd -- houseqaplan
godot --headless --path . --script res://tests/run_all.gd -- houseqafurnish
# broader bounded house-family regression
godot --headless --path . --script res://tests/house_test.gd
# exhaustive statistical house QA is for nightly/pre-merge use
godot --headless --path . --script res://tests/run_all.gd -- houseqafull
# the temple suites alone
godot --headless --path . --script res://tests/temple_test.gd

# after changing anything in assets/props/, re-measure the catalogue
godot --headless --path . --script res://tools/build_prop_catalog.gd

# reference renders -- must NOT be headless, the dummy renderer makes no image
godot --path . --script res://tools/render_shots.gd     # -> artifacts/renders/
godot --path . --script res://tools/shoot_studio.gd     # screenshot of the Studio UI
```

After adding a script with a NEW `class_name`, run the editor once so the
class is registered, or every suite fails with "Identifier not declared":

```
godot --headless --path . --editor --quit
```

## Gotchas

* A GDScript **parse error makes the headless runner hang** rather than exit.
  If a run stops producing output, read the top of the log for "Parse Error"
  instead of waiting on it.
* Godot's front faces are **clockwise**, so a triangle wound (a, b, c) has
  outward normal `(c - a).cross(b - a)` -- the opposite hand from the usual
  formula. `MeshKit._face_normal` is the single place this is decided.
* `MeshKit.commit()` deliberately does **not** call `generate_normals()`. Every
  emitter sets its own per-face normal, and generate_normals() smooths across a
  whole surface -- one smooth group spans the entire building.
* Both generators share `core/mass_builder.gd`: the mesh kit plus `part_log`
  and `mass_log`, which every QA check measures. A builder that logs a mass it
  never emitted is caught by the voxel suites, not the massing ones.
* **An opening must be placed on the surface, not on the bounding box.** A
  battered wall, a drum tower and a tiered keep are all narrower than the AABB
  their mass is logged as, so a window placed on the box hangs in the air
  beside the building. `_wall_slits` and `_shell_openings` exist for this.
* Castle geometry lives in `src/castle/castle_geometry.gd` and, like
  `ChurchGeometry`, is the single source of truth. `CastleGenerator` clamps
  every size against it so `CastleBuilder.build()` stays a pure function of
  its spec.
* **A house is a plan, not a mesh.** `HousePlan` holds the rooms, doors,
  windows and furniture; the builder makes a shell from it and
  `HouseAssembler` is the ONLY place that loads a model. Keep it that way:
  it is why the whole house harness runs headless in milliseconds per house.
* Furniture sizes are measured, never authored. `tools/build_prop_catalog.gd`
  writes `assets/props/catalog.json`; the house assets suite re-measures the
  models and fails if they have drifted.
* Walking a building is `qa/walk_grid.gd`: rectangles of floor, rectangles of
  obstruction, a start point. Both the house nav check and the temple rite
  check use it -- do not grow a second copy of the distance transform.
* A temple is judged by its AXIS. `qa/temple_rite_check.gd` is ten rules about
  the line from the gate to the god, and every one of them has caught a real
  defect. If a change makes one of them noisy, the change is probably wrong.
* `TempleRiteCheck.ascii_map()` marks the Gate, Altar and Idol.
* `HouseNavCheck.ascii_map()` prints the walkability grid. Reach for it before
  theorising about a reachability failure -- it shows the blockage in a second.
* The furnisher calls the nav check on itself, per room and again at the end,
  and removes furniture until the house is walkable. If it has to remove
  something a room needs, it records that on the plan and the furnishing check
  downgrades that one complaint to a warning. Do not "fix" a warning of that
  shape by making the check quieter.
