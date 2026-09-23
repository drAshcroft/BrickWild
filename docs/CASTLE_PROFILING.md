# Castle phase profiling

`tools/profile_castle_interiors.py` prepares an isolated source snapshot, then
instruments shallow phase boundaries without changing the working source files.
Each wrapper calls the original function exactly once, with identical arguments
and return value. Timing includes return expressions. The recorder separates
inclusive time from self time so furnishing is not counted as mesh emission.

```powershell
python tools/profile_castle_interiors.py prepare artifacts/castle_perf/before
python tools/profile_castle_interiors.py run artifacts/castle_perf/before --godot C:/path/Godot.exe
```

Coordinate a quiet machine before running performance acceptance. `--concurrent`
explicitly labels an exploratory run with other work active. `--case
norman:castle:0` selects a `CastleSweep.spec_at` fixture; the flag is repeatable.
The default runs three samples each of Norman manor/castle/fortress, Edwardian
castle/fortress and Crusader fortress 0 (a canonical shell keep). Full CastleQA, including interior HouseQA and
the existing lord's walk corridor/full fallback, runs on each sample. `--no-qa`
is only a generation diagnostic and cannot establish acceptance.

Each snapshot has a source hash manifest and `results/profile.json`, incremental
logs, and a binary snapshot per fixture. The snapshot covers all derived spec and
plan fields (including subclass/private fields), furniture, transforms, bounds,
RNG seed/state, all mesh surface arrays, and the part/mass/component/prop logs.
Every repeat must be byte-identical. Generation and QA failures return nonzero;
timeouts and missing completion markers cannot pass. Windows runs the real Godot
executable directly so a timeout cannot orphan a console-shim child.

```powershell
python tools/profile_castle_interiors.py prepare artifacts/castle_perf/after
python tools/profile_castle_interiors.py run artifacts/castle_perf/after --godot C:/path/Godot.exe
python tools/profile_castle_interiors.py compare artifacts/castle_perf/before/results/profile.json artifacts/castle_perf/after/results/profile.json
```

The comparison reports full-state parity and before/after medians. Keep the source
versions fixed except for the proposed optimization. A `prepare --plain` snapshot
omits instrumentation for a control/parity run. `prepare --detail` times candidate,
affinity, fit and polygon containment helpers as well; it adds overhead to very
hot paths, so its absolute times are diagnostic rather than release medians.

Never coarsen grids, omit real furnishings or relax QA to improve these timings.
Acceptance still requires the five castle suites plus affected house/shop suites.
An exclusive BigGlade test window is not an idle machine if unrelated projects
are running CPU-heavy tests; record that limitation explicitly.

The September 2026 exploratory run is in `artifacts/p1p2_api/perf_before/results`.
All six fixtures repeated with identical complete-state fingerprints. It was
explicitly concurrent: an unrelated dungeon test process stayed active, and other
BigGlade lanes resumed during the later cases. These are diagnostic medians, not
an idle-machine acceptance baseline:

| Fixture | Generate | Furnisher | Free placement | Navigation repair | Castle QA |
|---|---:|---:|---:|---:|---:|
| Norman manor 0 | 0.68s | 0.64s | 0.23s | 0.08s | 1.00s |
| Norman castle 0 | 8.61s | 8.46s | 3.38s | 2.67s | 7.02s |
| Norman fortress 0 | 72.61s | 72.21s | 44.89s | 20.66s | 8.20s |
| Edwardian castle 0 | 24.96s | 24.17s | 15.89s | 5.36s | 10.23s |
| Edwardian fortress 0 | 23.43s | 22.77s | 17.02s | 3.87s | 6.57s |
| Crusader castle 0 | 2.65s | 2.48s | 0.91s | 1.02s | 4.24s |

Norman fortress 0 exposed pre-existing `keep_shell` QA failures (its eight occupied
levels exceeded the declared four, with further stair/daylight/hearth errors), so
the complete run correctly exited 1. Other five fixtures had no QA failures.
Crusader castle 0 selected a square keep; future acceptance must additionally
select a canonical Crusader fixture whose generated keep is a shell. No castle
performance optimization or full-suite acceptance is claimed by this run.

The corrected motte fixtures were profiled again from a fixed source snapshot.
The detailed diagnostic attributed 94.39s of the Norman fortress's 216.63s
generation to 719,726 `_inside_outline` calls. `_fits` is now ordered to reject
rectangle collisions and insufficient clearances before running the same pure
polygon-corner predicates. No candidate, tolerance, navigation resolution or RNG
draw changed. The original and reordered implementations agreed on 20,000
candidate cases across rectangular, oval and concave outlines.

`artifacts/p1p2_api/perf_fitorder_before` and `perf_fitorder_after` differ in that
one function only; the other 111 source inputs have identical hashes. All six
complete plan/placement/RNG/mesh/log fingerprints match, including the corrected
eight-floor Norman motte and the canonical Crusader shell keep. Full CastleQA
passed every fixture in both snapshots. These single-sample, concurrent timings
are useful diagnostics, **not idle-machine performance acceptance**:

| Fixture | Original generation | Reordered generation | Original furnishing | Reordered furnishing |
|---|---:|---:|---:|---:|
| Norman manor 0 | 1.57s | 0.89s | 1.50s | 0.85s |
| Norman castle 0 | 18.46s | 13.23s | 18.27s | 13.09s |
| Norman fortress 0 | 191.42s | 179.11s | 188.63s | 176.79s |
| Edwardian castle 0 | 32.93s | 26.21s | 32.12s | 25.37s |
| Edwardian fortress 0 | 22.32s | 17.10s | 21.47s | 16.31s |
| Crusader fortress 0 | 16.52s | 16.52s | 15.78s | 15.26s |

The comparison and source manifests are saved beside those snapshots; the
compact table data is `artifacts/p1p2_api/perf_fitorder_summary.json`. The task's
quiet repeated medians and final five-suite castle acceptance remain separate
gates, after the concurrent geometry and furnishing changes settle.
