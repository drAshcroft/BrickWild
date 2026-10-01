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
