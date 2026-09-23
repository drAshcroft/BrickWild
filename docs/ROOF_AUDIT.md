# Roof audit utility and findings

The cross-family audit checks the **emitted meshes** of houses, shops, hotels,
churches, castles and temples. Run it from the repository root:

```powershell
.\tools\check_roofs.ps1
.\tools\check_roofs.ps1 -Family hotel -Seed 42
.\tools\check_roofs.ps1 -Family church,temple -Output artifacts/dome_audit
.\tools\check_roofs.ps1 -SelfTest -Output artifacts/roof_probe_controls
.\tools\check_roofs.ps1 -RegionsOnly -Output artifacts/roof_region_contracts
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
the probe controls only. `--regions-only` runs the named authored contracts
without repeating the broad generated matrices. The full audit remains a
separate reporting tool; `roofprobe` is in the regular suite order.

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
fixtures. Eleven controls establish valid slabs/attachments and detect missing
coverage, covered courtyards, reversed normals, floating dormers and duplicated
triangles, including explicit stone-surface ceiling selection. The older house suite separately retains the crossed-hip and lowered
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

### Classified roof seams (ROOF-AUDIT-002)

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

The table above is the original inventory. The final church/temple audit
(`artifacts/p1p2_roof_seams/final.json`) passes 8,904 checks, with three warning
groups and no degenerate faces. Renaissance and Russian fixtures are clean.
Successive dome clipping left micrometre-wide polygon slivers and repeated
corners; extruding them created full-depth coincident caps. `ChurchRoofs`
now removes consecutive edges below 0.1 mm and rejects only fragments whose
minimum altitude is below 0.1 mm. A real 1 mm strip remains in the control.

`MeshKit.revolve` now rejects zero-area partial-dome caps and winds the far
cut face outwards. This retains the closed end faces and shell thickness.
Byzantine/4413 retains 22 opposite-facing cap triangles where closed half-domes
meet. Both rotunda seeds retain two opposed deck/rim caps whose corresponding
vertices differ by about 1.43 micrometres. Those are internal shared boundaries,
not exposed same-facing skins, and are deliberately retained. The probe reports
normal dot products and actual vertex deltas alongside quantized signatures.
It distinguishes `opposed_shared_cap`, `same_facing`, `crossed_normals` and
`quantized_near` instead of treating a rounded coordinate match as proof.

`tests/roof_seams_test.gd` guards real fixture dispositions, synthetic opposite
and same-facing triangles, thin intentional strips, and outward partial caps.
The geometry lane plus church normals and castle/temple roof regression passed
8,992 checks with zero failures and three existing normals warnings.

Useful starting evidence: renaissance/42 duplicates surface-2 triangles
2510/2518 near (6.668,14.484,7.183); rotunda/42 duplicates 175/654 near
(10.405,11.880,-3.381). Byzantine/4413's first zero-area face is triangle 412,
with two effectively identical apex vertices at Y=15.47923. All offending
coordinates are in the JSON report.

## Authored region contracts (ROOF-AUDIT-003)

`tests/roof_region_fixtures.gd` declares each covered polygon, intentional sky
polygon, occupied-space top and material surface independently of emitted logs.
The JSON retains those coordinates and exclusions, dimensions, source, seed,
surface, sample counts and every failing coordinate. Every covered region has
an actual removed-surface negative control, with the specification unchanged.

| Contract | Explicit coverage and sky |
|---|---|
| Two four-range courts | Every occupied range covered; central yard sees sky |
| 8- and 14-sided halls | Polygon floor covered except the circular 24-sided oculus |
| Three ziggurat sizes (18×24, 24×30, 36×42 m) | Base chamber covered by stone surface 0; exposed terraces see sky outside the independently tested stair flights |
| Ziggurat summit support | Real platform supports the entire idol base; host mesh omits the idol so it cannot support itself |
| Ziggurat summit stairs | Every actual tread reaches its intended height with risers ≤350 mm; the landing meets the summit; stair-only geometry leaves the chamber below clear |
| Four castle tiers at two sizes | Native occupied keep outlines and ranges; flat turret decks use trim surface 1; yard/wall walks remain open; the well's little roof is an explicit covered exception |
| Both hotel styles at two sizes | Cupola coverage plus actual rim-to-tower bearing; a raised roof fails the seam control |
| Two placed village buildings | Native house/shop roofs and open approaches after real lot placement and rigid transformation |

The contracts and renders exposed several geometry defects. Ziggurat columns used the entire
mountain height and pierced the upper terraces; their capitals now meet the
base chamber ceiling. The summit idol used the ground sanctum's rear position
and floated beyond its platform; its footprint now fits the highest terrace,
with the chamber dais/altar axis adjusted below it and the pit refitted. A flat
castle turret deck passed its centre to a primitive that takes its base,
leaving a 0.125 m gap; the deck now meets the shaft. Actual raised-deck controls
guard that bearing as well as hotel cupola rims.

Ziggurat flights originally reached full height at the base's front wall, several
metres short of the summit. They now extend into the summit with a half-metre
landing overlap and correctly centred treads. The original physical toe and
forecourt stay fixed; an actual mesh AABB comparison guards placement bounds.
The extension initially revealed a second problem: solid stair blocks filled
the chamber beneath. Outdoor sections remain solid to ground, while indoor
sections start at the chamber ceiling and have separate truthful mass records.
Alcove caps also respect that ceiling. No overlap rule was relaxed. Actual
shortened-flight and solid-filled-chamber mutations prove the contact and
interior checks fail when those defects return.

Final evidence for ROOF-AUDIT-003:

- `artifacts/p1p2_roof_regions/regions_complete.json`: 24 authored cases,
  11 probe controls, **16,971 checks, zero failures and zero warnings**.
- `stair_chamber_lane.log`: temple, rite, temple archetypes and castle/temple
  roofs, **4,196 checks, zero failures**, 11 existing idol-dominance warnings.
- `geometry_final.log`: required geometry lane, **6,961 checks, zero failures
  and zero warnings**. The earlier optional `geometry_lane.log` was stopped
  during the slow broad castle normals sweep and is not a passing lane.
- `renders/`: six real assembled ziggurat views (front, summit and occupied
  chamber at 18×24 and 24×30 m). The summit idol is supported, the flights reach
  the platform, and the chamber remains clear beneath them. The renderer logs
  the existing Mobile-renderer SSAO warning; all six images were produced and
  inspected.

The reusable contract guidance is in `docs/ROOF_REGION_CONTRACTS.md` and the
WaterFree knowledge entry `b1c72898-24d8-4f10-883e-140f21693ce1`.

The clean addon consumer subsequently exposed a compact 24×24×16 m blood
ziggurat at seed 731: the original random bay count compressed capital pairs
into overlaps up to 1.20 m after the sanctum moved beneath the summit. The
generator now fits the final longitudinal run using the actual capital diameter
(2.4 times shaft radius) plus 0.2 m clearance before authoring `spec.columns`.
Twelve compact size/seed cases and moved-column negative controls now join
`TempleSuite`. `compact_columns.log` passes **2,275 checks**, zero failures and
11 existing dominance warnings; the installed addon smoke also passes
(`artifacts/p1p2_api/addon_temple4_smoke.log`). This is additional compact-grid
evidence, not a claim that arbitrary untested roof regions are covered.

These remain uncovered rather than passing: arbitrary court/outline and castle
shape/size combinations outside the named matrix, complete church peripheral
joins beyond existing fixed suites, a true hotel mansard profile, other placed
village families, inter-building roof joins and tree/roof interference.
`registry_coverage` lists every registered WorldFamilies kind as **uncovered**
until a dedicated roof contract exists. If the registry is empty, the report
explicitly says so; an empty registry is never a passing family.

Use explicit covered polygons, sky openings and occupied-space top heights for
new fixtures. A site's bounding box cannot distinguish rooms from intentional
courtyards. Add a removed-roof negative control and an intentional-open-area
positive control per new contract. The fixed regression suites supplement
sampling, but neither this run nor a coverage percentage proves every possible
intersection, culling direction or visual design is correct.

The durable task snapshot is `docs/tasks/roof_audit_tasks.json`; live tasks are
in WaterFree. Existing house exterior backlog remains in
`docs/HOUSE_EXTERIOR_TASKS.md` and is not closed by this audit.
