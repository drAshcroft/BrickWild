# Known issues

Status after commits d2eb18b, 9ac1fce, ede3e99 and the follow-up.
All 5 suites pass: 443 checks, 0 failures, 0 warnings.

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

## Open

### 1. `src/building/` is a superseded draft awaiting a decision
`building_spec.gd`, `spec_generator.gd`, `building_builder.gd`, `main.gd`,
`scenes/main.tscn` and the legacy suite are an earlier house generator. It
compiles, it is deterministic, and its suite passes — but nothing in the
shipping path reaches it: `scenes/main.tscn` is referenced by nothing and is
not the main scene. Its colour pipeline is also unfinished (`wall_color`,
`timber_color`, `roof_color`, `wall_material`, `plaster_worn` are written by
the generator and read by nothing, so houses render untextured).

**This is a product decision, not a bug: finish it or delete it.** It is kept
building so the choice stays deliberate.

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
