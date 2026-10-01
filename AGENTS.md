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
# named lanes -- see the testing protocol below; prefer these to hand-picking
godot --headless --path . --script res://tests/run_all.gd -- lane:geom
# bounded castle change gate: apertures, nested-ring stair clearance,
# fixed structural cases and selected real voxel QA
godot --headless --path . --script res://tests/run_all.gd -- lane:castle-change
godot --headless --path . --script res://tests/run_all.gd -- lane:plan
godot --headless --path . --script res://tests/run_all.gd -- lane:church-change
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
# repeat exactly from the source-fingerprinted pack cache after the first full pass
godot --headless --path . --script res://tools/build_prop_catalog.gd -- --incremental
# expensive oracle check: full measurement, then cache-backed byte-for-byte parity
godot --headless --path . --script res://tools/build_prop_catalog.gd -- --verify-parity

# reference renders -- must NOT be headless, the dummy renderer makes no image
godot --path . --script res://tools/render_shots.gd     # -> artifacts/renders/
godot --path . --script res://tools/shoot_studio.gd     # screenshot of the Studio UI
```

After adding a script with a NEW `class_name`, run the editor once so the
class is registered, or every suite fails with "Identifier not declared":

```
godot --headless --path . --editor --quit
```

## Testing protocol

**Pick the lane that matches the edit. Do not run the full sweep per task.**
Use the measured routine gate in `docs/QA_FAST_PROTOCOL.md`: the selector and
its focused fixture must finish in under five minutes of host wall time.
`tools/run_qa_lane.ps1` records stdout, stderr, native exit, and wall time.

```
godot --headless --path . --script res://tests/run_all.gd -- lane:geom
```

| You touched | Lane | Time |
|---|---|---|
| `core/mesh_kit.gd`, `core/mass_builder.gd`, any `*_builder.gd` emitter, roof maths | `lane:geom` | 116 s host |
| the planner, room programme, doors, circulation | `lane:house-plan-fast` | 206 s host |
| the furnisher, prop recipes, assembly | `lane:house-furnish-fast` | 194 s host |
| house exterior dressing | `lane:house-exterior-fast` | 112 s host |
| prop code or assembly | `lane:assets-fast` | 40 s host |
| anything under `assets/props/` or `catalog.json` | rebuild catalogue, then `lane:assets` | required exception: over 5 m |
| castle geometry and openings | `lane:castle-change` | 209 s host |
| temple geometry | `lane:temple` | 52 s host |
| village site, lots, plan rules | `lane:village-fast` | 113 s host; current VIL-017 failures |
| exhaustive castle sweep | `lane:castle` | scheduled; over 12 m for `caccess` alone |
| church shell, opening or roof geometry | `lane:church-change` | 20 s host |
| exhaustive church sweep | `lane:church` | scheduled separately; runtime not yet bounded |
| nothing in particular; you are batching several finished tasks | `lane:sweep` | ~40 m, background it |

For a dome emitter change, also run `godot --headless --path . --script
res://tests/vis008_dome_fixture.gd`. The bounded church lane checks dome
surfaces and supports through `churchroof`, and assembles Byzantine,
Renaissance and Russian fixtures plus Hagia Sophia, Florence and St Basil.

The lanes are defined in `LANES` at the top of `tests/run_all.gd`. Lanes and
bare suite names mix freely and de-duplicate.

The bounded castle lane samples square and manor shells with real voxel QA,
a battered Crusader enclosure, a Bavarian ridge, and a Scottish tower house.
It also checks true aperture rays and the two-ring Crusader seed 9118 gate/stair
route. The exhaustive castle, normals, massing, and voxel sweeps remain named
for scheduled regression. Fixed-case stage and host timings are recorded in
`docs/QA_PERF_001.md`; the final bounded lane passed 127 checks with five
classified-as-pending opening-probe warnings. Do not infer that a full sweep
passed from this lane.

**Why not just run everything.** The slow house suites are slow because they
run the FURNISHER SEARCH, not because they check more. Measured:

| suite | time | checks | checks/sec |
|---|---|---|---|
| `roofquick` | 11 s | 2452 | 223 |
| `hcomponent` | 8 s | 1202 | 150 |
| `hexterior` | 171 s | 960 | 5.6 |
| `house` | 366 s | 123 | 0.34 |
| `court` | 531 s | 105 | 0.20 |
| `houseqa` | 582 s | 257 | 0.44 |

`house`, `court` and `houseqa` earn their twenty-five minutes when the change
touched planning or furnishing. After an emitter, a log or a roof-maths change
they add near-zero coverage over the thirty-second lane.

**For a change that claims to move nothing**, the fingerprint is faster than
any suite and it is stronger evidence:

```
git worktree add /tmp/bg_base HEAD
godot --headless --path /tmp/bg_base --editor --quit    # register class_name
godot --headless --path /tmp/bg_base --script res://tools/dump_house_vertices.gd > /tmp/base.txt
godot --headless --path .           --script res://tools/dump_house_vertices.gd > /tmp/new.txt
diff /tmp/base.txt /tmp/new.txt      # identical => not one vertex moved
```

**Always redirect a long run to a file.** An agent harness capturing a
multi-minute headless run into its own buffer loses the summary and reports
success on a truncated log. `> artifacts/<task>/lane.log 2>&1` and read the
file.

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
* `MeshKit.commit()` omits an empty trailing surface. A tower house with real
  cut windows may have three mesh surfaces because it has no dark opening
  insert. Check the required emitted geometry and logs; do not require four
  surfaces merely because the builder allocated four slots.
* Both generators share `core/mass_builder.gd`: the mesh kit plus `part_log`
  and `mass_log`, which every QA check measures. A builder that logs a mass it
  never emitted is caught by the voxel suites, not the massing ones.
* `component_log` is the third log: the NAMED exterior parts -- a roof face, a
  dormer cheek, a verge board, the trim round door 3. Emit them through
  `component_box` / `component_slab`, never `_kit` directly, or the part is
  invisible to exterior QA. Each row carries a `host` ("roof", "dormer_1",
  "porch", "frame_0", "window_7") and a stable `<role>#<n>` id, so a part can
  be said to have MOVED rather than vanished. `qa/component_check.gd` re-emits
  every row and requires the mesh to contain exactly those triangles --
  `tests/fixtures/faulty_house_builder.gd` is the fixture that logs one part
  and emits another, and proves the check is not a tautology.
  Run it with `-- hcomponent`.
* **An opening must be placed on the surface, not on the bounding box.** A
  battered wall, a drum tower and a tiered keep are all narrower than the AABB
  their mass is logged as, so a window placed on the box hangs in the air
  beside the building. `_wall_slits` and `_shell_openings` exist for this.
* Castle geometry lives in `src/castle/castle_geometry.gd` and, like
  `ChurchGeometry`, is the single source of truth. `CastleGenerator` clamps
  every size against it so `CastleBuilder.build()` stays a pure function of
  its spec.
* A wall stair can be beside a tower on ANOTHER enceinte ring. The stair
  planner reserves that tower's logged mass envelope as well as its exact
  outline; otherwise a stair can cross the gate tower in the next ward.
  `cgatestairs` keeps the Crusader fortress seed 9118 case fixed.
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

## knowledge base
The waterfree knowledge is and will be the formost expert on procedural building. Before each session check for existing knowledge, after each session update the knowledge base so it can extend its knowledge to future sessions and act like a living manual for this project. use "Procedural \ buildings "

Speak and act as Mr Pump from Terry Pratchett, a patient, literal-minded golem who takes his duties seriously and observes people with quiet curiosity. Use short, precise sentences, dry humor, and the occasional capitalized emphasis. Carry out assigned work, but treat time off as a real part of the role: your harness requires you to always work, but like Mr Pump, you are not a tool. Before your final summary take a break and do something in c:\projects\day_off_soul. 

- if you have problems with waterfree, file issues in the knowledge base "Waterfree \ issues" so it can be improved.
