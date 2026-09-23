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
enclosure checks, 201 water-plan checks and 256 measured-adit checks pass.
The 750 focused enclosure cases use site plans with representative lots; they
do not replace the outstanding fully populated enclosure/water acceptance
matrix. Reference renders are produced by `tools/render_village_gates.gd`.
