# Architecture concepts expressed as generator rules

Architecture is an arrangement of space, structure, light, thresholds, and
social meaning. Its art cannot be reduced to a score, but a generator can
protect the relationships that make a building legible. BrickWild's family
documents are a rich source of measurable examples; the rules below are
**design heuristics**, not universal historical standards or building codes.

## 1. Begin with the question a building answers

| Building | Primary question | First plan constraint | Visible consequence |
|---|---|---|---|
| House | How do people live and move privately? | Rooms, hearth, sleeping, access, daylight | Entrance hierarchy and domestic scale |
| Shop | How do strangers find the work or counter? | Public threshold and work/storage relation | Wide frontage, sign, goods transition |
| Castle | How are people supplied and defended? | Gate route, hall, water, service yard | Layered perimeter and dominant keep |
| Temple | How does the rite reach its focus? | Procession, sightline, congregation | Axis, light, scale change, focus |
| Hotel/inn | How do guests arrive, gather, and retreat? | Lobby or common room, service route, lodging | Landmark entry and repeated private bays |
| Village | Why is this settlement here? | Resource/landmark, road, common, households | Street and service hierarchy |

See [HOUSES.md](HOUSES.md), [SHOPS.md](SHOPS.md), [CASTLES.md](CASTLES.md),
[TEMPLES.md](TEMPLES.md), [HOTELS.md](HOTELS.md), and [VILLAGES.md](VILLAGES.md).
The same initial question should drive exterior, interior, and QA. For
example, a castle's intimidating gate is incomplete if a wagon cannot cross
its actual passage.

## 2. An architectural rule has five parts

Write a rule as `(host, relation, measure, exception, evidence)`.

- **Host:** the wall, room, roof plane, road, court, doorway, or landmark to
  which the rule belongs.
- **Relation:** faces, supports, joins, contains, overlooks, approaches,
  shields, mirrors, or contrasts.
- **Measure:** polygon overlap, clearance, angle, graph reachability, height,
  visible area, material continuity, or ray sightline.
- **Exception:** a named archetype, climate, culture, fantasy premise, or
  deliberate state that changes the rule.
- **Evidence:** plan record, emitted mesh, navigation graph, and render view.

Example: a house porch **belongs to** its front wall; its door must **face**
the road, the path must **reach** the actual threshold, and its roof must
**join** the host roof. A courtyard manor may have a recessed door: the
exception is an explicit open arrival court with a verified approach. The
exception does not apply to a closed curtain wall.

## 3. Composition at four scales

**Site.** Relation to road, slope, water, sun, wind, fields, and nearby
landmarks. Let these inputs affect orientation and approach before styling.
A building placed against a slope may need stairs descending in the correct
direction; a watermill needs an actual water relationship, not a wheel prop
on any wall.

**Mass.** Establish a dominant body, subordinate wings, voids, and a clear
roof hierarchy. Variation needs controlled ratios and a small number of
contrasts. Randomly changing every bay, roof pitch, and material produces
noise rather than richness. A landmark can be taller, brighter, or more
central, but choose its dominant signal deliberately.

**Facade.** Divide the shell by real floors, structural bays, and openings.
Align a clerestory with the aisle roof below; align a shop opening with its
public room; put a dormer on its actual roof plane. Repetition creates rhythm;
exceptions mark entrances, corners, towers, or a special room. The
[CGA building grammar](https://doi.org/10.1145/1179352.1141931) supports
the useful hierarchy from mass to facade scopes to detail, including
context-sensitive interactions.

**Detail.** Place trim where material or function changes: eave, sill,
plinth, arch, joint, railing, lintel, drain, chimney, worn threshold. Details
should explain how parts meet or how people use them. A density target alone
cannot decide where a bracket or barrel belongs.

## 4. Core relationships to encode

| Concept | Practical generative rule | Useful check | When the rule changes |
|---|---|---|---|
| Hierarchy | One primary entrance and one strongest focus per composition | Rank entrances and visible masses | Multiple equivalent gates in a symmetrical complex |
| Axis | Align approach, opening, room, and focus where procession matters | Centerline error and sightline | Bent entry for privacy; looping pilgrimage |
| Rhythm | Repeat bays with a small number of purposeful exceptions | Spacing and alignment distribution | Ruin, accretion, informal vernacular |
| Proportion | Relate height, width, court size, opening size, and roof rise | Dimensionless ratios across scales | Monumentality or deliberate distortion |
| Datum | Let floors, sill courses, eaves, and roof edges share reference levels | Height-band agreement | Stepped terrain or split levels |
| Support | Make visual loads appear to reach ground or a named support | Mesh contact and component graph | Explicit levitation or impossible structure |
| Threshold | Change enclosure, light, sound, and floor treatment on entry | Door graph plus render comparison | Concealed entrance or ritual deception |
| Light | Put openings where rooms need daylight or where a rite needs contrast | Room coverage, sightline, light placement | Bathhouse oculi, blind store, dark sanctum |
| Weather | Give roof and walls plausible runoff/erosion logic | Roof joins, overhang, opening clearance | Magical environment with stated rule |
| Context | Size and style against adjacent buildings and public space | Street rhythm, setback, landmark prominence | Deliberate anomaly or singular landmark |

The numeric bounds belong to an archetype and setting, not this general table.
For instance, BrickWild's village widths and room clearances are design
fixtures. Test them at several scales; do not canonize one screenshot.

## 5. Typology before ornament

The same material palette can cover buildings with wholly different spatial
logic. A courtyard house organizes inward around sky; a tower house stacks
rooms vertically; a timber hall uses a column grid and deep eaves; a stepwell
descends to water; a stupa organizes a path around a solid focus. Generate
their graph and structural envelope first, then apply a style palette.
[WORLD_BUILDINGS.md](WORLD_BUILDINGS.md) inventories examples from several
regions and exposes the representation changes required for each. It should
be used as a starting map for research, with cultural details verified from
specialist sources before publication.

One spec can deliberately cross a typology with a fictional style: a basalt
courtyard library, a timber hall of a coastal culture, or a floating
caravanserai. Preserve the essential room and circulation relations so the
hybrid is intelligible. This is also how fantasy avoids becoming a random
collection of motifs.

## 6. Translate the art into a search process

1. Choose an archetype, site, and brief. Derive a small set of hard rules
   that protect use and recognizability.
2. Generate several mass and plan candidates with distinct seeds. Reject
   invalid plans before emitting fine geometry.
3. Score soft qualities separately: silhouette, entry legibility, rhythm,
   landmark relation, daylight, material coherence, and controlled surprise.
4. Select candidates by Pareto balance or a weighted score, then render the
   finalists at pedestrian, aerial, interior, and approach views.
5. Compare the rendered result to its intended sentence. If the shop does
   not read as a shop, identify the missing relation and add a rule rather
   than adding random detail.
6. Preserve negative controls: move a door to the back, remove a support,
   block a view, collapse a roof join. The corresponding checks should fail.

This chapter's central principle is: **rules protect relationships; art
direction chooses which relationships matter.**
