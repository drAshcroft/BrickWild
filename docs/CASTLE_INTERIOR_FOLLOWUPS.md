# Remaining castle interior work

The original findings date from INT-007 on 2026-09-13. Plans now exist for
ridge ranges, tower houses and motte keeps. Their existence did not establish
complete castle occupancy: the independent inventory added on 2 October found
whole missing interiors and windows above the rooms actually represented.
The broad CASTLE-INTERIOR-FORMS task remains open.

## Status after the 6 October 2026 pass (CASTLE-INTERIOR-FORMS)

Every form named in the inventory (`CastleOccupancyCheck.expected_ids`) now has
a planner. What changed, and what is still red, measured with
`artifacts/castle_todo/sweep_occ.gd`-style sweeps (build, occupancy, route and
per-plan HouseQA over the canonical style x tier x size grid):

Done and green on the bounded lane (`lane:castle-change`, `cridgeoccupancy`,
`coccupancy`, `cmotteaccess`, `cmotteroute`, `cgatestairs`, `ctowerhouse`):

- Walled castles: mural towers, gatehouse chamber and apse are planned for every
  enclosed plan, not only the motte (`castle_mural_plan.gd`, `castle_gate_plan.gd`,
  `castle_apse_plan.gd`). A slender tower coarsens its facets (12, 8, 6, 4) until
  a facet takes a door; the door floor is fitted to the coping; a tower lower
  than the coping, or one no gallery reaches, is entered from the ward.
- Manors and houses: `castle_manor_plan.gd` plans wings (a ridge range turned to
  the court), the courtyard front range (guard bay, passage, guard bay, one room
  above), the annexe, the front towers and the tower-house jogs. A wing starts
  at its tower's rear face and masonry cheeks fill the strip beside the tower.
- Ridge castles: `castle_ridge_plan.gd` trims each range at its vertex towers
  (mitre-safe cut), fills the old overlap with solid cheeks, and plans the vertex
  towers and the dark spire (the castle's `keep`). Dormers over a planned mass
  are shuttered blind gablets: a window must open into a room.
- Sky castles: each turret-island is a stack of rooms entered a storey up from
  the bridge that leaves it.
- QA: `_check_room_floor` counts samples outside stair wells (dais measured at
  its rise) and wants half of them supported; the mutation harness removes every
  floor triangle that reaches the room.

Found and fixed on the way (each one made a whole family read red):

- A flat-topped tower house has no roof slot, so `commit()` slid its glazing
  from surface 3 to surface 2 and every opening check read it as masonry.
  `_keep_surface_slots` now holds every empty slot below a populated one.
- `tower_door_sill`: a 5.7 m storey could not hold a 2.6 m door above a 4 m
  sill; the head went through the ceiling.

Still open (this is why the task stays pending). `tools/castle_occupancy_sweep.gd`
reproduces every line below; the counts are from the canonical grid at the
pass's last full sweep:

- Tight ridge zigzags (`dark castle` seed 9249, 40 m): FIXED 14 October. The
  ranges were as wide as the pitch between five vertices, so towers plus the
  mitre-safe cut left no run for a room and everything stayed solid. Mitring the
  end bays was not needed: `CastleGenerator._fit_ridge` now draws fewer vertices
  (floor three) until every `CastleRidgePlan` range is `usable`. Seed 9249 is a
  three-vertex ridge; the occupancy sweep reports no `occupied_shells` failure.
  `castle_change_suite._tight_ridge_contract` pins it, with the old five-vertex
  spine as the negative control. (The sweep's remaining raw-HouseQA furnishing
  lines for the dark ridges predate this and are unfurnished-plan noise.)
- Tower-house shaft: FIXED 14 Oct (`tools/castle_tower_house_sweep.gd` reproduces
  every style x seed x three footprints; pinned by `ctowerhouse`
  `_platform_entry_contract`, each probe with a built-to-break negative control).
  The roof platform is a planned open-air deck (`open_air` room: the top
  chamber's clear floor, floor slab and no walls; `HouseBuilder` raises none and
  `CastleBuilder` caps the walls with a parapet ring, not a solid slab that filled
  the stair well). `TowerSpec.entry_storey` carries the raised door's storey
  (as a keep's), and `HousePlanCheck` exempts only an `open_air` deck from the
  walk-through-a-bedroom privacy rule. The L/Z front jog no longer stands in the
  entrance: `CastleGeometry.tower_entry_x` slides the door and steps left of the
  jog, `tower_jog_width` narrows the jog, and `_fit_tower_house` drops a jog
  narrower than `TOWER_JOG_MIN_W`. Windows that opened onto a solid stair flight
  (jog block, faceted wizard shaft) are dropped and daylight restored.
  Still red in these cases and NOT this item: furnishing findings
  (`sparse`, `lamps`, `seat_count`, `seat_kinds`, `stowage`, `table_band` in every
  tower house), being baselined separately. `ctowerplan` (wizard oval) and
  `cforms` were not re-run after this change.
- Furnishing walk-QA in castle rooms (`seat_count`, `sparse`, `lamps`): FIXED
  20 October for the castlechange and README hero fixtures by
  `src/castle/castle_room_top_up.gd` (`CastleRoomTopUp`), run after the minimum
  programme and after every castle call to the full furnisher. Causes: the
  minimum programme seated only hall/parlour, so every guardroom table seated 0;
  `_place_behind` committed the lord's bench with no `host`, so a great hall's
  high table seated 0; a 55-254 m2 tower guardroom held one table (1-4 %) and no
  light. The pass seats short tables in pairs (one seat model per room), fills
  sparse rooms with a free table set (first clear spot nearest the middle on a
  0.5 m grid, then two seats drawn up to that table), trestle rows, wall and
  corner stores, and hangs sconces. It changes no check. A room is dressed in
  one go and judged once: every HouseFurnishCheck complaint except the two whose
  text carries the changing measure (`sparse`, `lamps`) must not grow, and a
  room-local WalkGrid (HouseNavCheck's cell and alignment, only this room's
  floor) must still reach every door threshold, landing, plan zone and use zone
  of the room. A worse room is cut back to its longest good prefix by halving,
  then continued piece by piece. A parlour in a household that eats elsewhere
  gets no table (the programme rule's own question, asked first).
  Measured interior failures (scratch probe = `HouseQA` on every interior, as
  CastleQA does): square 1 -> 0, round 9 -> 0, battered 226 -> 5, ridge 82 -> 11,
  tower house 13 -> 2, README hero 37 -> 0; every remaining line was present at
  baseline (ridge hall `corridor` on a 38 x 10.8 m great hall the corridor rule
  classifies as a corridor, `stowage` in lords' chambers, two `front_door`, a
  battered keep parlour of 187 m2 that the programme forbids a table and no
  wall will take a piece). Pass cost on a loaded host: battered 62 s, ridge 71 s,
  tower house 9 s, hero 6 s (the 14 October WIP took 700-940 s for battered
  alone: whole-plan HouseNavCheck per trial plus place_free's 128 x 128 scored
  search per table). The whole-plan HouseNavCheck safety net
  (`CastleRoomTopUp.verify_whole_plan`, env `BW_TOPUP_VERIFY=1`) undid no room
  in any of the six builds, so it is off by default; CastleQA still runs
  HouseNavCheck on every interior. Lanes, same host and day: castlechange +
  cmotteaccess 17 failures (354 checks) -> 3 (castlechange: battered `front_door`
  + 187 m2 keep parlour; ridge hall `corridor` x2 rows); `cmotteaccess` passes.
  `lane:castle-change` 7 suites green but castlechange; `lane:house-furnish-fast`
  240/240 green before and after (the `_place_behind` host link is the only
  house-family change). Remaining cost: sconce placement
  (`HouseFurnishSurface.place_mounted`, 20-28 s per big castle) and the whole
  furnishing check (~0.3 s per room judged).
- **CASTLE-CHANGE-17 CLOSED (21 October).** `lane:castle-change` is green on
  `terrain-villages`: 7 suites, 706 checks, 0 failures, 0 warnings
  (`artifacts/castle_change17/lane4.log`; `castlechange` 264 checks in 310.63 s:
  square 1.50, round 35.52, battered 141.84, ridge 92.62, tower house 18.40 s;
  `ctowerhouse` 65, `cmotteaccess` 91, `caperture` 150, `cgatestairs` 16,
  `cbergfried` 19, `kwalk` 101). Seven causes, each fixed where it is
  generated: the corridor rule is narrow first (2.6 m, then 3.0 m, then a 3.5
  ratio) so a 38 x 10.8 m great hall is a room; a polygonal tower takes one
  window per `KEEP_WINDOW_PITCH` around its perimeter rather than one per
  facet; the placer tests a turned piece's own corners, not its AABB, so a
  square can stand on a chamfer of a 14-sided keep (the physical check follows
  the turned footprint); a parlour gets a wall bench (battered 187 m2 parlour
  1% -> 11%); a relocated seat carries its exact zone strip; a front-door focus
  stands clear of the way in (`ShopPlanner._choose_focus`, `place_free`) so
  `cshop` is 21/21 where HEAD had two `front_door` failures; and a range's
  upper storeys take their own bays (3.4:1 aspect, 250 m2 cap) so the ridge's
  441 m2 parlours at 8-9% become six 219.8 m2 rooms at 11-13%. No check was
  relaxed. `main` coverage follows a merge.
- The smallest tier of every walled style (40 x 55 m): the corner towers are
  embedded in a 5 m footing, no clear gallery reaches the coping, and the ground
  door a fallback gives them meets the 0.65 m wall footing (door clearance fails);
  `crusader`, `french_chateau`, `bavarian`, `japanese`, `moorish`, `wizard`
  castle 0.
- Elven (bowed) curtains: `_curved_wall_run` bypasses `CastleBuilder.box`, so the
  towers are never cut out of the wall, the tower rooms have no floor where the
  curtain crosses them and the routes fail.
- Gate chamber routes in a few rect and fortress cases are crossed by masonry
  (`access_routes[gate_N]`); inner-ward gate towers' windows in some polygon
  fortresses face the other ring.
- Not this task's forms, but red in the same sweeps: `yard_general_store`
  planned window has no matching emitted aperture (every fortress), a keep
  programme with a second dining table (fortress keeps), `hall`/`chapel`/`apse`
  records in a few fortress shapes (the fallback plans cover most).

## Earlier implementation inventory (historical)

The following inventory predates the 6 October pass above. Its statements
about missing jog, manor, ridge-tower and sky plans are historical, not the
current implementation state. Source review on 13 October confirms the
dispatches in `castle_interiors.gd` to `castle_manor_plan.gd` for these forms.
The unresolved physical failures in the current-status section still govern
completion; no new castle sweep is claimed by this documentation correction.

### Plans for ridge castles, tower houses and motte shell keeps

Current entry points:

- `src/castle/castle_interiors.gd::primary` dispatches ridge ranges and tower
  houses to their local plans. Inventory coverage still needs to include ridge
  defensive towers, tower-house jogs, manor annexes/wings and sky towers.
- Ridge ranges use `CastleInteriorPlans.ridge_range_plan` in each segment's
  rotated frame. Seed 8805 exposed upper facade windows without upper rooms;
  the multistorey repair and its emitted-floor evidence are still in progress.
- Tower-house plans represent the main tapered storeys and raised entrance.
  `tower_jog_aabbs` still require independent occupied plans and real access.
- Motte plans use the mound-fitted oval at `shell_keep_aabb`. The seed 8856
  furnished fixture now passes full CastleQA: its keep, hall, chapel, sanctuary,
  gate chamber and six mural towers have room-backed openings. Seven defensive
  entrances reach courtyard ground through two real wall stairs. Fresh renders
  are being inspected separately; this fixture does not close the broad task.

Implementation requirements:

1. Add pure, local plan generators for each supported form. Derive dimensions,
   per-floor outlines, origins and rotations from the same geometry records the
   builder consumes. Plan records must own openings, floors, stairs, furniture
   and explicit omissions; keep model loading in the assembler.
2. For ridge ranges, generate each rotated range in its own frame and represent
   doors/connections between touching ranges. Do not treat the world AABB as the
   local floor or as the opening surface.
3. For tower houses, represent the actual storey count, floor heights, tapered
   floors and jogs. Model the elevated exterior entrance plus its actual approach
   and stairs. Replace the ground-only entrance rule only with a stricter family
   rule that proves this route, never a blanket exemption.
4. For the motte, use `shell_keep_aabb` and the oval inner floor at the correct
   mound height. Decide explicitly whether its centre is an open court or an
   occupied building. Cut real doorway geometry and prove the route up the mound.
5. Replace the corresponding solid bodies with stone shells, preserve top-level
   mass records, and group HouseQA reports by stable building ID. Extend the
   castle walk across the actual terrain and connected building entrances.

Acceptance and reproduction:

- Use canonical `CastleLandmarkSuite` fixtures for the ridge castle, tower house
  and motte at the suite's small/default/large scales; preserve their shape and
  top-level mass assertions.
- Compare each local room outline and transformed opening against emitted mesh
  triangles. A rectangular-room/AABB substitution must fail for rotated and oval
  hosts. A filled doorway or upper stair opening must fail a ray-based check.
- Assert that every stair landing fits both adjacent actual floor polygons and
  that the terrain/entrance route reaches all occupied rooms.
- Require grouped HousePlanCheck, HouseFurnishCheck and HouseNavCheck reports;
  any genuine plan, furnishing or access failure must fail CastleQA.
- Run `tests/run_all.gd -- castle cnormals cmassing clandmark cvoxelqa` plus the
  castle interior/plan-shell suites. Render each new form with roofs on and off.

## Polygon wall indices in furniture affinity and secondary QA

The core wall placer already uses `HouseGeometry.room_walls`. Several affinity
and secondary-check helpers still assume four AABB walls in the order front,
back, left, right. A polygon's walls instead follow its outline; even a four-point
square has a different order. A 14-sided keep makes indices above three valid.

Confirmed remaining locations:

- `HouseFurnisher._back_wall_index`, `_wall_normal`, `_window_crowding`,
  `_wall_has_window`, `_over_bonus` and the other `_wall_normal`
  callers in `src/house/house_furnisher.gd`.
- `HouseFurnishCheck._fs_back_wall`, `_fs_wall_normal`, `_fs_wall_lit`, the
  four-wall loop in `_check_bed_window`, and remaining `_fs_wall_normal` callers
  in `qa/house_furnish_check.gd`.
- INT-007 already fixed `HouseFurnishCheck._wall_of` for fireplace/chimney
  agreement. Preserve its new polygon-normal lookup and regression tests.
- INT-007 also fixed paired lamps: `_flank_wall`, `_flank_anchor`,
  `_flank_station` and `_flank_bonus` now use actual facets, as do the independent
  `_fs_pair_wall`, `_check_sconce_pair` and `_fs_pair_fits` checks. Adjacent
  14-gon faces must remain distinct; their normals have a dot product just over
  0.9, which is too loose a same-wall threshold. Preserve the oblique pair,
  adjacent-facet, off-symmetry and beyond-facet regressions in
  `tests/suites/polygon_sconce_suite.gd`; pairing is complete, not new work.
- Rotated prop footprints, polygon overhang detection, and four-corner bounds
  for access/window strips are also fixed. Preserve
  `tests/suites/castle_keep_furnishing_suite.gd`; do not defer or duplicate these
  physical corrections.

Replace AABB wall identification with measured distance/facing against actual
room edges, and retrieve normals from those same wall records. Update producers
and independent checks together while preserving the existing rectangular
results. Review projections onto diagonal walls; `.abs()` of a tangent can
destroy its signed direction. Do not use the placement's declared wall index as
the check's only evidence.

Acceptance:

- Construct the same square both as a rectangle and as a polygon with rotated
  starting vertex and reversed winding. Physical placement preferences and QA
  outcomes must agree regardless of numeric wall labels.
- Add an octagon and 14-gon with windows, a blind bed wall, a fireplace and
  shelving on edges whose indices exceed three. Preserve the existing paired
  lamp regressions while changing shared wall helpers.
- Mutate a bed onto a glazed wall, a bookcase onto the fireplace wall and a shelf
  away from its host. Each relevant check must detect its physical defect.
- Run shaped-room, keep, house-furnishing and asset suites. Review room renders
  to confirm that furniture faces the actual wall and remains navigable.

## Generation and QA performance

Large castle generation and validation remain expensive. The
[CASTLE-INTERIOR-PERF task](tasks/castle_interior_performance.json) records the
observed suite timings, representative fixtures, and required phase profiles.
Those timings were collected under concurrent load and are not isolated
generation benchmarks. Preserve complete plans, RNG state, furniture and
navigation resolution while identifying the cost. The implementation and
[verification commands](CASTLE_INTERIORS.md#verification) include `hassembly`
to protect the measured model-pivot, wall-mount and bed-headboard corrections.

## 21 October 2026: every occupied range must be reachable from the gate

CASTLE-CHAPEL-SEALED. `kwalk` reported `castle bavarian 55x50 seed 3` only as
"the mesh does not claim what the grid cannot enter", because nothing asked
whether a range has a way in from the ward.

The defect: `CastleApsePlan` builds the apse as a projecting half-drum on the
chapel's axial end wall, entered only from the chapel; `_hall_door` put the
chapel's one entrance on that same wall; `connect_chapel` then widened that
door and kept it as the entrance. So each of the pair had exactly one door and
it opened onto the other. `CastleOccupancyCheck` passed both: it requires *an*
exterior entrance per building, never that the entrance leads anywhere the ward
can reach.

Fixed in the planning, not the check:

- `CastleInteriorPlans._bailey_door` adds the chapel's way in on its bailey
  face (the west long wall, `DOOR_CORNER_MARGIN` off the corner) whenever an
  apse owns the axial end wall. It is recorded before `_courtyard_windows`, so
  the window run splits around it instead of the door landing on a window.
- `CastleApsePlan.connect_chapel` demotes the axial door to the sanctuary arch
  (`front: false`, `connects_to: "apse"`, head 2.3 m) once the plan has another
  exterior door, so `entrance()` is the way in and not the way through.

New rule: `CastleOccupancyCheck.unreachable_ranges(builder)` links every
exterior door to the range whose footprint it opens onto (or to the ward), then
floods from the ward. Every range with a way in of its own must be reached; a
range with no exterior door is an annex entered through its host and is not
reported; mural towers and gate chambers are `CastleRouteCheck`'s wall-walk
route and are left out. `check()` fails each unreached range.

Negative controls in `tests/suites/castle_occupancy_suite.gd`
(`_sanctuary_contract`): strip the chapel's `front` door from the README motte
and both the chapel and the apse must fail the rule; restore it and
`unreachable_ranges` must be empty.

`tools/castle_range_reach_probe.gd` prints the same flood from
`CastleWalkSources` (with the plan's doors) for any spec:

```
godot --headless --path . --script res://tools/castle_range_reach_probe.gd -- bavarian castle 55 50 3 chapel apse
```

Before: `apse SEALED`, `chapel SEALED`. After: all four ranges reachable, and
the walk gains the link `0 -> 400` (ward to chapel).

## 22 October 2026: the live occupancy inventory (CIF-INVENTORY)

Measured with `tools/castle_occupancy_sweep.gd` over every style at the
`castle` and `fortress` tiers, index 0 (seed 9249 for `castle`, 9117 for
`fortress`). Each case builds the castle, runs `CastleOccupancyCheck`,
`CastleRouteCheck` and `HouseQA` on every interior, and groups the failures by
message. Logs: `artifacts/castle_if_1022/inventory_cf0.log` and
`inventory_fortress_rest.log`.

| style | tier | failures |
|---|---|---|
| norman | castle | 0 |
| edwardian | castle | 0 |
| crusader | castle | 0 |
| dark | castle | 0 |
| french_chateau | castle | 6 |
| moorish | castle | 7 |
| wizard | castle | 8 |
| japanese | castle | 12 |
| bavarian | castle | 15 |
| sky | castle | 20 |
| elven | castle | 28 |
| norman | fortress | 1 |
| japanese | fortress | 2 |
| wizard | fortress | 1 |
| bavarian | fortress | 0 |
| dark | fortress | 0 |
| sky | fortress | 0 |
| crusader | fortress | 10 |
| edwardian | fortress | 12 |
| elven | fortress | 67 |
| moorish | fortress | 68 |
| french_chateau | fortress | 76 |

Four defect classes account for almost all of it, and they are not evenly
spread:

1. **Outdoor lanterns in demoted stores** (the whole of `french_chateau`
   fortress's 76, 67 of `elven` fortress's, 68 of `moorish` fortress's, 12 of
   `edwardian` fortress's and 10 of `crusader` fortress's failures): a mural
   tower storey is furnished as a guardroom and only later demoted to a store
   by `blind_rooms_to_stores`, keeping the one OUTDOOR-tagged prop. Fixed in
   `CIF-STORE-FURNITURE` (361a65c, after these fortress runs): the demotion now
   takes the piece out. The fortress numbers in the table are therefore
   PRE-FIX upper bounds; each style's chunk reruns its own case.
2. **Mural tower door thresholds on the side and corner towers of the rect
   castles** (`bavarian` 15, `japanese` 12, `wizard` 8): "exterior entrance has
   insufficient standing height above its emitted threshold". The corner towers
   of the polygon castles were fixed in `CIF-MURAL-DOORS`; the rect tiers place
   their side-tower doors differently.
3. **Curtain routes on the polygon castles** (`moorish` 7, `french_chateau` 6,
   `elven` 28): "masonry blocks wall-walk route" and, on `elven`, every tower's
   "curtain route does not reach an emitted stair down to the courtyard" --
   a curved curtain has no wall stair at all, so the whole walk is stranded.
   `elven` also reports "room 2 has no emitted floor with standing clearance" on
   every corner tower and masonry-filled windows on the curved towers.
4. **Sky towers** (`sky` 20): "final mesh blocks exterior door clearance" and
   "Chair_1 in room 5 (watch_room)" on the sky towers, which stand in the air
   with their own door geometry.

Smaller, one-off findings: `norman`, `wizard` and `japanese` fortress each
report `yard_general_store: planned window has no matching emitted aperture`;
`japanese` fortress also reports the keep's 344 m2 parlour as sparse; `sky`
fortress is clean at this index.

Each class below is a chunk of CASTLE-INTERIOR-FORMS with its own acceptance.
