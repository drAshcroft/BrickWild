# Roof audit utility and findings

The cross-family audit checks the **emitted meshes** of houses, shops, hotels,
churches, castles and temples. Run it from the repository root:

```powershell
.\tools\check_roofs.ps1
.\tools\check_roofs.ps1 -Family hotel -Seed 42
.\tools\check_roofs.ps1 -Family church,temple -Output artifacts/dome_audit
.\tools\check_roofs.ps1 -SelfTest -Output artifacts/roof_probe_controls
```

The wrapper uses the Godot executable documented in AGENTS.md. Override it with
`-GodotPath`. It launches a hidden headless process, writes `.log`/`.err`, detects
script errors that otherwise hang Godot, and enforces `-TimeoutSeconds` (600 by
default). It rejects engine errors and stale reports. Exit 0 means no detected
failures; exit 1 means roof defects; runner errors raise a PowerShell error.

The portable Godot entry point is `res://tools/check_roofs.gd`:

```text
godot --headless --path . --script res://tools/check_roofs.gd
godot --headless --path . --script res://tools/check_roofs.gd -- --family=hotel --seed=42 --out=res://artifacts/hotel_roofs
godot --headless --path . --script res://tests/run_all.gd -- roofprobe
```

Repeat `--family=` to select several families. Unknown arguments fail with code
2. The native runner exits 2 for usage/report-write errors. `--self-test` runs
the probe controls only. The full audit deliberately remains separate from
`run_all` because it currently reports unresolved defects; `roofprobe` is in
the regular suite order.

## What it measures

- Existing house, church and castle/temple roof suites: independent envelope
  equations, ridge/hip/valley joins, gable closures, dormer cuts, dome rims,
  tower caps, spire seating, pitch/size/rotation variants and known regressions.
- 58 complete generated shells: every registered style/form of the six
  families at seeds **42 and 4413**, using each spec's default dimensions.
  Shops use their default business. Furniture is omitted; shop/hotel generators
  now accept `with_furniture=false`, like HouseGenerator. Their default remains
  `true`, so normal calls retain furnishing.
- Roof material triangles above occupied space: finite coordinates, unit
  normals, clockwise winding agreement, zero-area triangles and coincident
  triangles (vertex positions quantized to 0.0001m).
- Vertical coverage over top-storey house/shop/hotel room outlines, church
  naves and non-ziggurat temple halls. The helper supports polygon outlines and
  explicit sky openings. Samples use an offset 13x13 grid per region.
- Hotel dormer attachment against a separately emitted host-only roof. The
  test cannot let a floating dormer count as its own supporting roof.

`tests/roof_probe.gd` exposes `inspect`, `coverage` and `attachment` for new
fixtures. Nine controls establish valid slabs/attachments and detect missing
coverage, covered courtyards, reversed normals, floating dormers and duplicated
triangles. The older house suite separately retains the crossed-hip and lowered
gable negative controls.

The generated report is `artifacts/roof_audit.md`, with all numeric evidence in
`artifacts/roof_audit.json`. Each generated row records family, style, seed,
dimensions, builder source and per-region samples. `mesh_findings` includes
surface-2 triangle indices, all three vertices and the original triangle index
for duplicates. Hotel `dormer_attachment_failures` gives the sample X/Z,
body-bottom height, host-top height and gap in metres.

## Completed run: 2026-09-09

**35,103 checks; 4 failure groups; 8 warning groups.** The PowerShell wrapper
returned exit 1 as expected for detected defects, with an empty engine-error
log. The nine probe controls also passed independently through the wrapper.
Counts combine sampled rays with existing suite assertions; failure groups
are grouped diagnostics, not counts of individual faulty triangles.

| Family | Generated cases | Checks including fixed suites | Failure groups | Warning groups |
|---|---:|---:|---:|---:|
| House | 10 | 7,114 | 0 | 0 |
| Shop | 10 | 6,820 | 0 | 0 |
| Hotel | 4 | 10,848 | 4 | 0 |
| Church | 12 | 7,345 | 0 | 6 |
| Castle | 14 | 1,417 | 0 | 0 |
| Temple | 8 | 1,550 | 0 | 2 |
| Probe controls | — | 9 | 0 | 0 |

### Confirmed: hotel dormers float above the host roof

Task **ROOF-AUDIT-001**, `ce7a0f3b-a089-47f0-ba09-fc263c3abdbd`, P1.

Source: `HotelBuilder._build_hotel_dormers` in
`src/hotel/hotel_builder.gd:154`. All cases are 48x24m, three 3.6m storeys.

| Style | Seed | Detached bodies | Rear-edge vertical air gap |
|---|---:|---:|---:|
| grand_budapest | 42 | 6 | 0.998m |
| alpine_palace | 42 | 6 | 0.777m |
| grand_budapest | 4413 | 8 | 1.137m |
| alpine_palace | 4413 | 8 | 0.916m |

The builder fixes each box at `z=-length/2-0.3` and
`y=wall_top+roof_rise*0.42`. Its rear edge does not reach the slope. For the
first grand_budapest/42 body, X=-16.21333, rear sample Z=-11.845,
body bottom Y=12.19133, host roof top Y=11.19340.

Fit the dormer body, cheeks and rooflet to the actual slope, with host openings
if these are occupiable dormers. Validate front/side/rear joins and unobstructed
glazing; passing attachment alone will not prove those additional properties.
Retain the strict attachment test and rerun hotel landmark checks after repair.

### Warnings: duplicate seams and degenerate faces need classification

Task **ROOF-AUDIT-002**, `3ef49d68-b9f9-4836-b0cb-c299cc4046ef`, P2.

| Fixture | Coincident triangles | Zero-area triangles |
|---|---:|---:|
| church renaissance/42 | 44 | 0 |
| church russian/42 | 114 | 0 |
| church byzantine/4413 | 50 | 4 |
| church renaissance/4413 | 108 | 0 |
| church russian/4413 | 10 | 0 |
| temple rotunda/42 | 2 | 0 |
| temple rotunda/4413 | 2 | 0 |

These are **warnings, not proven exposed holes or z-fighting**. Adjacent
clipped slabs can emit coincident, opposite-facing internal caps. Inspect
`src/church/church_roofs.gd`, `ChurchBuilder._dome_profile`,
`TempleBuilder._build_dome_roof`, and `MeshKit.slab_poly/revolve` before removing
faces. Preserve intentional shell thickness and shared boundaries.

Useful starting evidence: renaissance/42 duplicates surface-2 triangles
2510/2518 near (6.668,14.484,7.183); rotunda/42 duplicates 175/654 near
(10.405,11.880,-3.381). Byzantine/4413's first zero-area face is triangle 412,
with two effectively identical apex vertices at Y=15.47923. All offending
coordinates are in the JSON report.

## Remaining coverage work

**ROOF-AUDIT-003** records these test gaps; they are not counted as passing:

- Authored courtyard/polygon houses and arbitrary roof openings. The helper
  supports their explicit contracts; this generated sweep is rectangular.
- All castle tier sizes, intentional open battlements and yard regions;
  complete church peripheral joins; ziggurat chamber/terrace coverage.
- Hotel cupola seams and the architectural distinction between its current
  gable profile and a true mansard.
- Placed village instances, transformed joins and tree/roof interference.
- World building families: `WorldFamilies.FAMILIES` is currently empty.

Use explicit covered polygons, sky openings and occupied-space top heights for
new fixtures. A site's bounding box cannot distinguish rooms from intentional
courtyards. Add a removed-roof negative control and an intentional-open-area
positive control per new contract. The fixed regression suites supplement
sampling, but neither this run nor a coverage percentage proves every possible
intersection, culling direction or visual design is correct.

The durable task snapshot is `docs/tasks/roof_audit_tasks.json`; live tasks are
in WaterFree. Existing house exterior backlog remains in
`docs/HOUSE_EXTERIOR_TASKS.md` and is not closed by this audit.
