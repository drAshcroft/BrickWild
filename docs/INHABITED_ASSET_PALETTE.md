# Inhabited building asset palette

Prepared 2026-10-06. This is an implementation-ready palette and gap list for
the next domestic furnishing and surface work. It uses the measured props
already shipped in BrickWild wherever possible. It separates items available
to the current runtime from candidates that are owned elsewhere and still need
visual review, import, measurement, and catalogue QA.

No asset was imported and no prop catalogue row was changed for this research.

Root review of the five actual model boards in
`artifacts/renders/inhabited_palette/` confirms a coherent carved-wood/iron
domestic palette. The workbench has a broad readable working top; the cauldron
and bottle shelf distinguish processing from ordinary storage. The twin bed
has a readable head/foot and textile, while `Nightstand_Shelf` reads as tall
open shelving rather than a low bedside table: keep it as nearby storage,
not the default bedside surface. The cupboard, chest and standing candle
holder are compatible in material treatment. The chandelier is substantial;
its measured hanging depth must be reserved above people, never squeezed to fit.

These boards approve asset appearance for the proposed palette, not their
placement as a finished room. In particular, the side chair/bench orientations
and clearances in an inspection board are not a validated dining recipe.
Small potion vessels need a supporting shelf/bench composition to remain
readable. Missing herbs, basin and soft furnishings stay explicit; library
search candidates have not received visual approval or been imported.
Dimensions below are read from `assets/props/catalog.json`; placement metadata
comes from `PropCatalog.PROPS` in `src/house/prop_catalog.gd`. A size is
`width × height × depth` in metres. `zone` is the clear floor depth reserved
for a person using the object. All props face local `-Z` before any `face`
correction. Surface tops default to measured height unless `PropCatalog` gives
an explicit `top` value.

## Current rights and runtime boundary

The current BrickWild props are from Quaternius packs copied into
`assets/props/`. The Fantasy Props MegaKit Standard licence and the Dungeon
Kit licence in-tree both say CC0 1.0. The Nature Kit and Stylized Nature
MegaKit also have their CC0 license files under `assets/props/nature/` and
`assets/props/wild/`. They can be redistributed with the project under those
stated licenses. BrickWild's catalogue is the authority for what can be placed
today: a model existing in the larger owned library does not make it a
BrickWild prop until it is imported and measured there.

The skill's owned-library search found useful extra candidates in
`kenney_food-kit` and `kenney_furniture-kit`. Those searches report CC0 1.0,
engine-agnostic glTF models, and the files are present in the owned library.
They are not in `assets/props/catalog.json` and have no BrickWild measurements
or `PropCatalog` support metadata. Inspect their look against the project's
Quaternius palette before selecting a small subset. The catalog reports no
matching CC0 Godot model for a jug/pitcher/ewer, a dedicated water basin, or
herb bundles. No Unity Asset Store model is recommended for this first pass.

## Measured props usable now

The following rows are actual `PropCatalog.PROPS` keys and have a current
measured catalogue entry. The authored placement tags and zones are included
because dimensions alone do not say how a fitting should be composed.

| Activity / role | Current key(s) | Measured size (m) | Placement and support contract |
|---|---|---:|---|
| Hearth/cooking focus | `Cauldron` | 0.989 × 0.816 × 0.944 | `hearth`; wall-backed; 0.8 m user zone. The shell's built hearth/chimney and this prop are distinct things; review their visual alignment together. |
| Cookware | `Pot_1`, `Bucket_Metal` | 0.539 × 0.224 × 0.486; 0.485 × 0.365 × 0.449 | `cookware`; corner/away from doors; zero use zone. These are tabletop/floor cookware candidates, not the prep station or water source. |
| Water carrying | `Bucket_Wooden_1` | 0.434 × 0.293 × 0.383 | `bucket`; corner/away from doors. The model is small and visually reads as a bucket; no fill, water surface, or washing-basin role is authored. |
| Food storage | `Barrel`, `Barrel_Apples`, `Barrel_Holder` | `Barrel`: 0.698 × 0.898 × 0.698 | `barrel`; corner/away from doors; zero use zone. The apples key adds a visible produce read. Keep heavy storage off the route and do not use a barrel as the only kitchen furniture. |
| Dry/closed storage | `Cabinet`, `Chest_Wood`, `Bookcase_2` | 1.362 × 0.997 × 0.357; 1.276 × 0.715 × 0.755; 1.461 × 2.545 × 0.429 | `Cabinet`: wall + surface, 0.7 m zone; chest: wall, 0.6 m zone and away from doors; bookcase: wall, 0.7 m zone, avoid hearth wall and prefer away from hearth. `Bookcase_2` is tall. |
| Prep/work surface | `Workbench` | 2.019 × 0.895 × 1.024 | `workbench`; wall + surface; 0.9 m user zone; seeks daylight. Measured surface top is 0.895 m. It is currently a workshop fitting, not requested by the ordinary kitchen recipe. This is the strongest existing full-size prep candidate. |
| Dining/work table | `Table_Large` | 2.848 × 0.813 × 1.097 | `table`; surface; zero assigned use zone; affinity to hearth and facing the focus. Top defaults to 0.813 m. Its footprint is substantial. Measure free floor and chair clearance before placing it in small rooms. |
| Dining and conversation seats | `Chair_1`, `Stool`, `Bench` | 0.581 × 1.123 × 0.549; 0.475 × 0.589 × 0.475; 2.777 × 0.533 × 0.534 | Chair: 0.55 m user zone, `face = π` correction; stool: 0.5 m zone; bench: 0.55 m zone. The bench is a long settle, not a single chair. Preserve approach and seat-to-table orientation. |
| Bedside storage | `Nightstand_Shelf` | 0.693 × 1.216 × 0.393 | Wall + surface; 0.4 m zone. This is unusually tall for a bedside stand; confirm the bedside visual before generalizing it. |
| Tabletop meal dressing | `Mug`, `Chalice`, `Table_Plate`, `Table_Fork`, `Table_Spoon`, `Pot_1_Lid`, `Bottle_1` | e.g. Mug 0.192 × 0.184 × 0.147; Plate 0.333 × 0.020 × 0.337; Bottle 0.113 × 0.365 × 0.113 | All are on-surface pieces with zero floor zone. `Table_Plate` and cutlery make a meal legible; bottles are generic and should not be misread as water jugs without checking the model. |
| Surface books/reading | `Book_Stack_1`, `Book_Stack_2`, `BookStand`, `Scroll_1`, `Scroll_2` | 0.285 × 0.214 × 0.226; 0.274 × 0.198 × 0.227; BookStand 0.507 × 1.447 × 0.511 | Book stacks and scrolls are on-surface. `BookStand` is a surface-supporting, daylight-affine lectern with 0.7 m approach zone. The bookcase is separate wall furniture. |
| Witch/alchemy containers | `Potion_1`, `Potion_2`, `SmallBottles_1`, `SmallBottle`, `Potion_4` | 0.114 × 0.140 × 0.114; 0.127 × 0.262 × 0.127; SmallBottles 0.215 × 0.145 × 0.056 | `alchemy`; on-surface, zero floor zone. These work as grouped vessels on a shelf or bench, not as a complete laboratory. |
| Witch/herb and field identity | `Wild_Mushroom_Common`, `Wild_Mushroom_Laetiporus`, `Wild_Plant_7`, `Wild_Fern_1`, `Wild_Plant_1`, `Nature_Flower_3_Clump` | Varies; plant geometry is measured in the shared catalogue. | Yard recipes use these as ground plants. `Wild_*` foliage uses the Nature or Stylized Nature CC0 pack and carries plant canopy/trunk metadata where relevant. The house yard also builds a herb bed and drying line. |
| Wall storage/detail | `Shelf_Simple`, `Shelf_Arch`, `Shelf_Small_Bottles`, `Peg_Rack` | 1.184 × 0.309 × 0.292; 1.245 × 1.589 × 0.312; 1.137 × 0.647 × 0.285; 1.184 × 0.348 × 0.096 | All are wall-mounted and use `face = π` to correct their mount direction. Shelves support surface objects where tagged; `Shelf_Small_Bottles` is a useful witch-work fit. `Peg_Rack` offers hooks, not a hanging herb bundle. |
| Domestic and secondary light | `Torch_Metal`, `Candle_1`, `Candle_2`, `CandleStick`, `CandleStick_Triple`, `CandleStick_Stand`, `Chandelier` | Torch 0.223 × 0.648 × 0.388; CandleStick 0.261 × 0.155 × 0.179; Chandelier 1.303 × 1.458 × 1.303 | Torch is a wall-mounted light with zero floor zone; candles are on-surface lights; `CandleStick_Stand` is a floor candelabrum; chandelier is ceiling-mounted and has an affinity over tables. `Lantern_Wall` is explicitly tagged `OUTDOOR`; do not use it as ordinary indoor domestic light. |
| Existing trade additions | `Anvil`, `Anvil_Log`, `Whetstone`, `Pickaxe_Bronze` | Anvil 1.082 × 0.556 × 0.402 | Anvils reserve 0.9 m use zone and prefer the hearth; the pickaxe is a corner `big_tool`, not a tabletop tool. Alchemy trade recipes add surface vessels; the Witch Hut style alone does not activate the alchemist trade recipe. |

Some rows above are catalogued assets, not promises that every room recipe
currently uses them. The recipe file decides that. In particular, `Workbench`
is not in the domestic kitchen recipe, water carrying has no dedicated
household activity group, and `Potion_*` is not a generic witch-house recipe.

## Use groups to build a lived-in home

Compose full activities before optional dressing. The groups below specify
what the future recipe and review should prove. They identify a role and
physical relationship, not a required pile of extra objects.

| Group | Required functional set and relation | Available now | Acceptance evidence |
|---|---|---|---|
| Cook and prepare | Heat source; stable work surface; preparation tool/ingredient; cookware; closed and bulk storage; safe standing approach; connection to water handling. Heat, work, and storage should form a short, unblocked sequence. | `Cauldron`, `Workbench`, `Pot_1`, `Bucket_Metal`, `Cabinet`, `Barrel`, `Barrel_Apples`, crates, shelves. Existing kitchen recipe attempts heat, storage, barrels, cookware, shelves, tableware, and lighting; it does not request `Workbench`, knife/board, or water handling. | Show the person can stand at the work surface, reach cookware and storage without crossing the hearth, and carry water without blocking door/stair routes. Review meal preparation in a walk-through view. |
| Draw and use water | A visible vessel and wash point within a deliberate route to kitchen/prep. If water is carried, its placement should read as a filled household vessel with access. | `Bucket_Wooden_1`, `Bucket_Metal` only. No dedicated owned-library CC0 jug, ewer, or basin was found in the filtered search. | Mark this as an honest missing role until an existing vessel is approved or a replacement is authorized and measured. Do not relabel an empty bucket as a complete water system. |
| Eat | Table sized to room; chairs/bench on usable edges; reachable settings and a clear route around chairs. | `Table_Large`, `Chair_1`, `Bench`, `Stool`, `Mug`, `Chalice`, plates/cutlery. `Table_Large` is 2.848 m wide; its size requires a full seated-clearance calculation. | Count seats that can be approached, sit at, and leave. Place tabletop items on the table's measured top; no isolated table in an unrelated room. |
| Sit and talk | One clear focus (hearth, window, or reading), seats oriented toward one another/focus, an open central floor, optional book/chest side support, light. | `Bench`, `Chair_1`, `Stool`, `Bookcase_2`, `Chest_Wood`, candles/sconces. `SITTING_PARLOUR` already tries a settle, books/chest, sconce, and candle. | An observer can identify the conversation group from the plan. A central table must not consume the route or replace all seating. |
| Sleep and dress | Bed against a quiet wall, approach on a useful side, storage within reach, light reachable from bed, window/sightline that protects rest. | `Bed_Twin1`, `Bed_Twin2`, `Nightstand_Shelf`, `Chest_Wood`, `Cabinet`, candle and sconce. | Preserve access to the bed and separate sleeping from public, wet, hot, and noisy work paths. |
| Task and ambient light | Task light at kitchen/workbench/reading; lower calm light near rest; general light placed at the room's real focus. | `Torch_Metal`, candles, candelabrum, chandelier. `Lantern_Wall` remains exterior only. | Measure the light origin from the catalogue, verify illumination targets in the assembled scene, and ensure a light's hanging/floor placement does not collide with doors or a walking head. |
| Wall composition | Use construction and room use to choose a few useful wall elements: shelf over work, pegs near entry, books at study, bedside light, framed/soft piece in sitting/rest. Leave some walls quiet. | Mounted shelves, bottle shelf, peg rack, banners. Current props do not provide a clear household picture, mirror, tapestry, or curtain set. | Every mounted item has a valid host wall, correct face direction, height appropriate to hands/eyes, and no conflict with opening swing or window. Repeated walls should have rhythm, not copy/paste rows. |
| Soft detail and warmth | A restrained rug or textile can define a sitting/sleeping zone and soften a room; it must not hide a missing activity group or impede circulation. | No domestic rug/curtain/cushion is in the BrickWild prop catalogue. Owned-library `kenney_furniture-kit` contains `rugRectangle`, `rugRound`, `rugRounded`, and `rugSquare` (CC0), but they are candidate imports with no current measurement or style approval. | Inspect the low-poly look against project assets first. If chosen, import only the selected model(s), measure them, add a truthful support/placement row, rebuild the catalogue, and run the required asset lane. |
| Witch craft | Brewing/processing bench; heat and cookware; labeled/dry ingredients; usable book or recipe storage; task light; separate private sleeping and everyday cooking; link to herb yard/drying line. | Existing yard groups `herb_bed`, `drying_line`, and mushrooms; interior `Workbench`, `Cauldron`, pots, potion vessels, bookcase/books, bottle shelf, and wall light are all available. They are split across generic workshop, alchemist-trade, and yard paths. | Build one connected workspace; verify the style actually receives its work group with `trade=none`. Use the yard for growing/drying, the interior for preparation and storage, and a distinct domestic kitchen/eating/rest group. Avoid using potion bottle count as the witch identity test. |

## Current recipe baseline and practical gaps

`HouseFurnishingRecipes.RECIPES` already defines relational recipes rather than
unstructured inventory. Hall: table, seats, storage, shelf, light, and
tableware. Kitchen: hearth, storage, barrels/crates, cookware, shelves, light,
and tableware. Bedroom: bed, nightstand, chest, storage, light, books. Parlour:
table, benches/seats, bookcase, light, and tableware. Workshop: workbench,
crates, shelves, rack, lights, and tools. The furnisher also adds settings to
surfaces and performs walkability repair. This is a real foundation.

The following gaps stop the foundation from proving the requested inhabited
result:

* The ordinary kitchen recipe has no explicit full-size preparation workbench,
  chopping board, knife, water draw/wash, or mandatory meal-prep surface. Its
  ample-room addition adds a free table and storage, not a complete prep line.
* No current BrickWild prop has a true pitcher/ewer or basin/wash-station role.
  Buckets support carrying, not a credible water-and-washing arrangement.
* Furnishable surface dressing is mostly mugs, bottle, plate, cutlery, book,
  candles, and several fantasy vessels. Food variety and prep tools are thin.
* Current domestic props have no rugs, curtains, cushions, towels, woven
  hangings, domestic framed images, or broad wall-finish palette. The owned
  Kenney rug candidates are the smallest plausible first addition, subject to
  visual review.
* The witch yard already has herb and drying groups, but its interior
  brewing/book/bottle vocabulary is activated most directly by the separate
  `alchemist` trade. The `witch_hut` style row does not by itself request those
  interior work fittings. This is the integration gap to close, not an asset
  import requirement.
* `Nightstand_Shelf` is over 1.2 m tall. Do not assume that its key name
  describes bedside scale; consider a chest as low bedside support until visual
  inspection confirms the measured model works.
* `Table_Large` and `Bench` are over 2.7 m wide. They are useful for generous
  rooms but should not be scaled or dropped into small rooms solely to satisfy
  a recipe count. Use a smaller owned candidate only after it is visually
  approved and measured.

## Owned-library candidates for a small follow-up import

The asset search (6 Oct 2026) found these CC0, Godot-readable models in
`kenney_food-kit`: `bread`, `bowl`, `bowl_broth`, `bowl_soup`, `cooking_knife`,
`cooking_knife_chopping`, `cutting_board`, `cutting_board_round`, `pot`,
`pot_stew`, `pot_stew_lid`, `mushroom`, plus vegetables and ingredients. They
are not yet BrickWild props. Candidates serve these gaps:

| Candidate subset | Purpose | Import gate |
|---|---|---|
| `cutting_board`, `cooking_knife_chopping` | Explicit preparation action on a stable surface. | Check relative scale, pose, and support on `Workbench`; it should be a small tabletop model, not a new freestanding obstacle. |
| `bread`, `bowl`, `bowl_soup`, a small food set | A readable meal and pantry variety beyond generic tableware. | Check style/material compatibility with the current Quaternius prop set and avoid adding every food model. |
| `pot`, `pot_stew`, `pot_stew_lid` | Additional cooking vessels with visible contents/lid variation. | Select only if they are visually distinct and measured sizes fit shelves/hearth. |
| `rugRectangle` or `rugRound` from `kenney_furniture-kit` | A restrained soft zone for parlour or bedroom. | Different pack: visually inspect first, then measure flat bounds and surface/ground support. Avoid modern patterns if their style breaks the medieval scene. |

Searches for a CC0 Godot jug/pitcher/ewer, basin, and herb bundle returned no
matching model. Keep those as explicit missing roles. A minimal future asset
request should prioritize one water carrier/wash vessel and one or two wall
soft-detail pieces only after the existing and Kenney candidates have been
viewed at their correct scale. Record the exact pack licence with any import.

## Concrete palette and acceptance mapping

The `LIVE-GROUPS` implementation can begin with this palette map without
waiting for new assets:

| Room/group | Primary now | Support now | Placement contract |
|---|---|---|---|
| Kitchen/prep | `Cauldron` + `Workbench` | `Cabinet`, `Barrel`, `Barrel_Apples`, `Pot_1`, `Bucket_Metal`, `Shelf_Simple`, `Shelf_Small_Bottles`, tableware, `Torch_Metal`/candle | Workbench on a window-lit wall; leave its 0.9 m use zone. Heat and cookware close, bulk storage in a corner, no pot/bucket in the door or stair envelope. Keep the existing chimney/fire relation. |
| Dining | `Table_Large` | `Chair_1`, `Bench`, `Stool`, measured tableware, optional candle | Seat approaches on at least the clear edges; table settings fit the measured 0.813 m top. Review whether the current 2.848 m table is too large for a given room before selection. |
| Parlour | `Bench`/`Chair_1` around hearth/window focus | bookcase, chest, sconce, candle, optional rug candidate | Form a conversation arrangement with shared facing and clear center; keep wall-backed items away from doors/windows and reserve a continuous route. |
| Bedroom | `Bed_Twin1` or `Bed_Twin2` | `Chest_Wood`, `Cabinet`, `Candle_1`/`Torch_Metal`; `Nightstand_Shelf` only after scale review | Keep bed head at a quiet wall, avoid window wall per affinity, allow a 0.75 m use zone and clear door route. |
| Witch workshop | `Workbench` + `Cauldron` | `Pot_1`, `Potion_1`, `Potion_2`, `SmallBottles_1`, `Bookcase_2`, books, `Shelf_Small_Bottles`, mushrooms/herb yard | Bench faces task light/daylight, wall shelf above the bench, ingredients grouped by task, clear 0.9 m work approach; preserve separate kitchen and private bedroom. |

For every candidate placement, retain both the measured footprint and the
authored usage metadata. `SURFACE` must be used when something sits on an
object; `ON_SURFACE` objects must never be floor-placed; wall-mounted keys need
their corrected `face`; clearance zones must participate in the existing
walkability checks. Do not infer `top` from a convenient guessed height when
the measured support is the full bounding box.

Acceptance for an ordinary furnished house requires all of the applicable
groups above at a size where they fit, with the actual final meshes measured.
At small footprints, preserve the core cooking, sleep, and entry functions and
report a genuinely infeasible role; do not substitute a scattering of pots for
preparation or a bed pushed into the only circulation path. A witch hut must
read as a home and a working herbal dwelling in both exterior/yard and
interior walk views. The asset palette is support for that result; it is not
the design result by itself.
