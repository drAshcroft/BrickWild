# CAS-009: Bergfried and Palas acceptance

The `bergfried` plan places a five-metre fighting tower beside a broad Palas
inside one compact polygonal ward. Norman castle sites between 42 and 55 m
may select it naturally; a plan override provides a fixed fixture. The
Bergfried has one raised side-facing door and a covered stair in the clear
gap to the Palas. Its top remains above the hall roof and all other masses.

## Structural checks

`cbergfried` covers the forced seed 918009 plan, a natural seed, and forced
42, 50 and 55 m sites on four- and six-sided wards. It checks the occupied
footprints against the actual inner polygon, tower slenderness, Palas volume,
mass dominance, the one raised door, and emitted shell. Six mutations must
fail the massing rule: an overwide keep, undersized Palas, over-tall corner
tower, displaced Palas, second keep door, and low keep door. The primary
fixture also probes emitted stair headroom and
the gate-to-stair-toe walk route. The physical probe caught a roof plane 8 mm
short of required headroom; its roof and cheeks were raised 0.30 m. The
ground-grid toe sample stays in the one-metre clear strip before the Palas
wall. The stair itself is probed at its actual height.

On the reconciled CAS-008/CAS-009 clone, editor registration exited 0
(`artifacts/cas009_editor.native_exit.txt`). `cbergfried` exited 0 with 19
checks, zero failures and zero warnings
(`artifacts/cas009_cbergfried.stdout.log`, native exit in
`artifacts/cas009_cbergfried.native_exit.txt`). The bounded
`lane:castle-change` exited 0 with five suites, 214 checks, zero failures
and five existing opening-probe warnings
(`artifacts/cas009_castle_change.stdout.log`, native exit in
`artifacts/cas009_castle_change.native_exit.txt`). The exact
`castle cmassing cvoxelqa` command then ran in that isolated tree, whose
production source and suite files were content-compared with the main
checkout. Its native exit was 0. The redirected stdout and exit file are
under `artifacts/cas009_reconciled_worktree/artifacts/cas009_clone_broad/`.

| Suite | Checks | Failures | Classified warnings | Body time |
|---|---:|---:|---:|---:|
| `castle` | 488 | 0 | 221 | 2,805.27 s |
| `cmassing` | 165 | 0 | 0 | 1,581.81 s |
| `cvoxelqa` | 123 | 0 | 291 | 3,479.37 s |

The 776-check gate took almost two hours. It is exhaustive regression
evidence, not a practical per-change gate. Routine castle work uses the
bounded `lane:castle-change` with the relevant focused fixture.

The main checkout initially registered `CastleInteriorPlans` from a stale
scratch copy in `artifacts/cas009_merge_tmp`. The tracked
`artifacts/.gdignore` excludes generated worktrees from Godot's class scan.
After editor registration mapped the class to
`src/castle/castle_interior_plans.gd`, the main checkout passed `cbergfried`
(19 checks, zero failures/warnings) and `lane:castle-change` (214 checks,
zero failures, five classified opening-probe warnings). Both native exits
are 0 under `artifacts/cas009_main/`. The main non-headless render also
exited 0; its three images were reviewed after correcting class discovery.

## Render review

`tools/render_cas009_bergfried.gd` assembles the fixed Norman castle and
writes three images under `artifacts/cas009_bergfried/renders/`. The final
non-headless run exited 0 (`artifacts/cas009_render.native_exit.txt`; output
in `artifacts/cas009_render.stdout.log`).

| View | Observation |
|---|---|
| `bergfried_palas_assembled.jpg` | The fighting tower reads as the tallest interior mass; the roofed Palas carries much more volume. Both sit within the polygon ward. |
| `bergfried_access_assembled.jpg` | The covered stair meets the tower beside the Palas; the roof obscures some treads from this camera. |
| `bergfried_palas_cutaway.jpg` | The removed roofs expose the full stair run and hall footprint. The stair toe and hall wall remain separate. |

The fixed view shows structural access and mass hierarchy, not detailed
historical decoration. The render stage is a flat reference plane. This
reconciled clone includes the CAS-008 Mont-Saint-Michel wall-stair clearance
repair; its bounded castle-change lane passed on this source.

```powershell
& 'C:\Projects\godot\Godot_v4.5.2-stable_mono_win64\Godot_v4.5.2-stable_mono_win64.exe' --path . --log-file artifacts/cas009_bergfried/godot_render.log --script res://tools/render_cas009_bergfried.gd
```
