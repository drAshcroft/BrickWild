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

The defining fixtures are semantic rather than coordinate-based: a blacksmith
must contain an anvil and workbench, a stable a stall and feed storage, a shop
a counter, a dining room a table and seats, and a civic hall a meeting table.
Optional dressing is removed when necessary to preserve circulation.

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

Run them with:

```
godot --headless --path . --script res://tests/run_all.gd -- shop sarchetype
```

## Assets

The supplied paths were not present verbatim; the nearby libraries are
`C:/Projects/itch_assets` and `C:/Projects/kenny_assets`. The existing imported
Quaternius Fantasy Props catalogue already provides counters, stalls/carts,
anvils, workbenches, tables, seats, shelves, food crates, storage, books, and
banners, so the initial slice does not duplicate assets. There is no suitable
horse model in the currently imported catalogue: stables therefore read
through stall furniture, feed/tack storage, and clear working circulation.
