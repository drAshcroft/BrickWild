# Village realism gate (VTER-REALISM)

Generated villages measured against the real world set, stratum by stratum.
Suite `vrealism` (`tests/suites/village_realism_suite.gd`), in `lane:scheduled`.

```
godot --headless --path . --script res://tests/run_all.gd -- vrealism > artifacts/vter_realism/gate.log 2>&1
# after a deliberate change (rewrites the baseline and the table below):
BRICK_WILD_REALISM_UPDATE=1 godot --headless --path . --script res://tests/run_all.gd -- vrealism
```

Runtime: 22 min loaded host (1330 s, 42 plans = 14 sites x 3 seeds; was 9 min for 14 plans). (Old note: a quiet
host is nearer half.) The cost is planning on real 90 m grids, so it is a
scheduled gate, not a per-task one.

## Method

* **Strata.** `in_stratum` reads a real site's env and morph record. A site
  belongs to every stratum it satisfies: lowland (median slope < 4 %, disc
  relief < 60 m), hillside (slope >= 8 %, the survey's steep threshold),
  valley (labelled valley, or body in the lowest quarter of a >= 100 m
  disc), crest (labelled crest, or body in the top fifth of a >= 60 m disc),
  coast (coast in the disc or < 2 km), lake (lake < 2 km), island (landmass
  < 500 km2), arid (Koppen B), polar (Koppen E or beyond 66.5 degrees).
  Members: 14 to 46 per stratum, 109 usable sites.
* **Band.** The real p10-p90 of the members, per metric, straight from
  `world_settlements.json`. A cell with fewer than 5 real values is not judged.
* **Generated sample.** A 50-person village, seed 4242, derived form, planned
  by `VillageLotPlanner.plan_measured` on the world90 grid of a real site of
  that stratum (14 sites, listed per stratum below). Water is `lake` or `coast`
  when the site is, purpose `fishing` then, else `farming`. The cell is the
  median over the plans that belong to the stratum.
* **Measure.** `VillageShape.measure` (`qa/village_shape.gd`), the GDScript
  twin of `survey.py measure()`; key-for-key parity with `measure-plan` is
  proven by `tools/shape_parity.gd` + `shape_parity.py`
  (SETTLEMENT_TESTSET.md). No second measurement was written.
* **Metrics (23).** All of the survey's arrangement measures a 50-person plan
  can have. Left out on purpose: counts that scale with the mapped disc
  (`osm_buildings`, `body_buildings`, `body_hull_ha`, `body_offset_m`,
  `clusters_ge5`), `footprint_cv`/`footprint_p90_m2` (spread of thousands of OSM
  polygons), `slope_p90_pct` (duplicates the median), `adjacent_water_ha`,
  `water_median_m`, `road_reached`, `tunnels`, `city_wall`, `worship` (counts).
* **Gate.** `tests/fixtures/settlements/realism_baseline.json` stores in/out per
  cell. The suite fails when a cell that was in is now out, or a baseline cell
  is no longer judged. A control inside the suite proves the comparison fails
  on a cell leaving its band and does not on one entering it. Out cells stay
  out without failing: they are the follow-ups below.

## Result (2026-10-26)

**166 of 207 judged cells (80 %) are inside the real p10-p90: the 75 % bar is
met** (2026-10-25: 148, 71 %). Two changes moved 18 cells in and none out:

* **Back streets** (VTER-REAL-STREETNET, `src/village/village_street_net.gd`,
  called from `VillageLotPlanner.plan_measured` after `_trim_lanes`, on given
  ground only). Up to three loops of three straight streets (out, along, back)
  leave the through road through the gaps the lots left, run behind a row and
  come back, until no more than 40 % of the net's nodes are ends. A corner
  BETWEEN two roads is a junction (30 degrees, 8 m), which is why the loop is
  three roads and not one bent one (the in-road bend rule is 25 degrees in
  20 m). In: `dead_end_ratio` hillside, valley, coast, lake, island;
  `intersections_per_ha` lowland, coast, polar; `orientation_order` lowland,
  hillside, lake, island, polar. Laying loops BEFORE the lots grew the site
  1.6 to 2.5 times through the retry ladder and was dropped.
* **Turned houses** (VTER-REAL-FRONTAGE, `VillageLotPlanner._turned`). On the
  terrain forms 45 % of cottages and farms are drawn a turn of 16-22 degrees
  (seed and lot index, no random draw); the turned building gets the square
  lot widened and deepened by what it sweeps, re-centred, inside its setback
  band and fire gaps, or stays square. `VillageLotCheck.faces_road` allows the
  turn the lot declares (`yaw_deg`). In: `frontage_aligned` hillside, crest,
  coast, island, arid (valley stays out: Haldenstein turns one house).

Tried and dropped: the shore form's seaward share 0.4 -> 0.25 brought coast
`water_within_30m` in but widened the shore sites (elongation out in lowland,
coast, lake) and left Naujaat's common path off the rerouted through road
(`connected` failed): net negative.

Caveats as before: 27 cells (`over_water_share`, `steps_ways`, `bridges`) are
in by emptiness; two to six plans per stratum, one seed. Per-plan probing
without the whole gate: `tools/probe_realism.gd` (caches each plan's shape,
re-judges the cache, lists regressions; NONET=1 / NOTURN=1 switch the two
changes off).

The checks were not tuned to pass: bands are the fixture's, the sample was
cut for runtime (slow plans dropped), never for the result.

## Causes of the out-of-band cells, and their tasks

| Cause | Cells still out | Task |
|---|---|---|
| a through road plus stubs | `dead_end_ratio` lowland, arid, polar; `orientation_order` coast, arid; `road_km_per_ha` coast, island | VTER-REAL-STREETNET (done; frontage-tiled shore rows such as Bakel/Naujaat have no gap for a leg) |
| every house square to its street | `frontage_aligned` valley | VTER-REAL-FRONTAGE (done) |
| lots evenly spaced | `clark_evans` 6, `nn_median_m` valley, `setback_median_m` crest, `coverage`, `compactness`, `elongation` crest | VTER-REAL-REGULAR |
| too little fall under the houses | `elev_span_m` 6 | VTER-REAL-VERTICAL |
| shore form puts houses on the water everywhere | `water_within_30m` coast, arid, polar | VTER-REAL-WATERFRONT |
| one body, always a common, landmark high | `body_share` 5, `squares` 2, `body_elev_pctile` 2, `worship_elev_pctile` | VTER-REAL-NUCLEUS |

Pattern: the generator is out of band on the DIRECTION of regularity
(everything too aligned, too evenly spaced, too connected to one spine), not
on size or slope; slope under the houses, footprints, steps and bridges are
in band in every stratum.

## Tables (generated by the suite)

## Sampling noise and the verdict (VTER-REAL-SAMPLE, 2026-10-29)

The gate used to plan each of 14 sites once (seed 4242), so a cell held 2 to
6 plans and its median moved with the seed. Measured on the UNCHANGED planner,
two single-seed runs agreed on in/out for **88.0 %** of the 207 cells (mean of
the 15 pairs among 6 seeds; `tools/realism_agreement.gd`). That is why every
siting change reshuffled unrelated cells.

Now:

* **Plans.** Every sample site is planned under `SEEDS` = 4242, 101, 202 (42
  plans, cells hold 6 to 18). Seeds are keyed into the measured-programme cache.
* **Verdict.** `median_interval` takes a 400-draw bootstrap of the cell median
  (plans resampled, fixed RNG, 90 % interval). `in`: interval wholly inside the
  real p10-p90. `low`/`high`: interval wholly outside, so out beyond the noise.
  `unsure`: it straddles an edge. **Unsure is not a pass**: it is not counted
  inside, and it never fails the gate either; it is listed (`UNSURE ...`).
* **Gate.** Fails only for a baseline `in` cell that is now out beyond the
  noise (or no longer judged). A baseline `in` cell that went `unsure` is noted
  for a human. The baseline stores `in` as true, everything else false.
* **Controls.** A shifted metric (x40) is judged `high`, not `unsure`; a sample
  straddling the edge is never `in`; a cell leaving its band is a regression.
* **Agreement of the new gate**, unchanged planner, disjoint seed sets
  {4242,101,202} vs {303,404,505} (and all 10 such splits, mean in brackets):
  out-beyond-noise vs not **95.7 % (97.5 %)**; no cell was `in` in one run and
  out in the other (decisive-vs-decisive agreement 100 %, 131 of 207 cells
  decisive in both); `in` vs not-in **92.8 % (92.6 %)** and exact three-state
  88.4 % (90.2 %), because a cell on the band edge flips between `in` and
  `unsure`. **The 95 % bar holds for the question the gate asks (is this cell
  out beyond noise); it does not hold for "is this cell in".** About 30 % of
  cells are `unsure`: 6 to 18 plans from 2 to 6 sites cannot place a median that
  sits on a band edge. More sites per stratum, not more seeds, is what would.
* **Baseline (2026-10-29).** 122 of 207 cells inside (59 %), 60 unsure, the rest
  out beyond noise. The old point figure was 166 (80 %); the drop is the
  verdict getting stricter, not the planner moving. Compare a planner change
  against THIS number, and read its `OUT`/`UNSURE` lines.
* **Runtime.** 42 plans: 22 min on a loaded host (1330 s; was 9.5 min for 14).
  Scheduled gate only. To judge a planner change faster, plan once with
  `tools/probe_realism_seeds.gd -- <seeds>` (cached per seed under
  artifacts/vter_sample/plans/, resumable) and judge from the cache with
  `tools/realism_agreement.gd`.

## Slope yardstick and the relief tie-break (VTER-REAL-VERTICAL, 2026-10-28)

Finding: a plan sited on a 90 m grid is measured on a resampled 5 m view, and
`VillageShape.Ground.grad` read the view, so a 90 m cell's own edge showed as
slope (2 m rise: 2.2 % over the cell). The real stock reads `np.gradient` of the
DEM nodes (two cells). `Ground` now reads the source grid's node gradient,
turned into the village frame (control: vshape `_resolution`, a 6 m rise in one
cell reads 6.7 % on the view and 3.3 % on the nodes; a turned 20 % plane keeps
its 20 % and direction). Plan-level result: slope_median moved (Bakel 3.15 ->
3.87, Tofta 1.21 -> 0.98, Haldenstein 4.25 -> 4.08), cells in 166 -> 166, no
cell left or entered. The gd/py parity harness keeps its 19 old disagreements on
the two Manarola terrain cases (its ground differs between the sides; not this
change).

The tie-break retried with that reading and a node-slope cap (relief term in
`VillageSiting._score` and `VillageShoreForm._score`, want 2.5 m / cap 2.5 %, then
4 m / 3 %): lowland slope held (Bakel 1.75, Tofta 2.59, Zýgi 2.02 %), valley span
8.0 m came in (and coast span in the second try), but 6 and 5 other cells left
(valley orientation_order, lake road_km and orientation, worship_centrality,
island intersections): 160 and 161 of 207 against 166. Any new frame on a 2-6
plan cell reshuffles unrelated medians, so the relief term is not kept. The
yardstick fix is the strict improvement kept. Left for a gate that scores whole
plans, not one metric: hillside span stays 6.75-9.2 m against p10 14.4.

## Relief tie-break under the three-state verdict, and the population test (VTER-REAL-VERTICAL, 2026-10-29)

Method: `tools/probe_realism_seeds.gd -- cache=<dir> [pop=N] [only=a,b] 4242 101 202`
plans into any cache dir; `tools/judge_cache.gd -- cache=<dir> out=<states.json>
base=<states.json> metric=elev_span_m` judges a cache in seconds and diffs every
cell's state against a saved one. Planning 42 plans takes about 40 min on a
loaded host (Naujaat 9 min, Civita 10 min), so one candidate frame is one
iteration; a cached baseline from unchanged code is identical to the committed
one (120 in, 61 unsure, 26 out on the cache; the gate's 122 differs by the
bootstrap only).

Baseline elev_span_m (median [90 % interval], real band): hillside LOW 10.5
[2.8-13.6] vs 14.4-73.0; valley UNSURE 2.8 [1.7-21.1] vs 6.0-70.2; crest UNSURE
10.4 [1.3-10.6] vs 4.35-37.4; coast UNSURE 0.6 [0.6-4.3] vs 1.28-59.6; lake LOW
0.9 [0.5-1.3] vs 1.81-46.9; arid LOW 1.3 [0.5-1.6] vs 1.63-18.2 (lowland, island
and polar are in).

Relief term retried (lattice p5-p95 span below 3 m costs 3, plus a 6x penalty on
median node slope over 3 %; the same span term on the shore frame): hillside LOW
10.8, valley UNSURE 2.8, crest UNSURE 5.2, coast UNSURE 0.9, lake LOW 1.0, arid
LOW 1.3. **No cell moved to in; 119 in / 62 unsure / 26 out against 120 / 61 / 26.**
Side effects: 4 in cells became unsure on unrelated metrics (hillside
orientation_order and dead_end_ratio, valley slope_median and worship_centrality,
crest slope_median, island nn_median and frontage_aligned, arid body_elev_pctile,
polar intersections) and 3 unsure cells went decisively out (hillside
frontage_aligned high, coast body_share and coverage high). No in cell went out,
but the term is not kept: it buys nothing. The siting cannot make relief the
ground does not have: the arid, lake and coast samples stand on flat DEM cells
(Bakel, Zygi, Tofta, Lelu span 0.5-1.7 m wherever the frame is put).

Population test (50 -> 150 people, seed 4242, the unchanged siting): Koshi 0.3 ->
7.3 m, Aoloau 9.2 -> 36.1, Posillipo 16.2 -> 26.5, Vijayapuri North 1.3 -> 3.2,
Cayumba 21.3 -> 16.5; but the flat grounds do not move: Bakel 1.7 -> 1.4, Zygi
0.5 -> 0.7, Lelu 0.6 -> 0.5. So population IS the cause for sloped sites (hillside,
valley, crest: a 50-person village is a hamlet on a 150 m site, a real mapped
village is several times that) and is NOT the cause for lake, arid and coast,
whose cells are limited by flat ground. `vrealism` plans at `POPULATION` 50;
`VillageRealismSuite.population` is now a static var so a probe can ask 150.
Moving the gate to 150 would triple its 22 min; left open.

<!-- realism:begin -->
### In-band share by stratum

| Stratum | Real sites (n) | Generated plans | Cells inside | Share |
|---|---|---|---|---|
| lowland | 29 | 3 (Bakel, Zýgi, Tofta) | 16 of 23 | 70 % |
| hillside | 46 | 6 (Cayumba, Monteriggioni, Civita di Bagnoregio, Posillipo, Limone sul Garda, Haldenstein) | 14 of 23 | 61 % |
| valley | 18 | 3 (Koshi, Cayumba, Haldenstein) | 14 of 23 | 61 % |
| crest | 16 | 3 (Monteriggioni, Civita di Bagnoregio, Vijayapuri North) | 12 of 23 | 52 % |
| coast | 35 | 5 (Posillipo, Lelu, Zýgi, Naujaat, Tofta) | 13 of 23 | 57 % |
| lake | 14 | 2 (Limone sul Garda, Vijayapuri North) | 12 of 23 | 52 % |
| island | 22 | 2 (Lelu, Aoloau) | 12 of 23 | 52 % |
| arid | 24 | 3 (Bakel, Zýgi, Vijayapuri North) | 12 of 23 | 52 % |
| polar | 16 | 2 (Naujaat, Haldenstein) | 17 of 23 | 74 % |
| **all** | 109 | | 122 of 207 | **59 %** |

### Every cell

Each cell: generated median (real p10-p90, in/LOW/HIGH). `-` : fewer than 5 real members or no generated value.

| Metric | lowland | hillside | valley | crest | coast | lake | island | arid | polar |
|---|---|---|---|---|---|---|---|---|---|
| `body_share` | 1.00 [1.00-1.00] (0.09-0.98) HIGH | 0.87 [0.68-0.97] (0.16-0.96) UNSURE | 0.75 [0.53-1.00] (0.18-0.84) UNSURE | 0.60 [0.50-1.00] (0.27-0.97) UNSURE | 1.00 [0.94-1.00] (0.23-0.97) UNSURE | 1.00 [0.97-1.00] (0.19-0.92) HIGH | 0.75 [0.42-1.00] (0.23-0.95) UNSURE | 1.00 [1.00-1.00] (0.16-0.97) HIGH | 0.90 [0.71-1.00] (0.06-0.96) UNSURE |
| `clark_evans` | 1.98 [1.97-2.06] (0.96-2.64) in | 1.95 [1.85-2.23] (0.86-1.80) HIGH | 1.88 [1.81-2.28] (0.86-2.06) UNSURE | 1.99 [1.88-2.78] (0.92-1.81) HIGH | 2.01 [1.97-2.05] (0.96-1.70) HIGH | 2.04 [1.99-2.13] (0.83-1.93) HIGH | 2.10 [2.05-2.14] (0.95-1.79) HIGH | 1.99 [1.98-2.06] (1.04-2.00) UNSURE | 2.08 [1.91-2.26] (1.05-2.44) in |
| `nn_median_m` | 14.2 [13.6-15.8] (8.92-23.9) in | 19.0 [18.6-19.9] (7.05-23.8) in | 19.8 [18.1-21.1] (9.51-20.8) UNSURE | 18.8 [13.5-19.8] (6.15-22.2) in | 15.0 [14.1-16.1] (6.64-21.5) in | 13.6 [13.0-14.2] (9.57-22.7) in | 16.0 [14.9-18.4] (7.17-20.7) in | 13.6 [13.0-15.8] (8.23-26.7) in | 16.1 [13.9-18.1] (10.6-25.9) in |
| `elongation` | 3.38 [3.13-4.02] (1.31-3.92) UNSURE | 2.33 [1.65-3.69] (1.32-4.88) in | 2.35 [1.67-4.35] (1.45-5.27) in | 2.74 [1.65-3.06] (1.19-3.09) in | 3.38 [3.00-3.93] (1.54-3.87) UNSURE | 3.40 [3.06-4.12] (1.34-3.66) UNSURE | 2.33 [1.27-3.93] (1.42-4.22) UNSURE | 3.13 [3.09-4.02] (1.30-3.26) UNSURE | 4.12 [3.21-4.71] (1.69-5.45) in |
| `compactness` | 0.43 [0.42-0.51] (0.34-0.89) in | 0.61 [0.43-0.70] (0.41-0.84) in | 0.69 [0.41-0.74] (0.33-0.81) in | 0.53 [0.51-0.70] (0.59-0.88) UNSURE | 0.43 [0.41-0.53] (0.47-0.84) UNSURE | 0.47 [0.43-0.51] (0.38-0.86) in | 0.62 [0.41-0.83] (0.46-0.83) UNSURE | 0.51 [0.43-0.51] (0.50-0.87) UNSURE | 0.40 [0.37-0.52] (0.43-0.83) UNSURE |
| `coverage` | 0.38 [0.34-0.42] (0.09-0.58) in | 0.20 [0.16-0.28] (0.10-0.49) in | 0.18 [0.13-0.23] (0.09-0.52) in | 0.43 [0.19-0.44] (0.14-0.55) in | 0.37 [0.32-0.39] (0.10-0.36) UNSURE | 0.40 [0.35-0.44] (0.12-0.70) in | 0.38 [0.24-0.41] (0.10-0.29) UNSURE | 0.43 [0.34-0.44] (0.09-0.54) in | 0.28 [0.21-0.39] (0.10-0.45) in |
| `footprint_median_m2` | 82.1 [80.9-87.5] (43.8-180) in | 82.1 [79.3-87.0] (37.6-174) in | 82.1 [77.8-87.5] (45.0-143) in | 82.1 [80.9-88.7] (37.6-182) in | 82.1 [80.9-82.2] (42.2-130) in | 81.5 [79.3-87.5] (51.0-195) in | 79.2 [75.8-82.1] (39.6-130) in | 82.1 [80.9-87.5] (29.7-200) in | 81.6 [79.3-86.5] (58.3-126) in |
| `orientation_order` | 0.94 [0.93-0.98] (0.10-0.98) UNSURE | 0.84 [0.73-0.92] (0.13-0.94) in | 0.96 [0.84-1.00] (0.25-0.98) UNSURE | 0.80 [0.56-1.00] (0.09-0.81) UNSURE | 0.93 [0.88-0.98] (0.09-0.97) UNSURE | 0.98 [0.90-1.00] (0.16-0.96) UNSURE | 0.97 [0.85-0.98] (0.08-0.92) UNSURE | 1.00 [0.96-1.00] (0.17-0.94) HIGH | 0.84 [0.78-0.91] (0.09-0.87) UNSURE |
| `dead_end_ratio` | 0.50 [0.50-1.00] (0.15-0.45) HIGH | 0.40 [0.37-0.50] (0.22-0.66) in | 0.38 [0.20-0.50] (0.16-0.62) in | 1.00 [0.33-1.00] (0.18-0.80) UNSURE | 0.50 [0.50-0.50] (0.21-0.54) in | 0.75 [0.42-1.00] (0.24-0.67) UNSURE | 0.44 [0.38-0.50] (0.22-0.64) in | 1.00 [0.50-1.00] (0.15-0.42) HIGH | 0.39 [0.33-0.69] (0.22-0.46) UNSURE |
| `intersections_per_ha` | 5.00 [0.00-5.45] (0.94-1005) UNSURE | 6.25 [1.77-9.50] (0.41-45.3) in | 8.14 [1.77-22.1] (0.28-60.2) in | 0.00 [0.00-6.63] (0.00-29.8) in | 5.45 [5.27-6.19] (0.82-21.8) in | 2.38 [0.00-8.15] (0.12-70.9) UNSURE | 11.5 [5.57-23.6] (0.17-17.0) UNSURE | 0.00 [0.00-5.00] (1.92-169) UNSURE | 7.94 [4.06-15.0] (1.22-184) in |
| `road_km_per_ha` | 0.69 [0.45-0.79] (0.14-1.52) in | 0.62 [0.31-0.77] (0.07-0.64) UNSURE | 0.68 [0.19-1.40] (0.08-0.74) UNSURE | 0.45 [0.00-0.73] (0.00-0.58) UNSURE | 0.79 [0.73-0.92] (0.07-0.41) HIGH | 0.56 [0.45-0.85] (0.02-0.61) UNSURE | 0.91 [0.75-1.02] (0.05-0.53) HIGH | 0.45 [0.45-0.78] (0.18-0.70) UNSURE | 0.73 [0.60-0.84] (0.14-1.27) in |
| `frontage_aligned` | 0.81 [0.81-0.87] (0.56-1.00) in | 0.86 [0.80-0.92] (0.47-0.87) UNSURE | 0.94 [0.88-1.00] (0.45-0.87) HIGH | 0.83 [0.71-0.88] (0.67-0.95) in | 0.85 [0.81-0.87] (0.56-0.95) in | 0.93 [0.88-0.94] (0.48-1.00) in | 0.81 [0.71-0.83] (0.58-0.86) in | 0.88 [0.81-0.88] (0.51-0.99) in | 0.90 [0.84-0.96] (0.59-1.00) in |
| `setback_median_m` | 7.50 [6.40-7.50] (5.64-12.1) in | 7.75 [6.40-8.25] (1.50-13.7) in | 8.30 [7.40-8.50] (2.92-13.4) in | 8.00 [7.50-9.70] (1.14-5.28) HIGH | 7.20 [6.00-7.50] (1.53-13.1) in | 7.15 [6.30-7.50] (2.06-16.4) in | 8.00 [7.50-10.4] (1.50-11.4) in | 7.50 [6.40-7.50] (3.24-12.4) in | 7.30 [5.50-7.50] (3.50-12.9) in |
| `elev_span_m` | 0.60 [0.50-1.60] (0.50-8.38) in | 10.5 [2.80-14.4] (14.4-73.0) UNSURE | 2.80 [1.70-21.1] (6.00-70.2) UNSURE | 10.4 [1.30-10.6] (4.35-37.4) UNSURE | 0.60 [0.60-4.30] (1.28-59.6) UNSURE | 0.90 [0.50-1.30] (1.81-46.9) LOW | 2.45 [0.60-7.60] (0.55-71.7) in | 1.30 [0.50-1.60] (1.63-18.2) LOW | 3.45 [2.25-5.05] (0.80-57.5) in |
| `slope_median_pct` | 1.97 [1.00-3.72] (0.29-2.20) UNSURE | 15.1 [6.20-24.2] (9.32-37.4) UNSURE | 6.20 [4.08-31.7] (1.62-31.9) in | 13.0 [4.14-23.6] (2.29-28.4) in | 1.97 [0.98-5.95] (0.54-28.4) in | 2.77 [1.44-4.13] (0.90-20.3) in | 5.41 [0.92-10.7] (0.53-36.9) in | 3.86 [1.99-3.95] (0.99-12.7) in | 6.05 [5.01-6.20] (0.27-21.9) in |
| `body_elev_pctile` | 0.46 [0.41-0.48] (0.24-0.86) in | 0.84 [0.57-0.91] (0.15-0.89) UNSURE | 0.53 [0.36-0.85] (0.07-0.35) HIGH | 0.96 [0.65-0.98] (0.51-0.96) UNSURE | 0.48 [0.41-0.70] (0.30-0.86) in | 0.59 [0.57-0.64] (0.46-0.83) in | 0.59 [0.36-0.86] (0.22-0.86) in | 0.46 [0.41-0.62] (0.40-0.87) in | 0.62 [0.53-0.72] (0.21-0.57) UNSURE |
| `water_within_30m` | 0.47 [0.40-0.50] (0.00-0.38) HIGH | 0.17 [0.00-0.43] (0.00-0.23) UNSURE | 0.00 [0.00-0.54] (0.00-0.22) UNSURE | 0.00 [0.00-0.50] (0.00-0.34) UNSURE | 0.40 [0.38-0.44] (0.00-0.27) HIGH | 0.52 [0.45-0.61] (0.00-0.47) UNSURE | 0.19 [0.00-0.44] (0.00-0.25) UNSURE | 0.50 [0.47-0.60] (0.00-0.07) HIGH | 0.49 [0.38-0.66] (0.00-0.27) HIGH |
| `over_water_share` | 0.00 [0.00-0.00] (0.00-0.00) in | 0.00 [0.00-0.00] (0.00-0.00) in | 0.00 [0.00-0.00] (0.00-0.00) in | 0.00 [0.00-0.00] (0.00-0.00) in | 0.00 [0.00-0.00] (0.00-0.00) in | 0.00 [0.00-0.00] (0.00-0.00) in | 0.00 [0.00-0.00] (0.00-0.00) in | 0.00 [0.00-0.00] (0.00-0.00) in | 0.00 [0.00-0.00] (0.00-0.00) in |
| `steps_ways` | 0.00 [0.00-0.00] (0.00-9.60) in | 2.00 [0.00-4.00] (0.00-46.5) in | 0.00 [0.00-4.00] (0.00-16.3) in | 0.00 [0.00-4.00] (0.00-47.5) in | 0.00 [0.00-0.00] (0.00-47.0) in | 0.00 [0.00-0.00] (0.00-3.70) in | 0.00 [0.00-1.08] (0.00-48.5) in | 0.00 [0.00-0.00] (0.00-1.70) in | 0.00 [0.00-0.00] (0.00-10.5) in |
| `bridges` | 0.00 [0.00-0.00] (0.00-15.6) in | 0.00 [0.00-0.00] (0.00-11.0) in | 0.00 [0.00-0.00] (0.00-12.0) in | 0.00 [0.00-0.00] (0.00-6.00) in | 0.00 [0.00-0.00] (0.00-8.60) in | 0.00 [0.00-0.00] (0.00-2.70) in | 0.00 [0.00-0.00] (0.00-8.90) in | 0.00 [0.00-0.00] (0.00-2.00) in | 0.00 [0.00-0.00] (0.00-14.0) in |
| `squares` | 1.00 [1.00-1.00] (0.00-1.20) in | 1.00 [1.00-1.00] (0.00-4.50) in | 1.00 [1.00-1.00] (0.00-1.00) in | 1.00 [1.00-1.00] (0.00-3.50) in | 1.00 [1.00-1.00] (0.00-4.60) in | 1.00 [1.00-1.00] (0.00-0.00) HIGH | 1.00 [1.00-1.00] (0.00-3.70) in | 1.00 [1.00-1.00] (0.00-0.70) HIGH | 1.00 [1.00-1.00] (0.00-1.00) in |
| `worship_centrality` | 0.44 [0.42-0.52] (0.23-1.05) in | 0.75 [0.63-0.99] (0.15-0.81) UNSURE | 0.69 [0.57-0.99] (0.17-0.99) in | 0.92 [0.69-1.06] (0.07-0.73) UNSURE | 0.56 [0.43-1.00] (0.23-0.81) UNSURE | 0.64 [0.44-0.87] (0.13-0.75) UNSURE | 0.56 [0.43-1.04] (0.23-0.95) UNSURE | 0.51 [0.44-0.61] (0.23-0.79) in | 0.99 [0.60-1.48] (0.42-1.53) in |
| `worship_elev_pctile` | 0.75 [0.69-0.93] (0.05-0.98) in | 0.87 [0.73-0.93] (0.28-0.97) in | 0.93 [0.62-0.94] (0.20-0.98) in | 0.88 [0.81-0.94] (0.56-0.97) in | 0.86 [0.73-0.92] (0.05-0.96) in | 0.70 [0.62-0.88] (0.43-0.94) in | 0.93 [0.88-0.94] (0.00-0.77) HIGH | 0.88 [0.63-0.94] (0.22-1.00) in | 0.88 [0.47-0.94] (0.00-1.00) in |
<!-- realism:end -->
