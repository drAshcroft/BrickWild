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
