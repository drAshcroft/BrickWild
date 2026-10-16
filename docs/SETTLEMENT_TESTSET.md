# The world settlement test set

A village generator tuned on its own output drifts toward the mean village:
one road, a green, houses turned to the street, all on a flat table. Real
settlements are not like that. They are on hills, in valleys, on islands,
over water, under cliffs; they straggle, cluster, climb and split. This set
is a sample of **real** towns and villages chosen to **span** that variety,
not to average it, measured so that the generator can be compared with it.

| File | What it is |
|---|---|
| `tests/fixtures/settlements/world_settlements.json` | the set: per site, its environment, its measured arrangement, the nearest `VillageSpec`, and what no `VillageSpec` can say |
| `docs/images/settlements/settlement_sheet_*.png` | every measured site drawn at one scale: buildings, streets, paths, water, walls, contours |
| `tools/settlements/survey.py` | the pipeline that makes both, from public data, cached |
| `tools/settlements/curated_sites.json` | the hand-picked unusual sites and the phenomenon each covers |
| `tests/suites/village_world_sample_suite.gd` | suite `vworld`: keeps the coverage, maps every site to a spec, reports the gaps |

```
godot --headless --path . --script res://tests/run_all.gd -- vworld
```

## Sources

| What | Source | Licence |
|---|---|---|
| where people live | GeoNames `cities500`: 164 162 populated places of 500–25 000 people (`PPL`, `PPLA2`–`5`, `PPLF/L/R/S`) | CC BY 4.0 |
| climate | Kottek et al. 2006, *World Map of the Köppen-Geiger climate classification updated*, 0.5° grid (the Vienna server is down; the Wayback copy is byte-identical) | free for research |
| coast, rivers, lakes, islands | Natural Earth 10 m coastline, rivers + lake centrelines, lakes, land | public domain |
| elevation | Mapzen terrain tiles (SRTM, GMTED, ETOPO1) through the OpenTopoData public API | open |
| the arrangement itself | OpenStreetMap through the Overpass API: buildings, streets, paths, water, walls, places of worship, squares, piers | © OpenStreetMap contributors, ODbL |

The fixture holds only *derived measurements*, with attribution. The raw OSM
geometry stays in `artifacts/settlements/cache/` (gitignored), from which
the survey regenerates the fixture and the sheets byte for byte.

## How the sites were chosen

Two streams, merged.

**1. Environment-sampled (64 sites).** Every place in the pool gets a
Köppen class, its distance to the coast, a major river and a lake, and the
area of the landmass it stands on. The pool is cut into strata — Köppen
group × water (coast / lake / river / inland) × altitude band (<200, <800,
<1800, <3000, ≥3000 m) × island class (continent / large island / small
island) — 130 of them exist. Up to ten places are drawn from each, round
robin over countries so that a well-mapped country cannot fill a stratum:
1 114 candidates. Each candidate gets 17 DEM samples (its centre and two
rings at 300 and 800 m), giving local relief, slope and **prominence**
(above or below its surroundings: a spur, or a valley floor).

The candidates are then put in **maximin order** in a rank-normalised
twelve-axis space (thermal and moisture axes from Köppen, |latitude|,
elevation, relief, slope, prominence, coast, river and lake distance,
landmass, population). Each next site is the one farthest from every site
already chosen; the first *k* of that order cover the space as evenly as *k*
points can. That is the opposite of sampling the mean: the second and third
sites the order chose were a hamlet on a Greenland rock and an atoll in
Micronesia. The survey walks the order, at most three sites per country,
skipping any place where OSM maps fewer than 25 buildings, until 64 are
measured.

**2. Hand-picked (52 named, 50 resolved).** Sampling finds the common environments well
and the strange ones rarely, because the strange ones are rare. Each
hand-picked site names the phenomenon it is here to cover: a street roofed
by a rock overhang (Setenil), roofs that are the next row's street
(Masouleh), a stilt town in a lagoon (Ganvié), a terp, a Rundling, a bastide,
a tidal island, a ksar, a cliff-shelf village reached by tunnel (Guoliang),
5 100 m of altitude (La Rinconada). A hand-picked site the sample also found
is merged into one record carrying both labels.

## What is measured

Each site is a 700 m disc around its named point, with a DEM grid at 90 m.
The **body** is the cluster of buildings linked at 45 m that holds the
most footprint near the centre; most arrangement measures are taken on it.

| Measure | Meaning | The generator's assumption it tests |
|---|---|---|
| `body_share`, `clusters_ge5` | how much of the disc's building stock is one nucleus | one village is one body |
| `clark_evans` | nearest-neighbour ratio: <1 clumped, ~1 random, >1 regularly spaced | — |
| `elongation` | √ of the PCA eigenvalue ratio of the body | street vs nucleated |
| `compactness` | 4πA/P² of the body's hull | round vs straggling |
| `coverage`, `footprint_*` | built share of the hull; house size and its spread | lot sizes |
| `orientation_order` | Boeing's street-orientation order (1 = a grid, 0 = uniform) | planted grids |
| `dead_end_ratio`, `intersections_per_ha` | the street graph | a through road plus lanes |
| `frontage_aligned`, `setback_median_m` | share of houses square to their nearest street (random ⅓); the gap | houses turn to the road |
| `elev_span_m` | 5th–95th percentile of house elevations | flat ground |
| `slope_median_pct`, `slope_p90_pct` | hillside slope under the houses at DEM resolution | flat ground |
| `street_contour_share` | on ground over 8 %, share of street length within 30° of the contour (random ⅓) | streets ignore terrain |
| `house_contour_share` | the same for house long axes | — |
| `body_elev_pctile` | where the body sits in its disc's elevation: 0 the floor, 1 the crest | — |
| `water_within_30m`, `over_water_share`, `adjacent_water_ha` | waterfront, stilts, the largest standing water touched | water at the edge |
| `steps_ways`, `bridges`, `tunnels` | vertical and crossing circulation | — |
| `city_wall`, `squares`, `worship`, `worship_elev_pctile`, `worship_centrality` | edge, common and landmark | the church on the common or the high point |

Then each site is mapped to the **nearest** `VillageSpec` (population from
the body's buildings, culture by country, purpose and water from what is
there, a wall if one is mapped), its arrangement is named in the generator's
own words (`street`, `green`, `crossroads`, `round`, `strand`, `planted`, or
`dispersed`, which no spec can ask for), and every feature that no spec can
express is listed under `unsupported`.

## What the set says

114 sites: 63 sampled, 50 hand-picked, and Ganvié, which the sample found on
its own and the hand list also named. 109 have enough mapped buildings to
measure; the five that do not (Hongcun, Zhouzhuang, Guoliang among them) stay
in the file, flagged, so their absence is visible. Every Köppen group is
present (A 15, B 24, C 39, D 14, E 14), on coast 30, river 39, stream 22,
pond 3, dry 15; 22 stand on landmasses under 500 km², 6 above 3 000 m, 8
beyond the polar circles. The first twelve the maximin order chose:
Kangaatsiaq (GL), Lelu (FM), Øksfjord (NO), Lugar de Guene (CV), Sunndalsøra
(NO), Varennes (CA), Ifalik (FM), Ganvié (BJ), Pakil (PH), Sfântu Gheorghe
(RO), Kisinga (UG), Ust-Nera (RU). None of them is a medieval English green.
The sheets in `docs/images/settlements/` show all 109.

**How varied the arrangement is** (10th percentile / median / 90th, over
the measured sites):

| Measure | p10 | median | p90 |
|---|---|---|---|
| elongation of the body | 1.3 | 2.1 | 4.3 |
| share of the disc's buildings in one body | 0.16 | 0.60 | 0.97 |
| houses square to their street (random ⅓) | 0.51 | 0.79 | 0.99 |
| elevation span under the houses, m | 1.6 | 13 | 52 |
| median hillside slope under the houses, % | 0.8 | 5.3 | 28 |
| street length along the contour, on steep ground (random ⅓) | 0.32 | 0.57 | 0.80 |

The ends of each axis are the test cases: Positano spans 157 m between its
lowest and highest house, La Rinconada 101 m; Rocamadour's houses stand on a
56 % hillside and 89 % of its steep street length runs along the contour;
Mont-Saint-Michel has 166 mapped stairways, Positano 120; Tireli's buildings
are 14 m² granaries and Kampong Ayer's 237 m² stilt longhouses.

**What explains it.** Spearman ρ between environment and arrangement, the
strongest twelve (all in the fixture's `correlations`):

| Environment ~ arrangement | ρ |
|---|---|
| local relief ~ slope under the houses | +0.72 |
| local relief ~ elevation span of the houses | +0.67 |
| altitude ~ slope under the houses | +0.43 |
| local relief ~ dead-end share of the street graph | +0.35 |
| moisture ~ dead-end share | +0.34 |
| altitude ~ elevation span | +0.33 |
| altitude ~ waterfront share | −0.29 |
| latitude ~ waterfront share | +0.28 |
| local relief ~ setback from the street | −0.28 |
| local relief ~ houses square to their street | −0.28 |
| moisture ~ waterfront share | +0.28 |
| coast distance ~ waterfront share | −0.25 |

Relief is the single strongest driver of arrangement. Hilly villages are
built *on* the slope, not on a levelled table: their streets end in more
dead ends, houses sit closer to the street and are less often square to it,
and on steep ground streets follow the contour more than half the time. High
latitudes and wet climates pull houses to the water's edge. Climate and size
alone explain little of the street pattern; the ground does.

**Where the generator stands** (`vworld`'s report). Mapping every site to its
nearest `VillageSpec`:

* **103 of 109** have a feature no spec can say. By frequency: slope 46,
  stairs 37, bridges 34, dispersed 34, contour streets 33, vertical span 32,
  island 22, tunnel 21, beyond the 500-person scale 21, lake shore 16,
  polar 14, waterfront 10, crest 8, altitude 8, valley floor 5, over water 2.
* **The form the spec derives matches the measured one for 2 of 109.**
  `VillageSpec._derive_form` reads only population, purpose and culture, and
  `gate` wins at 200 people, so most real places come out `gate` whatever
  their ground. The measured labels are a heuristic (below), but the
  disagreement is not: nothing in the spec can say *hillside*, *lake shore*
  or *several hamlets*.

The first job this points at is the ground. See
[VILLAGE_TERRAIN.md](VILLAGE_TERRAIN.md): the exporter now reads a real
height grid and reports how it lies under every lot, building and road, and
`tests/fixtures/terrain/` holds three of this survey's sites as test ground.

## Limits

* **OSM coverage is uneven.** 25 mapped buildings is the floor, not a
  guarantee; a place can be half mapped. The sheets show it.
* **Slope is hillside slope.** At 90 m the DEM sees a valley side, not a
  terrace. A terraced village on a 40 % hill reads as 40 %, which is the
  ground it was built against.
* **Population is modern.** GeoNames counts people now; a medieval village
  of 200 may be a commuter town of 5 000. The arrangement of the *old core*
  is what matters, and the 45 m body usually finds it, but sprawl and
  modern grids appear in the sample too and are kept; they are real.
* **Bathymetry is clipped.** Mapzen includes the sea floor. Below −30 m is
  sea level; on a coast all negatives are sea level; inland a shallow
  negative is kept (polders, Siwa).
* **The form names are a heuristic.** They put the place in the
  generator's vocabulary so the two can be compared; they are not a
  morphological classification of record, and they miss: Satemin, the
  textbook Rundling, reads `crossroads`; Monpazier, the textbook bastide,
  reads `street` because its modern ribbon stretches the body; Shibam reads
  `planted`. Trust the measurements over the label.
* **Tiny bodies give noise.** Under about eight buildings the ratios mean
  nothing (Abra Pampa's "coverage" is 12.5); such sites are `dispersed`.
* **DEM holes.** At Kangaatsiaq and Uummannaq (Greenland) the elevation
  source returns sea level for the whole disc; their span and slope read 0.
* **Ghadames** maps its roofed old town as a few huge polygons, so the
  measured body is its modern edge.

## Re-running

```
# the user's venv has numpy, scipy, shapely, matplotlib, requests
C:/projects/.local/Scripts/python.exe -I -X utf8 tools/settlements/survey.py all --data artifacts/settlements --repo .
```

The raw downloads go in `artifacts/settlements/raw/` (`cities500.zip`, the
four Natural Earth GeoJSON files, `kg_ascii.zip` from
`web.archive.org/web/2019id_/http://koeppen-geiger.vu-wien.ac.at/data/Koeppen-Geiger-ASCII.zip`).
Stages are `pool`, `relief`, `select`, `morph`, `report`; each reads the
previous one's file. The public services impose real limits, and the
survey keeps to them:

* **Overpass** is often at capacity. Each site is one query declaring
  `[timeout:60][maxsize:64 MiB]`: under load the server admits modest
  declarations and turns big ones away. Backoff doubles to five minutes; a
  site that still fails is skipped and filled by the next run. Do not run
  two survey processes; the second only earns 429s.
* **OpenTopoData** allows 1 000 calls a day of 100 points each. The full
  survey needs about 900. A thin-OSM site costs no elevation calls.
* **Open-Meteo's elevation API counts each point**, so it allows about a
  hundred such calls a day. Do not switch back to it.
