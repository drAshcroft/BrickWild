# Church bay composition review — 2026-10-09

`LIVE-SACRED-CHURCH-BAYS` is complete as a bounded geometry task. Sacred style identity and complete furnishing remain open.

Lower nave and outer aisle windows now use the real structural bay intervals. Compact lights respect the actual west tower and crossing perimeter. Style-specific supports retain timber for Nordic stave and stone for the other styles. Existing buttress stations are computed before emission so an exterior bearing is emitted exactly once.

The contract compares emitted component triangles, removes exactly the expected bearing triangles while preserving a neighboring wall triangle, and tests actual aperture rays with an inserted solid plug. Logical material slots are resolved to compressed physical mesh surfaces. The aperture suite retains all 235 assertions and repairs its blocked-bearing control using an actual overlapping window and shaft.

## Native evidence

All receipts are under `artifacts/personality/resumed/`.

| Receipt | Result |
|---|---|
| `restart9_church_bays_native_perimeter` | native0, 86.424 s, full sacred structural fixture, zero failures |
| `restart9_church_bays_change_perimeter` | native0, 30.900 s, 5,796 checks, zero failures, 12 existing warnings |
| `restart9_church_bays_dome_fixture` | native0, 5.172 s, 47 checks, zero failures or warnings |
| `restart9_church_isolated_geom_roofs` | native0, 75.356 s, 4,613 checks |
| `restart9_church_isolated_geom_components` | native0, 182.042 s, 2,775 checks |
| `restart9_church_isolated_geom_bounds` | native0, 89.797 s, 2,245 checks |
| `restart9_church_bays_final_original` | native0, 46.656 s, 18 images |
| `restart9_church_bays_final_vault` | native0, 23.006 s, six images |

The eleven original geometry selectors retain all 9,633 checks, with zero failures or warnings. They ran serially in an isolated checkout based on c465003, excluding unrelated Witch and Rotunda work. Aggregate time is 347.195 s; each process is below 300 s. The live combined roof attempt failed 207 unrelated Rotunda assertions and is not accepted evidence. Earlier bay fixtures and the first aperture negative-control attempt failed and are superseded by the receipts above.

## Visual review

Root opened all 18 original views and all six supplemental vault views. The six requests are Romanesque small seed 1; Gothic default 8102; Byzantine large 21325; Nordic stave small 8102; Renaissance default 21325; and Russian large 1. Final source hashes are recorded in the frozen `church_bay_opening_composition_v1/SHA256SUMS` packet.

Lights and structural bays now agree, and the nave frames remain visible. Nordic uses timber but still has pale, generic character. Large upper wall fields remain empty and seating remains repetitive. Gothic and Renaissance nave-to-aisle walls still appear closed: a separate arcade todo will reproduce and repair that interface. This evidence accepts bay geometry, not final church personality.

The frozen full matrix remains 234 requests and 702 original images; these six representatives are not full-matrix approval. Vault views are supplemental. Camera body clearance is unmeasured. Scheduled exhaustive gates remain separate.
