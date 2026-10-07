# Believable, inhabited buildings: design work plan

Prepared 2026-10-06 (America/Phoenix). This is a design backlog, not a claim
that every historic pin remains broken. The user explicitly confirmed that
some pin defects are fixed and that the design is still bad.

## Outcome

A generated building should explain who uses it, what they do, and how its
spaces support that life. Houses need domestic scale, privacy, comfort,
storage, useful light and coherent activity groups. Shops need a legible
customer/work/storage sequence. Churches and temples need their own spatial,
structural and ritual hierarchy. These are family-specific briefs, not one
generic room grid with different prop lists.

Recognizable style and personality are required across every published family
and style. The witch hut was found during a walk; it is not a scope boundary.
The coverage inventory and proposed design directions live in
`BUILDING_PERSONALITY_BRIEFS.md`. Every style needs a spatial habit, a readable
silhouette, a coherent material/detail vocabulary and signs of its users.

The witch hut is one complete design example. It must read as a witch's
dwelling outside and inside, including ordinary living needs. A green roof,
a cauldron and a high clutter setting have not delivered that result.

## Evidence and limits

The current `visualqa/walk_pins.jsonl` parses as **18 reviews, 109 pins, 10
distinct building names**, all seed 1. The nine-building count in
`WALK_PINS.md` omits the additional witch hut. Some pins are praise or questions;
109 pins does not mean 109 confirmed current defects. Source timestamps are
UTC and include 7 October; this plan uses the user's local date.

| Design concern | Historical evidence (`review_id`, pin) | Follow-through |
|---|---|---|
| Witch hut reads as an ordinary house | `1a113f97860b8a160d1`, 1 | New identity design, not a collision fix |
| Furnished room lacks purpose | hotel `1a113eece1512b6faee`, 4, 9, 10; domus `1a113f41f088a9b6f32`, 2–4 | Compose complete activities and scale spaces to them |
| Tables dominate circulation | village `1a10f969d1e9468a0ef`, 6, 7, 13; `1a113f86d10724c5a87`, 12 | Distinguish entrance hall from communal eating hall; plan the route first |
| Furniture relations feel wrong | cottage `1a1030ce0521e8a6361`, 3–6; later `1a113a20fda8c84783d`, 1–3 | Preserve existing fixes; add composition and domestic-use acceptance |
| Hall/stair/door proportions and access | hotel `1a113eece1512b6faee`, 6–7; village `1a113f86d10724c5a87`, 3–7, 10–11 | Reproduce before calling a defect open; design usable arrival and vertical circulation |
| Blank surfaces and weak architecture | domus `1a113f41f088a9b6f32`, 1; hotel `1a10f89a6dbf74a26f6`, 5–6; temple `1a10f8b2344acda7803`, 1 | Wall composition, structural rhythm, thresholds, light and type identity |

The initial audit did not regenerate these requests. Subsequent generation,
renders and bounded tests are recorded in `PERSONALITY_PROGRESS.md`; the table
above remains a historical ledger, not a claim that every pin is still broken.

Existing progress must be credited. `WALK_PINS.md` documents chair-facing,
hosted-seat, sparse-room, stair and z-fight checks. The completed
`WLD001-DOMUS-WALKPIN` task records always-attempt bedroom storage in ample
rooms; the completed stair regression tasks cover specific well/interior
placement failures. Leave those completed tasks alone unless a new replay
demonstrates a regression. A test fixture, a caught diagnostic, a generator
repair and a visually successful building are four different kinds of evidence.

## Why more pin fixes alone will not deliver the outcome

The ordinary house path in `src/house/house_plan_rooms.gd` recursively splits
the largest rectangle, then names the rooms. It also supports custom room
rectangles; preserve that extension point and family-specific planners.
`HouseSpec.PROGRAM` and `rooms_for()` provide a shared household programme.
Connectivity alone does not select a good room sequence or usable proportions.

`house_furnishing_recipes.gd` already contains relational recipes and ample-room
additions. Extend those mechanisms. Optional rolls, floor coverage, or object
counts cannot prove that a room supports its intended activities. The meaning
of `hall` must be explicit: an entrance is not automatically a dining room.

The witch hut already has steep-roof/palette styling, cauldron and pot dressing
in `house_exterior.gd`, and herb-bed/drying-line/mushroom vocabulary in
`house_yard.gd`. It is incorrect to say it has no themed content. What is missing
is a convincing, integrated spatial and visual identity. The shared component
role count reported by `WALK_PINS.md` is a clue, not an identity acceptance test.

`FURNISHING_WALLS.md` solves real wall geometry and furniture fit. The next
design layer is wall composition: finishes, structural bays, openings, fitted
storage, light and a restrained selection of domestic objects. Deliberate quiet
walls remain valid. Do not cover every wall to satisfy a density score.

The knowledge base already teaches these principles in
`PROCEDURAL_ARCHITECTURE_RULES.md` and `PROCEDURAL_EXTERIOR_INTERIOR.md`.
The work is to make their contracts drive generation and acceptance.

## Work order (also recorded in WaterFree todos)

| Key | Priority | Deliverable | Prerequisites |
|---|---|---|---|
| LIVE-BRIEF | P0 | Current baseline, family design briefs, labelled room activities and review rubric | None |
| LIVE-ROOMS | P1 | Purpose-led household graphs, proportions and circulation reservations | BRIEF |
| LIVE-THRESHOLDS | P1 | Door, hall, landing and stair design integrated with room planning | ROOMS |
| LIVE-ASSETS | P1 | Curated owned-asset palette for room roles, materials and coherent style | BRIEF |
| LIVE-GROUPS | P1 | Complete domestic activity groups sized to usable space | THRESHOLDS, ASSETS |
| LIVE-SURFACES | P1 | Composed interior walls, ceilings, light and exterior rhythms | GROUPS |
| LIVE-WITCH | P1 | First complete witch hut across plan, silhouette, interior and yard | SURFACES |
| LIVE-HOUSE-STYLES | P1 | Distinct domestic design across every published house style | SURFACES |
| LIVE-SHOPS | P1 | Shop-specific customer, counter, work and storage compositions | SURFACES |
| LIVE-SACRED | P1 | Separate church and temple composition briefs and representative implementations | BRIEF |
| LIVE-FAMILY-STYLES | P1 | Personality rollout across remaining public families and their styles | BRIEF |
| LIVE-REVIEW | P1 | Cross-family first-person and visual acceptance on multiple seeds and sizes | WITCH, HOUSE-STYLES, SHOPS, SACRED, FAMILY-STYLES |

These dependencies are implementation gates. Design sketches and asset research
can proceed earlier. Reuse the smallest necessary shared mechanism; do not
delay the witch hut behind a universal planning-engine rewrite. Complete a
vertical slice, then generalize proven relationships across the complete style
inventory. Church and temple work need not wait for a witch hut to be complete.
Preserve existing family
semantics, particularly temple rite/axis and courtyard inward-facing design.

## Concrete design contracts

**Brief and planning.** Record inhabitants/capacity, activities, privacy,
adjacencies, focal points, light, storage and intentional empty space. Allocate
room dimensions from full-size activity groups and circulation before packing
the envelope. Use archetype-specific area/aspect bounds, minimum usable wall
runs and residual-space checks. Reject or replan impossible briefs. A narrow
strip cannot count as a usable room merely because it has positive area.

**Movement.** Place doors to support routes and furniture walls. Distinguish
arrival, passage and gathering space. Reserve real door swings, approaches,
stair runs, landings and headroom before furnishing. Measure the assembled
collision mesh in both directions with props enabled. Use the existing walk
grid and stair checks; do not create a second reachability model. Dimensions
are project/archetype design targets, not claims of building-code compliance.

**Domestic groups.** Cooking needs preparation, heat, storage, water handling
and work access appropriate to the setting. Sleeping needs privacy, usable
bed access, storage and light. Eating needs a deliberate household eating
place with enough usable seating. Sitting needs a focus and conversation
arrangement. A hall gets a table only when its brief calls for gathering or
eating. Required activities survive placement repair: retry layout or report
the brief unsatisfied; optional clutter cannot substitute for them. Existing
omission warnings remain honest and must not be muted to obtain a green run.

**Comfort and surfaces.** Treat the user's feng shui concern as privacy,
arrival, sightlines, protected rest, light and comfortable movement. Do not
claim a universal cultural rule. Compose wall bays and ceiling treatment from
room purpose and construction: shelves near work, pegs near arrival, bedside
light near the bed, softer detail in rest areas. Rugs, curtains, cloth, pictures
or plants are palette-dependent candidates, not mandatory objects everywhere.

**Witch hut.** Proposed direction: a compact, accreted dwelling with an
expressive roof/chimney silhouette, a sheltered entrance, herb-processing and
brewing workspace, dry ingredient storage, a private sleeping nook, hearth
and small eating/resting place. Connect the work area to the existing herb yard.
Use controlled asymmetry with credible supports and weathering logic. Avoid
forced crooked geometry that makes doors or furniture unusable. Review this
direction in the brief; it is a design proposal, not the only valid witch hut.
At review, hide labels and compare with the ordinary cottage. Ask what makes
each identifiable. Three extra component names or props are insufficient.

### Proposed witch dwelling: labelled spatial direction

This is a design brief, not a generated plan or a scale drawing. Front is -Z.
One resident receives a visitor without exposing the bed. Cooking and brewing
have separate working surfaces; ingredients stay close to the work. The
sleeping room is a private leaf, never a passage to the yard. A compact hut
may combine living and eating, but must retain their usable activity groups.

```text
                 REAR / +Z: herb yard and drying shelter
                 [covered service threshold]
                              |
  +-------------------+-------+---------------------+
  | PRIVATE SLEEP     | BREW / HERB WORK             |
  | bed + side access | cauldron + preparation bench |
  | chest + lamp      | ingredient shelves + water   |
  | quiet window     | working light + dry storage  |
  +--------door-------+-------------door------------+
  | LIVING / EATING   | COOKING / SERVICE            |
  | hearth focus     | heat + prep + food storage   |
  | two seats, table | route to work without bed    |
  +----------+-------+------------------------------+
             | sheltered arrival, coat/boot storage
             FRONT / -Z: path, readable entrance
```

The default 9x12 envelope is a test, not permission to enlarge all activity
groups to fill it. Reserve wall thickness, doorway approaches and circulation
before comparing usable areas. At small size, combine compatible activities;
report an unsatisfied brief when full-size essentials cannot fit.

```text
                  offset chimney (real hearth host)
                         ||
                  /\     ||
                 /  \___/\       unequal roof masses
                /         \      supported eaves
               /___________\___
               | small high |  \  lower work/service roof
               | windows    |___\
               |____[door]__|___|  sheltered threshold
                   steps / herb edge
```

Silhouette direction: a dominant steep dwelling roof and subordinate work
volume, an offset chimney, deep sheltered entry, restrained asymmetry and
different window treatment for private rest and active work. Roof seams,
supports and drainage must remain credible. Green materials are optional;
the form and use must carry recognition without a style label.

**Shops, churches and temples.** A shop's trade must read through work and
goods, customer access, counter and back-room relations. Churches need a clear
entry/nave/sanctuary hierarchy and coherent structural/light rhythm. Temples
must express their particular rite and focus; do not impose church seating
or domestic clutter on them. Sacred emptiness can be intentional. Hotel lobby
and domus pins remain stress fixtures for large-space composition, without
expanding the first delivery into a complete hotel/castle redesign.

## Completion evidence

Begin with the pinned request and retain full request JSON, seed, source
revision and local-change fingerprint. Use seed 1 plus two other fixed seeds
chosen before tuning, at small/default/large supported dimensions. Initially
apply the nine-case matrix to cottage and witch hut; expand to each target
shop/church/temple during its task. Reject label-only success and single-seed
hand placement. Deterministic repeats must reproduce the same plan and result.

Keep roof-on exterior, cutaway plan, entrance-eye, main-activity and sleeping/
service views where applicable. Judge room proportions, purpose, circulation,
composition, light, comfort and family identity. Record reviewer observations
and unresolved criticism; automated or local-model scoring is assistance,
not proof that the user finds a building convincing.

Use independent negative controls: remove a required activity group, swap
the witch hut for the cottage, block an actual landing, or rotate a seat model.
Numeric checks should catch what they claim; visual review must still judge
the result. Preserve successful historical fixes and distinguish regression,
new design shortfall, and deliberate archetype exception in the ledger.

Run only relevant routine gates per edit: `lane:house-plan-fast`,
`lane:house-furnish-fast`, `lane:house-exterior-fast`, `lane:assets-fast`,
`walkpins`, `lane:geom`, `lane:church-change` or `lane:temple` as appropriate.
Use `harchetype` for completed household integration and record known baseline
failures explicitly. Asset imports require catalogue rebuild and `lane:assets`;
public API changes require `lane:api`. Keep long logs on disk. Scheduled gates
remain pre-merge work. A passing bounded lane is not full-suite evidence.

## Asset research and knowledge references

The owned-library kitchen/Godot search returns 540 matching assets, including
Kenney furniture-kit subjects and cached Kitchen Collection material. These
are candidates, not approved period/style matches. A witch/Godot text search
returns zero; it does not establish absence of useful herbs, vessels, books,
cloth or generic components. Search by function, inspect appearance and rights,
then measure selected models. Do not buy or generate replacement art first.

Knowledge references: `86e6c098-0d66-4d70-bcee-90e63edf687b` (architectural rule
contract), `ff45e8af-e943-416a-9388-79ca7eb99c4e` (activities before clutter),
`f84ac6c3-98e7-4620-97d2-ae8345817ce8` (host relationships),
`9c848f5d-dd12-437d-9918-376e45d0122a` (shared facts belong to the plan), and
`ab52f96a-faf4-40f5-a435-5c5aa9f4953f` (blank-facade measurements).
