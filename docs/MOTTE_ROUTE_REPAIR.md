# Motte entrance and courtyard route repair

The README fixture is Norman motte seed 8856, 45 × 55 metres and height 6.
Its old tests missed missing occupied structures and stairs crossing masonry.
The current inventory derives required structures from the spec and geometry;
removing an interior record no longer removes its requirement.

Mural towers now have real curtain-walk galleries, floor-backed doors and stairs
inside their guardrooms. Corner galleries connect both adjoining curtain walks.
Guardrail returns leave those actual junctions open. Wall stair planning reserves
the flight and its final arrival corridor against towers and galleries.

The route checker measures emitted treads, headroom and body clearance, then
floods the actual curtain coping from verified stairs. All seven defensive
entrances must reach that network. It uses the shared WalkGrid and verifies the
local route through each doorway against the emitted mesh. Each lateral sweep
retains its own preceding floor height until the step is complete.

Window surrounds reserve the raised doors' opening intervals. Door clearance is
measured above the actual threshold, including the small step between a gallery
and a tower floor. A floor's vertical side below its walking surface is not a
standing obstruction. A retained-log shin-height blocker still fails the check.

On 3 October 2026 the combined gate passed 112 checks, zero failures and zero
warnings, native exit 0, in 176.81 seconds:

```powershell
& tools/run_qa_lane.ps1 -Selectors cmotteaccess,cmotteroute,wld005,hammammesh
```

Evidence: `artifacts/qa_fast/cmotteaccess__cmotteroute__wld005__hammammesh/20261003_002809`.
The full motte fixture contributes 84 checks and its structural companion 13.
Controls preserve logs while removing stairs, omit a required route record,
insert roof/body blockers, and obstruct a doorway above its threshold.

This fixture requires eleven occupied structures and twelve exterior doors.
Bailey shops are included when the generated spec requests them; they must not
be inferred from another fixture's inventory. The wider castle forms and their
scheduled regression gates remain open.

The final non-headless capture exited 0 in 111.61 seconds, with no script or
compile errors. Luna and the coordinating agent inspected the four fresh views.
Hero and ward frame the complete castle; entrance and flue are close studies.
The images and [preflight report](screenshots/motte_revision_qa.json) are copied
to `docs/screenshots/` with SHA-256 parity against the rendered originals.
The report records Godot 4.5.2, UTC capture time, source hashes and camera poses.
Its lighting, seating and small sanctuary navigation warnings remain visible.
