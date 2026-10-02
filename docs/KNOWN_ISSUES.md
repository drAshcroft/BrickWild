# Known issues

This file includes historical findings. For the current render-led review and
exact QA coverage, see [the evaluation follow-up](EVALUATION_2026-10-01.md#render-led-follow-up-brickwild).
Passing bounded lanes does not imply that the full scheduled sweep passed.
House warnings deliberately retain daylight shortfalls and furniture removed
to preserve circulation.

## Fixed

### Geometry
- **Apse detached from the nave by 3.7–7.4 m in every apse-bearing variant.**
  `half_cylinder()` puts the drum's flat face at `cy`, but `cy` used
  full-cylinder maths. Two independent checks missed it: the `parts_join` test
  recomputed `cy` from the same formula and reduced to `x < x - 0.05` (never
  true), and voxel connectivity passed because a *full* cone roof bridged the
  void.
- **The apse roof is now a half cone**, matching the half drum it caps.
- **The nave and transept had no roof.** `_slab()` took no base height, so it
  built every gable at `y ∈ [0, rise]` — on the ground, inside the walls.
  Measured: byzantine seed=5000 walls at 10.00 m, sheet dimensioned 17.13 m,
  highest roof vertex 12.37 m (which was the apse).
- **Eaves/trim dipping below ground**, which warned on 60/60 variants, was a
  symptom of the same bug: slabs at ground level with 0.12 half-thickness.
  Gone now, not suppressed.
- **Stepped roofs overshot their nominal apex.** Steps are anchored so their
  tops land on the profile.
- **Aisles lapped the transept crossing by 0.30 m** — the aisle limit ignored
  the `APSE_EMBED` shift applied to the transept.

### Structure
- **The blueprint was not a drawing of the model.** Mesh embedded the tower
  0.6 m; the blueprint embedded it `0.55 × tower_width` (5.5 m for a 10 m
  tower). Transept Z, apse Z and the nave-window rule disagreed too. Both now
  read `src/church/church_geometry.gd`, which owns every shared constant and
  derived position.
- **`ChurchBuilder.build()` mutated its input** (`spec.aisles = 0`), which also
  blinded the QA aisle check. The decision moved to `ChurchGenerator`; the
  church suite asserts purity and idempotence.
- **`BuildingBuilder` drew randomness from `spec.rng` at build time**, so the
  same spec built twice differed. It now uses its own generator re-seeded from
  the spec; the legacy suite asserts idempotence.
- **`ChurchGenerator.generate()` double-seeded.** `ChurchSpec.new()` no longer
  demands a provisional seed; `generate()` is the single seeding point.
- **Seeds were unreproducible in the UI.** The studio now displays the seed.
- Removed dead code: `_cone_cap`, `ChurchSpec.rf/chance/pick`,
  `ChurchBuilder.surf()`, `BlueprintView.mesh_info`, `studio._mat()` (an
  identity function returning a Color, not a Material), and the no-op draws in
  `BlueprintView` — the empty `draw_string`, the fully transparent
  `draw_rect`, the duplicated `t_l`/`t_r`, and the degenerate east-gable
  polyline that began and ended at the same point.
- Duplicated 4×15 test fixture folded into `TestSweep`.

## Fixed by the castle work

- **The box emitter and the stepped taper were written four times over**
  (issue 2 below). Both live in `MeshKit` now, and `core/mass_builder.gd`
  holds the logs and the kit for both builders.
- **The voxel rasterizer existed once, inside `BlueprintQA`.** It is
  `qa/voxel_grid.gd` now, and the castle sweep uses it. Its voxel size is
  chosen per building: a 300 m fortress at half-metre voxels is 24 million
  cells, and the dilation pass alone outran every other suite combined.
- **`revolve()` emitted the degenerate apex ring of every cone and dome.**
  Zero-area triangles can only carry an invented normal; they are dropped now,
  which also took the church normals warnings from 72 down to 40.
- **The three structural rules were welded to the church.** They are
  `qa/mass_rules.gd`, parameterised by a joint table; `MassingCheck` and
  `CastleMassingCheck` supply their own.

## Open

### 0. The blueprint sheet draws churches, villages and houses, not castles or temples
`BlueprintView` draws a plan and elevation for a `ChurchSpec`, the site for a
village, and (EVAL-U02) `HouseSheet` draws a house, a shop or a hotel: a plan
per storey from `HouseGeometry` (shell runs, partitions, doors as swing arcs,
windows as triple lines, stairs, hearth, courts, furniture at its measured
footprint), the front elevation (-Z) from the builder's own roof faces, and a
room schedule. The `hblueprint` suite holds the drawing against the plan and the
mesh. A castle still gets a note, and a temple a text list. The house sheet draws
no dormers (they are never on the -Z face), no colonnade runs, and a courtyard
house gets no roof in elevation because its ranges are roofed one by one.

### 0b. Houses are one to three storeys, with a cellar (resolved)
`HouseSpec.storeys` is 1..3 and `cellars` 0..1 (INT-016); stairs are a room
kind, the nav check climbs them, and `hmultistory` sweeps 200 two-storey
houses. What remains is the temple (0aa below).

### 0aa. A temple is one storey and has no crypt
The rite runs at ground level. A stair down to an undercroft, or up to a
gallery over the nave, would need the walking check to understand levels --
which is the same thing the houses want for a second storey.

### 0c. The full suite takes well over an hour
Measured 2026-10-01: `hotel` alone 23 min (a hotel generation costs 45 s or
more in the furnisher search), `court` 8 min, `dressing` 37 min, `library`
10 min after its regeneration waste was removed, `placement` over an hour.
`lane:api` and `lane:scheduled` in `tests/run_all_impl.gd` split the fast
contract checks from the pre-merge gates; see `docs/QA_FAST_PROTOCOL.md`.
A faster hotel generator is the real fix.

### 0d. Village scheduled acceptance still needs a complete rerun
The fresh 2026-10-02 audit supersedes the original thirteen-failure report:
`vlot` passed 71 checks, including manor frontage. Before the current repair,
`vcheck` had four failures (one missing tavern and three common-frontage cases).
The Thorpe matrix stopped at seed-index 0, population scale 1.4, with density
and common-frontage failures; unvisited cells are not passes.

The green-site repair keeps road offset tied to site depth, moves ring
junctions when the common needs more width, and connects the well by a real
path. The expanded `vsite` gate passed 311 checks and `lane:village-fast`
passed 10. All four originally failing green seeds subsequently passed focused
VillageQA. Thorpe's measured landmark-depth reservation now includes churches
as well as temples: its failing cell passed nine checks, with density 6.7%
and common frontage 69%. Sixteen native-building warnings remain visible.
Complete scheduled acceptance is still tracked as EVAL-C11/C13; these focused
passes do not establish that every previously unvisited matrix cell is green.

### 1. `src/building/` has been deleted (resolved)
The superseded draft generator is gone from the tree.

### 2. Remaining duplication inside the builders
The box emitter is written three times (`building_builder.gd:104`,
`church_builder.gd:239`, `church_builder.gd:_push_poly_box`) with the corner
list a fourth. The stepped-taper solid appears four times, and `_slab`/
`_lean_roof` are near-identical. Extracting a shared mesh kit is worthwhile but
touches every emitter, so it wants doing in one deliberate pass with the suites
as the guard.

### 3. `ChurchBuilder.build()` is still long
~200 lines across ten `tag()`-delimited sections. The tags already name the
methods it should be split into. Behaviour-preserving, but wide.

### 4. Type-hint gaps, and the disabled guardrail
`project.godot:16` sets `gdscript/warnings/untyped_declaration=0`, suppressing
the warning that would surface these. Untyped `Array` where the element type is
known: `_sts`, `part_log`, `specs`, `meshes`, `_solid`. `part_log` entries are
stringly-typed dicts read as `p["tag"] != "nave"` at 7 sites in
`blueprint_qa.gd`.

### 5. `ChurchSpec.STYLES` is generation policy on a data model
The UI also reaches into it for `"label"` strings through an untyped
Dictionary. `gothic`'s `"aisles": [1, 2]` remains a dead branch: the builder
tests `> 0` and always loops two sides, so `2` renders identically to `1`.
