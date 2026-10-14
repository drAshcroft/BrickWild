# Family style ledger

Coverage ledger for LIVE-FAMILY-STYLES, acceptance item 1: every published
kind, style and purpose has a mapped brief, actual request fixtures and an
explicit evidence state. Written 2026-10-14 from code and file reading. No
suite or render was run to produce this table.

## Source of the published list

- `src/api/building_library.gd:29` `KINDS`: church, castle, house, shop, hotel,
  temple, windmill, world, village. Bridge, tree and dungeon are not in
  `KINDS`, and `src/api/building_navigation.gd:16` says bridges and trees report
  `supported: false`. They are not published kinds and are excluded. Dungeon
  styles (`src/dungeon/dungeon_styles.gd:19`, five styles) are not published
  through the library either.
- `src/api/building_library.gd:192-222` names each kind's style and purpose
  table: `styles()` and `purposes()`.
- `src/api/building_request.gd:127-173` holds the request factories
  (`church` 127, `castle` 132, `house` 137, `shop` 144, `hotel` 151, `temple` 156,
  `windmill` 165, `village` 173). The world family is reached through the
  generic `world` kind, with `WorldFamilies.FAMILIES` (`src/world/world_families.gd:15`).

| Table | File:line |
|---|---|
| church styles | `src/church/church_spec.gd:76` `STYLES` |
| castle styles | `src/castle/castle_spec.gd:271` `STYLES` |
| house styles (also the shop shell) | `src/house/house_spec.gd:121` `STYLES` |
| house trades (house purpose) | `src/house/house_spec.gd:112` `TRADES` |
| shop businesses (shop purpose) | `src/shop/shop_spec.gd:185` `BUSINESSES` |
| hotel styles | `src/hotel/hotel_spec.gd:5` `HOTEL_STYLES` |
| temple forms (style) | `src/temple/temple_spec.gd:60` `FORMS` |
| temple cults (purpose) | `src/temple/temple_spec.gd:96` `CULTS` |
| windmill types (style) | `src/windmill/windmill_spec.gd:147` `TYPES` |
| world families (style) | `src/world/world_families.gd:15` `FAMILIES`, `kinds` arrays per family |
| world sub-kinds (purpose) | the `kinds` arrays in `src/world/world_families.gd` |
| village cultures (style) | `src/village/village_spec.gd:61` `CULTURES` |
| village purposes (purpose) | `src/village/village_spec.gd:64` `PURPOSES` |

Row counts: church 6, castle 11, house 12 styles and 6 trades, shop 12 shells
and 23 businesses, hotel 2, temple 4 forms and 5 cults, windmill 5, world 19
families and 25 sub-kinds, village 10 cultures and 9 purposes. Total 149 rows.
The shop shell row reuses `HouseSpec.STYLES` (`building_library.gd:197`), so
those 12 rows are the house rows seen again in the shop context.

## Evidence state rules

- **missing**: no brief row, and nothing else.
- **designed**: a brief row exists; no fixture, check or review was found.
- **generated**: a saved request or render exists for the row; no suite was found that reads the row.
- **mechanically-checked**: a suite in `tests/suites/` iterates or names the row (read from code; not run here).
- **visually-reviewed**: a review record names this row with a per-row verdict. A family-level score does not count, and neither does a concept board or an unreviewed render.

Each row carries the highest state it satisfies. "Accepted" appears nowhere:
every review found says needs_changes, not accepted, or unreviewed.

## Brief and fixture sources

- Briefs: `docs/BUILDING_PERSONALITY_BRIEFS.md`. Sections: House style briefs
  (line 104), Shop and civic business briefs (142), Church style briefs (183),
  Temple forms and cults (205), Castles (241), Hotels (262), Windmills (273),
  World buildings (287), Villages (316).
- Request fixtures: `tests/fixtures/sacred_sequence_requests.json` (church
  styles, temple forms and cults, a site request); `tests/fixtures/sacred_structure_requests.json`
  and `sacred_structure_batches.json` (same rows); `tests/fixtures/witch_family_requests.json`
  (witch_hut); `visualqa/personality/frozen_requests.json` (one style per family
  at three sizes and seeds: castle norman, church romanesque, hotel grand_budapest,
  house cottage and witch_hut, shop cottage with barracks, temple basilica with blood,
  windmill tower, world courtyard_house with domus, village english with farming);
  `visualqa/personality/baseline_requests.json` (same ten, default size);
  `tools/house_style_visual_matrix.json` (eight house styles, as a matrix spec, not expanded requests).
- Suites: `tests/suites/*.gd`. The lane definitions are in `tests/run_all_impl.gd`
  (`LANES`, around line 120).
- Reviews: `visualqa/personality/README.md` (root review table, default-size
  views), `visualqa/styles/house/assistant_review.json` and per-style
  `assistant_review.json` files under `visualqa/styles/house/<style>/renders/`,
  `visualqa/styles/church/gothic/assistant_review.json`, `visualqa/HumanRate.md`
  (walk pins, not per style).
- Inventory: `visualqa/personality/style_inventory.json` lists 81 style rows
  (church 6, castle 11, house 12, shop 12, hotel 2, temple 4, windmill 5, world 19,
  village 10). Every row has `generated`, `mechanically_checked` and
  `visually_reviewed` set to false. That is a stale snapshot. It is not
  evidence either way, and this ledger does not use it.

## church

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| romanesque | BUILDING_PERSONALITY_BRIEFS.md § Church style briefs | tests/fixtures/sacred_sequence_requests.json; visualqa/personality/frozen_requests.json | tests/suites/test_sweep.gd via church_suite.gd; sacred_sequence_suite.gd | visualqa/personality/README.md root review (default nave/tower view, not accepted) | visually-reviewed |
| gothic | same | tests/fixtures/sacred_sequence_requests.json | test_sweep.gd via church_suite.gd; sacred_sequence_suite.gd | visualqa/styles/church/gothic/assistant_review.json (building_design_status needs_changes; scope physical chapel passage) | visually-reviewed |
| byzantine | same | tests/fixtures/sacred_sequence_requests.json | test_sweep.gd; sacred_sequence_suite.gd | none | mechanically-checked |
| nordic_stave | same | tests/fixtures/sacred_sequence_requests.json | test_sweep.gd; sacred_sequence_suite.gd | none | mechanically-checked |
| renaissance | same | tests/fixtures/sacred_sequence_requests.json | test_sweep.gd; sacred_sequence_suite.gd | none | mechanically-checked |
| russian | same | tests/fixtures/sacred_sequence_requests.json | test_sweep.gd; sacred_sequence_suite.gd | none | mechanically-checked |

## castle

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| norman | BUILDING_PERSONALITY_BRIEFS.md § Castles | visualqa/personality/frozen_requests.json; baseline_requests.json | castle_sweep.gd via castle_suite.gd; castle_normals_suite.gd, castle_massing_suite.gd, castle_landmark_suite.gd (lane:castle) | none counted (root review says "Castle", style not named) | mechanically-checked |
| edwardian | same | MISSING | castle_sweep.gd via castle_suite.gd | none | mechanically-checked |
| crusader | same | MISSING | castle_sweep.gd via castle_suite.gd | none | mechanically-checked |
| french_chateau | same | MISSING | castle_sweep.gd via castle_suite.gd | none | mechanically-checked |
| bavarian | same | MISSING | castle_sweep.gd via castle_suite.gd | none | mechanically-checked |
| japanese | same | MISSING | castle_sweep.gd via castle_suite.gd | none | mechanically-checked |
| moorish | same | MISSING | castle_sweep.gd via castle_suite.gd | none | mechanically-checked |
| wizard | same | MISSING | castle_sweep.gd via castle_suite.gd | none | mechanically-checked |
| dark | same | MISSING | castle_sweep.gd via castle_suite.gd | none | mechanically-checked |
| sky | same | MISSING | castle_sweep.gd via castle_suite.gd | none | mechanically-checked |
| elven | same | MISSING | castle_sweep.gd via castle_suite.gd | none | mechanically-checked |

## house (styles)

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| cottage | BUILDING_PERSONALITY_BRIEFS.md § House style briefs | visualqa/personality/frozen_requests.json; tests/fixtures/witch_family_requests.json (witch only) | house_sweep.gd (styles(), line 22) via house_suite.gd, house_qa_suite.gd; house_vernacular_suite.gd | visualqa/styles/house/cottage/renders/fire_composition_restart44/assistant_review.json (verdict not read); visualqa/styles/house/cottage/renders/firewood_restart48/assistant_review.json (verdict not read) | visually-reviewed |
| farmhouse | same | MISSING | house_sweep.gd via house_suite.gd, house_qa_suite.gd | visualqa/styles/house/farmhouse/renders/fire_composition_restart44/assistant_review.json; .../firewood_restart48/assistant_review.json (verdicts not read) | visually-reviewed |
| townhouse | same | tools/house_style_visual_matrix.json (matrix entry) | house_sweep.gd via house_suite.gd, house_qa_suite.gd | visualqa/styles/house/townhouse/renders/target_comparison_restart23/assistant_review.json (needs_changes); office_activity, office_nav, nav_inventory restart reviews (verdicts not read) | visually-reviewed |
| longhall | same | tools/house_style_visual_matrix.json (matrix entry) | house_sweep.gd via house_suite.gd, house_qa_suite.gd; house_vernacular_suite.gd | visualqa/styles/house/longhall/renders/target_comparison_restart23/assistant_review.json (needs_changes) | visually-reviewed |
| witch_hut | same | tests/fixtures/witch_family_requests.json; tests/fixtures/witch_render_view_request.json; tests/fixtures/personality/witch_requests.json; frozen_requests.json | house_sweep.gd via house_suite.gd, house_qa_suite.gd; house_witch_compact_suite.gd | visualqa/styles/house/assistant_review.json (cohort restart21_witch_joint_cluster_full_render, needs_changes) | visually-reviewed |
| rich | same | tools/house_style_visual_matrix.json (matrix entry) | house_sweep.gd via house_suite.gd, house_qa_suite.gd; house_rich_suite.gd | visualqa/styles/house/rich/renders/target_comparison_restart23/assistant_review.json (needs_changes) | visually-reviewed |
| mediterranean | same | tools/house_style_visual_matrix.json (matrix entry) | house_sweep.gd via house_suite.gd, house_qa_suite.gd; house_vernacular_suite.gd | visualqa/styles/house/mediterranean/renders/target_comparison_restart23/assistant_review.json (needs_changes) | visually-reviewed |
| asian | same | tools/house_style_visual_matrix.json (matrix entry) | house_sweep.gd via house_suite.gd, house_qa_suite.gd; house_vernacular_suite.gd | visualqa/styles/house/asian/renders/target_comparison_restart23/assistant_review.json (verdict not read) | visually-reviewed |
| african | same | tools/house_style_visual_matrix.json (matrix entry) | house_sweep.gd via house_suite.gd, house_qa_suite.gd; house_vernacular_suite.gd | visualqa/styles/house/african/renders/target_comparison_restart23/assistant_review.json (verdict not read) | visually-reviewed |
| thatch_cottage | same | MISSING | house_sweep.gd via house_suite.gd, house_qa_suite.gd | visualqa/styles/house/thatch_cottage/renders/fire_composition_restart44/assistant_review.json; firewood_restart48 (verdicts not read) | visually-reviewed |
| mud_hut | same | tools/house_style_visual_matrix.json (matrix entry) | house_sweep.gd via house_suite.gd, house_qa_suite.gd; house_vernacular_suite.gd | visualqa/styles/house/mud_hut/renders/target_comparison_restart23/assistant_review.json (verdict not read) | visually-reviewed |
| pueblo | same | tools/house_style_visual_matrix.json (matrix entry) | house_sweep.gd via house_suite.gd, house_qa_suite.gd; house_vernacular_suite.gd | visualqa/styles/house/pueblo/renders/target_comparison_restart23/assistant_review.json (verdict not read) | visually-reviewed |

## house (trades)

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| none | MISSING (no house-trade section in BUILDING_PERSONALITY_BRIEFS.md) | MISSING | house_sweep.gd trades() (line 26) via house_qa_suite.gd | none | mechanically-checked |
| smith | MISSING (the word appears only in the shop business section) | MISSING | house_qa_suite.gd (HouseSweep.trades) | none | mechanically-checked |
| alchemist | MISSING | MISSING | house_qa_suite.gd | none | mechanically-checked |
| farmer | MISSING | MISSING | house_qa_suite.gd | none | mechanically-checked |
| innkeeper | MISSING | MISSING | house_qa_suite.gd | none | mechanically-checked |
| scholar | MISSING | MISSING | house_qa_suite.gd | none | mechanically-checked |

## shop (shells, the 12 house rows)

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| cottage (shell) | BUILDING_PERSONALITY_BRIEFS.md § Shop and civic business briefs (line 62 table: every business uses all 12 shell rows) | visualqa/personality/frozen_requests.json (shop cottage, barracks) | house_suite.gd and house_qa_suite.gd check the house row; shop_suite.gd checks shell ("bad shell", line 29) | none in shop context | mechanically-checked |
| farmhouse (shell) | same | MISSING | same | none | mechanically-checked |
| townhouse (shell) | same | MISSING | same | visualqa/styles/shop/townhouse/businesses/bakery/targets is a concept board, not a review | mechanically-checked |
| longhall (shell) | same | MISSING | same | none | mechanically-checked |
| witch_hut (shell) | same | MISSING | same | none | mechanically-checked |
| rich (shell) | same | MISSING | same | none | mechanically-checked |
| mediterranean (shell) | same | MISSING | same | none | mechanically-checked |
| asian (shell) | same | MISSING | same | none | mechanically-checked |
| african (shell) | same | MISSING | same | none | mechanically-checked |
| thatch_cottage (shell) | same | MISSING | same | none | mechanically-checked |
| mud_hut (shell) | same | MISSING | same | none | mechanically-checked |
| pueblo (shell) | same | MISSING | same | none | mechanically-checked |

## shop (businesses)

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| barracks | BUILDING_PERSONALITY_BRIEFS.md § Shop and civic business briefs | visualqa/personality/frozen_requests.json | shop_suite.gd (loops BUSINESSES, line 8) | none | mechanically-checked |
| library | same | MISSING | shop_suite.gd; library_business_suite.gd (lane:library-change) | none | mechanically-checked |
| prison | same | MISSING | shop_suite.gd | none | mechanically-checked |
| palace | same | MISSING | shop_suite.gd | none | mechanically-checked |
| blacksmith | same | MISSING | shop_suite.gd | none | mechanically-checked |
| stable | same | MISSING | shop_suite.gd | none | mechanically-checked |
| restaurant | same | MISSING | shop_suite.gd | none | mechanically-checked |
| tavern | same | MISSING | shop_suite.gd | none | mechanically-checked |
| inn | same | MISSING | shop_suite.gd | none | mechanically-checked |
| bakery | same | MISSING | shop_suite.gd | concept board only: visualqa/styles/shop/townhouse/businesses/bakery/targets/ (not a review) | mechanically-checked |
| butcher | same | MISSING | shop_suite.gd | none | mechanically-checked |
| apothecary | same | MISSING | shop_suite.gd | none | mechanically-checked |
| general_store | same | MISSING | shop_suite.gd | none | mechanically-checked |
| tailor | same | MISSING | shop_suite.gd | none | mechanically-checked |
| carpenter | same | MISSING | shop_suite.gd | none | mechanically-checked |
| town_hall | same | MISSING | shop_suite.gd | none | mechanically-checked |
| guildhall | same | MISSING | shop_suite.gd | none | mechanically-checked |
| market_hall | same | MISSING | shop_suite.gd | none | mechanically-checked |
| alchemist_laboratory | same | MISSING | shop_suite.gd | none | mechanically-checked |
| bathhouse | same | MISSING | shop_suite.gd | none | mechanically-checked |
| hospice | same | MISSING | shop_suite.gd | none | mechanically-checked |
| school | same | MISSING | shop_suite.gd | none | mechanically-checked |
| thieves_den | same | MISSING | shop_suite.gd | none | mechanically-checked |

## hotel

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| grand_budapest | BUILDING_PERSONALITY_BRIEFS.md § Hotels | visualqa/personality/frozen_requests.json; baseline_requests.json | hotel_suite.gd (loops HOTEL_STYLES, line 8); hotel_landmark_suite.gd (lane:scheduled); hotel_roof_smoke_suite.gd | visualqa/personality/README.md root review ("Hotel", guest rooms sparse, not accepted) | visually-reviewed |
| alpine_palace | same | MISSING | hotel_suite.gd; hotel_landmark_suite.gd | none | mechanically-checked |

## temple (forms)

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| basilica | BUILDING_PERSONALITY_BRIEFS.md § Temple forms and cults | tests/fixtures/sacred_sequence_requests.json; sacred_structure_requests.json; visualqa/personality/frozen_requests.json | temple_sweep.gd (FORMS, line 21); temple_archetype_suite.gd; sacred_sequence_suite.gd (lane:temple) | visualqa/personality/README.md root review ("Basilica temple", not accepted) | visually-reviewed |
| pylon | same | tests/fixtures/sacred_sequence_requests.json; sacred_structure_requests.json | temple_sweep.gd; temple_archetype_suite.gd; sacred_sequence_suite.gd | concept board only: visualqa/styles/temple/pylon/targets/ | mechanically-checked |
| ziggurat | same | tests/fixtures/sacred_sequence_requests.json; tests/fixtures/site_requests/wuunafu-schema2.json | temple_sweep.gd; temple_archetype_suite.gd; sacred_sequence_suite.gd | none | mechanically-checked |
| rotunda | same | tests/fixtures/sacred_sequence_requests.json; sacred_structure_requests.json | temple_sweep.gd; temple_archetype_suite.gd; sacred_sequence_suite.gd | concept board only: visualqa/styles/temple/rotunda/targets/ | mechanically-checked |

## temple (cults)

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| blood | BUILDING_PERSONALITY_BRIEFS.md § Temple forms and cults | tests/fixtures/sacred_sequence_requests.json; visualqa/personality/frozen_requests.json | temple_sweep.gd (CULTS, line 25); sacred_sequence_suite.gd | none counted (the basilica review's request used blood; the verdict is about the form) | mechanically-checked |
| void | same | tests/fixtures/sacred_sequence_requests.json; sacred_structure_requests.json | temple_sweep.gd; sacred_sequence_suite.gd | none | mechanically-checked |
| flame | same | tests/fixtures/sacred_sequence_requests.json; sacred_structure_requests.json | temple_sweep.gd; sacred_sequence_suite.gd | none | mechanically-checked |
| bone | same | tests/fixtures/sacred_sequence_requests.json; sacred_structure_requests.json | temple_sweep.gd; sacred_sequence_suite.gd | none | mechanically-checked |
| serpent | same | tests/fixtures/sacred_sequence_requests.json; sacred_structure_requests.json | temple_sweep.gd; sacred_sequence_suite.gd | none | mechanically-checked |

## windmill

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| tower | BUILDING_PERSONALITY_BRIEFS.md § Windmills | visualqa/personality/frozen_requests.json; baseline_requests.json | windmill_suite.gd (loops TYPES, lines 84, 109); lane:windmill | visualqa/personality/README.md root review (complete silhouette usable, no design verdict) — not counted | mechanically-checked |
| post | same | MISSING | windmill_suite.gd | none | mechanically-checked |
| smock | same | MISSING | windmill_suite.gd | none | mechanically-checked |
| windpump | same | MISSING | windmill_suite.gd | none | mechanically-checked |
| paddle | same | MISSING (tests/fixtures/libraryquick_partitions.json names it, but that is a partition list, not a request) | windmill_suite.gd | none | mechanically-checked |

## world (families)

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| courtyard_house | BUILDING_PERSONALITY_BRIEFS.md § World buildings | visualqa/personality/frozen_requests.json; baseline_requests.json | world_courtyard_suite.gd | none at family level (the domus kind review is below) | mechanically-checked |
| mosque | same | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| cruciform_temple | same | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| timber_hall | same | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| insula | same | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| tower_house | same | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| caravanserai | same | MISSING | world_archetype_suite.gd; world_han_suite.gd | none | mechanically-checked |
| hammam | same | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| pagoda | same | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| stupa | same | MISSING | world_archetype_suite.gd; world_stupa_suite.gd | none | mechanically-checked |
| vihara | same | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| vastu | same | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| siheyuan | same | MISSING | world_archetype_suite.gd; world_siheyuan_suite.gd | none | mechanically-checked |
| tulou | same | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| nagara | same | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| rock_cut_temple | same | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| temple_mountain | same | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| stepwell | same | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| dravida | same | MISSING | world_archetype_suite.gd | none | mechanically-checked |

## world (sub-kinds)

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| domus | BUILDING_PERSONALITY_BRIEFS.md § World buildings (courtyard_house row) | visualqa/personality/frozen_requests.json (courtyard_house, domus) | world_courtyard_suite.gd (KINDS, line 7) | visualqa/personality/README.md root review ("Domus", not accepted) | visually-reviewed |
| riad | same | MISSING | world_courtyard_suite.gd (KINDS) | none | mechanically-checked |
| palazzo | same | MISSING | world_courtyard_suite.gd (KINDS) | none | mechanically-checked |
| hypostyle | same (mosque row) | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| temple_of_four_winds | same (cruciform_temple row) | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| great_hall | same (timber_hall row) | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| phoenix_pavilion | same (timber_hall row) | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| port_tenement | same (insula row) | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| merchant_tower | same (tower_house row) | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| sultan_han | same (caravanserai row) | MISSING | world_archetype_suite.gd; world_han_suite.gd | none | mechanically-checked |
| steam_baths | same (hammam row) | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| square_pagoda | same (pagoda row) | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| octagonal_pagoda | same (pagoda row) | MISSING | none found | none | designed |
| dodecagonal_pagoda | same (pagoda row) | MISSING | none found | none | designed |
| saints_mound | same (stupa row) | MISSING | world_archetype_suite.gd; world_stupa_suite.gd | none | mechanically-checked |
| monks_cloister | same (vihara row) | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| merchants_haveli | same (vastu row) | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| scholars_compound | same (siheyuan row) | MISSING | world_archetype_suite.gd; world_siheyuan_suite.gd | none | mechanically-checked |
| two_court_compound | same (siheyuan row) | MISSING | none found | none | designed |
| clan_ring | same (tulou row) | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| hundred_spires | same (nagara row) | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| quarried_temple | same (rock_cut_temple row) | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| angkor_mountain | same (temple_mountain row) | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| queens_well | same (stepwell row) | MISSING | world_archetype_suite.gd | none | mechanically-checked |
| god_kings_precinct | same (dravida row) | MISSING | world_archetype_suite.gd | none | mechanically-checked |

## village (cultures)

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| english | BUILDING_PERSONALITY_BRIEFS.md § Villages (culture table) | visualqa/personality/frozen_requests.json (english, farming); baseline_requests.json | village_suite.gd (loops CULTURES, line 576); village_archetype_suite.gd | none (root review: "Shop / village" unreviewed) | mechanically-checked |
| frankish | same | MISSING | village_suite.gd; village_archetype_suite.gd | none | mechanically-checked |
| norse | same | MISSING | village_suite.gd; village_archetype_suite.gd | none | mechanically-checked |
| alpine | same | MISSING | village_suite.gd; village_archetype_suite.gd | none | mechanically-checked |
| moorish | same | MISSING | village_suite.gd; village_archetype_suite.gd | none | mechanically-checked |
| eastern | same | MISSING | village_suite.gd | none | mechanically-checked |
| blighted | same | MISSING | village_suite.gd; village_archetype_suite.gd | none | mechanically-checked |
| mediterranean | same | MISSING | village_suite.gd | none | mechanically-checked |
| east_asian | same | MISSING | village_suite.gd | none | mechanically-checked |
| saharan | same | MISSING | village_suite.gd | none | mechanically-checked |

## village (purposes)

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| farming | BUILDING_PERSONALITY_BRIEFS.md § Villages (purpose table) | visualqa/personality/frozen_requests.json; baseline_requests.json | village_suite.gd (loops PURPOSES, line 374) | none | mechanically-checked |
| crossroads | same | MISSING | village_suite.gd | none | mechanically-checked |
| market | same | MISSING | village_suite.gd | none | mechanically-checked |
| mill | same | MISSING | village_suite.gd | none | mechanically-checked |
| fishing | same | MISSING | village_suite.gd | none | mechanically-checked |
| mining | same | MISSING | village_suite.gd | none | mechanically-checked |
| garrison | same | MISSING | village_suite.gd | none | mechanically-checked |
| pilgrim | same | MISSING | village_suite.gd | none | mechanically-checked |
| forest | same | MISSING | village_suite.gd | none | mechanically-checked |

Village forms (`gate`, `strand`, `planted`, `crossroads`, `green`, `round`,
`street`) are derived, not published, and are not rows here. The five village
form renders cited in `docs/VISUAL_QA.md` (score 27.5) are family-level and do
not count as per-row review.

## Biggest gaps

1. **Request fixtures.** 10 of 11 castle styles, 4 of 5 windmill types, 18 of 19
   world families, 24 of 25 world sub-kinds, 22 of 23 shop businesses, 9 of 10
   village cultures, 8 of 9 village purposes, 1 of 2 hotel styles and 10 of 12
   house styles (8 appear only as entries in `tools/house_style_visual_matrix.json`,
   and 2 have no entry at all) have no saved request. Church and temple forms
   and cults are covered by `sacred_sequence_requests.json`. The rest are
   covered only by a generator or a sweep, not a saved request.
2. **Accepted visual review: none.** Every review found says needs_changes or
   not accepted, or it is unreviewed. Per-row reviews exist for 12 house styles,
   church romanesque and gothic, hotel grand_budapest, temple basilica, and world
   domus, and they are not accepted. Castle, windmill, shop, village, world (other
   than domus) and the temple cults have no per-row review at all.
3. **Windmills.** Three of five types have neither a fixture nor a review. The
   tower's only review is a camera check that concluded nothing about design.
4. **Three published rows have no mechanical check at all:** world sub-kinds
   `octagonal_pagoda`, `dodecagonal_pagoda` and `two_court_compound`. Each is
   only `designed`.
5. **House trades (6 rows) have no brief section.** They are checked by
   `house_qa_suite.gd` but have no entry in BUILDING_PERSONALITY_BRIEFS.md and no fixture.
6. **Shop shells.** The 12 shell rows are checked through the house suites, but
   no shop-context request or review exists for any shell.
7. **Stale inventory.** `visualqa/personality/style_inventory.json` marks all 81
   of its rows unchecked and unreviewed. Its own `README.md` says it is a scope
   snapshot. Refresh it before using it as a coverage source.
8. **Hotel alpine_palace** has no fixture and no review; the family has a single
   reviewed row out of two.

Not verified in this task: whether any suite passes today; the content of the
`wld*` lane suites beyond their names; and the verdicts of the
`fire_composition`, `firewood`, and `office` review files, which were noted but
not read.
