# CAS-010 acceptance note

Prepared in `artifacts/cas010_cas009_integration_worktree` from frozen CAS-009 source, then integrated into main with the current five-minute QA protocol preserved.

## CAS-010 implementation

Terraced plans use nested polygon wards, a minimum 3 m ground rise at the inner ring, logged retaining fill that supports the lifted curtain, and a stair connecting the levels. The Himeji 100% fixture checks the tenshu base and its height above each curtain. Small Himeji sizes that cannot fit a walkable inner ward switch explicitly to a single-ring polygon while preserving the requested footprint. Physical route, overlap, fill, support, fallback, and failure-mutation controls are in `tests/suites/castle_terrace_suite.gd` and the massing/access suites.

## Main-worktree bounded evidence

The prepared clone passed editor registration, `cterrace` (3/0/0),
`lane:castle-change` (214/0/5), and `lane:geom` (6,975/0/0). Main was then
checked through `tools/run_qa_lane.ps1`, which captures native exit and wall
time and enforces a 300-second cap per invocation.

- `lane:castle-change,cterrace`: native exit 0, 160.74 seconds, 6 suites,
  217 checks, 0 failures, 5 existing opening-probe warnings. Log:
  `artifacts/qa_fast/lane_castle-change__cterrace/20260930_171101/`.
- `lane:geom`: native exit 0, 51.04 seconds, 10 suites, 6,975 checks,
  0 failures, 0 warnings. Log:
  `artifacts/qa_fast/lane_geom/20260930_171401/`.
- `chimeji`: native exit 0, 41 seconds, all four Himeji landmark scales,
  4 checks, 0 failures. Log: `artifacts/qa_fast/chimeji/20260930_172324/`.
- The real renderer completed with native exit 0 in 111.47 seconds.
  Log: `artifacts/cas010_main/render.*`; images:
  `artifacts/cas010/renders/`.

The following clone logs remain as preparation evidence. They are not the
main-worktree gate.

- Editor registration: `cas010_editor_clean_exit.txt` native exit 0. No script parse errors. Godot logged a platform root-certificate-store error and regenerated missing UID files; the UID files are generated cache metadata and are not part of the source delta.
- `cterrace`: `cterrace_exit.txt` native exit 0; 1 suite, 3 checks, 0 failures, 0 warnings. Full stdout and Godot log: `cterrace_stdout.log`, `cterrace.log`.
- `lane:castle-change`: `lane_castle_change_exit.txt` native exit 0; 5 suites, 214 checks, 0 failures, 5 opening-probe warnings. Full stdout and Godot log: `lane_castle_change_stdout.log`, `lane_castle_change.log`.
- `lane:geom`: `lane_geom_exit.txt` native exit 0; 10 suites, 6,975 checks, 0 failures, 0 warnings. Full stdout and Godot log: `lane_geom_stdout.log`, `lane_geom.log`.
- `git diff --check`: clean after the render-camera update.

The exhaustive `castle cmassing clandmark cvoxelqa` batch has not been run on
the integrated source. The current routine protocol schedules exhaustive seed
and voxel sweeps separately; bounded task completion does not imply they pass.
An exploratory full `clandmark` invocation hit the 300-second cap before its
summary and was stopped by exact PID. Log:
`artifacts/qa_fast/clandmark/20260930_171717/`. The Himeji-only selector uses
the same landmark assertions and completed in 41 seconds.

## Non-headless visual review

Godot used Vulkan on the RTX 3060. Main regenerated all six images with native
exit 0. The close stair shot shows continuous treads through the gate passage;
Himeji's tenshu clears the raised curtain; Edinburgh's two courtyard levels
are visible. The prepared clone's initial render native exit 0 is recorded in
`render_exit.txt`; the tighter Edinburgh rerender native exit 0 is in
`render_edinburgh_close_exit.txt`.

- `renders/himeji_terraced_assembled.jpg` and `renders/himeji_terraced_cutaway.jpg`: both raised ward levels are visible; the tenshu stands above the curtain line.
- `renders/himeji_terrace_stair_close.jpg`: continuous stone treads rise through the gate passage.
- `renders/edinburgh_terraced_assembled.jpg` and `renders/edinburgh_terraced_cutaway.jpg`: the tighter framing makes the outer and inner terraces legible.

The render stage is flat and has no surrounding terrain. The terrace retaining faces read clearly, but a hillside beyond the outer ward is absent.

## CAS-010-only file delta relative to `artifacts/cas009_reconciled_worktree`

- `core/mesh_kit.gd`
- `qa/castle_massing_check.gd`
- `qa/castle_qa.gd`
- `src/castle/castle_access_geometry.gd`
- `src/castle/castle_builder.gd`
- `src/castle/castle_generator.gd`
- `src/castle/castle_geometry.gd`
- `src/castle/castle_keep_plan.gd`
- `src/castle/castle_spec.gd`
- `tests/run_all_impl.gd`
- `tests/suites/castle_landmark_suite.gd`
- `tests/suites/castle_terrace_suite.gd` (new)
- `tools/render_cas010_terraces.gd` (new; Edinburgh-only mode supports camera rerender)
- `docs/CAS_010_ACCEPTANCE.md` (this note)

Water/front-axis geometry, Mont access reservation, Bergfried/Palas source and fixtures were preserved from CAS-009 integration. The above list is the content delta; editor-generated `.uid` files are excluded.
