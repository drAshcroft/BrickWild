# VIS-012 verification

The [paired church renders](../renders/visualqa/vis012/README.md) compare the
accepted VIS-007 shell at commit `254cf66` with the finished openings at the
same seeds, cameras, framing and front/raking light. Notre-Dame's clerestory
changes from a plain dark rectangle to a pointed, leaded window. Notre-Dame
and Durham retain open west entrance routes with visible exterior moulding.

The focused `churchaperture` check exercises direct masonry rays through the
cut openings, their adjacent jambs and their component logs. It also verifies
the four architectural surface slots and the marked glazing region. The
`churchload` check re-emits the logged box/slab components and compares stable
component identities across regenerations. See `focused_final.log` and
`church_lane.log` for the accepted runs.

`lane:church blueprint landmark` passed 1,052 checks, zero failures, and the
same three Russian-style normals warnings already present before VIS-012.
The accepted focused run passed 652 checks with zero failures or warnings.
