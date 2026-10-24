# Changelog

This file records public releases. A release is frozen and verified by
`tools/release_brick_wild.ps1` into `releases/brick_wild-<version>/`; other
projects consume that, never this working tree (`docs/RELEASES.md`).
`BrickWild.API_VERSION` is a separate compatibility number; see `README.md`
and `docs/PUBLIC_API_TRANSPORT.md`.

## 0.1.4 - 2026-10-23

Villages can be planned on real ground. Buildings stand on falling ground,
and castles are furnished and their tower doors open onto the wall walk. Tag
`v0.1.4`. `API_VERSION` stays 2. Every new field is optional, and a request
without ground gives the same SitePlan bytes as 0.1.3 (see Compatibility).

### Notable changes

- **Villages on given ground** (`docs/VILLAGE_TERRAIN.md`). A site request
  may carry a `brickwild.terrain` height grid, either as `terrain.height`
  (inline, or a path beside the request) or as `--terrain <grid.json>` to
  `tools/export_village_plan.gd`. The village is then planned on that ground:
  - It is sited and turned on the grid (`site.anchor_m`, `site.yaw_deg`), and
    its roads are routed by grade, with a `steps` class where a cart cannot
    climb.
  - The form follows the land. `shore`, `valley`, `crest`, `dispersed` and
    `hillside` have their own planners; `water` is still planned as its
    fallback, and the plan says so.
  - Lots stand on platforms fitted to the fall, with cut, fill and terrace
    walls. Every off-road lot gets an entry flight. The ground's water becomes
    plan water, and bridges are fitted to their banks.
  - The plan carries `ground` for the whole site, and a `ground` block on
    every lot, building and road.
  - `VillageGroundSurface` meshes the graded ground: pads, road beds, retaining
    walls and banks.
  - The village walk becomes 3D, with stairs as links.

  Without terrain, nothing in the output changes.
- **Buildings on falling ground.** `BuildingRequest.ground_fall_m` and
  `ground_downhill_deg` (local frame; default 0 / 0, and left out of
  `to_dict()` then). Houses and shops take up to two storeys of fall:
  foundations, entry steps and a bank storey. A door above the ground
  publishes its way down as `route_m`. A church stands on a terrace of up to
  6 m. A castle stands on a revetted platform with a stepped talus, a filled
  bailey and a gate flight, up to `CastleGeometry.SLOPE_MAX_FALL`. A fall
  beyond a family's limit is refused with `ground_too_steep`, not clamped. A
  sky citadel, and any family other than these four, refuses any fall.
- **Castles.**
  - Guard and hall tables are seated, sparse rooms are filled, and rooms are
    lit (`CastleRoomTopUp`). A tower storey that cannot seat a table becomes a
    watch room.
  - The chapel has a bailey door, and every occupied range must be reachable
    from the gate.
  - Every mural tower door opens onto the wall walk at its own sill, on
    polygon castles and on rect ones (bavarian, japanese, wizard).
  - A corner tower's walker goes round its tower, not through its parapets.
- **Windmills publish a walk.** `BrickWild.navigation()` walks the four
  windmill types that have a room: the miller's floor, inside its drawn wall.
- **Churches, temples, shops, the Witch hut.**
  - Churches: a built reredos for large naves, wall props on the wall face,
    and Gothic towers that end in spires.
  - Temples: a framed gate for the rotunda.
  - Shops: trade-identity contracts for the butcher, apothecary, tailor,
    carpenter and smith. A small 9x12 m smithy keeps its forge when its back
    door crowds the fire wall (`ShopPlanner._hold_the_fire_wall`).
  - Witch hut: the large hut gets a framed entry hood and a tall, crooked
    second stack.

### Fixes

- A royal or military hamlet with a round plan is no longer spread thin. The
  round form's lane-free retry ladder (VIL-ROUND-17077, unreleased) housed the
  seat by widening alone, so Thorn's royal hamlet of 30 was taken at 270 m and
  4.2 % built, below the 5 % floor. When a widened plan is under the floor,
  the planner now clears the seat's head at each narrower width first. The
  result is 225 m and 5.1 %, as in 0.1.3, and round seed 17077 still keeps its
  one entrance lane (`vforms` green).

### Compatibility

- **SitePlans without ground are unchanged.** Exported through the 0.1.3
  release's own exporter and through 0.1.4, Thorn-hamlet, Wuunafu 60 + 6000
  and Thaannafu 45 + 4000 are byte-identical. `schema_version` stays 1, and
  the `walk` schema stays `brickwild.walk` v1.
- **Same request, different interior.** Footprints, doors and lots do not
  move, but regenerating at the same seed changes these:
  - castle furnishing, tower doors and wall-walk copings;
  - church and temple dressing;
  - shop furnishing for the five trades above;
  - the large Witch hut's massing.

  Regenerate any cached copies.

### Known issues

- **Castle occupancy is not clean everywhere.**
  `tools/castle_occupancy_sweep.gd` at castle index 0 still reports these:
  - bavarian: corners 1 and 3, whose curtain route does not reach a wall
    stair, plus the apse sanctuary furnishing (no table);
  - polygon castles' blocked wall-walk routes (moorish 7, french 6);
  - the elven curved curtain, which has no wall stair;
  - sky tower doors and their watch rooms (sky 20).

  The fortress tier is worse. See `docs/CASTLE_INTERIOR_FOLLOWUPS.md`.
- The `water` terrain form has no planner yet. It is planned as its
  `FORM_FALLBACK`.
- Temple Rotunda arcade asymmetry: 4 warnings, as in 0.1.3.
- `lane:church-change` carries 16 warnings, as in 0.1.3.

### Lanes

Run on this tree, on a loaded host. Times are host wall-clock. The rows
marked * were rerun after the VIL-ROUND-DENSITY fix; the rest ran just
before it, on a tree that differed only in that one planner branch.

| Lane | Checks | Result | Time |
|---|---|---|---|
| `lane:api` * | 802 | pass | 816 s |
| `lane:dungeon` | 432 | pass | 88 s |
| `lane:village-fast` * | 47 | pass | 332 s |
| `lane:village-terrain` * | 476 | pass | 84 s |
| `vforms` * | 486 | pass | |
| `dmvbrief` `dmvimplied` `dmvwalk` * | 308 | pass (1 failure before the fix) | 1170 s |
| `lane:church-change` | 5940 | pass, 16 warnings | 143 s |
| `lane:temple` | 3467 | pass, 4 warnings | 301 s |
| `lane:castle-change` | 706 | pass | 855 s |
| `lane:windmill` | 270 | pass | 32 s |
| `lane:house-plan-fast` | 293 | pass, 34 warnings | 201 s |
| `walk_navserver_test` (Wuunafu, Thaannafu) | 114 paths | all arrive | 39 s |

`lane:castle-change` is green for the first time in a release. 0.1.3 shipped
it with 17 failures. A cold editor import of a fresh worktree reports no
SCRIPT ERROR.

### Migration

- Install from `releases/brick_wild-0.1.4/`. A consumer that does not pass
  ground or a fall needs no change.
- Dm_View and PaperFjord: pass a terrain grid to plan on real ground, and
  read `ground` from the plan. Without it the plan is the 0.1.3 plan.
- VoxelGames: `ground_fall_m` / `ground_downhill_deg` on a request place a
  building on a slope. Its local y = 0 is the ground at the uphill edge.

## 0.1.3 - 2026-10-14

Temples, churches and walled castles say where a person can walk; BrickWild
realises dungeon plans; a compact village can be a garden. Tag `v0.1.3`.
`API_VERSION` stays 2: everything is additive, but some buildings look
different at the same seed (see Compatibility).

### Notable changes

- **Interior walks for temples, churches and walled castles.**
  `BrickWild.navigation()` and `navigation_node()` now walk temples (one
  storey, gate to altar; `BuildingFamilyAdapter.walk_sources` / `walk_frame`).
  Churches too (nave, one aisle ring, west doors to altar; transept, apse and
  chapels are not walked yet; a twin-door church no longer has its font in a
  doorway). Walled castles too (`CastleWalkSources`): the ward from the gate,
  each range (hall, chapel, apse, yard buildings, keep) as storeys joined to it
  by a link at every door, the keep up its forebuilding stair and its own
  stairs to the lord's chamber. The mural towers, gate chambers and wall walk
  are not walked yet, nor are manors, tower houses, mottes, ridge and sky
  castles, terraced castles or a castle with a barbican (all report
  `supported: false`). Walking a castle costs about what building its interiors
  does: seconds for a castle, minutes for a fortress; the result is cached per
  spec. Windmills, bridges and trees still report `supported: false` (todo
  `NAV-INTERIOR-OTHER-FAMILIES`).
- **Dungeon rooms (for VoxelGames).** `DungeonRealiser.realise()` (the addon's
  `families/dungeon`) and `tools/realise_dungeon.gd` (the frozen `project/`)
  read a `dmv.dungeon.plan` export from `C:\Projects\dungeon` and write
  `brickwild.dungeon.rooms` v1: each room's size in metres, the planner's
  ceiling/wall/floor grammar per archetype and style, an ordered carve list
  (box / cylinder / ellipsoid, carve or fill), doorways along their walls,
  gates by lock kind, and sockets for fixtures, torches and set pieces. Data
  only: no voxels, no godot_voxel dependency. The default sizes are
  VoxelGames' old formulas, so nothing moves until a style asks it to. Every
  pit has a ledge and a stair out of it. See `docs/DUNGEONS.md`.
- **The garden village (for PaperFjord).** `VillageSpec.garden` (0 to 1,
  default 0) plants a compact display's open ground: beds along house fronts
  and path verges, flower scatter, flowering shrubs, trees where a canopy
  fits, lamp posts along the paths and small ponds in the gaps. Buildings,
  lots and roads never move for it, and a full (non-compact) village ignores
  it. It is a spec field only: the site request JSON and
  `tools/export_village_plan.gd` do not carry it yet.
- **Furnishing.** Shops stock, light and shelve big sales floors, workshops and
  offices by area. Shop kitchens (restaurant, tavern, inn, bakery) get a
  proper commercial kitchen. The palace hangs its banners again (seed 8102 had
  none). Big halls (60 m² and up) and parlours (20 m² and up) are furnished to
  size. The furnisher keeps the foot of every stair reachable. Large churches
  get pews to the door, a raised chancel and an altar group scaled to the nave.
  The Witch hut's large Hall and records room are furnished.
- **Exteriors.** Gothic churches get an octagonal crocketed spire, pinnacles
  and wider lights. The Nordic stave church reads as stave: tarred timber, a
  tiered shingle tower, a svalgang and dragon heads. Romanesque and Russian
  west towers get finished crowns (a hipped cap; a drum and onion). The temple
  basilica gets a pediment. The Witch hut gets a steeper roof, a leaning stack,
  a hooded entry and (large) a second stack. Tower houses get an open-air roof
  deck, and the entrance clears the front jog.
- **Fixes.** Trade houses (innkeeper townhouse, smith longhall) climb by the
  human-scale domestic stair instead of the legacy 2.4 m flight. A tight ridge
  castle (seed 9249) no longer stays solid. Three archived source snapshots no
  longer register duplicate `class_name`s.

### Compatibility

- **Same request, different building.** Regenerating at the same seed changes
  these:
  - The **Witch hut**: dark slate roof colour (was thatch brown), no longer
    clipped to a half-hip, plus the massing above. Plans are unchanged.
  - **Churches**: Gothic, Nordic stave, Romanesque and Russian exteriors;
    larger naves furnished differently. A church's footprint can grow by a
    few centimetres to a few decimetres, and its landmark lot with it.
  - **Trade houses** with more than one storey: a new stair, so the rooms and
    the front door can move.
  - **Shops, palaces, tower houses and big halls**, as above.
- **SitePlans**, diffed against the 0.1.2 release's own exporter (garden 0):
  - Thorn-hamlet: only the church lot `l-000` and the walk round it differ.
  - Wuunafu 60 + 6000: only the smith townhouse `b-013` differs. Its door
    moved 2.7 m, and its yard and three tree trunks moved with it.
  - Thaannafu 45 + 4000: the two church lots grew by 0.1 to 0.2 m, one site
    door moved, and the navmesh has 476 polygons (was 475).
  - Every other building, lot, road and gate is identical. `schema_version`
    stays 1, and the `walk` schema stays `brickwild.walk` v1.
- A Dm_View or PaperFjord map baked from 0.1.2 will not line up exactly with
  0.1.3 at the church and that one townhouse. Re-export rather than mixing the
  two versions.

### Known issues

- **`lane:castle-change` is not green**: 17 failures in `cmotteaccess` and
  `castlechange`. Castle guardroom and great-hall tables seat no one
  (`seat_count`), and some tower and range rooms are under-furnished
  (`sparse`, `lamps`). Not a regression: the 0.1.2 release fails the same two
  suites on the same cases with 18 failures. Its extra sanctuary corridor
  failure is fixed in 0.1.3. A fix is in progress (`CastleKeepPlan.furnish_minimum_programme` seats only
  halls and parlours).
- Temple Rotunda arcade piers 04/10 and 04/13 have no twin across the axis.
  These are 4 symmetry warnings now; TEMPLE-ROTUNDA-ARCADE is still open.
- `lane:church-change` carries 12 warnings for transept openings walled in
  from outside (Byzantine, Gothic and Renaissance at seeds 5003 and 5008).
- Set the 3D map's merge rasterizer cell scale to 0.04, as in 0.1.2.

### Lanes

Run on the release commit's tree, on a loaded host (times are wall-clock and
about three times the recorded ones):

| Lane | Checks | Result | Time |
|---|---|---|---|
| `lane:api` | 798 | pass | 706 s |
| `lane:dungeon` | 432 | pass | 121 s |
| `lane:village-fast` | 47 | pass | 863 s |
| `dmvbrief` `dmvimplied` `dmvwalk` | 308 | pass | 2674 s |
| `lane:church-change` | 5940 | pass, 16 warnings | 388 s |
| `lane:temple` | 3467 | pass, 4 warnings | 747 s |
| `lane:house-plan-fast` | 293 | pass, 34 warnings | 348 s |
| `lane:castle-change` | 701 | **17 failures** | 1446 s |
| `walk_navserver_test` (Wuunafu, Thaannafu) | 114 paths | all arrive | |

`lane:house-plan-fast` is green for the first time in a release. Releases
0.1.0 to 0.1.2 recorded 28 `hmultistory` failures; it now reports 0 failures
and 34 warnings. The warnings were not compared item by item with the old
findings.

### Migration

- Install from `releases/brick_wild-0.1.3/`. Re-export SitePlans and
  regenerate any cached Witch huts, churches and trade houses.
- VoxelGames: realise dungeon plans with `DungeonRealiser.realise()`, or run
  `tools/realise_dungeon.gd -- --plan plan.json --out rooms.json` from the
  frozen project. Carve the ops in order. Apply the ROOT overlap as written:
  shapes reach a metre below the floor so a signed-distance carve meshes
  cleanly.
- Add `BrickWild.navigation_node(b)` under temples, churches and walled
  castles as for houses. Check `navigation(b).supported` first; the castle
  forms listed above still return false.

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
  `VillageNavCheck.sources()` and `HouseWalkSources.sources()` list the outlines
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
