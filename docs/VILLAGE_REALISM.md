# Village realism gate (VTER-REALISM)

Generated villages measured against the real world set, stratum by stratum.
Suite `vrealism` (`tests/suites/village_realism_suite.gd`), in `lane:scheduled`.

```
godot --headless --path . --script res://tests/run_all.gd -- vrealism > artifacts/vter_realism/gate.log 2>&1
# after a deliberate change (rewrites the baseline and the table below):
BRICK_WILD_REALISM_UPDATE=1 godot --headless --path . --script res://tests/run_all.gd -- vrealism
```

Runtime: 9 min loaded host (540 s, 14 plans of 50 people at 4-80 s each; a quiet
host is nearer 5 min). The cost is planning on real 90 m grids, so it is a
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

<!-- realism:begin -->
### In-band share by stratum

| Stratum | Real sites (n) | Generated plans | Cells inside | Share |
|---|---|---|---|---|
| lowland | 29 | 3 (Bakel, Zýgi, Tofta) | 21 of 23 | 91 % |
| hillside | 46 | 6 (Cayumba, Monteriggioni, Civita di Bagnoregio, Posillipo, Limone sul Garda, Haldenstein) | 21 of 23 | 91 % |
| valley | 18 | 3 (Koshi, Cayumba, Haldenstein) | 19 of 23 | 83 % |
| crest | 16 | 3 (Monteriggioni, Civita di Bagnoregio, Vijayapuri North) | 18 of 23 | 78 % |
| coast | 35 | 5 (Posillipo, Lelu, Zýgi, Naujaat, Tofta) | 15 of 23 | 65 % |
| lake | 14 | 2 (Limone sul Garda, Vijayapuri North) | 19 of 23 | 83 % |
| island | 22 | 2 (Lelu, Aoloau) | 19 of 23 | 83 % |
| arid | 24 | 3 (Bakel, Zýgi, Vijayapuri North) | 15 of 23 | 65 % |
| polar | 16 | 2 (Naujaat, Haldenstein) | 19 of 23 | 83 % |
| **all** | 109 | | 166 of 207 | **80 %** |

### Every cell

Each cell: generated median (real p10-p90, in/LOW/HIGH). `-` : fewer than 5 real members or no generated value.

| Metric | lowland | hillside | valley | crest | coast | lake | island | arid | polar |
|---|---|---|---|---|---|---|---|---|---|
| `body_share` | 1.00 (0.09-0.98) HIGH | 0.81 (0.16-0.96) in | 0.75 (0.18-0.84) in | 0.56 (0.27-0.97) in | 1.00 (0.23-0.97) HIGH | 1.00 (0.19-0.92) HIGH | 0.75 (0.23-0.95) in | 1.00 (0.16-0.97) HIGH | 1.00 (0.06-0.96) HIGH |
| `clark_evans` | 2.00 (0.96-2.64) in | 1.95 (0.86-1.80) HIGH | 1.88 (0.86-2.06) in | 2.03 (0.92-1.81) HIGH | 2.04 (0.96-1.70) HIGH | 2.03 (0.83-1.93) HIGH | 2.08 (0.95-1.79) HIGH | 2.03 (1.04-2.00) HIGH | 1.91 (1.05-2.44) in |
| `nn_median_m` | 14.3 (8.92-23.9) in | 19.3 (7.05-23.8) in | 21.1 (9.51-20.8) HIGH | 18.7 (6.15-22.2) in | 14.9 (6.64-21.5) in | 13.9 (9.57-22.7) in | 17.3 (7.17-20.7) in | 14.3 (8.23-26.7) in | 16.0 (10.6-25.9) in |
| `elongation` | 3.46 (1.31-3.92) in | 3.20 (1.32-4.88) in | 1.88 (1.45-5.27) in | 3.14 (1.19-3.09) HIGH | 3.46 (1.54-3.87) in | 3.63 (1.34-3.66) in | 2.51 (1.42-4.22) in | 3.17 (1.30-3.26) in | 3.98 (1.69-5.45) in |
| `compactness` | 0.43 (0.34-0.89) in | 0.51 (0.41-0.84) in | 0.69 (0.33-0.81) in | 0.49 (0.59-0.88) LOW | 0.43 (0.47-0.84) LOW | 0.46 (0.38-0.86) in | 0.61 (0.46-0.83) in | 0.49 (0.50-0.87) LOW | 0.45 (0.43-0.83) in |
| `coverage` | 0.38 (0.09-0.58) in | 0.18 (0.10-0.49) in | 0.18 (0.09-0.52) in | 0.43 (0.14-0.55) in | 0.38 (0.10-0.36) HIGH | 0.39 (0.12-0.70) in | 0.31 (0.10-0.29) HIGH | 0.43 (0.09-0.54) in | 0.29 (0.10-0.45) in |
| `footprint_median_m2` | 80.9 (43.8-180) in | 79.4 (37.6-174) in | 77.8 (45.0-143) in | 80.9 (37.6-182) in | 80.9 (42.2-130) in | 80.9 (51.0-195) in | 79.2 (39.6-130) in | 80.9 (29.7-200) in | 80.9 (58.3-126) in |
| `orientation_order` | 0.97 (0.10-0.98) in | 0.77 (0.13-0.94) in | 0.96 (0.25-0.98) in | 0.78 (0.09-0.81) in | 0.98 (0.09-0.97) HIGH | 0.92 (0.16-0.96) in | 0.92 (0.08-0.92) in | 0.98 (0.17-0.94) HIGH | 0.85 (0.09-0.87) in |
| `dead_end_ratio` | 0.75 (0.15-0.45) HIGH | 0.45 (0.22-0.66) in | 0.40 (0.16-0.62) in | 0.75 (0.18-0.80) in | 0.50 (0.21-0.54) in | 0.63 (0.24-0.67) in | 0.44 (0.22-0.64) in | 0.75 (0.15-0.42) HIGH | 0.70 (0.22-0.46) HIGH |
| `intersections_per_ha` | 3.11 (0.94-1005) in | 6.25 (0.41-45.3) in | 7.75 (0.28-60.2) in | 3.23 (0.00-29.8) in | 5.45 (0.82-21.8) in | 3.99 (0.12-70.9) in | 11.2 (0.17-17.0) in | 3.11 (1.92-169) in | 3.87 (1.22-184) in |
| `road_km_per_ha` | 0.52 (0.14-1.52) in | 0.62 (0.07-0.64) in | 0.61 (0.08-0.74) in | 0.54 (0.00-0.58) in | 0.79 (0.07-0.41) HIGH | 0.59 (0.02-0.61) in | 0.84 (0.05-0.53) HIGH | 0.52 (0.18-0.70) in | 0.52 (0.14-1.27) in |
| `frontage_aligned` | 0.81 (0.56-1.00) in | 0.80 (0.47-0.87) in | 0.94 (0.45-0.87) HIGH | 0.67 (0.67-0.95) in | 0.81 (0.56-0.95) in | 0.91 (0.48-1.00) in | 0.72 (0.58-0.86) in | 0.88 (0.51-0.99) in | 0.88 (0.59-1.00) in |
| `setback_median_m` | 7.50 (5.64-12.1) in | 7.75 (1.50-13.7) in | 8.20 (2.92-13.4) in | 8.00 (1.14-5.28) HIGH | 7.50 (1.53-13.1) in | 7.45 (2.06-16.4) in | 9.35 (1.50-11.4) in | 7.40 (3.24-12.4) in | 7.45 (3.50-12.9) in |
| `elev_span_m` | 0.60 (0.50-8.38) in | 6.75 (14.4-73.0) LOW | 1.70 (6.00-70.2) LOW | 3.10 (4.35-37.4) LOW | 0.60 (1.28-59.6) LOW | 0.90 (1.81-46.9) LOW | 4.90 (0.55-71.7) in | 1.30 (1.63-18.2) LOW | 3.00 (0.80-57.5) in |
| `slope_median_pct` | 1.36 (0.29-2.20) in | 22.5 (9.32-37.4) in | 4.25 (1.62-31.9) in | 20.0 (2.29-28.4) in | 2.22 (0.54-28.4) in | 2.15 (0.90-20.3) in | 8.63 (0.53-36.9) in | 3.13 (0.99-12.7) in | 5.52 (0.27-21.9) in |
| `body_elev_pctile` | 0.42 (0.24-0.86) in | 0.78 (0.15-0.89) in | 0.53 (0.07-0.35) HIGH | 0.95 (0.51-0.96) in | 0.48 (0.30-0.86) in | 0.61 (0.46-0.83) in | 0.59 (0.22-0.86) in | 0.42 (0.40-0.87) in | 0.63 (0.21-0.57) HIGH |
| `water_within_30m` | 0.38 (0.00-0.38) in | 0.19 (0.00-0.23) in | 0.00 (0.00-0.22) in | 0.00 (0.00-0.34) in | 0.38 (0.00-0.27) HIGH | 0.44 (0.00-0.47) in | 0.19 (0.00-0.25) in | 0.50 (0.00-0.07) HIGH | 0.50 (0.00-0.27) HIGH |
| `over_water_share` | 0.00 (0.00-0.00) in | 0.00 (0.00-0.00) in | 0.00 (0.00-0.00) in | 0.00 (0.00-0.00) in | 0.00 (0.00-0.00) in | 0.00 (0.00-0.00) in | 0.00 (0.00-0.00) in | 0.00 (0.00-0.00) in | 0.00 (0.00-0.00) in |
| `steps_ways` | 0.00 (0.00-9.60) in | 2.00 (0.00-46.5) in | 0.00 (0.00-16.3) in | 0.00 (0.00-47.5) in | 0.00 (0.00-47.0) in | 0.00 (0.00-3.70) in | 0.00 (0.00-48.5) in | 0.00 (0.00-1.70) in | 0.00 (0.00-10.5) in |
| `bridges` | 0.00 (0.00-15.6) in | 0.00 (0.00-11.0) in | 0.00 (0.00-12.0) in | 0.00 (0.00-6.00) in | 0.00 (0.00-8.60) in | 0.00 (0.00-2.70) in | 0.00 (0.00-8.90) in | 0.00 (0.00-2.00) in | 0.00 (0.00-14.0) in |
| `squares` | 1.00 (0.00-1.20) in | 1.00 (0.00-4.50) in | 1.00 (0.00-1.00) in | 1.00 (0.00-3.50) in | 1.00 (0.00-4.60) in | 1.00 (0.00-0.00) HIGH | 1.00 (0.00-3.70) in | 1.00 (0.00-0.70) HIGH | 1.00 (0.00-1.00) in |
| `worship_centrality` | 0.38 (0.23-1.05) in | 0.71 (0.15-0.81) in | 0.64 (0.17-0.99) in | 0.47 (0.07-0.73) in | 0.45 (0.23-0.81) in | 0.45 (0.13-0.75) in | 0.75 (0.23-0.95) in | 0.42 (0.23-0.79) in | 1.23 (0.42-1.53) in |
| `worship_elev_pctile` | 0.69 (0.05-0.98) in | 0.89 (0.28-0.97) in | 0.93 (0.20-0.98) in | 0.81 (0.56-0.97) in | 0.86 (0.05-0.96) in | 0.72 (0.43-0.94) in | 0.91 (0.00-0.77) HIGH | 0.81 (0.22-1.00) in | 0.91 (0.00-1.00) in |
<!-- realism:end -->
