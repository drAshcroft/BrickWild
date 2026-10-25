# House style traits (HS-*)

Each HS-* task names a short, checkable trait list for one house style, measures
it with `qa/house_trait_measure.gd` (`HouseTraitMeasure.measure`, extend it with
the keys the next style needs) in a focused test with negative controls, and
then has an independent reviewer tick it on renders.

## cottage (HS-COTTAGE)

Traits: (1) one storey, eave wall top <= 2.6 m; (2) exactly one masonry stack on
the hearth wall, rising above the ridge; (3) a porch roof over the front door.

Measured first: traits 1 and 2 already held on 40 seeds (stack present, on the
hearth wall, above the ridge). Trait 3 failed on about half of them because the
style row drew `porch` at 0.5. Fix: `porch` and `chimney` are 1.0 in the
`cottage` row of `HouseSpec.STYLES` (`chance` still consumes its draw, so the
random stream and every other roll are unchanged). A request that asks for more
than one storey is the caller's choice and is not clamped.

Test: `tests/house_cottage_traits_test.gd` (28 checks) over the frozen requests
`house/cottage/{1,8102,21325}` in `tests/fixtures/family_style_requests.json`;
controls: two storeys, chimney removed, porch removed.

Renders for review: `artifacts/goal/HS-COTTAGE/renders/` (`tools/render_hs_cottage.gd`,
not headless).

Blind review round 1 (renders/): eaves, door shelter, reads-as-cottage 3/3;
chimney clear on 8102 only, UNCLEAR on seeds 1 and 21325 (stack small, only
0.38 m over the ridge vertex). Fix: `HouseGeometry.stack_extra` raises a
cottage stack 0.7 m (no draw; bound `roof_top_above_walls` follows), test floor
`STACK_CLEAR_MIN` 0.9 m with a farmhouse control. Round 2 renders (full stack
in frame, plus a `_hearthwall` view): `artifacts/goal/HS-COTTAGE/renders2/`.

Reviewer tick: DONE 2026-10-24 — round 1 chimney 1/3; round 2 (80e52d2) 3/3, storey 3/3, door shelter 3/3.

## farmhouse (HS-FARMHOUSE)

Traits: (1) the kitchen or store has an exterior door onto a yard on a side or
rear facade, not the front; (2) an attached outbuilding (byre) under its own,
lower roof; (3) the yard carries at least 3 kinds of working props from fence,
cart, hay, trough, sacks.

Measured first (40 seeds, 8 x 10 m, one storey): the style row drew
`back_door` at 0.55 through the generic rule (about 45 percent had a yard
door, always on the rear wall); no outbuilding existed; the yard held a cart
and the produce sacks (`Bag`) on the service wall, plus a woodpile and midden
that are not on the trait list, so only 2 of the 5 kinds.

Built: `HouseGenerator` forces `back_door` for a farmhouse with 3 or more rooms
(the 0.55 draw is still consumed, so no later roll moves). `HouseYard` gains a
`byre` group (`_byre`): an open-fronted lean-to against a side or rear wall, its
own `byre_roof` (surface roof, high edge 2.2 m, pitched away from the wall, so
lower than the 2.6 m eave) on two posts, with five hay bales. The `farmhouse`
style groups become byre, cart, trough (three slots, replacing woodpile,
cart, midden for a no-trade farmhouse; a farmer trade keeps its own recipe).
Kinds present on all 40 seeds: hay, cart, trough, sacks. No fence is claimed.
Hay is emitted on the roof (thatch) surface so it reads as straw; the trim
material ignores vertex colour, so a tint was not possible. Round 2 (blind
review round 1: byre 3/3, props NO, back door UNCLEAR): the cart is a built
two-wheel farm cart with shafts and a hay load (`_farm_cart`, piece kind `cart`,
group `farm_cart`) replacing the `Dungeon_Cart` box; the farm trough stands on
four legs (no water inset: no surface takes a blue). No catalogue model for
hay, barrow or trough exists. Renders2 frame the yard door with byre, cart
and trough, and the kitchen view stands on the side away from the hearth.
Round 2 renders: `artifacts/goal/HS-FARMHOUSE/renders2/`.

Test: `tests/house_farmhouse_traits_test.gd` (31 checks) over the frozen
requests `house/farmhouse/{1,8102,21325}`; controls: back door removed, yard
door moved to the front wall, byre removed, yard stripped to the byre alone.
Keys added to `HouseTraitMeasure.measure`: `back_door_room`,
`back_door_off_front`, `byre_*`, `yard_kinds`.

Renders for review: `artifacts/goal/HS-FARMHOUSE/renders/` (round 1; `tools/render_hs_farmhouse.gd` now writes renders2/,
not headless): `_front` three-quarter, `_rear` three-quarter from the byre
side, `_interior` eye level toward the kitchen's yard door (the hearth breast
partly screens the door in some seeds).

Reviewer tick: DONE 2026-10-24 (coordinator). Round 1: byre 3/3, yard props NO
(hay read as white cubes), back door UNCLEAR. Round 2 (c7e9745, renders2): back door
plain in all three interior views, byre 3/3, straw bales + shafted cart + sacks read.
Weak: the trough still reads as a plain box with no water.

## townhouse (HS-TOWNHOUSE)

Traits: (1) two or three storeys, the street frontage (the entrance facade)
narrower than the depth; (2) one stair from the entry reaches every floor, with
a foot and head landing and a window in the landing room on each; (3) the
ground floor holds the shop or work room and no bedroom, the beds are above.

Measured first (40 seeds, 8 x 10 m, request storeys 1): frontage 8 against depth
10 on 40 of 40; every house was ONE storey (the row had no `min_storeys`, only
the rich row did), so there was no stair; the ground held hall, bedroom, kitchen.
Work room: none (the office is in the programme but the one-storey plan kept
the bedroom instead).

Built, as style constants with no new random draw: the townhouse row gains
`min_storeys: 2` (the existing generator floor) and `beds_upstairs: true`.
`HousePlanLevels.move_beds_upstairs` (called by `HousePlanner.plan` after the
upper storeys are cloned and named) renames each ground-floor bedroom of a
`beds_upstairs` house to office (the work room), else workshop, parlour or
store, once a bed is known to stand above. Only a no-trade townhouse is changed: a
trade townhouse keeps its own programme (with the innkeeper 13 x 16 m seed 32102
of `hmultistory` the rename makes the kitchen seat count fail, a furnishing
sensitivity not chased here; such a house can still have a ground bedroom). The partition and stair do not move:
a first attempt that dropped bedrooms from the ground programme re-flowed the
ground floor and left some upper floors with only thin rooms and no bedroom
(programme sweep seeds 41050, 41170). Upper storeys keep their own naming (2
bedrooms above on 40 of 40 seeds at 8 x 10 m), and the stair, landings and
windows come from the domestic stair profile already in place. Three storeys also hold, tested at seeds 1, 8102 and
21325.

Consequence, fixed: `min_storeys` also lifts trade townhouses to two storeys, so the
feng shui sweep seed 60002 (townhouse, alchemist, once one storey) failed `sconce_pair`
in the ground workshop. Cause: the door swing cut one of the mirrored lamp stations
(`_blocks_domestic_threshold`), so the furnisher found no pair anchor and hung the
second lamp on another wall, while the check (which ignores the swing) still saw a
pair that fitted. `HouseFurnishSurface.place_mounted` now keeps the one lamp and notes
`sconce_pair:no_safe_mirrored_station` in every room of an ordinary house, as it already
did for the hall. The check is unchanged. Round 2 renders (upper bedroom with its bed,
per seed): `artifacts/goal/HS-TOWNHOUSE/renders2/` (`tools/render_hs_townhouse_beds.gd`).

Test: `tests/house_townhouse_traits_test.gd` (58 checks) over the frozen requests
`house/townhouse/{1,8102,21325}` (the 8102 row existed; 1 and 21325 added),
plus the same three at three storeys. Controls: spec back to one storey, width
and length swapped, stairs removed, head landings removed, upper windows
removed, the office turned into a bedroom. Keys added to
`HouseTraitMeasure.measure`: `frontage`, `depth`, `frontage_narrower`,
`room_storeys`, `ground_work`, `ground_bedrooms`, `upper_bedrooms`,
`spine_storeys`, `spine_landings`, `spine_lit`.

Note for LHS-STAIRS (a domestic stair profile for multistorey requests): the
townhouse already runs the domestic profile (`domestic_profile: true`, foot and
head landing rectangles) at 2 and 3 storeys through `HousePlanLevels`; the
spine keys above are a ready check for it.

Renders for review: `artifacts/goal/HS-TOWNHOUSE/renders/` (`tools/render_hs_townhouse.gd`,
not headless): `_front` roof-on three-quarter, `_workroom` ground floor eye level,
`_stairfoot` the spine from the entry hall, `_landing` the upper landing
looking back at the stair opening.

Reviewer tick: DONE 2026-10-24 (coordinator). Round 1: storeys/frontage YES, stair spine with landing and windows YES, beds above UNCLEAR (no bed in view). Round 2 (36f16b5, renders2 `_bedroom`): a bed upstairs reads plainly; ground office as work room. 3/3.

## longhall (HS-LONGHALL)

Traits: (1) the footprint is at least 2.5 times as long as it is wide, one
storey under one main roof; (2) an open fire near the middle of the hall, with a
smoke hole and louvre in the roof above it; (3) no ceiling over the hall, the
trusses and rafters are in view from the floor; (4) benches along both long
walls, private rooms only at the ends.

Measured first (40 seeds, 8 x 10 m, one storey): ratio 1.25; the plan was a
5-room front-hall grammar (the hall a 3.8 m band across the front, kitchen,
store, workshop and bedroom stacked behind it); the hearth stood in the kitchen
against a wall with a chimney; the whole storey was under one plaster ceiling;
no benches; no smoke hole. Only "one storey under one main roof" held.

Built (all in the plain `longhall`, no trade, no world family, no shop spec;
`HouseLonghall` in `src/house/house_longhall.gd`, plan data in `plan.longhall`):
- Size: `HouseGenerator.generate` calls `HouseLonghall.clamp_size` (pure
  arithmetic, no draw): one storey, the long side on X, ratio at least 2.8 (the
  trait asks 2.5), short side 5.5 to 8 m. The default 8 x 10 m request therefore
  builds 15.4 x 5.5 m. The front door stands in the middle of a long wall.
- Plan: `HousePlanRooms.subdivide` tiles the interior with the hall in the middle
  (the whole depth, about half the floor) and a room at each end: the sleeping room
  at one end (the end swaps with the seed's parity, as the ordinary layout
  mirrors), the work room (front) and the store (back) at the other. Cooking is
  shared in the hall (no kitchen room). The wall hearth, its focus and the
  chimney are cancelled (`HouseLonghall.prepare`), as are dormers.
- Fire: `hearth_kerb` stones round an ash bed on the hall floor, half way along
  (builder, `_build_longhall_floor`); crossed logs, flames, embers and an omni
  light are added by `HouseAssembler._longhall_fire`. A keep-clear "open hearth"
  zone in `plan.zones` keeps furniture off it.
- Smoke: a roof opening `longhall_smoke_hole` over the fire, derived in
  `HouseGeometry.roof_openings` (never stored); a slatted louvre with a small
  hood stands on it (`_build_longhall_louvre`). `roof_top_above_walls` and the
  bound follow (`HouseLonghall.LOUVRE_TOP`).
- Open roof: `_build_ceiling` ceils only the end rooms (`_build_longhall_ceilings`);
  over the hall `_build_longhall_roof` emits arch-braced collar trusses on wall
  posts and corbels, a ridge beam, two purlins and common rafters, and a screen
  filling each end partition up to the roof. The chandelier a hall normally gets
  is removed (nothing to hang from).
- Benches: `HouseLonghall.prepare` reserves a strip along each long wall (keeping
  out of every door's clear floor); `HouseLonghall.seat`, called after the
  furnisher, stands real `Bench` props (rescaled 0.82 to 1.2) in the free runs,
  seats toward the fire.

Test: `tests/house_longhall_traits_test.gd` over the frozen requests
`house/longhall/{1,8102,21325}` (8102 existed; 1 and 21325 added, all 8 x 10 m).
Controls: a farmhouse of the same size, a ceiling put over the hall, the smoke
hole moved off the fire, the fire pushed into a corner, the back-wall benches
removed, a room put beside the hall, the hall made too short for any truss.
Keys added to `HouseTraitMeasure.measure` (furnished plan needed for the
benches: the new `furnished` argument): `long_ratio`, `main_roofs`,
`hall_fraction`, `hall_full_depth`, `hall_length`, `rooms_off_ends`, `end_sides`,
`private_kinds`, `hearth_gap`, `hearth_mid_offset`, `hearth_kerb_count`,
`hearth_wall_fire`, `smoke_hole`, `smoke_over_hearth`, `louvre_over_ridge`,
`ceiling_over_hall`, `ceiling_over_ends`, `truss_count`, `rafter_count`,
`has_ridge_beam`, `bench_walls`, `bench_front_len`, `bench_back_len`.

Renders for review: `artifacts/goal/HS-LONGHALL/renders/`
(`tools/render_hs_longhall.gd`, not headless), per seed: `_exterior` roof-on
three-quarter, `_louvre` the smoke louvre on the ridge, `_interior` eye level
down the hall, `_roof` looking up into the open roof, `_plan` roof off from above.

Known sides: the benches are warned by the furnishing check as "not at any table"
(they stand at the walls, the table stands near the fire); the village programmer
gives `longhall` to the norse culture, so a norse lot now holds a 15.4 x 5.5 m
footprint for an 8 x 10 m request.

Reviewer tick: DONE 2026-10-25 (coordinator): long narrow hall, central fire on a kerb under a ridge louvre, open trussed roof over the hall, benches on both long walls; 4/4 on seeds 1, 8102, 21325.

## rich (HS-RICH)

Traits: (1) the front door opens into a hall that holds the main stair; (2) a
separate parlour (a seating group) and dining room (a table with at least four
chairs); (3) every cornice and string-course component lies within 0.15 m of a
floor line or the eave.

Measured first (rich at the old fixture size 8 x 10 m, seeds 1..20 plus 8102 and
21325, two storeys by `min_storeys`): (1) HELD. The door opened into the hall and
the domestic stair started there (LHS-STAIRS, 3ae7d20). (2) MISSING. No room
was a `dining_room`; the table stood in the hall with 2 chairs (4 on 2 of 20
seeds, 6 on none); the parlour held ONE bench; 8 of 20 seeds had no fourth ground
room at all. (3) MISSING in a way the old bound hid: the crown was hung from
`spec.height * level`, the first-floor line, not the eave. A two-storey rich house
had its cornice AND its string course both at 2.24..2.6 m on the ground-floor
head, and no ornament at the real eave (5.2 m). The cornice sat within 0.15 m of
a floor line by accident, so a pure distance test would have passed it; the
measure also asks for the crown's top to stand at the eave (`cornice_top_gap`).

Built, all style constants with no random draw (a row without the keys is
untouched):
* `rich` row: `domestic_program [hall kitchen parlour dining_room]` (beds go
  above, as in the townhouse), `dining_seats 4`, `sitting_group true`.
  `_compact_backness(kitchen)` is 4 for rich, so the formal rooms take the front
  and the kitchen the back wall (without it the `poles sweep` back-door-on-kitchen
  gate of `lane:house-plan-fast` fell from 20 to 19 of 24, one rich scholar house).
  `HouseFurnisher._household_seat_capacity`
  lays at least `dining_seats` chairs. `_sitting_parlour_recipe(plan)` seats a
  `sitting_group` parlour with two settles instead of one.
* The default rich footprint is now 9 x 11 m (was 8 x 10): the domestic grammar
  needs 6.0 m behind the entry hall for two rows of rooms and an 8 x 10 house
  has 5.7 m, so hall + kitchen + parlour + dining room cannot all sit on the
  ground floor. 9 x 11 holds the four rooms on 40 of 40 seeds (100..139). The three
  frozen requests `house/rich/{1,8102,21325}` are 9 x 11 (the 8102 row was
  8 x 10; `shop_shell/rich/8102` is a shop and unchanged).
* `HouseBuilder._build_rich_cornice` now hangs the crown from the TOP storey's
  eave (`height * storeys`), each of its three steps running down from the eave
  (bed full height, corona two thirds, crown one third, tops staggered 30 mm so
  no two boxes share a top plane; the `CORNICE_*` outs are unchanged, so the
  bound is). Before, the stacked steps ended 0.24 m from the nearest level.

Test: `tests/house_rich_traits_test.gd` over the frozen requests; keys
`HouseTraitMeasure` `door_room_kind hall_holds_stair parlour_rooms dining_rooms
parlour_seating dining_tables dining_chairs rooms_distinct dining_table_elsewhere
trim_count trim_worst cornice_top_gap` and the static `trim_off_level(log,
height, storeys)`. Controls: stair removed, stair not starting in the hall, the
hall renamed, the dining room renamed to a parlour, parlour seating removed,
chairs cut to two, the table removed, every trim part dropped 0.6 m, and a log
with no trim.

Known weakness, not chased: the dining room is a 2.8 to 3.3 m wide strip, and
a long table fills it; and the upper storey names rooms from the landing outward
(parlour, store, parlour, bedroom), so a rich house has one bedroom above.

Renders for review: `artifacts/hs_rich/renders/` (`tools/render_hs_rich.gd`, not
headless): `rich_<seed>_front` roof-on three-quarter, `_hall_stair`, `_parlour`,
`_dining_room` at eye level, seeds 1, 8102, 21325.

Fingerprint (`tools/fingerprint_houses.gd`, five older styles, HEAD worktree vs this tree): 130 lines, identical. `lane:house-exterior-fast` has one failure, `witch_hut/none rotated=false no exterior dressing`, that fails identically at HEAD (`hexterior` in the base worktree).

Independent reviewer: fresh agent, from the renders of commit 41e0ad3 (2026-10-25). Judged only from `artifacts/hs_rich/renders/rich_<seed>_{front,hall_stair,parlour,dining_room}.jpg`.

| seed | (1) door hall holds stair | (2) parlour + dining room, 4+ chairs | (3) trim on floor lines / eave |
|---|---|---|---|
| 1 | YES | YES (borderline) | YES (borderline) |
| 8102 | YES | NO | YES (borderline) |
| 21325 | YES | YES (borderline) | YES (borderline) |

Reasons:
* (1) all three: the hall view shows a flight with rails rising from a floor with wall lights, windows and a chest or bench; the front door itself is not in any hall frame, only the porch in the exterior, so "door into the hall" is inferred from the porch position. Seed 1 stair is in a plain narrow hall; 8102 and 21325 are clear.
* (2) seed 8102 MISS: the dining view shows a long laid table with two stools on one side and nothing else; no set of four chairs can be seen (the far side of the table is out of frame, and what is seated are stools, not chairs). Cannot tick what is not seen. Seed 1 and 21325: four chairs in a row along one side of the table, one table, a distinct room: tick. Borderline in all seeds: the parlour is two long bare benches facing each other down a corridor-like room (plus a cabinet on seeds 1 and 21325); it reads as a waiting passage, not a seating group of settles around a hearth. Seed 8102 parlour has no other furniture at all.
* (3) a thin horizontal band at the eave under the gable and a string course at the first-floor line are plainly visible on all three fronts (21325 has the storey line on stone with a notched course). Borderline: both are thin flat bands; neither reads as a projecting cornice crown, and no band shows at the ground-floor head or above the plinth.

Images: `artifacts/hs_rich/renders/rich_1_front.jpg`, `rich_1_hall_stair.jpg`, `rich_1_parlour.jpg`, `rich_1_dining_room.jpg`; the same four for `8102` and `21325`.

Open:
* Seed 8102 dining room: only two stools in view, no four chairs visible (trait 2 not met by the image).
* All seeds: the parlour has no recognisable seating group, only two bare benches; the trait is held on the letter, weakly on the look.
* All seeds: the front door is not shown opening into the hall; trait 1 rests on the porch plus the hall view.
* All seeds: the cornice is a plain thin band, not a visible crown.

Observed (not traits):
* Dining room and parlour are 2.8 to 3.3 m strips that read as corridors; the table fills the width and leaves one chair-width of walkway (seed 1, 21325).
* Dining table: a long grey strip crosses the tabletop through the plate (seeds 1, 8102, 21325), reads as a mis-scaled runner or knife clipping the plate.
* Parlour benches on the near side look cantilevered and oversized, a bench end overhanging past its legs (seeds 8102, 21325 right bench is two planks with a step).
* 8102 and 21325 dining: a chair or barrel back clips the camera in the foreground; objects at the room edge crowd the door swing.
* Seed 1 front: no chimney visible, only two thin poles on the ridge and gable; 8102 has a very tall detached-looking stone stack; 21325 has a blank stone ground floor.
* 21325 hall: a chandelier hangs low against the stair wall, and the stone-faced hall wall differs from the plaster of the other seeds.
* No z-fighting or floating furniture otherwise seen.
