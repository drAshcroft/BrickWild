# CAS-008: water castle acceptance

## Geometry and access

Water plans emit 2-4 m deep negative trench masses at 8-25 m width on every
side of the enceinte. The front-axis trench continues under a raised causeway
or drawbridge; the visible water sheets are kept off structural voxel and walk
surfaces. Bodiam uses one ring and Caerphilly uses two. The water fixture
checks all six named side segments, a voxel void below the crossing, a solid
causeway, and missing or displaced segment controls.

The first broad landmark run exposed small-scale facade windows, raised keep
stairs, and one Mont-Saint-Michel inner-gate overlap. These were repaired in
the shared castle geometry. A later broad run exposed a Mont wall stair
crossing the forebuilding. The wall-stair planner now reserves the emitted
forebuilding overhang before selecting two independent stairs per ring. The
fixed Mont fixture checks both planned footprints and emitted stair mass
boxes.

## Bounded verification on the final source

All runs used Godot 4.5.2. Long tests wrote redirected logs and native exit
files under `artifacts/`.

| Gate | Result | Log |
|---|---|---|
| Editor registration in main | Exit 0; no script parse errors | `artifacts/cas008_main/final_editor.stdout.log` |
| `cwater` in integrated copy | Exit 0; 9 checks, 0 failures or warnings | `artifacts/cas008_integration/cwater.stdout.log` |
| `lane:geom` in integrated copy | Exit 0; 6,975 checks, 0 failures or warnings | `artifacts/cas008_integration/lane_geom.stdout.log` |
| `lane:castle-change` in integrated copy | Exit 0; 195 checks, 0 failures, 5 classified opening warnings | `artifacts/cas008_integration/lane_castle-change.stdout.log` |
| Mont .70/1.00 fixed fixture | Exit 0; 26 checks, 0 failures | `artifacts/cas008_montstair_worktree/artifacts/cas008_montstair/mont_stairs.stdout.log` |
| `caccess` in patched isolated copy | Exit 0; 228 checks, 0 failures or warnings | `artifacts/cas008_montstair_worktree/artifacts/cas008_montstair/caccess.stdout.log` |
| `cforebuilding` in patched isolated copy | Exit 0; 109 checks, 0 failures or warnings | `artifacts/cas008_montstair_worktree/artifacts/cas008_montstair/cforebuilding.stdout.log` |

The five castle-change warnings are the existing blocked-opening probes on a
round hall and battered keep. They are classified warnings, not failures.

## Render review

The non-headless assembled Bodiam view shows blue water around the island and
a pale road reaching the gate. Caerphilly shows two separate blue moat bands,
a narrow dry divider, and the aligned gate approach. The final-main captures
are in `artifacts/cas008/renders/` and can be
recreated with `tools/render_cas008_water.gd`. The flat beige reference stage
does not show excavation depth; the negative mass and voxel probes measure
that depth. Both captures saved successfully with native exit 0
(`artifacts/cas008_main/render.stdout.log`). Their image hashes match the
earlier integrated captures reviewed visually.

The assembled Mont 1.00 view in
`artifacts/cas008_montstair_worktree/artifacts/cas008_montstair/`
shows a coherent courtyard and the central roofed keep stair. The wall-stair
feet are small from this wide camera, so the emitted mass fixture supplies
the exact clearance evidence.

## Exhaustive acceptance

The exact final-main command is `godot --headless --path . --script
res://tests/run_all.gd -- castle cmassing clandmark cvoxelqa`. Its redirected
log and native exit are `artifacts/cas008_main/final.stdout.log` and
`artifacts/cas008_main/final.exit.txt`.

The combined run exited 0: 868 checks, 0 failures and 512 classified
warnings.

| Suite | Checks | Failures | Warnings | Elapsed |
|---|---:|---:|---:|---:|
| `castle` | 488 | 0 | 221 | 2,461.92 s |
| `cmassing` | 165 | 0 | 0 | 1,482.80 s |
| `clandmark` | 92 | 0 | 0 | 1,290.77 s |
| `cvoxelqa` | 123 | 0 | 291 | 2,280.61 s |

The landmark sweep reported zero defects at all four scales for each listed
site, including Bodiam, Caerphilly, and Mont-Saint-Michel. Its printed
expected-fail notes for Edinburgh's future terraced form and Mont's church
composition remain annotations, not failures. The voxel warnings are
classified interior/daylight and opening observations; the native suite
verdict is PASS. The only stderr message concerns the Windows root certificate
store and did not affect the tests.
