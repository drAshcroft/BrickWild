# BigGlade

Procedural cathedral generator for Godot 4.5 (GDScript).

A seed plus a handful of user-locked dimensions produce a spec; the spec
produces an `ArrayMesh`; a 2D blueprint sheet is drawn alongside it from the
same geometry. Six styles, from a Romanesque parish church to Hagia Sophia.

## Library API

Godot tools can generate the family-specific representation first, then choose
when to emit a mesh:

```gdscript
var request := BuildingRequest.house(1234, &"townhouse", &"smith", 9.0, 12.0, 2.6, 2)
var building: GeneratedBuilding = BigGlade.generate(request)
if building.is_ok():
	var plan: HousePlan = building.plan
	var mesh: ArrayMesh = BigGlade.build_mesh(building)
	var placement: Dictionary = BigGlade.placement(building)
	var furnished_scene: Node3D = BigGlade.instantiate(building, false, true)
```

Use `BuildingRequest.church()`, `.castle()`, `.house()`, `.shop()`, `.hotel()` or `.temple()` so each
call site keeps the vocabulary of that building family. Generation is seeded,
does not mutate the request, and does not emit geometry until `build_mesh()`.
`placement()` reports measured bounds, footprint, identity and the local -Z
front. The third `instantiate()` argument opts into shell-only collision.

### Discovering what to ask for

`BigGlade.describe_kind()` publishes everything a caller needs to build a
valid request without importing a single family header: the size envelope,
the labels, and — the option-discovery contract — `styles` and `purposes`,
each an ordered array of `{"id", "label"}`, alongside the words that family
calls them (`style_label`, `purpose_label`: a temple has a form and a cult, a
shop a style and a business).

```gdscript
var d := BigGlade.describe_kind(&"shop")     # d["purpose_label"] == "Business"
for option in d["purposes"]:
	print(option["id"], " ", option["label"])
var request := BigGlade.default_request(&"shop", 1234)   # valid, from d's own defaults
print(BigGlade.option_label(&"shop", &"purpose", request.purpose))
```

`src/api/building_library.gd` owns those tables, and the same rows that
publish them are the rows a request is validated against, so anything offered
can be built and anything built was offered. `src/api/building_family_adapter.gd`
owns the other half — what each family DOES: generate its representation,
build its mesh, assemble its scene, and answer for its own footprint and
front door. `BigGlade` is dispatch and nothing else, so a new family is a new
adapter and a new library row rather than an edit to five `match` statements
in five different orders. Every request is refused on its
own terms — with `{"code", "field", "message"}` errors — before a family
generator sees it.

### Documents: what a building is, before anything draws it

`generate()` hands back the family's own live object. `generate_document()`
wraps it in the shape that crosses a boundary:

```gdscript
var doc: BuildingDocument = BigGlade.generate_document(request)
var mesh: ArrayMesh = BigGlade.build_mesh(doc)      # same mesh, vertex for vertex
var json := JSON.stringify(doc.to_dict())           # plain data: no BigGlade needed to read it
```

The payload inside a document is the family's plan or spec **untouched**, so
building from a document and building from the generation that made it give
the same mesh; `to_dict()` is the same building as plain dictionaries, arrays
and numbers, with `placement` already measured. `tools/export_village_plan.gd`
is the same idea one level up, for a whole village.

House requests accept one to three explicit storeys. `height` remains the
floor-to-ceiling height of each storey. The retained `HousePlan` labels rooms,
openings and furniture by storey and records the stair links between floors;
the builder emits those levels and puts one pitched roof above the top level.

Shop requests use the same tested plan-first representation and accept a
business plus a house shell style. Available businesses include blacksmith,
stable, restaurant, tavern, inn, bakery, butcher, apothecary, general store,
tailor, carpenter, town hall, and guildhall. See `docs/SHOPS.md`.

A **village** is asked for the same way (`kind = &"village"`), and comes back
as a `VillagePlan` on `GeneratedBuilding.village` — roads, lots and the
`BuildingRequest`s standing on them. Its two numbers are not metres: the
request's `width` carries the population and its `length` the wealth as a
percentage, which is why the descriptor publishes `width_label` and
`length_label`. `build_mesh()` gives the ground, roads, water, edge and
built props; `instantiate()` gives all of that plus every building, prop,
plant and light. See `docs/VILLAGES.md`.

```gdscript
var request := BigGlade.default_request(&"village", 9101)
request.width = 40.0          # people
request.style = &"english"    # culture
var made := BigGlade.generate(request)
var plan: VillagePlan = made.village
```

`BuildingRequest.hotel()` builds a Grand Budapest-inspired landmark with a
furnished three-storey plan, broad symmetrical pink facade, raised central
pavilion, mansard roof, dormers, balconies, and paired cupolas. See
`docs/HOTELS.md`.

## Compatibility and reproducibility

What a caller of the library may rely on, and what it may not.

- **Godot.** The source project and packaged addon target Godot 4.5.2.
  The installer harness accepts the consumer's Godot executable for verification.
  Pure GDScript, no C# and no GDExtension.
- **API version.** `BigGlade.API_VERSION` is `1`, and every `describe_kind()`
  and `placement()` result carries it. Additive changes (a new kind, a new
  descriptor field, a new placement key) keep the number; a change that
  removes or renames a field, or alters what an existing field means, raises
  it. `BuildingRequest`'s public fields (`kind`, `seed`, `style`, `purpose`,
  `width`, `length`, `height`, `storeys`, `material`, `water`, `enclosure`) are
  the request contract.
- **Coordinates.** Metres. `+X` right, `+Y` up, `+Z` back; every family's
  public front faces local `-Z`. The door is the actual entrance, which may
  be recessed behind the footprint's front edge in an open manor courtyard.
  The ground plane is `y = 0` (a cellar's pit is
  below it). `placement().bounds` is the emitted architecture's AABB.
- **Materials.** Every family's mesh has four surfaces, in this order:
  wall/stone, trim, roof, floor/openings. `instantiate()` assigns a
  `StandardMaterial3D` per surface from the spec's colours, through the one
  loop in `ShellAssembler.surface_materials()`; the colours themselves come
  from `BuildingFamilyAdapter.colours(spec)`, so a caller that builds its own
  materials can ask for them by surface index instead of reaching into a spec
  it should not have to know about. (A village is the one family with more
  than four: ground, road, common, water, stone, wood, roof, dark.)
- **Serialization.** Plans and specs are plain data (`Dictionary`,
  `Rect2`, `Vector2`, `StringName`). A record may gain keys between
  releases; readers must ignore keys they do not know. Keys are never
  removed without the API version changing. Requests and building documents
  have schema-1 dictionary/JSON readers and writers; document state preserves
  derived values and engine value types without RNGs or runtime objects.
  See [the transport contract](docs/PUBLIC_API_TRANSPORT.md) for headless
  generation, structured QA, lossless state and DM_View interior export.
- **Seeds.** Within one generator release, the same request (kind, seed, style,
  purpose, sizes, storeys) produces the same representation, the same
  `placement()` and the same mesh, on the same Godot version. Seeded output
  is **not** guaranteed stable across releases: a generator change that
  re-arranges a house is a change to every seed, and it is made
  deliberately. A caller that needs a building to stay put should keep the
  plan it was given, not the request.

`tests/suites/library_suite.gd` holds the smoke contract for all of this:
the version, the descriptors, the placement keys, and the same request
generated twice.

## Addon installation

To use BigGlade from another Godot project, install the relocatable addon with
the repository's PowerShell installer (Godot 4.5 or newer):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\install_big_glade_addon.ps1 `
  -TargetProject C:\path\to\GodotProject
```

The installer places the package at `res://addons/big_glade`, is safe to run
again, and leaves unrelated files there untouched. Run the destination project
once in the editor after installation so Godot imports the bundled props and
registers the addon's scripts. See `packaging/big_glade/README.md` for the
package details and managed-file behavior.

Main scene: `res://scenes/studio.tscn` (Church Blueprint Studio).

## Layout

```
scenes/          studio.tscn, the main scene
core/
  mesh_kit.gd           mesh primitives shared by every builder: boxes, slabs,
                        gable/hip roofs, tapers, surfaces of revolution, arches
  mass_builder.gd       the three logs every check reads: parts, masses, props
  shell_assembler.gd    a built shell + its dressing -> a scene, with lights
src/
  api/           the public request, generated result and BigGlade facade
  church/        the generator, in pipeline order
    church_spec.gd        data model (seed + locked dims -> derived fields)
    church_geometry.gd    WHERE EVERY MASS SITS -- shared by builder and view
    church_generator.gd   seed -> fills the spec
    church_builder.gd     spec -> ArrayMesh (stone / trim / roof / openings)
    church_furnisher.gd   spec -> prop placements: pews, altar, banners, fire
    church_assembler.gd   the only file that loads a model
  ui/
    studio.gd             sliders, variants, materials, camera
    blueprint_view.gd     draws the plan and south elevation
qa/
  blueprint_qa.gd         voxelising mesh-validation library
  massing_check.gd        no gaps, no overlap, size match
  dressing_check.gd       the props are known, inside, clear of each other,
                          and not blocking the aisle or the gate
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

A built church is also **furnished**. `ChurchFurnisher` puts an altar at the
east end with a chalice, candles and standing candelabra; pews in two blocks
either side of a processional aisle, pitched down the nave and dropped where
they would stand in the crossing; a lectern and a brazier at the chancel step;
torches and banners along the nave walls at the same bay as the windows;
lamps hung over the aisle; a font inside the west door and a coil of bell rope
in the tower. Aisles get their own light and the parish chest.

None of it is placed by a coordinate. The pews are pitched, the sconces are
spaced by the bay, and every piece is sized against the nave it is going in --
so a chapel and a cathedral are furnished by the same rules and neither has a
number written down for it.

## Running the tests

```sh
godot --headless --script res://tests/run_all.gd              # everything, in order
godot --headless --script res://tests/run_all.gd -- massing   # one suite
```

Suites run cheapest-and-most-fundamental first, so a broken contract is
reported before a slow voxel sweep can bury it. Each assumes the ones above it
hold:

| suites | asserts |
|---|---|
| `library` | public request, representation, mesh and scene contract |
| `church`, `castle`, `house`, `shop`, `hotel`, `temple` | family generation purity and determinism |
| `normals`, `massing`, `blueprint`, `cnormals`, `cmassing` | emitted geometry and drawing agreement |
| `voxelqa`, `cvoxelqa`, `houseqa`, `hmultistory`, `rite`, `interior` | spatial, circulation and ritual correctness |
| `landmark`, `clandmark`, `harchetype`, `sarchetype`, `hlandmark`, `tarchetype` | named reference buildings and archetypes |
| `court` | buildings round a yard: the four court rules, each shown firing, and a hundred courtyard houses |
| `assets` | measured prop catalogue still matches imported models |
| `dressing` | churches and castles are furnished, and you can still walk through them |

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
