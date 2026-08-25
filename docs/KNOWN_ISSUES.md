# Known issues — prioritized backlog

Findings from the architecture review. Ordered by severity.
Items marked FIXED were resolved in commit 9ac1fce.

## FIXED

- **Apse detached from the nave by 3.7–7.4 m in every apse-bearing variant.**
  `half_cylinder()` puts the drum's flat face at `cy`, but `cy` was computed as
  `l/2 + r - APSE_EMBED` (full-cylinder maths). Missed because the check that
  should have caught it recomputed `cy` from the same formula and reduced to
  `x < x - 0.05` — always false. Voxel connectivity also passed because
  `_cone_cap` emits a full cone that bridged the void.
- **Aisles lapped the transept crossing by exactly 0.30 m.** The aisle east
  limit ignored the `APSE_EMBED` shift applied to the transept.
- **Added `qa/massing_check.gd`** — no gaps / no overlap / size match, measured
  from emitted geometry. Run via `tests/massing_test.gd`; also wired into
  `BlueprintQA`.

## Still open — geometry

### A. The apse roof is a full cone over a half drum
`_cone_cap` (`src/church/church_builder.gd`) emits full boxes centred on the
drum, so the roof extends `r + 0.35` in **both** Z directions while the drum it
caps occupies only `[cy, cy + r]`. Its western half is now buried inside the
nave. It was this overhang that masked the detached apse from the connectivity
check. A half-cone matching the drum is the correct primitive.

### B. The blueprint's tower placement disagrees with the mesh by metres
Mesh tower spans `[-l/2 + 0.6 - tw, -l/2 + 0.6]` — embedded 0.6 m.
Blueprint tower spans `[-l2 - 0.45·tw, -l2 + 0.55·tw]` — embedded `0.55·tw`,
which for a 10 m tower is 5.5 m. Same drift class as issue 2 below; the
massing checks do not cover the blueprint, only the mesh.

## P1 — Correctness

### 1. `ChurchBuilder.build()` mutates its input spec
`src/church/church_builder.gd:70` does `spec.aisles = 0` when the tower leaves
no room. Consequences:
- `build()` is not a pure function of its argument — building the same spec
  twice can differ.
- `qa/blueprint_qa.gd:392` tests `if spec.aisles > 0`, so it reads the
  **post-mutation** value and silently skips the aisle/tower check for exactly
  the cases that triggered the fix.
- `tests/church_test.gd:17` only checks that `style` and `length` survive, so
  the mutation is untested.

The "no room for aisles" decision is a generation decision and belongs in
`church_generator.gd`.

### 2. The blueprint is not a drawing of the mesh
`src/ui/blueprint_view.gd` re-derives the geometry by hand instead of reading
it from the builder. The two have already drifted:

| Quantity | church_builder.gd | blueprint_view.gd |
|---|---|---|
| Tower center Z | `-l/2 + TOWER_EMBED - tw/2` (:131) | `-l2 - tw*0.45 + tw/2` (:89) |
| Apse center Z | `l/2 + apse_radius - APSE_EMBED` (:112) | `l2 + apse_radius*0.6` (:82) |
| Transept Z | `l/2 - tz_w/2 - APSE_EMBED` (:96) | `l2 - tz_w/2 - apse_radius*0.6` (:69) |
| Nave side windows | only when `aisles == 0` (:214) | drawn unconditionally (:200) |

Fix: extract a shared geometry module both consume. Then add the missing test —
rasterize the plan the way `BlueprintQA` rasterizes the mesh and compare
footprints.

### 3. `building_builder.gd` draws randomness at build time
`src/building/building_builder.gd:96-100` pull from `spec.rng` (used at :67,
:68, :157-158, :179, :190-191). So the *mesh* consumes randomness the *spec*
was supposed to have resolved, and two builds of the same spec object differ.
This breaks the contract stated at `building_spec.gd:3-4`.
`church_builder.gd` does not have this bug. `church_test.gd` tests determinism
only by regenerating from seed, so it would not catch it.

### 4. A warning that fires 100% of the time (STILL OPEN)
`artifacts/qa_out.txt` reports `60/60 variants passed` while emitting 60
warnings — every variant trips `grounded: eaves/trim dips 0.06-0.11m below
ground`. The builder's slab half-thickness (`church_builder.gd:286-289`, ±0.12)
structurally guarantees it. Either lift the eave geometry or raise the
threshold at `blueprint_qa.gd:213-214`. As written it is noise, not a signal.

## P2 — Structure

### 5. God functions
- `church_builder.gd:34-232` — `build()` is 199 lines across ten `tag()`-
  delimited sections. The tags already name the ten methods it should be.
- `blueprint_view.gd:119-225` — `_draw_elevation()`, 107 lines.
- `blueprint_view.gd:32-117` — `_draw_plan()`, 86 lines.

### 6. Duplicated geometry emitters
- Box triangulation written **four** times: `building_builder.gd:104-138`,
  `church_builder.gd:239-270`, `church_builder.gd:454-468` (`_push_poly_box`),
  and the corner list again at `:470-477`.
- Stepped-taper solid written **four** times: `building_builder.gd:206-216`,
  `:249-255`, `church_builder.gd:370-376`, `:378-384`.
- Sloped slab twice in one file: `church_builder.gd:280-306` and `:309-336`.
- `pick()` four times: `building_spec.gd:51`, `church_spec.gd:87`,
  `spec_generator.gd:149`, `church_generator.gd:82`.

### 7. Constants duplicated across the builder/view boundary
This is the drift vector behind issue #2. Each should exist once:
`0.55` transept depth ratio, `2.2` spire rise, `0.32`/`3.4` door height,
`3.2` window bay spacing, `0.15` aisle interpenetration, `0.75` pyramid rise,
`0.02` opening epsilon (9 sites in `church_builder.gd` alone), `7919` seed stride.

### 8. Misplaced responsibilities
- `ChurchSpec.STYLES` (`church_spec.gd:45-74`) is generation policy on a data
  model; the UI reaches into it for `"label"` strings via an untyped Dictionary.
- `ChurchSpec.transept_w_depth()` (:91) is builder geometry on a data bag — and
  two of its three would-be call sites ignore it anyway.
- `studio.gd:69-76` builds `StandardMaterial3D` inside a UI controller.
- `studio.gd:95-110` is a camera controller inside a UI controller.

### 9. `ChurchGenerator.generate()` double-seeds
`studio.gd:47` seeds via `ChurchSpec.new(base_seed + i*7919)`, then `:52` passes
the same seed again to `generate()`, which re-assigns `spec.seed` and
`spec.rng.seed` (`church_generator.gd:12-13`). In tests it is worse:
`ChurchSpec.new(0)` then `generate(spec, 5000+i)` — the constructor argument is
meaningless. One concept, two entry points.

### 10. Seeds are unreproducible in the UI
`studio.gd:45` does `var base_seed: int = randi()`, never displayed or
persisted, with no seed input field. Both spec docstrings promise "the same
seed always rebuilds the identical structure" — but no user can act on it.

## P3 — Hygiene

### 11. Confirmed dead code (each verified by grep, zero call sites)
`BuildingSpec.randf/randi_range/pick` (`building_spec.gd:45,48,51`),
`ChurchSpec.rf/chance/pick` (`church_spec.gd:81,84,87`),
`ChurchBuilder.surf()` (`church_builder.gd:236`),
`BlueprintView.mesh_info` (`blueprint_view.gd:7`, never written or read),
`main.gd:4` `GRID` const (loop hardcodes `range(8)` and `- 3.5`).

### 12. No-op statements
- `building_builder.gd:181-182` — `fwd` computed, overwritten, never used.
- `blueprint_view.gd:35-36` — `draw_string(..., "", ...)` draws an empty string.
- `blueprint_view.gd:62` — `draw_rect` with `Color(0,0,0,0)`, fully transparent.
- `blueprint_view.gd:152-155` — `t_l` recomputed identically; `t_r` overwritten.
- `blueprint_view.gd:187-189` — the east gable polyline starts and ends at the
  same point, so the gable is never actually drawn.
- `studio.gd:89-90` — `_mat(c: Color) -> Color: return c` is an identity
  function, and misleadingly named (returns a Color, not a Material).
- `church_spec.gd:56` — gothic `"aisles": [1, 2]`, but the builder only tests
  `> 0` and always loops two sides, so `2` renders identically to `1`.

### 13. Type-hint gaps, and the disabled guardrail
`project.godot:16` sets `gdscript/warnings/untyped_declaration=0`, which
switches off the warning that would surface these. Untyped `Array` where an
element type is known: `_sts`, `part_log`, `specs`, `meshes`, `_solid`.
All four `pick`/`_pick` return Variant. `part_log` entries are stringly-typed
dicts read as `p["tag"] != "nave"` at 7 sites in `blueprint_qa.gd`.

### 14. Shadowing of `@GlobalScope`
`building_builder.gd:96,99` and `building_spec.gd:45,48` define `randf` /
`randf_range`. `blueprint_qa.gd:235` declares `var seed := ...`, shadowing the
global `seed()`. `blueprint_qa.gd:368-369` declare local variables in
SCREAMING_CASE, which read as constants.

### 15. Duplicated test fixture
`tests/church_test.gd:7-15` and `tests/blueprint_qa_test.gd:8-18` are the same
4x15 sweep setup, byte for byte.
