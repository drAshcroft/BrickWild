# INT-009 Library Acceptance

Prepared in `artifacts/int009_reconcile_worktree` from the corrected INT-008
source, then integrated into main after INT-008. Main preserves the bounded QA
protocol and earlier barracks fixture.

## Checks

All captured native exits below are 0. Logs and exit files are under `artifacts/int009_reconcile/`.

On main, `tools/run_qa_lane.ps1 lane:library-change` passed with native exit
0 in 54.36 seconds: 3 suites, 31 checks, 0 failures, 32 warnings. The lane
runs `shop`, `librarybiz` and `libraryreg`; it omits the slow 100-seed and full
shop archetype sweeps. Log:
`artifacts/qa_fast/lane_library-change/20260930_173614/`.

- Editor registration: exit 0; class registration completed without parse errors.
- `shop`: 22 checks, 0 failures, 0 warnings.
- `sarchetype`: 61 checks, 0 failures, 13 warnings.
- `librarybiz`: 7 checks, 0 failures, 27 warnings; covers 70%, 100%, and 140% plans and four negative controls for bookcase-row removal, moved lecterns, missing scriptorium windows, and a bookcase on the hearth wall.
- `libraryreg`: seeds 62006 and 62029; 2 checks, 0 failures, 5 warnings. This guards atomic center-row navigation repair and row pitch.
- `library100`: 100 seeds (62000-62099), 100 checks, 0 failures, 814 warnings.
- `lane:plan`: 3 suites, 386 checks, 0 failures, 1 existing townhouse multistory warning.
- `lane:dress`: 4 suites, 1,170 checks, 0 failures, 32 warnings.
- Non-headless renderer: exit 0; all five PNG saves returned error 0.

The library warnings include low daylight ratios in large rooms and the intentional free-standing center bookcase row. They did not produce HouseQA failures. The existing dress-lane warnings are recorded in its log. Its rule-override negative fixture also emits an expected `push_error` while confirming that disabling daylight without a replacement is rejected.

## Render review

The full cutaways show the four-room sequence. Close stacks views show three distinct banks with 5, 5, and 8 measured Bookcase_2 cases, with open side aisles and an end route. The closer reading/scriptorium cutaway shows the two BookStand lecterns and workbench; renderer logs include their room assignments and rectangles. The reading room has a Cauldron, the only owned prop measured in the `hearth` category. This model reads as a prominent chimney/hearth feature in the wide angle.

- `artifacts/int009/library_cutaway.png`
- `artifacts/int009/library_cutaway_opposite.png`
- `artifacts/int009/library_stacks_detail.png`
- `artifacts/int009/library_stacks_detail_opposite.png`
- `artifacts/int009/library_reading_scriptorium_detail.png`

Main regenerated all five images with native exit 0 in 13.7 seconds and all
PNG saves returned error 0. I inspected the main images: three stack banks
and side aisles are visible; the reading and scriptorium fittings are present.
The render log identifies both BookStand lecterns, the hearth, the scriptorium
workbench and the row counts 5/5/8. Log: `artifacts/int009_main/render.*`.

## INT-009 source delta

- `src/shop/shop_spec.gd`
- `src/shop/shop_generator.gd`
- `src/shop/shop_planner.gd`
- `src/house/house_geometry.gd`
- `src/house/house_plan_rooms.gd`
- `src/house/house_furnishing_recipes.gd`
- `src/house/house_furnish_score.gd`
- `src/house/house_furnish_placement.gd`
- `src/house/house_furnish_repair.gd`
- `src/house/house_furnisher.gd`
- `tests/suites/shop_archetype_suite.gd`
- `tests/suites/library_business_suite.gd` (new)
- `tools/render_int009_library.gd` (new)

`tests/run_all_impl.gd` registers `librarybiz`, `libraryreg` and `library100`.
The main `lane:library-change` uses the first two plus `shop` to stay under
five minutes. The clone's wider lane included `sarchetype` and `library100`;
their recorded results above remain breadth evidence from the prepared tree.
