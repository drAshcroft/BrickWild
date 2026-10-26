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

Test result: `tests/house_minka_traits_test.gd` 106 checks, 0 failures. Lanes run on the
change: `lane:geom` (11 suites, 9810 checks), `lane:house-exterior-fast` (4794), `lane:house-plan-fast`
(322), `lane:house-furnish-fast` (242), `hvernacular`, `hbounds`, `cultureapi`, `vcompact`.
`tools/fingerprint_houses.gd` (130 lines, five long-standing styles) is identical against HEAD.
Two suites were changed for the new vocabulary: `qa/vernacular_house_check.gd` counts `engawa`
as a vernacular switch, and `tests/suites/house_qa_suite.gd`'s poles sweep does not take a
screen door for the back door; `qa/house_yard_check.gd` matches yard parts at `-floor_raise`.

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

First review (354ff25, from the renders of 41e0ad3) failed seed 8102 trait 2 (dining room showed only two stools) and passed the parlour only on the letter.

Independent re-review: fresh agent, from the renders of commit 41f66c2 (renders written 2026-10-25 10:46-10:47, after the 354ff25 review; all 12 images opened). Judged only from `artifacts/hs_rich/renders/rich_<seed>_{front,hall_stair,parlour,dining_room}.jpg`.

| seed | (1) door hall holds stair | (2) parlour + dining room, 4+ chairs | (3) trim on floor lines / eave |
|---|---|---|---|
| 1 | YES (borderline) | YES (parlour borderline) | YES (borderline) |
| 8102 | YES | YES (parlour borderline) | YES (borderline) |
| 21325 | YES | YES (parlour borderline) | YES (borderline) |

Reasons:
* (1) the hall frames show a flight with rails in a hall with wall lights, windows and a chest; the front door itself is in no hall frame, only the porch on the front render, so "door opens into the hall" is inferred. Seed 1 is the weakest: a plain narrow corridor with the flight on the right, no chest or door in view.
* (2) dining, all three seeds: one long table, four `Chair_1` chairs counted in the image (seed 1: three near side plus one at the far end; 8102: three near plus one far; 21325: three near plus one at the end by the window). The 8102 miss is fixed. Parlour, all three: a chair, a long bench and a high-backed settle in a 5 x 3 m room; they are recognisable seating but spread out along the walls, not facing, no hearth or rug, so it reads as scattered seating rather than a group. Held, weakly. Two distinct rooms in every seed (separate views, different furniture).
* (3) a band at the eave under the gable and a string course at the first-floor line are visible on all three fronts (21325 stands the storey line on a notched stone course). Borderline: thin flat bands, not a projecting cornice crown.

Images: `artifacts/hs_rich/renders/rich_1_front.jpg`, `rich_1_hall_stair.jpg`, `rich_1_parlour.jpg`, `rich_1_dining_room.jpg`; the same four for `8102` and `21325`.

Open:
* All seeds: the parlour is chair + bench + settle spread along the walls, not a facing group; trait 2 holds on a loose reading.
* All seeds: the front door is not shown opening into the hall; trait 1 rests on the porch plus the hall view.
* All seeds: the cornice is a plain thin band, not a visible crown.

Observed (not traits):
* Parlour 21325: a large wooden post (a timber or newel) fills the left foreground and blocks a third of the frame; the camera stands against it.
* Parlour 8102 and 1: the long bench's near end hangs past its pedestal, reading as cantilevered; 8102 also has a chest in the parlour.
* Dining tables carry an oversized grey cooking pot and a grey strap that crosses the tabletop (all seeds).
* Dining 1 and 8102: the timber-slat wall has open gaps that show the room beyond; the dining room is a narrow strip with a barrel in the corner.
* Seed 1 front: no chimney, only two thin poles on the ridge; 8102 has a very tall stack standing off the gable; 21325 has a blank stone ground floor with a small stack.
* 21325 hall: a chandelier hangs low over the stair, and the stone-faced hall wall differs from the plaster of seeds 1 and 8102.
* No floating furniture or z-fighting seen.

Round 2 (fixes after the 41e0ad3 review): seed 8102's dining table was laid with 4 STOOLS (the seat-set probe fell back to `Stool` when `Chair_1` did not fit that table pose; the earlier test counted any `seat`). A style with `dining_seats` now skips `Stool` in `_seating_probe`, and the test counts `Chair_1` keys (`dining_chairs`, with `dining_stools` reported). Plan chair counts, before: seed 1 4 chairs, 8102 4 stools / 0 chairs, 21325 4 chairs; after: 4 / 4 / 4 `Chair_1`. The parlour's two facing benches are replaced by a conversation group: one settle on the wall, a chair beside it and a chair on the end wall (`sitting_group` recipe; the test asks for 1 settle + 2 `Chair_1`, controls: seating removed, chairs turned to stools, dining stools). The review camera now stands in the room corner furthest from any piece (`_look_room`). Left alone: the grey runner on the tabletop is the measured `tableware` model, not a mis-scaled prop (not trivial). Parlour group remains modest: chair, settle, chair spread over a 5 x 3 m room.


## mediterranean (HS-MEDITERRANEAN)

Traits: (1) lime-rendered masonry (white or ochre) with wall reveals at least
0.30 m deep; (2) a terracotta tile roof at 25 degrees or less, or a flat terrace
with a parapet; (3) a loggia, pergola or covered terrace at the entry or garden
side; (4) an open courtyard or roof terrace when the footprint allows (the
threshold is recorded below).

Measured first (8 x 10 m, one storey, seeds 1, 8102, 21325): (1) HELD. Cream to
ochre `e8dabf` / `eee3cc` / `e6d8bb`, no timber, no stone ground floor, wall 0.45 m
(`wall_t`), every window and exterior door jamb 0.49 m deep. (2) MISSING. The
roof faces fell 27.1, 27.3 and 32.4 degrees (the row drew pitch 0.5 to 0.75); the
terrace alternative held on one seed in three (`parapet` 0.7: seed 1 only). (3)
MISSING. `veranda` was 0.0 and the porch 0.35: no seed had a covered entry
except a small porch on seed 1. (4) MISSING. No court, no roof terrace, no walled
ground at all; only the two-group yard (fenced kitchen bed, a few crates).

Built (style constants, no random draw is added or moved; the row's draws are
still taken):
* Roof: `roof_pitch` [0.32, 0.44] (was [0.5, 0.75]). On the faces that is 17.5,
  17.7 and 20.6 degrees on the three seeds; any seed stays under 25 because the
  rise is measured over the run to the eave and the pitch cap is tan 25 = 0.466.
  The `parapet` chance (0.7) is untouched; the test accepts either alternative.
* Loggia: `veranda` 1.0 and `porch` 0.0 in the `mediterranean` row. The existing
  veranda (deck, four posts, head beam, falling rooflet, `veranda_rect` already in
  the bound) is the covered entry: 1.4 to 1.7 m deep over the entrance door.
* Court: `HouseYard` group `court` (`_court`, a built piece of kind `court`), first
  in the style's yard groups: a rendered rear wall and two returns that continue
  the house's side walls outward (0.3 m thick, 1.7 m high), a gateway 1.2 m wide in
  one return (on the side the yard's own rng prefers, because the rear wall stands
  at the envelope's edge and nothing can walk round it), paving, open to the
  sky, about 8 x 2.65 m (21 m2) on an 8 x 10 house. The mediterranean yard apron
  is 3.0 m (was 2.4, still inside the 2 to 3 m contract) to hold it.
* The rear door: `back_door` is `room_count >= 3` for mediterranean as it is for
  the farmhouse (the draw is still taken), so the court is entered from the house.
* Door approach: a door that opens onto the court (`HouseYard.opens_on_court`)
  reserves 2.0 m (`COURT_DOOR_APPROACH`) in `HouseExterior.facade_clear`, not the
  usual 3.2 m, because the court's own rear wall stands about 2.7 m out. Every
  other door in every other house is unchanged.

Threshold recorded: a court is built only when the house's shorter side is at
least `HouseYard.COURT_MIN_SIDE` = 7.0 m, there is `COURT_MIN_DEPTH` = 2.4 m clear
behind the rear wall, and the yard check finds the ground clear (so an 8 x 10 m
house has one, a 6 x 8 m house has none and keeps the render, the low roof and the
loggia). No roof terrace is built: the court is the open outdoor room.

Test: `tests/house_mediterranean_traits_test.gd` (94 checks) over the frozen
requests `house/mediterranean/{1,8102,21325}` (8102 existed; 1 and 21325 added, all
8 x 10 m). Keys `HouseTraitMeasure` `wall_kind wall_rendered wall_thick reveal_min
roof_angle_deg roof_tile roof_terracotta parapet_count terrace_roof low_tile_roof
loggia_posts loggia_roofs loggia_beams loggia_covers_door loggia_depth
court_expected court_min_side court_present court_inner_area court_wall_parts
court_open court_gate court_rear_wall court_door` (the roof angle is the angle of each
roof face's own plane, not of an edge: a hip face's edges are shallower than the face).
Controls: timber frame, green wall, a 0.12 m wall (reveals), a steep roof, a slate
roof, no veranda, the court removed, a roofed court, a court with no rear wall, no
rear door; and the 6 x 8 m footprint with no court.

Known sides: the loggia is the shared veranda emitter, so it reads as a timber
verandah with a shed rooflet (teal posts and beam) more than a masonry arcade;
the court is a plain paved room with no planting of its own (the garden group
now stands beside the house); `lane:village-fast` was not run for the apron change
(3.0 m for mediterranean lots).

Renders for review: `artifacts/hs_mediterranean/renders/` (`tools/render_hs_mediterranean.gd`,
not headless), per seed: `_front` roof-on three-quarter of the entrance side, `_rear`
roof-on three-quarter of the court, `_loggia` eye level three metres out, `_court`
eye level inside the court, `_interior` eye level through the rear door.

Independent reviewer: fresh agent, from the renders of commit 82b461c (all 15 images opened). Judged only from `artifacts/hs_mediterranean/renders/mediterranean_<seed>_{front,rear,loggia,court,interior}.jpg`.

| seed | (1) lime render, deep reveals | (2) low tile roof or parapeted terrace | (3) shaded outdoor room | (4) court / terrace |
|---|---|---|---|---|
| 1 | YES (borderline) | YES (hip roof inside a white parapet) | YES (borderline) | YES |
| 8102 | YES (borderline) | YES (shallow gable) | YES (borderline) | YES |
| 21325 | YES (borderline) | YES (shallow gable) | YES (borderline) | YES (interior view unusable) |

Reasons:
* (1) pale cream/white render, no timber frame, on all fronts. Reveals read on the court door and the court-side windows (shutters stand proud, frames recessed), but on the front windows the depth is modest and cannot be read as 0.30 m. A stone-block plinth runs round the whole ground floor (a visible stone course under the render), so "render, no stone" is true of the walls, not of the base.
* (2) terracotta tiles with visible courses; 8102 and 21325 are shallow gables, seed 1 is a hip sitting inside a flat white parapet with an orange band (the parapet alternative also shows). Pitch looks low on all three.
* (3) the loggia is four teal posts, a head beam and a small orange shed rooflet over a paved deck in front of the door. It is a covered entry, but it is a timber verandah, not a masonry loggia. The rooflet is short and sits inside the beam line (posts pass through it), so the shaded area is a strip about one door wide. Weak, held on the letter.
* (4) a white walled paved court, about 2.7 m deep, open to the sky, with a gateway in one return, reached from the rear door (seeds 1 and 8102 show the door opening onto the paving; the seed 1 court frame shows the door at the far end). No planting, furniture or shade in it; a bare paved corridor. Held on the letter.

Images: `artifacts/hs_mediterranean/renders/mediterranean_1_front.jpg`, `_rear`, `_loggia`, `_court`, `_interior`; the same five for `8102` and `21325`.

Open:
* All seeds: the loggia is a timber verandah with a small rooflet, not a masonry arcade; shade covers only a strip in front of the door (trait 3 borderline).
* All seeds: the court is a narrow bare paved passage with nothing in it (no planting, table or pergola); it is an enclosure, not a lived outdoor room (trait 4 borderline).
* All seeds: window reveals do not read as deep from the front; a stone plinth shows under the render (trait 1 borderline).
* Seed 21325 interior: the camera sits inside or against a solid piece (teal slab above and below, a black block on the left, dithered cream strip); the frame shows nothing about the house. The interior view is not judgeable for this seed.
* Seed 8102 interior: the frame is a doorway looking out to the court, not a room; it shows no furniture.

Observed (not traits):
* Rear renders (all seeds): the court's near rear wall seems to hover; its cast shadow lies far below and to the right of it, detached from its foot, and the wall's near end meets no gate post. Likely a wall at the envelope edge seen from above, but it reads as floating.
* Front renders: the white parapet/eave band on seed 1 hides the roof from low angles; a bench stands against the front wall on all seeds, a blank stone plinth with no door-side landing.
* Loggia renders: the rooflet's posts pierce it (the four posts pass through the orange slab); a small grey object floats in the gap between the post and eave at left in 8102 and 21325 (a distant prop seen through the gap, or a floating item).
* Seed 1 interior: a very large hearth, table and bowl fill the frame; the bowl sits large against the table (prop scale).
* Seed 1 and 21325 front: the hanging lamp glow at the left gable end is bright and blows out the wall.

## thatch_cottage (HS-THATCH)

Traits: (1) thatch eaves at least 0.4 m thick, soft-edged, with a combed ridge
roll; (2) at least one eyebrow dormer swept out of the thatch; (3) pale rendered
cob walls with no visible timber-frame components; (4) a front garden with flower
beds and a path to the door, no work-yard props at the front.

Measured first (8 x 10 m, one storey, seeds 1, 8102, 21325): (1) PARTLY. The
eave was a plain box 0.45 m wide and 0.34 m high (hard edges, 90 degree corners,
under the 0.4 m) and the ridge roll 19 triangular fins; the roll was combed but
nothing was soft. (2) MISSING. `dormers` 0.2 and a dormer only ever stands on a
house of two storeys or 12 m; a one-storey 10 m cottage never had one, and the
real dormer is a gabled box with cheeks, not thatch. (3) PARTLY. Pale cream wall
colour on all three, but `timber` 0.55 framed seeds 1 and 21325 (49 and 56 timber
parts, gable ties and members, interior frame posts); seed 8102 was bare. (4)
MISSING. Yard: path, the fenced kitchen bed (behind), a washing line, and the
porch pail at the front; no flower bed anywhere.

Built (style constants, no random draw added or moved):
* Soft thatch: `HouseGeometry.thatch_soft()` (the Witch hut and `thatch_cottage`
  only; cottage, farmhouse, longhall and african keep the box eave and fin roll,
  unchanged). The cottage's eave is an ellipse 0.34 x 0.26 m (0.52 m through, 14
  profile points) centred 0.32 m in from the roof edge, so its reach stays inside
  the edge and the plan bound loses nothing; the ridge roll is a saddle (nine-point
  half-ellipse crown 0.30 m over the ridge, skirts flared down both slopes and buried
  in the thatch), 19 bundles spanning the whole ridge. The Witch hut keeps its own
  profiles; its code path is the same.
* Cob: the row's `timber`, `braces`, `rail`, `jetty` and `stone_ground` are 0.0 (the
  draws are still taken).
* Eyebrow dormer: `eyebrow` 1 in the row, read into `HouseSpec.eyebrows` with no draw.
  `HouseGeometry.eyebrow_sites()` (pure) puts it on the slope on the door's side of the
  ridge at the door's end (the entrance of this style is in a gable end), clear of the
  chimney and of any real dormer. `HouseBuilder._build_eyebrows` emits it as host
  `eyebrow_N`: a level half-barrel of thatch, 2.0 m wide and 0.95 m high at the mouth,
  coming out of the slope (a thin arched lip and a body 1.6 m long behind it, buried in
  the slope), with a dark window 1.1 x 0.46 m in the mouth under the brow. No cheeks,
  no gable, no wall: the thatch is the dormer. It stays below the ridge.
* Front garden: yard group `front_beds` (first in the style's groups, the kitchen
  garden behind it): a flower bed (`bed` piece with boards and soil, three flower
  clumps standing on it) on each side of the path, found by walking outward from the
  path until clear (a facade bench stood exactly where the first bed would go on
  all three seeds). The washing line and woodpile are no longer in the style's
  groups and the porch pail is not planned for this style, so nothing of a work
  yard stands at the front.

Test: `tests/house_thatch_traits_test.gd` (94 checks) over the frozen requests
`house/thatch_cottage/{1,8102,21325}` (8102 existed; 1 and 21325 added, all 8 x 10 m).
Keys `HouseTraitMeasure` `wall_pale wall_rendered frame_parts eave_count eave_form
eave_points eave_thick eave_turn_max roll_count roll_points roll_turn_max roll_cover
roll_height eyebrow_count eyebrow_glazing eyebrow_width eyebrow_rise eyebrow_seated
eyebrow_below_ridge eyebrow_faces_entrance eyebrow_clear_of_chimney path_pavers
path_reaches_door flower_beds flower_bed_sides bed_flowers front_roles`. Softness is
the sharpest turn of the profile outline (60 degrees at most; a box is 90); the buried
vertices of the ridge saddle are left out. Controls: the same plan built as a
`farmhouse` (box eave 0.34 m, fin roll, no eyebrow), `thatch_roll` off, eyebrows 0, a
timber frame, a dark wall, the beds removed, a crate at the front, the path removed.

Known sides: the interior still shows the exposed ceiling joists (not a wall frame);
the stone plinth shows under the cob; the eyebrow reads best from the side, as a
rounded bump with a window, and its window uses the same pale glazing as every other
window; the eave roll is a smooth bolster, not individually combed layers.

Renders for review: `artifacts/hs_thatch/renders/` (`tools/render_hs_thatch.gd`, not
headless), per seed: `_front` roof-on three-quarter from the eyebrow's side, high;
`_eyebrow` roof-on, lower and closer on the same side; `_garden` eye level from the
road; `_interior` eye level in the entrance room, looking at the door.

Independent reviewer: fresh agent, from the renders of commit fa87736 (all 12 images opened). Judged only from `artifacts/hs_thatch/renders/thatch_<seed>_{front,eyebrow,garden,interior}.jpg`.

| seed | (1) thick rounded thatch, ridge roll | (2) eyebrow dormer | (3) white cob, no timber frame | (4) flower-garden front |
|---|---|---|---|---|
| 1 | YES (borderline) | YES (borderline) | YES | YES (borderline) |
| 8102 | YES (borderline) | YES (borderline) | YES | YES (borderline) |
| 21325 | YES (borderline) | YES (borderline) | YES | YES (borderline) |

Reasons:
* (1) the eaves are a clearly rounded bolster, roughly a thick log of thatch, with round-ended gable verges; the ridge carries a visible roll. But the roll is a row of separate bundles with dark notches between them, so it reads as a crenellated crest rather than one smooth saddle, and the thatch surface is flat horizontal courses, not combed. Held on the letter.
* (2) one small domed bump on the entrance-side slope with a window under it, below the ridge, no cheeks or gable wall. But the window is a flat pale-blue rectangle with square corners lying in the slope; the thatch does not sweep over it in a curve, and from the front it is small (about a window wide). It reads as a low hooded hatch, not a flowing eyebrow. Borderline on all seeds.
* (3) smooth white/cream walls on every elevation, no frame members on the walls. Brown frames on windows and doors, a porch of dark posts, a stone-block plinth round the base, and exposed ceiling beams indoors are not wall framing. The wall is plain white; it does not read as earthen (no undulation, no texture).
* (4) one raised bed with three flowers on each side of a paver path at the door, all three seeds. They are small and sparse (a single short bed each side), but they are flower beds along the path. A bench stands against the front wall on every seed.

Images: `artifacts/hs_thatch/renders/thatch_1_front.jpg`, `_eyebrow`, `_garden`, `_interior`; the same four for `8102` and `21325`.

Open:
* All seeds: the eyebrow's window is a flat rectangle and the thatch does not curve over it; the bump is small (trait 2 borderline).
* All seeds: the ridge roll is segmented into notched bundles, not a smooth roll (trait 1 borderline).
* All seeds: the walls are flat white with no earthen character; reads as plaster (trait 3 held on the letter).
* All seeds: the flower beds are two short boxes of three flowers; a thin garden (trait 4 borderline).

Observed (not traits):
* Long side wall (all seeds, front and eyebrow renders): a pale grey rectangular patch sits on the wall just under the eave, with a hard straight lower edge; it reads as a floating panel or a bad shadow.
* Garden renders (8102, 21325): a dark lintel bar floats a little above the front window, detached from the frame. Seed 1's window has no such bar.
* Garden renders (all seeds): small dark blocks hang under the eave ends at both gables.
* Seed 8102 front/eyebrow: a barrel, a bucket and a tub stand against the long wall at the left, loose on the grass; the tub is large against the bucket. They are at the side, not the front.
* The hanging lamp glow blows out the gable wall beside the door on all seeds.
* Seed 1 interior: a chest fills the lower right corner and a bed the lower left; the camera is cramped against them. Seed 21325 interior: a wardrobe fills the left; both are close-up but readable.
* Seed 1 front: the chimney is a thin pot on a block; on 21325 it is a small pipe, much slimmer than on 1 and 8102.


## asian -- the Japanese minka (HS-MINKA)

The style key stays `asian` (no API break); its label is now `Japanese Minka` and
its brief row in `docs/BUILDING_PERSONALITY_BRIEFS.md` says so.

Traits: (1) the floor raised at least 0.4 m on a stone plinth, with an engawa
(veranda) along at least one long side; (2) an irimoya (hip-and-gable) roof with
eaves at least 0.9 m deep; (3) sliding lattice screens on the veranda side; (4) the
main room opens onto the garden side.

Measured first (8 x 10 m, one storey, seeds 1, 8102, 21325): (1) PARTLY. A masonry
dwarf wall 0.75 to 0.93 m high stood round the walls, but the floor was at ground
level (a door cut straight through the plinth), and the "veranda" was a 4-post
shed-roof platform 1.5 m deep and 2 m wide on the ENTRANCE wall, at ground level,
not along a long side. (2) MISSING. A plain hip (`hipped`), eave 0.95 m on the sides and
0.85 m on the ends (it held the 0.9 m on the sides only), plus four swept-eave fins
(a Chinese form). (3) MISSING. Ordinary 0.95 m glazed windows with mullions. (4)
MISSING. The yard was a kitchen garden at the back, crates and a barrel; no room opened
onto anything.

Built (style row constants, no random draw added or moved; `asian` now takes the same
draws as before with different values):
* Irimoya roof: `RoofShape.faces(.., &"irimoya")`: four skirt planes (rising 0.2 of
  the rise, inset 0.3 of the half-span on every side) and two steeper gable planes
  above them; the two vertical hafu triangles are emitted by `HouseBuilder._build_irimoya_hafu`
  (a wall slab and a barge board along each sloping edge). `HouseGeometry.ridge_half_for`
  knows the ridge is shorter by the inset. Eaves: `span_out` 1.0, `along_out` 0.9 (0.9 is the least the trait allows, and a wider eave moved the east_asian compact village's common under its 70% standable share: 1.1 gave 66%, 1.4 gave 68%, 1.0 passes; see Open).
  Swept-eave fins, the chimney and the entrance-wall veranda are off in the row.
* Raised floor: `HouseSpec.floor_raise` (the plinth draw, 0.45 to 0.6 m; the dwarf wall
  is gone). The floor's underside stays at local y = 0 as everywhere in the house
  family; the ground is `floor_raise` BELOW it (same convention as `HouseSlope` and
  `HousePiles`). `HouseMinka` emits a stone stylobate under every exterior wall, stone
  steps (risers 0.17 or less) from every entry door to the ground, and the yard is
  emitted `floor_raise` lower. `HouseAssembler.build` lifts the shell and furniture by
  `floor_raise` so that the ground lands at the root's y = 0; the facade pieces and
  yard props stand at y = 0. `HouseGeometry.floor_raise()` is 0 on falling ground or
  piles. `exterior_bounds` reaches down to `-floor_raise`.
* Engawa: `HouseMinka.plan_engawa` (after the windows) picks the long side (never the
  entrance wall) whose room is the main room; a deck level with the floor, 0.8 m deep,
  the full wall long, on posts with stone footings under a head beam, the roof eave
  covering it; one flight of stone steps down to the ground off the end of the deck that is
  farther from the front door, running along the wall (a flight out from the middle squared
  every bound up to a deck 2 m deep).
* Screens: the windows of the engawa side become sliding lattice screens (window records
  with `screen: true`, sill 0, `balcony: true` so the planner's sill rule is unchanged);
  the main room (parlour, else hall) gets a wide (1.5 to 2.4 m) `screen` + `sliding` door
  onto the engawa, drawn with its panels pulled apart. A screen is a track, panels on two
  lanes (frame, paper, a lattice of bars on both faces). The kitchen keeps its windows.
* Garden: yard group `engawa_garden` (first in the style's groups): a `dry_garden` piece
  (gravel, raked lines, a stone edge) with three rocks, a tree and stepping stones from the
  engawa step, on the engawa side. `HouseExterior`/`HouseYard` know the engawa is built
  ground (no facade piece or prop stands on it; a screen door's approach is the engawa).

Test: `tests/house_minka_traits_test.gd` over the frozen requests `house/asian/{1,8102,21325}`
(8102 existed; 1 and 21325 added, all 8 x 10 m). Keys in `HouseTraitMeasure._minka_keys`
(see its header). Controls: floor on the ground, no engawa, a 2 m engawa stub, a plain hip,
a plain gable, a 0.35 m eave, glazed windows in place of screens, the screens cut into the
opposite wall, the screen door removed, the entrance room named as the main room, the garden
removed.

Known sides: the deck is one plank-textured slab (no board gaps); the gable (hafu) is plain
wall colour with no timber members; the panels of a closed screen are drawn but do not
animate; the interior has no tatami; the timber frame keeps the row's arch braces.

Renders for review: `artifacts/hs_minka/renders/` (`tools/render_hs_minka.gd`, not
headless), per seed: `_front` roof-on three-quarter from the engawa side, high; `_engawa`
roof-on, lower and closer on the same side; `_interior` eye level in the main room, looking
through its screen door onto the engawa and garden.

Open: the red suites seen on the way (witch_hut `henvelope` and `hvernacular`, `harchetype`
furnishing complaints for african/cottage/farmhouse/inn) are red on HEAD without this change
(`henvelope` and `vcompact` compared on a HEAD worktree); `harchetype` (254 red lines over every style, known red; the asian lines are the same
furnishing complaints, a table, a hearth, sparse halls at scales 0.75 to 1.9, and its `declared`
rule is fixed). The east_asian compact village is within 2 points of its
limit with a house this wide.

Independent reviewer: fresh agent, from the renders of commit 99925e6 (all 9 images opened). Judged only from `artifacts/hs_minka/renders/minka_<seed>_{front,engawa,interior}.jpg`.

| seed | (1) raised floor on plinth, engawa | (2) irimoya roof, deep eaves | (3) sliding lattice screens | (4) main room faces the garden |
|---|---|---|---|---|
| 1 | YES | YES | YES | YES |
| 8102 | YES | YES | YES | YES (borderline) |
| 21325 | YES | YES | YES | YES (borderline) |

Reasons:
* (1) every seed: a timber deck runs the whole long side, under the eave, on posts, with a visible stone-block base course and stone footings below it, and stone steps at the deck end. The floor stands clearly above the grass. The plinth is a row of blocks with square footings, so it reads partly as piers; the deck is one plain slab with no board gaps.
* (2) every seed: a hipped skirt all round, a steeper upper roof, and a pale gable triangle (hafu) with a barge board at the end; the eaves overhang far past the posts on the long side and the end. Reads as irimoya. The hafu is blank wall with no timber members.
* (3) every seed: the engawa wall is lattice panels (frame, pale paper, grid of bars) in sliding pairs between the posts, some drawn pulled apart. No ordinary glazed window on that side. Plain glazed windows remain on other walls (seen from inside), which is correct.
* (4) seed 1: the interior looks straight out through the opened screen onto the gravel garden, a rock and the grass; clear. Seed 8102: the opening is narrow and the table blocks the lower half; only a rock edge and a gravel sliver show in the gap. Seed 21325: the open gap shows a tree, a rock edge and grass; the gravel is hardly visible. The garden is seen, but only just, on those two.

Images: `artifacts/hs_minka/renders/minka_1_front.jpg`, `_engawa`, `_interior`; the same three for `8102` and `21325`.

Open:
* 8102 and 21325 interior: the opening onto the garden is small in the frame and the garden is barely readable through it (trait 4 borderline).
* All seeds: the plinth reads as separate footing blocks under a thin base course, not a continuous stone platform (trait 1 held on the letter).
* All seeds: the hafu gable is blank, and the deck is one flat slab (known sides, not a trait miss).

Observed (not traits):
* Interior (all seeds): a large window frame fills the right or left edge of the frame and the sky shows blue through it; the camera is crowded by it. A glazed rectangular window with a deep sill is not a Japanese form.
* Seed 8102 interior: a heavy plank trestle table with an iron pot, goblet, tankard and a wall torch; this reads as a medieval European tavern, not a minka. Seed 1 interior: an empty room with plank floor, no tatami, no furniture.
* Garden trees: on 21325 and 8102 the tall pine stands on the gravel edge, its trunk cutting across the engawa wall; on 1 the maple stands in front of the plinth. They hide part of the screens. The conifer is also a Western form.
* Seed 1 and 8102 front: the stepping-stone path ends in the grass to the right with no link to the steps; it floats as a short loose boardwalk.
* Front renders: a red bench, barrel, bowl and a bundle of crates sit loose beside the end steps (21325 shows a barrel and a bowl standing on bare grass).
* The dry garden is a flat rectangle with a thin wood border and a little raking; rocks sit on top of it. It reads as a sandbox, not a garden, but the intent is clear.



## african -- the Sahel courtyard house (HS-SAHEL)

The style key stays `african` (no API break); its label is now `Sahel Courtyard House`
and its brief row in `docs/BUILDING_PERSONALITY_BRIEFS.md` says so. It is a fictional
household in the manner of Djenne and the Mopti region, not a claim about one people.

Traits: (1) flat-roofed banco (mud-brick) rooms arranged round an inner court; (2)
buttressed walls; (3) projecting toron beams on the outer walls; (4) a decorated entry.

Measured first (8 x 10 m, one storey, seeds 1, 8102, 21325): (1) MISSING. A hip
(seed 1) or a cone (8102, 21325) of combed thatch with a roll along the eave, on walls
0.5 m thick with rounded corner piers (kept); parapet on seed 1 only; the yard was a
path, a midden and crates; no court. The shaded veranda (0.75 chance) was on 21325. (2)
MISSING. Only the four corner piers. (3) MISSING. (4) MISSING. Glazed, mullioned windows
and a dripstone hood on a third of the seeds (a European window set into a mud wall).

Built (style row constants and flags, no random draw added or moved):
* Flat banco roof: `roof_types [flat]`, `roof_material earth`, pitch 0, parapet 1.0
  (and the generator makes it invariant for a `sahel` row), thatch roll 0, veranda 0,
  eave 0.55 m. Walls 0.55 m thick, the corner piers stay.
* Court: the `african` yard now leads with `court` (HouseYard, the group HS-MEDITERRANEAN
  built) instead of the midden; the rear door is invariant (`back_door`) so the rooms
  open onto it. `court_ranges` makes the court's two sides flat-roofed ranges
  (`HouseYard._court_ranges`): a 2.3 m outer wall, a 0.22 m roof slab 1.7 m wide with a
  parapet round its outer edge and end, and a stout pier at its free corner; the court side
  is open (a shaded bay). The rear wall is whole; the gateway is in the outer wall of one
  range, at its rear end, where the walk along the flank reaches it. The house is the
  fourth side. The ranges are open bays, NOT furnished rooms: nothing is planned inside them.
* Buttresses, toron, entry: `HouseSahel` (new, `src/house/house_sahel.gd`), called from
  `HouseBuilder._build_culture`. Buttresses: a 0.55 m foot (0.42 m off the wall, 62 % of the
  height) and a narrower shaft up to the parapet's inside, spaced about 2.6 m on a wall,
  never within 0.3 m of a door or window, not on the entry's flanks, and not on the
  part of the court wall that the ranges stand against. Toron: 0.09 m square wood stakes
  0.4 m past the wall (0.2 m inside it) every 0.55 m in a row 0.32 m under the roof edge,
  on all four walls, clear of every opening and of the entry, lengthened to 0.67 m where one
  passes through a buttress. Entry: two pilasters (0.62 m wide, a hand past the eave) with two
  steps in the shaft, a cap and a tip, rising 0.9 m above the parapet, three toron through each, and a raised relief
  frame (a strip beside each jamb, a header, three blocks above it).
* Windows are open apertures (`unglazed`: no pane, mullion or hood; the frame, sill and the
  row's shutter chance stay). The exterior dressing of a `sahel` house is water jars (`Pot_1`)
  and a bucket: no wall lantern, bench or barrel.
* Exterior bound: `HouseGeometry.exterior_bounds` and `spec_bounds` know the pilasters'
  reach and the pinnacle's height (`HouseSahel.reach`, `top_height`).

Test: `tests/house_sahel_traits_test.gd` over the frozen requests `house/african/{1,8102,21325}`
(8102 existed; 1 and 21325 added, all 8 x 10 m). Keys in `HouseTraitMeasure._sahel_keys`
(see its header). 127 checks, 0 failures. Controls: a gable roof, a timber-framed wall, a
0.2 m wall, the court removed, the ranges removed, a deep range slab, a roofed court, the rear
door removed, glazing put back, then buttresses, toron and the entry each removed alone
(`HouseSpec.sahel_skip`, set only by the test) with the other two required to survive, and a
mediterranean house (the measure reads none of this onto another style).

Lanes run on the change: `lane:geom` (11 suites, 9810 checks), `lane:house-exterior-fast` + `hbounds` (4 suites, 7095),
`lane:house-plan-fast` (322), `lane:house-furnish-fast` (242), `hvernacular` (191; only the 4 known witch_hut lines red, HVERN-WITCH-THATCH), `cultureapi` (20), `vcompact` (12).
`tools/fingerprint_houses.gd` (130 lines, the five long-standing styles) is identical against HEAD.

Known sides and open:
* The INTERIOR FURNITURE is not narrowed. The furnisher has no style vocabulary: a furnished
  `african` house still gets a trestle table and chairs, wall torches, a chandelier, goblets, mugs and
  a workbench (European stock), and the floor is planks over a stone skirting, not packed earth. The
  review renders are therefore of the UNFURNISHED house (`generate(.., false)`): the rooms are
  bare. A Sahel interior needs props the catalogue does not have (mats, low stools, clay pots, a
  grain jar) and a furnisher row; it is not part of these four traits.
* The walls are one colour; no plaster relief or hand marks. The toron are square, not round.
* On a wall with a door and two windows (seed 1's front and back) no buttress fits between the
  openings, so seed 1 has buttresses on its two long walls only; the entry's pilasters stand on the front.
* The ranges are open bays: they have no door, no floor of their own and no room inside.
* A `saharan` village (`programmer.gd`) now gets this house; its court needs the lot to leave
  the apron (3 m) behind the house, as before for the mediterranean.

Renders for review: `artifacts/hs_sahel/renders/` (`tools/render_hs_sahel.gd`, not headless),
per seed: `_front` roof-on three-quarter of the entry side (flat roof and parapet, buttresses, toron,
the pinnacled entry); `_rear` roof-on three-quarter from behind and above (the court, its two ranges,
the gateway); `_entry` eye level three metres from the door (pinnacles, relief frame, toron);
`_court` eye level inside the court looking back at the house; `_interior` eye level inside, looking
through the rear door onto the court.

Independent reviewer: fresh agent, from the renders of commit d15b731 (all 15 images opened). Judged only from `artifacts/hs_sahel/renders/sahel_<seed>_{front,rear,entry,court,interior}.jpg`. Interiors are unfurnished on purpose (CULTURE-FURNISH-VOCAB), not marked down.

| seed | (1) flat banco rooms round a court | (2) tapering buttresses | (3) projecting toron | (4) decorated entry |
|---|---|---|---|---|
| 1 | YES (borderline) | YES (borderline) | YES | YES (borderline) |
| 8102 | YES (borderline) | YES (borderline) | YES | YES (borderline) |
| 21325 | YES (borderline) | YES (borderline) | YES | YES (borderline) |

Reasons:
* (1) every seed: flat earthen roof with a parapet, no thatch, earth-coloured walls on a stone base course; a paved court with a low outer wall and two flat-roofed ranges flanking it (rear and court views). But the "rooms round a court" are the house on one side and two open-fronted roofed bays; the ranges show no door or room, so it reads as a walled forecourt with lean-to shelters more than rooms on several sides.
* (2) every seed: vertical earthen piers stand against the long walls and beside the door, rising to the eave. They step in once near the top (entry view, 8102 and 21325) but are otherwise straight-sided slabs, so the taper is slight. On seed 1 the long-wall buttresses are seen only at a glancing angle in the front view.
* (3) every seed: rows of dark square stakes stand out from the wall under the roof edge, and on the door pilasters (entry view); clear in the court view too. They are square, not round.
* (4) every seed: two tall pilasters with stepped, pinnacled tops beside the door, and a lintel with a row of small blocks over it; clearly more elaborate than the windows. The relief frame beside the jambs is faint, and from the front view alone the door is a plain dark slot between two thick piers.

Images: `artifacts/hs_sahel/renders/sahel_1_front.jpg`, `_rear`, `_entry`, `_court`, `_interior`; the same five for `8102` and `21325`.

Open:
* All seeds: the court is not enclosed by rooms; the two ranges are open bays with no door or interior, so trait 1 holds on the letter only.
* All seeds: the buttress taper is slight (one step), and the relief frame round the door is hard to see (traits 2 and 4 borderline).
* The three seeds are near-identical in massing and layout; they differ mostly in window position.

Observed (not traits):
* Interior (8102, 21325): the camera is pressed against a huge window frame that fills most of the image and shows only sky and a blank wall; nothing of the court is readable. Seed 1 interior shows a bare room with a plank floor over a stone skirting, not packed earth.
* Windows: the dark thick frames and sills are timber-box forms that read slightly European on a mud wall.
* Court view (8102, 21325): a lone stepped column stands in front of the wall in the middle of the frame (the free pier of a range, seen close); it looks like a floating post.
* Water jars (blue-grey bowls) stand on bare grass at the right flank and a woven basket hangs against the wall in the rear view; the bucket in the entry views is a European wooden pail. A short plank path leads to the door and ends in the grass.
* Ground: flat green grass, not sand or dry earth; the house does not sit in a Sahel setting.
* Roof: the slab overhangs the walls widely and reads as a thick lid; the pinnacles stand close to the front parapet.


## roundhouse -- the round hut, formerly `mud_hut` (HS-ROUNDHOUSE)

The published style id is `roundhouse` (label "Roundhouse"). `mud_hut` is an ALIAS:
`HouseSpec.style` is a property whose setter resolves it through
`HouseSpec.STYLE_ALIASES` (`canonical_style`), `BuildingLibrary` accepts the old name in
validation and labels, and a saved request that says `mud_hut` builds the same mesh as
one that says `roundhouse` (the focused test compares them vertex for vertex through the
public API). The option list shows only `roundhouse`. The rename is in `CHANGELOG.md`
("Unreleased"). The village programmer never named `mud_hut`, so no village file changed.

Traits (named by the user, 2026-10-24): (1) one round room with thick walls (door reveal
at least 0.35 m); (2) a conical thatch roof with a vent at the apex; (3) a hearth at the
centre of the floor, and a bed or mat at the wall.

Measured first (8 x 10 m, one storey, seeds 1, 8102, 21325): (1) MISSING. Three
rectangular rooms (hall, kitchen, parlour) in a square plan; walls 0.62 m thick (held). (2)
HALF. A conical thatch roof existed, but over the plan's SQUARE (a cone on the rectangle's
perimeter), with a ridge-less apex, no vent. (3) MISSING. The hearth was a breast built
into a wall (`chimney_breast`) and the bed was in the front room; nothing on the floor's
middle. The old hut also had rounded corner piers, a veranda (45 %) and a thatch eave roll,
all of which belong to a rectangle.

Built:
* `HouseRound` (new, `src/house/house_round.gd`): the plan. A plain roundhouse (no trade,
  not a shop or world family, one storey) is ONE room whose outline is a regular 12-gon
  (`outline`), inside a ring of wall 0.62 m thick. It takes a circle of the width asked for,
  8 to 10 m (`clamp_size`, no random draw). One door in the front facet, four small high
  windows (0.5 m wide, sill 1.15 m) on the diagonal facets. A roundhouse that carries a trade
  keeps the old square hut under its square cone (that path is unchanged).
* Walls: the shell follows the room outline (the device the castle's drum towers use);
  `HouseGeometry.shell_runs` lengthens each run of this ring so the outer faces meet, and the
  plinth follows the ring.
* Roof: `RoofShape._round_cone` (12 facets from a circular eave to one apex). The cone is
  lowered by `HouseRound.eave_drop` so that the thatch rests on the outer edge of the wall head
  and hangs past it, and is built that much taller so the apex stays where `roof_rise` puts
  it. The apex vent is a roof opening `roundhouse_vent` (0.38 m radius), with a collar of
  eight thatch bundles round it, four posts and a small hat over it, 0.45 m clear above the
  collar so the smoke leaves between (`HouseBuilder._build_round_roof_fittings`). A ring of
  rafter tails stands out of the eave. The corner piers, veranda and thatch roll are 0.0 in the
  row.
* Hearth: `plan.roundhouse` ("hearth" kerb Rect2 at the middle, "vent"). The builder draws the
  same kerb of stones round ash that the longhall has; the assembler gives it logs, flames and
  a light (`HousePlan.open_fire()` serves both). No chimney, no wall hearth, no focus in a wall.
  A keep-clear zone surrounds it.
* Bed: the furnisher's wall rule finds no facet of a round room that takes a bed, so
  `HouseRound.seat` seats `Bed_Twin1` head to the wall on the rear, east or west facet (the
  largest scale that fits, as close to the wall as it goes) and removes the chandelier (nothing
  hangs from an open cone).

Test: `tests/house_roundhouse_traits_test.gd` over `house/roundhouse/{1,8102,21325}` (8102
existed as `mud_hut`; all 8 x 10 m). Keys in `HouseTraitMeasure._round_keys`. 141 checks, 0
failures. Controls: the outline removed (square shell, four wall masses), a second room, a
0.2 m wall, a gable roof, a shingle roof, the vent removed (no collar or hat either, nothing
else moved), the fire moved to the wall, the kerb removed, a wall hearth, the bed removed, the
bed moved to the middle, a cottage (the measure reads none of it onto another style), and a
table across the door (the nav check must notice). The room also passes `HouseQA`, the nav
check, and the walk grid is the circle (14.8 m2 walkable of 33.8 m2, not the 42.5 m2 box).

Checks widened for a shaped plan, and why: `HouseQA._check_shell` expects the roof to begin
at the wall head, and a roundhouse's cone begins `eave_drop` lower, by design;
`VernacularHouseCheck` accepts the 12-facet round cone whose facets end round the vent, and
does not ask a roundhouse to declare rectangular vocabulary; `house_exterior_suite` allows a
round hut no exterior dressing or approach path (it records an omission: exterior recipes
need a rectangular facade); `house_vernacular_suite` keeps one square-cone fixture as a
smith's roundhouse.

Lanes run on the change: `lane:geom` (11 suites, 9810 checks), `lane:house-plan-fast` (322),
`lane:house-furnish-fast` (242), `lane:house-exterior-fast` (4720), `hbounds` (2317),
`hvernacular` (191; only the 4 known witch_hut lines red, HVERN-WITCH-THATCH), `cultureapi`
(20), `libraryquick` (104), `lane:api` (802), `vcompact` (12). `harchetype` has its known
failures on other styles; roundhouse has 0 defects. `tools/fingerprint_houses.gd` against HEAD:
is identical against HEAD (120 fingerprints; the fingerprint tool skips the new empty `roundhouse` plan field, as it does `longhall`).

Known sides and open:
* The INTERIOR FURNITURE is not narrowed (CULTURE-FURNISH-VOCAB). A furnished roundhouse
  still gets a trestle table, chairs or stools, wall torches, chests and a plank floor; the bed
  is the generic `Bed_Twin1` (a carved timber bedstead, no mat or straw). The review renders
  keep ONLY the bed besides the fire, and say so.
* No yard or exterior dressing (a shaped plan has no rectangular facade); the porch and pail
  of other houses are absent.
* Only 1.2 m2 of glass for 33.8 m2 of floor (a daylight WARNING, small high windows on
  purpose).
* The wall is plain; no relief, no painted band. The windows still carry a timber frame and
  glass pane (European).
* A request for 6.5 x 7.5 becomes an 8 m circle: a smaller hut would not take the bed.

Renders for review: `artifacts/hs_roundhouse/renders/` (`tools/render_hs_roundhouse.gd`, not
headless), per seed: `_front` roof-on three-quarter from the door side, high (round wall, cone,
vent hat); `_door` roof-on, lower and closer (wall thickness in the reveal, the hanging eave);
`_interior` eye level just inside the door, across the fire to the bed; `_vent` eye level beside
the fire looking up the cone at the vent.

Reviewer: pending
