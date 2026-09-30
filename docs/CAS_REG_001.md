# CAS-REG-001: oversized enclosed keep access

## Finding

The reported large fortress seeds had no keep plan. `CastleKeepPlan.generate()` rejected interior footprints over 36 m, so `CastleInteriors.primary()` omitted `keep`. The production builder consequently emitted neither the planned first-floor door nor its protected forebuilding. Norman fortress seed 9119 has a keep AABB of about 63.6 x 48.2 m; the Japanese fortress sweep also crosses the old limit at seed 9118.

## Change

`CastleKeepPlan` now accepts fortress keep footprints up to 66 m, covering the largest affected sweep footprint (64.3 m). `CastleInteriors.primary()` keeps the complete keep plan, door and inter-storey stairs for these large rooms, while skipping furniture search above 36 m. The access route and its emitted shell remain plan-owned. `CastleQA.lords_walk()` checks the gate approach, stair, doorway and occupied keep route against the emitted mesh.

The focused fixture in `tests/suites/castle_forebuilding_suite.gd` retains the original index-0 castle and fortress cases, including the filled-stair physical negative control. It also adds seven production cases: Norman, Crusader, French chateau, Japanese, Moorish and Wizard at seed 9119, plus Japanese at seed 9118. Production cases check forebuilding geometry, named components, massing, gate-to-keep reachability, and a missing-stair negative control.

## Verification

- Production cases: PASS, 35 checks, zero failures or warnings. All seven target cases passed `CastleQA.forebuilding_report`, `ComponentCheck.check`, `CastleMassingCheck._check_forebuilding`, and `CastleQA.lords_walk`. The run took 710.37 seconds. [Log](../artifacts/cas_reg_001/cforebuilding_after.log).
- Original small fixtures: PASS, 70 checks, zero failures or warnings, including the filled-stair negative control. [Log](../artifacts/cas_reg_001/legacy_controls.log).
- `git diff --check` passed.

The renderer uses the fixed Norman 9119 entrance direction `(0, -1)` in both the baseline and updated scripts. The front and raking views use identical focus, radius, pitch, and yaw offsets for the two versions. Baseline commit `ef9b1ed` shows the keep without a protected entrance; the updated render shows the roofed stair reaching the raised keep door.

- [Baseline front](../artifacts/cas_reg_001/before/renders/norman_9119_front.png) and [updated front](../artifacts/cas_reg_001/renders/norman_9119_front.png).
- [Baseline raking](../artifacts/cas_reg_001/before/renders/norman_9119_raking.png) and [updated raking](../artifacts/cas_reg_001/renders/norman_9119_raking.png).
- Render logs: [baseline](../artifacts/cas_reg_001/before_render.log), [updated](../artifacts/cas_reg_001/after_render.log). The scripts are `tools/render_cas_reg_001_before.gd` on `ef9b1ed` and `tools/render_cas_reg_001.gd` on this change.

Large keeps intentionally have no generated furniture. Their interior shell, door and stairs remain planned and walkable; this avoids scaling the furnish search with a multi-thousand-square-metre floor. Broad castle `caccess` and `cmassing` sweeps were not run; they include unrelated seed families and the project notes a known baseline-red cmassing case.
