# QA-PERF-001 evidence

- `profile_0.log` through `profile_5.log`: fixed square, round style,
  battered, nested, ridge and tower-house stage timings on the prechange code.
- `profile_detail_2.log`, `_3.log`, `_4.log`: exact prechange CastleQA failures
  for Crusader 9250, Crusader 9118 and Bavarian ridge 8805.
- `castle_change_baseline.log`: three-suite lane before CAS-REG-003, failing
  tower-house windows as expected (90.26 s host wall).
- `castle_change_trial_surface.log`: an intermediate four-suite run with a
  false surface-count assertion; actual aperture and massing checks passed.
- `castle_change_final.log`: four suites, 127 checks, no failures, five known
  opening-probe warnings (91.40 s host wall).

`tools/profile_castle_change.gd` is the repeatable fixed-case profiler. The
interpretation and scope limits are in `docs/QA_PERF_001.md`.
