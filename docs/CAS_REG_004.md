# CAS-REG-004: Bavarian ridge interior openings

Base: `e155a3c` (master). Seed: Bavarian ridge 8805, 120 × 40 × 20 m.

## Failure and repair

The pre-fix fixed-seed CastleQA report had 17 interior failures. The hall's
link door and `range_1`'s link door sat 1.2 m inside their end-wall planes.
`range_1` also assigned the later bay's windows to room 0. That left room 1
without daylight and put twelve openings outside the room that claimed them.
The range plan furnished both bays as lord's chambers even though a
`HousePlan` records one chimney wall; those two hearths had no matching flue
plan.

`CastleInteriorPlans.ridge_range_plan` now puts each shared-range door on the
actual end wall in local coordinates. The existing `CastleInteriors.emit`
transform maps those points and their facing directions into the castle
frame; the regression fixture checks each forwarded opening against that
transform. Ridge windows now retain the bay index passed to the shared window
planner. The first chamber owns the range hearth; later bays use the guest
room programme and do not claim a second, unplanned chimney. QA remains
unchanged.

The focused fixture checks both range plans with HouseQA, verifies the
transformed opening records, and moves a window off its wall to prove
HousePlanCheck rejects it. The same 8805 row now runs full CastleQA in the
bounded castle-change lane.

## Verification

- `lane:castle-change`: **PASS**, 190 checks, 0 failures. The ridge seed 8805
  CastleQA passed. Five existing opening-probe warnings remain on the round
  seed 9075 and battered seed 9250 cases; none are from the ridge fixture.
- Plan-only reproduction: hall 0 HouseQA failures; `range_1` 0 HouseQA
  failures.
- `git diff --check`: clean.

Logs: [bounded lane](../artifacts/cas_reg_004/lane_castle_change.log),
[plan probe](../artifacts/cas_reg_004/plan_probe.log).

## Render inspection

Before and after used the same seed and 1100 × 760 SubViewport. Both views
used a fixed center `(0, 10, 0)`, 65 m frame radius, 48° field of view and
matching lighting. Front yaw/pitch: `3.1416 / -0.20`; raking yaw/pitch:
`2.30 / -0.27`.

The front and raking pairs show the same ridge silhouette, roofs, and facade
window rows. No stray or floating openings are visible. The corrected end
doors are buried in the shared tower joins, so their local relocation is not
visible in these two exterior views; the plan and emitted-record assertions
provide the direct evidence for those apertures.

| View | Before | After |
|---|---|---|
| Front | [before_front.jpg](../artifacts/cas_reg_004/renders/before_front.jpg) | [after_front.jpg](../artifacts/cas_reg_004/renders/after_front.jpg) |
| Raking | [before_raking.jpg](../artifacts/cas_reg_004/renders/before_raking.jpg) | [after_raking.jpg](../artifacts/cas_reg_004/renders/after_raking.jpg) |

## Changed files

- `src/castle/castle_interior_plans.gd` — end-wall link coordinates, correct
  bay ownership for windows, and the single hearth programme per range.
- `tests/suites/castle_change_suite.gd` — fixed-seed full QA, transformed
  opening checks, and moved-off-wall negative control.
- `tools/render_cas_reg_004.gd` — deterministic before/after render runner.
