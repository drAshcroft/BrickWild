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
- Request fixtures: `tests/fixtures/family_style_requests.json` (106 frozen
  requests, seed 8102, added 2026-10-14; run by `tools/generate_family_requests.gd`,
  not a lane); `tests/fixtures/sacred_sequence_requests.json` (church
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
| edwardian | same | tests/fixtures/family_style_requests.json (castle/edwardian/8102) | castle_sweep.gd via castle_suite.gd | none | mechanically-checked |
| crusader | same | tests/fixtures/family_style_requests.json (castle/crusader/8102) | castle_sweep.gd via castle_suite.gd | none | mechanically-checked |
| french_chateau | same | tests/fixtures/family_style_requests.json (castle/french_chateau/8102) | castle_sweep.gd via castle_suite.gd | none | mechanically-checked |
| bavarian | same | tests/fixtures/family_style_requests.json (castle/bavarian/8102) | castle_sweep.gd via castle_suite.gd | none | mechanically-checked |
| japanese | same | tests/fixtures/family_style_requests.json (castle/japanese/8102) | castle_sweep.gd via castle_suite.gd | none | mechanically-checked |
| moorish | same | tests/fixtures/family_style_requests.json (castle/moorish/8102) | castle_sweep.gd via castle_suite.gd | none | mechanically-checked |
| wizard | same | tests/fixtures/family_style_requests.json (castle/wizard/8102) | castle_sweep.gd via castle_suite.gd | none | mechanically-checked |
| dark | same | tests/fixtures/family_style_requests.json (castle/dark/8102) | castle_sweep.gd via castle_suite.gd | none | mechanically-checked |
| sky | same | tests/fixtures/family_style_requests.json (castle/sky/8102) | castle_sweep.gd via castle_suite.gd | none | mechanically-checked |
| elven | same | tests/fixtures/family_style_requests.json (castle/elven/8102) | castle_sweep.gd via castle_suite.gd | none | mechanically-checked |

## house (styles)

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| cottage | BUILDING_PERSONALITY_BRIEFS.md § House style briefs | visualqa/personality/frozen_requests.json; tests/fixtures/witch_family_requests.json (witch only) | house_sweep.gd (styles(), line 22) via house_suite.gd, house_qa_suite.gd; house_vernacular_suite.gd | visualqa/styles/house/cottage/renders/fire_composition_restart44/assistant_review.json (verdict not read); visualqa/styles/house/cottage/renders/firewood_restart48/assistant_review.json (verdict not read) | visually-reviewed |
| farmhouse | same | tests/fixtures/family_style_requests.json (house/farmhouse/8102) | house_sweep.gd via house_suite.gd, house_qa_suite.gd | visualqa/styles/house/farmhouse/renders/fire_composition_restart44/assistant_review.json; .../firewood_restart48/assistant_review.json (verdicts not read) | visually-reviewed |
| townhouse | same | tools/house_style_visual_matrix.json (matrix entry); tests/fixtures/family_style_requests.json (house/townhouse/8102) | house_sweep.gd via house_suite.gd, house_qa_suite.gd | visualqa/styles/house/townhouse/renders/target_comparison_restart23/assistant_review.json (needs_changes); office_activity, office_nav, nav_inventory restart reviews (verdicts not read) | visually-reviewed |
| longhall | same | tools/house_style_visual_matrix.json (matrix entry); tests/fixtures/family_style_requests.json (house/longhall/8102) | house_sweep.gd via house_suite.gd, house_qa_suite.gd; house_vernacular_suite.gd | visualqa/styles/house/longhall/renders/target_comparison_restart23/assistant_review.json (needs_changes) | visually-reviewed |
| witch_hut | same | tests/fixtures/witch_family_requests.json; tests/fixtures/witch_render_view_request.json; tests/fixtures/personality/witch_requests.json; frozen_requests.json | house_sweep.gd via house_suite.gd, house_qa_suite.gd; house_witch_compact_suite.gd | visualqa/styles/house/assistant_review.json (cohort restart21_witch_joint_cluster_full_render, needs_changes) | visually-reviewed |
| rich | same | tools/house_style_visual_matrix.json (matrix entry); tests/fixtures/family_style_requests.json (house/rich/8102) | house_sweep.gd via house_suite.gd, house_qa_suite.gd; house_rich_suite.gd | visualqa/styles/house/rich/renders/target_comparison_restart23/assistant_review.json (needs_changes) | visually-reviewed |
| mediterranean | same | tools/house_style_visual_matrix.json (matrix entry); tests/fixtures/family_style_requests.json (house/mediterranean/8102) | house_sweep.gd via house_suite.gd, house_qa_suite.gd; house_vernacular_suite.gd | visualqa/styles/house/mediterranean/renders/target_comparison_restart23/assistant_review.json (needs_changes) | visually-reviewed |
| asian | same | tools/house_style_visual_matrix.json (matrix entry); tests/fixtures/family_style_requests.json (house/asian/8102) | house_sweep.gd via house_suite.gd, house_qa_suite.gd; house_vernacular_suite.gd | visualqa/styles/house/asian/renders/target_comparison_restart23/assistant_review.json (verdict not read) | visually-reviewed |
| african | same | tools/house_style_visual_matrix.json (matrix entry); tests/fixtures/family_style_requests.json (house/african/8102) | house_sweep.gd via house_suite.gd, house_qa_suite.gd; house_vernacular_suite.gd | visualqa/styles/house/african/renders/target_comparison_restart23/assistant_review.json (verdict not read) | visually-reviewed |
| thatch_cottage | same | tests/fixtures/family_style_requests.json (house/thatch_cottage/8102) | house_sweep.gd via house_suite.gd, house_qa_suite.gd | visualqa/styles/house/thatch_cottage/renders/fire_composition_restart44/assistant_review.json; firewood_restart48 (verdicts not read) | visually-reviewed |
| mud_hut | same | tools/house_style_visual_matrix.json (matrix entry); tests/fixtures/family_style_requests.json (house/mud_hut/8102) | house_sweep.gd via house_suite.gd, house_qa_suite.gd; house_vernacular_suite.gd | visualqa/styles/house/mud_hut/renders/target_comparison_restart23/assistant_review.json (verdict not read) | visually-reviewed |
| pueblo | same | tools/house_style_visual_matrix.json (matrix entry); tests/fixtures/family_style_requests.json (house/pueblo/8102) | house_sweep.gd via house_suite.gd, house_qa_suite.gd; house_vernacular_suite.gd | visualqa/styles/house/pueblo/renders/target_comparison_restart23/assistant_review.json (verdict not read) | visually-reviewed |

## house (trades)

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| none | MISSING (no house-trade section in BUILDING_PERSONALITY_BRIEFS.md) | tests/fixtures/family_style_requests.json (house_trade/none/8102) | house_sweep.gd trades() (line 26) via house_qa_suite.gd | none | mechanically-checked |
| smith | MISSING (the word appears only in the shop business section) | tests/fixtures/family_style_requests.json (house_trade/smith/8102) | house_qa_suite.gd (HouseSweep.trades) | none | mechanically-checked |
| alchemist | MISSING | tests/fixtures/family_style_requests.json (house_trade/alchemist/8102) | house_qa_suite.gd | none | mechanically-checked |
| farmer | MISSING | tests/fixtures/family_style_requests.json (house_trade/farmer/8102) | house_qa_suite.gd | none | mechanically-checked |
| innkeeper | MISSING | tests/fixtures/family_style_requests.json (house_trade/innkeeper/8102) | house_qa_suite.gd | none | mechanically-checked |
| scholar | MISSING | tests/fixtures/family_style_requests.json (house_trade/scholar/8102) | house_qa_suite.gd | none | mechanically-checked |

## shop (shells, the 12 house rows)

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| cottage (shell) | BUILDING_PERSONALITY_BRIEFS.md § Shop and civic business briefs (line 62 table: every business uses all 12 shell rows) | visualqa/personality/frozen_requests.json (shop cottage, barracks); tests/fixtures/family_style_requests.json (shop_shell/cottage/8102) | house_suite.gd and house_qa_suite.gd check the house row; shop_suite.gd checks shell ("bad shell", line 29) | none in shop context | mechanically-checked |
| farmhouse (shell) | same | tests/fixtures/family_style_requests.json (shop_shell/farmhouse/8102) | same | none | mechanically-checked |
| townhouse (shell) | same | tests/fixtures/family_style_requests.json (shop_shell/townhouse/8102) | same | visualqa/styles/shop/townhouse/businesses/bakery/targets is a concept board, not a review | mechanically-checked |
| longhall (shell) | same | tests/fixtures/family_style_requests.json (shop_shell/longhall/8102) | same | none | mechanically-checked |
| witch_hut (shell) | same | tests/fixtures/family_style_requests.json (shop_shell/witch_hut/8102) | same | none | mechanically-checked |
| rich (shell) | same | tests/fixtures/family_style_requests.json (shop_shell/rich/8102) | same | none | mechanically-checked |
| mediterranean (shell) | same | tests/fixtures/family_style_requests.json (shop_shell/mediterranean/8102) | same | none | mechanically-checked |
| asian (shell) | same | tests/fixtures/family_style_requests.json (shop_shell/asian/8102) | same | none | mechanically-checked |
| african (shell) | same | tests/fixtures/family_style_requests.json (shop_shell/african/8102) | same | none | mechanically-checked |
| thatch_cottage (shell) | same | tests/fixtures/family_style_requests.json (shop_shell/thatch_cottage/8102) | same | none | mechanically-checked |
| mud_hut (shell) | same | tests/fixtures/family_style_requests.json (shop_shell/mud_hut/8102) | same | none | mechanically-checked |
| pueblo (shell) | same | tests/fixtures/family_style_requests.json (shop_shell/pueblo/8102) | same | none | mechanically-checked |

## shop (businesses)

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| barracks | BUILDING_PERSONALITY_BRIEFS.md § Shop and civic business briefs | visualqa/personality/frozen_requests.json | shop_suite.gd (loops BUSINESSES, line 8) | none | mechanically-checked |
| library | same | tests/fixtures/family_style_requests.json (shop/library/8102) | shop_suite.gd; library_business_suite.gd (lane:library-change) | none | mechanically-checked |
| prison | same | tests/fixtures/family_style_requests.json (shop/prison/8102) | shop_suite.gd | none | mechanically-checked |
| palace | same | tests/fixtures/family_style_requests.json (shop/palace/8102) | shop_suite.gd | none | mechanically-checked |
| blacksmith | same | tests/fixtures/family_style_requests.json (shop/blacksmith/8102) | shop_suite.gd | none | mechanically-checked |
| stable | same | tests/fixtures/family_style_requests.json (shop/stable/8102) | shop_suite.gd | none | mechanically-checked |
| restaurant | same | tests/fixtures/family_style_requests.json (shop/restaurant/8102) | shop_suite.gd | none | mechanically-checked |
| tavern | same | tests/fixtures/family_style_requests.json (shop/tavern/8102) | shop_suite.gd | none | mechanically-checked |
| inn | same | tests/fixtures/family_style_requests.json (shop/inn/8102) | shop_suite.gd | none | mechanically-checked |
| bakery | same | tests/fixtures/family_style_requests.json (shop/bakery/8102) | shop_suite.gd | concept board only: visualqa/styles/shop/townhouse/businesses/bakery/targets/ (not a review) | mechanically-checked |
| butcher | same | tests/fixtures/family_style_requests.json (shop/butcher/8102) | shop_suite.gd | none | mechanically-checked |
| apothecary | same | tests/fixtures/family_style_requests.json (shop/apothecary/8102) | shop_suite.gd | none | mechanically-checked |
| general_store | same | tests/fixtures/family_style_requests.json (shop/general_store/8102) | shop_suite.gd | none | mechanically-checked |
| tailor | same | tests/fixtures/family_style_requests.json (shop/tailor/8102) | shop_suite.gd | none | mechanically-checked |
| carpenter | same | tests/fixtures/family_style_requests.json (shop/carpenter/8102) | shop_suite.gd | none | mechanically-checked |
| town_hall | same | tests/fixtures/family_style_requests.json (shop/town_hall/8102) | shop_suite.gd | none | mechanically-checked |
| guildhall | same | tests/fixtures/family_style_requests.json (shop/guildhall/8102) | shop_suite.gd | none | mechanically-checked |
| market_hall | same | tests/fixtures/family_style_requests.json (shop/market_hall/8102) | shop_suite.gd | none | mechanically-checked |
| alchemist_laboratory | same | tests/fixtures/family_style_requests.json (shop/alchemist_laboratory/8102) | shop_suite.gd | none | mechanically-checked |
| bathhouse | same | tests/fixtures/family_style_requests.json (shop/bathhouse/8102) | shop_suite.gd | none | mechanically-checked |
| hospice | same | tests/fixtures/family_style_requests.json (shop/hospice/8102) | shop_suite.gd | none | mechanically-checked |
| school | same | tests/fixtures/family_style_requests.json (shop/school/8102) | shop_suite.gd | none | mechanically-checked |
| thieves_den | same | tests/fixtures/family_style_requests.json (shop/thieves_den/8102) | shop_suite.gd | none | mechanically-checked |

## hotel

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| grand_budapest | BUILDING_PERSONALITY_BRIEFS.md § Hotels | visualqa/personality/frozen_requests.json; baseline_requests.json | hotel_suite.gd (loops HOTEL_STYLES, line 8); hotel_landmark_suite.gd (lane:scheduled); hotel_roof_smoke_suite.gd | visualqa/personality/README.md root review ("Hotel", guest rooms sparse, not accepted) | visually-reviewed |
| alpine_palace | same | tests/fixtures/family_style_requests.json (hotel/alpine_palace/8102) | hotel_suite.gd; hotel_landmark_suite.gd | none | mechanically-checked |

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
| post | same | tests/fixtures/family_style_requests.json (windmill/post/8102) | windmill_suite.gd | none | mechanically-checked |
| smock | same | tests/fixtures/family_style_requests.json (windmill/smock/8102) | windmill_suite.gd | none | mechanically-checked |
| windpump | same | tests/fixtures/family_style_requests.json (windmill/windpump/8102) | windmill_suite.gd | none | mechanically-checked |
| paddle | same | tests/fixtures/family_style_requests.json (windmill/paddle/8102) | windmill_suite.gd | none | mechanically-checked |

## world (families)

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| courtyard_house | BUILDING_PERSONALITY_BRIEFS.md § World buildings | visualqa/personality/frozen_requests.json; baseline_requests.json; tests/fixtures/family_style_requests.json (world/courtyard_house/riad/8102, world/courtyard_house/palazzo/8102) | world_courtyard_suite.gd | none at family level (the domus kind review is below) | mechanically-checked |
| mosque | same | tests/fixtures/family_style_requests.json (world/mosque/hypostyle/8102) | world_archetype_suite.gd | none | mechanically-checked |
| cruciform_temple | same | tests/fixtures/family_style_requests.json (world/cruciform_temple/temple_of_four_winds/8102) | world_archetype_suite.gd | none | mechanically-checked |
| timber_hall | same | tests/fixtures/family_style_requests.json (world/timber_hall/great_hall/8102, world/timber_hall/phoenix_pavilion/8102) | world_archetype_suite.gd | none | mechanically-checked |
| insula | same | tests/fixtures/family_style_requests.json (world/insula/port_tenement/8102) | world_archetype_suite.gd | none | mechanically-checked |
| tower_house | same | tests/fixtures/family_style_requests.json (world/tower_house/merchant_tower/8102) | world_archetype_suite.gd | none | mechanically-checked |
| caravanserai | same | tests/fixtures/family_style_requests.json (world/caravanserai/sultan_han/8102) | world_archetype_suite.gd; world_han_suite.gd | none | mechanically-checked |
| hammam | same | tests/fixtures/family_style_requests.json (world/hammam/steam_baths/8102) | world_archetype_suite.gd | none | mechanically-checked |
| pagoda | same | tests/fixtures/family_style_requests.json (world/pagoda/square_pagoda/8102, world/pagoda/octagonal_pagoda/8102, world/pagoda/dodecagonal_pagoda/8102) | world_archetype_suite.gd | none | mechanically-checked |
| stupa | same | tests/fixtures/family_style_requests.json (world/stupa/saints_mound/8102) | world_archetype_suite.gd; world_stupa_suite.gd | none | mechanically-checked |
| vihara | same | tests/fixtures/family_style_requests.json (world/vihara/monks_cloister/8102) | world_archetype_suite.gd | none | mechanically-checked |
| vastu | same | tests/fixtures/family_style_requests.json (world/vastu/merchants_haveli/8102) | world_archetype_suite.gd | none | mechanically-checked |
| siheyuan | same | tests/fixtures/family_style_requests.json (world/siheyuan/scholars_compound/8102, world/siheyuan/two_court_compound/8102) | world_archetype_suite.gd; world_siheyuan_suite.gd | none | mechanically-checked |
| tulou | same | tests/fixtures/family_style_requests.json (world/tulou/clan_ring/8102) | world_archetype_suite.gd | none | mechanically-checked |
| nagara | same | tests/fixtures/family_style_requests.json (world/nagara/hundred_spires/8102) | world_archetype_suite.gd | none | mechanically-checked |
| rock_cut_temple | same | tests/fixtures/family_style_requests.json (world/rock_cut_temple/quarried_temple/8102) | world_archetype_suite.gd | none | mechanically-checked |
| temple_mountain | same | tests/fixtures/family_style_requests.json (world/temple_mountain/angkor_mountain/8102) | world_archetype_suite.gd | none | mechanically-checked |
| stepwell | same | tests/fixtures/family_style_requests.json (world/stepwell/queens_well/8102) | world_archetype_suite.gd | none | mechanically-checked |
| dravida | same | tests/fixtures/family_style_requests.json (world/dravida/god_kings_precinct/8102) | world_archetype_suite.gd | none | mechanically-checked |

## world (sub-kinds)

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| domus | BUILDING_PERSONALITY_BRIEFS.md § World buildings (courtyard_house row) | visualqa/personality/frozen_requests.json (courtyard_house, domus) | world_courtyard_suite.gd (KINDS, line 7) | visualqa/personality/README.md root review ("Domus", not accepted) | visually-reviewed |
| riad | same | tests/fixtures/family_style_requests.json (world/courtyard_house/riad/8102) | world_courtyard_suite.gd (KINDS) | none | mechanically-checked |
| palazzo | same | tests/fixtures/family_style_requests.json (world/courtyard_house/palazzo/8102) | world_courtyard_suite.gd (KINDS) | none | mechanically-checked |
| hypostyle | same (mosque row) | tests/fixtures/family_style_requests.json (world/mosque/hypostyle/8102) | world_archetype_suite.gd | none | mechanically-checked |
| temple_of_four_winds | same (cruciform_temple row) | tests/fixtures/family_style_requests.json (world/cruciform_temple/temple_of_four_winds/8102) | world_archetype_suite.gd | none | mechanically-checked |
| great_hall | same (timber_hall row) | tests/fixtures/family_style_requests.json (world/timber_hall/great_hall/8102) | world_archetype_suite.gd | none | mechanically-checked |
| phoenix_pavilion | same (timber_hall row) | tests/fixtures/family_style_requests.json (world/timber_hall/phoenix_pavilion/8102) | world_archetype_suite.gd | none | mechanically-checked |
| port_tenement | same (insula row) | tests/fixtures/family_style_requests.json (world/insula/port_tenement/8102) | world_archetype_suite.gd | none | mechanically-checked |
| merchant_tower | same (tower_house row) | tests/fixtures/family_style_requests.json (world/tower_house/merchant_tower/8102) | world_archetype_suite.gd | none | mechanically-checked |
| sultan_han | same (caravanserai row) | tests/fixtures/family_style_requests.json (world/caravanserai/sultan_han/8102) | world_archetype_suite.gd; world_han_suite.gd | none | mechanically-checked |
| steam_baths | same (hammam row) | tests/fixtures/family_style_requests.json (world/hammam/steam_baths/8102) | world_archetype_suite.gd | none | mechanically-checked |
| square_pagoda | same (pagoda row) | tests/fixtures/family_style_requests.json (world/pagoda/square_pagoda/8102) | world_archetype_suite.gd | none | mechanically-checked |
| octagonal_pagoda | same (pagoda row) | tests/fixtures/family_style_requests.json (world/pagoda/octagonal_pagoda/8102) | world_unchecked_subkinds_suite.gd (`wunchecked`, lane:world, 2026-10-14) | none | mechanically-checked |
| dodecagonal_pagoda | same (pagoda row) | tests/fixtures/family_style_requests.json (world/pagoda/dodecagonal_pagoda/8102) | world_unchecked_subkinds_suite.gd (`wunchecked`, lane:world, 2026-10-14) | none | mechanically-checked |
| saints_mound | same (stupa row) | tests/fixtures/family_style_requests.json (world/stupa/saints_mound/8102) | world_archetype_suite.gd; world_stupa_suite.gd | none | mechanically-checked |
| monks_cloister | same (vihara row) | tests/fixtures/family_style_requests.json (world/vihara/monks_cloister/8102) | world_archetype_suite.gd | none | mechanically-checked |
| merchants_haveli | same (vastu row) | tests/fixtures/family_style_requests.json (world/vastu/merchants_haveli/8102) | world_archetype_suite.gd | none | mechanically-checked |
| scholars_compound | same (siheyuan row) | tests/fixtures/family_style_requests.json (world/siheyuan/scholars_compound/8102) | world_archetype_suite.gd; world_siheyuan_suite.gd | none | mechanically-checked |
| two_court_compound | same (siheyuan row) | tests/fixtures/family_style_requests.json (world/siheyuan/two_court_compound/8102) | world_unchecked_subkinds_suite.gd (`wunchecked`, lane:world, 2026-10-14) | none | mechanically-checked |
| clan_ring | same (tulou row) | tests/fixtures/family_style_requests.json (world/tulou/clan_ring/8102) | world_archetype_suite.gd | none | mechanically-checked |
| hundred_spires | same (nagara row) | tests/fixtures/family_style_requests.json (world/nagara/hundred_spires/8102) | world_archetype_suite.gd | none | mechanically-checked |
| quarried_temple | same (rock_cut_temple row) | tests/fixtures/family_style_requests.json (world/rock_cut_temple/quarried_temple/8102) | world_archetype_suite.gd | none | mechanically-checked |
| angkor_mountain | same (temple_mountain row) | tests/fixtures/family_style_requests.json (world/temple_mountain/angkor_mountain/8102) | world_archetype_suite.gd | none | mechanically-checked |
| queens_well | same (stepwell row) | tests/fixtures/family_style_requests.json (world/stepwell/queens_well/8102) | world_archetype_suite.gd | none | mechanically-checked |
| god_kings_precinct | same (dravida row) | tests/fixtures/family_style_requests.json (world/dravida/god_kings_precinct/8102) | world_archetype_suite.gd | none | mechanically-checked |

## village (cultures)

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| english | BUILDING_PERSONALITY_BRIEFS.md § Villages (culture table) | visualqa/personality/frozen_requests.json (english, farming); baseline_requests.json | village_suite.gd (loops CULTURES, line 576); village_archetype_suite.gd | none (root review: "Shop / village" unreviewed) | mechanically-checked |
| frankish | same | tests/fixtures/family_style_requests.json (village_culture/frankish/8102) | village_suite.gd; village_archetype_suite.gd | none | mechanically-checked |
| norse | same | tests/fixtures/family_style_requests.json (village_culture/norse/8102) | village_suite.gd; village_archetype_suite.gd | none | mechanically-checked |
| alpine | same | tests/fixtures/family_style_requests.json (village_culture/alpine/8102) | village_suite.gd; village_archetype_suite.gd | none | mechanically-checked |
| moorish | same | tests/fixtures/family_style_requests.json (village_culture/moorish/8102) | village_suite.gd; village_archetype_suite.gd | none | mechanically-checked |
| eastern | same | tests/fixtures/family_style_requests.json (village_culture/eastern/8102) | village_suite.gd | none | mechanically-checked |
| blighted | same | tests/fixtures/family_style_requests.json (village_culture/blighted/8102) | village_suite.gd; village_archetype_suite.gd | none | mechanically-checked |
| mediterranean | same | tests/fixtures/family_style_requests.json (village_culture/mediterranean/8102) | village_suite.gd | none | mechanically-checked |
| east_asian | same | tests/fixtures/family_style_requests.json (village_culture/east_asian/8102) | village_suite.gd | none | mechanically-checked |
| saharan | same | tests/fixtures/family_style_requests.json (village_culture/saharan/8102) | village_suite.gd | none | mechanically-checked |

## village (purposes)

| row | brief | request fixture | mechanical checks | visual review | evidence state |
|---|---|---|---|---|---|
| farming | BUILDING_PERSONALITY_BRIEFS.md § Villages (purpose table) | visualqa/personality/frozen_requests.json; baseline_requests.json | village_suite.gd (loops PURPOSES, line 374) | none | mechanically-checked |
| crossroads | same | tests/fixtures/family_style_requests.json (village_purpose/crossroads/8102) | village_suite.gd | none | mechanically-checked |
| market | same | tests/fixtures/family_style_requests.json (village_purpose/market/8102) | village_suite.gd | none | mechanically-checked |
| mill | same | tests/fixtures/family_style_requests.json (village_purpose/mill/8102) | village_suite.gd | none | mechanically-checked |
| fishing | same | tests/fixtures/family_style_requests.json (village_purpose/fishing/8102) | village_suite.gd | none | mechanically-checked |
| mining | same | tests/fixtures/family_style_requests.json (village_purpose/mining/8102) | village_suite.gd | none | mechanically-checked |
| garrison | same | tests/fixtures/family_style_requests.json (village_purpose/garrison/8102) | village_suite.gd | none | mechanically-checked |
| pilgrim | same | tests/fixtures/family_style_requests.json (village_purpose/pilgrim/8102) | village_suite.gd | none | mechanically-checked |
| forest | same | tests/fixtures/family_style_requests.json (village_purpose/forest/8102) | village_suite.gd | none | mechanically-checked |

Village forms (`gate`, `strand`, `planted`, `crossroads`, `green`, `round`,
`street`) are derived, not published, and are not rows here. The five village
form renders cited in `docs/VISUAL_QA.md` (score 27.5) are family-level and do
not count as per-row review.

## Generation findings (2026-10-14)

`tools/generate_family_requests.gd` generated all 106 requests in
`tests/fixtures/family_style_requests.json` through `BrickWild.generate`,
`build_mesh` and `placement` (seed 8102, default envelope; world sub-kinds use
the `WorldArchetypeSuite` size, or the family's own for the three new rows).
Result: 106 generated, 0 failed (`artifacts/family_requests_20261014/result.json`,
not committed). The request-fixture column above now names each row's id.
A row that was already `mechanically-checked` or `visually-reviewed` keeps
that state. "Generated" is the floor, and nothing here is a visual review.

Findings that are not failures:

- `shop/palace` generates but `ShopPlanner.place_palace_banners`
  (`src/shop/shop_planner.gd:191`) calls `push_error("palace cannot find a
  mirrored banner station")` at seed 8102 and returns, so that palace has no
  banners. Open; not fixed (a planner placement rule, not a small bug).
- Wall time is dominated by three families: castles 30 to 45 s each, villages
  45 to 67 s each, hotel alpine_palace 167 s (host under load). Houses, shops
  and trades take 1 to 7 s; world sub-kinds are under 1 s except
  `merchant_tower` (15 s); windmills under 1 s.
- A `world` request's `style` is the family and `purpose` the sub-kind; the
  fixture ids read `world/<family>/<kind>/<seed>`.

## Biggest gaps

1. **Request fixtures.** Closed 2026-10-14 for every row below by
   `tests/fixtures/family_style_requests.json`. As found: 10 of 11 castle styles, 4 of 5 windmill types, 18 of 19
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
4. **Three published rows had no mechanical check:** world sub-kinds
   `octagonal_pagoda`, `dodecagonal_pagoda` and `two_court_compound`. Closed
   2026-10-14 by `tests/suites/world_unchecked_subkinds_suite.gd` (`wunchecked`,
   in lane:world): generate, non-empty mesh, inside the family envelope,
   deterministic twice. PASS, 3 checks. It is a smoke check, not the
   archetype `must` list the other sub-kinds carry.
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
