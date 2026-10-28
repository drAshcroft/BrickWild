# Medieval shops and civic buildings

Shops use the same plan-first architecture as houses:

```
ShopSpec -> ShopPlanner -> ShopFurnisher -> HousePlan
                                      -> HouseBuilder / ShopAssembler
```

`HousePlan` remains the common representation. The shared builder cuts real
doors and windows into a half-timbered shell, while the assembler is still the
only layer that loads prop models. This lets the existing tiling, daylight,
furnishing-clearance, and walkability checks judge a workplace headlessly.

## Supported businesses

The initial programme covers blacksmiths, stables, restaurants/cookshops,
taverns, inns, bakeries, butchers, apothecaries, general stores, tailors,
carpenters, town halls, and guildhalls. Each declares public rooms first and
service rooms behind them; the generator chooses their exact subdivision and
connections.

INT-012 adds a recipe-only thieves' den. Its ordinary sales floor leads to a
hidden store through one secret interior door, then to a private dormitory.
The two hidden rooms have no outside doors or windows. The builder cuts the
passage for navigation and covers the public-side aperture with a logged,
full-height joinery panel that reads as a solid wall or bookcase. Secret doors
are absent from entrance and visible-opening semantics, but remain in room
connectivity. Privacy treats rooms marked `secret` as private endpoints.
`HouseNavCheck` checks the normal route and repeats its flood without secret
doors; the hidden rooms must then be unreachable.

INT-013 adds four recipe-only occupational families to that same plan and
furnishing pipeline. An alchemist laboratory has two rowed workbenches, with
alchemy props distributed across both, a cage, and a hearth. A bathhouse has
a changing room and a bath hall; the current owned prop catalogue has no
dedicated tub, so the measured upright barrel model stands in as each wooden
tub and the bath check requires at least two in one row. A hospice has a ward
with a row of beds and an alchemy-equipped dispensary. A school has two
separate bench rows and a lectern in its schoolroom, plus a master's office.
These are room recipes and `SHOP_FITTINGS`, not new mesh or room-planner
families. Fittings can name their target `room` when they belong behind the
public room.

The defining fixtures are semantic rather than coordinate-based: a blacksmith
must contain an anvil and workbench, a stable a stall and feed storage, a shop
a counter, a dining room a table and seats, a tailor a cutting table under a
rack with the shop's shelf behind, a carpenter a bench to saw on under a rack
of tools, and a civic hall a meeting table. Optional dressing is removed when
necessary to preserve circulation.

Each business also says what its front is (`ShopSpec.BUSINESSES`): `door_w`,
the width of the street door (a horse needs 1.5 m, a forge opens to the
street through 2.4 m); `front_open`, a shopfront hatch cut in the street wall
beside the door from counter height to the door head, which the builder
frames like a window; and `focus`, the fixture the front room is arranged
around -- the counter, the bar, the anvil -- and whether it must face the
door. The focus becomes `HousePlan.focus`, the furnisher pins that piece
there and turns it to the door, and the `focus` rule of the furnishing check
proves it. The archetype suite adds `shopfront_rules`: the street door opens
into the front room and is as wide as the trade needs, the smithy's forge is
on the chimney wall under one chimney, the shopfront hatch is there, and the
tavern's casks stand behind its bar.

The forge also fixes the front room's shape before the furnisher sees it. A
workshop whose chimney wall has no unbroken 1.39 m run for the fire -- the
measured widest hearth plus 0.4 m -- is replanned: the interior door whose
swing would eat the end of that wall is re-hung at the far end of its own
partition, and the hearth is elected again over the new spans
(`ShopPlanner._hold_the_fire_wall`). The room keeps its one window on that
wall and its shopfront beside it, and nothing moves unless the fire does not
fit as drawn (blacksmith 9x12 seed 1).

## Harness evaluation

The house harness was reusable for shops because it measures plans rather than
assuming domestic meshes. `HousePlanCheck` proves room tiling, openings,
daylight, and connectivity; `HouseFurnishCheck` proves measured placement and
occupational requirements; `HouseNavCheck` proves every room and use zone can
be reached; `HouseQA` also checks the emitted shell.

Two shop suites extend that coverage:

- `shop` checks every business, deterministic plans, furnishings, and shells.
- `sarchetype` checks the defining room and fixtures of every business, then
  runs the full shared QA harness.
- `int013` checks only the four new families at 70%, 100%, and 140% footprints,
  runs shared house QA, and removes one defining fixture per family to prove
  its semantic contract fails. It is the routine focused gate; broad seed
  sweeps remain scheduled work.
- `int012` checks the thieves' den at 70%, 100%, and 140%, the concealed panel,
  shared QA, and negative controls for a lost secret marker, missing passage,
  and an invalid exterior secret door. `thievesden100` is the opt-in scheduled
  100-seed seed contract; it is deliberately not part of the routine focused
  lane.

Run them with:

```
godot --headless --path . --script res://tests/run_all.gd -- int012
godot --headless --path . --script res://tests/run_all.gd -- int013
```

## Assets

The supplied paths were not present verbatim; the nearby libraries are
`C:/Projects/itch_assets` and `C:/Projects/kenny_assets`. The existing imported
Quaternius Fantasy Props catalogue already provides counters, stalls/carts,
anvils, workbenches, tables, seats, shelves, food crates, storage, books, and
banners, so the initial slice does not duplicate assets. There is no suitable
horse model in the currently imported catalogue: stables therefore read
through stall furniture, feed/tack storage, and clear working circulation.

## LIVE-SHOPS review: four-point checklist (2026-10-24)

Scope: the counter trades in `tests/fixtures/family_style_requests.json` (seed 8102, default envelope). Civic kinds are out of scope.

Checklist: (1) a counter visible from the customer door; (2) wares of that trade on display; (3) a staff work station; (4) a storage room or store off the work area.

Evidence: two renders per case by `tools/render_shop_trades.gd` (not headless): an exterior three-quarter view and an eye-level view (1.6 m, 80 degree fov, roof off) from the customer door looking along the inward door normal. Plan facts are in `artifacts/goal/LIVE-SHOPS/plan_facts.json`. The reviewer saw the images only, blind to the plan facts. The reviewer's NOs stand as recorded; none is softened.

| kind | counter | wares | station | store | reviewer notes |
|---|---|---|---|---|---|
| apothecary | YES (canopied stall counter, red banner) | YES (shelves of small dark jars) | NO (no still or mortar bench seen) | UNCLEAR | market-stall shop; exterior generic half-timber |
| alchemist_laboratory | NO (empty room) | NO | UNCLEAR (one cauldron at right edge) | UNCLEAR | mostly bare floor and wall; trade not readable |
| bakery | YES | NO (apples, cauldron, empty cabinets; no bread) | NO (no oven or hearth) | UNCLEAR | reads as a generic grocer |
| blacksmith | NO (door view faces a blank wall) | NO (empty shelf) | YES (anvil on stump) | UNCLEAR | strong station, no counter or goods |
| butcher | YES | NO (no meat; empty cabinets) | NO (no cutting block) | UNCLEAR | trade not readable |
| carpenter | NO | NO (empty shelf) | YES (long trestle workbench) | UNCLEAR |  |
| general_store | YES | YES (barrels, carrot crates, shelves) | NO | UNCLEAR | best match |
| tailor | YES | NO (no cloth, bolts or garments) | NO (no sewing table or loom) | UNCLEAR | reads as a general store |
| tavern | YES (bar and stools) | YES (barrels, goblet) | NO (no hearth or kitchen visible) | UNCLEAR | reads as a tavern |
| inn | YES | YES (mug, bottle, bar) | UNCLEAR (pots, no hearth) | UNCLEAR | near identical to restaurant and tavern; no beds visible |
| restaurant | YES | UNCLEAR (drinks only) | UNCLEAR | UNCLEAR | indistinguishable from inn |

### Images and plan facts per case

**apothecary**: `artifacts/goal/LIVE-SHOPS/apothecary/exterior.jpg`, `artifacts/goal/LIVE-SHOPS/apothecary/door_eye.jpg`

- Plan: front=sales_floor; counter present=True, in line of sight=True; wares on front floor 12, in line of sight 2 (Cabinet, Shelf_Small_Bottles); stations: alchemy@sales_floor, alchemy@workshop, workbench@workshop; storage rooms: store, workshop

**alchemist_laboratory**: `artifacts/goal/LIVE-SHOPS/alchemist_laboratory/exterior.jpg`, `artifacts/goal/LIVE-SHOPS/alchemist_laboratory/door_eye.jpg`

- Plan: front=laboratory; counter present=False, in line of sight=False; wares on front floor 6, in line of sight 0 (none); stations: alchemy@laboratory, hearth@laboratory, workbench@laboratory, workbench@office; storage rooms: office, store

**bakery**: `artifacts/goal/LIVE-SHOPS/bakery/exterior.jpg`, `artifacts/goal/LIVE-SHOPS/bakery/door_eye.jpg`

- Plan: front=sales_floor; counter present=True, in line of sight=True; wares on front floor 12, in line of sight 2 (Cauldron, Shelf_Arch); stations: hearth@kitchen, hearth@sales_floor, workbench@kitchen, workbench@workshop; storage rooms: kitchen, store

**blacksmith**: `artifacts/goal/LIVE-SHOPS/blacksmith/exterior.jpg`, `artifacts/goal/LIVE-SHOPS/blacksmith/door_eye.jpg`

- Plan: front=workshop; counter present=False, in line of sight=False; wares on front floor 4, in line of sight 2 (Anvil_Log, Shelf_Simple); stations: anvil@workshop, hearth@workshop, workbench@office; storage rooms: office, store

**butcher**: `artifacts/goal/LIVE-SHOPS/butcher/exterior.jpg`, `artifacts/goal/LIVE-SHOPS/butcher/door_eye.jpg`

- Plan: front=sales_floor; counter present=True, in line of sight=True; wares on front floor 11, in line of sight 4 (Cabinet, Shelf_Arch, Shelf_Simple); stations: blade@sales_floor, blade@workshop, workbench@workshop; storage rooms: store, workshop

**carpenter**: `artifacts/goal/LIVE-SHOPS/carpenter/exterior.jpg`, `artifacts/goal/LIVE-SHOPS/carpenter/door_eye.jpg`

- Plan: front=workshop; counter present=True, in line of sight=False; wares on front floor 6, in line of sight 2 (Bench, Torch_Metal); stations: bench@workshop, rack@workshop, workbench@workshop; storage rooms: sales_floor, store

**general_store**: `artifacts/goal/LIVE-SHOPS/general_store/exterior.jpg`, `artifacts/goal/LIVE-SHOPS/general_store/door_eye.jpg`

- Plan: front=sales_floor; counter present=True, in line of sight=True; wares on front floor 12, in line of sight 3 (Barrel_Holder, FarmCrate_Carrot, Shelf_Small_Bottles); stations: workbench@office; storage rooms: office, store

**tailor**: `artifacts/goal/LIVE-SHOPS/tailor/exterior.jpg`, `artifacts/goal/LIVE-SHOPS/tailor/door_eye.jpg`

- Plan: front=sales_floor; counter present=True, in line of sight=True; wares on front floor 12, in line of sight 5 (Cabinet, Crate_Wooden, Key_Metal, Shelf_Arch, Shelf_Simple); stations: rack@sales_floor, workbench@workshop; storage rooms: store, workshop

**tavern**: `artifacts/goal/LIVE-SHOPS/tavern/exterior.jpg`, `artifacts/goal/LIVE-SHOPS/tavern/door_eye.jpg`

- Plan: front=dining_room; counter present=True, in line of sight=True; wares on front floor 9, in line of sight 4 (Barrel_Apples, Stool, Table_Large); stations: hearth@kitchen, workbench@kitchen, workbench@office; storage rooms: kitchen, office, store

**inn**: `artifacts/goal/LIVE-SHOPS/inn/exterior.jpg`, `artifacts/goal/LIVE-SHOPS/inn/door_eye.jpg`

- Plan: front=dining_room; counter present=True, in line of sight=True; wares on front floor 9, in line of sight 4 (Bottle_1, Stool, Table_Large); stations: hearth@kitchen, workbench@kitchen; storage rooms: guest_room, kitchen, store

**restaurant**: `artifacts/goal/LIVE-SHOPS/restaurant/exterior.jpg`, `artifacts/goal/LIVE-SHOPS/restaurant/door_eye.jpg`

- Plan: front=dining_room; counter present=True, in line of sight=True; wares on front floor 9, in line of sight 4 (Bottle_1, Stool, Table_Large); stations: hearth@kitchen, workbench@kitchen, workbench@office; storage rooms: kitchen, office, store

### Where plan and image disagree

- The plan says every case has a work station and storage joined to a work room. The door view cannot show a back room, so every `store` is UNCLEAR from these views. The plan's store test is loose (any store, kitchen, office or workshop room holding storage-category props), so it does not prove a store either. See SHOP-STORE-VIEW.
- Stations the reviewer could not see exist in back rooms (bakery hearth and workbench in the kitchen; butcher blade and workbench in the workshop; tailor workbench in the workshop; tavern, inn and restaurant hearth in the kitchen). The plan satisfies the station trait there; the images do not show it. The reviewer's NO stands as a miss of the visible evidence.
- The plan lists wares on the front floor for every case, but the reviewer found none of the trade's goods in bakery, butcher and tailor: the props are generic (apples, empty cabinets). The plan's wares count is every non-seating prop, not trade-specific.
- The bakery, butcher, tailor and apothecary counters are present and in line of sight in the plan, and the reviewer saw them. The alchemist_laboratory and blacksmith have no counter in the plan, and the carpenter's counter is out of line of sight: plan and reviewer agree.
- Inn and restaurant read as the same room as the tavern; the plan has the same dining_room, bar and kitchen for all three. Beds sit in guest rooms the door view does not show.
- general_store: the plan has a workbench only in the office, so the reviewer's NO on station matches the plan.

Misses are filed as open tasks: SHOP-<KIND>-TRAITS for each kind with a NO, and SHOP-STORE-VIEW for the storage room that no view shows.

### Fixes after the review (2026-10-26)

- **Trade wares** (`src/shop/shop_wares.gd`, called from `HouseAssembler.furnish`): small procedural goods set on the boards the plan already holds -- loaves, joints and hanging hams, jars and herb bunches, cloth bolts and hung lengths, cheeses and crocks, tankards, tools and horseshoes. It is dressing, not plan: no floor is taken, no plan record is added, so the walk and furnishing checks see the same plan. Each trade's station goes on the middle of its counter where the door sees it: the butcher's block and cleaver, the apothecary's alembic and mortar, the tailor's chalked cutting cloth and shears, the grocer's scales and ledger, the tapster's cask. Board heights are measured from the models' up-facing faces (stall board 0.82, arched shelf -0.42/0.12/0.64 from its mount, plain shelf 0.10).
- **Bakery oven**: the bakery's fire is a catalogue cauldron; the assembler draws it as a domed brick oven with a glowing mouth on the same footprint.
- **Alchemist laboratory**: a counter fitting (rule wall) after the laboratory's own benches.
- **Plan view** (`plan.jpg`, `tools/render_shop_trades.gd`): the ground storey from straight above, orthographic, cut at 2.1 m (canopies and the storey above vanish), with each room outlined, every door a gap and every room named. It is the view that can show a store.
- **Store fact, tightened**: `storage_off_work_area.present` now needs a room NAMED for stock (store, storeroom, pantry, cellar) that holds storage-category pieces and opens through an interior door off a work room (a workshop, kitchen or laboratory, or any room with a workbench, fire or anvil). The old loose answer is kept as `loose_present`.
- Still open: the blacksmith and carpenter are workshop-front trades by contract (`ShopTradeSuite.IDENTITY` bans a smithy counter); their customer is served at the anvil or bench, so the review's "counter" point is a design disagreement, not a missing piece.
- The stricter store fact, on the review cases (seed 8102): bakery, blacksmith, carpenter, general store, tavern and the alchemist each have a named store opening off a work room. The apothecary, butcher and tailor do not: every store opens off the sales floor or another store, never the workshop (SHOP-STORE-JOIN).

### Walk-pin clearances (SHOP-WALK-FURNISH, 2026-10-27)

A shop is walked by strangers. `HouseFurnishGeometry.fits` (shops only) now keeps clear the walk through every door (leaf width, 1.6 m deep at the street door, 1.1 m at an inner one) and the 0.6 m keeper's stance behind a `hatch` window; the plan's own focus piece and the smith's hearth/anvil are exempt. `place_mounted` will not hang a fitting through a floor piece (a bench or counter is the intended host and is exempt; 8 cm tolerance). `HouseFurnishPhysicalCheck.check_shop_clearance` (inside `doorway`) judges both; `ShopTradeSuite._run_walk_furnish` sweeps 11 trades x seeds 1, 8102 x african/rich/townhouse at 11 x 14 with three failing controls.

### Serving place and wares in the door's view (SHOP-ALCHEMIST_LABORATORY-TRAITS, -BLACKSMITH-TRAITS, -CARPENTER-TRAITS, 2026-10-27)

The checklist's "counter" is the trade's SERVING PLACE: the counter of a counter trade, and for a work-front trade the piece the customer is served at (the smith's anvil, the carpenter's bench). That settles the design disagreement: a smithy still has no counter (`IDENTITY` bans it), but its anvil must stand in the door's view, and so must the carpenter's workbench.

- `qa/shop_sightline.gd` (`ShopSightline`): the door-eye rule as code (80 degree view from just inside the street door; a 1.5 m piece hides what is behind it). `tools/render_shop_trades.gd` keeps its own copy for the facts file.
- Alchemist laboratory: the focus is now `{counter, faces_door}` (it was `{}`), so the planner puts a counter in the laboratory facing the door first; the old `SHOP_FITTINGS` counter (a wall rule that landed at the edge of the view, or not at all at 9 x 12) is gone.
- Carpenter: the focus workbench `faces_door` (it was false and stood out of view in five of six cases).
- `ShopTradeSuite._run_traits` (`traits_contract`: rules `serving`, `wares`): six trades x 3 footprints x 2 seeds, plus two controls per trade (the serving place removed; the serving place moved out of view). On the old code the carpenter failed `serving` in 5 of 6 cases and the alchemist had no counter at 9 x 12 seed 1.
- Blacksmith: no planner change. The anvil is the focus and already faces the door, so it is the serving place and is in view at every footprint and seed; the review's missing counter is answered by the rule above (no counter is added, `IDENTITY` still bans one). The suite now holds it there.

### Plan rules from the walk and the review (2026-10-14 to 2026-10-27)

These are `ShopPlanner` post-passes and furnishing overlays. Each one has a failing control in `shoptrade` or `sarchetype`.

- **Store joined to the work room** (SHOP-STORE-JOIN). The house planner hangs every leaf off the first public room it touches, so a store could open only off the sales floor. `_join_store_to_work_room` cuts an inner door where a work room and a store share a usable wall and no store already opens off a work room. Palace, prison, thieves' den, barracks and market hall are exempt. `store_join_contract`: old code failed on apothecary, butcher and tailor (seed 8102).
- **Yard door on a large shop** (SHOP-SECOND-DOOR, walk pin WALK-1a17a581-1). `YARD_DOOR_ROOMS` = 5 (about 75 m2: 9 x 12 shops have 5 rooms, 11 x 14 have 6). Such a shop with a work room and no non-street door gets one by `_cut_yard_door`. It goes on a store that opens off the work room, or else on the work room. A side wall is preferred, at the end farthest from the street door. Windows give way. The same five businesses are exempt. This also removed two blacksmith `workbench_daylight` failures from `sarchetype` (33 -> 31).
- **Narrow meeting hall** (SHOP-GUILDHALL-NARROW). To seat a meeting table from both long sides, a hall needs the table depth + 2 x (bench + 0.04) + 2 x `PATH_MIN`, which is 3.56 m. The guildhall's hall was 3.22 m. A narrower hall gets the table on a wall and one bench on the open side (`HouseFurnishingRecipes.narrow_meeting_hall`). Do not shrink `PATH_MIN` to make the table fit.
- **Palace banners** (SHOP-PALACE-BANNER). The banners are placed after the furnisher has hung its sconces, and those sconces are mirrored about a rear door, not about the throne. The banner station search therefore ignores sconces. Doors, windows and other mounted pieces still veto a station. Sconces under a banner are re-hung beyond the pair, mirrored about the throne, or dropped: lighting is optional, the axis is not. Before the fix, seed 8102 had no banners. A blocked-wall control checks this.

### Still open (2026-10-28)

- The blind re-review of the 2026-10-26 re-renders was never done: the local vision model timed out. This affects apothecary, bakery, butcher, general store, tailor and tavern. Until a fresh reviewer looks, their YES ticks in this file are the implementer's, not independent ones.
- Tailor: no dress form. It would need floor space. The station is the cutting cloth and shears on the counter.
- Tavern: its station is the kitchen hearth. The door view cannot see the kitchen; `plan.jpg` can.
