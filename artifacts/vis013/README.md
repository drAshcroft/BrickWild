# VIS-013: unplanned round and shell keep apertures

The old `CastleBuilder._build_keep` fallback emitted a complete 14-sided drum
and placed four shallow dark window boxes on it. Its east and west window
positions also fell between emitted facets. The new fallback partitions four
chosen facets around through openings. The opening log, stone partition and
trim use each facet's actual chord and outward normal.

## Scope correction

This fallback is **not** the source of Bodiam's or Krak's default keep
appearance. The fixed landmark seeds (`6001`, `6002`) both select `shell` and
produce valid `CastleKeepPlan` layouts with 40 planned windows. Bodiam's built
keep log also contains 40 planned windows. `CastleBuilder._build_keep` selects
`CastleInteriors.emit` for a valid plan, so the fallback change does not touch
those landmark keep meshes or their circulation. The original VIS-013 priority
and Bodiam/Krak render acceptance claim were based on the wrong path.

## Evidence

- [Before front](renders/round_keep_before_front.png) / [after front](renders/round_keep_after_front.png)
- [Before raking](renders/round_keep_before_raking.png) / [after raking](renders/round_keep_after_raking.png)

The fixture uses the exact old drum plus `_shell_openings` branch and the new
`_cut_keep_drum` branch, the same 14 facets, material, light and camera in each
pair. The old opening reads as a shallow flat patch. The new opening has a
visible return and a view through the keep. These are isolated fallback fixtures, not
claims that the two landmark portraits changed.

`caperture cgateaccess` passed 88 checks with no failures or warnings. The
aperture fixture checks both zero and rotated drums, all-surface centre rays,
adjacent masonry, logged returns, and the round and shell `_build_keep` routes.
The [focused log](focused.log) records the result. The exhaustive castle lane
was not rerun here: VIS-006 recorded pre-existing `cmassing` failures and
excessive castle sweep runtime under CAS-REG-001/002/003 and QA-PERF-001.
