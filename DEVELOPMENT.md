# Developing BrickWild

This guide is for contributors working on the generator, Studio, QA, or addon
packaging. If you only want to run or embed BrickWild, use the
[installation guide](INSTALLATION.md).

BrickWild is the repository and product name. The public GDScript class
`BigGlade`, the `addons/big_glade` install directory, and related filenames are
retained for API compatibility.

## Requirements

- Godot **4.5.2**. This is the tested source and addon version.
- Git.
- PowerShell for the addon installer and optional QA timing wrapper.

The project is pure GDScript. It does not require Mono, C#, GDExtension,
Python, or a package manager at runtime. Newer Godot releases have not yet been
verified.

## Set up a development checkout

```powershell
git clone https://github.com/drAshcroft/BrickWild.git
cd BrickWild
godot --editor --path .
```

Let the first editor import finish before running the project or tests. If
`godot` is not on `PATH`, replace it with the path to your Godot 4.5.2
executable.

After adding a script with a new `class_name`, refresh Godot's class cache
before running any suite:

```text
godot --headless --path . --editor --quit
```

Without that import pass, unrelated suites can fail with `Identifier not
declared`.

## Asset packs

The tracked checkout contains the Fantasy Props MegaKit and
`assets/props/catalog.json`. The Dungeon Kit, Nature Kit, and Stylized Nature
MegaKit model files are excluded from Git. Their local README files record the
expected sources and filename conventions, but the public repository does not
yet provide a reproducible fetch/import command or the omitted license files.

This is an **open release blocker**. A fresh clone can work on source-only
areas, but it cannot build the complete addon or run every asset-dependent
suite. Do not substitute a different pack revision and assume the catalogue is
still valid. After changing anything in `assets/props/`, rebuild and verify the
catalogue:

```text
godot --headless --path . --script res://tools/build_prop_catalog.gd
godot --headless --path . --script res://tests/run_all.gd -- lane:assets
```

The full measurement is intentionally slower than the ordinary per-change
gate. `--incremental` repeats from the source-fingerprinted cache;
`--verify-parity` checks cache-backed output against a complete measurement.

## Repository map

```text
core/                  shared mesh emitters, mass logging, and assembly
src/api/               public requests, documents, adapters, and facade
src/<family>/          family-specific specs, plans, geometry, and builders
src/ui/                Blueprint Studio UI and plan views
qa/                    geometry, circulation, furnishing, and semantic checks
tests/suites/           reusable test suites
tests/fixtures/         focused failure and integration fixtures
tools/                  renderers, exporters, catalogue and install tools
packaging/big_glade/    addon metadata, example, and package version
docs/                   design contracts, investigations, and QA protocols
```

The central runtime flow is:

```text
BuildingRequest -> BigGlade -> BuildingFamilyAdapter -> plan/spec
                                                  -> mesh / scene / placement
```

Keep planning and assembly separate. A house is a `HousePlan`; only
`HouseAssembler` loads models. Church and castle geometry modules are the
single source of truth for their mass placement. The builder and blueprint
must read those modules rather than independently deriving coordinates.

## Development workflow

1. Reproduce the problem with a fixed seed or focused fixture.
2. Change the smallest owning layer: plan, geometry, builder, assembler, or QA.
3. Add a regression check that observes the emitted result, not merely the
   formula used to produce it.
4. Run the bounded lane that matches the edit.
5. Render a representative case when the visual result changed.
6. Update user, API, or design documentation when the contract changed.

Godot front faces are clockwise. `MeshKit._face_normal` is the single winding
authority. `MeshKit.commit()` also deliberately does not generate normals:
emitters provide their own face normals so one surface does not become one
building-wide smoothing group.

When a named exterior part is added, emit it through `component_box` or
`component_slab`. Sending it directly to `_kit` makes it invisible to
component QA. For battered, tapered, or tiered walls, place openings on the
actual wall surface rather than on the building AABB.

## Running tests

Choose the lane that owns the edited behavior. Do not run the exhaustive sweep
for an ordinary change.

| Changed area | Selector |
|---|---|
| shared mesh emitters, builders, or roof math | `lane:geom` |
| church shell, opening, or roof geometry | `lane:church-change` |
| castle geometry and openings | `lane:castle-change` |
| house planning, doors, or circulation | `lane:house-plan-fast` |
| house furnishing, recipes, or assembly | `lane:house-furnish-fast` |
| house exterior dressing | `lane:house-exterior-fast` |
| prop code or assembly | `lane:assets-fast` |
| temple geometry | `lane:temple` |
| village sites, lots, or plan rules | `lane:village-fast` |
| public request, library, placement, or facade API | `lane:api` |
| church or castle dressing | `dressingquick` |
| house archetypes that must furnish correctly | `harchetype` |

Example:

```text
godot --headless --path . --script res://tests/run_all.gd -- lane:geom
```

Selectors and bare suite names can be combined and are de-duplicated. The
runner exits nonzero on failure. A successful run ends with `ALL PASS`.

Always redirect a multi-minute run to a file. This preserves the summary and
prevents a test harness from mistaking truncated output for success:

```powershell
New-Item -ItemType Directory -Force artifacts/my-change | Out-Null
godot --headless --path . --script res://tests/run_all.gd -- lane:api *> artifacts/my-change/lane.log
```

`tools/run_qa_lane.ps1` records stdout, stderr, native exit code, and wall
time. See [the fast QA protocol](docs/QA_FAST_PROTOCOL.md) for lane definitions,
expected times, and scheduled gates.

If a run stops producing output, inspect the top of its log for `Parse Error`.
A GDScript parse error can leave the headless runner alive instead of returning
normally.

The long `lane:scheduled` and `lane:sweep` gates are for release or batched
merge validation. Run only one Godot process at a time and keep their output in
an artifact log. A bounded lane does not imply that an exhaustive sweep passed.

## Visual verification

Reference renders require a real renderer; the headless dummy renderer does
not produce a useful image:

```text
godot --path . --script res://tools/render_shots.gd
godot --path . --script res://tools/shoot_studio.gd
```

Rendered evidence complements geometry and QA checks. It does not replace
them. When updating a tracked screenshot, keep its generating script and
reproduction seed current.

## Addon packaging

`tools/big_glade_addon_manifest.json` defines the relocatable package.
`tools/install_big_glade_addon.ps1` copies that closure into
`res://addons/big_glade` and tracks the files it owns. Update the manifest when
a runtime script is added, removed, or moved. Every `.gd` with a registered
class must travel with its `.gd.uid` sidecar.

From a complete local checkout, verify an install with a disposable Godot
project:

```powershell
.\tools\install_big_glade_addon.ps1 -TargetProject C:\path\to\GodotProject -DryRun
.\tools\install_big_glade_addon.ps1 -TargetProject C:\path\to\GodotProject
godot --headless --path C:\path\to\GodotProject --editor --quit
```

The installer is currently tested on Windows. PowerShell 7 behavior on macOS
and Linux has not been verified.

## Before opening a pull request

- Read [CONTRIBUTING.md](CONTRIBUTING.md) and follow the code of conduct.
- Run the smallest relevant bounded lane and report its exact command/result.
- Note any required suite that could not run because of the missing public
  asset closure.
- Include a seed and screenshot for visible changes.
- Preserve API compatibility or explain the `BigGlade.API_VERSION` impact.
- Record the origin and license of every new third-party asset.

For deeper project invariants and maintainer commands, see `AGENTS.md`. Design
documents in `docs/` explain the family-specific contracts; start with the
document nearest the code being changed.
