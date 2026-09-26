# Village boundaries and usable entrances

The final lot planner authors `VillagePlan.enclosure` and `gate_crossings`
after road trimming and before dressing. The boundary is the lot hull offset
by six metres, clipped one metre inside the available site. Clipping matters:
an offset beyond the ground also lies beyond the road endpoints and silently
leaves a village without an entrance.

Every actual segment intersection is recorded, including two crossings on a
single straight road. Nearby points are never projected onto the boundary.
Main roads receive gateways; field tracks and other minor roads receive
posterns. Records retain the road and edge indices, position, road direction,
edge tangent, road clearance width and oblique opening span. Equality and the
typed document codec preserve these data. Unenclosed villages use through-road
site endpoints as arrival points; enclosed villages use their actual gates.

The builder cuts the whole carriageway out of the wall, aligns the portal
with its boundary, and emits posts and an overhead lintel. A closed fence
panel is inappropriate across this working route. A masonry boundary has an
inward timber guard walk with grounded steps and an inner rail. Hedge
boundaries use measured plants from the culture palette above a low bank;
neighbouring shrubs overlap intentionally, while water, roads and roofs stay
clear. Natural shores remain open and mill channels retain culverts.

The walk grid blocks the solid boundary runs and keeps the gateway openings.
Road QA independently intersects roads and the boundary, checks record indices,
widths, entrance types and both surface contacts, and rejects a completed
enclosed settlement with no entrance. Focused tests additionally cast physical
rays through the emitted portals, compare component records with triangles,
round-trip the data and inject closed leaves, missing gates and stale indices.

Current evidence: 93 gateway checks, 97 bridge/navigation checks, 752 focused
enclosure checks, 251 water-plan checks, 356 mill checks and 256 measured-adit
checks pass.
The 750 focused enclosure cases use site plans with representative lots; they
do not replace the outstanding fully populated enclosure/water acceptance
matrix. Reference renders are produced by `tools/render_village_gates.gd`.

Run the populated enclosure/water acceptance matrix with
`tests/village_enclosure_full_test.gd`. Its default is fifty complete native
garrison programmes across all fifteen enclosure/water pairs. `--start=N
--count=N` selects a disjoint seed slice. Measurements are reused only after
the complete request JSON matches; each case still runs the production site,
lot retries, final crossings, enclosure and dressing pipeline. The matrix
requires every earned building, density/site bounds, lot fit, dry far-side
wood, real hedge coverage and the road crossing/gate checks. Its first seed
also compares the encoded result with ordinary fresh native generation.
The request identities and multiplicities must match the complete programme.
Each coastal plan also checks every native building's full bounds against
the site, dry structural envelopes, the manor's private lane, and the lots'
fire gaps. A working mill with its actual race and wheel may project eaves
over the bank; its measured walls must remain dry. Ordinary and civic buildings
retain the full-bounds dry check. Translating the actual mill walls into the
sea, or removing its race association, is rejected by the same check.
Native measurements use a test-only cache keyed by exact request JSON, Godot
version, native source contents, catalogue and project configuration. Typed
jobs retain their full placement data; count, fields, request identity and a
payload checksum are checked before reuse. Corrupt entries regenerate.
Planner-only changes still rerun every site/lot/dressing/QA step. The fresh
ordinary-generation parity control bypasses the cache.

`--controls` runs the quick mutations alone. A requested hedge no longer
counts as visible plants: removing its actual row fails the edge rule. Trees
must root on dry land beside every water kind, and an underwater tree cannot
satisfy the far-side wood rule. The isolated mill suite authors its final
crossings and boundary before dressing, exactly as the populated planner does.
Edge coverage requires a known measured upright plant, at least 0.5 m tall
and 0.25 m across; unknown model names and walkable ground cover cannot supply
it. The existing 25 m maximum empty edge run remains unchanged.

Gate settlements reserve northern ground for their measured manor approach.
Their coast occupies the opposite site edge at the same depth, keeping that
reserved ground dry. Far-side woodland candidates likewise reject water and
its bank before the dresser tries to plant them.

A pond bay that clears roads can still be beyond the earned mill's short
race. If ordinary mill placement fails, the cutter tries the same-sized pond
beside measured mill lots on its already allowed roads. It chooses the
smallest move, with common distance breaking ties. The prior buildings, roads,
reservations and other water stay fixed; a pond with an attached race cannot
move. Each candidate still passes the ordinary lot and 14 m race rules, and
failed candidates restore the original pond. The actual seed 18003 regression
also checks failed-candidate rollback, native request identity and prior-layout
bytes; the full matrix continues with the complete household programme.
