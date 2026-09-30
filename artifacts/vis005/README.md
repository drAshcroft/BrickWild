# VIS-005 verification

The [render set](../renders/visualqa/vis005/README.md) has same-seed, same-camera front and raking pairs for Notre-Dame's west portal and clerestory and Durham's west portal, plus current whole-building portraits. The before frames use the VIS-004 code at `de66292` with the identical shot definitions. The final candidate shows real host-wall depth without turning the clerestory into a row of bright sky holes.

Final focused checks: `churchaperture` 44/44, `church` 92/92, `massing` 90/90, `blueprint` 90/90 and `landmark` 32/32, with zero failures and zero warnings. Final `normals` passed 96/96 with three Russian-style warnings that match the pre-VIS-005 baseline. `lane:geom normals` passed 7,071 checks with the same three warnings after the plain pane was seated. The final twin-tower side-wall split was then checked by the focused aperture fixture and a separate final normals run. `church_lane.log` is the earlier broad pass before that small refinement; the individual `final_*.log` files cover the accepted code.

Other church wall kinds still have shallow opening treatments. They are tracked as VIS-011. Designed glazing, pointed heads and portal leaves are VIS-012.

Follow-up voxel sweep: five wide, genuinely cut portals were reported as
"floating" because the legacy opening check expected stone within one dilated
voxel of the logged centre. The [first sweep](voxelqa_followup_before.log)
records those cases. The check now leaves explicitly marked through apertures
to the triangle-ray fixture, extended to those five seeds in
[the focused run](aperture_expanded.log) (74/74), while still checking all
recessed openings. The [second sweep](voxelqa_followup_after.log) passes 90/90.
