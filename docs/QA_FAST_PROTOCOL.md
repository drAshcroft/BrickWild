# Routine QA: five-minute task gate

Use one bounded selector for the code that changed, plus its focused feature
fixture. Run them together so the runner de-duplicates suites. A passing task
gate needs a native exit of 0, an `ALL PASS` summary, no script errors, and
less than 300 seconds of host wall time. `tools/run_qa_lane.ps1` records all
four facts under `artifacts/qa_fast/<selectors>/<timestamp>/`. A slow result
is marked `SLOW` and returns nonzero even if its checks pass. A run still
active at five minutes is stopped by its exact Godot PID and marked
`TIMEOUT`.

```powershell
& tools/run_qa_lane.ps1 lane:castle-change
& tools/run_qa_lane.ps1 -Selectors lane:castle-change,cterrace
```

Run the headless editor once after adding a new `class_name`, then run the
selected lane. Use the installed Godot 4.5.2 Mono binary named in
`AGENTS.md`. The wrapper sets a private Godot profile and puts `--log-file`
before `--script` so that Windows startup and the native exit are captured.

## Selection and measured wall time

Measurements are from 2026-09-30 on this Windows host. An unrelated Godot
process shared the host during several trials, so these are observed wall
times rather than an idle-machine promise.

| Edit | Routine selector | Wall time | Result |
|---|---|---:|---|
| mesh emitters, roofs, house components | `lane:geom` | 116 s | 6,975 checks, pass |
| castle shells, openings, access | `lane:castle-change` | 209 s | 214 checks, pass; 5 classified warnings |
| church shells, openings, roofs | `lane:church-change` | 20 s | pass |
| house planning and circulation | `lane:house-plan-fast` | 206 s | 263 checks, pass; 1 warning |
| furnishing and assembly | `lane:house-furnish-fast` | 194 s | 127 checks, pass; 2 warnings |
| house exterior and assembly | `lane:house-exterior-fast` | 112 s | 1,024 checks, pass |
| props and assembly contracts | `lane:assets-fast` | 40 s | 119 checks, pass |
| library business and row repair | `lane:library-change` | 54 s | 31 checks, pass; 32 warnings |
| prison programme and keyed routes | `prison` | 225 s | 7 checks, pass; 13 warnings |
| temple geometry and rite | `lane:temple` | 52 s | 2,247 checks, pass; 7 warnings |
| village site, lots, plan rules | `lane:village-fast` | 113 s | 10 checks, 0 failures (the VIL-017 baselines were fixed) |

The first furnishing candidate used the existing 24-house statistical sweep.
It passed its assertions but took 343 seconds, so it is **not** the routine
selector. `houseqafurnishfast` uses 12 houses and 8 variety cases; the
original `houseqafurnish` still runs all 24. The first village candidate ran
`vsite vlot vcheck`, exposed failures, and exceeded five minutes during
`vlot`; it was stopped. `vquick` instead measures real street and hamlet
seed-0 sites and lots, runs plan checks, and proves the road-width rule can
reject a mutated plan. Its current red result is a village defect, not a
runner error. See the logs under `artifacts/qa_fast/`.

Run the focused feature fixture in the same invocation whenever one exists:
for example `cbergfried`, `cterrace`, `chimeji`, `barracksquick`, `librarybiz`, or `prison`. If the
combined wall time exceeds 300 seconds, make a smaller fixed fixture; keep
the wider sample as scheduled regression. The 100-seed barracks and library
matrices are scheduled breadth checks. A quick lane never proves that every
seed or style passes.

For CAS-010, the full `clandmark` suite hit the five-minute cap. The
`chimeji` selector runs the same landmark assertions at all four Himeji
scales in 41 seconds; use it with the terrace fixture for castle terrace
edits. Keep full `clandmark` in the scheduled batch.

For the scheduled castle contract/massing/landmark/voxel batch, use
`lane:castle-spot` for routine spot coverage. It composes the existing
`castlechange` fixed production cases, which check the build contract, massing,
and full `CastleQA`, with Himeji's four fixed landmark scales from `chimeji`.
Expected host time is about 100 seconds: the measured bodies were 51 seconds
for `castlechange` and 41 seconds for `chimeji`, plus one runner startup. This
deterministic spot lane does not prove that the full style × tier × seed sweep
passed; keep `lane:castle` and `castle cmassing clandmark cvoxelqa` as scheduled
runs.

For INT-008, `shop,barracksquick` passed in 38 seconds. The combined
`shop,sarchetype` sweep hit the cap while running other shop families.
`barracksquick` checks the requested three sizes, HouseQA and negative
controls; the prepared clone's 100-seed matrix remains breadth evidence.
For INT-009, `lane:library-change` checks shop contracts, three library sizes
and two repair regressions in 54 seconds. The 100-seed library matrix stays
in scheduled regression.

## Scheduled regression and asset exception

Keep `lane:castle`, `castle cmassing clandmark cvoxelqa`, `house`, `court`,
`houseqa`, `houseqafull`, `lane:dress`, full village form/enclosure matrices,
and `lane:sweep` as batch or pre-merge runs. Record their native exit and
summary separately. `cvoxelqa` now prints completed/total fixtures and
elapsed time every ten cases, before each fantasy fixture, and on completion.

Changes under `assets/props/` still require a catalogue rebuild and the full
catalogue check. The default `tools/build_prop_catalog.gd` is the full
measurement oracle. After that seeds the local cache, use its exact
pack-incremental mode for routine rebuilds:

```powershell
godot --headless --path . --script res://tools/build_prop_catalog.gd -- --incremental
godot --headless --path . --script res://tests/run_all.gd -- catalogcache
```

The cache hashes every file in each pack tree (models, buffers, textures and
`.import` settings), plus the measurement code, catalogue pack rules, project
settings and engine version. Any changed or added/removed file invalidates
that pack; a missing or malformed cache forces measurement. The cache is in
the project-local ignored `.godot/` directory, not source control.
`--verify-parity` is the expensive oracle
command: it runs a full measurement, reads the just-written cache back, and
requires cache-backed JSON to match the full output byte-for-byte. `lane:assets`
still checks every catalogue entry against its imported model; `lane:assets-fast`
does not replace it.
