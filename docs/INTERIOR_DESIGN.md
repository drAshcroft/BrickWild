# Interior design for BrickWild houses: the course, the contract, the audit

Written 2026-11-14 after the user's verdict on the generated houses: "the interiors
lack any form of legitimacy. No human would organize a house like that."

This is the distilled course. Full research notes with every source and number:
[interior/GUIDES.md](interior/GUIDES.md) (about 120 rules, each with a `check:` line).
Datasets surveyed and downloaded: [interior/DATASETS.md](interior/DATASETS.md).
The instrument that measures a generated house against the rules:
`tools/interiors/design_audit.py`, with controls in `tools/interiors/test_design_audit.py`.

## 1. How a designer actually works (and what BrickWild skips)

A designer never starts with furniture. The order is:

1. **Brief: who lives here and what they do.** Head-count, ages, status, trade,
   period and region. Everything later is derived from it: how many beds, how many
   places at table, how big the table is, whether there is a separate kitchen.
2. **Programme and grammar.** Which rooms exist and in which order from the street.
   The order follows the *intimacy gradient*: public at the door, private at the back
   or upstairs. The grammar depends on the culture and the period (section 3).
3. **The heart and the focus.** One room is the common room. In every pre-modern house
   it is the room with the fire. Seats face the fire or the table.
4. **Activity groups, placed as units.** Table with its chairs; bed with its bedside
   and chest; hearth with its settle, its fire irons and its pot; workbench in the light.
   The anchor goes first, its companions after, then the clearances round the group.
5. **Circulation.** One connected walkable floor that reaches every door and every
   item's use face; the door-to-door path keeps clear of the table and the bed.
6. **Light, then accessories.** Light in pools (fire, candle, window); small things last.

BrickWild today does 2 (as a label list), 4 (well, per piece) and 5 (very well). It
skips 1 and 3, so 4 has nothing to serve: valid furniture with no household behind it.

## 2. The ten rules a person notices first

Ranked by how fast a visitor says "no one would do this". Ids are the audit's.

| # | Rule | Number | Audit |
|---|---|---|---|
| 1 | Every piece faces its use; its back is to a wall or to its partner | wall gap <= 0.05-0.20 m; yaw within 5 deg of a wall | R-01, R-03 |
| 2 | The fire is the heart of the common room: the household eats, sits and (before c.1700, outside London) cooks there | seats face the hearth; hearth extension 0.41-0.51 m clear | R-14 |
| 3 | Furniture comes in groups: chairs round a table, bed with its bedside, settle at the fire | 0.60 m per place at table; bedside within 0.30 m of the bed | R-02, R-04, R-10 |
| 4 | Scale follows the household: table, beds and seats match the number of people | 1 cover = 0.60 m; ~10-20 m2 floor per head pre-modern (ESTIMATE) | R-10, R-11, R-20 |
| 5 | The room's inventory fits its kind AND its period | probate inventory tables, GUIDES 5b | R-09, R-13, R-18 |
| 6 | Intimacy gradient: privacy never falls with depth; no bedroom is a through-room | rank by graph depth from the entrance | R-17 |
| 7 | Bed: head on a solid wall, not in the door's line, not under a window | 90 % of real beds have the head at a wall (HSSD, n=435) | R-01, R-08 |
| 8 | Before c.1720, idle seats rest back-to-wall and the table is brought out; after it, groups float off the walls | period branch | R-03, R-04 |
| 9 | Door swings and the path from door to door are clear; no table in a passage | swing 0.9 m; 1.12 m behind a chair with traffic | R-07 |
| 10 | No room is a cupboard of leftovers: no duplicated principal rooms, no big stores between living rooms | one hall, one parlour per floor | R-15, R-16 |

## 3. The grammar of each published house style

A wrong grammar reads as "not that culture". The rules below come from GUIDES section 5.

| BrickWild style | Historic grammar | The common room | Where people sleep | GUIDES |
|---|---|---|---|---|
| `cottage`, `thatch_cottage` | two- or three-cell English vernacular, c.1400-1700 | the **hall / housebody**: fire, cooking, eating, sitting, work | chamber or parlour behind or above; truckle bed under the main bed | H1, H5, H8, 5b |
| `farmhouse` | hall-and-parlour, lobby entry against the stack, 1570-1700 | the hall, cooking in it outside London; a dairy/buttery on the service side | the parlour holds the best bed (72 % of Lincoln parlours); chambers above, often with stored grain or cheese | H5, H6, 5b |
| `townhouse` | the shop house | shop at the street, kitchen behind it on storey 0; the hall and parlour on storey 1 | chambers on storey 1-2, servants in the garret | H20, H21 |
| `rich` | the hall house with a dais (to c.1600), later the double pile with a dining room | the great hall: high table across the upper end, cross passage at the lower end, services beyond it | the solar / great chamber over the upper end | H1-H4, H7 |
| `longhall` | Norse longhouse | one central hall: long hearth on the axis, benches along both long walls | the benches; at most one box bed for the master and mistress | H9-H13 |
| `roundhouse` | Iron Age roundhouse | the whole room round a central hearth; work at the front by the door | the rear half, against the wall ring | H16 |
| `asian` | minka | the raised **hiroma** with the irori; four seats of fixed rank | tatami rooms behind; servants on the hiroshiki | H14, H15 |
| `pueblo` | Ancestral Pueblo suite | one habitation room with a rectangular hearth | the habitation room; storage rooms have no hearth and no furniture | H17 |
| `african` | Hausa compound (Sahel) | the entrance zaure for guests; the inner court for the household | each wife's own unit round the inner court | H18 |
| alpine (village farmhouse) | the Stube | stove in one corner, corner bench and table diagonally opposite under God's corner | chambers above | H19 |
| `mediterranean` | NOT RESEARCHED in this pass | -- | -- | gap |

Two consequences for BrickWild that matter most:

* **A separate kitchen is a big-house or late feature.** For cottage, farmhouse and
  thatch cottage before c.1700 the fire belongs in the hall. The planner already has
  this room: `domestic_role = living_hall` with `shared_cooking` (used today only by the
  witch hut and when a kitchen does not fit). Choosing it by period and style is a
  programme change, not a new system.
* **Beds in parlours and halls are legitimate** in provincial and vernacular houses,
  but the street door must not open onto one (human pin: "beds do not go in the
  entrance room").

## 4. Modern rules (for a modern style, and as the clearance floor everywhere)

Kept for any post-1850 style and for the clearances, which do not change with period
except where GUIDES section 7 relaxes them for pre-1700 rooms.

* Walkways 0.91 m (main), 0.61 m minimum; seat front 0.76 m; storage front 0.61 m
  (wardrobe 0.76 m); bed side 0.50-0.91 m; behind dining chairs 0.81 m to a wall,
  0.91 m to edge past, 1.12 m with traffic. (GUIDES A2-A6; Panero via Merrell Table 1.)
* Kitchen (NKBA): work-triangle legs 1.22-2.74 m, total <= 7.92 m; landing 0.38-0.61 m
  beside the cooker and sink; aisle 1.07 m. Hearth kitchens use Alexander's Cooking
  Layout instead: fire, water, store and table each within 3.05 m. (GUIDES 2a, K15.)
* Living room: one focal point; the seating group faces it, seats 1.22-2.44 m apart,
  no through-path across the group. (GUIDES A9, M11, Z9.)

## 5. What is wrong with BrickWild houses today (2026-11-14 baseline)

Sheets: `tools/dump_interiors_json.gd` then `tools/interiors/draw_interiors.py`.
Tally: `tools/interiors/design_audit.py` over 37 houses (11 styles x 3 seeds, plus a
smith, an innkeeper, a scholar and a farmer).

Findings per rule and style (R-04 seats with no purpose, R-11 table out of scale, R-14
fire with no one at it, R-15 duplicated room, R-16 big store on a living floor, R-18 torch
indoors, R-20 house too big for its beds):

| style (plans) | R-04 | R-11 | R-14 | R-15 | R-16 | R-18 | R-20 | findings per house |
|---|---|---|---|---|---|---|---|---|
| longhall (3) | 0 | 2 | 0 | 0 | 0 | 8 | 0 | 4.0 |
| roundhouse (3) | 0 | 3 | 0 | 0 | 0 | 7 | 0 | 4.3 |
| farmhouse (4) | 0 | 4 | 4 | 0 | 0 | 15 | 4 | 7.2 |
| cottage (5) | 3 | 4 | 4 | 0 | 0 | 21 | 4 | 8.0 |
| asian (3) | 3 | 3 | 3 | 0 | 0 | 14 | 3 | 9.0 |
| thatch_cottage (3) | 3 | 3 | 3 | 0 | 0 | 16 | 2 | 9.0 |
| mediterranean (3) | 3 | 3 | 3 | 0 | 0 | 14 | 3 | 9.3 |
| african (3) | 4 | 2 | 3 | 0 | 0 | 16 | 3 | 9.3 |
| pueblo (3) | 8 | 1 | 3 | 0 | 0 | 21 | 1 | 12.3 |
| townhouse (4) | 14 | 3 | 4 | 4 | 4 | 25 | 4 | 14.8 |
| rich (3) | 37 | 0 | 3 | 3 | 0 | 40 | 3 | 29.7 |

Whole set: R-14 in 30 of 37 houses (every house with a chimney fire except the
innkeeper's); R-11 in 28; R-20 in 27; R-04 75 seats in 24 houses; R-18 197 torches in
all 37. Rarely seen, because the existing QA already enforces them: R-01 floating (6),
R-07 door swing (0), R-08 bed at the door (1), R-09 bed in the entrance room (3).

Against real homes (`tools/interiors/compare_to_data.py`):

| Measure | BrickWild (37 houses) | Real data |
|---|---|---|
| bed head at a wall | 1.00 (n=38) | 0.90 HSSD (n=435); 0.66 SUN scans, a lower bound (n=1019) |
| storage back at a wall | 1.00 (n=173) | 0.91-0.99 HSSD |
| places per dining table | 2 (n=37) | median 4 HSSD (n=93) and SUN (n=171); 6 next |
| beds with 2 / 1 / 0 bedside pieces | 0.00 / 0.92 / 0.08 (n=38) | 0.40 / 0.23 / 0.37 HSSD (n=435) |
| bedroom area m2 | 20.9 (n=36) | 16.3 HSSD (n=382); 14.0 Swiss (n=23k) |
| kitchen area m2 | 23.4 (n=31) | 17.4 HSSD (n=172); 8.0 Swiss |
| living-room area m2 | 18.8 (n=83 rooms in 37 houses) | 32.4 HSSD (n=133); 28.4 Swiss |
| pieces per m2: bedroom / living / kitchen | 0.14 / 0.17 / 0.24 | 0.33 / 0.22 / 0.52 HSSD |

**The piece-level QA works: BrickWild beats real homes on walls.** What fails is the
household: too many small "living rooms" (83 in 37 houses, where a home has one common
room of ~30 m2), bedrooms and kitchens a third too big and half as furnished, and two
places at every table.

Read as a designer:

1. **No household.** cottage, farmhouse, townhouse and mediterranean cut the default
   9 x 12 m box into the same four rooms (hall ~29 m2 at the street, kitchen ~23 m2, a
   third room ~17 m2, bedroom ~21 m2). Nothing records a head-count, so beds, places
   and table size are derived from nothing: a 2.85 m table laid for two; one double
   bed in a 200 m2 townhouse.
2. **The fire is in the wrong room.** `HousePlanFeatures.choose_hearth` prefers the
   kitchen; the kitchen gets the fire but no table and no seat, and the hall -- the
   biggest room, entered from the street -- gets the table and no fire. It is a modern
   kitchen-and-dining-room plan dressed in medieval furniture, and it fails both.
3. **Seats with no group.** Benches line parlours that have no table and no fire;
   chairs stand mid-floor facing walls. The rich house has three parlours of them.
4. **Wrong things.** Torch_Metal, an open wall torch, is the default light of every
   room. Houses burned candles and rushlights, and the fire gave most of the light.
5. **The catalogue cannot say "home".** One bed (Bed_Twin, 1.88 m wide, really a
   double), one table (a 2.85 m feast trestle), one chair, one stool, a 2.78 m bench.
   Missing: a small or square table, a settle, a dresser or court cupboard, a box bed,
   a truckle or child's bed, a cradle, a spinning wheel, a kitchen work table, a
   candlestick or rushlight for walls. The owned library has none of the period pieces
   (Quaternius Fantasy Props MegaKit is in use; the Kenney furniture kit is modern).
6. **What reads well already:** the longhall (benches along the long walls round one
   hall) and the roundhouse. Their grammar is one common room, and the audit agrees.

## 6. The fix, in order

Each step is checkable by the audit plus the existing house lanes. Smallest change first.

| Step | Change | Where | Audit rules it should clear |
|---|---|---|---|
| 1 | **Household brief.** A head-count from style, size, trade and status; record it on the plan (`domestic_layout.household`). Beds, places at table and table size derive from it. | `house_plan_rooms.gd` `_domestic_layout`; furnisher recipes | R-10, R-11, R-20 |
| 2 | **The fire goes where the household lives.** For pre-1700 cottage, thatch cottage and farmhouse, use the existing `living_hall` + `shared_cooking` grammar: no separate kitchen, or demote it to a buttery/pantry service room. The hall recipe gains the hearth group (settle, fire irons, pot) and the household table. | style `domestic_program`; `choose_hearth`; hall recipe | R-14 |
| 3 | **Entrance is not a bedroom; a parlour is a room with a purpose.** A parlour gets either the best bed (provincial) or a table and its seats (town); never a ring of idle benches with nothing to face. | `RECIPES` parlour / hall | R-04, R-09 |
| 4 | **Leftover capacity is not a store.** `_domestic_kinds` pads with `store`; pad instead with a chamber (beds) upstairs, and keep bulk storage in the service end, a cellar or the garret. | `_domestic_kinds` | R-15, R-16 |
| 5 | **Light by period.** Candles, candlesticks and rushlights in dwellings; Torch_Metal only for castles and dungeons. | `RECIPES` sconce steps; catalogue | R-18 |
| 6 | **Seat rest position by period.** Idle seats back-to-wall facing into the room before 1720; never facing a wall. | `place_around` / wall rule | R-03 |
| 7 | **Assets.** Squashing Table_Large into a short table is not enough. Source a settle, small table, dresser, box bed, truckle bed, cradle and candle lights (CC0 first). | `assets/props/`, `catalog.json` | R-11, R-19 |
| 8 | **Port the audit into GDScript QA** once steps 1-4 land, as `qa/house_design_check.gd`, so the house lanes enforce it. | `qa/` | all |

Steps 1-2 are the ones that change the reading of every house; step 5 is a one-line
recipe edit with a large visual effect.

### Landed 2026-11-14: steps 1 and 2, and the period-seating flag

**HOME-BRIEF.** `HouseHousehold.brief(plan)` (src/house/house_household.gd) runs at the
start of `HouseFurnisher.furnish` for every ordinary house but the witch hut and is
recorded on `plan.domestic_layout["household"]`: people = floor / 24 m2, 3..8 (Laslett's
4.75; the real median of 4 places a table); beds = people / 2 (the only bed is a
1.88 m double); `bed_rooms` gives every sleeping room its first bed and hands out
second beds by floor (8 m2 a bed, at most two a room: one chest stows two). The
household table is laid for `places` = people, at most 6 (`MAX_PLACES`: the real median
is 4 and 6 the next; laying 8 made a two-storey townhouse six times slower to furnish,
measured A/B in one process, 126.6 s against 20.8 s; with the cap the brief costs nothing,
ratio 0.93 over four houses -- `tools/interiors/time_household.gd`). After
furnishing the brief records `beds_placed`, `places_laid` and `short`. Second beds are
attempted but optional (`repair_optional`), so a chamber too small for two doubles
gives one up and the brief says so.

**HOME-HEARTH.** `HousePlanRooms.living_hall_grammar(spec)`: an ordinary, no-trade,
one-storey cottage, thatched cottage or farmhouse with `period` <
`HouseSpec.LIVING_HALL_BEFORE` (1700) plans no separate kitchen. The existing `living_hall` + `shared_cooking` grammar
then puts the fire, the cooking corner and the household table in the hall, and the
dining selection seats the household there by its fire. The freed bay becomes the
programme's second chamber or a store (the buttery). A bedroom reached only through
another bedroom now gets its own door (`HousePlanOpenings.open_up_privacy`, hall or
parlour before a store). The thatched cottage gained the cottage's domestic programme:
on the old partition path it had a 13 m2 hall and 22 m2 stores. Trade houses and
houses of two or more storeys keep their kitchen for now: trade houses plan on the
partition path, whose small hall cannot cook and seat the household, and a
two-storey hall also carries the stair (see the comment on `living_hall_grammar`).

**period_seating** (`HouseSpec` and `BuildingRequest`, houses only, left out of the
request JSON at its default): `with_table` (default) gives a sitting parlour a side
table against its wall -- the trestle at plan scale 0.62, full height -- with its seats
drawn up to it, and the programme check does not take it for a second dining table
(it is in the `sitting` group). `without_table` is strict pre-1720 history: a settle on
the wall and no table. The audit's R-04 honours the flag.

Suite `hhousehold` (49 checks) holds all three with failing controls: a cottage of
1800 keeps its kitchen, a hand-made bedroom-behind-a-bedroom gets its door, a side
table relabelled as dining is caught, and an unknown or non-house `period_seating`
is refused.

Before and after, the same seven houses (cottage 1 and 2, farmhouse 1, thatched
cottage 1, townhouse 1, rich 1, smith's cottage 3; design audit, findings in houses):

| Rule | Before | After |
|---|---|---|
| R-14 fire with no one at it | 7 in 7 | 3 in 3 (townhouse, rich, smith: they keep a kitchen by scope) |
| R-11 table out of scale | 6 in 6 | 0 |
| R-04 seats with no purpose | 19 in 5 | 1 in 1 (a townhouse office chair) |
| R-20 house too big for its beds | 7 in 7 | 5 in 5 (second beds do not fit; see below) |
| R-17 bedroom through a bedroom | 0 | 0 (it appeared with the second chamber, then got its door) |
| R-01 floating | 0 | 4 in 4 (the living hall's cooking bench; see below) |

Every one-storey, no-trade cottage, thatched cottage and farmhouse has the fire in its
hall and a complete meal for its household there (4 places of 4); townhouse and rich
lay 6 of 6. Lanes on 14 Nov: `hhousehold` 49/49, `houseqaplan` pass (dining 19/19),
`walkpins` 77/77, `house QA (furnishing)` 97/97, `house assembly` 95/95,
`hmultistory` 214/214 (18 warnings), `libraryquick` 104/104. `harchetype` timed out
at 45 min on a machine shared with a busy Unity process and gave no result.

Still open on these steps: the second double bed rarely fits a 4 m chamber (needs a
narrower bed -- HOME-ASSETS -- or the best bed in the parlour -- HOME-PARLOUR); in every
living hall so far the cooking bench stands opposite its cupboard as a work table
1.1-1.3 m off the wall (audit R-01): it must stay within 1.9 m of the fire
(MAX_COOKING_HEAT_GAP) and the hearth wall beside the breast is too short for it, so
`_opposed_prep_candidate` wins -- it wants a hearth-corner placement rule; townhouse and rich houses still need HOME-PADDING before their beds can
match their households.

## 7. Datasets and what they calibrate

Full survey (27 candidates), download steps, loaders and caveats:
[interior/DATASETS.md](interior/DATASETS.md); every statistic with its n:
[interior/dataset_stats.txt](interior/dataset_stats.txt). The data itself is in
`artifacts/interior_data/` (gitignored, never committed); the loaders are in
`artifacts/interior_research/scripts/`, run with `python -I`.

| Dataset | What it gives | Licence | Use here |
|---|---|---|---|
| HSSD-hab (168 artist-made houses, Hugging Face, ungated; annotations only, 57 MB) | room outlines + every object's position, rotation, size | CC BY-NC 4.0 | wall contact, bedside pairs, chairs per table, density per room type |
| SUN RGB-D (10,335 scanned real rooms; metadata only, 25 MB) | oriented 3D furniture boxes in real rooms | academic, cite | a real-room check on the HSSD wall numbers (lower bounds: partial views) |
| Swiss Dwellings (45,175 real apartments, 1.9 GB) | typed rooms, doors, windows, fixed fittings; no movable furniture | CC BY 4.0 | room sizes and the door graph: the entrance opens on a corridor 87 % of the time; a bathroom has one door 95 %; doors sit a median 0.13 m from a room corner (n=28,907) |
| De Graeff inventory, Amsterdam 1709 (1,523 entries, 34 rooms) | what a rich canal house held, room by room | CC BY 4.0 | period evidence: chairs in sets of 12-17 in the best rooms, beds in the great room and the dining room, a kitchen with no furniture listed |

Read the modern sets as evidence about ergonomics and walls, not period taste. The
period evidence is the probate inventories (GUIDES 5b; De Graeff).

Better data sits behind agreement forms; BrickWild has not applied. The user would
have to: **3D-FRONT** (Alibaba Tianchi dataset 65347, Aliyun account, research
terms), **Structured3D** (agreement form at structured3d-dataset.org), **Matterport3D**
(signed ToS by email; ask for `house_segmentations` only), **ScanNet** (signed ToS),
**Zillow ZInD** (Bridge Interactive request). ProcTHOR-10K is free but is another
generator's output, so it is not evidence of what people do.

## 8. How to run the instrument

```
# furnished plans to JSON (case = style[:seed[:purpose[:storeys]]])
godot --headless --path . --script res://tools/dump_interiors_json.gd -- \
    out=artifacts/interior_research/plans.json cases=cottage:1,townhouse:2,rich:1
# sheets from above, one panel per storey
python -I tools/interiors/draw_interiors.py artifacts/interior_research/plans.json artifacts/interior_research/sheets
# the audit, and its controls (one good plan, one failing mutation per rule)
python -I tools/interiors/design_audit.py artifacts/interior_research/plans.json
python -I tools/interiors/test_design_audit.py
```

The dump is about 10-15 s per house (the furnisher search). 37 houses take ~8 minutes.
