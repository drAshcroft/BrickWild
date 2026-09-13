# INT-007 completion and validation

Status: **complete**, 2026-09-13. Live task:
`168997fe-d387-43df-a46d-9bdbe8dd5cd0`.

Existing eligible hall, keep, chapel and bailey-shop HousePlans now emit real
stone shells. CastleQA groups HouseQA by building and verifies the physical
gate-to-keep route, then the keep's navigation and stairs to the lord's chamber.
Stone walls are at least 0.6 m thick and have no half-timber framing.
Top-level castle mass contracts remain intact.

Corrections also cover polygon and tiered floors, real stair openings,
courtyard windows, opening transforms and glazing materials, occupied keep
heights, rotated furniture/access bounds, measured model pivots, bed headboard
orientation, polygon lamp pairs, stable facing and workshop daylight.
See [architecture and eligibility](../CASTLE_INTERIORS.md).

## Required castle suites

All five required suites passed: **704 checks, zero failures**. Warning counts
are occurrences within each suite and overlap between suites; they are not a
count of independent defects.

| Suite | Checks | Failures | Warnings | Log in `artifacts/` |
| --- | ---: | ---: | ---: | --- |
| castle | 344 | 0 | 182 | `int007_castle_normals_final.log` |
| cnormals | 84 | 0 | 169 | `int007_cnormals_split.log` |
| cmassing | 100 | 0 | 0 | `int007_massing_landmarks.log` |
| clandmark | 92 | 0 | 0 | `int007_massing_landmarks.log` |
| cvoxelqa | 84 | 0 | 204 | `castle_voxel_final.log` |

All associated stderr files are empty. The complete CastleSuite report was
written before its process was stopped at the following normals boundary:
normals had been started separately to overlap the remaining programme checks.
Only two small house traces were duplicated. The separately completed normals
run exited 0. CastleSuite's 344 checks are counted from its source; the complete
report contains zero failures. Evidence: `artifacts/int007_suite_split.txt`,
`artifacts/int007_split_summary.json`, and
`artifacts/int007_cnormals_split.exit.txt`.

Castle programme coverage includes 76 eligible halls (59 with two trestle
rows), 31 keeps and 26 chapels across the canonical 84-case grid. Landmark
feature gaps already listed in the suite's EXPECTED_FAIL remain documented;
their probe messages are not new failing suite assertions.

The five suite elapsed times were 2827.57, 915.74, 1798.30, 993.34 and 1949.20
seconds respectively. Most ran concurrently; these are not isolated production
generation benchmarks.

## Focused verification

All entries below passed with zero failures.

| Log in `artifacts/` | Checks | Coverage / warnings |
| --- | ---: | --- |
| `int007_integration_final.log` | 992 | Plan shells 903, aperture 16, castle shops 21, polygon sconces 15, polygon 28, roof probe 9; no warnings |
| `int007_shared_regressions.log` | 371 | Stone 89, multistory 210, shops 20, shop archetypes 52; 6 furnishing warnings |
| `int007_assets_final.log` | 488 | Measured model catalogue; 31 recorded origin warnings handled by assembly |
| `house_assembly.log` | 59 | Actual imported pivots, rotations, scaled upper-floor support, mounted-wall contact, light anchors, bed headboards and exterior-origin preservation; no warnings |
| `keep_furnishing_regression.log` | 55 | Five formerly bedless keeps each have a bed and no HouseQA failures; 9 furnishing warnings |
| `rotated_furnishing_bounds.log` | 15 | Rotated footprint/access bounds and wrong-size/polygon-overhang negatives |
| `int007_openings_final.log` | 182 | Aperture 16, range plans 76, earlier walk 90; 13 chapel seating/focus warnings |
| `castle_voxel_final.log` + `castle_connected_run.log` | 100 | Current walk controls: 97 in the main run, plus 3 connected-mass controls; no warnings |

Earlier independent controls proved stable focus and reversed-stall rejection
(`stable_regression3.log`, 8), full keep occupied height
(`keep_occupied_height.log`, 9), and identical complete plan/spec/RNG output
after furnishing loop hoisting (`free_furnisher_comparison.log`, 4 fixtures).
Raw model assets and catalogue measurements did not change.

## Render review

`artifacts/int007_renders_assembled.log` completed all nine images with no
stderr:
`artifacts/renders/castle_{square,round,tiered}_{roof_on,roof_off,lords_chamber}.png`.

These are the final references, including pivot and headboard corrections.
Root reviewed the latest three chamber images and the square roof-on view;
roof-on/off views also received independent visual review. Square, round and
tiered scenes contain 38, 37 and 38 actual lights. Measured tests cover stair
clearance hidden by walls in some render angles.

## Remaining tasks

- Hotel dormer attachment: `ROOF-AUDIT-001`,
  `ce7a0f3b-a089-47f0-ba09-fc263c3abdbd`; exact four-fixture reproduction and
  measured air gaps are in [the roof audit](../ROOF_AUDIT.md).
- Ridge castles, tower houses and motte shell keeps need dedicated plans.
  Existing valid plans are covered by INT-007; these specialised forms, plus
  wings/annexes without a HousePlan, are described in
  [the form and polygon follow-ups](../CASTLE_INTERIOR_FOLLOWUPS.md).
- Remaining secondary polygon affinity:
  `c658d3e0-66b8-45f1-846d-b4102caf02d8`; preserve the completed actual-facet
  lamp pairing and rotated physical-bound corrections.
- Performance: `e27c4eb9-e799-49b4-bfa2-b64e8c4866d6`;
  [phase-profiling task](castle_interior_performance.json).
- Interior warning triage: `8e41759c-ef3f-4b57-9910-3c32078f25de`;
  [task record](castle_interior_warning_triage.json).
- Normals warning triage: `f3e66523-0e0a-4655-89f4-3898f13a01fa`;
  [task record](castle_normals_warning_triage.json).

[The warning handoff](../CASTLE_INTERIOR_WARNINGS.md) gives exact fixtures and
source branches for the 204 voxel-QA warnings and 169 normals warnings. The
former include explicit cabinet fallbacks, generic seating rules applied to
chapel pews, measured stable floor pockets and secondary placement preferences.
The latter include degenerate roof triangles and outside-opening probes
against mass AABBs. A warning's presence alone does not establish the right
fix; the follow-ups require physical evidence and preserve meaningful checks.

The todo graph validates cleanly, and `git diff --check` reports no whitespace
errors. No commit was requested. Superseded diagnostic logs and the stopped
optional LibrarySuite run are not used as final proof.

