# VIS-011 church host apertures

The remaining church windows now cut their own masonry. Straight wall shells
are partitioned around an opening; apse, chapel, and drum windows partition
the emitted polygon facet, using its local face normal rather than a mass AABB.
Each cut has wall-thickness returns. The west rose uses an inscribed polygonal
cut behind its twelve-piece ring. Leaded panes sit in the openings and retain
the four expected mesh surfaces.

`aperture_final.log` runs fixed-seed exterior-to-interior rays through every
representative host and blocked rays through adjacent masonry: 184 checks,
zero failures or warnings. `lane_church_final.log` passes church geometry,
normals, massing, blueprint, landmark, apertures and load paths: 1,308 checks,
zero failures and three existing Russian-style warnings. `churchload_fixed.log`
passes 726 checks. The
nonheadless `tools/render_shots.gd -- vis011` run writes front and raking
details to `artifacts/renders/visualqa/vis011/`; the rose, Chartres apse and
chapel, Notre-Dame aisle and tower, Durham crossing tower, and both dome
styles were inspected. The rose clears the west string course and the raised
apse glazing stays visible over the ambulatory roof.

The visible door at the narthex outer wall is cut through that wall. A complete
route through the inner nave wall and the single axial tower is separate work
(`VIS-014`). Likewise, these close views prove host openings rather than a
whole-building visual score; larger church silhouettes remain in the visual
backlog.

After integration into the main tree, `main_integration.log` passes the focused
aperture and load-path suites together: 910 checks, zero failures or warnings.
