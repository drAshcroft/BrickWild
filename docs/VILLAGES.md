# Villages

The seventh generator, and the first one that is made of the other six. A
village is not a building; it is a *reason*, a *road*, a *common*, houses
turned toward that road, the trades those houses can support, and an edge
that says where it stops. Everything below is in service of that sentence,
and the harness at the end measures each clause of it.

This is the abstract of a town, not a town. A thousand houses is a failure
mode. The generator takes a population and stops when that population is
housed; the harness fails a village that is bigger than its people.

```
VillageSpec ─▶ SitePlanner ─▶ LotPlanner ─▶ Programmer ─▶ BigGlade.generate()
 population,    roads,          parcels        which lot     per lot, seeded
 style, purpose, common,        along roads,   gets which
 wealth, water  edge, water     front to road  building
                                                     │
                     VillagePlan  ◀──────────────────┘
                     roads, lots, buildings, commons,
                     props, plants, enclosure, fields
                          │              │
                  VillageDresser    VillageBuilder ──▶ ground, roads, walls,
                  props, fences,    VillageAssembler ─▶ bridge, well (mesh)
                  plants, fields                     ─▶ instantiate buildings + props
                          │
                     VillageQA: scale, roads, lots, arrangement, walk, dressing
```

`VillagePlan` is the one thing everyone agrees about, exactly as `HousePlan`
is for a house. The planners write it, the dresser adds to it, the builder
and the assembler read it, and the checks judge it in metres and polygons
without loading a model. The buildings inside it are ordinary
`BuildingRequest`s answered by `BigGlade.generate()`, so a village inherits
every house, shop, church, castle and temple suite for free — a village
that passes `VillageQA` has also passed `HouseQA` on every house in it.

---

## 1. The spec

Everything a person chooses; everything else comes from the seed.

| Input | Range | What it decides |
|---|---|---|
| `population` | 12 – 500 | how many households, and therefore how many buildings, roads and props. Hard cap; above 500 the generator refuses rather than sprawls |
| `culture` | `english`, `frankish`, `norse`, `alpine`, `moorish`, `eastern`, `blighted` | which house, shop, church, castle and temple styles the buildings are asked for, and which plant palette the edge is planted with |
| `purpose` | `farming`, `crossroads`, `market`, `mill`, `fishing`, `mining`, `garrison`, `pilgrim`, `forest` | the reason the village is there: which landmark it has, what the through road does, what lies outside it |
| `wealth` | 0 – 1 | house sizes and storeys, stone vs timber, paved vs dirt roads, how much dressing |
| `enclosure` | `none`, `hedge`, `palisade`, `wall` | what the edge is made of; `wall` needs `population ≥ 150` or `garrison` |
| `water` | `none`, `pond`, `stream`, `river`, `coast` | a water body on the site, which the mill, the ford/bridge and the fishing strand need |
| `seed` | int | everything else |

Derived, and recorded on the spec so a variant is reproducible from the
seven inputs alone:

| Derived | Rule |
|---|---|
| `households` | `round(population / PEOPLE_PER_HOUSEHOLD)`, 4.5 people; ±10 % from the seed |
| `form` | the village shape, from §3, chosen by population and purpose |
| `programme` | the list of non-house buildings the population earns, from §4 |
| `site` | a rect sized from the programme: `Σ lot areas × 1.6` plus the common, plus the edge band |
| `variant_name` | `CastleGenerator`'s word lists, with village suffixes (` -ton`, ` -ham`, ` -by`, ` -thorpe`, ` Ford`, ` Cross`, ` Mill`, ` Green`) |

Between 12 and 500 people, households run from 3 to about 110. Add the
programme and a fortified market town at the cap comes out near 140
buildings. That is the top of the envelope, and the harness's first rule
holds it there.

---

## 2. What a village IS: the six clauses

Each of these is a paragraph here and a group of rules in §9.

1. **A reason.** Nobody lives at a random point in a field. A village sits
   at a ford, a crossroads, a mill stream, a harbour, a mine mouth, a lord's
   gate or a shrine. `purpose` names it and the site planner puts the
   landmark for it *first*, before any house, because everything else is
   arranged around it.
2. **A road that goes through.** The through road enters at one edge,
   leaves at another, and passes the common on the way. Houses are on it or
   on lanes off it. A road that ends inside the village is a lane to a farm,
   and there are not many of those.
3. **A common.** A green, a square, a widening of the road with the well on
   it. The church, the market and the tavern are on it or next to it. It is
   the one place in the village where nothing is built.
4. **Houses that face the road.** Every lot has a road frontage; every house
   fronts it with its door a few steps from the verge and its yard behind.
   This is what makes a row of generated houses read as a street rather
   than as a scatter.
5. **The trades the people can support.** A smith at thirty souls, a tavern
   at forty, a church at sixty, a market at a hundred. Nothing the
   population has not earned.
6. **An edge.** Hedge, palisade, wall, or just the backs of the outer houses
   and the woods beyond — but *something*, so a person standing on the
   common can tell they are inside and a person on the road can tell they
   have arrived. Fields, orchards and trees outside it.

---

## 3. The forms: what a village looks like from above

Real village morphology has a handful of shapes, and they are the whole
vocabulary needed. Each is a road-graph pattern plus a common shape; the
lots and buildings follow.

| Form | Plan | When | Real name |
|---|---|---|---|
| **street** | one road, houses on both sides, long strips behind | 12 – 80, `farming`, `forest`, `mining` | *Strassendorf*, the English street village |
| **green** | houses round an open green with the well and pond, the through road across one side or through the middle | 40 – 200, `farming`, `pilgrim` | *Angerdorf*, the green village |
| **crossroads** | two roads crossing, the common at the crossing, the inn on the corner | 30 – 150, `crossroads`, `market` | |
| **round** | houses in a fan round a circular common, one lane in | 12 – 60, `farming`, `forest`, `blighted` culture | *Rundling* |
| **strand** | one row along the shore, the road behind the row, boats and racks in front | 15 – 100, `fishing`, `coast` | the fishing village |
| **planted** | a market square with a short grid of streets | 150 – 500, `market`, `garrison` | the bastide |
| **gate** | a street village with a manor or keep at the head of it | any, `garrison`, or `population ≥ 200` | the castle village |

Two things every form shares: the through road, and the common. A form
without a common is a hamlet, and a hamlet is the `street` form below 25
people with the common shrunk to the well.

```
            green village, 80 people, farming, stream to the north

   ~~~~~~~~~~~~~~~~~~~~~~ stream ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        [mill]══race══                              . . . . .
   ─────┬────────────────────┬─────────────────────┬─────── through road
   [h] [h] [h]  [smithy]    │    [tavern] [stable] │ [h] [h]
   ─────┘                    │                      │
       [h]              . . . . . GREEN . . . . .   [shop]
       [h]         [church]   (well)  (pond)        [h]
       [h]              . . . . . . . . . . . . .   [h]
   ─────┐                    │                      │
   [h] [h] [farm]═══lane═══  │  [h] [h] [h] [h]     └──── lane ──── [manor]
   ─────┴────────────────────┴──────────────────────────── through road
   ┃ hedge ┃ ▒▒ orchard ▒▒ ┃ ░ strip fields ░░░░░ ┃ ♣♣ wood ♣♣
```

---

## 4. Population to programme

The thresholds are the village's `RECIPES`. Every row is a building family
the generator already has; the village asks for it by `BuildingRequest`
and never draws one of its own.

| People | Building | Request | Where it goes |
|---|---|---|---|
| every | houses | `house(seed, style, trade, w, l, h, storeys)` — one per household; trade from the trades the village needs | on lots, §5 |
| every | a well | `MeshKit` (no asset — §7) | on the common, 1 per 60 people |
| ≥ 20 | shrine | `temple` small form, or `church` at 12 m | on the common or the high point |
| ≥ 30 | smithy | `shop(&"blacksmith")` | on the through road, at the edge |
| ≥ 40 | tavern | `shop(&"tavern")` | on the through road, near a gate, facing the common |
| ≥ 50 | mill (if `water`) else bakery | `shop(&"bakery")` + a mill mass | on the water, with a race |
| ≥ 60 | church | `church(seed, style, 10, 20, 12)` | on the common, on its own churchyard lot |
| ≥ 60 | general store | `shop(&"general_store")` | on the common |
| ≥ 80 | inn + stable | `shop(&"inn")`, `shop(&"stable")` | on the through road, stable behind or beside |
| ≥ 80 | carpenter | `shop(&"carpenter")` | any street |
| ≥ 100 | market | `Stall_Empty` / `Stall_Cart_Empty` rows on the square; butcher and tailor shops | the common becomes a square |
| ≥ 100 | town hall | `shop(&"town_hall")` | on the square |
| ≥ 120 | apothecary, second tavern | `shop(...)` | streets |
| ≥ 150 | guildhall; the wall is allowed | `shop(&"guildhall")`, `enclosure = wall` | on the square; the wall round everything |
| ≥ 200 or `garrison` | the lord's house | `castle` at `house` or `manor` tier (≤ 2 000 m²) | at the head of the village on its own lane, §6 |
| `pilgrim` | a temple and an inn at any size | `temple(...)` | the temple takes the church's place and the common is its forecourt |
| `mining` | a mine mouth, a smithy at any size | a `MeshKit` adit + `shop(&"blacksmith")` | at the far end of the through road |
| `fishing` | racks, boats, a smokehouse | props | on the strand in front of the row |

House trades follow the same idea: of the households, `farmer` fills most of
a farming village, `none` most of a market town; `smith`, `alchemist`,
`scholar`, `innkeeper` appear once the matching shop or the population
justifies them. The house `style` comes from the culture; `wealth` sets
storeys (1 below 0.3, 2 above 0.6) and moves the mix from `cottage` to
`townhouse`.

---

## 5. Roads and lots

### Roads

A road is a polyline with a class. Class sets width, verge and surface.

| Class | Width | Verge | Surface (by wealth) | Role |
|---|---|---|---|---|
| `through` | 6 m | 1.5 m | dirt → gravel → cobble | enters and leaves the site; the only class that crosses the enclosure |
| `street` | 4 m | 1 m | dirt → cobble | joins the through road to the common and the lots on it |
| `lane` | 2.5 m | 0.5 m | dirt | serves a handful of lots or one farm; may dead-end at a lot |
| `path` | 1.2 m | 0 | trodden; `RockPath_*` stepping stones at wealth ≥ 0.5 | door to road, across the green, round the church |
| `track` | 3 m | 0 | dirt | out to the fields; outside the enclosure only |

The site planner lays the through road first (a gentle curve or two, never a
straight line the whole width of the site: `bend radius ≥ 3 × width`,
`≤ 25° per 20 m`), then the common on it, then streets and lanes by the
form's pattern, then the enclosure with a `gate` mass wherever a through
road crosses it, then a `bridge` (`BridgeSection`) or ford where any road
crosses water. Junctions are `≥ 30°` and `≥ 8 m` apart except round the
square.

### Lots

A lot is a polygon with a `front` edge on a road. The lot planner walks each
road and cuts frontages along it: `frontage = building width + gap`,
`depth = 2 – 4 × frontage` for farms, `1 – 1.5 ×` for town lots. Corner lots
front the more important road. The common, the churchyard, the water and
the roads themselves are never lots.

| Lot rule | Value |
|---|---|
| **setback** — door to road edge | cottage 1.5 – 6 m; townhouse 0 – 1 m; farm 4 – 12 m; church 6 – 15 m; manor ≥ 20 m on its own lane |
| **fire gap** — between building bounds | cottage ≥ 1.5 m; farm ≥ 6 m; townhouse may touch its neighbours (a terrace) when `wealth ≥ 0.5` and `form = planted` |
| **front** — building local −Z toward the front edge | within 15°; every family's front is −Z (`BigGlade.placement()`), so this is one rule for all of them |
| **fit** — `placement().bounds` inside the lot | with the fire gap as margin |
| **yard** — the rest of the lot | garden, orchard, hedge, props by trade |

Building sizes come from the family's `describe_kind()` envelope, scaled by
wealth and the household, and every request is sent through
`BigGlade.generate()`; the lot is sized from the *measured* `placement()`
bounds afterwards, never from the requested envelope, for the same reason
the massing check reads `mass_log` and not the spec.

---

## 6. Arrangement: where things go and why

This is the village's feng shui, and it is the part the harness cares most
about, because a village with the right buildings in the wrong places reads
as a scatter.

| Thing | Rule | Why |
|---|---|---|
| **church / temple** | on the common, or on the highest ground; clear ground on three sides (the churchyard); its tower or spire the tallest mass; visible from every gate | it is the landmark, and the village is arranged so you find it |
| **well** | on the common, ≥ 6 m from any building, a path to it from the road | everybody walks to it |
| **tavern / inn** | on the through road, within 60 m of a gate, its front to the road or the common | travellers find it before they find anything else |
| **stable** | within 20 m of the inn, its wide door to the road | |
| **smithy** | on the through road at the edge, ≥ 12 m from the church and the tavern, downwind (+x by convention) | fire, noise, and the smell |
| **mill** | on the water, the race adjoining, a lane from the through road | it cannot be anywhere else |
| **market stalls** | in rows on the square, rows ≥ 4 m apart, every stall fronting an aisle | walkable, and reads as a market |
| **town hall / guildhall** | on the square, its front to it | |
| **manor / keep** | at the head of the village at the far end of a lane, its own footprint clear ≥ 15 m all round, its gate facing the village | the lord looks down the street |
| **farms** | at the edge, on lanes, their yards toward the fields | |
| **hovels and big houses** | the bigger and taller houses nearer the common, one-room cottages at the edge | the wealth gradient every real village has |
| **the outside** | strip fields on the `farming` side, orchards behind the farms, pasture with fences, a wood on the far side, the churchyard's yews, the mill pond | the village is bounded because the outside is different |

---

## 7. Props: what is in the packs and what is not

Inventory of `C:\Projects\itch_assets\quaternius`, read on 2026-09-03.
Everything the village uses goes through the same measured catalogue as the
houses (`tools/build_prop_catalog.gd` → `catalog.json`), and `assets`
re-measures it.

Imported (VIL-011): the **Nature Kit** as pack `nature` and the **Stylized
Nature MegaKit** as pack `wild` — 104 plants between them — and the
dungeon-kit village pieces that were still missing (`BridgeSection`,
`Column_BridgeSupport`, `Wall`, `Wall_Half`, `Wall_Broken`,
`Doors_RoundArch`). Both nature packs are prefixed on disk (`Nature_*`,
`Wild_*`) because they each ship a `DeadTree_1`.

A plant is measured differently from a barrel, and `PropCatalog.PACKS` marks
the two packs `plants` so it is. It gets a **`canopy`** and a **`trunk`**
radius as well as a box, because a box is the wrong shape for a tree: a
birch is a two-metre box of empty air round a 16 cm stem, and a village
planted on the box has no trees within four metres of anything. `canopy` is
the furthest any vertex reaches from the model's axis; `trunk` is the same
at or below 1.8 m — what a person walking into it walks into, so a spruce
whose skirt sweeps the ground measures the skirt and a bush measures the
bush. Both are taken from the **vertices**, not from each mesh's declared
bounding box, because two of the Nature Kit's bushes declare one half a
metre bigger in every direction than the mesh inside it — measure those from
the box and the bush floats. `SceneBounds.plant_of_node()` is the single
measurement; the tool writes it down and the `assets` suite takes it again.

**Fantasy Props MegaKit** (already imported for houses) — outdoor use:
`Stall_Empty`, `Stall_Cart_Empty` (market), `Barrel`, `Barrel_Apples`,
`Barrel_Holder`, `Crate_Wooden`, `FarmCrate_Apple`, `FarmCrate_Carrot`,
`FarmCrate_Empty`, `Bag`, `Bucket_Wooden_1`, `Bucket_Metal`, `Bench`,
`Stool`, `Anvil_Log`, `Dummy`, `WeaponStand`, `Torch_Metal`,
`Lantern_Wall`, `Banner_1`, `Banner_2`, `Cauldron`, `Cage_Small`, `Rope_*`,
`Chain_Coil`, `Pickaxe_Bronze`, `Axe_Bronze`, `Shield_Wooden`.

**dungeon kit** (OBJ) — the pieces a village needs that nobody made a
village kit for: `Rail_Straight`, `Rail_Corner`, `Rail_Divider` (fences),
`Cart`, `BridgeSection`, `Column_BridgeSupport`, `Statue_Fox`, `Statue_Stag`
(on the green), `Torch`, `Wall`, `Wall_Half`, `Wall_Broken`, `Bricks`
(ruins and garden walls), `Pot1–3` and their broken versions, `Skull`,
`BearTrap_*` (the forest edge), `Trapdoor` (a cellar), `Doors_*` (a gate).

**Nature Kit** (glTF): `BirchTree_1–5`, `MapleTree_1–5`, `DeadTree_1–10`,
`Bush`, `Bush_Large`, `Bush_Small` and their `_Flowers` variants,
`Flower_1–5` and `_Clump`, `Grass_Small`, `Grass_Large`.

**Stylized Nature MegaKit** (glTF): `CommonTree_1–5`, `Pine_1–5`,
`TwistedTree_1–5`, `DeadTree_1–5`, `Bush_Common`, `Bush_Common_Flowers`,
`Fern_1`, `Plant_1`, `Plant_7` and `_Big`, `Clover_1–2`, `Flower_3–4`
`_Single`/`_Group`, `Grass_Common_Short/Tall`, `Grass_Wispy_Short/Tall`,
`Mushroom_Common`, `Mushroom_Laetiporus`, `Rock_Medium_1–3`,
`Pebble_Round_1–5`, `Pebble_Square_1–6`, `RockPath_Round_*`,
`RockPath_Square_*` (stepping stones), `Petal_1–5`.

**Missing from every pack**, and therefore built rather than loaded, so the
village never depends on an asset that is not there. Implemented as
`core/prop_kit.gd` (VIL-010) — a kit of its own over `MeshKit`, the way
`LightKit` is, because `MeshKit` takes plain sizes and does not know what a
well is. All ten: the **well** (a revolve drum, two posts, a windlass and a
little roof), the **signpost**, the **palisade** (posts from `box` at a
pitch, sharpened by `taper`, with a waling piece), the **lamp post** (a post
carrying `Torch_Metal`), the **haystack** (a revolve dome), **fence gates**,
the **mill wheel** (two revolve rings, spokes and paddles), the **mine
adit**, the **boat** and the **drying rack** for the strand.

Every one returns the world `AABB` of what it emitted, accumulated from the
pieces as they go out rather than written down beside them — the discipline
`MassBuilder` keeps for buildings, for the same reason: the walk grid, the
fire gap and the road-clearance rule all measure that box, so a well whose
roof hangs out of it is a well people walk through. `PropKitSuite` (`props`
in the runner) reads the mesh back vertex by vertex and proves it holds; it
caught three props understating themselves the first time it ran.

**Animals** are still not built at all; a fence round an empty pasture reads
as a pasture.

### Prop recipes, by host

Implemented as `src/village/village_dresser.gd` (VIL-013), and called at the
end of `VillageLotPlanner.plan()` -- a planned village is a dressed one,
because the rules that judge the arrangement (what stands on the common,
what is in a doorway, what is in the road) are judging the props as much as
the buildings.

Two things it does that the house furnisher does not. **Plants are kept apart
from props**, in `plan.plants`, because they are judged differently: a prop is
a footprint, a plant is a trunk you walk round and a canopy that must not
hang over a roof, and §8's rules are about those two radii. And **it measures
with the checks' own functions** -- a prop's ZONE against the road ribbon
with its verge, through `VillageLotPlanner.overlap_area`, which is exactly
what `RoadCheck.clear` does. Measuring it any other way put anvils in the
road: the check tests the zone and the first version tested the anvil, and
`Poly.intersection_area` clips convex polygons while a road ribbon bends.

Like `HouseFurnisher.RECIPES`, each host has steps of `{cat, rule, n, opt}`
and the rules mean what they mean indoors, translated:

| Rule | Outdoors it means |
|---|---|
| `wall` | against the host building's wall, not across a door or window (`door_clear_rect`, `window_clear_rect` reused) |
| `yard` | in the lot behind or beside the building, off the path to the door |
| `verge` | on the road verge in front of the lot, never on the carriageway |
| `corner` | at a lot corner or a fence corner |
| `row` | N copies along an axis at a pitch — stalls, racks, orchard trees, fence posts |
| `on` | on a cart, a stall, a bench |
| `light` | a torch or lantern; the same `LIGHT` tag, with the `OmniLight3D` the temple assembler already knows how to add |

| Host | Recipe |
|---|---|
| any house | `Barrel` or `Bucket` by the door (`wall`, 0.7); `Bench` (`wall`, 0.4); a `Bush_*_Flowers` either side of the path (`verge`, 0.6); a hedge of `Bush_Common` along the lot's side edges (`row`, wealth × 0.8) |
| farm | `FarmCrate_*` and `Bag` in the yard (`yard`, 0.9); `Cart` (`yard`, 0.6); haystack (`yard`, 0.8); an orchard of `CommonTree` behind (`row`, 0.7); `Rail_*` round the pasture |
| smithy | `Anvil_Log` and `Barrel` outside the door (`wall`, 1.0); `Bucket_Metal` (`wall`, 0.8); `Torch_Metal` (`light`, 1.0) |
| tavern / inn | `Bench` ×2 and `Barrel` on the verge (`verge`, 1.0); `Lantern_Wall` by the door (`light`, 1.0); `Banner_*` (`wall`, 0.6); `Cart` by the stable |
| market square | `Stall_Empty` / `Stall_Cart_Empty` (`row`, 1.0, rows 4 m apart); `Crate_Wooden`, `FarmCrate_*` (`on`, 0.9); `Torch` on posts at the row ends (`light`, 1.0) |
| the common | well (1.0); `Statue_*` or a single `CommonTree` at the centre (0.5); `Bench` ×2 (0.7); `Flower_*_Clump` (0.6) |
| church | yews — `Pine_*` (`row`, 0.8) round the churchyard; a low `Wall_Half` ring with a gap on the path |
| gate | `Torch` ×2 (`light`, 1.0); signpost (1.0); the palisade or wall either side |
| water | `BridgeSection` on the road; `Rock_Medium_*`, `Fern_1`, `Grass_Wispy_*` along the bank; the mill wheel |
| strand | boats, `Rope_*`, `Crate_Wooden`, drying racks (`row`) |
| the edge | trees by culture palette (§8), `Rock_Medium_*`, `Mushroom_*` in the `blighted` and `forest` palettes, `DeadTree_*` in `blighted` |

---

## 8. Plants and the outside

A culture has a palette, and the palette says which trees stand at the edge,
which on the green, and what grows on the verges.

| Culture | Edge trees | Green tree | Hedge / verge | Ground |
|---|---|---|---|---|
| `english`, `frankish` | `CommonTree_*`, `MapleTree_*` | one `CommonTree` | `Bush_Common`, `Flower_*_Clump` | `Grass_Common_*`, `Clover_*` |
| `norse`, `alpine` | `Pine_*`, `BirchTree_*` | `BirchTree` | `Bush_Small`, `Fern_1` | `Grass_Wispy_*`, `Rock_Medium_*` |
| `moorish`, `eastern` | `CommonTree_*` sparse, `TwistedTree_*` | one `TwistedTree` | `Plant_1`, `Plant_7` | `Pebble_*`, `Grass_Common_Short` |
| `blighted` | `DeadTree_*`, `TwistedTree_*` | none | `Mushroom_*` | `Grass_Wispy_Short`, `Skull`, `Bricks` |

Rules the planter follows, each of which the dressing check re-measures:

- **Trunks** ≥ 1 m from any road polygon and any building's `placement()`
  bounds; **canopies** (the measured `canopy` radius) over no roof at all.
- The **edge band** outside the enclosure is planted at the culture's
  density (`forest` purpose doubles it); inside it, only the green tree, the
  churchyard yews and the orchards.
- **Orchards** are `row` placements behind farms, pitch 5 m, inside the lot.
- **Hedges** run along lot side boundaries, with a gap at the path.
- **Strip fields** (`farming`) are long rects outside the enclosure on the
  side away from the water, each touching a `track`; **pasture** is a
  fenced rect (`Rail_*` in a closed loop with a gate) outside the enclosure;
  the **wood** is the far side.
- **Ground cover** is scattered on verges and the common at a density per
  wealth (a poor village is muddy, a rich one is mown), never on the
  carriageway, never in a doorway.

---

## 9. The harness: `VillageQA`

Implemented (VIL-006..009): `qa/village_scale_check.gd`,
`qa/village_road_check.gd`, `qa/village_lot_check.gd` and
`qa/village_place_check.gd`, composed by `qa/village_qa.gd`, which then runs
the family QA on every building. `qa/village_measure.gd` is the one place
"the front of a building", "its door" and "the common's centre" are defined.
Every rule takes an override (RuleSet, INT-020). The rules that are about
things the planner does not yet lay -- water crossings, gates, the well,
stalls, the mill -- run only when the plan carries them, and each has a
fixture in `tests/suites/village_check_suite.gd` (`vcheck`) that builds the
thing by hand to prove the rule fires. Three planner changes came with them:
households come in sizes (the programmer, `HOUSE_SIZE_SPREAD`), the lot
planner takes the frontage nearest the common first (the wealth gradient of
6), and when the form's frontage cannot house everyone the site planner is
asked for back lanes and then for more ground (`VillageLotPlanner.RETRIES`),
and dead-end lanes are trimmed to their last lot.

**The arrangement pass (VIL-012)** then made the planners meet most of §6.
Where each thing goes is now a table, `VillageLotPlanner.SITING`, one row per
thing: the road class it insists on, whether it is placed before the
households (the smithy and the tavern are), what it is drawn to (`common`,
`gate`, `edge`, `outside`) and which side of the common it belongs on. Six
changes came with it, and each is a rule the checks were already measuring:

- Candidate frontages are compared **across every road at once** rather than
  road by road in rank order. A farm wants the one frontage nearest the site
  edge and a house the one nearest the common; taking the best spot on the
  through road first gave neither, and left the street round the common
  empty while the through road filled up (`common` measured 50 %).
- **The wealth gradient is enforced, not hoped for**: households are handed
  over biggest first and no house may stand nearer the common than a bigger
  one already does, less a few metres of slack.
- **The tavern takes the upwind gate and the smithy the downwind edge**, so
  the two stop competing for the same end of the through road.
- **Farms are out of the gradient and into their own rule.** A farmhouse is a
  big building and `farms outside` puts it at the edge, so counting it in
  `gradient` asked the planner to satisfy two rules that contradict each
  other. Each rule now names the set it measures.
- **Back ways are `track`s that run to the site boundary**, not lanes that
  stop short of it -- §9.2 forbids a lane to end on the boundary and refuses
  a dead-end lane over forty metres, and a way out to the fields is neither.
  They are laid on whichever side of the through road has the ground, one
  per two households, fifty metres apart (a farm lot is twenty-five metres
  deep either side).
- **A village that outgrows itself gets longer, not wider**, and every extra
  lane is tried before a metre of ground is added -- which is what `density`
  was measuring.

`density` and `common` now pass on every village in the sweep; `gradient`
went from seven villages in twenty-four to one and `tavern` from nine to
three. What is left -- `tavern`, `gradient`, `smithy`, `landmark`, `farms` --
is listed in `VillageCheckSuite.PLANNER_FOLLOW_UPS` with the follow-up each
needs; the sweep counts and prints them as warnings and fails on everything
else. Their fixtures still fire.

`qa/village_qa.gd` now composes all six (VIL-017) -- scale, roads, lots,
places, dressing and walking -- and then runs the family QA on every building
in it. The order is §9's own and it is the order a person would look in;
walking is last because it is the only one that rasterises the whole site,
and there is no sense grinding a grid over a plan that has already failed to
be a village. `VillageQA.ascii_map()` draws the walk and
`VillageQA.dressing_map()` draws what is standing about.

Composing the last two turned three disagreements between the dresser and
the checks into fixes, all of them the same lesson -- **the placer and the
check must measure with the same function**: a bench on the verge is on the
ROAD and not on its lot, and `host` had to say so; the dresser's rect-overlap
test for a trunk's clearance and the check's true-distance test disagreed by
centimetres, so the dresser uses the check's; and a prop must stand on ground
its host owns, which the dresser now refuses to break rather than leaving
`host` and `use` to report it afterwards. The common also stopped being an
island: §3 calls it "a widening of the road" and a metre and a half of ground
that is neither road nor common nor lot is a moat the walk grid cannot cross.

`qa/village_qa.gd` composes six checks over the `VillagePlan` and then runs
the family QA on every building in it. Each rule is a sentence and a
measurement, in the vocabulary the harness already has: `Rect2`/polygon
geometry, `WalkGrid`, `MassRules`, `_segment_hits` from the rite check, and
`BigGlade.placement()` for building bounds and fronts. `ascii_map()` prints
the plan — roads, lots, building fronts, the common, the walk — because a
village is the building most in need of being *looked at*.

### 9.1 `ScaleCheck` — is this a village, not a city?

| Rule | The sentence | The measurement |
|---|---|---|
| **housed** | there are as many houses as there are households | `count(house) = households ± 10 %`; `households = population / 4.5 ± 10 %` |
| **not a city** | it stops | `count(buildings) ≤ 140`; `population ≤ 500`; site area ≤ 400 × 400 m |
| **earned** | every building the people can support exists, and nothing they cannot | the §4 table, both directions: a guildhall at 40 people fails, and so does a village of 100 with no tavern |
| **density** | neither a scatter nor a slum | `Σ placement().bounds area ÷ site area` between 0.06 and 0.30 |
| **pure** | the same spec twice is the same village | `VillagePlan` equal on two generations; `spec` unchanged by planning |

### 9.2 `RoadCheck` — do the roads make sense?

| Rule | The sentence | The measurement |
|---|---|---|
| **connected** | you can drive from any road to any other | the road graph is one component |
| **through** | the through road comes in one side and goes out another | exactly one `through` polyline (two at a crossroads) with both ends on the site boundary, on different sides; it passes within 15 m of the common |
| **hierarchy** | lanes join streets, streets join the through road | every `lane` endpoint is on a `street`/`through` or at a lot; every `street` endpoint is on a `through`/`street` |
| **no dead ends** | a road goes somewhere | any endpoint not on the boundary or another road is a `lane` ending at a lot's front; dead-end `lane` length ≤ 40 m |
| **width** | a road is as wide as its class | the ribbon polygon's width is the class width ± 5 % along its whole length |
| **bends** | roads curve, they do not kink | turning ≤ 25° per 20 m; bend radius ≥ 3 × width |
| **junctions** | roads meet at angles you can turn through, and not on top of each other | every junction's smallest angle ≥ 30°; junction centres ≥ 8 m apart except on the square |
| **clear** | nothing stands in the road | no `placement().bounds`, lot, prop footprint or tree trunk intersects a road polygon grown by its verge |
| **crossings** | water is crossed by a bridge or a ford, on the road | every intersection of a road with a `water` polygon contains a `bridge` or `ford` mass whose centre is on the road centreline |
| **gates** | roads cross the edge only at gates | every intersection of a road with the enclosure polygon contains a `gate` mass; no other opening in the enclosure |

### 9.3 `LotCheck` — do the houses sit on the street?

| Rule | The sentence | The measurement |
|---|---|---|
| **tiling** | lots do not overlap each other, the roads, the common or the water | pairwise polygon intersection area = 0 |
| **frontage** | every lot has a road | each lot has a `front` edge collinear with a road edge, length ≥ building width + 1 m |
| **faces the road** | the house looks at the street | the angle between `placement().front` (local −Z) and the front edge's inward normal ≤ 15° |
| **setback** | the door is a few steps from the road | distance from the door (from the plan for houses/shops; from the gate mass for castles; from the west door for churches) to the road edge within the §5 range for its kind |
| **fit** | the building is on its lot | `placement().bounds` inside the lot polygon with the fire gap as margin |
| **fire gap** | neighbours do not touch | `MassRules.separation` between any two buildings ≥ the §5 gap, terraces excepted where allowed |
| **not back to front** | no house stares at a blank wall | no building's front faces another's back at < 8 m |
| **variety** | no two neighbours are the same house | adjacent buildings differ in (style, storeys, footprint rounded to 0.5 m) or in seed-derived variant; no style is > 45 % of houses unless `form = planted` |

### 9.4 `PlaceCheck` — is everything where a village puts it?

| Rule | The sentence | The measurement |
|---|---|---|
| **common** | there is a common, and it is fronted | a `common` polygon ≥ 150 m² (≥ 30 m² in a hamlet); ≥ 60 % of its perimeter lies within 12 m of a building *front*; nothing built inside it but the well, stalls and the green tree |
| **landmark** | the tallest thing is the church or the keep, and you can see it from the gate | the tallest `placement().bounds` is the landmark's; `_segment_hits` from eye height at every gate to its upper third, against every other building's bounds, is clear |
| **well** | on the common, apart | the well is inside the common; ≥ 6 m from any bounds; a `path` reaches it |
| **tavern** | by the road, by the gate | the tavern's front is on a `through` or on the common; distance to the nearest gate ≤ 60 m |
| **stable** | by the inn | ≤ 20 m from the inn; its front door ≥ 1.5 m wide faces a road |
| **smithy** | at the edge, away from the church, downwind | on a `through`; ≥ 12 m from church and tavern bounds; `x ≥` the common's centre x |
| **mill** | on the water | the mill's bounds touch the `water` polygon; a `race` polygon adjoins both |
| **market** | rows on the square, with aisles | stall footprints lie on the common; rows parallel, ≥ 4 m apart; every stall's front faces an aisle |
| **civic** | the hall fronts the square | town hall / guildhall front edge on the common's perimeter |
| **manor** | at the head, alone | the castle's bounds ≥ 15 m from any other bounds; on a `lane` of its own; its gate (local −Z) faces the common's centre within 30° |
| **churchyard** | the church has room | clear ground ≥ 6 m on ≥ 3 sides of the church's bounds |
| **gradient** | the big houses are in the middle | Spearman correlation of house floor area with distance to the common's centre ≤ −0.3 |
| **farms outside** | farms face the fields | every `farmer` house is within 30 m of the enclosure and its yard side faces outward |

### 9.5 `VillageNavCheck` — can a person walk it?

Implemented as `qa/village_nav_check.gd` (VIL-016), on the same `WalkGrid`
the house nav check and the temple rite check use. Roads with their verges,
the common and the lots are floor; buildings, water and the props and plants
that take FLOOR are obstruction — a wall lamp hangs above head height and
grass is walked over, and `PropCatalog.blocks_floor` already knows which is
which. Blocking on every plant made the verges solid and pinched the through
road to nothing.

Three of its measurements had to be written more carefully than the sentence
suggests, and each is commented where it lives. A door sits ON the wall and
the wall is solid, so every rule about a door measures from the first ground
OUTSIDE it a person can stand on. A through road runs from one edge of the
site to the other by definition and the grid stops at the site, so the ends
are not sampled — they measure the width of the world. And a prop's use zone
is centred on the prop, so asking whether the zone was reached asks whether a
person can stand inside the well.

`paths` is the one rule that cannot yet be measured as §9.5 states it: the
site planner lays no `path` roads. It measures the two halves it can — that
there is standing ground outside every door, and that any `path` that does
exist stays 1.2 m clear — and says so rather than measuring the straight line
to the lot's frontage, which on a jettied townhouse starts on the road and
ends inside a building.


`WalkGrid` over the whole site at a cell size chosen per village the way
`VoxelGrid` chooses its voxel per castle — 0.25 m for a hamlet, 0.5 m at the
cap, where a 400 m site is 640 k cells — with roads, paths, verges and the common as floor; buildings, water, walls,
fences, props with footprints and tree trunks as obstacles; person radius
`PERSON_RADIUS`.

| Rule | The sentence | The measurement |
|---|---|---|
| **arrive** | you can walk from any gate to any door | flood from each gate's centre; every building's door threshold `reached` |
| **use** | you can reach every prop meant to be used | every prop with a non-empty `zone` `reached` |
| **the road stays open** | the through road is never pinched | `clearance_along` the through centreline ≥ half its width everywhere |
| **paths** | door to road without crossing a yard | a `path` from every door to its road, ≥ 1.2 m clear the whole way |
| **the common** | mostly standable | `standable` ≥ 0.7 of the common's area |
| **outside** | the fields and the mill are reachable | every `track` endpoint and the mill door `reached` from a gate |
| **map** | `ascii_map()` | `#` built, `=` road, `.` common, `~` water, `|` enclosure, `G` gate, `T` tree, space reached, `:` never reached |

### 9.6 `DressCheck` — do the props and plants belong?

Implemented as `qa/village_dress_check.gd` (VIL-015). Twelve rules, and each
has a fixture in `VillageCheckSuite` that breaks exactly it. `fences` and
`fields` run only when the plan carries them, the way `PlaceCheck` treats the
mill and the market — the planner does not lay either yet, and their fixtures
build them by hand so the rules can still be seen to fire.

It found four real gaps in the dresser the first time it ran, all now closed:
a hundred and fourteen metres of unbounded edge (the band is walked at a
pitch now, and its count comes from the perimeter and not the recipe), an
unlit village twice over (a wall lamp was competing for ground with the anvil
already against that wall, and then landing on the road because a shop's
setback is six-tenths of a metre — it hangs ON the wall and is held to the
doorway and the road but not to the floor it does not take), and a village
whose whole edge was one tree.


| Rule | The sentence | The measurement |
|---|---|---|
| **host** | every prop belongs to something | every prop lies within its host's lot or the common; a `yard` prop is behind the front line of its building; nothing has no host |
| **doorways** | nothing in the swing of a door | `door_clear_rect` of every exterior door is empty of prop and plant footprints |
| **not in the road** | | `RoadCheck.clear` applied to props and trunks |
| **stalls face the aisle** | | each stall's local −Z points across an aisle, not into another stall |
| **fences** | on the boundary, with a way through | every `Rail_*` segment lies on a lot or pasture boundary; every closed fence loop has a gap or gate ≥ 1.2 m; no fence crosses a path |
| **trunks and canopies** | trees do not stand in the road or grow through roofs | trunk ≥ 1 m from any road polygon and any bounds; canopy circle ∩ any roof footprint = ∅ |
| **the edge is planted** | the village is bounded by something | walking the enclosure polygon, no run > 25 m without a building back, a hedge, a wall or a tree within 6 m, except at gates and water |
| **the green tree** | at most a few | 0 – 3 trees inside the common, none within 4 m of the well |
| **ground cover** | on the ground, off the road | `Grass_*`, `Flower_*`, `Pebble_*` only on verges, the common, lots and the edge; density within the wealth band |
| **lights** | the night has somewhere to go | every gate has ≥ 1 light; the tavern, the well and the square have one; every door is ≤ 25 m from a `LIGHT`-tagged prop; every light gets an `OmniLight3D` in the assembler |
| **fields** | outside only | every field and pasture polygon lies outside the enclosure and touches a `track`; none inside |
| **culture** | the plants match | every plant key is in the culture's palette |

### 9.7 What every building still has to pass

`VillageQA.check()` ends by running `HouseQA`, `CastleQA`, `BlueprintQA`
and `TempleQA` on each building in the plan. A village whose smithy has an
anvil in the doorway fails the village. This is the reason the village is
built from `BuildingRequest`s and not from its own house drawings.

---

## 10. Archetypes

`tests/suites/village_archetype_suite.gd`, in the manner of the house and
temple suites: what each must CONTAIN, never where. Each built at three
seeds, and at 70 %, 100 % and 140 % of its population, so the thresholds
in §4 are crossed and un-crossed on purpose.

| Archetype | People | Culture / purpose / water / edge | Must contain |
|---|---|---|---|
| Thorpe | 18 | english, farming, none, hedge | 4 houses, a well, fields, no shop of any kind |
| Green village | 80 | english, farming, pond, hedge | a green, a church, a smithy, a tavern, a farm, an orchard |
| Ford | 60 | frankish, crossroads, stream, none | a bridge, a tavern on the through road within 60 m of it, a smithy |
| Mill village | 120 | frankish, mill, river, hedge | a mill on the water with a race, a bakery, an inn and stable, a store |
| Strand | 45 | norse, fishing, coast, none | one row of houses, a road behind it, racks and boats in front |
| Pine hold | 70 | alpine, forest, stream, palisade | a palisade with two gates, a carpenter, trees at double density |
| Mine camp | 70 | norse, mining, none, palisade | an adit at the end of the through road, a smithy, no farms |
| Pilgrims' rest | 80 | eastern, pilgrim, none, none | a temple on the common, an inn, a market |
| Lord's village | 150 | english, garrison, none, wall | a manor-tier castle at the head of a lane, a church, a wall with gates |
| Market town | 300 | frankish, market, river, wall | a square with ≥ 8 stalls, a town hall, a guildhall, two taverns, a bridge, a wall |
| Blight | 40 | blighted, forest, pond, none | a temple, dead trees, mushrooms, a ruin (`Wall_Broken`), no green tree |
| The cap | 500 | frankish, market, river, wall | passes every rule at the top of the envelope; `buildings ≤ 140` |

---

## 10a. The plan on disk: `tools/export_village_plan.gd`

A `VillagePlan` could only be had in-process from GDScript, which is no use
to a consumer in another language. `tools/export_village_plan.gd` (VIL-014)
reads a mythsim **SiteRequest** and writes a **SitePlan** as JSON, headless,
with no scene, no mesh and no assets:

```
godot --headless --path . --script res://tools/export_village_plan.gd \
    -- --request in.json --out out.json
```

The contract is `C:/Projects/Dm_View/docs/contracts/c1-site.md` and it is
binding. This is a serialiser over data the planners already produce; the
work is mapping mythsim's vocabulary onto a `VillageSpec` (its cultures onto
the seven palettes, its `built` fractions onto a purpose and an enclosure,
its unbounded wealth onto 0–1) and writing the result out in the agreed
shape, plus one new field: `building_id`, `"<city_id>/b-<nnn>"`, the join key
C2 and C4 hang off.

Three things are worth knowing:

- **Byte-identical output**, because DM_View regenerates rather than stores.
  Every float is snapped to a millimetre before it is written, every list
  keeps the planner's own order, and the **seed is taken from the request's
  TEXT** — mythsim seeds are unsigned 64-bit and do not survive a JSON parse
  as integers.
- **A city is bigger than a village.** Population is capped at 500 and, above
  the `gate` form's threshold of 200, *scaled* into 140–199 rather than
  clamped — the contract's acceptance is that building count rises with
  population, and clamping 210, 300 and 420 to 199 gave three identical
  villages.
- **Every concession is written down.** Only two of §3's seven forms have
  planners, so a request that derives `gate`, `round`, `strand`, `planted`
  or `crossroads` is stepped toward one that can be laid, and each step goes
  into the plan's own `notes` array. `pilgrim` is never substituted in,
  because it is the one purpose that earns a temple and the contract says a
  city without one does not get one.

Fixtures are in `tests/fixtures/site_requests/`. Over those five: two runs
byte-identical, every building inside the site, every building fronting a
road, counts of 8/42/49/54/58 rising with population and never near the 140
cap, and the village suites still green on the plans produced.

---

## 11. What has to exist first

| Need | Who needs it | What it is |
|---|---|---|
| **`VillagePlan`** | everything | roads (polylines + class), lots (polygons + front), buildings (lot, request, `placement()`, door), commons, enclosure polygon, gates, water, fields, props, plants — all in metres, no meshes |
| **Polygon geometry helpers** | lots, roads, the common | polygon area, intersection area, point-in-polygon, offset (for road ribbons and verges), convex hull; `WalkGrid` rasterising polygons — the same upgrade the world-buildings doc needs for round rooms |
| **Building bounds as rotated rects** | lots, fire gap, canopy | `placement()` gives an AABB in the building's frame; the village rotates it to the lot |
| **`MeshKit` small props** | §7's missing list | well, signpost, palisade, lamp post, haystack, fence gate, mill wheel, adit, boat, rack |
| **Measured `canopy`** | plants | `build_prop_catalog.gd` records a canopy radius and trunk radius for anything under `nature/` |
| **A ground and a road mesh** | the builder | done (VIL-018): `src/village/village_builder.gd` raises the site slab, the lots, the road ribbons with their verges, the commons, the water and a bridge wherever a road crosses it, the palisade or wall round the edge with a gate at every crossing, and the ten `PropKit` props the dresser asked for. It extends `MassBuilder`, so every one of those is in `mass_log` and the checks measure what was emitted. `VillageAssembler` then adds what is a MODEL — the buildings, the catalogue props, the plants, and an `OmniLight3D` per light through `LightKit`. A heightmap is *not* v1 — every form here is flat, and the strand and the mine are the first to want a slope |
| **Village-scale `WalkGrid`** | the nav check | cell 0.25 m; `add_obstacle` for polygons |
| **A `village` kind on the facade** | every consumer | done (VIL-019): `BuildingRequest(kind = &"village")` goes through `BigGlade.generate()` like any other family and comes back with its `VillagePlan` on `GeneratedBuilding.village`. Its two numbers ride on the request's own number fields — `width` is the population and `length` the wealth as a percentage — and the descriptor's `width_label`/`length_label` say so, so a caller filling a form from `describe_kind()` asks for the right thing. `placement()` gives the site as the footprint and the point on its −Z edge nearest the common as the door |
| **The Studio** | looking at it | a `Village` kind with population, culture, purpose, wealth, water, edge; and `BlueprintView` draws the plan from above — the sheet finally draws something other than a church, and it is the most useful drawing the Studio could make |

## 12. Order

The `VillagePlan` and the polygon helpers first, because every check reads
them. Then the site planner for the `street` and `green` forms only — one
road, one common, lots along it — with `ScaleCheck`, `RoadCheck` and
`LotCheck`, because that is already a village and the checks will catch
more than the planner gets right. Then `PlaceCheck` and the programme table,
which is where it starts to look like *a* village rather than *some*
houses. Then the dresser and `DressCheck`, with the `MeshKit` well and
fences before any nature asset is imported, so a village never renders with
a hole where the well should be. Then the nav check over the whole site,
then the remaining forms, the enclosure and the archetypes. Terrain last,
if at all.

## Sources for the rules

- English village morphology — street, green and planted villages:
  https://en.wikipedia.org/wiki/Village_green,
  https://en.wikipedia.org/wiki/Bastide
- Rundling and Angerdorf: https://en.wikipedia.org/wiki/Rundling,
  https://en.wikipedia.org/wiki/Angerdorf
- Medieval household size (4–5 people): Russell, *British Medieval
  Population*; the 4.5 multiplier is the conventional one.
- Parish and trade thresholds: Dyer, *Making a Living in the Middle Ages*
  (a village smith at ~30 households; a market charter at ~100).
- Road widths: the King's highway at "two carts abreast"; a medieval street
  of 12–20 ft.
- Parish and Müller, *Procedural Modeling of Cities* (SIGGRAPH 2001)
  — L-system road networks, and why village roads should NOT be that.
- Emilien et al., *Procedural Generation of Villages on Arbitrary Terrains*
  (Eurographics 2012) — interest-driven placement of village buildings
  along roads, the closest published model to §6.
