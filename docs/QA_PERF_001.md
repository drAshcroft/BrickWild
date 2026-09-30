# QA-PERF-001: bounded castle change gate

The previous `lane:castle` estimate of 3–8 minutes was not a useful completion
gate. The `caccess` suite alone took 707.87 seconds for 199 checks during
CAS-REG-002. The castle contract, normals, massing and voxel suites each repeat
the full style × tier × three-seed sweep, rebuilding every case. Running all
four for a small emitter edit spends most of its time on repeated castle
generation and interior furnishing.

`tools/profile_castle_change.gd` measures generation, `CastleBuilder.build()`,
normals, `CastleMassingCheck`, `ComponentCheck`, and actual `CastleQA` in separate
processes on fixed production specifications. Its logs are in
`artifacts/qa_perf_001/profile_*.log`. Timings below are process-local stage
times on this Windows/Godot 4.5.2 host; other machines will differ.

| Case | Style, tier, seed | Build | Normals | Massing | Components | CastleQA |
|---|---|---:|---:|---:|---:|---:|
| square | Norman house 9330 | 0.43 s | 0.00 s | 0.00 s | 0.00 s | 0.30 s |
| round style | Edwardian manor 9075 | 1.07 s | 0.01 s | 0.00 s | 0.00 s | 1.45 s |
| battered | Crusader castle 9250 | 35.72 s | 0.29 s | 0.04 s | 0.78 s | 14.29 s |
| nested rings | Crusader fortress 9118 | 32.86 s | 0.29 s | 0.05 s | 1.12 s | 25.69 s |
| ridge | Bavarian castle 8805 | 6.28 s | 0.06 s | 0.00 s | 0.00 s | 2.85 s |
| tower house | Norman house 8804, Scottish form | 11.24 s | 0.02 s | 0.00 s | 0.00 s | 2.87 s |

The largest measured cost is **build**, not normal checking. The Crusader
castle has 93,702 vertices and 698 parts; its build costs about 36 seconds.
Full `CastleQA` is also material on large enclosures. It voxelizes each mesh
and checks structural connectivity and access. We have not inferred a total
full-sweep time from these six cases, nor claimed that sweep passed.

## Everyday lane

`lane:castle-change` runs four suites:

1. `ctowerhouse`: Bologna 8803 and Scottish 8804 plans, emitted slit rows,
   raised doors, normals, and missing-opening controls.
2. `caperture`: real square keep, round keep, battered tower and curtain opening
   rays, with missing-surround and blocked-opening controls.
3. `cgatestairs`: both nested Crusader seed 9118 rings, emitted stair components,
   access rays, and a deliberate gate-tower/stair overlap.
4. `castlechange`: fixed Norman, Edwardian, Crusader, Bavarian ridge and Scottish
   tower-house builds. It checks normals, opening directions, massing, component
   triangle parity, and real `CastleQA` on the Norman, Edwardian, Crusader and
   Bavarian whole buildings. It checks both fixed Crusader entrance plans
   without rebuilding the two-ring fortress. Its own controls invert normals,
   erase the mass log and block a window ray with solid masonry.

The scheduled `lane:castle`, `castle`, `cnormals`, `cmassing` and `cvoxelqa`
remain available. This lane does not imply that every seed passes voxel QA.

## Baseline and follow-up

Before CAS-REG-003, the three suite bodies took 3.63 + 18.14 + 57.57 = 79.34
seconds; host wall time was 90.26 seconds. The lane correctly failed the
Scottish tower house seed 8804 because five occupied storeys lacked emitted
windows. It also asserted four mesh surfaces, which was later shown to be an
invalid requirement for a castle with no dark opening insert. The first two
suites passed 72 and 8 checks. See
`artifacts/qa_perf_001/castle_change_baseline.log`.

After CAS-REG-003, the final four suite bodies took 16.36 + 2.08 + 11.40 +
51.13 = **80.97 seconds**; host wall time was **91.40 seconds**. All 127 checks
passed, with five opening-direction probe warnings. The suite names and timings
are in `artifacts/qa_perf_001/castle_change_final.log`. An interim check wrongly
required four surfaces from a tower house with cut openings; Godot omitted its
empty trailing dark-insert surface. The final lane checks structural geometry,
emitted window records and actual aperture rays instead. The interim result is
preserved in `castle_change_trial_surface.log`.

The broader voxel sweep is still a separate regression gate. Fixed full
`CastleQA` probes on Crusader 9250 and nested Crusader 9118 both report
`interiors[keep]: stair_line: the foot of stair 1 lies in the line of the front
door`. `CAS-REG-005` owns that repeatable keep-plan defect. Bavarian ridge 8805
reports 17 interior failures, starting with two exterior doors off their host
wall and windows outside the assigned rooms. `CAS-REG-004` owns the rotated
ridge-plan contract; it blocks facade work in `VIS-009`. The specific reports
are in `profile_detail_2.log`, `profile_detail_3.log` and
`profile_detail_4.log`. These are baseline failures, not passes or new
regressions from the lane. Several manor hall and Crusader keep
opening-direction warnings also appeared in the bounded lane. They need a
separate rendered and triangle check before declaring them blocked apertures.

## Current gate after the interior repairs

`CAS-REG-004` repaired the ridge range doors, window ownership and room
programme; `CAS-REG-005` repaired the raised keep entrance route. The updated
lane now passes **195 checks, 0 failures and the same 5 outside-probe
warnings**. It runs full `CastleQA` on fixed Bavarian 8805 and Crusader 9250,
plus both raised keep plans. The dedicated `ckeepstair` suite also passes
full `CastleQA` on Crusader 9250 and 9118. See
`artifacts/cas_reg_005/lane_castle_change.log` and
`artifacts/cas_reg_005/ckeepstair.log`. These fixed cases make the everyday
gate useful; the exhaustive sweep remains separate.
