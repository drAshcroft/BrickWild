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

Reviewer tick: OPEN
