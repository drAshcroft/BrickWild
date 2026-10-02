House exterior task runbook
===========================

These tasks implement the findings in [HOUSE_RULES_EVALUATION.md](HOUSE_RULES_EVALUATION.md). The authoritative live status/dependencies are in the waterfree task store. This file and `docs/tasks/house_exterior_tasks.json` preserve the instructions in the repository, since `.waterfree/` and `artifacts/` are ignored. The initial backlog was diagnostic; implementation and remaining scope are now recorded in [HOUSE_ROOF_FIX.md](HOUSE_ROOF_FIX.md) and task aiNotes. Pending does not mean untouched: read those notes before repeating a geometry repair.

Start with `waterfree todos search HOUSE-EXT- --workspace .` or `get-ready`. Claim only a ready task, set it executing, and read its dependencies' completion notes. Do not infer completion from old roof tasks: the earlier overhead-coverage repair is complete but its overlapping-slab approach is explicitly superseded by HOUSE-EXT-003.

All lengths below are metres. House axes: +X right, +Y up, +Z back; the front is -Z. The builder rotates the roof to follow the longer footprint dimension, so roof-local sides are not always world-space sides. Use symbol searches when line numbers drift.

Known fixtures (set style/trade/width/length/height/storeys first, then call `HouseGenerator.generate(spec, seed)`):

| Fixture | Style / trade | Seed | Width x length | Height per storey | Storeys | Original result |
|---|---|---|---|---|---|---|
| Farm | farmhouse / none | 4413 | 10 x 13 | 2.7 | 1 | Naturally hipped; 2 dormers; broken side envelope; runtime QA passes |
| Town | townhouse / none | 4411 | 9 x 12 | 2.7 | 2 | Half hip; 2 dormers; trim-only jetty; runtime QA passes |
| Cottage | cottage / none | 4412 | 7 x 9 | 2.5 | 1 | Gable; no dormers; sill crosses door at Y about 0.624; runtime QA passes |
| Hall | longhall / none | 4414 | 12 x 16 | 2.7 | 1 | Gable; rise 5.440636; nominal gable profile offset 0.299878; runtime QA passes |

Keep both natural-generation integration fixtures and deliberately configured geometry fixtures. If generation changes legitimately, log the derived fields; do not let a seed that now disables a feature silently remove regression coverage. Explicit overrides must be applied after generation and labelled in the fixture. Geometry-focused tests should avoid repeated expensive furnishing when a small explicit plan suffices.

PowerShell commands (Godot is not on PATH):

```powershell
$godotExe = 'C:/Projects/godot/Godot_v4.5.2-stable_mono_win64/Godot_v4.5.2-stable_mono_win64.exe'
# Only required after adding a NEW class_name:
& $godotExe --headless --path . --editor --quit
# Choose suites relevant to your task, not every suite on every edit:
& $godotExe --headless --path . --script res://tests/run_all.gd -- house houseqa hmultistory harchetype
# Changed prop files require remeasurement, then assets suite:
& $godotExe --headless --path . --script res://tools/build_prop_catalog.gd
& $godotExe --headless --path . --script res://tests/run_all.gd -- assets
# Existing tracked render starting point; do NOT add --headless:
& $godotExe --path . --script res://tools/render_house_roofs.gd -- --full
```

HOUSE-EXT-001 now provides `tests/run_all.gd -- hroof hexterior`, `tests/house_roof_test.gd -- --full` and `tools/render_house_roofs.gd -- --full`. Historical `artifacts/eval_house_rules.gd` and `artifacts/probe_house_rules.gd` are useful if present, but not guaranteed in a fresh checkout. Existing images are under `artifacts/house_rules_eval/`. The `roof_farm_*` images are the natural seed; `roof_farm_hip_*` is an explicitly forced-hip control. The basic house suite completed 123 checks without reported failures in the evaluation; houseqa/hmultistory/harchetype did not complete in that run. Do not reuse historical task notes as proof that today's full suite passes.

Read AGENTS.md for the full rules. In particular: a GDScript parse error can hang a headless process; inspect the start of its error log instead of waiting indefinitely. Front faces are clockwise and `MeshKit._face_normal` owns the convention; never call generate_normals to paper over it. HousePlan is the truth, the builder is a pure emitter, and HouseAssembler is the only house model-loading boundary. Measure furniture/prop dimensions; reuse WalkGrid; preserve documented furnishing compromises.

When introducing files/classes/surfaces/serialized fields, inspect `tools/brick_wild_addon_manifest.json`, the addon installer tests, BuildingFamilyAdapter and BuildingDocument as applicable. Shared MeshKit changes may affect castle, hotel, temple and PropKit; discover actual callers and run their relevant suites. Do not automatically broaden a house fix into unrelated building-rule changes.

Dependency order controls prerequisites, not exclusive file ownership. HOUSE-EXT-003/004/005 may touch the same builder/mesh code: inspect the current diff before editing and coordinate if another agent owns those files. These tasks authorize backlog work, not automatic parallel execution.

For completion, write the reproduction, change, exact validation commands/results, render locations, unresolved failures and intentional behavior changes into aiNotes. A pass from old HouseQA or a nonempty mesh is never sufficient evidence of an exterior fix.

Related work: INT-018 (roof openings) remains pending and broader than dormers. It now depends on HOUSE-EXT-007, which owns the sloped dormer-cut subset and must establish a compatible roof_openings contract. INT-018 retains compluvium/oculus/court-sky requirements and reuses that implementation when it starts. Existing completed multi-storey/lighting/prop tasks are reusable foundations, not tasks to reopen wholesale.


Task index
----------

| Key | Priority | Task | Prerequisites |
|---|---|---|---|
| HOUSE-EXT-001 | P1 | Preserve house exterior reproductions and add a focused diagnostic runner | Ready |
| HOUSE-EXT-002 | P1 | Define one roof geometry description for faces, eaves, ridge and attachments | HOUSE-EXT-001 |
| HOUSE-EXT-003 | P1 | Replace overlapping hipped roof slabs with joined polygon faces | HOUSE-EXT-001, HOUSE-EXT-002 |
| HOUSE-EXT-004 | P1 | Fit gable walls, trusses and bargeboards to the actual roof underside | HOUSE-EXT-001, HOUSE-EXT-002 |
| HOUSE-EXT-005 | P1 | Log emitted roof and facade components for exterior QA | HOUSE-EXT-001 |
| HOUSE-EXT-006 | P1 | Make dormer eligibility and spacing follow roof-local capacity | HOUSE-EXT-002 |
| HOUSE-EXT-007 | P1 | Plan dormer openings and join cheeks and rooflets to their host faces | HOUSE-EXT-002, HOUSE-EXT-003, HOUSE-EXT-004, HOUSE-EXT-005, HOUSE-EXT-006 |
| HOUSE-EXT-008 | P1 | Split timber sill beams at exterior door openings | Ready |
| HOUSE-EXT-009 | P1 | Make house height and footprint bounds include the actual exterior | HOUSE-EXT-002, HOUSE-EXT-004, HOUSE-EXT-007 |
| HOUSE-EXT-010 | P2 | Add planned exterior placements and shared facade clearance rules | HOUSE-EXT-005, HOUSE-EXT-008 |
| HOUSE-EXT-011 | P2 | Dress house exteriors with owned props and style/trade recipes | HOUSE-EXT-010 |
| HOUSE-EXT-012 | P2 | Represent a real upper-storey jetty in the house plan | HOUSE-EXT-002 |
| HOUSE-EXT-013 | P2 | Emit jettied floors, walls, openings and roof on the planned footprint | HOUSE-EXT-004, HOUSE-EXT-007, HOUSE-EXT-009, HOUSE-EXT-012 |
| HOUSE-EXT-014 | P2 | Give house roofing and glazing distinct material treatment and valid UVs | HOUSE-EXT-003, HOUSE-EXT-004, HOUSE-EXT-007 |
| HOUSE-EXT-015 | P2 | Tune roof proportions and facade decoration rhythm by house archetype | HOUSE-EXT-004, HOUSE-EXT-007, HOUSE-EXT-011, HOUSE-EXT-013, HOUSE-EXT-014 |
| HOUSE-EXT-016 | P1 | Integrate exterior QA and close the house roof/decor regression matrix | HOUSE-EXT-003, HOUSE-EXT-004, HOUSE-EXT-005, HOUSE-EXT-007, HOUSE-EXT-008, HOUSE-EXT-009, HOUSE-EXT-011, HOUSE-EXT-013, HOUSE-EXT-014, HOUSE-EXT-015 |

HOUSE-EXT-001: Preserve house exterior reproductions and add a focused diagnostic runner
-------------------------------------------------------------------------
Priority: P1. Estimated effort: 90 minutes. Task ID: `809add2d-61e1-4c51-ac42-e1521f667471`.
Start at [tests/suites/house_qa_suite.gd](../tests/suites/house_qa_suite.gd), approximately line 433. Prerequisites: none.

PROBLEM
The evidence scripts and 24 images live under ignored artifacts/. A fresh checkout loses the reproductions. The generic house suites are slow and their roof coverage check accepts the broken farmhouse.

REPRODUCE / LOCATE
Read scratch/shoot_roofs.gd and, when present, artifacts/eval_house_rules.gd and artifacts/probe_house_rules.gd. Fixtures: farmhouse/none seed 4413, 10x13 m, height 2.7, storeys 1; townhouse/none 4411, 9x12, 2.7, 2; cottage/none 4412, 7x9, 2.5, 1; longhall/none 4414, 12x16, 2.7, 1. Set inputs before HouseGenerator.generate; build roof-on.

IMPLEMENTATION SCOPE
Move the useful fixture definitions and render/probe capability into tracked tools/tests, without depending on artifacts/ or scratch patches. Add a focused headless runner with a small mesh-only mode (derive fields and plan using HousePlanner where possible instead of expensive furniture searches) plus an explicit end-to-end generation mode. Preserve front, rear, both sides and elevated views; the negative roof-local-X side is needed to see dormers. Save JSON diagnostics and log the actual derived roof type. Establish the runner interface that later tasks can extend.

ACCEPTANCE CRITERIA
- A fresh checkout can regenerate the four fixtures and their measurements using documented commands, without pre-existing images or scripts in artifacts/.
- A non-headless command writes consistently framed before/after roof-on renders. Headless diagnostics never pretend to produce usable images.
- Baseline explicitly records farmhouse 4413: HouseQA ok=true and projected coverage=1.0 despite the visible defect; cottage entrance trim is hit near Y=0.624 m.
- New tests/diagnostics identify known broken cases explicitly; do not disable failures or turn a known defect into a passing assertion. Harness completion is separate from fixing those cases.
- Document focused invocation, expected output and exit status; new class_name is registered with a headless editor import.

HANDOFF / GUARDRAILS
Read AGENTS.md, docs/HOUSE_RULES_EVALUATION.md, and the shared runbook in docs/HOUSE_EXTERIOR_TASKS.md before editing. Symbol names are authoritative; line numbers are September 2026 starting points. Do not fix geometry or alter seed generation in this task. Preserve the naturally generated farmhouse separately from forced-hip examples. Tests that inspect only part counts are insufficient. Record exact commands, seeds, failures, and render paths when closing. Do not mark complete merely because existing HouseQA passes.

HOUSE-EXT-002: Define one roof geometry description for faces, eaves, ridge and attachments
----------------------------------------------------------------------------
Priority: P1. Estimated effort: 180 minutes. Task ID: `51b304dc-af35-4cee-b8ea-5f5e8058f92a`.
Start at [src/house/house_geometry.gd](../src/house/house_geometry.gd), approximately line 377. Prerequisites: HOUSE-EXT-001.

PROBLEM
HouseBuilder currently re-derives orientation, span, overhang, gable profile and dormer offsets in different methods. These disagree. There is no surface query that can place an attachment on the actual roof.

REPRODUCE / LOCATE
Compare HouseGeometry.roof_rise with HouseBuilder._build_roof (844), _half_hipped (900), _half_hip_gables (931), _build_bargeboards (941), _build_dormers (988). The roof chooses its ridge along the longer footprint axis; roof width is span+0.7 and ridge-axis extent along+0.5.

IMPLEMENTATION SCOPE
Add a pure roof description owned by HouseGeometry (a dedicated helper may be used), with explicit local/world transform, host storey, footprint/eave coordinates, ridge endpoints, named face polygons, surface normals/height queries, slab thickness and attachment regions. Define behavior for gable, half-hipped, hipped, square and rotated footprints. Query outside a face must report no host. Keep room/model loading separate. Migrate dimensions incrementally without presenting still-broken hip emission as corrected. Leave courtyard roofs explicit; do not cover a courtyard with a bounding rectangle.

ACCEPTANCE CRITERIA
- Equivalent footprints rotated 90 degrees produce equivalent local roof dimensions, transformed faces and attachment capacity; establish a deterministic square tie-break.
- Face height queries agree with their plane at vertices and interior samples; rejected outside-face queries cannot create floating attachments.
- Document whether eaves refer to slab mid-plane, top or underside; all thickness offsets have named ownership.
- The representation can describe short or collapsed hip ridges without degenerate faces or NaN normals.
- Basic house contract and focused descriptor tests pass; public user dimensions remain unchanged and repeated generation is deterministic.

HANDOFF / GUARDRAILS
Read AGENTS.md, docs/HOUSE_RULES_EVALUATION.md, and the shared runbook in docs/HOUSE_EXTERIOR_TASKS.md before editing. Symbol names are authoritative; line numbers are September 2026 starting points. Do not introduce a second random generator inside HouseBuilder. Support later top-storey footprints without implementing the jetty planner here. Pending INT-018 roof_openings should use this same description. Record exact commands, seeds, failures, and render paths when closing. Do not mark complete merely because existing HouseQA passes.

HOUSE-EXT-003: Replace overlapping hipped roof slabs with joined polygon faces
---------------------------------------------------------------
Priority: P1. Estimated effort: 180 minutes. Task ID: `f421f933-24f6-46fe-b13e-012831dd7b88`.
Start at [core/mesh_kit.gd](../core/mesh_kit.gd), approximately line 279. Prerequisites: HOUSE-EXT-001, HOUSE-EXT-002.

PROBLEM
MeshKit.hip_roof_at emits rectangular side and end slabs that intersect and leave lateral openings. An earlier completed task fixed overhead coverage by allowing overlap; that approach did not fix the envelope.

REPRODUCE / LOCATE
Natural reproduction: farmhouse/none seed 4413, width 10, length 13, height 2.7, storeys 1. Inspect artifacts/house_rules_eval/roof_farm_three_quarter.jpg if present. Existing HouseQASuite._roof_cover reports 1.0 and HouseQA reports no failures. Related completed task: 16322eb8-49de-4972-b574-ad682952bc2a; its suggestion to overlap slabs is superseded.

IMPLEMENTATION SCOPE
Use shared eave/ridge endpoints to emit two trapezoidal long faces and triangular hip ends, with explicit near-square/pyramid handling and joined slab thickness. Remove the crossed rectangular substitutes. Preserve the public MeshKit primitive contract where practical. Search callers of hip_roof and hip_roof_at before edits, including indirect wrappers. Add actual mesh-side closure and face-intersection regression checks, not only footprint coverage.

ACCEPTANCE CRITERIA
- Farmhouse 4413 has no large open side, crossing slab or buried dormer caused by an unrelated hip face; inspect all four sides and above.
- Long, short, square, near-square and rotated hip fixtures have finite clockwise outward faces and no positive-area overlap of unrelated exterior faces; shared ridge/hip seams and deliberate caps remain allowed.
- A regression fixture recreating the old crossed-slab geometry fails an envelope/topology check even though projected roof coverage remains 100%.
- Focused exterior checks pass for this defect; run house/houseqa plus relevant shared-primitive caller suites found by search.

HANDOFF / GUARDRAILS
Read AGENTS.md, docs/HOUSE_RULES_EVALUATION.md, and the shared runbook in docs/HOUSE_EXTERIOR_TASKS.md before editing. Symbol names are authoritative; line numbers are September 2026 starting points. Do not fix this by extending slabs until they overlap, adding a wall to hide the hole, disabling culling tests, or reducing the coverage threshold. MeshKit uses clockwise front faces and must not call generate_normals(). Record exact commands, seeds, failures, and render paths when closing. Do not mark complete merely because existing HouseQA passes.

HOUSE-EXT-004: Fit gable walls, trusses and bargeboards to the actual roof underside
---------------------------------------------------------------------
Priority: P1. Estimated effort: 150 minutes. Task ID: `f71d5095-3469-4af0-bb8e-9f44651e6ed4`.
Start at [src/house/house_builder.gd](../src/house/house_builder.gd), approximately line 931. Prerequisites: HOUSE-EXT-001, HOUSE-EXT-002.

PROBLEM
The slab slope uses span+0.7, the bargeboard uses span, and MeshKit.ridge_roof lowers the gable apex by ex/half. This shifts the gable wall profile downward from the real roof, with trim masking some of the error.

REPRODUCE / LOCATE
Inspect core/mesh_kit.gd ridge_roof lines 143-168 and gable_end_at; HouseBuilder._half_hip_gables, _build_bargeboards, _gable_frame and _under_rafter. Longhall/none seed 4414, 12x16, height 2.7, one storey: rise=5.440636 and nominal profile offset about 0.299878 m. Cottage 4412 is a second gable case; townhouse 4411 is half-hipped.

IMPLEMENTATION SCOPE
Compute wall closure at the actual wall plane against the shared slab underside, including nonzero roof height at the wall/eave inset. Derive verge-board endpoints, truss limits and half-hip cut intersections from that same surface. Do not simply raise the apex without fixing the whole profile. Check MeshKit.ridge_roof callers in castle, hotel, temple and PropKit; preserve no-end-wall behavior.

ACCEPTANCE CRITERIA
- Gable wall top follows the roof underside across the span, within an explicit numerical join tolerance, for both roof orientations.
- Half-hip gable, truss and boards stop on the same hip-cut boundary; only full gables have apex finials.
- Side-facing ray/section checks detect an intentionally lowered gable; screenshots alone are not the regression test.
- Tests distinguish the measured nominal 0.300 m offset from an exposed air gap after thickness/trim, and assert the actual final mesh.
- Focused cases and relevant castle/hotel/temple/props caller suites pass after shared emitter changes.

HANDOFF / GUARDRAILS
Read AGENTS.md, docs/HOUSE_RULES_EVALUATION.md, and the shared runbook in docs/HOUSE_EXTERIOR_TASKS.md before editing. Symbol names are authoritative; line numbers are September 2026 starting points. Do not conceal profile errors by widening trim. Use actual slab thickness and roof slope; avoid normals regeneration. Record exact commands, seeds, failures, and render paths when closing. Do not mark complete merely because existing HouseQA passes.

HOUSE-EXT-005: Log emitted roof and facade components for exterior QA
------------------------------------------------------
Priority: P1. Estimated effort: 120 minutes. Task ID: `756c6708-85ca-4e38-83c1-f24322b708e9`.
Start at [core/mass_builder.gd](../core/mass_builder.gd), approximately line 18. Prerequisites: HOUSE-EXT-001.

PROBLEM
tag("dormer") and tag("timber") do not record anything when primitives are emitted directly through _kit. Current part_log omits visible roof, dormer and trim geometry, so component QA cannot inspect it.

REPRODUCE / LOCATE
Read MassBuilder.tag/_log_part/box and HouseBuilder._beam, _build_dormers, _build_roof, _build_bargeboards. Townhouse 4411 visibly has dormers and timber but its probe logged_tags contains neither. The roof has only an aggregate mass AABB.

IMPLEMENTATION SCOPE
Add backward-compatible architectural component records or logging wrappers that preserve the actual emitted transform, dimensions/face geometry, role, storey and host identity. Capture geometry at emission, not by reconstructing what the spec should have produced. Use stable component IDs, distinguish main roof from dormers/porch, and reset records on every build. Keep existing part_log/mass_log consumers compatible.

ACCEPTANCE CRITERIA
- Every emitted main-roof face, dormer, verge and opening-adjacent trim piece needed by QA is identifiable and tied to its emitted geometry.
- Repeated builds clear records and produce the same component identities; roof-off builds have no claimed main roof or dormers.
- A fixture moves or removes an emitted component while leaving the original spec unchanged, and geometry-backed QA notices the mismatch.
- Logging alone changes no emitted vertices or furniture; existing MassBuilder and house contracts remain valid.

HANDOFF / GUARDRAILS
Read AGENTS.md, docs/HOUSE_RULES_EVALUATION.md, and the shared runbook in docs/HOUSE_EXTERIOR_TASKS.md before editing. Symbol names are authoritative; line numbers are September 2026 starting points. Do not assert that a tag call is evidence of a placed object. Do not classify a porch or dormer as a second main roof mass. The current vertical-shell check expects exactly one main roof mass for ordinary houses. Record exact commands, seeds, failures, and render paths when closing. Do not mark complete merely because existing HouseQA passes.

HOUSE-EXT-006: Make dormer eligibility and spacing follow roof-local capacity
--------------------------------------------------------------
Priority: P1. Estimated effort: 90 minutes. Task ID: `cea392c2-0f16-4fd2-8f26-f8d52f4803f0`.
Start at [src/house/house_generator.gd](../src/house/house_generator.gd), approximately line 42. Prerequisites: HOUSE-EXT-002.

PROBLEM
Dormer eligibility and count use spec.length even when the roof rotates to follow spec.width. Identical roof geometry turned 90 degrees can therefore get a different nominal capacity. Fixed length/5 count is not a fit check.

REPRODUCE / LOCATE
HouseGenerator lines 42-43 selects dormers using storeys>1 or length>=12 and count=int(length/5); HouseBuilder._build_roof rotates when width>length. Use a controlled spec/roof choice with 14x7 and 7x14 footprints, one and two storeys, same style and pitch. Explicitly enable dormers after generation for capacity tests so an unrelated random false result cannot hide the defect.

IMPLEMENTATION SCOPE
Derive eligibility/capacity from usable roof-local face length and required dormer width/spacing/end margins. Separate the seeded desire for dormers from geometric ability to fit them. Preserve deterministic selection and document any intentional facade preference separately from geometric capacity. This task computes candidates/count; HOUSE-EXT-007 owns actual roof cuts and joined geometry.

ACCEPTANCE CRITERIA
- Rotated equivalent footprints have equal geometric capacity and equivalent placements after transforming coordinates, unless an explicit documented entrance/facade preference changes the chosen side.
- Narrow, short, near-square and hip-end cases produce zero or fewer candidates instead of crowding an edge.
- Count is consistent with accepted candidate footprints, never an arbitrary positive count with no usable host.
- Generation remains reproducible and unrelated furniture randomness does not shift merely because a disabled decoration consumes extra random draws.

HANDOFF / GUARDRAILS
Read AGENTS.md, docs/HOUSE_RULES_EVALUATION.md, and the shared runbook in docs/HOUSE_EXTERIOR_TASKS.md before editing. Symbol names are authoritative; line numbers are September 2026 starting points. Do not merely replace length with max(width,length) and assume hips, spacing and chimney exclusions are solved. Keep placement and emission ownership clear. Record exact commands, seeds, failures, and render paths when closing. Do not mark complete merely because existing HouseQA passes.

HOUSE-EXT-007: Plan dormer openings and join cheeks and rooflets to their host faces
---------------------------------------------------------------------
Priority: P1. Estimated effort: 240 minutes. Task ID: `84dfd92f-218a-4419-b9f0-804228538b07`.
Start at [src/house/house_builder.gd](../src/house/house_builder.gd), approximately line 988. Prerequisites: HOUSE-EXT-002, HOUSE-EXT-003, HOUSE-EXT-004, HOUSE-EXT-005, HOUSE-EXT-006.

PROBLEM
Dormers are boxes at x=-0.52*half_span and y=0.40*rise. They neither cut nor query the main roof, so glazing/cheeks can be buried or unsupported. Correcting hip slabs alone does not make this attachment rule sound.

REPRODUCE / LOCATE
Townhouse/none seed 4411, 9x12, 2.7 m, two storeys has two dormers; farmhouse 4413 also has two. _build_dormers uses dw=.95, dh=1.15, dd=1.25, d_rise=.45 and always the negative roof-local-X face. View the left side as well as the usual right three-quarter shot.

IMPLEMENTATION SCOPE
Record accepted dormers in the plan with face/storey, opening polygon, sill/glazing, cheek profiles and rooflet joins. Fit footprints to the descriptor and avoid ridge, hips, chimney and other dormers. Cut all layers of the host slab (not only its top triangles), emit cheek polygons intersecting that surface, and close the rooflet rear join. Reuse/extend the HousePlan.roof_openings direction in pending INT-018 rather than create an incompatible second roof-hole list; own only the dormer/sloped-polygon subset here, leaving compluvia/oculi to INT-018.

ACCEPTANCE CRITERIA
- Actual host-roof triangles do not cross the dormer opening or glazing; side cheeks meet the host without visible air gaps or unsupported floating bottoms.
- Rooflet and host form a closed external junction with intentional internal opening; no unrelated face passes through the dormer.
- Each rejected candidate has an inspectable reason and accepted count matches the plan, component log and assembled result.
- Mutation fixtures bury the glazing, shift a cheek off the host, put a dormer on a hip edge, and collide it with a chimney; each relevant check fails.
- Gable/half-hip/hip, rotated, low/high pitch and zero/one/multiple-dormer cases pass; roof-off mode removes dormers coherently.

HANDOFF / GUARDRAILS
Read AGENTS.md, docs/HOUSE_RULES_EVALUATION.md, and the shared runbook in docs/HOUSE_EXTERIOR_TASKS.md before editing. Symbol names are authoritative; line numbers are September 2026 starting points. Do not add painted windows on an uncut roof or lower the coverage rule to allow arbitrary holes. Coordinate shared roof_openings schema with INT-018 (9ad843c9-fbf7-4168-b636-b8e1af4397ef); do not claim that broader task complete. Record exact commands, seeds, failures, and render paths when closing. Do not mark complete merely because existing HouseQA passes.

HOUSE-EXT-008: Split timber sill beams at exterior door openings
-------------------------------------------------
Priority: P1. Estimated effort: 90 minutes. Task ID: `ce08c261-7141-43e8-b53f-4d159191f1b5`.
Start at [src/house/house_builder.gd](../src/house/house_builder.gd), approximately line 599. Prerequisites: none.

PROBLEM
The timber sill is emitted over the full wall length at plinth height, crossing the front door. Midrails already have an opening-aware implementation. Plan navigation passes because it does not measure this emitted trim.

REPRODUCE / LOCATE
Cottage/none seed 4412, width 7, length 9, height 2.5, storeys 1. In _build_timber_frame_level, the full-length sill calls _beam before _rail_between is used for the midrail. Cast a segment across the center of plan.doors[plan.entrance()] in its normal direction, at min(plinth_height, WINDOW_SILL-.18)+SILL_BEAM_H/2: Y=0.623870 for this seed; it currently hits SURF_TRIM triangles. Farmhouse 4413 and longhall 4414 also hit; stone-ground-floor townhouse 4411 is a negative control.

IMPLEMENTATION SCOPE
Reuse the opening interval clipping of _rail_between for the sill, considering the sill vertical band and door widths. Ensure windows whose sills are above the beam do not unnecessarily remove it. Cover front and back doors and any supported exterior wall orientation. Add a direct emitted-mesh doorway regression, using the existing house QA suite if the focused exterior harness has not landed.

ACCEPTANCE CRITERIA
- The center and interior-width samples of every tested exterior doorway remain free of sill triangles throughout the sill band; the old uninterrupted beam fails the regression.
- Trim remains on solid wall segments, with correct corner and jamb joins, and does not get deleted across an entire facade.
- Front/back doors, timber/no-timber and stone-ground-floor cases pass, including cottage 4412.
- Rendered cottage entrance is clear; plan/furnishing behavior remains unchanged.

HANDOFF / GUARDRAILS
Read AGENTS.md, docs/HOUSE_RULES_EVALUATION.md, and the shared runbook in docs/HOUSE_EXTERIOR_TASKS.md before editing. Symbol names are authoritative; line numbers are September 2026 starting points. This is an independent small fix and may start immediately. Do not quiet HouseNavCheck or move the door to avoid the beam. Broader decoration keep-out rules belong to HOUSE-EXT-010. Record exact commands, seeds, failures, and render paths when closing. Do not mark complete merely because existing HouseQA passes.

HOUSE-EXT-009: Make house height and footprint bounds include the actual exterior
------------------------------------------------------------------
Priority: P1. Estimated effort: 120 minutes. Task ID: `3cce0258-e051-4727-8eaf-8bd294c7ad44`.
Start at [src/house/house_geometry.gd](../src/house/house_geometry.gd), approximately line 381. Prerequisites: HOUSE-EXT-002, HOUSE-EXT-004, HOUSE-EXT-007.

PROBLEM
HouseGeometry.total_height still uses a capped chimney rise, while _build_chimney now extends above the full ridge. plan_extent assumes the chimney is on +X even though hearth placement can choose any wall; it also omits roof/trim extent.

REPRODUCE / LOCATE
Compare total_height/plan_extent with HouseBuilder._build_chimney (1145), _build_roof and finials. Farmhouse 4413: predicted height 6.333691, mesh top 7.663692. Townhouse 4411: 10.285340 vs 11.615340. Longhall 4414: 8.140636 vs 9.470636. Cottage 4412 has a separate 0.495 m finial-related underestimate. Search all callers, including HouseAssembler.viewing_distance and placement/API consumers.

IMPLEMENTATION SCOPE
Define exact planned exterior bounds using the same geometry/attachment records as emission: slab thickness, ridge caps, finials, dormers, full chimney with crown/pots, porch and overhangs on their actual host wall. Add a plan-aware bounds API where the spec alone lacks placement information, keeping a documented conservative compatibility wrapper if needed. Later props and jetties must extend this same contract.

ACCEPTANCE CRITERIA
- Predicted bounds contain every shell vertex for the four named fixtures and all four chimney wall placements; assert tightness within a documented small tolerance where exact bounds are promised.
- No-chimney, one/two-pot, bargeboard on/off and dormer on/off cases are covered.
- Camera/placement callers use the appropriate plan-aware or documented conservative bounds, not an unexplained padding constant.
- Injected too-short or wrong-wall bounds fail the regression; pure deterministic planning remains intact.

HANDOFF / GUARDRAILS
Read AGENTS.md, docs/HOUSE_RULES_EVALUATION.md, and the shared runbook in docs/HOUSE_EXTERIOR_TASKS.md before editing. Symbol names are authoritative; line numbers are September 2026 starting points. Do not only add 1.33 m: the cottage shows another feature-dependent error. Do not load a model in HouseGeometry to discover dimensions; use planned/measured catalogue data. Record exact commands, seeds, failures, and render paths when closing. Do not mark complete merely because existing HouseQA passes.

HOUSE-EXT-010: Add planned exterior placements and shared facade clearance rules
-----------------------------------------------------------------
Priority: P2. Estimated effort: 180 minutes. Task ID: `050fe5ab-4e19-4d4a-8deb-c30945d71543`.
Start at [src/house/house_plan.gd](../src/house/house_plan.gd), approximately line 37. Prerequisites: HOUSE-EXT-005, HOUSE-EXT-008.

PROBLEM
Houses have interior furniture records but no exterior dressing plan. Uncoordinated shutters, hoods, sill beams, porches and future signs/props can overlap openings and access routes.

REPRODUCE / LOCATE
HouseSpec.exterior_props is line 57 and HouseGenerator sets it true at line 58; rg exterior_props finds no consumer. HouseAssembler.furnish iterates only plan.furniture. Read _opening_trim shutter/hood dimensions, HouseGeometry.door_clear_rect/window_clear_rect and qa/walk_grid.gd.

IMPLEMENTATION SCOPE
Introduce exterior placement records with stable ID, role, host facade/storey or ground region, key, transform, measured footprint, vertical interval and clearance zone. Derive facade exclusion regions from actual opening/trim/shutter extents, door head clearance and porch structure. Keep ground access outside the entrance connected to the site approach using existing WalkGrid. Separate these from interior room furniture so they are not removed or misclassified by interior furnishing rules. Add exterior QA with synthetic measured placements before adding assets.

ACCEPTANCE CRITERIA
- A record outside all interior rooms is valid when it has a valid exterior host, and remains deterministic across rebuilds.
- Mutations putting a barrel in a doorway, a sign below head clearance, a planter over glazing, or two props in the same reserved region fail with role/host/ID diagnostics.
- Shutter/hood clearance includes their full projected dimensions and vertical ranges; nearby unrelated details are not falsely rejected.
- A synthetic decorated house has a continuous clear approach to its entrance using WalkGrid; no second navigation rasterizer is introduced.
- No models are loaded in the planner/builder/QA path; existing interior furniture counts and compromise warnings remain meaningful.

HANDOFF / GUARDRAILS
Read AGENTS.md, docs/HOUSE_RULES_EVALUATION.md, and the shared runbook in docs/HOUSE_EXTERIOR_TASKS.md before editing. Symbol names are authoritative; line numbers are September 2026 starting points. Exterior_props false may legitimately leave shell vertices unchanged; its eventual contract is no exterior placements/instances, not a requirement to change the shell mesh. Do not store decorations in arbitrary room -1 furniture without auditing every consumer. Record exact commands, seeds, failures, and render paths when closing. Do not mark complete merely because existing HouseQA passes.

HOUSE-EXT-011: Dress house exteriors with owned props and style/trade recipes
--------------------------------------------------------------
Priority: P2. Estimated effort: 210 minutes. Task ID: `4219c932-ac6a-48d7-892b-3a80526f3e4e`.
Start at [src/house/house_assembler.gd](../src/house/house_assembler.gd), approximately line 59. Prerequisites: HOUSE-EXT-010.

PROBLEM
exterior_props is currently inert and all houses lack the intended barrels/firewood/trade signs. The visual target is a few functional groups, not random clutter across every wall.

REPRODUCE / LOCATE
Use cottage 4412, farmhouse 4413, townhouse 4411 and longhall 4414, then add farmer/smith/alchemist trade cases. Search the owned library with the waterfree-assets skill; prior searches found barrel in Kenney food-kit, sign and flowers in Kenney nature-kit. These are candidates, not confirmed project-catalogue entries.

IMPLEMENTATION SCOPE
Select a small visually consistent set of existing project or owned-library models; confirm catalogue keys and measured bounds. Add deterministic recipes: cottage entrance/bench/planter/storage, farmer service barrels/tools, townhouse or smith trade sign/light, alchemist herb/pot work group, longhall entrance/hearth-end storage. Fit groups through HOUSE-EXT-010 clearance rules. Instantiate only in HouseAssembler, including existing LightKit behavior for lights. Prefer a compact generic fallback with a recorded reason if an optional recipe item cannot fit. Extend plan-aware bounds for accepted props.

ACCEPTANCE CRITERIA
- Toggle exterior_props false/true on equivalent generation inputs: false yields zero exterior records/instances, true yields fitted dressing on suitable fixtures; interior furniture and shell structure do not depend on prop loading.
- Every accepted record creates the intended instance with catalogue orientation, scale and floor/wall offset; missing mandatory keys fail clearly instead of disappearing silently.
- Catalogue is remeasured after changes in assets/props; assets suite passes. Asset source and applicable licence are recorded without publishing licensed source files to a public location.
- Side-by-side roof-on views show distinguishable, coherent style/trade groups and clear entrances/windows, including small houses where items must be omitted.
- Repeated seeds reproduce placement IDs/transforms and exterior access QA passes.

HANDOFF / GUARDRAILS
Read AGENTS.md, docs/HOUSE_RULES_EVALUATION.md, and the shared runbook in docs/HOUSE_EXTERIOR_TASKS.md before editing. Symbol names are authoritative; line numbers are September 2026 starting points. Do not source or buy new art before searching the owned library. Do not add models to HouseBuilder. A recipe target of one entrance accent and one/two support groups is an art-direction starting point, not an unconditional count assertion. Record exact commands, seeds, failures, and render paths when closing. Do not mark complete merely because existing HouseQA passes.

HOUSE-EXT-012: Represent a real upper-storey jetty in the house plan
-----------------------------------------------------
Priority: P2. Estimated effort: 240 minutes. Task ID: `4744e5b4-112d-401e-a187-8ae47e6001cb`.
Start at [src/house/house_planner.gd](../src/house/house_planner.gd), approximately line 842. Prerequisites: HOUSE-EXT-002.

PROBLEM
spec.jetty adds facade brackets but the upper rooms/walls repeat the ground footprint. A real cantilever cannot be fixed only in mesh emission, because rooms, windows, floor slabs and circulation must agree.

REPRODUCE / LOCATE
Townhouse/none 4411, 9x12, height 2.7, two storeys. Read HouseBuilder._build_jetty (230), HouseGeometry.shell_runs/interior_rect/room_floor_rect and HousePlanner._clone_upper_storeys (842). Current jetty_depth is 0.24-0.32 m and decoration is at the front (-Z).

IMPLEMENTATION SCOPE
Add per-storey footprint support for a single front jetty, keeping ground dimensions as the user-requested footprint. State whether every level above ground shares the same overhang (recommended initial scope), rather than accumulating depth. Update room allocation, exterior classification, door/window positions, stair landings and interior furnishing geometry to use the correct storey envelope. Preserve unjettied houses and cellar levels. Hand a documented footprint API to HOUSE-EXT-013 for emission.

ACCEPTANCE CRITERIA
- With jetty enabled, upper planned exterior front is exactly jetty_depth outside the ground front, while ground and cellar footprints remain unchanged.
- Upper rooms tile their own footprint and windows/doors are on that storey surface; clear floor uses the same geometry.
- Stair landings and routes remain reachable for two/three-storey cases, without weakening room-area, daylight, privacy or furnishing checks.
- Unjettied fixtures preserve equivalent plans. New planner tests pass and the existing hmultistory suite is run with all failures recorded.
- Document representation/API changes and ensure serializer/addon manifest compatibility if affected.

HANDOFF / GUARDRAILS
Read AGENTS.md, docs/HOUSE_RULES_EVALUATION.md, and the shared runbook in docs/HOUSE_EXTERIOR_TASKS.md before editing. Symbol names are authoritative; line numbers are September 2026 starting points. This task owns planned geometry only; HOUSE-EXT-013 completes the visible feature. Do not silently clamp requested building width/length or confuse four-storey shared QA limits with the house generator cap of three. Record exact commands, seeds, failures, and render paths when closing. Do not mark complete merely because existing HouseQA passes.

HOUSE-EXT-013: Emit jettied floors, walls, openings and roof on the planned footprint
----------------------------------------------------------------------
Priority: P2. Estimated effort: 180 minutes. Task ID: `f9fc6b77-d03c-42f5-ad42-9666dc606a14`.
Start at [src/house/house_builder.gd](../src/house/house_builder.gd), approximately line 210. Prerequisites: HOUSE-EXT-004, HOUSE-EXT-007, HOUSE-EXT-009, HOUSE-EXT-012.

PROBLEM
Current _build_jetty emits joist ends and brackets supporting no projecting floor. Once HOUSE-EXT-012 supplies real storey footprints, every upper shell attachment must follow them.

REPRODUCE / LOCATE
Townhouse 4411 is the visual baseline. Audit _build_floor, _build_exterior_walls, _build_jetty, _build_timber_frame_level, _build_plinth, _build_roof and _build_chimney. Some decoration loops still use HouseGeometry.exterior_runs(spec), bypassing storey shape.

IMPLEMENTATION SCOPE
Emit each upper floor/wall/framing band from the planned storey runs, position openings on those surfaces and size the main roof over the highest storey. Align bressummer, joists and brackets beneath the actual cantilever and record their actual geometry. Resolve the ground-supported chimney intersection with projecting storeys explicitly so the flue does not pass through upper windows or float away from its hearth. Update bounds and component hosts.

ACCEPTANCE CRITERIA
- Upper mesh front matches the planned offset, with a real continuous floor above the brackets; no unsupported trim-only jetty remains.
- Main roof overhang is measured from the top-storey wall, including when ridge axis is rotated; dormers still fit their host.
- Chimney, porch, upper openings and framing do not conflict with the new facade; mutations shifting a wall/roof back to the old rectangle are detected.
- Two/three-storey, stone-ground-floor, cellar and jetty-off fixtures pass relevant house/multistory QA; front and side renders clearly show the overhang.
- Final mesh/prop bounds include the projection and assembly remains deterministic.

HANDOFF / GUARDRAILS
Read AGENTS.md, docs/HOUSE_RULES_EVALUATION.md, and the shared runbook in docs/HOUSE_EXTERIOR_TASKS.md before editing. Symbol names are authoritative; line numbers are September 2026 starting points. Do not move only the facade mesh while the plan stays rectangular. Courtyard/polygon hosts need explicit supported behavior; do not accidentally apply a rectangular jetty to unrelated building families. Record exact commands, seeds, failures, and render paths when closing. Do not mark complete merely because existing HouseQA passes.

HOUSE-EXT-014: Give house roofing and glazing distinct material treatment and valid UVs
------------------------------------------------------------------------
Priority: P2. Estimated effort: 180 minutes. Task ID: `e32a95aa-c672-499d-a44d-4d68a331c410`.
Start at [core/shell_assembler.gd](../core/shell_assembler.gd), approximately line 32. Prerequisites: HOUSE-EXT-003, HOUSE-EXT-004, HOUSE-EXT-007.

PROBLEM
House shell materials are four flat colors; window panes use SURF_ROOF. Roof courses/texture cannot be added reliably to polygon slabs because MeshKit._tri sets every vertex UV to (0.5,0.5).

REPRODUCE / LOCATE
Read HouseBuilder surface constants and _opening_trim (414-418), _build_dormers glazing, core/mesh_kit.gd _tri/_quad and slab_poly, ShellAssembler.surface_materials and src/api/building_family_adapter.gd colours. HouseSuite currently asserts exactly four surfaces. The shared assembler is used by other building families.

IMPLEMENTATION SCOPE
Choose an explicit backward-compatible house material strategy: roof material choice with readable scale/course direction, and glazing visually distinct from roof. Provide meaningful face-local UVs or another deliberate mapping for sloped polygons; keep detail scale consistent across different roof dimensions. Restrict material changes to intended house surfaces or carefully update shared surface contracts and tests if an additional glazing surface is required. Use the owned-asset skill before selecting textures; procedural material treatment is also acceptable.

ACCEPTANCE CRITERIA
- Roof course/detail scale and direction are coherent on gable, hip, half-hip and dormer faces, including rotated footprints; no stretched single-pixel UVs.
- Window/dormer glazing does not change color or acquire roofing texture when roof material changes.
- Deterministic material selection is represented in the spec/plan, with restrained visual variation and readable roof edges in fixed-camera renders.
- Surface count/material mapping, cutaway behavior and exported/addon assembly tests are updated to the intentional contract; unrelated family appearance remains compatible.

HANDOFF / GUARDRAILS
Read AGENTS.md, docs/HOUSE_RULES_EVALUATION.md, and the shared runbook in docs/HOUSE_EXTERIOR_TASKS.md before editing. Symbol names are authoritative; line numbers are September 2026 starting points. Do not change only one color array and leave HouseSuite, BuildingFamilyAdapter or cutaway surface indices stale. Do not apply global texturing to every MeshKit triangle as a shortcut. Record exact commands, seeds, failures, and render paths when closing. Do not mark complete merely because existing HouseQA passes.

HOUSE-EXT-015: Tune roof proportions and facade decoration rhythm by house archetype
---------------------------------------------------------------------
Priority: P2. Estimated effort: 180 minutes. Task ID: `ac9d0f8f-4cb7-4b45-a836-482c5e607a2d`.
Start at [src/house/house_spec.gd](../src/house/house_spec.gd), approximately line 80. Prerequisites: HOUSE-EXT-004, HOUSE-EXT-007, HOUSE-EXT-011, HOUSE-EXT-013, HOUSE-EXT-014.

PROBLEM
Roofs can dominate the entire house and facade ornament is selected independently of window bays and entrance hierarchy. Longhall 4414 has a 5.440636 m roof rise over 2.7 m walls; that is an art-direction concern, not automatically a structural failure.

REPRODUCE / LOCATE
Review all five HouseSpec.STYLES, HouseGeometry.roof_rise, HouseGenerator framing/dormer choices and HouseBuilder._build_timber_frame_level. Use the four named fixtures plus witch_hut and all canonical HouseSweep sizes; compare at the same camera, light and scale.

IMPLEMENTATION SCOPE
Establish documented per-style proportion targets and deliberate exceptions. Adjust derived roof rise/pitch behavior without changing locked user width/length/height. Derive facade bay/trim rhythm from openings and the entrance, with purposeful clusters instead of adding repeated ornaments everywhere. Keep intentionally steep witch-hut/longhall character where the evidence supports it. Record before/after decisions and ensure changes do not invalidate attachment fits.

ACCEPTANCE CRITERIA
- A fixed-seed comparison sheet covers five styles, small/large footprints and one/multiple storeys, with numeric roof-to-wall ratios alongside images.
- Each style has a stated silhouette/material/decorative intent and visually coherent entrance/window rhythm; improvements are supported by renders rather than a count of new details.
- Any proportion thresholds are labelled art-direction targets; valid steep archetypes are not globally capped to a generic cottage silhouette.
- All new geometry, attachment, opening and access checks pass after tuning; locked inputs and determinism remain valid.

HANDOFF / GUARDRAILS
Read AGENTS.md, docs/HOUSE_RULES_EVALUATION.md, and the shared runbook in docs/HOUSE_EXTERIOR_TASKS.md before editing. Symbol names are authoritative; line numbers are September 2026 starting points. Do not use decorations to conceal geometry defects. Keep aesthetic review separate from hard geometric checks, and document uncertainty instead of inventing universal architectural rules. Record exact commands, seeds, failures, and render paths when closing. Do not mark complete merely because existing HouseQA passes.

HOUSE-EXT-016: Integrate exterior QA and close the house roof/decor regression matrix
----------------------------------------------------------------------
Priority: P1. Estimated effort: 180 minutes. Task ID: `092af343-a558-49aa-be1e-1ee2d78541ba`.
Start at [qa/house_qa.gd](../qa/house_qa.gd), approximately line 21. Prerequisites: HOUSE-EXT-003, HOUSE-EXT-004, HOUSE-EXT-005, HOUSE-EXT-007, HOUSE-EXT-008, HOUSE-EXT-009, HOUSE-EXT-011, HOUSE-EXT-013, HOUSE-EXT-014, HOUSE-EXT-015.

PROBLEM
Runtime HouseQA and the current roof suite accept lateral gaps, crossed slabs, buried dormers and doorway trim. Fixes need durable detection across the building pipeline, not just repaired screenshots.

REPRODUCE / LOCATE
Baseline: farmhouse 4413, townhouse 4411, cottage 4412, longhall 4414 all pass runtime HouseQA. _roof_cover counts any projected triangle; _roof_reach only inspects high roof-surface vertices. The broad previous run completed only house, then was stopped during houseqa; no clean full-suite baseline was established.

IMPLEMENTATION SCOPE
Compose the incremental exterior rules into runtime/focused QA, with diagnostics naming seed, style, component, host/storey, measured value and tolerance. Check envelope closure, unrelated face conflicts, roof-to-wall/trim contact, dormer joins/openings, facade/prop clearance and actual bounds. Add a compact deterministic pairwise matrix across roof types, orientation, near-square/extreme supported footprints, pitches, storeys, jetty, dormer, chimney and props. Preserve intentional courtyard/roof openings. Run relevant suites and final roof-on renders.

ACCEPTANCE CRITERIA
- Each new rule has a negative mutation fixture that breaks emitted geometry or placement while leaving the expected specification unchanged; corresponding normal fixtures pass.
- The original farm roof defect cannot pass solely because coverage is 1.0. Shared edges/caps and intentional roof/court openings are not false positives.
- Final named fixtures and matrix pass with no unexplained exterior failures; preserve existing furnishing-compromise warnings and report unrelated baseline failures separately.
- Run house, assets, houseqa, hmultistory, harchetype, court, plus affected MeshKit caller suites and addon tests. Record exact commands, counts and failures; do not say ALL PASS if a run is stopped.
- Regenerate front/back/both-side/elevated views and update docs/HOUSE_RULES_EVALUATION.md with resolved task IDs and evidence.

HANDOFF / GUARDRAILS
Read AGENTS.md, docs/HOUSE_RULES_EVALUATION.md, and the shared runbook in docs/HOUSE_EXTERIOR_TASKS.md before editing. Symbol names are authoritative; line numbers are September 2026 starting points. Do not postpone every regression test to this integration task: each implementation task owns its focused test. Do not use whole-mesh watertightness as a naive rule when doors/windows/cutaways are intentionally open. Record exact commands, seeds, failures, and render paths when closing. Do not mark complete merely because existing HouseQA passes.
