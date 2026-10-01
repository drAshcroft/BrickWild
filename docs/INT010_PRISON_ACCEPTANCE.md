# INT-010 Prison Acceptance

## Scope

Prepared in `artifacts/int010_reconcile_worktree`, based on the corrected INT-009 reconciliation clone. The change adds a prison business with a front guardroom, three or more locked ground-floor cells, a lower sealed oubliette, and a closed trapdoor panel. Cell cages use the measured `Cage_Small` model. Existing INT-008 hearth handling and INT-009 library daylight/stack fixes are retained.

The source was then integrated into main after INT-009. The main runner keeps
the bounded QA selectors for castle, houses, barracks and library.

## Checks

| Command | Native exit | Result |
|---|---:|---|
| Editor registration (`--headless --editor --quit`) | 0 | No script parse errors |
| `prison` | 0 | 1 suite, 7 checks, 0 failures, 13 warnings |
| `sarchetype` | 0 | 1 suite, 62 checks, 0 failures, 15 warnings |
| `lane:plan` | 0 | 3 suites, 386 checks, 0 failures, 1 warning |
| `lane:dress` | 0 | 4 suites, 1,170 checks, 0 failures, 32 warnings |
| Non-headless render | 0 | Three PNGs written and visually inspected |

Main editor registration passed with native exit 0. Main `prison` passed
through `tools/run_qa_lane.ps1` with native exit 0 in 224.95 seconds:
7 checks, 0 failures, 13 warnings. The wrapper result and logs are under
`artifacts/qa_fast/prison/20260930_174053/`. The broader plan, dress and
shop archetype results in the table above are from the prepared clone.

The prison suite exercises 70%, 100%, and 140% archetypes plus negative controls for an unlocked cell, missing hatch, unsealed oubliette, and missing cell cage. The output confirms lower room index 31 is an `oubliette`, marked sealed, with trapdoor rectangle at `(-3.973334, -4.611848)` and size `0.7 x 0.7m`.

Warnings are non-failing furnishing/nav advisories: store-room density, small disconnected floor regions, and one guardroom daylight ratio at 140%. The archetype lane also reports inherited library free-standing shelf warnings and existing unrelated archetype warnings. No acceptance rule was weakened to silence them.

## Render review

- `artifacts/int010/prison_assembled.png`: timber hall exterior is coherent.
- `artifacts/int010/prison_cutaway.png`: repeated cell partitions, circulation aisle, cages, and front guardroom are visible.
- `artifacts/int010/prison_oubliette_hatch.png`: close view shows the cages, guard station, and closed blue trapdoor panel at the reserved hatch position. The sealed lower room is verified by plan and negative-control checks rather than visible in this upper-floor camera.

Main regenerated all three Vulkan images with native exit 0 in 45.96 seconds.
I inspected the main images: the corridor and repeated cell partitions read
clearly, the cages and guard station are present, and the hatch panel is
visible. Main render logs are in `artifacts/int010_main/render.*`.

## INT-010-only source delta

- `src/house/house_builder.gd`
- `src/house/house_furnishing_recipes.gd`
- `src/house/house_geometry.gd`
- `src/house/house_plan.gd`
- `src/shop/shop_generator.gd`
- `src/shop/shop_planner.gd`
- `src/shop/shop_spec.gd`
- `qa/house_furnish_check.gd`
- `qa/house_nav_check.gd`
- `qa/house_plan_check.gd`
- `tests/run_all_impl.gd` (only the `prison` suite registration/dispatch hunk; integrate separately after ordered commits)
- `tests/suites/prison_suite.gd` and generated `.uid`
- `tests/suites/shop_archetype_suite.gd`
- `tools/render_int010_prison.gd` and generated `.uid`

The corrected INT-008 hearth guard in `src/house/house_furnisher.gd` and the INT-009 source changes are unchanged from the baseline clone. No assets or catalog data changed. The integrated source/test delta passed `git diff --check`.

## Captured evidence

Logs and exact native exits are under `artifacts/int010_reconcile/`: `editor.*`, `prison.*`, `sarchetype.*`, `lane-plan.*`, `lane-dress.*`, and `render-prison.*`. The root certificate-store message is emitted by this Windows Godot build after successful runs and does not change their native exit codes.
