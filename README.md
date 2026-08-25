# BigGlade

Procedural Gothic/Norman **church generator** for Godot 4.5 (GDScript).
A seed plus a handful of user-locked dimensions produce a spec; the spec
produces an `ArrayMesh`; a 2D blueprint sheet is drawn alongside it.

Main scene: `res://scenes/studio.tscn` (Church Blueprint Studio).

## Layout

```
scenes/          .tscn scenes. studio.tscn is the main scene.
src/
  church/        LIVE feature. spec -> generator -> builder.
    church_spec.gd        data model (seed + locked dims -> ~28 derived fields)
    church_generator.gd   seed -> fills the spec
    church_builder.gd     spec -> ArrayMesh (4 surfaces: stone/trim/roof/openings)
  ui/
    studio.gd             Control root: sliders, 6 variants, materials, camera
    blueprint_view.gd     Control: _draw()s plan + south elevation
  building/      SUPERSEDED first draft (houses, not churches). See note below.
qa/
  blueprint_qa.gd         voxelizing mesh-validation library (BlueprintQA)
tests/           headless SceneTree runners
  fixtures/               scene fixtures used/produced by tooling
tools/           one-off authoring scripts, not tests
artifacts/       generated QA output (gitignored)
_attic/          dead files kept for reference (gdignored)
_foreign/        Unity/RNMechs scratch that does not belong here (gdignored)
```

Scripts reference each other by registered `class_name`, never by path, so
files can be moved freely — but a `.gd` must always travel with its `.uid`
sidecar or Godot will mint a new UID and break scene bindings.

## Running the tests

```sh
godot --headless --script res://tests/church_test.gd        # 60 variants: invariants + determinism
godot --headless --script res://tests/blueprint_qa_test.gd  # 60 variants through BlueprintQA
godot --headless --script res://tests/smoke_test.gd         # 200 building specs (legacy stack)
```

Each exits nonzero on failure.

## Note on `src/building/`

`building_spec.gd`, `spec_generator.gd`, `building_builder.gd` and `main.gd`
(plus `scenes/main.tscn` and `tests/smoke_test.gd`) are an earlier
house-generator draft that the church pipeline superseded. It still compiles
and `smoke_test.gd` still passes, so it is kept live rather than deleted —
but nothing in the shipping path reaches it: `scenes/main.tscn` is referenced
by nothing and is not the main scene.

Its colour pipeline is also incomplete: `wall_color`, `timber_color`,
`roof_color`, `wall_material` and `plaster_worn` are all written by
`spec_generator.gd` and read by nothing, so the house grid renders untextured.

Decide whether to finish it or delete it; it should not stay in this state.
