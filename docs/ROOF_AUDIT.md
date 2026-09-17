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
log. All four failure groups were ROOF-AUDIT-001 and are resolved; see below. The nine probe controls also passed independently through the wrapper.
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

### RESOLVED 2026-09-17: hotel dormers floated above the host roof

Task **ROOF-AUDIT-001**, `ce7a0f3b-a089-47f0-ba09-fc263c3abdbd`, P1. Fixed.

Source was `HotelBuilder._build_hotel_dormers`. It fixed each box at
`z = -length/2 - 0.3` and `y = wall_top + roof_rise * 0.42` -- two numbers that
never ask the roof how high its surface is at that point. All cases 48x24 m,
three 3.6 m storeys.

| Style | Seed | Detached bodies before | Rear-edge gap before | After |
|---|---:|---:|---:|---:|
| grand_budapest | 42 | 6 | 0.998 m | 0 |
| alpine_palace | 42 | 6 | 0.777 m | 0 |
| grand_budapest | 4413 | 8 | 1.137 m | 0 |
| alpine_palace | 4413 | 8 | 0.916 m | 0 |

The fix moved the dormer-seating maths into `RoofShape.dormer_seat`, which the
house already had inline and correct -- the hotel's separate copy was the bug.
The hotel now seats every dormer on the actual host plane in the roof's own
frame, ends rooflets on the valley line, tapers cheeks to the same
intersection, and cuts a real opening in the host slope using
`MeshKit.ridge_roof`'s `deferred_faces` hook, so the roof no longer runs behind
the glazing. Centre-crown and cupola positions are skipped explicitly.

Verification:

- `tools/check_roofs.ps1 -Family hotel` -- 10857 checks, 0 failure groups,
  0 warning groups; `dormer_attachment_failures` empty on all four rows, with
  all 28 bodies actually probed. Baseline for the same command was 4 failure
  groups / 28 detached bodies.
- `tools/check_roofs.ps1 -Family hotel -Seed 42` -- 5431 checks, 0 failure
  groups, the same check count as the 5431-check baseline that reported 2
  failure groups.
- `run_all.gd -- hotel hotelroof hlandmark` -- 3 suites, 18 checks, 0 failures.
- Before/after renders: `tools/render_hotel_dormers.gd -- --tag=<label>`
  (must not be headless) writes eave, row and single-dormer views.

Two notes for whoever touches this next:

- The dormer pieces are logged components (`dormer_roof`, `dormer_cheek`,
  `dormer_gable`, `dormer_jamb`, `dormer_panel`, `dormer_glazing`) hosted on
  the dormer id, plus ONE `part_log` row per body measured from the emitted
  cheeks and gable front. Two logging defects were found on the way, and both
  are worth knowing about:
  - Emitting straight through `_kit` left the geometry correct but invisible to
    `HotelQA._check_landmarks`, which counts `part_log` dormers. Loud failure.
  - Logging the body with `kind = "dormer"` made `_hotel_attachments` select
    nothing, because it filters `tag == "dormer" and kind == "box"`. The audit
    then reported zero failures HAVING PROBED ZERO BODIES. Silent false pass;
    the only tell was the total check count dropping by 12. The record is
    `kind = "box"` for that reason -- do not rename it.
  - The record covers the BODY only (cheeks and gable front). The rooflet
    overhangs the join, and `Probe.attachment` samples the host under the
    body's REAR edge, so including the rooflet would sample past the join.
- The landmark dormer count clears its threshold with ZERO MARGIN at scales
  1.00 and 1.30 (6 of 6, 10 of 10). Three dormers are dropped by the
  centre-crown exclusion, as they were before this fix. Any change to crown
  width or dormer spacing will trip `landmark: mansard roof has too few
  dormers` immediately.

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
