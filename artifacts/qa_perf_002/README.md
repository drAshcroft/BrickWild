# QA-PERF-002: bounded church change checks

The old `lane:church` estimate of about six minutes is unsupported. A VIS-008
run remained CPU-active in `church` past twelve minutes without a suite result;
a VIS-014 `normals` run did the same for over nine minutes. The standalone
`churchaperture` suite took 499.66 seconds on the busy host. A fixed Byzantine
seed 5003 profile reached the dome, then remained inside `ChurchRoofs.emit` for
over two minutes. Its spec has a dome and half-domes; `QA-PERF-003` tracks the
roof clipping cost. The [diagnostic log](byzantine_build_profile.log) used
temporary stage prints, which are absent from production code.

`lane:church-change` runs `churchroof` and `churchchange`. The roof suite checks
5,325 roof, support and normal conditions. The new suite checks generated
Romanesque, Gothic and Nordic stave seeds 5003/5008, Notre-Dame and Durham at
full scale, a clerestory aperture, three exterior-to-nave entrance routes,
normals and massing. Deliberately solid wall, inverted normal and missing-mass
controls must all be detected. Its fixture timings are printed in the
[suite log](churchchange.log).

| Run | Suite body | Process wall | Process CPU | Checks |
|---|---:|---:|---:|---:|
| [churchroof](churchroof.log) | 102.19 s | 163.53 s | 40.13 s | 5,325 |
| [churchchange](churchchange.log) | 6.49 s | 45.43 s | 14.55 s | 44 |

Both runs passed with zero failures or warnings. The process figures came from
[`profile_church_lane.ps1`](../../tools/profile_church_lane.ps1) with the
non-console Godot executable. Another Godot test process was active on this
machine, so wall time includes startup and scheduling delays. An earlier
combined lane run completed its suite bodies in 49.27 s and 3.14 s before the
inverted-normal control was added. The body time and CPU figures describe this
host, not a universal time guarantee.

The [final combined lane](lane_final.log) passed 5,369 checks across both
suites with no failures or warnings. Its suite bodies took 34.49 s and 0.88 s.

The bounded lane does not exercise an assembled Byzantine, Renaissance or
Russian dome or the complete landmark scale matrix. Use the focused dome
fixture with it for dome emitter edits. Keep `lane:church` for scheduled broad
verification; do not report an interrupted run as passed. `QA-PERF-003` is the
next generator optimization needed to include assembled domed cases in a
predictable lane.
