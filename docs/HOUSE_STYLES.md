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
