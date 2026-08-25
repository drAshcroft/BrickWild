# BigGlade

Procedural cathedral generator for Godot 4.5 (GDScript).

A seed plus a handful of user-locked dimensions produce a spec; the spec
produces an `ArrayMesh`; a 2D blueprint sheet is drawn alongside it from the
same geometry. Six styles, from a Romanesque parish church to Hagia Sophia.

Main scene: `res://scenes/studio.tscn` (Church Blueprint Studio).

## Layout

```
scenes/          studio.tscn, the main scene
core/
  mesh_kit.gd           mesh primitives shared by every builder: boxes, slabs,
                        gable/hip roofs, tapers, surfaces of revolution, arches
src/
  church/        the generator, in pipeline order
    church_spec.gd        data model (seed + locked dims -> derived fields)
    church_geometry.gd    WHERE EVERY MASS SITS -- shared by builder and view
    church_generator.gd   seed -> fills the spec
    church_builder.gd     spec -> ArrayMesh (stone / trim / roof / openings)
  ui/
    studio.gd             sliders, variants, materials, camera
    blueprint_view.gd     draws the plan and south elevation
qa/
  blueprint_qa.gd         voxelising mesh-validation library
  massing_check.gd        no gaps, no overlap, size match
tests/           headless suites; run_all.gd runs them in order
  suites/               the suite libraries themselves
  fixtures/             scene fixtures used by tooling
tools/           one-off authoring scripts, not tests
docs/            LANDMARKS.md (reference churches), KNOWN_ISSUES.md
```

Scripts reference each other by registered `class_name`, never by path, so
files move freely — but a `.gd` must always travel with its `.uid` sidecar or
Godot mints a new UID and breaks scene bindings.

## Architectural features

Driven by the reference churches in `docs/LANDMARKS.md`:

| Feature | Seen in |
|---|---|
| Flying buttresses (pier + flyer arch + pinnacle, 1–2 tiers) | Notre-Dame, Cologne, Chartres |
| Domes: hemispherical, onion, on an octagonal drum; lanterns | Hagia Sophia, St Basil's, Florence |
| Half-domes and semi-domed exedrae buttressing the main dome | Hagia Sophia |
| Alcoves: radiating chapels, ambulatory, clustered chapel rings | Chartres, Notre-Dame, St Basil's |
| Twin west towers, and crossing/lantern towers | Cologne, Durham, Salisbury |
| Multiple aisle rings (single, double, five-aisled) | Notre-Dame, Cologne |
| Narthex, pendentives, transept crossing, apse, rose windows | throughout |

## Running the tests

```sh
godot --headless --script res://tests/run_all.gd              # everything, in order
godot --headless --script res://tests/run_all.gd -- massing   # one suite
```

Suites run cheapest-and-most-fundamental first, so a broken contract is
reported before a slow voxel sweep can bury it. Each assumes the ones above it
hold:

| # | suite | asserts |
|---|-------------|--------------------------------------------------------|
| 1 | `church`    | inputs survive generation; `build()` is pure and deterministic |
| 2 | `massing`   | no gaps, no undesigned overlap, sizes match the spec    |
| 3 | `blueprint` | the drawing agrees with the model                      |
| 4 | `landmark`  | the famous churches build, at four scales each         |
| 5 | `voxelqa`   | rasterised geometric checks (slowest)                  |

The runner exits nonzero if any suite fails. Suite bodies live in
`tests/suites/` as libraries; `tests/<name>_test.gd` are thin wrappers that run
one suite each, so both entry points share one implementation.

Suites 1–3 and 5 iterate `TestSweep` — the same 6 styles × 15 sizes with fixed
seeds — so a seed named in one suite's output is the same building in every
other suite's output.

## Structural correctness

`qa/massing_check.gd` checks three properties over the building's structural
masses, and runs both standalone and as part of `BlueprintQA`:

- **no gaps** — every mass touches the assembly; nothing floats
- **no overlap** — masses interpenetrate only at joints designed to, and only
  as deep as that joint declares (see the `_allowance` table)
- **size match** — emitted masses match the dimensions the spec asked for

It measures `ChurchBuilder.mass_log`, which records the true world AABB of each
volume as emitted. That distinction matters: the check it replaced re-derived
the apse position from the same formula the builder used, so it compared a
formula against itself and could never fail.

## The one rule

`ChurchGeometry` owns the massing. Both the mesh builder and the blueprint view
read from it, and **neither may derive a position of its own**. When they each
did their own arithmetic they drifted — the mesh embedded the tower 0.6 m while
the drawing embedded it 5.5 m, and nothing caught it. The `blueprint` suite
exists to keep them honest.
