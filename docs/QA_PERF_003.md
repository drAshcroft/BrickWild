# QA-PERF-003: bounded church dome roof clipping

## Finding

`ChurchRoofs.emit()` intersected every dome tetrahedron section with every
remaining roof piece, including pieces whose plan bounds did not touch the
section. On Byzantine TestSweep seed 5003, the dome emitted 1,248 tetrahedra
against eight roof faces. The original clipper reached 2,150 pieces on face 0
after 15.95 s and 12,356 pieces by tetrahedron 1,100 on face 2 after 81.31 s
on that face alone. The full baseline run was stopped there because its piece
count was still growing. [The captured profile](../artifacts/qa_perf_003/profile_seed5003.log)
shows the progression.

The emitter now caches tetrahedron plan bounds, skips sections outside each
face, and skips `RoofShape.subtract()` for roof pieces whose bounds do not
overlap that section. It stops after all roof pieces have been removed. The
actual intersection and subtraction math is unchanged where bounds overlap.

## Measured result and geometry limit

The final fixed Byzantine seed 5003 build completed in **710 ms** and the
Hagia Sophia landmark at scale 1.0 completed in **539 ms** on this host. These
are builder timings printed by [the fixed probes](../artifacts/qa_perf_003/README.md),
not promises about a loaded editor or a whole QA lane. The bounded church lane
now assembles Byzantine, Renaissance and Russian seeds plus Hagia Sophia,
Florence and St Basil; its two suite bodies took 7.08 s in the final run.

The original full build could not produce a baseline raw mesh fingerprint
within the change-check budget. A bounded 100-tetrahedron fixture did. The
original emitted 16,796 roof triangles in 7,942 ms; the optimized emitter
emitted 1,776 in 360 ms. The raw triangulation necessarily differs because
the original repeatedly split pieces outside a cut. Both versions produced
the same part, mass and component log digest. At 289 fixed roof-ray samples,
286 height pairs matched at 1 mm rounding; the other three differed by 1 mm.
[The sample comparison](../artifacts/qa_perf_003/surface_compare.json) records
their coordinates and heights. This supports equal exposed surface at the
sampled resolution, not bitwise mesh identity everywhere.

The same-camera Hagia and Florence [front and raking pairs](../artifacts/qa_perf_003/README.md)
were inspected. Approximately 1.2–2.2% of pixels changed per image, with
mean channel differences of 3–5/255 among changed pixels; the visible forms
and joints remain the same at those views. The roof seam, dome support and
church aperture fixtures pass. A negative control omits volume cuts and
exposes roof inside the Byzantine half-dome, while the repaired path does
not. The broader `lane:church` sweep remains a separate scheduled check.

## Change check

Run `lane:church-change` for routine church geometry changes. For dome emitter
edits, also run `tests/vis008_dome_fixture.gd` and
`tests/roof_seams_test.gd`. The lane now checks a roof vertex budget for
Byzantine seed 5003 and Hagia Sophia, as well as the real cut and its
missing-volume negative control. [Final results](../artifacts/qa_perf_003/README.md)
list the commands and logs.
