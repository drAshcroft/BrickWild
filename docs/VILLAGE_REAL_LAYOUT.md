# Villages that do not look generated (VREAL)

Walk QA, 7 Nov 2026, the `mixed` village series: "Towns are not so
incredibly spaced out with huge houses", "so far away?", and from the brief:
house sizes should be a normal distribution, the types of houses should make
sense, a wall should not stand an eternity from the town.

This file is what was measured, what the real villages say, what changed,
and what is still to do. The survey that the real numbers come from is
`docs/SETTLEMENT_TESTSET.md`; the arrangement gate is `docs/VILLAGE_REALISM.md`.

## The real numbers, and where they live

The survey had already downloaded every site's OpenStreetMap answer
(`artifacts/settlements/cache/overpass`, 155 answers) but kept only medians.
The generator needs the distributions, so they are read again:

```
python -I tools/settlements/layout_stats.py --data artifacts/settlements --repo . \
    --out tests/fixtures/settlements/layout_stats.json        # per site + pooled
python -I tools/settlements/emit_layout_table.py --repo .     # -> src/village/village_real_layout.gd
```

`VillageRealLayout` is GENERATED; the generator reads it and never the
fixture (the fixture does not ship in a release). Per culture it holds the
main buildings' footprint quantiles and log spread, the plan aspect, the
wall-to-wall gap to the nearest neighbour and the share of buildings that
touch one; and the pooled distance from a town wall to the nearest building.

Only the 46 HISTORIC sites (the curated list) are used. The 63
environment-sampled sites are mostly modern: a GB/US/CA/AU suburb's median
house is 121 m2, the historic pool's 87. A culture with few historic sites is
shrunk toward the pool (weight n / (n + 3)); `english` reads GB and IE only
(the survey maps the New World to english for its language, and a pueblo is
not an English village).

| | p10 | p50 | p90 m2 | log sd | gap p50 / p90 m | touching |
|---|---|---|---|---|---|---|
| historic pool (46) | 38 | 87 | 191 | 0.65 | 1.6 / 7.2 | 35 % |
| frankish (9) | 35 | 77 | 185 | 0.67 | 0.4 / 6.9 | 67 % |
| mediterranean (10) | 37 | 81 | 198 | 0.68 | 0.4 / 4.7 | 56 % |
| norse (4) | 40 | 86 | 201 | 0.64 | 3.5 / 10.5 | 24 % |
| town wall to nearest building (13 walled sites) | 1.7 | 5.4 | 22 m | | | |

The main building is >= 25 m2 and not tagged a shed, garage, barn or other
outbuilding. Its spread still holds the barns OSM maps as plain `yes`, which is
why the generator takes 0.7 of it (below).

## What the generator did (baseline, 13 Nov, walk stops 1-4, no extras, flat)

`tools/probe_village_layout.gd` plans villages exactly as the walk does and
writes every building, gap and the wall; `tools/settlements/layout_compare.py`
puts each beside the real band; `draw_layout_probe.py` draws them.

| stop | footprint p10/50/90 | log sd | gap p50 | touching | farthest from the common | wrong type |
|---|---|---|---|---|---|---|
| 1 english mill 50 | 56 / 92 / 137 | 0.35 | 6.5 m | 0 % | 106 m | 5 farmers in townhouses |
| 2 frankish market 70 | 61 / 99 / 137 | 0.32 | 3.2 m | 0 % (real 67 %) | 87 m | |
| 3 norse fishing 45 | 71 / 71 / 137 | 0.30 | 2.7 m | 0 % | 148 m (tavern, 134 m from any building) | |
| 4 alpine farming 60 | 56 / 95 / 137 | 0.34 | 7.3 m | 0 % (real 36 %) | 88 m | 6 farmers in townhouses |

Clark-Evans 1.6-2.9 against a real 1.1: the houses are spaced like a parade.
Median house 10-11 m to the ridge. Stop 3 placed 9 of its 14 buildings on a
315 m site (the strand needs ground; not a flat-ground walk case).

Causes, most visible first:

1. **No neighbour ever touches.** Every lot class has a fire gap and the
   frontage a 1 m slack; real old villages are 35-70 % touching. This is the
   single strongest "generated" signal, and VTER-REAL-NUCLEUS already found
   that Clark-Evans cannot move without grouping.
2. **Farmers are sent to the edge.** A farmer's house was a `farm` lot, sited
   "toward outside" (nearest the site boundary) on field tracks. In a farming
   village that is nearly every household, so the middle emptied and the site
   grew.
3. **Wrong houses.** A townhouse was a coin flip with probability `wealth`,
   in any village: rich farming hamlets came out half townhouses.
4. **Sizes were a ramp**, 7-10 x 9-13 m +-22 %, biggest first; the special
   trades took the biggest; every shop was 11 x 14 m.
5. **"By the gate" means the site boundary.** In an open village the gates
   are the through road's ends, so the tavern rule (within 60 m of a gate,
   planner and `VillagePlaceCheck` alike) and the smithy's "toward edge" put
   them at the far ends of a stretched site.
6. **The retry ladder stretches the site** along the road (up to 3.5x)
   whenever a siting rule fails, and the gradient floor (no house nearer the
   common than a bigger one, less 6 m) forbids filling the gaps left behind.
7. **The wall was the lots' convex hull plus 6 m**: farm yards, tracks and
   the hull's empty corners put it tens of metres from the houses.
8. **The walk series' extras** (castles, a sky castle, a wizard's tower, a
   ziggurat in farming hamlets) are a style showcase, not villages; they also
   widen every site they are added to.

## What changed (VREAL-SIZE, VREAL-TYPES, VREAL-WALL)

* **Sizes** (`VillageProgrammer.house_areas`, `house_dims`). Each household's
  footprint is the culture's real median times exp(sd z): z a seeded normal,
  redrawn beyond 1.75; sd 0.7 of the real per-site spread; wealth moves the
  median by +-15 %, never the spread. The special trades take sizes from the
  middle of the village, not the top. A plan's aspect comes from its style
  (a longhall long, a cottage nearly square); a townhouse's frontage is drawn
  in 5.5-7.5 m and its depth capped, so a merchant's household goes up, not
  25 m back. In the middle of the wealth band a house bigger than the real
  p75 stays one storey, and at any wealth a house under `STAIR_MIN_AREA`
  (55 m2) is a cottage with a loft: the house planner cannot fit a climbable
  flight in it and falls back to its legacy stair (`DBGSTAIR` in
  `house_plan_levels.gd`; the walk pin "stuck in the stairs" was a 6.6 x 8.6 m
  two-storey house). Shops are the size of their trade (`SHOP_SIZE`: a
  forge 7.5 x 9.5 m, an inn 11 x 14 m), scaled by the culture's median.
* **Not the compact display.** `VillageSpec.compact()` is a fixed 66 x 64 m
  grid other projects show many of; its churchyard and common were measured
  on the old ramp and 11 x 14 m shops, and `vcompact` failed on the real draw
  (a Mediterranean church clear on 2 sides, an East Asian common 68 %
  standable). It keeps those sizes (`_ramp_dims`); it does take the new types.
* **Types** (`VillageProgrammer._mixed_styles`). A farmer is a farmhouse if he
  is in the bigger half of the farmers, else a smallholder in a cottage. A
  townhouse is only in a trading village (market, crossroads, pilgrim,
  garrison, or 100+ people), only for a household that does not farm, the
  wealth's share of them capped at 45 %; the smith keeps his cottage. A
  household bigger than the real p75 is never a cottage. Cultures whose house
  is not cottage/farmhouse keep their own.
* **Smallholders' lots** (`VillageLotPlanner.lot_class`). A farmer in a
  cottage is a cottage lot in the village, not a farm at the edge.
  `VillagePlaceCheck`'s `farms` and `gradient` rules and the planner's farm
  reach now read the lot class, so the planner and the check judge the same
  set.
* **Variety** (`VillageLotCheck`): the 45 % share applies to the townhouse,
  the style wealth mixes in. A farming village that is mostly farmhouses and
  cottages is what one is.
* **The gate is where the village begins** (VREAL-BODY). Before a wall is
  drawn, and in an open village, the planner sites "toward the gate" (tavern,
  inn, stable) and "toward the edge" (the smithy) against the BODY: the
  points where the through road is `VillageLotPlanner.body_reach` from the
  common, the radius the measured buildings would cover at 20 %
  (`_gates`, `_sorted`). `VillagePlaceCheck`'s tavern rule reads
  `VillageMeasure.entrances`: the gates of an enclosed village, else where the
  through road enters what is built (the last point a building stands within
  20 m of, plus 8 m). `VillageMeasure.gates` (the dresser, the walk, the nav
  flood) is unchanged.
* **Wall** (`VillageEnclosurePlan.hug_ring`). A built edge (hedge, palisade,
  wall) is a closing of the buildings and commons, 6 m out: grown 24 m,
  merged, shrunk 18 m, simplified. Buildings that do not close into one ring
  keep the old hull. An unenclosed village's dressing edge is unchanged.

## After (13 Nov, same stops; stop 12 is the hedged English market town)

`artifacts/vreal_layout/after.json`, `after.png`; baseline `base_1to4.json`.

| stop | footprint log sd | median house height | farthest from the common | site width | wall |
|---|---|---|---|---|---|
| 1 english mill | 0.35 -> 0.39 | 11.1 -> 9.8 m | 106 -> 108 m | 225 m (same) | |
| 2 frankish market | 0.32 -> 0.30 | 10.8 -> 10.0 m | 87 -> 70 m | 205 -> 133 m | |
| 4 alpine farming | 0.34 -> 0.47 | 10.1 -> 7.9 m | 88 -> 70 m | 197 -> 157 m | |
| 12 english market | 0.28 | 10.3 m | 175 -> 88 m | 349 m (same) | 767 m round 2.46 ha -> 495 m round 1.25 ha; 6.2 m median from a house (real 5.4), p90 8.8 (real 22) |

No farmer is in a townhouse; the smith's house is a middling one; shops
range 63-150 m2 by trade. What did NOT move: nothing touches (0 %, VREAL-PACK),
stop 1's farmhouses still stand on field tracks at the ends of a site the
retry ladder stretched to 225 m (VREAL-SITE), and stop 12's site is still
349 m wide although the hedge now stands inside 190 m of it. Clark-Evans
1.5-1.9 (was 1.6-1.9 on these stops; real 1.1): grouping, not sizes, moves it.

Tests run on this change (13 Nov, loaded host): `village` green (1504 checks,
with `_check_programme_real_sizes` and its ramp control; 463 s, 1190 s on the
rerun), `venclosure` green (752), `vquick` green (13; its stair fallbacks 2 ->
0), `vcompact` green after the compact exception (it failed 2 on the real
draw), `vground`, `compactapi`, `wgridfill` green. NOT run: `vlot`, `vcheck`,
`vformslayout`, `varchetype`, `vrealism` (its baseline moves with every plan),
`lane:village-terrain`, `vterrainlane`, `libraryquick`, and the walk bake.

## Packing, the gradient and the strand (VREAL-PACK, VREAL-GRADIENT; 13 Nov, second pass)

Three more numbers were read from the same cached OSM answers
(`layout_stats.py`, now in the fixture):

| historic sites | p10 | p25 | p50 | p75 | p90 |
|---|---|---|---|---|---|
| touching share, by site | | 0.09 | 0.35 | 0.66 | |
| -- frankish (9) / mediterranean (10) / norse (4) | | 0.41 / 0.35 / 0.12 | 0.78 / 0.63 / 0.16 | 0.83 / 0.77 / 0.23 | |
| loneliest building's nearest neighbour (`gap_max_m`) | | | 23.5 m | 28 m | 33 m |
| size against distance from the body's middle (`gradient_rho`) | -0.08 | 0.01 | +0.06 | 0.20 | 0.34 |
| body hull per main building, <= 80 buildings | | 419 | 459 | 639 m2 | |

**The real villages have no wealth gradient by footprint.** The strongest of
46 is Monteriggioni at -0.70; measured from the church (22 sites) the median
is +0.05. The planner made -0.88 to -0.96 on every walk stop: the big houses
in a ring round the green, the small ones outside, which is exactly the kind
of order that reads as generated. `VillagePlaceCheck`'s `gradient` rule (<=
-0.3) is itself stricter than all but two real villages; it is kept, and the
question of loosening it is the owner's (see below). The hull per building
was already in the band: the villages were not too spread, their GROUND was.

What changed:

* **Snap** (`VillageLotPlanner._snap_spots`). Besides the 1 m slide, every
  frontage that stands exactly against a building already on the same road
  edge -- against its lot's side, and with the eaves at the fire gap -- is a
  candidate. Neighbours stand at the rule, not up to a metre past it.
* **Join** (`_joins`, `_try_join`). A household asks to stand against a
  neighbour while the village's buildings at a party side are fewer than
  the culture's real `touching` share of what will be built once it is (a
  running count; a per-household draw kept Frankish at 0.22 asking almost
  always, because a snapped row has no free side, and ran Norse over its
  band once farms could join): an ordinary house, shop or farm sited toward
  the common or the outside, on flat ground, never the smithy, tavern, inn,
  stable or mill.
  The eaves stand `JOIN_GAP` (0.1 m) apart; the neighbour's lot is cut back
  to a side halfway between and the new lot runs from there to its own eaves
  plus half a fire gap; both lots record `party`, the building's offset in a
  split lot is `shift`. `party_pair` waives the fire gap between the two
  (`VillageLotCheck`, `VillageLotSuite.judge`), `frontage_need` half the
  slack per party side. A join is taken when it is no worse, by the siting's
  own order, than `JOIN_REACH` (12 m) past the best free frontage. Most asks
  that fail find a lot or a lane behind in the way.
* **The gradient is a tendency** (`gradient_jitter`, `ORDER_RHO`,
  `gradient_mode`). The households are handed over by size rank plus a
  seeded jitter (0.35 sd of the rank range), the draw kept when the ORDER's
  Spearman with size is 0.7-0.85 (up to eight salts). One order band still
  read anywhere from -0.25 to -0.77 across villages, so the finished plan's
  gradient is measured as the place check measures it, and outside
  [`GRADIENT_RING` -0.75, the rule's -0.3] the same site is cut again with the
  next draw (`GRADIENT_REDRAWS` 4; a cut is seconds, a measurement minutes),
  then once in the old order -- strict, the floor a filter -- which a
  five-house hamlet whose one big house will not fit near the common needs
  (`vcheck`'s sweep: 5 of 24 small villages missed the rule on draws alone);
  the first inside, else the nearest, is kept. The floor is the MEDIAN
  of the bigger households' distances, not the farthest, and it is an ORDER,
  not a filter: the frontages beyond it first, then the rest. As a filter it
  dropped every inner frontage whenever any outer one existed, legal or not:
  the strand smith with forty legal frontages went unhoused, and the retry
  ladder stretched sites to find outer ground (stop 12: 349 m wide; 186 m
  now).
* **The strand's road** (`VillageSitePlanner.STRAND_BOW_MAX`, 3 m). The bend
  grows with the road's length; a stretched strand bowed so far that a
  Norse longhall's 18.6 m lot (its long side and door to the street, as a
  longhouse has) cut the carriageway with its front corners everywhere but
  the straight east end. The coast here is a straight rectangle; the road
  now follows it within 3 m (`MIN_BOW_M` is 2).
* **Not the compact display**, again. `VillageSpec.compact()` keeps the old
  planner whole: no snap or join, the strict order, the farthest bigger
  house as a filtering floor, no redraw, no sliver trim. `vcompact` failed
  its churchyard and common (the same two as in the first pass) when the
  order and floor reached it.
* **Seated fronts** (`_front_seated`). A split lot runs from the shared side
  to its free side and a trimmed neighbour's front shrinks from one end, so
  either front's middle can leave its road segment; a join that would unseat
  one is not taken (the lot suite asks every front's middle to stand over its
  segment).
* **Slivers** (`_trim_slivers`). A lot overhanging its 10 m road segment
  crosses the next segment's ribbon on the inside of a bend by a centimetre:
  under `SLIVER_M2` (0.5 m2) the sliver is cut off the lot instead of the
  frontage refused.
* **Gate**: `vreal` (`tests/suites/village_real_suite.gd`): touching share
  per culture inside the p10-p90 of the historic sites (one planned village
  is one draw against the spread of real ones), the loneliest building under
  33 m, the gradient between -0.75 and -0.3, the lot rules and every party
  side, the hedge at the real wall distance; with packing off, the old order
  (strict, the floor as a filter: `gradient_floor_filters`) and the old hull
  edge as the failing controls.

### After the second pass (13 Nov, walk stops, flat, no extras)

`artifacts/vreal_pack/sweep5.json`; the old planner is `sweep2.json`
(`variants=nopack+gmax+jit0`) and, for stop 3, `sweep1.json`.

| stop | site | touching (real) | gap p50 (real) | gradient | loneliest |
|---|---|---|---|---|---|
| 1 english mill | 225 -> 180 m | 0 -> 0.47 (0.35) | 6.7 -> 5.9 m (1.6) | -0.89 -> -0.49 (6 houses) | 21 -> 16 m |
| 2 frankish market | 133 -> 103 m | 0 -> 0.52 (0.67) | 2.3 -> 0.1 m (0.4) | -0.95 -> -0.52 | 9 -> 5 m |
| 3 norse strand | 315 -> 270 m; 9 -> 14 of 14 housed | 0 -> 0.29 (0.24) | 2.5 -> 2.3 m (3.5) | | 73 -> 19 m |
| 4 alpine farming | 157 m | 0 -> 0.42 (0.36) | 6.0 -> 3.4 m (1.5) | -0.88 -> -0.45 | 17 -> 18 m |
| 12 english market, hedged | 349 -> 186 m | 0 -> 0.37 (0.35) | 2.2 -> 1.5 m (1.6) | -0.95 -> -0.61 | 13 -> 15 m; hedge 6.0 m from a house (real 5.3) |

VillageQA on these stops: clean on 1, 4 and 12; stop 2 keeps the smithy-upwind
fault it had before; stop 3 keeps its tavern (78 m from the entrance, was 103)
and gains the two well faults of VREAL-STRAND-WELL (it lost `housed`,
`density`, `common`). Clark-Evans 1.4-2.2 (was 1.5-2.9; real 1.1).

`vreal` (13 Nov, loaded host, 306-1088 s): green on all four villages, each
with its control failing (packing off: touching 0.00; the old order: -0.96).

Tests on the second pass (13 Nov, loaded host): `vreal`, `vlot` (50
villages, 0 with violations, 2944 s), `vforms`, `venclosure`, `vquick` green
on the code before the last two changes (the old-order last resort and the
compact exception, neither of which reaches their villages' lot rules);
then on the final code `vcompact`, `vcheck` (its `gradient` fixture now sets
the lot class; the sweep's `gradient` follow-up 4 of 24), `village` (1505),
`compactapi`, `vground`, `wgridfill` green. NOT run: `vrealism` (baseline
moves; re-judge after review), `lane:village-terrain`, `vterrainlane`,
`vformslayout`, `varchetype`, `libraryquick`, and the walk bake.

## Still to do, in order

Each is a task with a measured acceptance against the real band, judged by
`probe_village_layout.gd` + `layout_compare.py` on the walk stops, by `vreal`,
and by the existing village checks.

1. **Owner question: the gradient rule.** `VillagePlaceCheck`'s `gradient`
   (<= -0.3) is stricter than 44 of the 46 historic villages (median +0.06).
   The planner now meets it with a tendency (-0.4 to -0.6) instead of a ring;
   loosening it toward the real band is the owner's call, not a planner's.
2. **VREAL-PACK, the rest.** Joins on given ground (terraces cut to the
   outline must be split with the lot); real party walls (the eaves stand
   0.1 m apart and the walls a verge apart, not one shared wall); the farm
   fire gap (still VILLAGES 5's 6 m); Clark-Evans in for >= 5 strata in
   `vrealism` (not run: its baseline moves with every plan).
3. **VREAL-SITE, the rest.** The stretch came mostly from the gradient floor
   as a filter; with it an order the walk stops' sites shrank (stop 12 349 ->
   186 m, stop 2 133 -> 103 m, stop 1 225 -> 180 m). Left: the first site is
   still sized at 16 % density, and the strand is long by form (270 m for 14
   buildings).
4. **VREAL-STRAND-WELL.** The strand's approach path ends 1.9 m short of the
   common's centre; the dresser's well there overlaps the path's end, falls
   back 5 m east, and fails both well rules. It depends on small shifts in
   the strand's geometry (it passed before the site shrank).
5. **VREAL-ARRIVAL.** The dresser's gate props, the walk's arrival and the
   nav flood still read the road's ends at the site boundary
   (`VillageMeasure.gates`), not the body's entrances.

Done: the walk series keeps its castles in the villages (owner, 13 Nov);
the gate is `vreal`.
