# Castle reference

Real dimensions and defining features for the fortifications the castle
generator is expected to be able to build. Sources at the bottom.

## Tiers

One input decides what KIND of building comes out: the footprint. The bands are
in `CastleSpec.TIERS`, and `CastleSpec.tier_for(w, l)` is the only place the
rule is written down.

| Tier | Footprint area | What it builds |
|---|---|---|
| house | up to 300 m² | one hall block, a porch, an annexe, external chimney stacks |
| manor | up to 2 000 m² | a main range with cross wings round a court, optionally closed by a front range, with towers on the wing ends |
| castle | up to 12 000 m² | a curtain wall with corner and mural towers, a gatehouse, and a keep, hall and chapel inside the bailey |
| fortress | above that | all of the above, plus a second enceinte inside the first, a barbican, and a walled causeway joining the two gatehouses |

A tier can be pinned with `CastleSpec.tier_override`, which is how the landmark
sweep below scales a real building without it turning into a different kind of
building on the way down.

## Landmarks

| Building | Style | Site W x L x H (m) | Tier | Defining features |
|---|---|---|---|---|
| Medieval longhouse | Norman | 6.5 x 18 x 4.5 | house | one range under a single ridge, gable **chimney stack**, no defences |
| Stokesay Castle | Norman | 30 x 24 x 10 | manor | earliest English **fortified manor house**: great hall 16.6 x 9.4 m between a north and a south **tower** |
| Hampton Court range | French Château | 40 x 28 x 11 | manor | Tudor **courtyard house**: ranges on all four sides of a base court, a **forest of chimney stacks** |
| Bodiam Castle | Edwardian | 55 x 50 x 18 | castle | textbook **quadrangular castle**: four **round drum towers** 9 m across and 18 m high, walls ~2 m thick, **twin-towered gatehouse**, moat |
| Caernarfon Castle | Edwardian | 170 x 60 x 12 | castle | **polygonal** rather than cylindrical towers -- seven of them -- two twin-towered gates, curtain to 12 m, walls 6 m thick in places; Eagle Tower 28 m to the parapet |
| Neuschwanstein | Bavarian Romantic | 150 x 40 x 25 | castle | a **150 m ridge of ranges** (`plan_kind = ridge`, spine >= 120 m), slender stair towers under tall **conical spires**, the northern one 65 m (the great tower at the far end of the spine) |
| Himeji Castle | Japanese | 60 x 50 x 15 | castle | **tiered tenshu**: a 15 m battered stone base carrying a 31.5 m timber keep, five storeys outside and seven within, with yagura turrets |
| Château de Chambord | French Château | 156 x 117 x 32 | fortress | 156 m facades, an enceinte round a 44 m-square **keep**, **round corner towers** under conical roofs, a **dormered roofscape**, 56 m tall |
| Krak des Chevaliers | Crusader | 300 x 140 x 20 | fortress | the **concentric** castle: two enceintes, 300 m at its longest and 140 at its widest, outer curtain ~9 m tall and 3 m thick with seven round towers 8-10 m across, inner walls over 4 m thick, and a great **battered talus** |
| Alhambra (Alcazaba) | Moorish | 200 x 70 x 16 | fortress | **square mural towers** and flat roofs; the Torre de la Vela is 16 x 16 m in plan and 26.8 m high |
| Windsor Castle (upper ward) | Norman | 200 x 120 x 18 | fortress | a **motte and bailey** (`plan_kind = motte_bailey`): the **shell keep** -- the Round Tower, 30.5 x 27.5 m internally, 20 m above the ward -- on its mound behind a walled bailey |
| Merchant's tower (Bologna type) | Norman | 8 x 8 x 45 | house | a **tower house**: one shaft four storeys and more, a raised door, walls thicker at the foot, a fighting platform on top, an L jog |
| Tower of London | Norman | 130 x 110 x 10 | fortress | **concentric**, with the White Tower -- a **square keep** 36 x 32 m, 27 m high -- standing **off the axis** in the south-east of the inner ward (`keep_offset`) |
| Conwy Castle | Edwardian | 100 x 40 x 15 | castle | **eight towers**; **two wards side by side**, not nested -- *expected-fail: no side-by-side plan kind yet* |
| Cité de Carcassonne | French Château | 300 x 180 x 10 | fortress | a **double wall** round a town: the inner enclosure is at least 40 % of the outer |
| Malbork Castle | Norman | 320 x 140 x 15 | fortress | **three wards in a line**, in brick -- *expected-fail: no in-line wards plan kind yet* |
| Castel del Monte | Crusader | 56 x 56 x 24 | castle | a regular **octagon** with an **octagonal tower at every angle**, mirror-symmetric across both axes |
| Edinburgh Castle | Edwardian | 200 x 100 x 15 | castle | a **ridge** of ranges, **terraced** up the rock -- *expected-fail: terraces need INT-016* |
| Eilean Donan | Norman | 60 x 50 x 12 | castle | an **island** with **water on every side** and one **causeway** -- *expected-fail: no water plan kind yet* |
| Caerphilly Castle | Edwardian | 240 x 200 x 12 | fortress | concentric inside **two moats** -- *expected-fail: no water plan kind yet* |
| Dover Castle | Norman | 200 x 150 x 15 | fortress | **concentric** with a **great square keep** on the axis, half as tall again as its curtain |
| Mont-Saint-Michel | French Château | 120 x 80 x 40 | fortress | an abbey **church on top of a terraced ring** -- *expected-fail: INT-016 and a church composed from ChurchGeometry* |

## Plan kinds

`CastleSpec.plan_kind` says what SHAPE the design is; the tier says how much
of it there is.

| plan kind | tiers | what it is |
|---|---|---|
| `rect` | all | an axis-aligned enceinte (or a house range); the N = 4 polygon |
| `polygon` | castle, fortress | a regular N-gon (5-8 sides) with a flat edge facing the gate and a tower at every vertex |
| `motte_bailey` | castle, fortress | a walled bailey at the front of the site and a mound behind it: a truncated cone 30-40 degrees steep, 6-15 m high by tier, with an oval **shell keep** on its flat top and one run of curtain climbing the slope from the bailey's back wall to the keep. The keep tops the bailey's curtain by 1.2x. The massing check's `motte` rule proves the keep stands on the top, nothing else stands on the slope, and the climb joins both ends: Windsor, Arundel, Lewes |
| `ridge` | castle, fortress | ranges strung along a polyline spine down the site's long axis (3-6 points, bending 15-45 degrees at every vertex), each under its own roof with a row of windows a storey, a tower at every bend and both ends, and no bailey, gate or keep: Neuschwanstein, Edinburgh, Hohenzollern. The massing check's `ridge` rule counts the ranges and the towers against the spine |
| `tower_house` | house, manor | the house tier grown up instead of out: one shaft of 4-6 storeys, a raised door, walls half as thick again at the foot, a roof platform, an L or Z jog and no curtain. Only a site at least twice as tall as it is wide can be one. `qa/tower_check.gd` measures it: `slender`, `lift`, `foot`, `no_gaps`, `grounded` |

## Feature checklist this drives

- curtain walls with a battered talus, a wall walk and crenellations
- towers: round drums, square towers, polygonal towers; conical, pyramidal,
  flat and tiered caps; one **great tower** per walled castle (`great_tower`,
  a vertex of the outer ring, 1.5-2x the others across and taller with it:
  the Eagle Tower, the Torre de la Vela), which the massing check requires to
  stand alone above the rest
- the hall and the chapel look **into the bailey**: a row of windows on the
  courtyard face, none through the curtain behind, and an **apse** on the
  chapel's free end
- gatehouses with flanking drums, murder holes and a barbican outwork
- concentric planning: an inner ward, and the causeway that ties it to the
  outer gate
- keeps: great square towers, drums, shell keeps, tiered tenshu
- domestic ranges: great hall, chapel, cross wings, courtyard ranges, porches,
  dormers, chimney stacks

## The great hall has an inside

`CastleGenerator.hall_plan(spec)` returns the hall range as a **`HousePlan`**:
one room, in the hall's own frame, whose rectangle is the hall mass footprint
less the wall it stands inside. `CastleGeometry.hall_aabb()` says where that
frame sits in the castle.

The point of doing it this way is that nothing new judges it. The hall is a
house plan, so `HousePlanCheck` measures its room and its openings,
`HouseFurnisher` furnishes it from a recipe like any other room,
`HouseFurnishCheck` judges what stands in it and `HouseNavCheck` walks it. What
makes it a *hall* is six arrangements, each of which is a rule the house
harness already had a name for:

| | |
|---|---|
| the **dais** | a raised rectangle at the end away from the door, a fifth of the hall deep and 0.4 m up. `HousePlan.dais`; the walk grid takes it as a step and a person walks onto it |
| the **high table** | on the dais, looking down the hall at the door. It is `plan.focus` (INT-002), so the furnisher pins it there and the `focus` rule proves it is there and facing the right way. A hall too narrow to stand a table across does not ask for the view it cannot give |
| the **lord's bench** | behind the high table, by the `behind` rule — and nobody sits between the high table and the hall |
| the **trestle rows** | down the length, by the `row` rule (INT-001), benches drawn up to them, each row with its own aisle |
| the **hearth** | on a long wall, on `plan.hearth.wall`, which is the wall the flue rises on (LAY-001) |
| the **screens passage** | a strip inside the door recorded in `plan.zones`, which the furnishing may not fill in and the walk has to reach |

A range that is not the size of a hall gets no plan rather than a bad one.
Under 3 m across or 16 m² it is a lean-to; over 25 m across or 80 m long it is
not a hall either, because a great hall is one room under one roof spanned by a
truss and the widest ever built is Westminster at 20.7 m. A fortress range is
sixty metres across, and that is a courtyard block the massing happens to draw
as a single mass. Either way the range still gets its mass; what it does not
get is an inside. A hall that could not fit its second row of trestles records
a compromise the way any other room does.

The lord's bench stands on its own feet -- no `host` -- because it is not a
chair drawn up to a table and pushed back in: it is where the lord sits, so the
walk has to reach it and a body crossing the dais has to go round it. Benches
drawn up to the trestles keep the house harness's own rule, which is that a
chair belongs to its table.

`CastleFurnisher` still dresses the hall mass from the prop tables below;
CAS-013 is the task that switches `CastleBuilder` over to raising every
interior from its plan instead.

## The keep has an inside

`CastleGenerator.keep_plan(spec)` returns the keep as a **`HousePlan`** of
three or four storeys, one room to each, in the keep's own frame;
`CastleGeometry.keep_aabb()` says where that frame sits.

A keep is the one castle building the house harness already knew how to
describe -- stacked storeys with a stair against the wall is exactly what
`HouseSpec.storeys` and `HousePlanner._add_stair` mean -- so the keep borrows
the harness whole. What it could not borrow is the house's idea of what belongs
on which floor:

| | |
|---|---|
| storey 0 | the **store**: entered from the bailey, and **blind**. No windows at the foot of a keep; that is the point of a keep |
| storey 1 | the **hall**, up a stair over that store |
| storey 2 | a **chamber**, on a four-storey keep |
| the top | the **lord's chamber**, a new kind in `HABITABLE` and `SLEEPING`, with a bed and a fire of its own on `plan.hearth.wall` |

That programme is why `KeepSpec` exists. `HousePlanCheck`'s
`upstairs_programme` rule keeps a dwelling's hall and its one hearth on the
ground floor, which is right for a farmhouse and wrong for a keep; the rule
exempts any spec that can answer `room_program`, the same door a shop and a
hotel go through, and answering it is the whole of what a `KeepSpec` adds.

One stairwell chains every storey, placed by the house planner's own placer so
it stands against a wall and out of the line of the door (LAY-005).

A mass that is not the size of a keep gets no plan: under 3.2 m across it is a
turret, and over 36 m -- the White Tower is 36 x 32 m -- it is a block the
massing happens to draw as one volume rather than a tower anybody lives up.

## Dressing

`CastleFurnisher` fills the shell with props from the same measured catalogue
the houses use (`assets/props/catalog.json`), and logs them on the builder as
`prop_log`. `CastleAssembler` is the only thing that turns one into a node.

| where | what goes in it |
|---|---|
| great hall | high table on the dais with a chalice and candles, chairs behind it, rows of trestles and benches down the length, a brazier on the long wall, barrels in the low corners |
| chapel | altar at the apse end, a candelabrum either side, benches facing it, torches on both walls |
| keep, manor wings, ridge lodgings | a table with stools, a chest, a weapon stand, a barrel, torches and a banner |
| bailey | a cart, an anvil and its fire, a training dummy, weapon stand, barrels, crates, sacks and rope, dealt round the inside of the curtain |
| defences | braziers along the wall walk and on every tower top, torches either side of the gate passage |

Two rules the placer will not break. The **way in** -- a corridor the width of
the gate, from the gate to the back of the bailey -- is reserved before any
clutter is set down, along with every building already standing in the yard.
And a **ridge range is furnished in its own frame**, not in its bounding box:
the spine runs at an angle to the world, and a trestle laid out on the box
stands outside the wall.

A range is logged as one mass from the ground to its eaves, so the dressing
treats a keep's ceiling as `ROOM_CEILING` (5.5 m) rather than the twenty metres
of the mass. It furnishes the ground floor; a banner hung at three quarters of
a keep would fly four storeys above the only floor there is.

## What the suites check

`castle`, `castle normals`, `castle massing`, `castle landmark`,
`castle interiors` and `castle voxel QA` -- run with
`godot --headless --path . --script res://tests/run_all.gd -- castle cnormals cmassing clandmark interior cvoxelqa`.

`castle` proves the great hall and the keep on the twelve canonical castles of
every style and tier; `interior` is the sweep -- two hundred halls and two
hundred keeps at sizes the canonical set does not visit -- and reports the rate
at which each part of the arrangement actually comes out.

`dressing` (shared with the churches) sweeps the same variants and asks
whether every prop is a prop the catalogue knows, whether it stands inside
the building, whether two of them are in the same place at the same height,
and whether a person can still walk from the gate to the middle of the
bailey with the clutter in the way.

The landmark sweep builds every row above at 40%, 70%, 100% and 150% of its
real size, forces the features that make it that building, and then requires
both that the geometry for those features exists and that the massing is still
sound. Krak is the exception worth knowing about: below full size there is no
room between two enceintes for the inner ring's towers to clear the outer
ring's, so it generates as a large single-ward castle, and the suite asserts
that it IS concentric at full size.

## Sources

- https://en.wikipedia.org/wiki/Bodiam_Castle
- https://great-castles.com/bodiamplan.html
- https://en.wikipedia.org/wiki/Krak_des_Chevaliers
- https://archeologie.culture.gouv.fr/crac-chevaliers/en/about-castle
- https://madainproject.com/outer_ward_of_krak_des_chevaliers
- https://en.wikipedia.org/wiki/Caernarfon_Castle
- https://medievalheritage.eu/en/main-page/heritage/wales/caernarfon-castle/
- https://en.wikipedia.org/wiki/Ch%C3%A2teau_de_Chambord
- https://en.wikipedia.org/wiki/Neuschwanstein_Castle
- https://en.wikipedia.org/wiki/Himeji_Castle
- https://www.hyogo-c.ed.jp/~rekihaku-bo/historystation/sp/rekihaku-db/castle/himeji/ca1_en.html
- https://www.english-heritage.org.uk/visit/places/stokesay-castle/history-and-stories/description/
- https://en.wikipedia.org/wiki/Stokesay_Castle
- https://en.wikipedia.org/wiki/Hampton_Court_Palace
- https://www.alhambradegranada.org/en/info/alcazaba/watchtower.asp
- https://castlestudiesgroup.org.uk/wp-content/uploads/2024/10/Shell-Keeps-Catalogue1-Windsor-low-res-07-09.pdf
- https://en.wikipedia.org/wiki/Tower_of_London
- https://en.wikipedia.org/wiki/Conwy_Castle
- https://en.wikipedia.org/wiki/Cit%C3%A9_de_Carcassonne
- https://en.wikipedia.org/wiki/Malbork_Castle
- https://en.wikipedia.org/wiki/Castel_del_Monte,_Apulia
- https://en.wikipedia.org/wiki/Edinburgh_Castle
- https://en.wikipedia.org/wiki/Eilean_Donan
- https://en.wikipedia.org/wiki/Caerphilly_Castle
- https://en.wikipedia.org/wiki/Dover_Castle
- https://en.wikipedia.org/wiki/Mont-Saint-Michel_Abbey
