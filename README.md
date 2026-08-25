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
    church_geometry.gd    WHERE EVERY MASS SITS -- shared by builder and view
    church_generator.gd   seed -> fills the spec
    church_builder.gd     spec -> ArrayMesh (4 surfaces: stone/trim/roof/openings)
  ui/
    studio.gd             Control root: sliders, 6 variants, materials, camera
    blueprint_view.gd     Control: _draw()s plan + south elevation
  building/      SUPERSEDED first draft (houses, not churches). See note below.
qa/
  blueprint_qa.gd         voxelizing mesh-validation library (BlueprintQA)
  massing_check.gd        structural correctness: no gaps, no overlap, size match
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
godot --headless --script res://tests/run_all.gd              # everything, in order
godot --headless --script res://tests/run_all.gd -- massing   # one suite
```

Suites run cheapest-and-most-fundamental first, so a broken contract is
reported before a slow voxel sweep can bury it. Each assumes the ones above it
hold:

| # | suite       | asserts                                                |
|---|-------------|--------------------------------------------------------|
| 1 | `church`    | inputs survive generation; `build()` is pure and deterministic |
| 2 | `massing`   | no gaps, no undesigned overlap, sizes match the spec    |
| 3 | `blueprint` | the drawing agrees with the model                      |
| 4 | `legacy`    | the superseded house stack still stands                |
| 5 | `voxelqa`   | rasterized geometric checks (slowest)                  |

The runner exits nonzero if any suite fails. Suite bodies live in
`tests/suites/` as libraries; `tests/<name>_test.gd` are thin wrappers that run
one suite each, so both entry points share one implementation.

All suites iterate `TestSweep` -- the same 4 styles x 15 sizes with fixed
seeds -- so a seed named in one suite's output is the same building in every
other suite's output.

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

## Structural correctness

`qa/massing_check.gd` checks three properties over the building's structural
masses, and runs both standalone (`tests/massing_test.gd`) and as part of
`BlueprintQA`:

- **no gaps** - every mass touches the assembly; nothing floats
- **no overlap** - masses interpenetrate only at joints designed to, and only
  as deep as that joint declares (see the `_allowance` table)
- **size match** - emitted masses match the dimensions the spec asked for

It measures `ChurchBuilder.mass_log`, which records the true world AABB of each
volume as emitted. That distinction matters: the check it replaced re-derived
the apse position from the same formula the builder used, so it compared a
formula against itself and could never fail.
