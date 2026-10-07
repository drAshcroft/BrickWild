# Building personality briefs

Prepared 2026-10-06. This is an artistic design brief for all nine currently
published building families and their style, purpose, and sub-kind options. It
describes intended future identity. It does not claim the current generator
already meets these briefs, and it makes no historical-authenticity claim.

The user asked for recognizable style and personality across the catalogue.
The witch hut is one example found during a walk, not the limit of the work.
The target is a building whose silhouette, plan, materials, thresholds, light,
and arrangement of use tell the same story. A palette change or a few themed
props alone do not establish identity.

## Scope and current baseline

The public catalogue in `src/api/building_library.gd` publishes nine families.
The complete selector and sub-kind inventory is below. Every shop business can
be requested with every shared house style. Thus the shop matrix is 12 shells
by 23 businesses, not 23 independently designed facades.

The current house style rows vary roof form/material, palette, timber, porch,
shutters, storeys-related ornament, and—in several vernacular rows—parapets,
verandas, eave sweep, thatch rolls, and corner piers. Most still enter the same
house planning and furnishing systems. The witch hut already has steep roof,
palette, chimney, cauldron/pot, herb-bed, drying-line, and mushroom vocabulary;
its outstanding complaint is that these do not yet make a convincing whole.
The `rich` row adds articulated exterior ornament, but its own design document
states that it remains an ordinary house plan.

Shop businesses currently define room programmes, front-door dimensions,
optional shopfront openings, and a focus fitting in `ShopSpec.BUSINESSES`.
They reuse house shell/planning/furnishing machinery. This gives meaningful
starting points for work but does not prove that each business reads clearly
from the street or that the rooms support its work as a complete composition.

Church style rows vary probabilistic structural and silhouette features, with
landmark-specific composition documented in `docs/LANDMARKS.md`. Temple form
and cult are separate inputs: forms describe the plan and roof mass; cults
select the idol, dress, stains, palette, and glow. Temple axis/rite rules remain
authoritative. These are current capabilities, not a visual acceptance result.

The briefs below are proposals. Words such as "should" and "must" state the
future review contract. They are not descriptions of code that exists today.
Where a present public label is too broad to imply a well-grounded design
identity, the brief says so rather than pretending the label settles it.

## Nine-family inventory

The public catalogue in `src/api/building_library.gd` has nine families:
church, castle, house, shop, hotel, temple, windmill, world building, and
village. This table is the scope check against `BuildingLibrary.KINDS`. House,
shop, church, and temple receive detailed briefs below; the other five receive
concise family-wide identity contracts later in this document. Every shop
business uses each shared house style, so the matrix is 12 shells by 23
businesses.

| Public family | Published style/form rows | Published purpose/sub-kind rows | Brief location |
|---|---|---|---|
| `church` | `romanesque`, `gothic`, `byzantine`, `nordic_stave`, `renaissance`, `russian` | none | Church style briefs |
| `castle` | `norman`, `edwardian`, `crusader`, `french_chateau`, `bavarian`, `japanese`, `moorish`, `wizard`, `dark`, `sky`, `elven` | none | Other public family briefs |
| `house` | `cottage`, `farmhouse`, `townhouse`, `longhall`, `witch_hut`, `rich`, `mediterranean`, `asian`, `african`, `thatch_cottage`, `mud_hut`, `pueblo` | `none`, `smith`, `alchemist`, `farmer`, `innkeeper`, `scholar` | House style briefs; household trade note |
| `shop` | all 12 house style rows above | `barracks`, `library`, `prison`, `palace`, `blacksmith`, `stable`, `restaurant`, `tavern`, `inn`, `bakery`, `butcher`, `apothecary`, `general_store`, `tailor`, `carpenter`, `town_hall`, `guildhall`, `market_hall`, `alchemist_laboratory`, `bathhouse`, `hospice`, `school`, `thieves_den` | Shop and civic business briefs |
| `hotel` | `grand_budapest`, `alpine_palace` | none | Other public family briefs |
| `temple` | forms: `basilica`, `pylon`, `ziggurat`, `rotunda` | cults: `blood`, `void`, `flame`, `bone`, `serpent` | Temple forms and cults |
| `windmill` | `tower`, `post`, `smock`, `windpump`, `paddle` | none | Other public family briefs |
| `world` | `courtyard_house`, `mosque`, `cruciform_temple`, `timber_hall`, `insula`, `tower_house`, `caravanserai`, `hammam`, `pagoda`, `stupa`, `vihara`, `vastu`, `siheyuan`, `tulou`, `nagara`, `rock_cut_temple`, `temple_mountain`, `stepwell`, `dravida` | sub-kinds mapped in Other public family briefs | Other public family briefs |
| `village` | cultures: `english`, `frankish`, `norse`, `alpine`, `moorish`, `eastern`, `blighted`, `mediterranean`, `east_asian`, `saharan` | purposes: `farming`, `crossroads`, `market`, `mill`, `fishing`, `mining`, `garrison`, `pilgrim`, `forest` | Other public family briefs |

## Shared identity and acceptance contract

Review each style without labels, then ask a reviewer who has not seen the
request to identify the building's use and broad style from its exterior and
walk-through. Show at least a roof-on exterior, plan/cutaway, entrance view,
main activity view, and private/service view where those spaces apply. A style
passes only when all of these statements are true:

1. **Silhouette:** one or more structural forms distinguish it at a distance;
   changing only colors or props would visibly weaken the read.
2. **Plan and movement:** room sizes and adjacency fit the stated life. Arrival,
   public use, service, privacy, doors, halls, stairs, and landings form a
   comfortable route. A corridor or leftover strip does not count as a room.
3. **Complete use:** required activities have coherent groups, work surfaces,
   storage, access, and appropriate light. Furniture relates to walls and
   neighbors; it does not sit as isolated inventory.
4. **Composed surfaces:** openings, structure, wall bays, ceilings, floor,
   fittings, and light reinforce room purpose. Quiet wall space is allowed;
   blankness by accident and clutter for a score are not.
5. **Materials and detail:** material logic supports the form and climate
   implied by the brief. Do not use a generic palette as a substitute for
   construction character.
6. **Repeatability and variety:** fixed seeds retain the brief's identity while
   changing secondary details. Every supported size keeps usable proportions;
   scaling a box up or down is not a design variation.
7. **Specificity:** the reviewer can name at least two independent identity
   cues, one spatial or structural and one experiential/use-based. Props alone
   cannot satisfy this rule.

This is a visual and spatial review, supported by measured plan, navigation,
opening, furnishing, and mesh checks. It is not a historical or building-code
certification. Respect intentional emptiness in sacred spaces and quiet rooms.
Treat comfort concerns as arrival, privacy, sightlines, light, and movement;
do not present one culture's feng shui as universal.

## House style briefs

Every row below is a future design direction for a published id in
`HouseSpec.STYLES`. Current feature notes summarize the row and related code;
the direction is proposed work.

| Published style | Current capability evidence | Proposed recognizable personality |
|---|---|---|
| `cottage` | Timber frame, gable/half-hipped roof, porch/chimney/shutters by chance. | A modest, settled home. Low eaves, readable hearth stack, sheltered door, small window bays, and a compact plan organized around cooking, eating, sleep, and storage. Warmth comes from an arranged hearth group and useful fitted storage, not a room-wide prop scatter. |
| `farmhouse` | Thatch, broad roof options, porch, high clutter range, yard/trade dressing. | A working home with a clear boundary between family life and farm work. Give the kitchen/store/work area a service route to the yard; use a generous back or side threshold and robust utility spaces. The public front remains domestic rather than becoming a barn facade. |
| `townhouse` | Close timber studding, slate roof, frequent jetty/dormers, stone-ground chance. | A tall, narrow street house. Make vertical stacking legible, give the entrance a compact arrival zone, put noisier/public work low and protected sleeping above, and make the stair a deliberate spine with landings and light. The street face should read as repeated bays, not a wide cottage squeezed thin. |
| `longhall` | Long gable form, thatch, timber braces, wide hall-oriented style row. | A communal long room is the organizing space, with a shared hearth and roof structure that explains the long span. Place sleeping and work at calmer ends or in subordinate bays. Keep the hall a lived-in social room; do not turn it into an empty corridor with a table. |
| `witch_hut` | Steep gable roof, chimney, dark green palette, cauldron/pot and herb-yard vocabulary. | A recognizable craft dwelling. Use a steep, asymmetrical but supported roof/chimney silhouette, a protected threshold, an active brewing/herb-processing bench near dry stores and water, a small hearth/eating place, and a private sleeping nook. Link the workroom to drying herbs and a garden outside. The ordinary domestic life must still work. Do not depend on crooked geometry or a cauldron for recognition. |
| `rich` | Cornice, string courses, pediments, ridge finial, jetty/dormer/porch variation; minimum two storeys. | A prosperous household with a formal arrival and a clear public-to-private sequence. Use the articulated facade to express floor hierarchy and an upper-storey silhouette; make the stair, parlour, dining, service, and bedrooms feel sized and related to the household. Ornament must follow the plan and structure, not mask a small cottage plan. |
| `mediterranean` | Lime-render palette, tile roof, low pitch, shutters, parapet-capable vernacular row. | A shaded masonry home built around cool transitions: thick-looking walls, deep eaves or terrace edge, shaded entry/loggia, cross-light, and a compact open-air court or equivalent outdoor room where the footprint supports it. Keep shutters, tile, and wall depth coherent. Do not imply that one generic row represents every Mediterranean culture. |
| `asian` | Raised plinth, deep hipped tile roof, veranda and swept-eave switches, timber frame. | Current label is broad. Proposed direction: a raised timber house with a continuous veranda, layered thresholds, a strong roof plane, and flexible rooms arranged around a clear central or garden-facing relationship. The label and cue set need cultural narrowing/review before claiming a specific Asian tradition; do not blend unrelated regional forms into one supposedly authentic style. |
| `african` | Earthen palette, thatch, veranda, parapet/corner-pier switches; comments describe an inward compound idea. | Current label is broad. Proposed direction: a fictional family compound whose shaded outdoor room links private sleeping, food preparation, storage, and shared life, with thick earthen masses and climate-aware openings. The broad label requires cultural narrowing/review before claiming a specific African tradition. Do not reduce a continent to ochre walls and thatch. |
| `thatch_cottage` | Steep thatch roof and combed ridge/eave roll; deliberately no bargeboards. | A small, soft-edged rural dwelling whose roof is visibly made and maintained as thatch. Let the roof mass, eave thickness, chimney, and sheltered door define its silhouette; arrange a compact hearth-centered household inside. Keep its read distinct from the generic cottage through roof construction and massing, not a palette swap. |
| `mud_hut` | Thick earthen walls, small/high openings, conical thatch roof, corner piers. | The current label is generic and may be derogatory in some contexts. Proposed design is a compact earthen dwelling with a protected central hearth, thick reveal depth, a roof vent, and useful shaded threshold. Rename and narrow the reference before claiming cultural identity. Do not assume all earthen homes are round, primitive, or one-room. |
| `pueblo` | Thick adobe wall, flat earth roof, parapet, terrace silhouette. | A stepped earthen settlement house with an inhabited roof terrace, deep wall reveals, compact protected openings, and a deliberate ladder/stair or roof access route where supported. Rooms should cluster around a shared outdoor court or roof life. The word names a living architectural tradition; seek appropriate cultural review and avoid treating this as a generic desert prop set. |

These directions preserve variety within a row: vary secondary openings,
finishes, and household details while retaining the defining spatial and
structural cues. Do not randomize away the thing that makes the style legible.

Household trades in `HouseSpec.TRADES` remain overlays on a domestic style.
Each trade should add a coherent work zone and storage/access story while
preserving the household's kitchen, rest, and social life.

| Trade id | Proposed household personality |
|---|---|
| `none` | A household with no extra occupation room; the ordinary domestic activities remain complete. |
| `smith` | A work zone near a safe exterior/service threshold, with forge/anvil, bench, fuel, and tool storage separated from sleeping and food preparation. |
| `alchemist` | A private preparation workshop with bench, books/ingredients, heat and ventilation access; its fantastical materials should still be organized as a working craft. |
| `farmer` | A direct path between kitchen, store, and yard with harvest/tool storage; the household remains more than an attached barn. |
| `innkeeper` | A social parlour or service room faces a clear guest arrival, while family sleeping and kitchen routes retain privacy. |
| `scholar` | A quiet study/parlour has useful book storage and a writing/reading surface, connected to but not swallowed by household life. |

## Shop and civic business briefs

Every business id in `ShopSpec.BUSINESSES` can currently use every
`HouseSpec.STYLES` shell row above. The shell is a setting; the business must
still read through its street face, customer route, focus fitting, work zone,
back stock, and service access. The following assignments cover all 23
published business rows. Directions are proposed; existing programmes and
focus fittings are only starting data.

| Business id | Proposed spatial/use personality |
|---|---|
| `barracks` | A controlled entry reaches a visible duty/office point; mess, sleeping, and armoury zones branch into distinct public, communal, and secured areas. Keep weapons storage away from the entry route. |
| `library` | A quiet reading threshold leads to legible reading places, with stacks and script work behind or alongside them. Use repeatable shelving bays, task light, and a calm focus; do not make the lectern the only evidence of a library. |
| `prison` | A guarded entry, clear observation point, controlled aisle/cell pattern, and secure staff route explain the plan. Keep circulation direct and uncluttered; do not dress cells as ordinary bedrooms. |
| `palace` | An ordered ceremonial sequence from arrival through antechamber to throne room, with treasury and private chamber protected off that axis. Height, thresholds, and focus should express authority without making circulation unusable. |
| `blacksmith` | The street-facing forge/anvil reads through a broad work threshold and a safe work zone; fuel, tools, and stock sit within short carrying distance. Keep customer approach outside dangerous work space. |
| `stable` | Wide animal access, stall bays, tack storage, feed, and a clean service aisle form a working stable. Door width and turning room matter more than decorative clutter. |
| `restaurant` | A welcoming dining room is distinct from the working kitchen; a counter, pass, or service opening makes their relationship legible. Storage and staff access avoid cutting through guest seating. |
| `tavern` | A social room centers on a readable bar/counter and conversation groups; kitchen and stores connect to service paths. Give the entry a place to arrive and gather without blocking the room. |
| `inn` | Public dining and service sit near arrival; a gallery or clear passage serves guest rooms without making one guest room a route to another. Guest doors and private windows support privacy. |
| `bakery` | The display/sales threshold faces the street; oven, preparation bench, cooling/work surfaces, and flour/stock stores form a clean production loop behind it. Make the craft visible without obstructing customer access. |
| `butcher` | A clear sales counter fronts a separated cutting/preparation zone with washable-looking work surfaces and cold/store provision. Keep stock and customer circulation distinct. |
| `apothecary` | A counter and readable shelves frame the public room; a secure preparation bench, labeled drawers/vessels, and controlled stock sit behind it. Avoid the generic alchemist-laboratory silhouette unless this is explicitly a fantasy variant. |
| `general_store` | A broad, browsable sales floor with counter, grouped goods, and direct stock access. The entrance should reveal a useful range of goods while leaving a clear route to the counter. |
| `tailor` | A customer-facing fitting/sales area connects to a well-lit cutting table, sewing/work bench, cloth storage, and fitting screen. Keep long fabric work surfaces clear and accessible. |
| `carpenter` | A large, unobstructed bench zone with tool wall, timber storage, and work access defines the shop. The sales area can be secondary; the workbench and material path lead the composition. |
| `town_hall` | A public entry leads to a civic chamber with a clear meeting focus; records and offices sit on controlled side routes. The room should support people gathering and speaking, not read as a shop floor. |
| `guildhall` | A communal meeting hall is the heart, with a visible place for shared decisions and display of the guild's work. Offices and records support it without competing with the main room. |
| `market_hall` | A broad public span with repeated vendor bays or a clear central market aisle, several approach paths, and service/storage edges. One counter in an otherwise empty box is not a market hall. |
| `alchemist_laboratory` | A controlled workshop organized around preparation benches, heat, water, ventilation, ingredient storage, and safe circulation. Separate public access from hazardous or private work. |
| `bathhouse` | A legible sequence from changing to bathing and staff/service space; privacy and wet/dry transitions govern thresholds and material changes. It should feel calm, humid, and processional, not like an ordinary room set with tubs. |
| `hospice` | A quiet arrival and dispensary lead to wards with access around beds, daylight, storage, and staff circulation. Protect rest and privacy; avoid packing beds into a corridor. |
| `school` | A bright schoolroom has a teaching focus, pupil places, and clear movement; the master's office and stores are supportive, separate spaces. Make the room's orientation readable on entry. |
| `thieves_den` | A deliberately concealed threshold leads to a compact common/transaction space; stores, sleeping, and escape/service routes are discreet and controlled. Avoid making it indistinguishable from a generic shop with a sinister palette. |

Any combination of shell style and business must keep both identities visible.
For example, a Mediterranean bakery should still read as a bakery through its
production loop and street display, while its shell retains the shaded masonry
and tile-roof character. Infeasible combinations should be constrained or
explicitly softened, rather than allowed to erase either brief.

## Church style briefs

The published rows are `romanesque`, `gothic`, `byzantine`, `nordic_stave`,
`renaissance`, and `russian`. Current probabilities and available landmark
features are in `src/church/church_spec.gd`; the following are proposed visual
priorities. The church interior must preserve an intelligible entry, nave, and
sanctuary hierarchy as well as a coherent structural and light rhythm.

| Published style | Proposed recognizable personality |
|---|---|
| `romanesque` | Heavy, grounded masonry; rounded openings; compact towers; a strong west entry; and a clear nave/apse sequence. Let repeated bays and thick supports explain the weight. |
| `gothic` | A tall, directional nave; pointed openings; vertical piers and buttresses that visibly carry the height; a luminous upper wall; and an emphatic west front. Height must still read at human scale inside. |
| `byzantine` | A centered, domed spatial focus with supporting half-domes or subsidiary volumes; layered entry; luminous drum and reflective interior focus. A dome must visibly belong to its bearings and central plan. |
| `nordic_stave` | A steep, timber-built vertical silhouette with layered roof lines, carved/structural posts, and a compact, sheltered nave. Timber construction should govern both exterior rhythm and the interior, not appear as surface stripes. |
| `renaissance` | Balanced geometry, measured bays, a legible crossing/dome, and controlled classical framing. The entry and plan should feel composed around clear proportions rather than a random tower chance table. |
| `russian` | A clustered, vertically varied composition with onion domes tied to distinct chapel volumes, a clear processional approach, and warm icon-focused interior light. Domes should crown meaningful spaces, not sit as detachable ornaments. |

Do not force every style to have the same transept, tower, seating, or
sanctuary details. Keep structure and worship sequence primary. Named landmark
fixtures are special compositions, not proof that all generated examples of a
style pass.

## Temple forms and cults

The supported form rows are `basilica`, `pylon`, `ziggurat`, and `rotunda`;
the supported cult rows are `blood`, `void`, `flame`, `bone`, and `serpent`.
All 20 combinations are supported inputs. The form owns plan and silhouette;
the cult owns ritual focus, light, material treatment, and the character of
the sacred objects. These proposals extend the current separation rather than
collapse it. Every combination must retain a readable gate-to-god axis and the
existing temple rite contract. Empty space may be ritual space.

| Form | Proposed spatial and silhouette identity |
|---|---|
| `basilica` | A processional nave with side aisles and a far apse; the altar and roof focus align on the axis. The interior's length should lead the eye and body to the destination. |
| `pylon` | A monumental gate compresses arrival, then releases into an open court and columned approach to a small, restricted inner shrine. Thresholds must make the change in access legible. |
| `ziggurat` | A stepped mass and visible stair lift the ritual route toward a summit shrine; the ground-level base remains a distinct chamber. The climb is part of the experience. |
| `rotunda` | A circular colonnade and central void organize the room; a deliberate bridge or crossing reaches a focus over the pit. Keep the ring, opening, and route visibly related. |

| Cult | Proposed sensory/use identity |
|---|---|
| `blood` — The Crimson Choir | A communal, repeated rite around a figure; red accents and traces of use guide the sequence to the focus. Keep marks purposeful and avoid indiscriminate gore as surface fill. |
| `void` — The Starless Deep | A sparse, dark, quiet approach to an unadorned monolith; low blue light and large shadowed intervals make absence active. Do not fill the void with decoration. |
| `flame` — The Ashen Crown | A heat- and light-led procession toward a pyre; warm glow, soot, fuel access, and safe spacing organize the room. Fire fixtures must not obstruct the route. |
| `bone` — The Ossuary | Pale mineral surfaces and collected remains form ordered, deliberate memory around a cairn focus. Use quiet repetition and legibility, not a random scatter of bones. |
| `serpent` — The Coiled Fang | A winding or encircling visual motif and green-lit focus imply a coiling presence, while the actual floor route remains safe and direct enough to walk. |

Review all form/cult combinations as distinct overlays: a void rotunda must
remain circular and void-like; a blood pylon must remain gate-court-shrine in
its access hierarchy. Do not let palette alone carry the cult identity or let
cult props erase the architectural form.

## Other public family briefs

These public families are in scope for the same recognizable-style goal. The
current feature notes describe published rows; each personality sentence is a
proposed review direction.

### Castles

Castle style rows currently choose massing, tower shape, openings, roof, and
stone palette; the exact options are in `CastleSpec.STYLES`. Every style must
also make defense, residence, ceremony, or fantasy purpose legible through the
plan. A castle is not accepted from towers and a wall outline alone.

| Style id | Proposed personality |
|---|---|
| `norman` | A compact, dominant square keep anchors a defensible enclosure; the gate route and vertical access feel controlled. |
| `edwardian` | Concentric round-tower defenses and a strong gatehouse make layered access the defining experience. |
| `crusader` | Thick battered walls, low heavy towers, and nested defenses express mass and endurance; routes between rings remain purposeful. |
| `french_chateau` | A residential range with steep roofscape, dormers, and elegant round towers; defensive features recede behind courtly living. |
| `bavarian` | A romantic skyline of slender towers and steep roofs frames a coherent palace-like residence, not an implausible fort. |
| `japanese` | A tiered timber keep rises from a battered stone base; gate, baileys, and roof hierarchy organize a legible approach. Cultural specificity merits expert review. |
| `moorish` | A warm masonry enclosure and inward court organize shade, privacy, and controlled entry; avoid reducing the design to arches and color. Narrow reference and seek cultural review. |
| `wizard` | A solitary vertical tower house makes study, ritual, storage, and protected retreat legible in its stacked plan; arcane decoration cannot replace usable floors and stairs. |
| `dark` | A severe, defensive ridge fortress uses a hard skyline and narrow approaches to create controlled, somber space. Keep darkness readable and navigable. |
| `sky` | An elevated, airy citadel pairs light-looking towers and connected platforms with explicit support and safe routes; height must not become floating ornament. |
| `elven` | A flowing, curved plan and slender hall volumes express a continuous landscape relationship; structure and circulation must explain every curve. |

### Hotels

The current `HotelSpec.HOTEL_STYLES` has facade palette/ornament/roof-rise
rows; hotel planning also carries lobby, room, and circulation contracts.
Those facts are not proof of an inviting hotel experience.

| Style id | Proposed personality |
|---|---|
| `grand_budapest` | A memorable civic facade and generous central arrival lead to a visible reception focus, public lounge/dining, and clearly separated guest circulation. The theatrical exterior should continue into coherent public interiors. |
| `alpine_palace` | A sheltered mountain retreat uses a steep, weather-aware silhouette and warm public hearth spaces, with quiet guest rooms and clear service paths behind them. |

### Windmills

`WindmillSpec.TYPES` already distinguishes which part turns and what supports
it. Visual acceptance must show the machine's working logic, maintenance
access, and relationship to wind or water, not only a rotor silhouette.

| Type id | Proposed personality |
|---|---|
| `tower` | A tapering masonry drum carries a rotating cap, with stage and fantail visibly attached to their jobs. |
| `post` | A complete timber body turns on one post; mound/trestle, offset ladder, and tail make support and access legible. |
| `smock` | An octagonal weatherboard body sits on its stump, with the cap turning above it; contrast the timber skin with tower-mill masonry. |
| `windpump` | An open lattice tower carries a many-bladed weathercocking head and a visible pump connection below. It must read as a pump machine, not a sail mill. |
| `paddle` | A grounded tower couples directly to a water race and undershot wheel. Water route, wheel clearance, and maintenance access are essential identity cues. |

### World buildings

`WorldFamilies.FAMILIES` publishes 19 architectural families with the
following sub-kinds. Each exact public family and sub-kind is listed. These are
briefs for spatial identity and use; details that imply a living cultural
tradition need informed review before they are presented as representative.

| Family id and sub-kind ids | Proposed personality |
|---|---|
| `courtyard_house`: `domus`, `riad`, `palazzo` | The courtyard is the organizing room outdoors. Keep inward-facing rooms, thresholds, and privacy legible; distinguish the household, garden-water, and ceremonial-palace variants in scale and sequence. |
| `mosque`: `hypostyle` | A shaded column hall and clear prayer orientation organize arrival, rows, and the qibla focus. Avoid treating the minaret or dome as a substitute for the worship space. Seek cultural review. |
| `cruciform_temple`: `temple_of_four_winds` | Four directional arms meet at a central focus; approach and orientation explain the cross-shaped plan and its vertical landmark. |
| `timber_hall`: `great_hall`, `phoenix_pavilion` | A large timber roof span, platform, and column rhythm define a gathering hall; the pavilion variant emphasizes open edges and a roofed platform. Do not make the two labels visually interchangeable. |
| `insula`: `port_tenement` | Repeated domestic units wrap a shared court and stack vertically, with street access, light, sanitation, and shared circulation treated as one system. |
| `tower_house`: `merchant_tower` | A compact, tall merchant residence stacks secure storage, work, household rooms, and defended access along a clear stair. Each floor must have a plausible use and landing. |
| `caravanserai`: `sultan_han` | A monumental gate opens to a working court; guest cells, stables, service, and a protected winter hall form a legible waystation. Movement of people and animals must not conflict. |
| `hammam`: `steam_baths` | A private changing-to-warm-to-hot sequence, domed rooms, controlled light, and service heat route make the bathing ritual legible. Preserve wet/dry and privacy transitions. |
| `pagoda`: `square_pagoda`, `octagonal_pagoda`, `dodecagonal_pagoda` | A rising sequence of distinct roof tiers marks stacked sacred levels. Each footprint variant should retain its own geometry and structural rhythm; all need safe, purposeful vertical access. Seek cultural review. |
| `stupa`: `saints_mound` | A solid sacred mound and circumambulatory route make walking around the monument the primary experience. Decoration must not block the route. |
| `vihara`: `monks_cloister` | A quiet monastic community is arranged around a cloister court, with cells, shared practice, and service spaces opening to deliberate thresholds. |
| `vastu`: `merchants_haveli` | An inward merchant mansion uses layered courts, screened arrival, family privacy, and guest reception to distinguish public trade from domestic life. Narrow the cultural claim and seek review. |
| `siheyuan`: `scholars_compound`, `two_court_compound` | An ordered courtyard sequence gives the main hall and wings clear hierarchy; the two-court variant adds a meaningful privacy gradient. Preserve orientation, screen, and court-to-room relationships. Seek cultural review. |
| `tulou`: `clan_ring` | A thick, communal ring encloses shared court and circulation; repeated dwelling bays and protected entry make collective life readable. Do not reduce it to a circular wall. Seek cultural review. |
| `nagara`: `hundred_spires` | A focused shrine is expressed by a rising clustered tower silhouette and a clear sacred approach; the outer massing should gather toward the sanctum. Seek cultural review. |
| `rock_cut_temple`: `quarried_temple` | Architecture is carved from a retained rock mass; cut face, courtyard, pillars, chambers, and light openings should read as subtraction from terrain, not a freestanding facade. |
| `temple_mountain`: `angkor_mountain` | A terraced cosmic mountain organizes concentric enclosures, ascent, and a summit sanctuary; the climb and nested thresholds are the experience. Seek cultural review. |
| `stepwell`: `queens_well` | A descending stair and repeated landings bring people to water; shade, retaining walls, access, and the changing light down the section define its identity. Seek cultural review. |
| `dravida`: `god_kings_precinct` | A temple precinct unfolds through a monumental gateway, layered enclosures, subsidiary shrines, and a focused inner sanctuary. Let the site sequence dominate rather than multiplying towers without hierarchy. Seek cultural review. |

### Villages

Village culture and purpose are public choices in `VillageSpec`. Culture
affects household/style distribution and planted vocabulary; purpose selects
the village form and programme. The identity should be visible across the
settlement plan, not only on individual house palettes. Current code supports
seven forms (`gate`, `strand`, `planted`, `crossroads`, `green`, `round`,
`street`); purpose and population determine which form is eligible. Each row
below maps a public culture or purpose to a proposed settlement personality.

| Culture id | Proposed settlement identity |
|---|---|
| `english` | A mixed rural settlement of cottages, farmsteads, lanes, and shared green, with coherent local materials and a clear village center. |
| `frankish` | A compact agrarian settlement organized around a church/green and productive plots; keep street rhythm and household variation consistent. |
| `norse` | A robust timber settlement with a communal hall, working yards, and weather-protected routes; avoid turning every dwelling into a longhouse. |
| `alpine` | A slope-aware settlement with clustered buildings, sheltered paths, and practical access between homes, storage, and grazing/work spaces. |
| `moorish` | A shaded, inward-oriented settlement with protected courts, water-conscious public space, and screened thresholds. Narrow the cultural reference and seek informed review. |
| `eastern` | This label is too broad to promise a specific architecture. Define a named regional direction and review it before claiming a coherent cultural identity. |
| `blighted` | A visibly strained or abandoned settlement expressed through broken upkeep, damaged routes, and selective vacancy while retaining a readable original structure. |
| `mediterranean` | A compact settlement with shaded public edges, masonry mass, and an active central square or water point. Avoid treating a broad region as one exact style. |
| `east_asian` | A legible settlement pattern with courtyard relationships, roof hierarchy, and a coherent street/gate system. The regional label is broad; narrow and review the intended reference. |
| `saharan` | A settlement organized around shade, water access, protected courts, and compact paths through heat. Narrow the cultural and climatic reference with informed review. |

| Derived village form | Proposed settlement composition |
|---|---|
| `gate` | The entry and its approach make defense and arrival the settlement's organizing axis. |
| `strand` | A long water-edge settlement ties homes and work yards to landing access along the shore. |
| `planted` | A generous planted common or market green anchors a larger settlement and its civic life. |
| `crossroads` | A clear junction gathers services and public activity where the main routes meet. |
| `green` | A shared green sits within walking reach of homes, paths, and community buildings. |
| `round` | A compact circular edge and central shared space reinforce the blighted settlement's sense of enclosure while keeping entry legible. |
| `street` | A linear street links homes, services, and work frontage into one readable settlement spine. |

| Purpose id | Proposed village form/use personality |
|---|---|
| `farming` | Homes, barns, plots, and routes connect directly to productive land; the green or lane remains a shared social focus. |
| `crossroads` | Roads meet at a legible common space with services facing the junction; movement should create the settlement's center. |
| `market` | A market square or planted common anchors trade, with clear approach routes and room for stalls without swallowing homes. |
| `mill` | The mill, water/wind infrastructure, and working route are visible anchors; place homes and service yards in relation to that work. |
| `fishing` | A strand or water-edge common ties homes, landing, gear storage, and paths to the shore into a working sequence. |
| `mining` | The settlement relates to an entry/adit and ore handling route; separate hazardous work and spoil from homes and shared space. |
| `garrison` | Defensible entry, watch points, stores, and a practical central route express the settlement's military role. |
| `pilgrim` | A clear arrival and hospitable shared route lead to a sacred destination, with rest/service provisions organized along it. |
| `forest` | A compact clearing links homes, woodland work, and paths while preserving a strong edge between settlement and forest. |

Culture and purpose are overlays. The same fishing village may have different
cultural architecture; the same culture may build for farming or mining. Keep
both meanings legible, and avoid using one as a palette-only override of the
other.

## Exceptions and review boundaries

Some current public options describe civic or industrial buildings rather than
shops in the ordinary retail sense. They are included because the API publishes
them through the same shop family. Do not force storefront windows or retail
counters onto `prison`, `palace`, `barracks`, `stable`, `town_hall`,
`guildhall`, `bathhouse`, `hospice`, or `school` where the brief gives another
use. Their use and access hierarchy take precedence over the shared family
name.

Cross-cultural rows (`asian`, `african`, `mud_hut`, `pueblo`) need careful
naming and review. The directions above are design prompts, not claims of
authentic representation. Narrow the reference and vocabulary with appropriate
cultural expertise before presenting a result as representative. The labels
remain published API identifiers until an intentional compatibility change is
made.

Household and shop footprints may not fit every proposed room sequence at
every supported size. At small sizes, reduce optional spaces while preserving
the defining activity and route; if the core brief cannot fit, report that
constraint or reject/replan it. Sacred layouts keep their own rituals and
intentional emptiness. Landmark and rich-house ornament do not replace
inhabited-space design.

## Delivery and visual review

Use this document alongside `docs/INHABITED_BUILDINGS_PLAN.md`. Start with a
cross-family visual inventory and implement briefs in vertical slices. For
each slice, record the exact request, seed, dimensions, revision, views, human
observations, and unresolved criticism. Use at least three predetermined
seeds and supported small/default/large sizes for representative reviews;
then broaden review to every published row. A label-hidden comparison and
first-person walk are required. Automated measurements can verify dimensions,
clearance, access, and required fittings; they cannot certify personality or
homeliness.

Passing means a reviewer can recognize the building's purpose and intended
style from its form and lived arrangement, can move through it comfortably,
and can explain why its rooms and surfaces belong together. Record deliberate
exceptions and known limitations beside the result. Do not count a completed
pin fix, a green geometry lane, or a prop count as visual acceptance.
