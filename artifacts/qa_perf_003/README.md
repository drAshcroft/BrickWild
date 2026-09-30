# QA-PERF-003 evidence

The baseline is commit `29e30e8`; the optimized run is the change in this
commit. The original full Byzantine seed 5003 profile was stopped after face 2
reached 12,356 pieces. The optimized run finished. Both use Godot 4.5.2 Mono.

| Evidence | Result |
|---|---|
| [Original full profile](profile_seed5003.log) | 8 faces, 1,248 volumes; face 2 still growing at 81.31 s and volume 1,100 |
| [Optimized full profile](profile_seed5003_after.log) | Finished in 779 ms with temporary face counters enabled |
| [Final fixed seed](seed5003_final.log) | 710 ms; 7,704 roof vertices |
| [Final Hagia Sophia scale 1](hagia_final.log) | 539 ms; 7,896 roof vertices |
| [Original 100-volume fixture](surface_baseline.log) | 7,942 ms; 16,796 roof triangles |
| [Optimized 100-volume fixture](surface_after.log) | 360 ms; 1,776 roof triangles |
| [Surface comparison](surface_compare.json) | 286/289 sampled rays exact at 1 mm rounding; other three differ by 1 mm |
| [Final bounded church lane](church_change_final.log) | 5,388 checks; zero failures or warnings |
| [Dome fixture](dome_fixture.log) | 20 checks pass |
| [Roof seams](roof_seams.log) | 49 checks pass |
| [Church apertures](church_aperture.log) | 204 checks pass |
| [Negative probe](negative_probe.log) | Omitting volume cuts exposes roof inside the half-dome at 38 samples |

The reproducible [100-volume surface probe](roof_surface_probe.gd) produced
the [baseline](samples_baseline.json) and [optimized](samples.json) height
arrays. The part, mass and component log digest is the same in both runs:
`bec2d17bc3e9911a22cd2cdb14f3eb9182e9d1768f322c14b92438634ae80d43`.
Raw triangles differ because the baseline subdivided pieces outside the cut.

The optimized [Hagia front](renders/hagia_front.png),
[Hagia raking](renders/hagia_raking.png),
[Florence front](renders/florence_front.png), and
[Florence raking](renders/florence_raking.png) renders use the cameras and
lighting in `tools/render_church_dome_acceptance.gd`. Compare them with the
[same-camera baseline pairs](../vis008/after/). The
[pixel comparison](render_compare.log) found 1.2–2.2% changed pixels, with
small color differences; visual inspection found the same exposed forms.

The full original seed 5003 build has no finished baseline raw mesh digest.
The partial fixture and views constrain the geometry claim; they do not prove
bitwise identity at every point.
