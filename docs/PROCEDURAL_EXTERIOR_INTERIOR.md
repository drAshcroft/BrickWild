# Exterior and interior design as one procedural system

An exterior promises where a visitor enters, how many floors exist, which
spaces are important, and how the roof meets the walls. An interior must honor
those promises. Generate both from the same semantic plan and geometry
descriptors, then add decoration through measured host relationships.

## 1. Exterior design: large to small

### Site and approach

Record road/front edge, slope, water, sun/wind brief, public view, service
access, and neighboring mass before producing the facade. Locate the front
door where a person or wagon can reach it. The true doorstep, porch, stairs,
and overhang count toward lot fit. For a village, the road class and common
decide whether the building fronts a street, faces a square, or stands on a
private lane. See [VILLAGES.md](VILLAGES.md) and
[PROCEDURAL_ARCHITECTURE_RULES.md](PROCEDURAL_ARCHITECTURE_RULES.md).

### Mass and roof

Construct a primary volume, secondary wings, courtyard or porch voids, roof
planes, and a silhouette landmark. Use the same polygon/plane descriptor
for roof skin, wall profiles, dormer seats, and drainage details. A roof may
be steep for visual character, but its openings and attachments must meet its
actual planes. [ROOF_AUDIT.md](ROOF_AUDIT.md) and
[ROOF_REGION_CONTRACTS.md](ROOF_REGION_CONTRACTS.md) give BrickWild examples.

### Facade and openings

Derive opening candidates from rooms and floors. A window should correspond
to a usable interior zone and sit on the real wall surface, even when the
wall is battered or curved. Then apply a facade grammar to organize bays,
courses, arches, shutters, glazing, and trim. Allow entry or landmark bays
to break the rhythm. A shop can have a wider public opening; a fortress can
have a controlled ground floor; a hall can have a clerestory above an aisle
roof. The [CGA paper](https://doi.org/10.1145/1179352.1141931) is a useful
mass-to-facade reference.

### Material and weather story

Give every surface a role: foundation, wall, exposed timber, roof, trim,
glazing, paving, metal. Weather and wear should follow exposure and use:
runoff below eaves, splash near ground, foot wear at thresholds, soot near
hearths, algae near water. Drive masks from semantic position plus restrained
noise, not unrestricted noise over the whole building. Match UV scale across
adjacent components; preserve hard normals at masonry and timber corners.

### Exterior dressing

Attach props to hosts: sign to shop frontage, barrels near service entry,
bench on verge, cart in yard, lantern beside public door, hedge on boundary,
tree behind house. Reserve door and road corridors first. A fence needs a
gate where the path crosses; a waterwheel needs a watercourse. Props carry
measured footprints and plants carry both trunk and canopy radii. See
[VILLAGES.md](VILLAGES.md) sections 7-9.

## 2. Interior design: use before clutter

### Programme and room sequence

Give each room a purpose and required activities. The house entry should
lead somewhere useful; a shop needs customer and work zones; a castle's hall
needs a route from the gate; a temple needs a clear processional path. Build
the adjacency graph, pack rooms, place doors and stairs, then confirm every
required threshold is reachable. BrickWild's `qa/walk_grid.gd` is the shared
floor/obstruction model for house and temple checks.

### Furniture hierarchy

Place fixed architecture and focus objects first: hearth, altar, counter,
bed, table, dais, bath, stair. Add supporting furniture second: chairs,
storage, shelves, workbench. Add small evidence of use last: vessels, books,
tools, cloth, baskets, light. This order protects the use of the room and
gives the viewer a readable focal hierarchy. A density target cannot make
an unusable room good.

### Relationship grammar

Every item has a host and a relation. `against_wall` needs the wall's actual
normal and the object's measured back plane. `facing_focus` needs orientation
and a clear sightline. `beside_table` needs a seat offset plus standing room.
`on_support` needs a measured support plane and enough footprint. `near_door`
must still leave the door's swing and approach clear. For angled or polygon
rooms, evaluate these relations in the host's local frame rather than its
AABB. BrickWild's polygon furnishing and castle range rules demonstrate why.

### Light and atmosphere

Daylight comes from an exterior opening or an open court, not a symbolic
window marker. Artificial lights belong to lamps, torches, braziers, or
magical sources and should cover the paths a user must traverse. Contrast can
be intentional: an approach may be dim and a focus bright. Verify it in a
render, since a geometric light placement record does not prove that the
player sees the focal object. [TEMPLES.md](TEMPLES.md) ties illumination to
the processional route.

### Repair without erasing purpose

The furnisher can move or remove optional clutter when it blocks navigation.
It should preserve required activity objects; if none can fit, return a
diagnostic identifying the room and violated constraint. BrickWild records a
warning when navigation repair forces removal of something a room needs.
Functional layout research likewise treats arrangement as constraints and
optimization; see [Make it Home](https://web.cs.ucla.edu/~dt/papers/siggraph11/siggraph11.pdf)
and [Infinigen Indoors](https://arxiv.org/abs/2406.11824).

## 3. Exterior-interior agreement table

| Exterior promise | Interior evidence | Measured check |
|---|---|---|
| Front door | Entry room, landing, usable route | Actual threshold and walk-grid reachability |
| Window bay | Room at that floor and wall | Opening projects onto real wall and room receives it |
| Chimney | Hearth and flue | Hearth contact, flue alignment, emitted mass |
| Dormer | Usable attic zone | Dormer seats on roof plane; no floating cheek |
| Porch or arcade | Covered walk | Roof support and passable floor below |
| Courtyard | Rooms around open sky | Court excluded from roof coverage, included in navigation |
| Tower storey | Floor and stair connection | Height-band opening plus stair graph |
| Shop sign/display | Public business room | Frontage and room purpose agree |
| Defensive gate | Through passage | Mesh aperture and wagon/person route clear |
| Temple spire | Dominant ritual focus | Arrival view and focus position agree |

## 4. Variation without visual noise

Use hierarchical seeds: site, building family, structural variant, facade,
interior, then clutter. A change to a basket should not reroll the entire
village. Keep coherent palettes by place and period, then vary a few features
within each family: bay count, roof type, porch form, material mix, room
programme, and decoration density. Evaluate variants at pedestrian and aerial
views. Prefer a meaningful difference in silhouette or function over many
random small objects.

For a ruined, haunted, or fantastical variant, first generate a sound
building. Apply a named transformation: collapse a wing, overgrow the court,
invert a tower, suspend a hall, or replace a route with a portal. Re-run the
checks appropriate to the new premise. This preserves a recognizable origin
while making the transformation legible.

## 5. Design review sheet

For every generated archetype, capture one street approach, one elevated
silhouette, one threshold view, one main-room view, and one plan. Record:

1. What is the primary entrance and focal mass?
2. Which exterior features express real interior rooms or structure?
3. Can a character reach every required activity without clipping props?
4. Do light, weather, and material changes follow exposure and use?
5. Are props placed on actual hosts, and do their clearances match measured
   assets?
6. What one change would make the design easier to read from ten metres?

The review should produce a rule or recipe change, not merely a score. The
goal is a family of buildings that remain coherent across seeds and scales.
