# VIS-007 verification

The [fixed-camera Durham and Notre-Dame pairs](../renders/visualqa/vis007/README.md)
show the stepped buttresses and heavier flying arch with coping at detail and
whole-building scale. The added shoulders cast separate shadows. The accepted
full portraits show a modest change; the broad nave proportions still govern
the silhouette.

`church_lane.log` covers `lane:church blueprint landmark`: 993 checks, zero
failures, and the same three Russian-style normals warnings present before this
edit. It includes the original `churchload` fixture with 549 checks. The later
VIS-005 QA follow-up expanded `churchaperture` from 44 to 74 direct-ray checks;
that focused run and the 90-building voxel sweep pass in
[`artifacts/vis005`](../vis005/README.md). The first voxel sweep exposed a
coarse-grid assumption about true portal cuts; commit `f8bfb57` corrected the
check, not the mesh.

`manifest_before.json` and `manifest_after.json` in the render directory
record the seeds, detail focus, scale, camera and light. The `before` church
frames came from VIS-005 commit `da81cc7`; no new host-wall cuts are part of
VIS-007.
