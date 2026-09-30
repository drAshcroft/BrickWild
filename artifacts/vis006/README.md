# VIS-006 aperture evidence

The aperture comparison starts from `de66292`. The whole-castle keep screenshots are not
acceptance evidence: the generated Bodiam/Krak keep is round or shell shaped,
and the castle massing obscures a useful view of the square shell cut. The
landmark camera's first-row selection also moved when opening counts changed.
The corrected renderer provides an isolated square-shell fixture instead.

## Isolated square keep shell

`keep_shell_fixture/` contains same-material, same-camera before/after views
from an isolated 10 × 12 × 10 m square keep wall. The baseline emits a solid
stone box with the legacy recessed face opening. The changed build partitions
the host stone around the aperture and emits jamb, head, sill, and through-wall
returns. Camera target and orientation are identical in both builds.

- `square_keep_before_front.png` and `square_keep_after_front.png` show the
  exterior view; the changed view has a clear opening to the far side.
- `square_keep_before_raking.png` and `square_keep_after_raking.png` show the
  same aperture from a raking angle; the changed returns are visible through
  the wall thickness.
- The renderer uses the same stone/trim materials and lighting for both.

The suite checks a ray from the exterior through both aligned apertures and
out the opposite face, and confirms adjacent masonry remains. The focused
`caperture_full_route_final.log` passes 34 checks with no failures or warnings.

## Whole-castle limitation

The random Bodiam and Krak specs select `round` or `shell` keep shapes. Those
branches still use `_shell_openings`; only the square branch calls
`_cut_keep_shell`. Therefore this render evidence demonstrates the square
branch in isolation. It does not establish that the default round/shell keep
branch is physically cut, nor that the full castle foreground provides a
useful view of the new aperture. `VIS-013` tracks round and shell keeps. The
whole-castle keep frames in `before/` and `renders/` are context only.

## Other geometry

- Bodiam curtain slits are cut through the battered wall's emitted stone
  courses. Course bands stop at sill and head, and the run is split around each
  slit. CastleGeometry supplies the actual wall surface.
- Polygonal curtain runs use the same vertical and along-run partitions after
  rotation. A separate flat-run ray fixture covers this path.
- The Bodiam tower slit is cut from the selected flat facet of the battered
  tower skin. Facet endpoints are interpolated along their chord, matching the
  drum emitter's actual polygon face.
- Planned interior openings, doors, and the gate passage retain their paths.
- Through-openings have no dark backing plane. The tower ray reaches the far
  facet of the same tower; that opposite host face is the pale panel in the
  aligned whole-castle view.

## Performance and remaining checks

`perf_baseline.log` and `perf_current.log` record four fixed Bodiam builds.
Stone vertices rose from 34,962 to 36,834 (+5.35%). Mean build time rose from
11.45 s to 11.61 s (+1.34%). The main-tree focused run in
`integration_final.log` passes 34 aperture and 16 gate-access checks with no
warnings. `representative_voxel_probe.log` runs complete `CastleQA` on the
same Bodiam and Krak seeds used for the renders, with a square keep to expose
the new window path; both pass with no failures or warnings. The separate
normal probe has no failures. Its one Bodiam and six Krak keep warnings are
identical in `baseline_representative_probe.log`; two baseline Krak tower
warnings disappear after the new facet placement.
`baseline_regression_probe.log` reproduces the three failure types
reported by the broad `cmassing` suite on the pre-aperture build: absent
forebuilding stair, gate-tower/wall-stair overlap, and tower-house door/window
counts. These are tracked as `CAS-REG-001` through `CAS-REG-003` rather than
attributed to this change. The exhaustive `cvoxelqa` and `castle cnormals`
runs were stopped after greatly exceeding the documented lane time;
`broad_sweep_partial.log` and `castle_normals_integration.log` are incomplete,
not passes. The bounded complete-CastleQA and normal probes above, along with
the aperture and gate fixtures, provide the acceptance evidence for the
changed hosts. The full castle lane remains red on the three proven baseline
massing defects.
