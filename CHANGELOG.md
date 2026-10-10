# Changelog

This file records public releases. A release is frozen and verified by
`tools/release_brick_wild.ps1` into `releases/brick_wild-<version>/`; other
projects consume that, never this working tree (`docs/RELEASES.md`).
`BrickWild.API_VERSION` is a separate compatibility number; see `README.md`
and `docs/PUBLIC_API_TRANSPORT.md`.

## Unreleased

Nothing yet.

## 0.1.2 - 2026-10-10

A village says where a person can walk, and a house says how to get upstairs.
Tag `v0.1.2`.

### Notable changes

- **The SitePlan's `walk` key** (schema `brickwild.walk` v1), written by
  `tools/export_village_plan.gd` for every plan: the ground `VillageNavCheck`
  judges, in the site frame. `floor[]` and `obstacles[]` outlines (roads with
  verges, commons, lots, courts, crossings; building bounds, yards, water,
  wall runs, blocking props, trunks), a `navmesh` of convex polygons eroded by
  the 0.24 m person radius, `gates[]`, `doors[]` (one per building: door,
  `outside_m` on the mesh, `inside_m`, `level`, the check's `reachable`) and
  `furniture[]` (every prop with a use zone: well, stalls, benches, with a
  `use_m` on the mesh). A navigation mesh rather than a grid: it loads into
  Godot as it is (`[x, z]` is `Vector3(x, 0, z)`). See docs/VILLAGES.md 10b.
- **`BrickWild.navigation(building)` and `BrickWild.navigation_node(building)`**
  for houses, shops and hotels: one navigation mesh per storey at its floor
  height from the floor `HouseNavCheck` walks, a two-way link per stair, the
  exterior doors and every piece of furniture's use point. `navigation_node()`
  is a `Node3D` of `NavigationRegion3D`s and `NavigationLink3D`s to add under
  the instanced building. Churches, temples, castles, windmills, bridges and
  trees report `supported: false` (todo `NAV-INTERIOR-OTHER-FAMILIES`).
- `NavBake` (core/nav_bake.gd): outlines in, canonical navigation mesh out.
  `VillageNavCheck.sources()` and `HouseNavCheck.sources()` list the outlines
  each check rasterises.
- New suites `dmvwalk` (the two real Voxel_Build cities) and `bwalk` (in
  `lane:api`); `tests/walk_navserver_test.gd` asks Godot's NavigationServer3D
  for paths over the exported data.

### Measured

| Request | Buildings | Gates | Mesh polygons | Walkable | Doors reached | Furniture |
|---|---|---|---|---|---|---|
| Thaannafu 45 + 4000 implied | 21 | 4 | 475 | 8 043 m² | 21 of 21 | 6 |
| Wuunafu 60 + 6000 implied | 29 | 5 | 499 | 9 023 m² | 29 of 29 | 6 |

Every door and usable prop is on the gates' island; no mesh polygon stands on
a building's walls (an arrival court excepted); 81 of 81 NavigationServer3D
paths arrive (gate to every door and prop in both cities; front door to every
upstairs piece in the two-storey innkeeper townhouse 32102).

### Compatibility

- Additive. Every SitePlan is byte-identical to 0.1.1 apart from the `walk`
  key: Wuunafu 60 + 6000, Thaannafu 45 + 4000 and `thorn-hamlet` were diffed
  against the 0.1.1 release's own exporter. The plan's `schema_version` stays 1.
- The exporter costs a little more per plan (one more walk grid and one bake;
  the bake itself is tens of milliseconds).
- `HouseNavCheck` and `VillageNavCheck` judge exactly as before; the new
  functions sit beside the rasterisers they mirror.

### Known issues

- **Set the 3D map's merge rasterizer cell scale to 0.04** (project setting
  `navigation/3d/merge_rasterizer_cell_scale`, or
  `NavigationServer3D.map_set_merge_rasterizer_cell_scale`). The meshes are on
  a centimetre grid; at Godot's default 0.25 m merge grid 38 of the 81 test
  paths failed and every stair link was lost.
- Interior walks are published for HousePlan families only.
- `lane:house-plan-fast` is not green: `hmultistory` reports 28 findings,
  line for line the 0.1.1 baseline. `lane:temple` was not run (no temple code
  changed); TEMPLE-ROTUNDA-ARCADE stands as in 0.1.1.

### Lanes

`lane:api` (with `bwalk`) 491 checks pass; `lane:village-fast` 47 pass;
`dmvbrief` 189 pass; `dmvimplied` pass; `dmvwalk` 87 pass;
`lane:house-plan-fast` 270 checks, the 28 known findings; the walk
NavigationServer3D test 81 of 81 paths. A second Wuunafu export is
byte-identical to the first.

### Migration

- Install from `releases/brick_wild-0.1.2/`. Read `walk` from the SitePlan for
  the street navmesh; add `BrickWild.navigation_node(b)` under each instanced
  building; link each site door's `outside_m` to the building's front
  `inside_m` through the building's transform.

## 0.1.1 - 2026-10-10

A city is planned for the people shown and built for the people implied.
Tag `v0.1.1`.

### Notable changes

- **`--implied-population M`** on `tools/export_village_plan.gd`, beside
  `--population N` (owner decision 2026-10-10). N, the visible people, sizes
  the homes, their lots and the everyday trades. M, the city the history says
  it is, sizes the civic programme only: the seat (hold below 200, castle from
  200), the wall (from 150), the landmark, the market and halls (butcher,
  tailor, town hall, guildhall) and the monuments. It never adds a home or a
  residential lot. Civic scale stops at `VillageSpec.CIVIC_MAX` (500): every
  civic threshold is below it, so a capital of millions plans the civic
  programme of a town of 500 on one site of at most 400 m. With the flag the
  plan carries `population_implied`, `population_civic`, a note, and on every
  building `serves: "visible" | "implied"`. Example:
  `--request wuunafu-schema2.json --population 60 --implied-population 6000`.
- **Monuments are never the seat.** A kept `great-tomb` or `ziggurat` is a
  castle mass marked `"monument": "<word>"`, sized as the seat is (the hold's
  footprint below 200 civic people), on its own lot class, placed after every
  home on the frontage nearest the site's edge or on its own plot and lane at
  the edge. A royal or military city that kept one still gets its seat.
- **A small city's kept wall is a palisade**, with a note, instead of a
  refusal: below 150 people (implied counted) and not military. A wall kept
  as fully as the palisade is now the wall.
- Exporter refusals name an unplaced monument by its word (`great-tomb`), not
  as `castle`.
- New suite `dmvimplied` (the two real Voxel_Build cities planned, about
  4.5 minutes); `dmvbrief` gained the small-wall, monument and implied checks.

### Measured

| Request | Buildings | Seat | Monuments | Enclosure | Homes | Site | Time |
|---|---|---|---|---|---|---|---|
| Thaannafu (military) 45 + 4000 implied | 21 | castle 40 x 50 | great-tomb 40 x 50 | wall | 9 | 400 x 235 m | 116 s |
| Thaannafu 45 + 2942190 implied | identical to the row above but for the implied fields | | | | | | 115 s |
| Wuunafu (royal) 60 + 6000 implied | 29 | castle 29 x 36 (palace 0.2) | great-tomb, ziggurat 40 x 50 | wall | 14 | 367 x 209 m | 151 s |
| Wuunafu 60 + 10614806 implied | identical to the row above but for the implied fields | | | | | | 152 s |
| Thaannafu 45, no implied | 17 | hold 12 x 14 | great-tomb 12 x 14 | wall | 9 | 225 x 150 m | 61-82 s |
| Wuunafu 60, no implied (was refused) | 25 | hold 10 x 12 | great-tomb, ziggurat 12 x 14 | palisade | 14 | 246 x 125 m | 78-94 s |

### Compatibility

- Byte-identical output for every request that planned before and does not
  keep a `great-tomb` or `ziggurat`, a wall as fully as a palisade, or a wall
  below 150 people: `thorn-hamlet` at 26, 40 and 160, `veld-070`, and
  `veld-100` at 220 were diffed against 0.1.0. Requests refused before are
  refused the same way unless one of the three decisions above lifted the
  refusal (Wuunafu at 60 and 150, Thaannafu at 150 now plan).
- A request that keeps a monument changes: it gains a seat, and the
  monument is resized and placed differently (Thaannafu at 45).
- No new field appears in a plan made without `--implied-population`
  except `monument` on a monument's building.

### Known issues

- `lane:plan` is not green: `hmultistory` reports the same 28 findings as
  0.1.0 (finding lines identical).
- `lane:temple` is not green: the Rotunda's upper arcade
  (TEMPLE-ROTUNDA-ARCADE), unchanged from 0.1.0.
- Market stalls on the square are still not planned at any population.

### Migration

- Callers of the exporter who show a slice of a large city: pass the shown
  people with `--population` and the history's people with
  `--implied-population`. Read `serves` to tell the city's buildings from the
  shown people's, and `monument` to tell a tomb from the seat.
- Install from `releases/brick_wild-0.1.1/`.

## 0.1.0 - 2026-10-09

The first release. Tag `v0.1.0`.

### Notable changes

- **Renamed** the public facade, addon path, tools and JSON schema namespace
  from BigGlade to BrickWild (`BrickWild`, `res://addons/brick_wild`,
  `brickwild.request` / `brickwild.building`). The public API version is 2
  for this breaking rename.
- **The C1 site exporter takes the settlement's size from the caller.**
  `tools/export_village_plan.gd` gained `--population N`. A Voxel_Build
  SiteRequest of schema 2 (VXB-002) carries `population` as the people of the
  whole polity node (`population_of: "node"`), often millions; it is never
  read as a village. Such a request without `--population` is refused with one
  line and exit 2. With it, N people are planned, `population_asked` is N, and
  `notes` records the node's figure. Schema 1 requests plan their own
  `population` as before; `--population` overrides it. See
  `docs/VILLAGES.md` section 10a.
- **A royal or military seat below 200 people is a hold**: one fortified house
  at the castle family's house tier (about 12 x 14 m), on a lane sized to it,
  not a 40 x 50 m castle. A royal or military hamlet of 30-60 people now
  plans every building inside a 400 m site (measured on
  `tests/fixtures/site_requests/thorn-hamlet.json` at 30, 45 and 60). A city
  gets one seat castle.
- A Pylon temple's published footprint is what it emits: it no longer
  reserves 1.5 m a side for obelisks that stand on its forecourt.
- Exporter refusals name the building that had no lot
  (`unplaced: castle`), not only the count.
- Added the `windmill` kind: post mills, tower mills, smock mills, American
  farm windpumps and Dutch polder mills, behind one family and one set of three
  numbers (`docs/WINDMILLS.md`). Its generator clamps those numbers to what the
  mill type can be built as, so `describe_kind()` publishes `"clamps": true`.
- `BuildingLibrary` gained `dimension_fields()`, `clamps()` and
  `surface_count()`, so a family whose spec names its dimensions differently or
  carries more than four surfaces says so in its own row.
- The addon manifest lists directories, not files, so a family can no longer
  be left out of the package; the bridge and tree families now ship.
- Release tooling: `tools/release_brick_wild.ps1` freezes a commit, installs
  it into an empty project with the release's own `install.ps1`, imports and
  smokes it, and only then publishes `releases/LATEST` and `releases/current`.
- Added `tools/render_windmills.gd`, the `lane:windmill` suite, and public
  contribution and development documentation.

### Compatibility

- Godot 4.5.2 (tested with `Godot_v4.5.2-stable_mono_win64`). Village and
  exporter seeds come from GDScript `hash()`, so byte-identical plans hold for
  that pinned binary, not across Godot upgrades.
- `BrickWild.API_VERSION` 2; JSON schema version 1 for `brickwild.request`,
  `brickwild.building` and `dmv.site.plan`.
- Exporter exit codes: 0 written, 2 usage or I/O (including a schema 2
  request without `--population`), 3 refused.
- The release embeds licensed prop packs that git does not track. It is
  built from a checkout that has them; `release.json` counts the files copied
  in (`untracked_pack_files_from_local_checkout`).

### Known issues

- Any non-military request under 150 people that keeps a
  `stone-wall` or `marble-wall` is refused: "a kept wall needs at least 150
  people or a military regime". Voxel_Build's `site:city-0002` (Wuunafu,
  royal) is refused at 60 people for this reason.
- `great-tomb` and `ziggurat` are planned as castle masses of up to 40 x 50 m
  whatever the population, and the seat is skipped when any castle is already
  in the programme. A military city with a great-tomb gets the tomb and no
  seat (`site:city-0004` at 45 people); Wuunafu at 150 people is refused
  because its tomb and ziggurat find no lot.
- `lane:plan` is not green: `hmultistory` reports 28 furnishing and stair
  findings on the multi-storey house sweep (bedside tables away from beds,
  sparse parlours, legacy trade stairs too steep or unguarded on townhouse
  32102 and longhall 32103, a cottage kitchen without a hearth). The same
  count has been tracked as known since 2026-10-07; the mix moved with the
  furnishing work of 2026-10-09. `house` and `houseqaplan` pass.
- `lane:temple` is not green: the Rotunda's new upper arcade (commit
  abf5395) logs its piers as masses QA reads as floating about 5.5 m above
  ground, and on some seeds a pier cuts into an interior column or the idol
  (`temple` 26 and `temple rite` 246 failures, every one a Rotunda). The
  Pylon passes its 45-case native fixture.

### Migration

- From BigGlade: rename `BigGlade` to `BrickWild`, `addons/big_glade` to
  `addons/brick_wild`, and the `bigglade.request` / `bigglade.building` schema
  strings to `brickwild.request` / `brickwild.building`. Install with the
  release's own `install.ps1`.
- Install from `releases/brick_wild-0.1.0/install.ps1` (embedding) or run
  `godot --path releases/brick_wild-0.1.0/project` (tools), not from the
  repository. Pin the version in your own staging script.
- Callers of `tools/export_village_plan.gd` with schema 2 SiteRequests: pass
  the settlement's people with `--population N`. The request's `population`
  is the polity's size, not the village's.
- A royal or military village of under 200 people now has a hold where it had
  a castle. Anything placed by the seat (a throne room, guards) should expect
  one building with no curtain wall or courtyard.
