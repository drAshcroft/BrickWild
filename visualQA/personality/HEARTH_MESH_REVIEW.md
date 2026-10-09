# Hearth mesh measurement review - 2026-10-09

LIVE-HEARTH-MESH-CONTRACT is complete. This changes measurement only. Hearth realism remains open as LIVE-DOMESTIC-HEARTH-DESIGN.

The ordinary breast has an open mouth, trim lintel and recessed header. The former QA tested upper front-center wall faces where the emitter intentionally leaves a recess. QA now checks the actual named cheek, foot, lintel, header, jamb and mantel triangles on their logical material surfaces, and requires a mouth ray to reach the host-wall backing. Full-storey mass dimensions, wall contact, measured hearth fit, 20mm back gap and all furniture collisions remain enforced. Solid compatibility geometry remains checked.

The fixture removes exact cheek/lintel/header triangles, seals the assembled mouth, enlarges the logged mass by50mm, moves the actual hearth record by120mm, and inserts colliding furniture. Each changed input must fail the same production predicate. Root corrected unsupported sinf/cosf names in the staged fixture before native acceptance.

## Evidence

Receipts under artifacts/personality/resumed:

- restart18_hearth_fault_controls_typed: native0,14.994s,78 checks,zero failures against committed house geometry.
- restart18_hearth_committed_surface_host: native0,72.270s,full existing surface-host consumer,zero failures.
- restart18_hearth_committed_furnish: native1,41.787s,12 cases,18 older complaints. Comparison with committed baseline42 complaints removes exactly24 false front-face probes; every other complaint is identical. This is diagnostic evidence, not a full house QA pass.
- restart18_hearth_geometry_render_fixed: native0,22.426s,three roof-on hearth portraits. Root opened all three. The detached checkout omits external yard model instantiation explicitly because ignored Nature models are unavailable there; generation and shell/hearth geometry are preserved. Camera body clearance is unmeasured. The earlier six-view render with missing yard models is invalid and excluded.

The live full surface-host run fails one unrelated Witch work-station distance assertion. It is not claimed green. Isolated sources are committed c465003 house geometry with only this QA repair overlaid. No production emitter, model or catalogue is included in this commit.

## Visual finding

The images show a real framed recess with wall backing. They also show a pale empty firebox and a large cold cauldron in all three styles. These are unresolved design defects. Actual opening support is accepted; complete furnished-home quality is not.
