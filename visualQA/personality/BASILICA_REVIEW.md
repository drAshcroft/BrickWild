# Basilica architecture review — 2026-10-08

This completes the bounded `LIVE-SACRED-BASILICA` architecture slice.
`LIVE-SACRED` remains in progress.

The cited barn-like walk request is `temple/basilica/default/1`: blood cult,
26 × 44 × 12 m, seed 1. The same seed was reviewed at the frozen small
(18 × 24 × 8 m) and large (48 × 80 × 20 m) sizes. No fixture dimensions were
changed to suit the implementation.

## Result and implementation

The basilica now has a raised central nave, lower side aisles and a projecting
pronaos. The generated inner colonnade carries longitudinal architraves and the
clerestory masonry above. Real openings admit light above the aisle roofs.
Front columns and side beams carry the entrance roof. Gable returns close the
ends, with thickness extruded along each profile's actual normal. The fallback
without inner columns bears its roof on the actual shell walls.

The entrance paving continues through the wall gate to the interior floor.
Placement retains the real door position and publishes the supported approach;
the site reservation includes the actual outworks. Rite QA uses that full
reservation. Neither a moved metadata door nor a fictitious floor is used.

## Verification

All receipts are under `artifacts/personality/resumed/`.

| Gate | Receipt directory | Result |
|---|---|---|
| Three-size emitted geometry and mutation controls | `restart4_basilica_v6_fixture_slot_fixed` | native 0, 52.168 s, no fixture failures |
| Temple and rite regression, corrected source | `restart5_basilica_v6_temple_lane` | native 0, 150.978 s; 3,737 checks, no failures or warnings |
| Focused public basilica/Gothic API | `restart4_sacred_api_v6_focus` | native 0, 27.532 s; 25 checks, no failures or warnings |
| Canonical library basilica seed 404 | `restart4_api_temple_404` | native 0, 20.495 s; 19 checks, no failures or warnings |
| Three-size public assembled renders | `restart5_basilica_v6_three_sizes` | native 0, 50.211 s; nine images, unchanged source during capture |
| Complete canonical quick library coverage | `restart5_library_parts` | eleven native0 processes, 195 checks; full union validated, 702.046 s aggregate |
| Complete canonical quick placement coverage | `restart5_placement_parts` | thirteen native0 processes, 31 checks; eighteen-marker union validated, 434.399 s aggregate |
| Remaining quick API-lane suites | `restart5_api_remaining_scene_cleanup` | native0, 153.899 s; 264 checks, no failures, warnings or engine errors |

Each library and placement process finishes under 300 seconds. Their source
fingerprints are unchanged within each complete batch. The original combined
selectors timed out and are not reported as passes. The partition drivers reuse
the canonical assertions, including invalid requests and orientation controls;
see the two API partition documents for coverage. These bounded processes
collectively retain the required quick API-lane checks.

The focused fixture checks actual emitted triangles, roof sections, load-path
contact, clerestory apertures, body-width paving and the entrance route. Its
controls remove actual column/floor/roof triangles, lift the entrance roof,
fill a clerestory opening, block the approach and extrude a gable on the wrong
axis. Zero-area triangles fail. An isolated one-surface mesh prevents empty
material slots from making the component-parity test vacuous.

## Render review

Root opened all nine fresh images in
`restart5_basilica_v6_three_sizes/renders/temple/{small,default,large}/`:
`basilica_blood_{exterior,axis,cutaway}_1.jpg`.

The roof-on views show the nave/aisle hierarchy and the supported entrance at
all three scales. The axis views show a coherent central procession framed by
colonnades. Cutaways show the longitudinal clerestory walls and transverse
ties over the occupied hall. This is accepted as a structural architectural
improvement over the single roofed box.

Default and large interiors are still dark. Repeated braziers, broad masonry
walls and the generic stepped rear spire need further design work. Cult
personality is not accepted by this slice. These images do not prove every
seed, cult or temple form, nor sacred camera body clearance. The complete
234-request/702-image sacred review remains a separate gate.
