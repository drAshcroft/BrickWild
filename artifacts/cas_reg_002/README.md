# CAS-REG-002 evidence

The baseline geometry is commit `29e30e8`; the repaired geometry is the CAS-REG-002 change from that base.

## Change

`CastleAccessGeometry.wall_stairs()` now reserves the AABB envelopes of towers on other enceinte rings as well as testing exact tower outline intersections. Nested-ring gate towers can project into the outer ward; the previous exact polygon test allowed wall-stair mass bounds to cross those tower envelopes. Same-ring towers continue to use exact polygon checks so stairs can meet their own curtain.

## Reproduction and result

Fixture: Crusader fortress, 90 x 140 m, wall height 20 m, seed 9118.

Before, both outer wall stairs overlapped the corresponding inner gate-tower mass bounds by 1.966 m along X and 2.52 m along Z. After, all four gate tower records and all four stair records have disjoint horizontal AABBs. The outer pair moves to transverse positions beside the front gate bay and remains within the existing gate-distance rule. `CastleMassingCheck._check_wall_stairs()` confirms two connected stair routes on each ring.

## Verification

- `cgatestairs`: 7 checks, 0 failures. Checks the focused stair massing rule, emitted component parity, gate tower/stair AABB separation and counts, gate passage access, mesh normals and opening direction, and clear tread headroom.
- `cgateaccess`: 16 checks, 0 failures, 0 warnings across Norman, Crusader, Moorish and Japanese gate cases.
- `caccess`: 199 checks, 0 failures, 0 warnings across the enclosed castle/fortress style-size sweep. Suite body took 707.87 s; this broad physical-access suite is slow and its measured cost is recorded for `QA-PERF-001`.
- After cherry-picking with QA-PERF-003, [the combined main-branch check](main_integration.log) passed `lane:church-change cgatestairs`: 5,395 checks, 0 failures or warnings.
- Fixed-camera appearance renders for the same Crusader 9118 production emitters. Cameras: `clearance_overhead` and `clearance_raking`. These render ring walls, gatehouses, towers and stairs from `CastleBuilder`; interiors and yard dressing are omitted to keep the run bounded. The placement change is small in these full geometry views, so use the diagnostic below for direct clearance comparison.

Images:

- [Before, overhead](renders/before_clearance_overhead.jpg)
- [After, overhead](renders/after_clearance_overhead.jpg)
- [Before, raking](renders/before_clearance_raking.jpg)
- [After, raking](renders/after_clearance_raking.jpg)

## Clearance diagnostic

The top-down diagnostic draws the actual production `mass_log` AABBs for both gate-tower rings, both gatehouse masses and all four wall stairs. Colors distinguish ring 0 towers, ring 1 towers, and stair masses; red marks horizontal AABB intersections. Both images use the same world extent and scale. Baseline has two intersections; repaired geometry has none.

- [Before, production mass bounds](renders/footprint_before.png)
- [After, production mass bounds](renders/footprint_after.png)

`tools/render_cas_reg_002_footprints.gd` rebuilds the real Crusader 9118 ring, gate and wall-stair geometry, reads the resulting mass log, and draws those records. This is a diagnostic plan view of logged mass bounds, not a beauty render or a substitute mesh.

Logs: `cgatestairs.log`, `cgateaccess.log`, `caccess.log`, `repro.log`, `after_probe.log`, `render_before.log`, `render_after.log`, `footprint_before.log`, `footprint_after.log`.

## Limits

The full castle-wide `cmassing` and `cnormals` sweeps were not run. The focused fixture calls the wall-stair massing check and shared normal/opening checks on seed 9118; the gate-access and broader physical-access suites supply independent route and emitted-tread coverage. No full fortress furnishing or whole-castle sweep was used for this placement-only change.
