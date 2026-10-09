# Connected chevet chapel passages

Chevet chapels now open through both faces of the actual segmented ambulatory wall. The cuts retain their jambs, heads and continuous upper and lower returns. Only chapels with a connected ambulatory mouth lose their radial end caps; unsupported arrangements retain them.

Threshold floors follow the ambulatory's piecewise chord boundary and the chapel mouth. Their potentially concave polygons are triangulated before emitting named slabs. Chapel interior floors share the same finished floor datum.

`tests/chapel_passage_test.gd` checks body-height openings across panel seams, nearby retained wall, shell and window retention, continuous floor support, dense coverage and measured area. Actual triangle-removal and doorway-plug controls must fail the same predicates. Floor support measures upward triangles; the first triangle returned by an unsorted hit search can be a slab underside.

The candidate was isolated on authenticated committed production from `d47effd`. The focused fixture passed 699 checks in 10.305 seconds. `lane:church-change` passed 5,561 checks in 19.943 seconds, with twelve existing opening warnings. Six roof-on assembled views rendered in 12.239 seconds, and root inspected all six. These are bounded results; they do not imply the exhaustive church sweep passed.

Open [the Gothic comparison gallery](../visualqa/styles/church/gothic/index.html). The isolated renders and their unchanged manifest are saved by request and room under `visualqa/styles/church/gothic/renders/chapel_passage_HEAD_restart23`. The earlier live cohort is retained separately. A generated target, exact prompt and interpretation notes sit under `targets`.

The passage repair is complete. The church's overall design remains unaccepted: chapel heads are plain rectangles, interiors are bare, and the chapel roof silhouette needs further work. Shaped supported openings, vaults and purposeful furnishing remain in the broader sacred-building plan.
