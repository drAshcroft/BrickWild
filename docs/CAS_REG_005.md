# CAS-REG-005: raised keep entrance route

Fixed production cases: Crusader castle seed 9250 and two-ring fortress seed
9118. Both have a shell keep, four occupied storeys, and a protected entrance
on storey 1.

## Cause and repair

`CastleKeepPlan._add_stair` penalized a stair footprint that crossed the
front-door line only when its lower storey was 0. Both protected entrances
actually open on storey 1. The scored search therefore chose a stair from
storey 1 to 2 directly in the entrance route. The unmodified
`HousePlanCheck` reported `stair_line: the foot of stair 1 lies in the line
of the front door` for each production case.

The search now compares `lower` with the actual entrance door's room index.
It keeps the stair on a wall, inside both connected floors, and away from the
protected entrance route. No QA threshold or room programme changed.

## Evidence

The [fixed camera plan render](../artifacts/cas_reg_005/plan_comparison.png)
draws the planner's rectangles from the [before](../artifacts/cas_reg_005/plan_before.log)
and [after](../artifacts/cas_reg_005/plan_after.log) logs. Blue is the front
door line; red is the obstructing stair foot; green is the repaired stair.
Its dashed outline is the entrance storey's floor bounds.

| Seed | Front-door line / stair footprint before | After |
|---|---:|---:|
| 9250 | 0.950 x 1.000 m | 0.000 x 1.000 m |
| 9118 | 0.950 x 1.000 m | 0.011 x 1.000 m |

The 0.011 m edge contact on 9118 is below `HousePlanCheck.TOL = 0.02 m`,
and does not block a 0.95 m route. Both plans now have zero `HousePlanCheck`
failures. The dedicated `ckeepstair` suite builds both full castle meshes and
runs full `CastleQA`: 14 checks, zero failures or warnings. Its deliberate
blocked-route mutation produces the original `stair_line` failure. See the
[focused log](../artifacts/cas_reg_005/ckeepstair.log). The bounded
`lane:castle-change` result is in
[its log](../artifacts/cas_reg_005/lane_castle_change.log). The routine lane
now runs full CastleQA on the 9250 mesh and checks the protected-entrance
plans for both 9250 and 9118. The dedicated suite retains full mesh coverage
for the two-ring fortress and the mutation control.

## Changed files

- `src/castle/castle_keep_plan.gd`: score stair positions against the actual
  entrance storey.
- `tests/suites/castle_keep_stair_suite.gd`, `tests/suites/castle_change_suite.gd`,
  `tests/run_all.gd`: fixed real production cases, a blocked-route negative
  control, and cheap routine coverage of both plans.
- `tools/probe_cas_reg_005.gd`, `tools/draw_cas_reg_005.py`: reproducible
  plan records and the before/after diagnostic render.
