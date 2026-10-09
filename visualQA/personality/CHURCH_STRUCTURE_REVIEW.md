# Occupied church structure review — 2026-10-09

This records the bounded `LIVE-SACRED-CHURCH` architecture slice. The wider
`LIVE-SACRED` style, furnishing and visual acceptance work remains open.

## Geometry and materials

Nave frames now have actual wall bearings. Gothic heads use the same curved
profile in their openings and emitted ribs. Nordic frames and shell walls use
the logical timber surface; later glazing and dome painting preserve that
material even when an empty accent stream compresses the physical surface list.
Crossing towers begin at their bearing elevation. Dome transitions, open apse
mouths, and the ambulatory's annular paving and roof preserve occupied space.

Render review exposed a separate obstruction: the former string course was a
solid rectangle across the entire nave at 62% of wall height. Actual scene-ray
traces hit its trim underside. It is now a series of named exterior wall runs,
cut around the same openings used to build the nave and each west tower. These
facade components have matching part records and no fictitious structural mass.

## Native evidence

Receipts are under `artifacts/personality/resumed/`.

| Gate | Receipt | Result |
|---|---|---|
| Full structural contract and 48 course cases | `restart7_church_perimeter_fixture_v2` | native0, 74.227 s, zero failures |
| Church change lane and aperture suite | `restart7_church_perimeter_lane_override_fixed` | native0, 45.555 s, 5,796 checks, zero failures, 12 existing warnings |
| Dome support and shell fixture | `restart7_vis008_perimeter` | native0, 5.377 s, 47 checks, zero failures or warnings |
| Geometry lane: roof partition | `restart7_geom_roof` | native0, 155.574 s, 4,613 checks, zero failures or warnings |
| Geometry lane: component/opening/material partition | `restart7_geom_parts` | native0, 296.163 s, 2,775 checks, zero failures or warnings |
| Geometry lane: bounds partition | `restart7_geom_bounds_serial` | native0, 175.561 s, 2,245 checks, zero failures or warnings |
| Actual render selectors and frozen matrix | `restart7_sacred_selector_contract` | native0, 9.426 s, all assertions pass |
| Original six-request render set | `restart7_church_perimeter_original18` | native0, 44.643 s, 18 images |
| Supplemental upward views | `restart7_church_perimeter_vault6` | native0, 25.394 s, six images |
| Exact CLI seed-8102 capture | `restart7_sacred_seed8102_render` | native0, 14.921 s, one Nordic small axis image |

The course fixture retains 18 canonical sweep cases, adds the 18 frozen
small/default/large style cases, and checks 12 explicit single/twin-tower cases.
The same cross-course ray must clear the real mesh and reject the exact former
12-triangle slab injected into its trim surface. All opaque structural material
slots participate. Each expected tower has a complete recorded perimeter.
Existing geometry-removal, sealed-opening and painter-collision controls remain.

Initial course attempts failed parsing; they are retained as failed receipts.
The first test draft was rejected before execution because its positive rays
did not cross the course and its nave-opening lookup used the wrong host name.
None of these attempts is reported as passing evidence.

The three geometry partitions retain all eleven original `lane:geom` selectors:
9,633 checks total. Each process finishes below 300 seconds; 627.298 s is their
aggregate, not a passing combined invocation. An accidentally overlapping bounds
process was stopped at 62.156 s and excluded. Its fresh serial replacement above
passes. The parts partition passed under the temporary extra load.

## Visual assessment and limits

Root opened all 18 original images and all six supplemental upward views for:

| Style | Size | Seed |
|---|---|---|
| Romanesque | small | 1 |
| Gothic | default | 8102 |
| Byzantine | large | 21325 |
| Nordic stave | small | 8102 |
| Renaissance | default | 21325 |
| Russian | large | 1 |

The nave arches and timber trusses are now visible from inside; the Russian
upward view exposes the supported dome interior. The nave roof no longer
vanishes behind an unintended flat trim ceiling. Byzantine and Renaissance
entrance views emphasize the long nave rather than fully exposing their distant
crossing domes. The measured structural contracts supply the corresponding
geometry evidence; those entrance images alone do not prove a dome interior.

Large blank wall areas, tiny high openings, repetitive seating and generic altar
dressing remain design work. Nordic timber is pale and its character still needs
review. Some roof trim survives cutaway visibility and appears detached there.
These are not accepted as final style identity. Camera body clearance against
shell and props remains explicitly unmeasured. The supplemental `vault` view
does not replace the original axis view or change the frozen 234 requests and
702 original images. Scheduled exhaustive sweeps remain separate.
