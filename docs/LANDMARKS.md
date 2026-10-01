# Landmark reference

Real dimensions and defining features for the churches the generator is
expected to be able to build. Sources listed at the bottom.

| Church | Style | Nave W x L x H (m) | Defining features |
|---|---|---|---|
| Notre-Dame de Paris | Gothic | 12 x 127 x 33 (overall 40 wide) | 36 flying buttresses (apse flyers span 15 m), **double aisles**, twin west towers 69 m, short transept, apsidal chapels, rose windows |
| Cologne | High Gothic | 144.5 long, nave 43.58 high, aisles 19.8 | **Five-aisled**, twin spires 157 m, transept 86.25 m wide, Latin cross |
| Chartres | Gothic | 16.4 x 130.2 x 37.5 | Widest Gothic nave; **double ambulatory**, **seven radiating chapels**, transept 64 m |
| Salisbury | Gothic | 135 long, transepts 62.5 across | Single dominant **crossing spire** (123 m) |
| Durham | Romanesque | 11.9 x 61 x 22.2 (total 143 long) | **Central lantern tower** (66 m) plus twin west towers (44 m) |
| Hagia Sophia | Byzantine | ~70 x 76 | **Central dome 31.7 m diameter, 55.6 m high, on pendentives**; buttressing **half-domes** east and west; smaller semi-domed **exedrae**; 40-window corona |
| Florence Duomo | Renaissance | 153 long, 90 at transept | **Octagonal drum + double-shell dome** (45.5 m inner diameter, 90 m to lantern base); three radial tribunes of five chapels each |
| St Basil's | Russian | central chapel 46 m internal | **Nine chapels around a central tent**, total 65 m; **onion domes**, eight arranged in a star |


## Feature checklist this drives

- flying buttresses (pier + flyer arch + pinnacle)
- domes: hemispherical, onion, octagonal drum, half-dome, lantern, oculus ring
- alcoves: radiating chapels, ambulatory, apsidal chapels, exedrae
- twin west towers, and a crossing tower/lantern
- multiple aisle pairs (single, double, and the five-aisled section)

## Hero composition (EVAL-B03)

Three of these buildings are read by one feature, so they are composed rather
than rolled. `ChurchGenerator.apply_landmark(spec, key)` runs after
`generate()`, sets `spec.hero` and sizes the parts from the figures above; every
hero rule in `ChurchGeometry` and `ChurchBuilder` is gated on `spec.hero`, so a
randomly generated church is byte-for-byte unchanged (90 sweep churches
fingerprinted before and after). The landmark suite, `render_shots.gd` and the
`vis010` fixture all call it, so they cannot disagree.

| Hero | Landmark rows used | What the mesh builds |
|---|---|---|
| `florence` | length is the OVERALL 153 m; the nave is shortened so nave, crossing and east tribune add up to it. Dome 45 m of 153 (`FLORENCE_DOME_RATIO` 0.14) | an octagonal crossing block as wide as the dome (the drum stands back from it on a chamfered ledge), three tribunes (east, south, north) round it, four nave bays with a pilaster on every bay edge, one tall aisle light and two modest round-headed clerestory lights per bay, the eight-sided shell and a lantern sized for its dome |
| `basil` | core 24 x 30 x 26 m (the earlier 12 x 46 row made a long box that no ring of chapels could surround); the real 65 m total comes from the tent | a podium (two stone courses, the door lifted onto it), a porch on the west where the ring opens, a tented core (eight-gored tent, stone bands, small gilded onion), eight chapels at staggered heights each with a windowed drum and its own painted onion (own vertex-coloured surface, `SURF_ACCENT`) |
| `hagia` | 31 x 76 x 40 m, dome 0.45 of the width | a shallow-roofed nave in bays (one tall arched clerestory light per bay, aisle arcade, pilasters), the drum on a square masonry bearing (vertical faces, windows under the north and south arches, a pier at each corner) with the four great arches drawn on its faces, half-domes springing from the bearing's east and west faces and crowning at its top, then the apse |

Checks: `landmark` (required masses, bay rhythm, Florence proportions, eight
distinct chapel heights), `vis010` (the blueprint inventory draws the same
rows), `vis016` (the Hagia bearing is a masonry block with a solid wall and an
open throat, not a flared skirt) and `lane:church-change` (normals and openings
of all three hero meshes).

## Sources

- https://en.wikipedia.org/wiki/Notre-Dame_de_Paris
- https://www.eutouring.com/facts_notre_dame_cathedral.html
- https://en.wikipedia.org/wiki/Cologne_Cathedral
- https://www.colognecathedral.de/blog/cologne-cathedral-architecture.html
- https://www.chartres-tourisme.com/en/the-cathedral/history-of-chartres-cathedral/dimensions
- https://en.wikipedia.org/wiki/Salisbury_Cathedral
- https://en.wikipedia.org/wiki/Durham_Cathedral
- http://www.medart.pitt.edu/image/england/durham/cathedral/Durhamcath-dimens-2.html
- https://en.wikipedia.org/wiki/Hagia_Sophia
- https://www.hagiasophia.com/hagia-sophia-dome
- https://duomo.firenze.it/en/discover/dome
- https://en.wikipedia.org/wiki/Saint_Basil%27s_Cathedral
# Clerestory rhythm

Gothic flying buttresses require a visible upper window course. `ChurchGeometry.clerestory_windows()` places one opening between adjacent nave piers, with its sill above the actual aisle roof slab and its crown below the nave eaves. `aisle_roof_high()` is shared by the roofs and window layout, including multiple aisle rings. The builder uses the church's pointed or rounded arch profile, plus a thin mullion and sill.

The landmark suite checks the emitted opening records against roof clearance and pier spacing. `tests/clerestory_test.gd` removes the course deliberately at three scales to prove the check detects a blank clerestory. `tools/render_clerestory.gd` produces Notre-Dame and Cologne close views in `artifacts/church_roofs/`.
