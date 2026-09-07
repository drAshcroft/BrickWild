# Furnished houses

The third generator. A church is judged by its silhouette and a castle by its
plan, but a house is judged from the inside: whether the rooms make sense,
whether the furniture makes sense, and whether a person can walk through it.
So most of the work here is in the harness.

## The pipeline

```
HouseSpec ─▶ HousePlanner ─▶ HouseFurnisher ─▶ HouseBuilder  ─▶ ArrayMesh (shell)
 size,        rooms,          furniture,        walls with      +
 style,       doors,          use zones         real openings   HouseAssembler
 trade        windows                                           ─▶ prop instances
```

`HousePlan` is the one thing all of them agree about. The planner and the
furnisher write it; the builder turns it into a shell; the four checks in `qa/`
read it and judge it; `HouseAssembler` is the only place that ever loads a
model. That split is why the whole harness runs headless in milliseconds per
house — the checks work in metres and rectangles and never touch the art.

## Storeys and roofs

A house asks for one, two or three levels through `HouseSpec.storeys`; the
CHECKS count up to `HouseGeometry.MAX_STOREYS`, which is four, because a castle
keep is four storeys of one room each and a check that stopped at three would
report its top floor as invalid rather than walk it.

`HouseSpec.storeys` requests one, two or three levels; `height` remains the
floor-to-ceiling height of each level. Rooms, doors, windows and furniture keep
flat stable IDs but carry a zero-based `storey`. `HousePlan.stairs` is the
vertical part of the room graph, with a landing footprint on both adjoining
levels. This keeps the building representation useful without loading a scene
or inspecting emitted triangles.

The builder repeats floor, wall, partition and timber bands at their planned
elevations, cuts the stair openings, and emits the stair flights. A single
pitched roof is attached to the top wall band. Cutaway assembly remains an
explicit presentation option; ordinary API instantiation includes the roof.

### Cellars

`HouseSpec.cellars` (0 or 1) digs a storey below the ground (INT-016): the
ground partition again at storey -1, every room a store, joined by the
ground floor's interior doors and a stair down from the hall. The builder
logs a `pit` mass, a storey deep and the size of the site, as a negative
mass of kind `dug`, and the cellar's floor and walls stand on the pit floor:
every mass carries its own `ground` level, which `MassRules.grounded`
measures against instead of the ground plane. `MassRules.overlaps` treats
two masses below the ground as earth against earth and lets only a stair
reach from above into one. The nav check floods down the stair as it floods
up, and the plan check's storey and stair rules run from the lowest storey.
The `cellar_house` archetype exercises it. There is no trapdoor model in the
prop set, so the hatch is the stairwell itself.

## Rooms

The interior is split by cutting the biggest room in two, over and over, until
the floor area has run out of rooms to hold. Then the rooms are NAMED by how
public they are, which is the oldest rule in domestic planning: the hall takes
the front door, the kitchen sits next to it, and bedrooms go as far from the
door as the plan allows. Doors go on a spanning tree rooted at the hall, pushed
out to the ends of the walls they are cut into so both rooms keep a long
unbroken wall to put furniture against.

A room too small or too thin for the kind it was given is renamed rather than
squeezed: a 2 × 6 m room has the floor area of a bedroom and cannot hold a bed,
so it becomes a store, and the bed goes to the hall — which is what a one-room
cottage has always done.

| Rule | Why |
|---|---|
| bedrooms are leaves of the door tree | nobody should walk through a bedroom to reach the kitchen |
| a bedroom that is still a through-route is renamed | a room people traipse through is not a bedroom |
| a room with no exterior wall becomes a store | it can never have a window |
| every habitable room gets a window, narrow if need be | a room with no daylight is worse than a window near a corner |
| a room that still cannot be given one becomes a store | a kitchen whose only outside wall is taken up by the back door is not a kitchen |

## Rooms a rectangle cannot say

A room may carry an **`outline`**, a `PackedVector2Array`, and when it does the
outline is the truth: `rect` stays as its bounding box so every
rectangle-shaped rule still has something to measure. A room WITHOUT one is the
four-sided case, which is every room in every house — the outline exists for
the shapes a rectangle cannot say: a round tower, an octagonal chapter house, a
pagoda.

An outline is the **clear floor**, not a partition centre-line. A rectangular
room is cut out of the interior and shares half of each partition with its
neighbour; a polygonal room is not produced by cutting, so there is no shared
partition to give half of, and what you draw is what you walk on.

| | |
|---|---|
| `HouseGeometry.room_walls` | one wall per edge for a shaped room; the fixed **front, back, left, right** labelling for a rectangle. That order is a labelling and not a traversal — "the hearth is on wall 2" has to keep meaning the left wall |
| `room_floor_poly`, `room_area` | the outline, and its true area |
| `polygon_runs`, `shell_runs` | the wall centre-lines the builder raises masonry along: the outline pushed out by half a wall, exactly what `exterior_runs` does to the site rectangle |
| `HouseFurnisher` | every corner of a piece has to be inside the outline, not merely inside the box round it |
| `HouseNavCheck` | rasterises the outline, so the corners a chamfer cuts off are wall and nobody stands in them |
| `HousePlanCheck` | shaped rooms are compared by polygon intersection. The "floor nobody owns" sum applies only to a storey of rectangles: the corners an octagon cuts off are masonry, and that is what makes it a tower |

Three rules turned out to be measuring the box rather than the room, and all
three were found by building an octagonal tower rather than by reading:

* the window rule only recognised a wall by its position on the interior
  rectangle's edge, so every window on a diagonal was "in a partition";
* `_back_gap` measured to the bounding box, and reported every piece in the
  room as standing a metre and a quarter off a wall it was flat against;
* `_place_against_wall` took `absf()` of the wall normal to get its along
  vector. That is right for the four walls of a rectangle and meaningless on a
  diagonal, where it walked the piece off the wall entirely. The corrected
  maths — the direction the wall actually runs, and the piece's own width and
  depth — gives identical results for all four rectangle cases, which is why
  the house suites did not move.

## Furnishing

Each room kind has a recipe of steps, and each step is a rule rather than a
coordinate:

| rule | means |
|---|---|
| `wall` | a bed, a cabinet, a bookcase wants its back to a wall |
| `free` | a table wants room all round it |
| `around` | seats belong at a table, facing it, with room to push back |
| `behind` | the seat on the far side of a thing with a front and a back: the lord's bench behind the high table, the clerk's stool behind the counter |
| `row` | N copies along a wall or an axis at one pitch, sharing one aisle: pews, barrack beds, the trestles down a hall |
| `corner` | barrels and crates go where nobody walks |
| `mounted` | shelves, racks and sconces hang at head height |
| `ceiling` | the chandelier hangs over the middle of the room |
| `on` | a mug belongs on a table, never on the floor |

Every placement records the floor it occupies **and the floor a person needs to
use it** — the pull-back space behind a chair, the side of a bed you get into
it from. That second rectangle is what makes the walking check possible.

`opt: 1.0` marks a piece the room is not that room without. Those are placed
first, without a dice roll, and the passes that thin a room out will not touch
them. Everything else is dressing and can be taken back out.

**Floor the plan keeps clear.** A use zone is the floor one piece needs and
belongs to that piece. `HousePlan.zones` is the other kind: floor kept clear
because of what the room is *for*, and kept clear if the room were empty — the
screens passage inside a great hall's door, so the way in is not through the
middle of dinner. The furnisher treats one as occupied ground before the first
piece is placed, the `clear` rule proves nothing ended up standing in it, and
the nav check proves it can actually be walked.

**Floor at another height.** `HousePlan.dais` is a raised rectangle in a room:
`{room, rect, rise}`. It is a step, not a wall — the walk grid keeps a level
per cell and joins two cells whose floors differ by up to `WalkGrid.MAX_STEP`
(0.6 m), so a person walks up onto a dais and does not walk off a mezzanine.
Anything standing on it is placed in plan exactly as if the floor were flat and
lifted by the rise when it is committed.

## Outside

The walls are half-timbered: a sill along the bottom, a wall plate along the
top, heavier posts at the corners, studs between them at the style's own
spacing, a mid rail at sill height, braces across the corners, and a king post
with struts in each gable. The studs read the same opening list the wall itself
was built from, so one can never be planted across a window.

`stud_pitch` is what separates the styles. A town house is close-studded at
half a metre, which was expensive and meant to look it; a farmhouse is nearer
a metre and a half. The chimney is stone rather than plaster, because it is the
one part of a timber-framed house that is neither.

## The harness

Five suites, run with
`godot --headless --path . --script res://tests/house_test.gd`.

**`qa/house_plan_check.gd` — is this a plan of a house?**
rooms tile the interior exactly; no room is smaller or thinner than the thing
it claims to be; exactly one front door, on an exterior wall; every room
reachable from it through doors; no room reachable only through a bedroom;
doors and windows fit the wall they are cut into, clear of the corners and of
each other; windows on exterior walls only; every habitable room has daylight.

**`qa/house_furnish_check.gd` — does the furnishing make sense?**
nothing is inside a wall or inside anything else; everything that must sit on a
surface is on one, at its height and within its top; nothing stands in the
swing of a door; nothing tall stands across a window; a bedroom has a bed, a
kitchen a hearth, a hall somewhere to sit, a smithy an anvil; the pieces that
want a wall have one behind them; seats are at a table and facing it; every
room has something to see by; and the feng shui rules, each a sentence and a
measurement — **the commanding position** (the bed's head against solid wall,
out of the line of the door, with a side you can get in from), **the hearth**
on the wall the planner gave the chimney, and one per affinity in the prop
catalogue: the workbench in the daylight, the bookcase off the chimney wall,
the bed off the window wall, the table drawn up to the fire, sconces in a
mirrored pair, the shelf over the bench, the chandelier over the table,
barrels out of the traffic. Last, **the focus**: `HousePlan.focus` names the
one piece the plan is arranged around (the fire in a house, the counter, bar
or anvil in a shop) and where it stands; the furnisher pins it there and turns
it to the door when the family says so, and the rule proves the piece is
there and looking the right way. It is the temple's axis rule brought indoors.

**Lights that light.** Every prop the catalogue tags `LIGHT` gets an
`OmniLight3D` from `core/light_kit.gd` when the house is assembled, at the
model's measured flame (`light` in `catalog.json`), with range and energy from
a per-category table; the temple's braziers use the same kit. The assets suite
re-measures the flame and counts the lights against the plan.

**`qa/house_nav_check.gd` — can a person walk through it?**
This one puts a body in the building. It rasterizes the floor at 12 cm, blocks
out the walls and the furniture, shrinks the free floor by a person's own
half-width with a distance transform, and walks: from the doorstep, through the
doors, into every room, and up to every use zone. A house passes only if every
room can be entered, both sides of every door can be stood on, and every piece
of furniture somebody is meant to use can be reached. Its `steps` rule adds the
two things a plan can ask for that are not furniture: the dais is walked onto,
and every passage the plan keeps clear is walked.

`ascii_map()` prints what the walker saw — `#` blocked, `.` too tight to stand
in, `:` standable but never reached, ` ` reached. Reading a reachability
failure off a list of room numbers is guesswork; reading it off the map takes a
second.

**Replacing a rule.** Every check lists its `RULES` and takes an `overrides`
dictionary (`check(plan, overrides)`, `HouseQA.check(plan, builder,
overrides)`) mapping a rule name to a replacement Callable, so a family that
is a correct building and breaks a rule -- a hammam has no windows -- replaces
the rule with the one it obeys rather than switching it off. The replaced
rule's messages carry both names (`daylight -> hammam.blind: ...`), the report
lists them under `replaced`, and a rule named with nothing in its place is an
error. `qa/sightline.gd` is the shared can-you-see-it test the temple's
sightline rule and the house focus rule both cast.

**`qa/house_qa.gd`** runs all three plus the shell rules from `MassRules`.
**`tests/suites/house_assets_suite.gd`** re-measures every model and compares
it against `assets/props/catalog.json`, so a swapped asset fails loudly rather
than quietly moving the furniture.

## The generator checks its own work

Rules that place one piece at a time cannot see the finished room, and three
sound decisions in a row still add up to a barrel in the only gap between the
table and the wall. So the furnisher walks the house itself:

1. after each room is furnished, if the house has stopped being walkable, the
   room that just changed loses its largest optional piece — and it is that
   room, because everything before it was sound;
2. at the end, while the house still fails, it tries removing each candidate in
   turn and keeps whichever actually opens up the most floor. Measured, not
   guessed: what blocks a bedroom is usually in the parlour you would cross to
   reach it.

A piece the room cannot do without is only removed when nothing else helps, and
when one goes the plan **records it**. The furnishing check reads that record
and reports "the parlour gave up its table so the rooms beyond it could be
reached" as a warning rather than as a defect — a generator that quietly drops
furniture is hiding a bug; one that writes down what it dropped and why is
reporting a compromise.

## Archetypes

`tests/suites/house_archetype_suite.gd` is the house equivalent of the church
and castle landmark suites. A fantasy dwelling has no Chartres to be measured
against, so the sweep uses archetypes — each built at 75%, 100%, 140% and 190%
of its size, each required to contain the rooms and the defining fittings that
make it that kind of house, and each put through the whole harness.

| Archetype | Style | Size (m) | Must contain |
|---|---|---|---|
| One-room cottage | Cottage | 5.5 × 7 | a bed |
| Family cottage | Cottage | 8 × 10.5 | hall, table, seat |
| Farmhouse | Farmhouse | 10 × 13 | hall, barrels or crates |
| Smithy | Long Hall | 11 × 13 | hall, workshop, anvil, workbench |
| Alchemist | Witch's Hut | 9.5 × 12 | hall, workshop, bookcase, workbench |
| Inn | Townhouse | 13 × 16 | hall, parlour, bedroom, table, seating |
| Scholar's house | Townhouse | 10 × 12 | hall, parlour, bookcase |

An archetype declares what a house must CONTAIN, never where anything goes.
The layout is the generator's business, and the moment a test says where the
bed is, it stops testing the generator and starts testing itself.

## Assets

Quaternius **Fantasy Props MegaKit** (Standard licence), copied into
`assets/props/fantasy/` from `C:/Projects/itch_assets`. 94 models, three shared
trim textures. `tools/build_prop_catalog.gd` measures every one of them into
`assets/props/catalog.json`; `src/house/prop_catalog.gd` says what each one IS
— what it is for, whether it wants a wall behind it, how much room a person
needs in front of it. Sizes are never authored by hand there, because a guessed
footprint is how furniture ends up half inside a wall.

## Sources for the rules

- Merrell et al., *Interactive Furniture Layout Using Interior Design
  Guidelines* (SIGGRAPH 2011) — the idea of encoding design guidelines as
  scored terms: clearance, circulation, pairwise relationships, alignment.
  https://graphics.stanford.edu/projects/furniture/
- Ordinary interior-design clearances: a 36 in main walkway, 30 in beside a
  bed, 36 in of pull-back behind a dining chair, 36 in of approach at a door.
  https://roomsketch3d.com/help/dimensions/clearance-around-furniture
- Feng shui bed placement, the commanding position, and why a bed is not put in
  line with the door or under a window.
  https://fengshuireport.com/blog/bed-placement-feng-shui
- Privacy gradients and adjacency in procedural floor plans.
  https://graphics.tudelft.nl/~rafa/myPapers/bidarra.GAMEON10.pdf
