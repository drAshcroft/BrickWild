House building-rule evaluation — 8 September 2026
================================================

**September 2026 completion:** See [house exterior completion](HOUSE_EXTERIOR_COMPLETION.md)
for the real storey-footprint jetty, measured dressing/clearances, independent
glazing and roof courses, style comparison matrix and composed runtime
envelope QA. The original findings below are preserved as the reproduction
baseline, not a description of the repaired renderer.

`HOUSE-EXT-010`/`011` resolve planned exterior placement and measured dressing;
`012`/`013` implement the usable upper floor and its emitted jetty;
`014` separates glazing from metre-scale roofing; `015` records the five-style
art direction. `016` composes independent emitted-geometry checks and the
pairwise regression matrix. Exact counts, warning context, stopped-run
limitations and the final integration evidence are in the completion report.

**Implementation update (9 September 2026):** Roof topology, wall joins, dormer cuts and door-crossing trim have been repaired, and exterior prop placement now works. See [repair details and validation](HOUSE_ROOF_FIX.md). The findings below preserve the original evaluation, not the current implementation status.

The roof complaint is supported by reproducible geometry defects. The decoration complaint is partly an implementation gap: exterior props are enabled in the specification but are never placed. The existing rules are much stronger for interior planning and circulation than for the exterior envelope and architectural composition.

This evaluation changes no production code. It combines source inspection, six shell variants rendered from four angles each, and targeted mesh/QA probes. The sixth render explicitly forces a hipped roof; the main failing example below is a naturally generated farmhouse.

Implementation backlog: [16 detailed house exterior tasks](HOUSE_EXTERIOR_TASKS.md), also stored in waterfree as `HOUSE-EXT-001` through `HOUSE-EXT-016`. Each task includes reproduction inputs, code entry points, dependencies, acceptance criteria and handoff rules.

**Findings, in recommended repair order**

| Priority | Finding and evidence | Rule that should replace the current behavior |
|---|---|---|
| 1 — geometry defect | **Hipped roofs are intersecting slabs with open sides.** `MeshKit.hip_roof_at` emits short rectangular side slopes and full-width rectangular end slopes. Those end slopes rise to the center instead of meeting the ends of the ridge. Farmhouse seed **4413**, 10 × 13 m, one 2.7 m storey, visibly reproduces this. [Emitter](../core/mesh_kit.gd), lines 279–306. | Derive ridge endpoints, four eaves, and hip edges once. Emit two trapezoidal side faces and two triangular end faces sharing those edges. Handle near-square plans explicitly. Validate the actual enclosed envelope and intersections. |
| 2 — placement defect | **Dormers do not fit their host roof.** `_build_dormers` always places fixed 0.95 × 1.25 m boxes on the negative local-X slope, at `x = -0.52 × half_span`, `y = 0.40 × rise`. It never queries the host face or cuts the main roof. On farmhouse 4413, dormers are swallowed by the overlapping hip slabs. Townhouse 4411 shows the separate box construction. [Builder](../src/house/house_builder.gd), lines 988–1017. | Choose a valid host face, derive the sill and cheek intersections from that face, reserve an opening, and join the rooflet to the main roof. Keep dormers clear of hips, ridge, chimney, and one another. Reject placements with buried glazing or unsupported cheeks. |
| 3 — envelope mismatch | **Gable walls and verge boards use different slope definitions from the roof.** Roof slabs use `span + 0.7`; boards use `span`. Gable-wall apex height is reduced to `rise × wall_half / roof_half`, although the roof still reaches the full rise at the center. The gable profile is therefore shifted downward relative to the nominal roof plane. Longhall 4414 has a **0.300 m nominal offset**, before slab thickness and trim obscure some of it. [MeshKit](../core/mesh_kit.gd), lines 143–168; [builder](../src/house/house_builder.gd), lines 931–972. | Derive wall closure, truss limits, bargeboards, and eave positions from the same roof surface, accounting for slab thickness. Do not independently rescale the apex. Use side-facing envelope checks as well as overhead coverage. |
| 4 — decoration collision | **Timber sill beams cross door openings.** `_build_timber_frame_level` emits the sill across the full wall, raised to plinth height. The cottage 4412 front render shows a horizontal bar crossing the doorway. Midrails already use `_rail_between`, which cuts around openings; sills do not. [Builder](../src/house/house_builder.gd), lines 599–608 and 699–719. | Every facade element must respect the full opening volume. Split sills at doors; reserve space for shutters, hoods, porch attachments, and signs. Test emitted trim, not only the plan's opening records. |
| 5 — missing feature | **Exterior dressing is unimplemented.** `exterior_props` is declared and set to true, with no consumer. The assembler only instantiates `plan.furniture`. Toggling the flag leaves all shell vertex arrays identical in all four probe cases, and every builder has an empty `prop_log`. [Spec](../src/house/house_spec.gd), line 57; [generator](../src/house/house_generator.gd), line 58; [assembler](../src/house/house_assembler.gd), lines 59–69. | Plan exterior placements explicitly with a host, position, measured footprint, and clearance zone. Let the assembler instantiate them. Give each style/trade a small dressing recipe, then validate access and attachment. |
| 6 — misleading feature | **Jetties decorate a wall that never projects.** The jetty routine adds a front beam, joist ends, and brackets. Upper walls still use the same footprint as the ground floor. The townhouse 4411 render shows this mismatch. [Builder](../src/house/house_builder.gd), lines 210–260. | Either implement a real upper-storey footprint with matching floors, walls, windows, and roof, or describe this feature as brackets. A jetty's supports should carry the projecting storey. |
| 7 — art-direction gap | **Roof scale and surface detail are weakly controlled.** Rise depends only on short span and style pitch. Longhall 4414 has a 5.441 m roof rise over 2.7 m walls, so the roof dominates the silhouette. All roof variants use a single solid material color; window panes share the roof surface/material. [Geometry](../src/house/house_geometry.gd), `roof_rise`; [materials](../core/shell_assembler.gd), lines 32–45; [builder](../src/house/house_builder.gd), lines 414–418. | Review roof-to-wall proportions per archetype; preserve intentionally steep roofs where appropriate. Add a roof material choice with readable courses, edge thickness, and restrained variation. Give glazing its own treatment. Establish facade bays before placing decorative accents. |

**Visual evidence**

Naturally generated farmhouse, seed 4413: open roof sides and intersecting slabs. This is not the forced-hip diagnostic case.

![Farmhouse roof defect](../artifacts/house_rules_eval/roof_farm_three_quarter.jpg)

Townhouse, seed 4411: dormers, flat roof treatment, and jetty brackets beneath an unshifted upper wall.

![Townhouse exterior](../artifacts/house_rules_eval/roof_town_left.jpg)

Cottage, seed 4412: the sill crosses the entrance below the porch canopy.

![Cottage entrance](../artifacts/house_rules_eval/roof_cottage_gable.jpg)

**Why existing QA accepts these houses**

The runtime `HouseQA` shell checks mostly inspect structural AABBs, storey elevations, and opening records. Roof coverage and reach are separate suite helpers. Neither path checks hip topology, dormer fit, verge alignment, or facade-detail interference.

The coverage helper projects triangles onto the footprint and accepts any covering triangle above the wall band, across all mesh surfaces. It cannot distinguish an intact roof from crossed slabs, lateral holes, or duplicate roof layers. The reach helper checks only roof-material vertices above half the rise; it does not measure trim alignment or roof-to-wall closure.

Most roof and trim primitives are emitted directly through `_kit`, bypassing `MassBuilder` part logging. Calling `tag("dormer")` does not log the subsequent direct kit calls. The probes contain visible dormers and timber but no corresponding logged tags. That prevents meaningful component checks using the existing logs alone.

| Naturally generated probe | Runtime HouseQA | Projected roof coverage | Exterior-props toggle |
|---|---|---|---|
| Farmhouse 4413, 10 × 13 m, 1 storey | Pass; one daylight warning | 100% despite visibly broken roof | Identical geometry |
| Townhouse 4411, 9 × 12 m, 2 storeys | Pass; two programme warnings | 100% | Identical geometry |
| Longhall 4414, 12 × 16 m, 1 storey | Pass; no warnings | 100% | Identical geometry |
| Cottage 4412, 7 x 9 m, 1 storey | Pass; one programme warning | 100% | Identical geometry |

A direct segment test through the center of the cottage entrance at Y = 0.624 m intersects the emitted trim mesh, confirming the sill obstruction independently of the screenshot. The farmhouse and longhall also have positive entrance-trim hits at their sill heights; the stone-ground-floor townhouse does not.

The programme warnings should remain: they report furnishing compromises rather than exterior defects.

Two additional consistency issues deserve follow-up. Dormer eligibility/count uses world-space `spec.length`, while the roof rotates to follow the longer dimension; rotating an equivalent footprint can change dormer capacity. `HouseGeometry.total_height` also retains an old capped chimney formula: in the farmhouse, townhouse, and longhall probes it underestimates actual mesh height by **1.33 m**. Geometry, attachment, and presentation bounds should share the same dimensions.

**Decoration rules worth adding**

Use a deliberate order: facade bays and entrance, roof and chimney, major architectural trim, then small prop groups. A starting art-direction target is one identifiable entrance feature and one or two functional exterior groups, scaled to available wall space. Treat that as a visual target, not a universal hard count.

| House identity | Suggested dressing | Placement rule |
|---|---|---|
| Cottage | Small planter or flowers, a bench, firewood | Keep the entrance dominant; place storage against a usable wall without obstructing a window or path. |
| Farmhouse/farmer | Barrels, crates, tools | Group near the work/service entrance; leave the main approach clear. |
| Townhouse/shop trade | Trade sign, entrance light, restrained window accents | Attach to facade bays and preserve head clearance and shutter space. |
| Longhall | Strong entrance framing, firewood/storage group | Concentrate detail at the entrance and hearth end; avoid repeating small ornaments across every bay. |
| Witch hut/alchemist | Pots, herbs, asymmetric work cluster | Let asymmetry follow a functional work area; keep roof joints and access structurally sound. |

The owned-asset search found Godot-compatible barrel, sign, and flower models, including Kenney food-kit and nature-kit subjects. These are library candidates, not verified additions to this project's measured prop catalogue. Select a consistent visual set, import only what is needed, and remeasure the catalogue before placement work. New purchases are not needed to begin this pass.

**Implementation sequence and acceptance criteria**

1. Create a shared roof description in `HouseGeometry`: local orientation, eaves, ridge, face polygons, surface-height queries, and actual bounds. Fix hipped faces and gable closure first. Preserve the existing pure plan-to-builder contract.
2. Record and fit dormers and other attachments against those faces. Split doorway sills. Log emitted architectural parts so QA can inspect them.
3. Add exterior placements to the plan, with measured footprints and doorway/window/route clearances. Keep model loading in `HouseAssembler` and reuse `WalkGrid` for access checks.
4. Tune archetype proportions, facade rhythm, and material treatment with fixed-seed views. Implement real jetties separately because their footprint affects plans and circulation.
5. Add targeted regression cases for 4413/4411/4412/4414, every roof type, rotated and near-square footprints, extreme supported sizes, and dormer/chimney combinations. Check side closure, host contact, conflicting faces, unoccluded openings, and exterior access. Deliberately break one condition in each check's fixture to prove it detects the defect.

Render reproduction: run Godot without `--headless`, using `--path . --script res://artifacts/eval_house_rules.gd`. Probe reproduction: `--headless --path . --script res://artifacts/probe_house_rules.gd`. The scripts, [24 render images](../artifacts/house_rules_eval), and [probe measurements](../artifacts/house_rules_eval/probe.json) are local ignored artifacts. The assessment itself is versioned here.

**Validation status:** The basic `house` suite completed with no reported failures or warnings (123 checks by its sweep definition). The broader run was stopped during `houseqa` after narrowing this evaluation to exterior defects; `houseqa`, `hmultistory`, and `harchetype` do not have completed suite results from this run. All four targeted runtime HouseQA probes passed, all 24 renders completed, and the probe/render error logs are empty. No full-suite pass is claimed. Production scripts and assets are unchanged.

