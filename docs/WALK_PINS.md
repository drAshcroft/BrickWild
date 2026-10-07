# Walk pins: what people found that the rig did not

Two rounds of human walk QA (`visualqa/walk_pins.jsonl`, 3 Oct and 6-7 Oct)
pinned 109 defects across nine buildings, all seed 1. Commit `6f8c71a` fixed
the first round. The second round pinned many of the same defects again, on
the same seeds. Every QA lane was green both times.

This note records why the rig stayed quiet, what now catches each repeated
defect, and how to measure the rig against a new round of pins.

## Measure the rig against the pins

```
godot --headless --path . --script res://tools/replay_walk_pins.gd -- [since=2026-10-06T23] [kind=house] [out=artifacts/walk_replay]
```

This rebuilds each pinned request through `BrickWild.generate`, the same path
the walker used, and runs `BrickWild.check` on it. For each pin it prints
`CAUGHT` when a diagnostic names the furniture or room under the pin,
`MISSED` when none does, and `UNMATCHED` when the family has no plan to
attribute against. Attribution only uses the plan, so a `CAUGHT` on a shell
pin means the room was mentioned. Read the diagnostic before you believe it.

Before this work: 109 pins, 13 nominally `CAUGHT`, and nearly all of those by
accident. Willowmill Cottage, Abbey Ivo, the Rustreliquary and Rook Mill all
returned **zero** diagnostics.

`tools/dump_plan_furniture.gd -- kind=.. style=.. seed=..` prints every room,
door and furniture record of a plan-backed building, so a pin's position can
be read against the records under it.

## Why the rig was quiet

1. **The rule checked the furnisher's arithmetic, not the object.** The
   furnisher turns a seat with `yaw_facing(table)`, which assumes the model
   faces −Z. The seating rule then checked the same yaw with the same formula.
   `Chair_1` faces **+Z**: its backrest is 0.24 m toward −Z. Every chair in
   every family sat with its back to the table, and the rule agreed with the
   furnisher. The fix is `face: PI` on `Chair_1`. The guard is
   `house_assembly_suite._seat`, which places every seat through
   `HouseAssembler` and requires the measured backrest to be behind the
   facing direction. It failed on `Chair_1` before the fix.
2. **Overlap rules skipped hosted pieces.** `placed` drops anything with
   `host >= 0` from its pairwise test, and `doorway` does the same. So a seat
   could stand inside its own table's trestle, inside a cabinet, in the front
   door's way, or with its pulled-out floor on another table's bench.
3. **Rules only looked one way.** `density` has a maximum and no minimum. A
   215 m² hotel lobby with two tables was "fine".
4. **Downgrades.** A table in the approach to the front door was a warning,
   "the room had nowhere else for it". It was pinned in both rounds.
5. **Probes that nothing runs.** `qa/coplanar_check.gd` was written in round
   one to find z-fighting. No family QA and no suite calls it. Z-fighting was
   pinned nine times in round one and six times in round two.

## The walk rules (`qa/house_furnish_walk_check.gd`)

These run in `HouseFurnishCheck` for every plan-backed family: house, shop,
hotel, world, village houses and castle interiors. They report under the
`walk` group. `bed_door` and `front_door` report under `feng shui`.

| rule | pin it answers | measurement |
|---|---|---|
| `tuck` | stool "collides with table" | a hosted seat past its table's end along the long axis (the trestle), or more than 0.25 m under its long side, or in any other floor piece |
| `pull_out` | "giant room with crowded two tables" | a hosted seat's pull-out zone on another table's seat, its zone, or a floor piece |
| `table_band` | "light is right in the way of the table" | a non-seat floor piece in the 0.45 m strip along a sat-at table's long side |
| `seat_kinds` | "why two kinds of chairs?" | more than one seat model round the tables of one room |
| `seat_count` | "one bench, just a table" | a table seating one, or none in an eating room |
| `sparse` | "huge room with nothing in it" (x7) | habitable, ≥ 20 m², not corridor-shaped, < 10 % furnished |
| `lamps` | "missing lights" | habitable, ≥ 30 m², fewer than one light per 35 m² |
| `worktop` | "needs a kitchen" (x3) | a kitchen with no table, workbench or counter |
| `bedside` | domus nightstand 2.3 m from its bed | a nightstand more than 0.35 m from every bed |
| `stowage` | "give the barracks some dressers" | fewer than one chest, cupboard or nightstand per two beds |
| `corridor` | hotel lectern "right in the way" | a floor piece more than 0.21 m off the long walls of a corridor |
| `bed_door` | "feng shui is bad to put bed right by door" | a bed within 0.4 m of a door's swing |
| `front_door` | "tables do not go right in front of main entrances" (x2) | any floor piece, hosted or not, in the entrance's 1.6 m way in, never downgraded |

`tests/suites/walk_pin_suite.gd` (`-- walkpins`, in `lane:house-furnish-fast`)
proves each rule twice. It must fail on the pinned furniture rebuilt in a
real room of the pinned cottage or domus. It must stay silent on the same
room put right. The rooms are cleared first, so a furnisher change cannot
move a fixture.

## Stairs (`qa/house_stair_check.gd`, run by `HouseQA`)

The plan rules asked only that a stair exists, where its rectangle lies, and
that there is floor at its foot. The nav check treats a stair as a jump. If
any cell of the flight is reached, it seeds the upper storey, so it cannot
report an unreachable foot or a walled-in top. The round-one fix to
`HouseGeometry.stair_climb` picked the end with floor as the foot, and so
turned house_9's flight to climb into the west wall.

| rule | pin | measurement |
|---|---|---|
| `stair_pitch` | "cannot climb stairs" | riser ≤ 0.22, going ≥ 0.22, 2R+G ≤ 0.70, pitch ≤ 42°. House flights are 10 steps on ≤ 2.4 m (47°); hotel flights 10 on 3.1 m for 3.6 m (49°) |
| `stair_head` | "stairs go directly into the wall" | a flight-width strip past the top step lies on the upper room's floor |
| `stair_headroom` | "bench on stairs" (a `Shelf_Simple`) | nothing within 2 m above the tread under it; wall pieces widened by their depth. `place_mounted` never looks at `plan.stairs` |
| `stair_guard` | "no railing" (x3) | each open side of a flight or its well has a `rail` component hosted `stair_<n>`. **No house or hotel builder emits one**, so this fails on every open stair until one does |
| `stair_approach` | hotel "cannot get to the stairs" | the foot is reachable from the front door by a 0.9 m walker, with the flight as an obstacle |

`walkpins` freezes village house_9's own request (`HOUSE_9`) so the five
rules can be proven in seconds without the village. The castle stair passes
`CastleMassingCheck.stair_walk_failures`. Its remaining faults: rails are a
single bar, posts are every third tread, and landing rails are 0.75 m high
(`RAIL_H`), below guard height. Those are not yet rules.

## Z-fighting (`CoplanarCheck.visible`)

`find` caught all ten z-fight pins it was tried on, at gap 0.0 mm, every one
a pair of different material slots. Its raw output is too noisy to gate on:
about 500 pairs for a cottage and 42,000 for a castle, mostly a material
fighting itself, which renders the same colour either way. `visible` keeps
only the pairs that matter:

- different surfaces;
- at least 0.01 m² (the smallest pin was 0.014 m²);
- in air, by winding number 3 mm off the face.

It reports `at` as the overlap's own centroid, not the first triangle's.

It runs as a **warning** in `HouseQA` (house, shop, hotel, world, village
houses) and in the church, temple and windmill adapters. It is not run on
castles yet: they take 11–17 s, and their shells are not closed, so the
winding filter cannot be used. The ratchet is `ZFIGHT_BUDGET` in
`walk_pin_suite.gd`. On 7 Oct the pinned seeds stood at: cottage 8, shop 0,
domus 24 (walls flush with the roof at the gable heads), temple 12 (the
pinned trim panel), church 92, windmill 40. A count may only fall. Lower
the budget with the fix. Still visible: hotel floor-slab edges flush with
partitions on every storey, and the house_9 floor/wall seam.

## Doors and facades: measured, not yet gated

These are instruments, not lane rules yet:

- `tools/door_gauge.gd -- '<request json>'` measures each exterior door on
  the emitted collision: clear width by height, head, floor profile. It then
  walks the rig body through, in and out, at angles and off-centre, with
  props solid as in the walker. `tools/walk_doors.gd` is run by no lane. It
  walks the centre line only, with shell-only collision.
- `tools/facade_gauge.gd -- '<request json>' [label]` rasters each elevation
  of the emitted shell. It reports the feature fraction and the largest
  blank rectangle.

Measured on the pinned seeds (2026-10-07):

- **Hotel back door 12** has 0.94 m clear and a 1.89 m head, with a 0.14 m
  floor rise at the jamb. Walking in at −40° or 0.3 m off-centre is blocked;
  walking out on the same line passes. The cottage door also blocks inbound
  at ±40°.
- **Village church_0** (gothic 6×10×6): the entrance passage is 1.94 m high.
  "Really short door". `BrickWild.check` returns 0 diagnostics.
- **Hotel balconies** (windows 73, 75 and 77) are glass to the floor, so no
  balcony can be reached. "These doors are not inside?" A chest stands in
  front of window 75. `HotelQA._check_balconies` checks only slab height and
  sill.
- **Windmill door**: hinge straps are 0.72 of a 1.0 m leaf, and there is no
  brace. "Missing some ribs".
- **Blank walls**: the domus sides are 30 × 3.2 m with 0% feature, and the
  front is 5%. A cottage is 15–32%, with at most 21 m² blank. The shop's +X
  side is 1.9%. Proposed rule (warning first): an elevation's largest blank
  rectangle over 40 m², or a run over 10 m wide and 2.5 m tall, or feature
  under 8% of an elevation over 30 m². Mind `court_check._check_inward`. It
  rewards blank outward walls on a courtyard house, so the domus wants
  relief (pilasters, string course, cornice), not windows.
- **Witch hut** shares 20 of its 22 component roles with the cottage. A
  style-identity rule: at least three roles the cottage does not have.

Proposed gates, not built: an `EmittedDoorCheck` suite with physics frames.
It would fail on under 0.90 m clear, under a 2.0 m head, or a church portal
head under 1.3 × its width. It would also fail when an inbound route blocks
but its outbound twin passes. Then a hotel balcony-access rule, and a
windmill door-leaf rule.
