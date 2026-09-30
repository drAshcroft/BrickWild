# CAS-004: current castle access acceptance

The gatehouse guides, drawbridge, wall-walk stairs, and protected keep entrance
were implemented before this review. Acceptance started at `7ea0e71` on
2026-09-30 and exposed failures in castle interior plans. This record checks
their repair on the integrated tree. The exterior acceptance renderer is
`tools/render_cas004_acceptance.gd`; it uses fixed seeds and camera positions
and builds the assembled castle scene.

## Render review

| View | Seed | Observation |
|---|---:|---|
| `gate_front.png`, `gate_raking.png` | Crusader fortress 9118 | The bridge reaches the outer passage. Its 2.4 m deck is small beside the gate towers at castle scale. |
| `bridge_close.png` | Crusader fortress 9118 | The deck and suspension guides are visible at the passage mouth. |
| `keep_front.png`, `keep_raking.png` | Norman fortress 9119 | A roofed forebuilding reaches the raised keep face. From the wide views it reads as a narrow wedge. |
| `keep_stair_close.png` | Norman fortress 9119 | The ground-level mouth is open and the 74 emitted treads climb inside the shelter to a 14.67 m raised entry. |
| `keep_arrival.png` | Norman fortress 9119 | A camera on the top landing looks through the open keep doorway to the now-furnished hall table and chair. |
| `norman_fortress_keep_cutaway.jpg` | Norman fortress 9119 | A diagnostic single-storey cutaway shows the newly placed hall table and chair as loaded models. The full keep interior remains sparse at this scale. |
| `wizard_tower_raised_door_stair.jpg` | Wizard tower 12012 | The 1.22 m raised doorway is visibly open, with ascending treads behind it. |

The images are in `artifacts/cas004_current/renders/`. That directory is
ignored by Git; the render scripts are the reproducible source. The two
interior diagnostics are in `artifacts/renders/cas004_acceptance/` and come
from `tools/render_cas004_interiors.gd`. The reference
stage is flat, so it does not show the ditch below the bridge. The portcullis
guides sit inside the passage and are not legible in the wide views. These
details remain visually schematic at castle scale, although the close views
show the physical route.

## Structural checks

The suites include negative controls for missing stairs, missing protected
forebuilding parts, blocked headroom, and missing gate-access logs. The
exhaustive `castle cmassing cvoxelqa` gate covers the complete style and seed
sweep. A bounded lane does not replace it.

| Suite | Result | Log |
|---|---|---|
| `caccess` | Exit 0; 199 checks, zero failures or warnings | `artifacts/cas004_acceptance/caccess_exact.log` |
| `cforebuilding` | Exit 0; 105 checks, zero failures or warnings | `artifacts/cas004_acceptance/cforebuilding.log` |
| `cgateaccess` | Exit 0; 16 checks, zero failures or warnings | `artifacts/cas004_acceptance/cgateaccess.log` |
| `lane:castle-change` | Exit 0; 195 checks, zero failures, five pending opening-probe warnings | `artifacts/cas004_acceptance/castle-change.log` |
| `lane:dress` | Exit 0; 1,170 checks, zero failures, 32 classified warnings. Covers the shared furnisher change. | `artifacts/cas004_acceptance/dress.log` |
| Isolated forebuilding speed repair | Exit 0; 105 checks, zero failures or warnings. Fixed Norman fortress output is byte-for-byte identical for the occupied plan and forebuilding record. | `artifacts/cas004_perf_worktree/artifacts/cas004_acceptance/perf_cforebuilding.log`; `artifacts/cas004_acceptance/probe_main_engine.log`; `artifacts/cas004_perf_worktree/artifacts/cas004_acceptance/probe_perf_engine.log` |
| Final-source focused gate | Complete runner summary: seven suites, 515 checks, zero failures, five known opening-probe warnings. The attached PowerShell command exited 0; the Godot process exit-code property was unavailable in its sidecar. | `artifacts/cas004_acceptance/focused_optimized.log` |
| Optimized exhaustive castle and massing phases | The current-main combined runner completed `castle` in 2,762.24 s with no failure lines, then completed `cmassing` in 1,535.58 s with zero defective variants in each of the four scale classes. The duplicate voxel phase was stopped after a separate exact `cvoxelqa` run had begun; this combined invocation has no aggregate verdict. | `artifacts/cas004_acceptance/broad_optimized.log` |
| Optimized exact `cvoxelqa` | Complete runner summary: 123 checks, zero failures, 291 classified warnings. The attached PowerShell command exited 0; its Godot process exit-code sidecar says `MISSING`. This suite used the same current-main source as the optimized castle and massing phases. | `artifacts/cas004_acceptance/cvoxel_optimized.log` |
| `castle cmassing cvoxelqa` | `castle` passed 488 checks; `cmassing` failed one stale tower-house negative fixture; `cvoxelqa` failed 44 of 123 checks, mostly generated interior programme and circulation. The combined run failed. | `artifacts/cas004_acceptance/broad_retry.log` |
| Repaired combined gate | The current-main `castle` phase finished after 5,354.24 s with no failure lines and the runner entered `cmassing`. Its detached engine and wrapper stopped before writing a native exit or later suite verdict. This is incomplete evidence, so the three exhaustive suites are being captured separately. | `artifacts/cas004_acceptance/broad_final.log` |
| Repaired `cmassing` | Full isolated rerun and current-main rerun each passed 155 checks, zero failures or warnings, after a focused six-check fixture pass. The final broad gate will repeat massing after the voxel-related production repairs. | `artifacts/cas004_fixture_worktree/artifacts/cmassing_fixed.log`; `artifacts/cas004_acceptance/cmassing_main.log` |
| Repaired castle focused gate | Isolated worktree and current main each passed 7 suites, 1,052 checks, zero failures, 27 classified warnings. Current-main native exit 0. | `artifacts/cas004_cvoxel_worktree/artifacts/cas004_acceptance/castle_change_gate.log`; `artifacts/cas004_acceptance/focused_main.log` |
| Pre-speed-fix exhaustive runs | Current main `cmassing` completed 155 checks, zero failures or warnings; its wrapper wrote an empty exit file. `cvoxelqa` exited 0 with 123 checks, zero failures, 291 classified warnings. Both preceded the two-file forebuilding speed repair, so the final integrated revision still requires the exhaustive gate. | `artifacts/cas004_acceptance/cmassing_final.log`; `artifacts/cas004_acceptance/cvoxel_final.log` |

The tower-house `lift` negative control searched only for a legacy `window`
tag. Planned openings use their host tag, so the fixture did not lower any
window. The repair selects an emitted window and first asserts that one was
found; `TowerCheck` must then reject its ground-level sill. This changes a
test fixture only; castle generation and emitted geometry are unchanged.

The voxel failures led to bounded required furnishing in oversized keeps,
public parlours between guest rooms, staggered range link doors, relocation
of one buried front door, and a wider narrow-shaft wizard entrance with
wall-adjacent stair footprints. The wizard tower omits a hearth prop because
it has no flue. Fixed-case QA and renders support these repairs. The final
source completed all three exhaustive suites: castle and massing as full
phases of the combined run, and voxel QA as an exact standalone run with a
complete passing summary.

The first repaired broad castle phase took 5,354 seconds because each
forebuilding query furnished an oversized keep merely to find its doorway.
The final source now builds a structural plan for that query and furnishes
only the occupied keep plan. A fixed Norman fortress probe measured a
forebuilding query at 5,773 ms before and 31 ms after the change; the occupied
plan and forebuilding record were identical. The final broad phases above
were run after this source change.

Run non-headless renders with a workspace log path:

```powershell
New-Item -ItemType Directory -Force -Path artifacts/cas004_current | Out-Null
& 'C:\Projects\godot\Godot_v4.5.2-stable_mono_win64\Godot_v4.5.2-stable_mono_win64.exe' --path . --log-file artifacts/cas004_current/render_godot.log --script res://tools/render_cas004_acceptance.gd
& 'C:\Projects\godot\Godot_v4.5.2-stable_mono_win64\Godot_v4.5.2-stable_mono_win64.exe' --path . --log-file artifacts/cas004_current/bridge_godot.log --script res://tools/render_cas004_acceptance.gd -- bridge
& 'C:\Projects\godot\Godot_v4.5.2-stable_mono_win64\Godot_v4.5.2-stable_mono_win64.exe' --path . --log-file artifacts/cas004_current/arrival_godot.log --script res://tools/render_cas004_acceptance.gd -- arrival
& 'C:\Projects\godot\Godot_v4.5.2-stable_mono_win64\Godot_v4.5.2-stable_mono_win64.exe' --path . --log-file artifacts/cas004_current/interiors_godot.log --script res://tools/render_cas004_interiors.gd
```
