# Village terrain: reading the ground

A village used to be planned on a table. `VillageBuilder.ground_height` is 0
everywhere except the banks of the village's own water, and the C1 SiteRequest
carries one `terrain.slope` number for a 4.9 km mythsim cell. A consumer with
real ground (VoxelGames) planned the village flat, then cut one pad at the
median height under the whole site and blended a 48 m skirt back into the land
(`CityGrounds.lay`). The world survey ([SETTLEMENT_TESTSET.md](SETTLEMENT_TESTSET.md))
says how far that is from how villages are built: most real ones stand on
ground that falls metres under a single house.

**BrickWild reads the caller's ground, says how it lies under everything it
planned, and plans on it**: the village is sited (an anchor and a yaw) and its
roads are laid by grade (VTER-SITING, VTER-ROADS, "Planning on the ground"
below).

| Piece | Where |
|---|---|
| the reader | `src/village/village_terrain.gd`, `VillageTerrain` |
| the spec's ground | `VillageSpec.terrain` (null = flat, as before) |
| the exporter | `tools/export_village_plan.gd`: `terrain.height` in the request, or `--terrain <grid.json>` |
| the suite | `vterrain`: refusals, three readers agreeing, a known plane, a cliff under a plot, real ground, the exporter |
| real ground | `tests/fixtures/terrain/` (Manarola, Limone sul Garda, Varennes), written by `tools/settlements/survey.py terrain`; `world90/`, every measured world site, by `survey.py terrain-world` |
| the form from the ground | `VillageSpec.read_ground` / `_derive_form_on_ground`, `form_intent`, `FORM_FALLBACK`; see "The form", below |

```
godot --headless --path . --script res://tests/run_all.gd -- vterrain    # ~70 s; the hamlet plan is the cost
# the bounded terrain lane: six villages (plane_30, lake_shore, cliff_band,
# Manarola, Masouleh, Monpazier), the five terrain rules, and one failing
# control per rule -- `tests/suites/village_terrain_lane_suite.gd`
godot --headless --path . --script res://tests/run_all.gd -- lane:village-terrain   # 196 s host
```

## Decisions (VTER-DECIDE, owner, 2026-10-16)

1. **A plan given terrain may differ from the flat plan.** Without terrain,
   every output stays byte-identical to the flat planner's.
2. **Form follows the ground first.** With terrain, the form is derived from
   landform, then water and purpose, then population. Without terrain,
   today's rule (including `gate` at 200 people) is kept unchanged for
   existing callers.
3. **New form names:** `hillside` (terraced, contour streets), `dispersed`
   (several hamlets), `crest` (perched on a hilltop or spur), `shore` (along
   a real shoreline; with a new `lake` water kind), `valley` (ribbon along a
   river under steep sides), `water` (stilts and islands).
4. **Fixtures hold metrics and elevation grids only.** Raw OpenStreetMap
   geometry stays in the gitignored survey cache.
6. **Grade caps by class** (2026-10-16, accepting VTER-ROADS' proposal):
   through roads and lanes 12 % (carts); streets, tracks and paths 30 %
   (walked and led, as hill-village streets are); steeper ways are `steps`.
   A 12 % street on a 30 % hillside could only run along the contour; real
   hill villages climb.
5. **Cross-project changes are made here too:** BrickWild work may amend
   Dm_View's C1 contract and VoxelGames' city grounding directly, on
   branches, with their own tests run.

## The grid: `brickwild.terrain` v1

A regular grid of heights in **site metres**, the frame of every VillagePlan
point: origin at the site centre, +X east, +Y of a plan point = +Z south.
Heights are metres in the caller's own datum; nothing assumes sea level is 0.

```json
{
  "schema": "brickwild.terrain", "schema_version": 1,
  "origin_m": [-210, -210],
  "cell_m": 5,
  "cols": 85, "rows": 85,
  "heights_m": [ ...rows*cols numbers, row-major, row 0 at the north edge... ],
  "water_level_m": 12.0
}
```

* `origin_m` is the site position of node (col 0, row 0). Node (c, r) is at
  `origin + (c, r) * cell_m`. Rows run **south**.
* Either `heights_m` (inline) or `"file": "ground.r32"`: little-endian
  float32, `rows*cols` of them, 4 bytes a node, read **beside the JSON**.
  A 400 m site at 1 m is 640 KB raw and about 2 MB of JSON text. Use the file.
* `water_level_m` is optional: standing water at that height; ground below it
  is wet, and every reading reports its `dry_share`.
* The grid must **cover the planned site** (`plan.site`, at most 400 m on a
  side, often less). The exporter refuses one that does not, with both
  rectangles in the message. Leave a margin; the site's size depends on the
  programme.

Refused, with a reason, never half-read: a wrong schema or version, a length
that is not `cols*rows`, fewer than 2×2 nodes, more than 4 M samples, a cell
outside 0.25–100 m, a non-number, a non-finite height, `|h| > 12 000` (a unit
error: centimetres, millimetres), a missing or short file. A `VillageSpec`
with unreadable ground is not `valid()`.

## The three readers

```gdscript
# 1. a file a baker wrote (header JSON, heights inline or in a .r32 beside it)
var ground := VillageTerrain.from_file("res://out/city-0002.terrain.json")

# 2. the dictionary itself, e.g. the request's own terrain.height
var ground := VillageTerrain.from_dict(request["terrain"]["height"], request_dir)

# 3. in-process: any sampler in SITE metres
var ground := VillageTerrain.from_sampler(
    func(x: float, z: float) -> float: return generator.sample_padded_height(centre.x + x, centre.y + z),
    Rect2(-210, -210, 420, 420), 5.0, water_level)

ground.save("res://out/city-0002.terrain.json")   # header + city-0002.terrain.r32
```

All three of the same ground give the same `fingerprint()`; `vterrain` checks
it. Check `ground.valid()` / `ground.errors()` before trusting it.

## What it answers

| Call | Answer |
|---|---|
| `height_at(p)` | bilinear height at a site point; the edge is held outside the grid (`covers()` says if you asked outside) |
| `gradient_at(p)`, `slope_at(p)` | dh/dx, dh/dy over one cell; rise over run (0.1 = 10 %, 1.0 = 45°) |
| `under(poly)` | how the ground lies under a lot, footprint or common: `min_m max_m mean_m span_m slope_max slope_mean dry_share low_m high_m` |
| `profile(points, step)` | along a road: `heights_m length_m rise_m fall_m grade_max` |
| `bounds()`, `covers(rect)`, `relief()`, `summary()`, `fingerprint()` | the grid itself |

`under()` samples the polygon on a half-cell lattice **plus every vertex**. A
centre sample proves only the centre (VoxelGames found this the hard way: an
8° centre with a 76° break across the site). `vterrain` puts a 6 m cliff
through a plot whose centre is flat and requires `under()` to see it.

`span_m` is the cut-and-fill a flat platform under that polygon would need;
`low_m` → `high_m` is the direction the plot rises.

## What the SitePlan gains

Only when the request has ground. **Without it the plan is byte-identical to
before.** With it the plan itself may differ (decision 1): `vterrain` checks
that every key the flat SitePlan has is still present with its type, that the
sited plan says where it stands (`site.anchor_m`, `site.yaw_deg`), and that a
flat request grows no ground block.

```json
"ground": { "schema": "brickwild.terrain", "source": "city-0002.terrain.r32",
            "origin_m": [...], "cell_m": 5, "cols": 85, "rows": 85,
            "min_m": 62.0, "max_m": 555.0, "relief_m": 493.0,
            "site": { ...under(site rect)... }, "water_level_m": null,
            "fingerprint": "dd741a36737c9a9b" },
"lots":      [ { ..., "ground": { ...under(lot poly)... } } ],
"buildings": [ { ..., "ground": { ...under(footprint)..., "door_m": 87.357 } } ],
"roads":     [ { ..., "ground": { "points_m": [...per vertex...], "length_m", "rise_m", "fall_m", "grade_max" } } ],
"commons":   [ { ..., "ground": { ...under(common)... } } ],
"terrain":   { ...the request's envelope..., "height": "brickwild.terrain" }
```

The grid itself is never echoed back. A note says where the flat plan and the
ground disagree most:

```
terrain: 58.7 m of relief under the site; 6 of 9 buildings stand on more than
1.5 m of fall (most: site:city-0101/b-000, 2.7 m). The plan is laid out flat;
buildings[].ground says where to cut, fill or step
```

That is `thorn-hamlet` on Limone sul Garda's real ground: its through road
falls 44 m over 226 m at a steepest grade of 48 %.

## For VoxelGames

What changes now, without waiting for terrain-aware planning:

1. **Bake the ground with the plan.** Where `bake_city_sites` asks for a
   SitePlan, sample the generator first, over the site plus a margin, at the
   grid your foundations need (5 m matches the footprint validator from
   ARCH-DOC; 1–2 m sees a terrace):
   `VillageTerrain.from_sampler(...).save(path)`, then
   `export_village_plan.gd -- --request ... --terrain path`.
2. **Ground each lot, not one pad.** `CityGrounds` can stand each building
   on its own `ground.mean_m` (or `door_m` for the threshold) with a local
   skirt, instead of one median pad for the city. `span_m` says how much of
   that is cut and how much fill; `low_m` / `high_m` say which way to step a
   plinth; over about a storey of `span_m`, the house wants a basement or a
   stair rather than a fill.
3. **Grade the roads by their profile.** `roads[].ground.points_m` is the
   height at each vertex; `grade_max` says where a cart cannot go and steps
   belong.

The grid is in BrickWild's site frame. Pass the city centre into the sampler,
as above, and the plan's points and the grid agree without any transform.

## Reading the ground: `VillageSiteAnalysis` (VTER-ANALYSIS)

Before a planner places anything it reads the ground once, over the site:

```gdscript
var a := VillageSiteAnalysis.of(spec.terrain, plan_site_rect)   # 5 m cells, cached
a.class_at(p)            # &"crest" &"spur" &"bench" &"open_slope" &"valley_floor" &"shore" &"flat" &"water"
a.slope_at(p)            # the cell's mean slope, rise over run
a.buildable(p, &"plot")  # dry and the cell's STEEPEST facet within the cap (&"cart" &"plot" &"path" &"steps")
a.level_regions(VillageSiteAnalysis.LEVEL_MAX, 2000.0)   # gentle dry components, largest first
a.highest_point(region); a.best_bench(1500.0)
a.contours(5.0)          # [{height_m, points, closed}] by marching squares
a.streams()              # D8 drainage polylines, only when no water_level_m was given
a.wet_at(p); a.water_distance_at(p); a.tpi_at(p); a.flow_area_at(p)
print(a.ascii_map({}, true))   # ~ , ^ A v = _ . per class, # past a footpath, * stream
```

`src/village/village_site_analysis.gd`; suite `vanalysis` (~15 s; every
synthetic landform's defining cells, and the twelve real 30 m grids).

| Constant | Value | Why |
|---|---|---|
| `CART_MAX` | 0.12 | a loaded cart; the classic upper limit of a made road |
| `PLOT_MAX` | 0.35 | a house plot on a stepped plinth; the survey's hill villages build to here |
| `PATH_MAX` | 0.60 | a footpath; beyond it, steps or nothing |
| `LEVEL_MAX` | 0.08 | level ground: a bench, a level region |
| `FLAT_MAX` | = `CART_MAX` | `flat` is ground a cart crosses in any direction; at 0.08 Monpazier's rolling plateau (median 10 % on the 30 m grid) read two-thirds `open_slope` |
| TPI annulus | square ring 30–150 m | a village's scale: a street to a quarter; summed-area table, O(cells) |
| `TPI_HIGH_M` / `TPI_LOW_M` | +10 / −10 m | clears the synthetic cliff's rim (±7.4 m) and keeps a 40 m hill top (+19), a spur ridge (+19) and a valley floor (−15) |
| summit | within 3 m of the highest ground in ±60 m | a crest is the top, not the shoulder |
| ridge / trough | both sides 30 m off ≥ 3 m lower (higher) in one of four directions | a spur's ridge line, not a round hill's shoulder (2.8 m at r = 25) |
| `VALLEY_FLOOR_MAX` | 0.20 | a low cell steeper than this is a valley side |
| bench | slope < 0.08, ground ≥ 0.15 steep both 2 m above and 2 m below within ±60 m | a shelf in a slope |
| `SHORE_M` | 30 m | one or two house rows from the waterline |
| streams | ≥ 5 ha of catchment; none below 2 m relief | a brook that turns a mill |

Decisions worth knowing:

* **Wet is inclusive** (`h <= water_level_m`) where `VillageTerrain.is_wet`
  is strict: a DEM records a lake or the sea at exactly its surface.
* **The analysis reads past the site.** It pads the site with up to 150 m of
  the terrain round it, so the edge cells' TPI, shore and catchment see the
  ground beyond the edge. Where the TERRAIN ends, the annulus is clipped and
  the reading is biased; give a site a margin.
* **A saddle centre reads `flat`**: level, and its ridge and trough cancel in
  the TPI. A planner wanting the pass looks for flat between two crests.
* **Slope has two readings.** `slope` is the mean of the cell's facets (the
  landform); `slope_max` the steepest facet (buildability). A coarse centre
  proves only its centre.
* **Drainage** is priority-flood filled, D8, and flats drained toward their
  outlet and away from higher ground (Barnes et al. 2014), so a dead-level
  valley floor drains down its middle.
* **The analysis cell** is never finer than half the terrain cell: 15 m on the
  real 30 m grids.

Class shares inside ±400 m of the twelve real 30 m grids (`vanalysis` notes;
Hallstatt with the lake the grid records at 503 m, which its fixture does not
carry as `water_level_m`):

| Site | Reading |
|---|---|
| Hallstatt | open_slope 54 %, water 39 %, shore 4 %, valley_floor 2 % |
| Monpazier | flat 55 %, open_slope 44 %, valley_floor 1 %, bench 1 % |
| Satemin, Giethoorn | flat 100 % |
| Castelmezzano, Masouleh, Èze | open_slope 93–96 % |
| Rocamadour | open_slope 68 %, flat 20 %, valley_floor 8 %, crest 3 % |

## The form: derived from the ground (VTER-FORM-DERIVE)

Decision 2, in code. `VillageSpec.generate()` with `terrain` reads the ground
once (`VillageSpec.read_ground`: a `VillageSiteAnalysis` over the planner's
site, `form_window_m()` = `requested_site_m` clamped to 120–400 m, at a 20 m
cell or half the terrain cell) and derives the form from it. **Without
terrain the old rule runs unchanged** — `gate` at 200 people included — and
`form_intent` is simply `form`. `compact_display` is still `planted`.

The reading: class shares over the window, the median and p75 slope of the
dry cells, the level (≤ `CART_MAX`) regions, the window's relief, the
centre's TPI and its **rank** (the share of the ground within 350 m lower
than it), and water: the window's wet share, the wider ground's (450 m) wet
share and the distance from the centre to the nearest wet ground.

First row that holds wins:

| # | the ground and the spec | form |
|---|---|---|
| 0 | an enclosed island within 320 m that the programme fills (`VillageIslandForm.fits_ground`: 0.7 to 4 times the ground the households need, a ring fits it; VTER-ISLAND-FILL, below) | water |
| 1 | half the window is wet (`FORM_DROWNED` 0.5): the DEM drowns the site, it stands at the edge | shore |
| 2 | ≥ 40 % of the ground within 450 m is wet (`FORM_WATER_ROUND`) | water |
| 3 | the centre ≥ 9 m over its 30–150 m ring and over ≥ 75 % of the ground within 350 m | crest |
| 4 | water `coast` or `lake`, and wet ground within 350 m of the centre | shore |
| 5 | water `river` or `lake`, p75 dry slope ≥ 0.25 (steep sides), centre below 55 % of its ground | valley |
| 6 | median dry slope ≥ 0.17, purpose farming/forest, and population < 150 or ≥ 3 separate level shelves | dispersed |
| 7 | median dry slope ≥ 0.17 | hillside |
| 8 | (level ground from here) purpose garrison | gate |
| 9 | water `lake`, purpose fishing | water |
| 10 | water `coast`, purpose fishing | shore |
| 11 | purpose crossroads | crossroads |
| 12 | anything else (market on level ground included) | planted |

Population enters only at row 6. On level ground the survey's real villages
read `planted` at every size from 12 people to 500; the flat rule's `gate` at
200 people is a flat-world habit the ground replaces.

**Fitted, and how well.** The thresholds were fitted on the 109 measured
world sites, each on its own cached 90 m ground (below), against the hand
labels in `tools/settlements/form_labels.json`. Agreement of `form_intent`
with `label_form`: **48 of 84 (57 %) at high or medium confidence, 54 of
109 overall**; the flat rule managed 1 of 84 and 2 of 109. Moving any one
threshold ±20 % keeps it at 54–57 %. `vworld` fails under 52 %. No rule names
a site. The rest of the confusion is mostly flat ground: 9 of the 17 firm
`dispersed` labels and 3 of the 4 `street` labels stand on ground as level as
the `planted` ones, and nothing in the ground or the seven inputs tells them
apart (the survey's own classifier sees the buildings; the spec does not).

**Fallback until each form has a planner.** `VillageSitePlanner` lays the
seven old forms, `dispersed`, `shore`, `valley` and `crest` (each in its own
section below). `form_intent` keeps the derived form; `form` is what is
planned, through `VillageSpec.FORM_FALLBACK`:

| intent | planned as | why |
|---|---|---|
| ~~hillside~~ | ~~street~~ | planned as itself since VTER-FORM-HILLSIDE |
| water | strand | the row along the water the stilts will stand in |
| ~~valley~~ | ~~street~~ | planned as itself since VTER-FORM-VALLEY |
| ~~crest~~ | ~~round~~ | planned as itself since VTER-FORM-CREST |
| ~~shore~~ | ~~strand~~ | planned as itself since VTER-FORM-SHORE |
| ~~dispersed~~ | ~~green~~ | planned as itself since VTER-FORM-DISPERSED |

Each VTER-FORM-* task that gives a form its planner deletes that form's one
line in `FORM_FALLBACK`. The exporter writes `form_intent` beside `form`
(only with ground, so a flat SitePlan's bytes never change) and adds a note:
`the ground derives the 'water' form, which has no planner yet; planned as
'strand' (form_intent keeps 'water')`.

**`lake`.** A new `water` kind: standing fresh water along one side.
`VillageWaterPlan` lays it as it lays a coast (a shore band, kind `lake`);
the mill race and the strand's boats treat it as a coast.

**The world ground.** `tests/fixtures/terrain/world90/<slug>.json` (+
`index.json`, name → file) holds the cached mapzen 90 m grid, ±450 m, of every
measured site, written by `survey.py terrain-world --data <survey dir> --repo .`.
It runs OFFLINE: a cache miss skips the site and names it, never fetches.
Coastal sites (coast within 3 km, or in the measured disc) stand at
`water_level_m` 0; a site with ≥ 15 ha of adjacent water that is not coastal
is a lake shore at the lowest grid height + 0.5 m, and its `about` says
`; lake:` — that is how `vworld` gives its spec `water = lake`. At 90 m most
of that water lies beyond the window, so the spec's `water` carries most of
the water evidence; a finer grid will let the ground say more.

```
python -I -X utf8 tools/settlements/survey.py terrain-world --data <survey dir> --repo .
godot --headless --path . --script res://tools/dump_form_ground.gd   # the readings the rule was fitted on
godot --headless --path . --script res://tests/run_all.gd -- vworld
```

## Planning on the ground: siting and roads (VTER-SITING, VTER-ROADS)

With `spec.terrain` the site planner no longer lays the village on a table.
**Without terrain none of this runs** and every output is byte-identical to
the flat planner's: `thorn-hamlet` and `veld-070` exported before and after,
`cmp` identical.

| Piece | Where |
|---|---|
| where the village stands | `src/village/village_siting.gd`, `VillageSiting` |
| the plan's own ground | `VillageTerrain.sited_view(anchor, yaw, rect, cell)` -> `plan.ground`; `plan.terrain()` |
| roads by grade | `src/village/village_road_router.gd`; `VillageSitePlanner._route_through`, `grade_roads` |
| per-class grade caps | `VillageSitePlanner.ROAD_CLASSES[cls]["grade_max"]`, via `road_rule` |
| lots on dry ground, off cliffs | `VillageLotPlanner.ground_clear` |
| the suite | `vtplan` (about 5 min; planning is the cost) |
| a table over every fixture | `tools/village_terrain_sweep.gd -- [--fixtures a,b] [--forms street,green] [--qa]` |

### Siting: an anchor and a yaw

The planners keep their own frame: an axis-aligned site centred on the
origin, the through road west to east, the common north of it.
`VillageSiting` chooses where that frame is laid on the caller's grid -- an
**anchor** (the site centre, in the grid's metres) and a **yaw** (the frame's
+X, counter-clockwise from the grid's +X in its (x, y)) -- and resamples the
ground into the frame (`sited_view`, at the grid's cell but at most 5 m, over
the largest site plus 160 m). A plan point p stands on the caller's ground at

    anchor + p.rotated(yaw) = anchor + (x cos yaw - y sin yaw, x sin yaw + y cos yaw)

`plan.site_anchor`, `plan.site_yaw` and `plan.ground` carry it; every reading
of a plan point (`plan.terrain().height_at(p)`, `profile`, `under`) needs no
transform. The exporter adds `site.anchor_m`, `site.yaw_deg`, `site.frame` and
a `siting:` note, only with terrain; every `ground` reading is the caller's
ground where the village stands, and the `ground` block still describes the
caller's grid as given (origin, cells, fingerprint).

The choice is a score over candidate frames, lower is better, read off the
FLAT plan of the same spec: its site lattice (11 x 11), its common, and its
through road stretched 2 x along itself (the retries grow the site along its
road):

| Term | Weight | What |
|---|---|---|
| cliff | 20 x share | lattice neighbours steeper than a footpath (60 %) |
| wet | 200 x share | lattice points at or under the water level: nothing on wet ground if any dry ground will do |
| steep | 4 x share | lattice neighbours steeper than a house plot (35 %) |
| road | 20 x grade over 10 %, + 2 x mean grade | the road runs along the frame's X, so this turns X onto the contour |
| common | 30 x slope over 4 %, + 10 x share wet or cliff | the common on level ground |
| water | 2 x (distance - 120 m) / 300 m | only when `spec.water` wants water |
| centre | 1 x distance / 400 m | stay near the caller's centre |

Anchors: a lattice through the caller's origin (step half the site's short
side, 20-60 m) over the grid less the site's half-diagonal, never more than
400 m from the origin (the survey's disc). Yaws every 15 degrees, then four
rounds of halved anchor and yaw steps round the best (under a degree). **A
grid that only just covers the site** -- a consumer that fixes the centre --
keeps the anchor at the origin and chooses the yaw alone, among the yaws that
keep the site's corners on the grid. Deterministic: cached on the ground's
fingerprint, the seed, the form and the flat site.

### Roads by grade

| Class | `grade_max` | Why |
|---|---|---|
| `through` | 12 % | a loaded cart |
| `lane` | 12 % | a cart to the farms |
| `street` | 30 % | the village's own walked way: people, a led mule, a handcart |
| `track` | 30 % | a field track on a hillside is walked and led as much as driven |
| `path` | 30 % | a footpath |
| `steps` | 100 % | NEW: a stair as a street, 2 m wide with 0.5 m verges; only the ground makes one |

* **The through road** is routed by dynamic programming over columns 10 m
  apart (`VillageRoadRouter.route_across`), monotone along the frame's X
  (what every form planner assumes), the state being the lateral offset (1 m
  lattice) AND the heading of the incoming segment, which may change by one
  notch per column (1 m per 10 m, under 6 degrees). §5's bend rule holds by
  construction and there is no staircase to smooth. Cost per metre: 1 +
  25 x grade, + 4000 x grade over 90 % of the cap (never, if there is another
  way), + 500 on standing water; + 3 per notch of turn; + 0.35 per metre off
  the form's own seeded bow. So on gentle ground it is the flat planner's road
  and on a hillside the contour line nearest it, within half the site's depth
  either side. A form that moves its road to stand beside its common (round,
  planted) routes it again through that place (`_repin`). The grade is
  measured again on the FINAL points with `VillageTerrain.profile`, and the
  lot planner never takes a wider retry site whose through road broke the
  cap over a narrower one whose road kept it.
* **Every other road** is laid by its form as before and then graded on its
  final points (`grade_roads`): over its class's cap it becomes a `path`,
  past a path's, `steps`. A lane or field track so re-classed runs straight
  out to the site edge, meeting it square (a footway goes somewhere, and one
  meeting the edge obliquely had no clear width in its last metre), or is
  dropped if that would cross the common or the landmark. The hierarchy is
  restored the same way: a street no longer ending on a street or the through
  road becomes a footway too. Where footways exist and none reaches the well,
  one is laid from the nearest road vertex (crossroads and round forms have
  none of their own).
* **Lots** (`ground_clear`) stand on dry ground and do not cross a cliff:
  corners, edge midpoints and centre above the water level (inclusive), and
  no neighbouring pair of those samples steeper than a footpath.

The checks learned the new class and the new input, nothing else: `steps`
may end on any road (`dead_ends`), a stair must be as clear as a path (nav
`paths`), a well reached by steps is reached (place `well`), the purity twin
carries the ground, and two plans sited differently are not equal.

### What the caps imply

`street_contour_share` counts streets only (`steps` and `path` are excluded,
as in the survey), within 30 degrees of the contour. A way of grade g on a
slope s runs asin(g / s) off the contour: on a 30 % slope every 12 % way is
within 24 degrees of it, which is why streets and field tracks are laid to
30 % -- a village of cart-graded ways only is all contour (share 1.0). On a
**50 % slope** every way a cart, a street or a track may climb is within 37
degrees, and in practice only the contour road survives: the plan there is a
contour road with stairs, share 1.0. The survey's real 50 % villages reach
0.57 with streets steeper than any cap here. Where the siting finds level
ground within reach (a valley floor, the plain beyond a crest, Manarola's
shoulder) the village goes there, and its steep street length is the field
tracks climbing out of it: `vtplan` applies the 0.45-0.80 band only where
most of the street length stands on steep ground (`street_steep_share` >= 0.5).

### Every fixture, 2026-10-16

A 50-person `street` village (seed 4242, 16 buildings measured once) on every
fixture, `tools/village_terrain_sweep.gd -- --forms street --qa`. Grades are
the steepest per class on the final points; "contour" is
street_contour_share / street_steep_share; "QA" is VillageQA without
per-building QA and without `pure` (the form is forced).

| Fixture | Anchor, yaw | through | others | contour | common | Placed | QA |
|---|---|---|---|---|---|---|---|
| plane_5 | (0, 0), 358 | 0.3 % | path, track, lane 5 % | - | 5.0 % | 16/16 | ok |
| plane_15 | (0, 0), 358 | 0.5 % | path, track 15 % | 0.65 / 1.0 | 15 % | 16/16 | ok |
| plane_30 | (0, 0), 358 | 1.0 % | path, track 30 % | 0.65 / 1.0 | 30 % | 16/16 | ok |
| plane_50 | (0, 0), 358 | 1.6 % | steps 50 % | 1.0 / 1.0 | 50 % | 16/16 | ok |
| valley | (0, 0), 0 | 0 % | path, track 30 % | - | 0 % | 16/16 | ok |
| river_valley | (0, -51), 359 | 0.5 % | path, track 30 % | 0.65 / 1.0 | 28 % | 16/16 | ok |
| spur | (-28, 0), 71 | 1.4 % | path, track 27 % | 0.64 / 1.0 | 27 % | 16/16 | ok |
| crest | (14, -318), 180 | 0.1 % | path, track 20 % | - | 0 % | 16/16 | ok |
| saddle | (0, 0), 45 | 0.1 % | lane 8 %, track 5 % | - | 1.3 % | 16/16 | ok |
| cliff_band | (0, 0), 0 | 0 % | 0 % | - | 0 % | 16/16 | ok |
| lake_shore | (0, 0), 358 | 0.5 % | 8 % | 0.77 / 0.38 | 8 % | 16/16 | ok |
| island | (-3, -87), 181 | 8.1 % | path, track 16 %, **lane 15.6 %** | 0.55 / 1.0 | 16 % | 16/16 | common fronting, lane hierarchy |
| Castelmezzano | (180, 203), 262 | 6.7 % | path 6 %, steps 43 % | - | 11 % | **7/16** | housed |
| Èze | (-23, -219), 323 | 10.8 % | lane 11.9 %, track 23 %, steps 53 % | 0.52 / 0.85 | 5.5 % | 16/16 | tavern 78 m from a gate |
| Giethoorn | (0, 0), 121 | 2.7 % | under 4 % | - | 0.1 % | 16/16 | ok |
| Hallstatt | (93, 3), 158 | 11.9 % | track 15 %, steps 49 % | 0.31 / 0.79 | 9.3 % | 16/16 | tavern 90 m from a gate; one stair pinched |
| Manarola | (-87, 6), 59 | 3.5 % | path 27 %, track 25 % | 0.17 / 0.43 | 3.0 % | 16/16 | ok |
| Masouleh | (-3, 135), 357 | 2.5 % | street, track 24 % | 0.41 / 0.95 | 24 % | **5/16** | housed |
| Monemvasia | (-143, 228), 145 | 8.2 % | track 16 % | 0.06 / 0.57 | 3.3 % | 16/16 | ok |
| Monpazier | (31, -8), 265 | 3.9 % | track 11 % | 0.23 / 0.42 | 3.6 % | 16/16 | ok |
| Positano | (127, 138), 160 | 7.9 % | path 26 %, steps 27 % | - | 7.0 % | **12/16** | housed |
| Rocamadour | (-177, -84), 265 | 9.2 % | track 16 % | 0.35 / 0.42 | 5.1 % | 16/16 | ok |
| Satemin | (0, 0), 236 | 2.9 % | under 4 % | - | 3.5 % | 16/16 | ok |
| Ushguli | (-53, -37), 169 | 10.5 % | street 18 %, steps 31 % | 0.41 / 0.56 | 8.3 % | 16/16 | ok |

Every road is within its class's cap except the island's landmark lane
(15.6 %: the lot planner's service lanes are laid after grading and a lane
is the only class that may dead-end at its lot). No lot is on water or across
the cliff band. Plan time 7-13 s each with the buildings measured.

### For VoxelGames

The plan arrives turned and placed: apply `site.anchor_m` and `site.yaw_deg`
to every plan point before grounding it, and stand each building on its own
`ground` (`door_m` for the threshold). `steps` roads are stairs: grade them
as flights, not ramps.

### Not yet

* **switchbacks** -- the through road is monotone along its axis and the
  bend rule (25 degrees per 20 m) forbids a hairpin. On the two steepest real
  grids (Masouleh, Castelmezzano: 40-60 % hillsides) fifty people need a
  270-315 m site and no such road crosses it at 12 % (0.27-0.50 if allowed),
  so the lot planner keeps the narrower site whose road kept the cap and
  leaves households unhoused (VillageQA `housed`). The hillside form lays
  terraces and stairs (VTER-FORM-HILLSIDE) but not a hairpin;
* ~~**the real hillsides' contour share**~~ -- mostly done in
  VTER-FORM-HILLSIDE: the form's terraces are contour streets and its risers
  keep non-contour length in the denominator, so the 30 % plane reads 0.739
  inside the steep sites' band, and Manarola (0.737) and Masouleh (0.516)
  since HILLS-FIXTURES (see "On the real hillsides");
* ~~graded service lanes~~ -- done in VTER-LOTS: a steep one is not laid;
* **a tavern near a gate on a stretched site** -- Èze and Hallstatt stretch
  to 270-315 m to house everyone, and the tavern's 60 m from a gate goes;
* ~~per-lot platforms and stepped plinths~~ -- done in VTER-LOTS;
* ~~**landform forms**~~ -- `hillside` (VTER-FORM-HILLSIDE), `crest`
  (VTER-FORM-CREST), `shore` (VTER-FORM-SHORE), `valley`
  (VTER-FORM-VALLEY) and `dispersed` (VTER-FORM-DISPERSED) all have planners;
  `water` is the one still planned as its fallback (`strand`);
* **the ground's own water as plan water** -- a lake or sea at
  `water_level_m` is plan water since VTER-LOTS; a river read from the
  drainage (`streams()`) is not yet a `plan.water` polygon with bridges.

## Lots on the ground (VTER-LOTS)

With `plan.ground` every lot is fitted to the ground it stands on and every
building is asked for the fall it stands on. **Without ground none of this
runs**: thorn-hamlet and veld-070 exported before and after, `cmp` identical.

| Piece | Where |
|---|---|
| the platform, the fall, the walls | `src/village/village_lot_ground.gd`, `VillageLotGround` |
| the lot planner's use of it | `VillageLotPlanner._ground_fit`, `_depths`, `_place_on_road` (door rise), `_lane_too_steep` |
| the ground's own water | `src/village/village_ground_water.gd`, `VillageGroundWater` |
| the record | `lots[i]["ground_fit"]` in the plan; `lots[].platform`, `buildings[].ground.platform_m / fall_m / downhill_deg / door_rise_m`, `water[].source = "ground"` in the SitePlan |
| the suite | `vtplan` (its `_lots_on_ground` checks, and Thorn on Hallstatt and Manarola) |
| the table | `tools/village_terrain_sweep.gd -- --forms street,derived --qa` (band, fall, water columns) |

**The platform.** A building's floor stands at the balanced cut-and-fill
level of the ground under its requested rectangle (the least-squares plane's
height at its origin). Below the floor the lot is GRADED to the family's own
ground model (`GroundFall`): level at the platform uphill of the walls (the
bank is cut back), GroundFall's plane across the footprint and on downhill.
The plane's fall is the least that keeps it at or below the natural ground
under the whole footprint, so no foundation is hung over a hollow; on a plane
of natural fall N it is N / 2 -- half is cut away uphill, half is foundation
and steps downhill. The fall is snapped up to 0.25 m and the direction to
15 degrees; the request carries both (`ground_fall_m`, `ground_downhill_deg`,
in the building's LOCAL frame). Because the lot is graded to exactly the plane
the family plans its flights on, every flight lands on the lot's ground.

**Terrace walls.** Where the graded ground leaves the natural ground by more
than 0.6 m along the lot's edge, the lot records a wall there: a polyline,
the most it holds, and whether it holds a `cut` bank above the lot or a
`fill` under it. VillageBuilder emits them as `terrace_wall` components
(VTER-GROUND-MESH, "The ground mesh" below); nothing here builds geometry.

**What a family accepts in a village.** A house or a shop: one storey of fall
(a raised floor and entry steps; the family's own bank storey digs a cellar
and moves the plan, so a village moves the lot instead). A church: its 6 m
terrace. A castle: its 6 m revetted platform. Every other family (a temple)
stands on a level pad cutting or filling at most 1.2 m. A lot whose building
would stand on more, or on more than 1 in 2, is refused and the search moves on.

**The steps are reserved, not guessed.** A house's or a shop's entry flights
are `HouseSlope.flights` run on the building's own flat plan with the lot's
fall set -- below a storey the plan does not move, so these ARE the sloped
house's flights, and the job keeps its generated building for exactly this.
A church's terrace and flight and a castle's talus and entrance flight come
from its sloped mesh, measured once per lattice point of fall and direction
and cached on the job across every retry. Whatever lies outside the lot must
be on its own road's verge at most: never a carriageway, another lot, the
common, the water. The placement keeps the FLAT measured bounds (the walk and
the fire gaps are unchanged); the parts are recorded as `entry_parts` and the
dresser keeps off them. `vtplan` measures the steepest house of each case for
real and requires its sloped bounds inside the flat bounds plus its parts.

**Orientation.** A lot whose front door would stand more than 1.2 m
(seven risers) over its graded ground -- a house set front-downhill -- is
taken only when no lot on the same search has its door nearer the ground. On
a contour road that puts the houses on its downhill side, fronts uphill and
level with the road, and the uphill side across the fall or not at all; every
building still fronts its road.

**Shorter plots on slopes.** A dwelling's or a shop's back yard shortens with
the slope under it, by half at a house plot's cap (35 %); the full depth is
tried after it, for a back door that needs its flight.

**The ground's own water** (`VillageGroundWater`). A grid with
`water_level_m` gives the plan water polygons: the site rastered at 2.5 m,
wet where the ground is at or under the level plus a 0.5 m freeboard (the
strand the water floods; a 30 m grid's shoreline is uncertain by more), kind
`coast` at about 0 m, else `lake`, `"ground": true`. It replaces a coast or
lake spec's own rectangle (not the strand's). Every road is cut back to the
shore where it ran into it; one cut off from the network with it is taken up.
`VillageRoadCheck` accepts a road ending at that shore as it accepts one at
the site's edge (a landing: the through road's own side 4). Lots and service
lanes refuse the water; a road crosses it only on a bridge landing dry.

**Service lanes are graded** (`_lane_too_steep`). The landmark's, the seat's,
a monument's and the stable's lanes are laid after the site planner graded
its roads, and a lane is the one class that may dead-end at its lot, so a
steep one cannot become a footway: on given ground one over a cart's 12 %, or
running down into the water, is not laid and its building looks elsewhere.
The seat (`_place_manor`) then tries both sides of the through road, east of
the common first, at five leans, keeping only a gate that looks at the common
(§9.4 `manor`) -- which is how Thorn's hold finds its terraced lot on
Manarola's hillside above the strand.

**Not yet.**

* ~~**the walk on the steps (VTER-STEPS-NAV)**~~ -- done: on given ground
  the SitePlan's walk also carries `navmesh_3d`, baked from the emitted
  ground with every flight as a link, and every lot has a way in from its
  road ("Steps and the 3D walk" below). `VillageNavCheck` itself still
  judges the flat floor.
* ~~the graded ground itself (VTER-GROUND-MESH)~~ -- done: VillageBuilder
  emits the platforms, the road beds and the walls on the terrain, and the
  assembler stands each building on its platform ("The ground mesh" below).
* **a bank storey in a village** -- a house over one storey of fall moves lot
  rather than dig its cellar (HouseSlope band 3 is the family's; the plan
  changes under it, so the flights cannot be reserved from the flat plan).
* **cost** -- the fit samples the ground per candidate lot and a church or a
  castle is measured once per lattice point of fall and direction: a
  50-person plan takes 16-36 s on a real grid (7-13 s before).

### Against the world set, 2026-10-16

VillageShape over every real fixture (`village_terrain_sweep.gd -- --forms
street,derived --qa`, 50 people, seed 4242; "~" is the form the ground
derives), against the world set's p10-p90 band by relief class -- low
(< 60 m): span 0.5-16 m, slope 0.4-5 %; mid (60-250 m): 2-44 m, 1.2-14 %;
high (>= 250 m): 7.5-72 m, 5-36 %. "Fall" is the most any building stands on
and its share of what its family takes in a village. QA as in the table above.

| Fixture | Form | Relief | Span | Slope | Fall | Placed | QA |
|---|---|---|---|---|---|---|---|
| Castelmezzano | street | high 302 | 8.3 ok | 21.6 ok | 2.50 (96 %) | 8/16 | housed |
| Castelmezzano | ~green | high 369 | **4.8 low** | 18.0 ok | 2.00 (71 %) | 10/16 | housed, stairs pinched |
| Èze | street | high 308 | 14.9 ok | 17.3 ok | 2.50 (96 %) | 16/16 | tavern 78 m from a gate |
| Èze | ~round | high 320 | 10.3 ok | 14.6 ok | 2.25 (80 %) | 16/16 | ok |
| Giethoorn | street / ~planted | low 10 | 1.2 / 1.4 ok | 2.6 / 3.3 ok | 0.50 | 16/16 | ok |
| Hallstatt | street | high 372 | 20.4 ok | 13.9 ok | 2.50 (96 %) | 15/16 | a stair pinched |
| Hallstatt | ~green | high 345 | 17.9 ok | 14.5 ok | 2.50 (96 %) | 15/16 | a stair pinched |
| Manarola | street | mid 215 | 4.5 ok | 7.0 ok | 1.25 (48 %) | 16/16 | ok |
| Manarola | ~strand | mid 230 | 4.7 ok | 6.3 ok | 1.00 | 9/16 | housed |
| Masouleh | street | high 320 | 9.4 ok | 22.9 ok | 2.50 (89 %) | 6/16 | housed |
| Masouleh | ~green | high 279 | 23.2 ok | 23.7 ok | 2.75 (98 %) | 16/16 | stairs pinched |
| Monemvasia | street / ~green | mid 144-172 | 4.1 / 7.2 ok | 9.5 / 13.4 ok | 1.25 | 16/16 | ok |
| Monpazier | street | low 56 | 5.4 ok | **5.1 high** | 0.75 | 16/16 | ok |
| Monpazier | ~planted | low 56 | 2.4 ok | 4.1 ok | 0.75 | 16/16 | ok |
| Positano | street / ~green | high 314-319 | 11.1 / 10.6 ok | 18.8 / 19.3 ok | 2.50 | 14/16 | housed |
| Rocamadour | street / ~green | mid 137 | 5.3 / 3.7 ok | 7.1 / 8.9 ok | 1.25 | 16/16 | ok |
| Satemin | street / ~planted | low 10 | 1.9 / 2.0 ok | 0.5 / 3.9 ok | 0.75 | 16/16 | ok |
| Ushguli | street / ~green | mid 144-155 | 7.5 / 5.6 ok | 13.8 / 12.8 ok | 1.75 (67 %) | 16/16 | ok |

22 of 24 inside both bands; the two outside are marginal (Monpazier's
street at 5.1 % against 5 %, Castelmezzano's green at 4.8 m against 7.5 m on
a site that houses ten of sixteen). No building stands on more fall than its
family takes; no lot is on water. The synthetic planes read one slope
everywhere and so sit above every band's slope by construction; on `plane_50`
the refusal of falls over a storey leaves 11-12 of 16 placed (16 before:
they stood on up to 4 m of fall nobody built for). `vtplan`'s Thorn on
Manarola is a strand on the shore flat (span 0.8 m against 2 m): the form's
choice, noted as a warning (VTER-FORM-SHORE).

## The dispersed form (VTER-FORM-DISPERSED)

Row 6 of the form rule, given its planner: `src/village/forms/dispersed_form.gd`,
`VillageDispersedForm`, reached from `VillageSitePlanner._plan` by one early
dispatch; `dispersed` is in `FORMS_SUPPORTED` and out of `FORM_FALLBACK`.
Without terrain the form is never derived, so nothing flat changes
(`thorn-hamlet` and `veld-070` exported before and after, `cmp` identical).

| Step | What |
|---|---|
| site | a square of 200 + 40 m per hamlet, 260-360 m, within the caller's `site_m`; the lot planner's retries widen it along the road |
| through road | laid and routed by grade as every form's |
| main hamlet | on the through road where the ground just beside it is gentlest in the middle 40 % of the road: the street form's core (common, approach path, ring street, landmark behind the ring). The most central hamlet takes the landmark |
| other hamlets | seats on a 10 m lattice, best "shelf" first: within 30 m, each dry cell counts 1 level falling to 0 at 60 %; first only seats whose ground averages under a house plot's 35 %, then -- never one hamlet -- any. 110 m apart (two hamlets' houses stay beyond the survey's 45 m linkage) |
| spine | each hamlet's way: square off the through road at the seat's own x, through the hamlet, straight out to the site edge (to the fields above); a `track` to 30 %, else `steps` from the start (re-classing would straighten it). It meets the edge square, a quarter metre inside the far edges (the walk grid stops at `end`) |
| hamlet common | 14 m square beside the spine, a path to its well; no house nearer the well than 7 m |
| hamlets | 2-5: one per 4.5 households; households by shelf, at least 3 each, and one hamlet besides the main with 5 where the households allow |
| lots | `assign_jobs` (lot planner hook): each household is cut its lot nearest its own hamlet's well, biggest house first round the hamlets; trades keep their §6 addresses (smithy east, tavern by a gate), the landmark its slot |
| fields | strip fields (to 15 %) and pasture (to 30 %) beside the spines beyond each hamlet, clear of everything (`finish`) |
| wells | the dresser's own well step on every other hamlet's common (`dress_hamlets`) |

`plan.hamlets` carries them; the exporter writes `hamlets` (seat, common,
spine road, households, main, ground) only when there are any.

**What the checks learned.** ScaleCheck's density is measured over the
hamlets' own ground (a 90 m square about each seat): the settlement is its
hamlets, not the fields between, and every household of every hamlet is
counted by `housed`. PlaceCheck: a well may stand on any common; the wealth
gradient measures each house from its own hamlet's common; a farm's edge is
its hamlet's ground. Every other rule is unchanged, and each change is a
no-op for a plan without hamlets.

Suite `vdispersed` (180 checks, ~5 min, most of it measuring the 19
buildings once): 60 farming people on Ushguli (real30), the synthetic
valley, the spur (which derives `crest`; forced) and Rubanda (world90,
labelled dispersed, high confidence).

| Ground | Hamlets (houses / buildings) | body_share | clusters_ge5 | Placed | QA |
|---|---|---|---|---|---|
| Ushguli | 4/7, 5/6, 5/6 | 0.368 | 3 | 19/19 | ok |
| valley | 5/8, 5/6, 4/5 | 0.421 | 3 | 19/19 | ok |
| spur (forced) | 5/8, 5/6, 4/5 | 0.421 | 2 | 19/19 | ok |
| Rubanda | 4/8, 5/5, 5/6 | 0.368 | 3 | 19/19 | ok |

Every hamlet's well is walked to from every gate; every road is within its
class's grade. The survey's dispersed sites read body_share 0.2-0.6.

**Second pass (VTER-DISPERSED-2).** The site is 320-400 m (230 m + 40 m per hamlet) and hamlet seats are 160 m apart
(nearest neighbour measured 160-169 m on Ushguli, valley, spur and Rubanda; suite bound 150-400). The main hamlet's ring joins the through road with at least 9 m of street (else two junctions fall under 8 m); a hamlet's common stands where its whole 90 m ground is inside the site. The site base is tuned: 220/240/250 each broke a QA rule on one fixture (steps link, junction, church rank), 230 passes all four.
Each other hamlet is joined by `_link_hamlet`: `VillageRoadRouter.route_across` (new `pin_last`
pins both ends) in the frame of the line from a foot on the through road to the seat, at the
track's 30 % cap, trying feet every 20 m within 200 m of the seat's x and keeping the shortest
checked track (measured grade to 30 %). Only when no foot gives one does the old straight
fall-line spine (steps where steep) remain. A link may pass no seat within 45 m. Fields follow
a winding track's local direction. The suite checks spacing and that each hamlet's spine is a
routed `track`.
Not yet: a hamlet earns no shrine of its own; the tavern and the smithy keep their §6
addresses at the gates; an enclosed dispersed village gets one enclosure round everything.

## A building on falling ground (VTER-HOUSE-SLOPE)

The "per-lot platforms and stepped plinths" item, for one building at a time.
A village does not call it yet; the request contract is ready for when it does.

**The request.** `BuildingRequest.ground_fall_m` is the total fall across the
building's requested width x length (centred on the origin): the exporter's
`buildings[].ground.span_m`. `ground_downhill_deg` is the way the ground falls
in the building's LOCAL frame, clockwise seen from above with the front at the
top: 0 = toward the front (-Z, the door), 90 = toward +X, 180 = toward the
back, 270 = toward -X. Subtract the building's yaw from a world bearing. Both
default to 0 (flat) and are left out of `to_dict()` then, so every request,
SitePlan and fixture written before them is byte-identical.

**The site model** (`core/ground_fall.gd`). Local y = 0 is the ground at the
uphill-most point of the footprint, and the floor stays where a flat building
has it, so a caller places the origin on the uphill ground. The ground is a
plane from 0 there to -fall at the downhill-most point, continuing beyond it
downhill; uphill of the footprint the site is cut level at 0.

**What stands under a house or shop** (`src/house/house_slope.gd`), by band:

| fall | model |
|---|---|
| up to 1.2 m | coursed foundation: the plinth carried down to the ground under every wall run in 0.30 m courses, each clipped to the ground (`foundation_course`); entry steps wherever a door ends up more than a riser above the ground |
| 1.2 m to one storey | the same, now a raised ground floor: every door above the ground gets `entry_landing` + `entry_steps` (0.17 m risers, 0.30 m treads) straight out or along the wall, whichever reaches the ground in fewest steps without crossing the house, the chimney or another door's flight; a porch or veranda deck is the landing, carried down |
| one to two storeys | a BANK STOREY: the plan digs its cellar (INT-016) and gives it its own exterior door on the downhill wall (`"undercroft": true`, storey -1) with its own steps; uphill it is dug into the bank |
| more than two storeys, or steeper than 1 in 2 | REFUSED by `validate()` with `ground_too_steep`, not clamped: a clamped house would float over its downhill edge, and a planner told why can terrace or move the lot |

Why the cellar for band 3: it is already a real lower storey the planner,
furnisher, nav check, walk export and sheet all know; the only new plan fact
is its one exterior door. Below a storey of fall the plan is untouched and
the flat shell is all still there, triangle for triangle.

**A church** stands on a terrace: the rectangle round its ground masses,
1.2 m wider, held by a coursed `terrace_wall` and paved (`terrace_paving`,
top at -0.03), with a west flight from the terrace edge. Its ceiling is 6 m.

**A castle** stands on a revetted PLATFORM (VTER-CASTLE-SLOPE,
`src/castle/castle_slope.gd`; sizes in `CastleGeometry.SLOPE_*`). Measured
first: every mass of a Norman castle stands at y = 0, so on any fall its
downhill wall foot was in the air. Nothing above y = 0 moves; per part:

| part | model | why |
|---|---|---|
| curtain, towers, gatehouse, barbican | a stepped TALUS (`talus_course`, one host `talus_<edge>` per run): 0.8 m thick at the top, each 0.30 m course set out 0.075 m (1 in 4) further, its outer foot on the ground | the revetted scarp a castle on a hillside is built on; it runs round the union of every grounded part grown by 0.5 m, so it follows the curtain's battered foot and wraps each tower |
| bailey | filled to the castle's ground and paved (`platform_paving`, top at -0.03) behind the talus: retaining wall plus fill | a ward that followed the slope would put the keep, ranges, wall stairs and yard on different levels, and the castle geometry has one ground per ward |
| keep, hall, chapel, yard buildings, props | on the filled bailey | the keep's plinth is the terrace |
| house and manor tiers (the hold, the village's seat), tower house | a terrace: the convex hull of the parts, so the forecourt between the wings is paved | a manor on a levelled platform with its court on it |
| the entrance | the platform runs 2.5 m in front of the gate or porch; a flight (`entry_landing`, `entry_step`, host `entry_gate`) goes from its edge to the ground, straight out or along the front, whichever is shortest | the gate is reached on the level and the flight obeys GroundFall's riser and tread |

The ceiling is `CastleGeometry.SLOPE_MAX_FALL` = 6 m (and 1 in 2 across the
requested rectangle): beyond it `validate()` refuses with `ground_too_steep`.
A sky citadel refuses any fall (`unsupported_option`); a water castle (only
reachable by `plan_override`) emits no platform and says so with an error.
Suite: `cslope` (the 40 x 50 manor seat, the 12 x 14 hold, a 60 x 90 Norman
motte-and-bailey, at 1.0 / 2.5 / 4.0 m, front-to-back and sideways).

Not yet: the castle walk export (`CastleWalkSources`) does not publish the
entrance flight as `route_m` -- the flight is planned from the built outline,
and the walk export never builds the mesh; a castle's `ground_apron`
(off by default) still lies flat at y = 0; the flight is steps, not a ramp.

**Walking.** The flights are in the walk export: `BrickWild.navigation()`
adds `route_m` (threshold, landing, each tread, the foot on the ground) to a
door that has one, for houses, shops and churches. Flat buildings gain no key.

**Not yet.** ~~Yard dressing (barrels, benches, gardens, fences) still stands
at y = 0 and floats on the downhill side~~ -- in a village on given ground the
assembler now sets each yard model on the lowest ground under its footprint
(VTER-GROUND-MESH); a building generated alone, outside a village, still
stands its yard at y = 0. ~~The village walk (`VillageWalk`) does
not read routes~~ -- it does since VTER-STEPS-NAV: each house's flights are
in its lot's `entry_flights` and the 3D walk links them. A front-downhill house in band 3 keeps its front door on the
downhill side and climbs to it by a long flight along the facade -- the
village should turn such lots so the front faces uphill or across the slope.

Suite: `hslope` (house, shop, church at 0 / 1.0 / 2.5 / 4.0 m, sideways and
front-to-back). Pictures: `godot --path . --script res://tools/render_slopes.gd`.

### On piles over water (VTER-FORM-WATER)

The second foundation the request contract takes, beside a fall.
`BuildingRequest.foundation` is `&""` (the ground; the default) or `&"piles"`,
for a house or a shop (`src/house/house_piles.gd`, `HousePiles`). Three more
fields, each 0 by default and left out of `to_dict()` then, so every request
written before them reads and writes byte for byte the same:

| field | meaning | default / range |
|---|---|---|
| `pile_water_m` | the water's depth under the house, surface to bed | 0 - `MAX_WATER_M` 4.0 m; deeper is REFUSED (`water_too_deep`) |
| `pile_freeboard_m` | the floor's height over the water | 0 = 1.2 m; else 0.4 - 3.0 m |
| `pile_deck_m` | how far the landing reaches out from the entrance wall's outer face | 0 = 1.5 m; at most 8 m |

The floor never moves, as on a fall: local y = 0 is still the floor's
underside, and it is now the top of a timber deck. The water's surface is at
-freeboard, the bed at -freeboard - water, every post's foot 0.6 m into the
bed. Under and round the house, host `piles`: `pile_deck` (disjoint
rectangles, top at y = 0: the footprint grown by a 1 m GALLERY all round, the
LANDING beyond it at the entrance, and whatever of the chimney's foot neither
covers), `pile_bearer` (a beam per row of posts), `pile` (a grid no wider
than 2.2 m) and `pile_ladder` (from the landing's edge down to the water,
where a canoe ties up). A house on piles plans NO YARD (`HouseYard.applies`):
there is no ground round it; its facade pieces stand on the gallery.
`exterior_bounds` holds the platform and reaches down to the posts' feet.
Refused, with their codes: piles under anything but a house or a shop
(`unsupported_option`), piles on a fall (`unsupported_option`), an unknown
foundation and a negative depth (`invalid_ground`), pile fields without
piles (`unsupported_option`).

Suite `hpiles` (218 checks, 76 s host): the contract and its refusals; `""`
is vertex-identical to no field; the house on the ground is a subset of the
pile house, triangle for triangle (the same plan built with the foundation
switched off); every post runs from the bearers to 0.6 m under the bed;
nothing of the platform stands above the floor; the deck is at y = 0 outside
the door and the landing reaches `pile_deck_m`; every point of the deck is
within a pile spacing of a post; no yard, every grounded facade piece on the
deck; ComponentCheck; every vertex inside the bound; the plan's own nav check.
House and shop, water 0.5 / 2.0 / 4.0 m, default and 2.0 m freeboard with a
3.0 m landing. The five long-standing styles' fingerprint
(`tools/fingerprint_houses.gd`) is identical before and after.

## The ground mesh (VTER-GROUND-MESH)

With `plan.ground` the 3D village stands on its terrain: VillageBuilder
emits the ground from the terrain, the lots on their platforms, the roads on
graded beds, the walls that hold them, and the water merged into the banks;
VillageAssembler stands every building, prop, plant and yard model on it.
**Without ground none of the new code runs**: seven flat villages built
before and after hash vertex for vertex the same (below).

| Piece | Where |
|---|---|
| the finished ground (field and mesh) | `src/village/village_ground_surface.gd`, `VillageGroundSurface` (cached per plan) |
| the emission | `VillageBuilder._ground_on_terrain`, `_terrace_walls`, `_retaining_walls`, `_water_on_terrain`, `_enclosure_on_terrain` |
| where things stand | `VillageBuilder.ground_height` (the emitted mesh), `VillageGroundSurface.stand_height`; `VillageAssembler` (buildings at `platform_m`, `_ground_yard`) |
| the check | `qa/village_ground_check.gd` (`GroundProbe` reads the Ground mesh back) |
| the suites | `vground` (Wolfmarch Green flat, in lane:village-fast); `vgroundterrain` (three grounds and five controls) |
| the flat proof | `tools/fingerprint_village_ground.gd` |
| pictures | `godot --path . --script res://tools/render_village_ground.gd` |

**The field.** The site is a partition into regions, claimed in priority
order, each with its own height:

| Region | Height | Surface |
|---|---|---|
| natural water | the natural ground, carved | bank colours |
| each road by rank (through first): worn line, carriageway, verges | its BED | wear, road, verge |
| each lot, split on GroundFall's crease | its platform, graded exactly as `VillageLotGround.graded_at` | yard, tinted |
| commons, fields, the bank ring, open land | the natural ground, carved | common, field, bank, ground |

The **natural ground** is the terrain sampled at `CELL` = 2.5 m and carved
by the water, linear over each cell's two triangles -- so the mesh IS it,
not an approximation. A river or pond the spec drew keeps the flat village's
bank (`bank_height`) set on the terrain, its sheet following the ground; the
ground's own water (`"ground": true`) is a level sheet at `water_level_m`,
the bank shelving under it and handed back to the terrain over 1.5 m.

A **road bed** is level across and follows the natural profile along its
centreline (stations every 2 m, averaged over 2 stations each side). Where a
lesser road leaves a greater road's ribbon, the step between the two beds is
spread over `JUNCTION_TAPER` = 8 m. `VillageGroundSurface.road_bed(i)` is the
bed: stations, metres along, heights.

**The mesh.** Every grid triangle is clipped (Geometry2D) against the regions
that reach it, highest first; each piece is triangulated and its vertices set
on its region's height. Where two regions meet at different heights the
higher one drops a vertical **riser** to the lower along the shared edge, so
the ground is closed by construction: pads and road beds are stitched by
setting vertex heights, never by CSG. A region wholly inside a triangle (a
hole) splits the triangle, up to three times. Round the site a skirt carries
the edge down to a common foot. Top faces are single-sided with per-face
normals; risers are double-sided.

**The walls.** Every recorded terrace wall (`ground_fit.terraces`) is emitted
as `terrace_wall` panels, host `lot<i>`; every stretch of a road's verge more
than `TERRACE_MIN` (0.6 m) over or under the ground beside it as
`retaining_wall` panels, host `road<i>`. A panel is a 1 m slab
(`component_slab`, not vertical-depth), 0.45 m thick, from 0.25 m under the
lower ground to 0.1 m over the higher, its body on the held side and its face
2 cm proud of the riser. ComponentCheck re-emits them in `vground`.

**Standing on it.** A building's node stands at its lot's `platform_m`. A
prop, a built prop and a yard model stand on the LOWEST ground under their
footprint (centre and eight points round the rim, radius half the larger
side), so the downhill edge is on the ground and the uphill edge sits into it.
A yard model up on a deck or a porch (planned above 5 cm) stays there. A
plant stands at its origin. "The ground" is the emitted mesh
(`VillageGroundSurface.ground_at`): a point ON an edge between a pad and the
terrain is held by both triangles, and a thing set there stands on the upper
one -- the dresser plants its hedgerow bushes exactly on lot edges, and
standing them on the field's lower side buried them 0.5-3 m in the riser's
face (caught by the check, the first time it ran). Gates, palisades, hedges,
walls and a mill race follow the ground in 3 m pieces; a bridge deck is level
with the higher of its landings and ramps down to the ground at both.

**The check** (`VillageGroundCheck`, on given ground) reads the emitted Ground
mesh back triangle by triangle -- upward faces, vertical faces, water --
never the field it was laid from:

| Rule | Measure |
|---|---|
| prop, yard | lowest point vs the mesh's lowest ground under its footprint, within 6 cm |
| plant | ground line vs the mesh at its origin, as on the flat village |
| building | node at `platform_m` (1 cm), the mesh under its footprint within 5 cm of `platform + GroundFall.ground_y` |
| seam | every metre of every lot edge and road verge: a step over 5 cm is closed by risers (`uncovered` <= 5 cm), and no two ground layers lie more than 5 cm apart |
| terrace | a lot whose recorded wall the mesh steps across has a `terrace_wall` component hosted by it |
| water | no ground over a natural water's surface (2 m lattice) |

`vground` (40 checks, all pass; 10 min on a loaded host, of which the three
terrain villages, 20 people each, are about 6), 2026-10-19. The terrain
villages are now their own suite, `vgroundterrain`:

| Ground | Lots | Pieces / risers (tallest) | Panels terrace / retaining | Pads | Seams (stepped), open | Layers | Water |
|---|---|---|---|---|---|---|---|
| plane_30, street | 6 | 3553 / 583 (5.33 m) | 273 / 223 | 0.012 m | 757 (681), 0.028 m | 0.020 m | - |
| Hallstatt, green | 6 | 7264 / 1033 (2.86 m) | 189 / 207 | 0.012 m | 1174 (984), 0.016 m | 0.012 m | 961 pts, 0.000 m |
| plane_15, green, a river | 6 | 4037 / 726 (2.59 m) | 204 / 186 | - | 959 (751), 0.016 m | 0.012 m | 168 pts, 0.000 m |

The 50-person street village on plane_30 and green village on Hallstatt
(16 buildings each) pass as well: 661 and 530 terrace panels, every terraced
lot named, open seams 0.020 / 0.018 m, pads 0.012 m. The ground costs 1-7 s
per village (Hallstatt's 12 600 pieces: 7.4 s on a loaded host).

The five **negative controls** on plane_30: a yard model at its centre's
ground on the slope (the old placement) floats; a building 0.3 m off its
platform; the risers removed (every step an open seam); the yard laid twice,
0.3 m apart (two layers, and off the pads); the terrace walls unlogged.

**Flat stays flat.** `tools/fingerprint_village_ground.gd` hashes every
surface's vertex, normal, colour and uv arrays, the component and mass logs,
and -- for two of them, assembled -- every building, prop, plant and yard
model transform, for seven flat villages covering every form planner used,
every water (river, stream, coast, pond) and every edge (palisade, wall,
hedge). Base (f10be7e, run from a copy of the untouched tree) and this change:
`diff` empty, all seven lines identical (`artifacts/vter_ground_mesh/flat_base.log`,
`flat_new.log`; e.g. `street-none-none mesh=e5da7c34d26d909e`).

**For VTER-STEPS-NAV.** A `steps` road has a bed like any road (level across,
on its profile): `VillageGroundSurface.of(plan).road_bed(i)` gives its
stations, distances and heights, and its ribbon is already in the mesh as
road and verge pieces, with risers to the lots beside it. Treads go on that
bed; replacing the ramp with flights is a matter of emitting treads over the
bed (or making `bed_at` stepped for that class) -- the check's seams will
then see the treads' risers as any other.

**For VTER-CROSSINGS.** `_crossing` lifts a deck to the higher of its
landings (`height_at` at its two ends) and ramps it down to the ground;
`VillageGroundSurface.water_surface(w, p)` is the water under it, and the
water region drops a riser (an abutment) to a road bed that runs into it.

### Not yet

* ~~**a stepped bed for `steps`**~~ -- done in VTER-STEPS-NAV: a stair
  street's bed is level treads with stone `stair_tread` / `stair_riser`;
* **earth risers under 0.6 m** -- where a pad meets the terrain or a road bed
  by less than `TERRACE_MIN` the step is a vertical face of earth (closed, not
  walled, not blended); two lots' pads meeting each other, or a road's
  junction residual (up to about grade x half-width, 0.25 m on a 12 % road),
  the same. A blend band inside the lot, kept clear of the footprint and the
  entry flights, would soften them;
* **one wall per metre** -- the panels are 1 m each (hundreds per village);
  merging collinear runs would shrink the component log;
* **rivers on steep ground** -- a river the spec draws on given ground is a
  sheet following the terrain, not a chain of pools and falls;
* **a building alone** -- yard models of a sloped house generated outside a
  village still stand at y = 0 (the family's own note in VTER-HOUSE-SLOPE);
* ~~**the vground cost**~~ -- its three terrain villages moved to
  `vgroundterrain`, out of `lane:village-fast`.

## Placing the programme on the ground (VTER-PLACE)

With `plan.ground` the programme is placed by the landform as well as by
§6, and PlaceCheck has seven rules about the ground. **Without ground none
of this runs**: every new branch tests `plan.ground`, and every new rule
returns at once without it (vtplan's `pure` plans a flat village and
requires no ground reading and no `*_ground` failure). `thorn-hamlet` and
`veld-070` exported before and after, `cmp` identical.

**The targets are the world set's.** `VillagePlaceCheck.WORLD_*` are numpy's
linear quartiles over `tests/fixtures/settlements/world_settlements.json`
(`survey.py measure()`, ported by `VillageShape`); `vworld` re-reads the
file and fails if they drift.

| Metric | Sites | p25 | median | p75 |
|---|---|---|---|---|
| `worship_elev_pctile` (the highest place of worship ranked among the body's buildings) | 61 | **0.380** | 0.724 | **0.950** |
| `worship_centrality` | 61 | 0.307 | 0.599 | 0.725 |
| `body_elev_pctile` | 109 | 0.389 | 0.528 | 0.716 |
| `water_within_30m` | 109 | 0.000 | 0.017 | 0.099 |

### What the planners do

| Thing | On given ground | Where |
|---|---|---|
| the church | §6: "on the common, or on the highest ground". Its slot behind the common is ranked among the places the houses will stand (both sides of every through road, street and lane already laid, 14 m out, every 5 m). Below 0.65 of them, it goes up: first to the highest buildable ground within 30 m of the common's edge if that is in the upper half of the rows (it still fronts the common), else the highest within 70 m of the common's centre; it takes the frontage nearest that point and the reservation moves to its lot (`landmark_high_ground` on the lot). Where its own lane would climb past a cart's 12 % it takes the frontage nearest its slot instead of the first legal frontage | `VillageLotPlanner.landmark_high_ground`, `_place_landmark_near`, in `cut_measured` |
| a strand's church | keeps its slot: inland of the one shore row, above it by construction | same |
| the common | already on the levellest ground the siting finds (its `common` term, VTER-SITING); now checked | `VillageSiting` |
| the mill race | of the candidate races the one whose ground falls least along it, none past 1.5 m (a leat follows the contour); the mill then looks along the bank for one | `VillageWaterPlan.mill_race` |
| the seat | unchanged: VTER-LOTS' search already lays it at the head, and on these grounds high; now checked | `VillageLotPlanner._place_manor` |
| the outer field | the gentlest of the track-end candidates (then the site bands), dry and no steeper than pasture (30 %); a `field` to 15 %, else `pasture`; none where all are steeper | `VillageDressContext._field_on_ground` |
| the wood | the steepest of its candidates (beyond the common's far side, the four corners): woods stand where nobody ploughs | `VillageEnclosurePlan.wood_candidates`, `wood_slope` |

**Tried and withdrawn: a landmark term in the siting.** Scoring each frame
by its slot's rank lifted Manarola's church from 0.0 to 0.81 but dropped
Hallstatt's from 0.44 to 0.13, and every moved frame moved roads with it
(two dispersed plans grew junctions 6-8 m apart; Èze's edge lost its
dressing). The slot is mid-village on a contour road whichever way round
it is laid, so the frame is the wrong lever; the church's own placement is
the right one. The siting is unchanged from VTER-LOTS.

### The rules (`qa/village_place_check.gd`)

Every building is ranked by the ground's height under its footprint centre,
the survey's searchsorted rank (the share strictly below). In a dispersed
village each building is ranked within its own hamlet (the nearest seat, as
`gradient` already reads it): a hamlet's church is not "low" because the
next hamlet is forty metres up the mountain. A rank is read only where the
buildings stand on 3 m of fall or more (p95 - p5).

| Rule | The sentence | The measurement |
|---|---|---|
| `landmark_ground` | the church is not at the bottom of its village; with a crest or spur among the houses, it takes the high ground | rank >= 0.38 (the world's p25); >= 0.5 when a `crest` or `spur` cell of `VillageSiteAnalysis` lies within 30 m of a lot. A WARNING, not a failure, when the planner sent the church to the high ground and that is the nearest frontage it could stand on (`landmark_high_ground` on its lot) |
| `common_ground` | the common is on the most level ground the village has | its mean slope <= max(8 %, the median lot's + 2 %) |
| `mill_ground` | the mill is low, at the water; its race runs along the contour | the race's ground falls <= 1.5 m under it; the mill's rank <= 0.5 |
| `manor_ground` | the seat at a prominence or the head | rank >= 0.5, or the outermost building on its side of the common (>= 75 % of the farthest) |
| `fields_ground` | fields on gentle ground | `field` <= 15 %, `pasture` <= 30 % mean slope, none on standing water |
| `wood_ground` | the wood on the steepest ground offered to it | no candidate more than 3 % steeper than the one taken |
| `edge_ground` | the edge stops where the ground turns too steep or too wet | no lot on standing water, none steeper on the mean than a footpath (60 %) |

`VillagePlaceCheck.ground_reading(plan)` prints the readings on one line;
`tools/village_terrain_sweep.gd` prints it under each plan with VillageShape's
`worship_elev_pctile`, `worship_centrality`, `body_elev_pctile` and
`water_within_30m`.

### Against the world set, 2026-10-19

`tools/village_terrain_sweep.gd -- --forms street,derived --qa` over the
twelve real 30 m grids (50 people, seed 4242, 16 buildings). "Survey" is
VillageShape's `worship_elev_pctile` (the survey's definition: the church
ranked among the BODY's buildings, `null` when it stands more than 40 m from
the body's hull); "rank" is PlaceCheck's, among every building (in a
dispersed village, its hamlet's). The real IQR is 0.380-0.950. Before is
f10be7e.

| Fixture | street: before | street: survey / rank | derived form | derived: survey / rank | ground rules |
|---|---|---|---|---|---|
| Castelmezzano | 0.375 | **0.250** / 0.250 (8/16 placed) | dispersed | 0.333 / 0.429 | warn (went high; the nearest frontage a church stands on) |
| Èze | 0.417 | 0.750 / 0.688 | round | 0.813 / 0.813 | ok |
| Giethoorn | 0.438 | 0.813 / 0.813 | planted | null / 0.750 | ok |
| Hallstatt | 0.438 | 0.688 / 0.688 | dispersed | null / 0.333 | **dispersed: landmark_ground** (spur among the houses, wants 0.5) |
| Manarola | 0.000 | 0.692 / 0.750 | strand | 0.444 / 0.444 | ok |
| Masouleh | 0.000 | **0.333** / 0.333 (6/16 placed) | dispersed | 0.200 / 0.200 | ok (span under 3 m in the hamlet, or warned) |
| Monemvasia | 0.625 | 0.625 / 0.625 | dispersed | null / 0.200 | **dispersed: landmark_ground, common_ground** (its main common on 48 %) |
| Monpazier | 0.750 | 0.750 / 0.750 | planted | null / 0.813 | ok |
| Positano | 0.333 | **0.333** / 0.385 (13/16 placed) | dispersed | null / 0.600 | ok |
| Rocamadour | 0.563 | 0.813 / 0.813 | dispersed | 0.800 / 0.800 | ok |
| Satemin | 0.000 | 0.500 / 0.500 | planted | null / 0.438 | ok |
| Ushguli | 0.625 | 0.625 / 0.625 | dispersed | null / 0.800 | ok |

**Street form: 9 of 12 inside the real IQR (7 before), median 0.69 against
the world's 0.724.** The three outside are the three that do not house their
village (6, 8 and 13 of 16 placed: VillageQA `housed`, unchanged from before):
their high side is a 40-60 % hillside on which no church terrace fits, and
the frontage the ground fit allows is mid-village. PlaceCheck says so as a
warning. Every suite fixture passes every ground rule: vtplan's nine cases
and two briefs, vdispersed's four, vcheck.

The survey reads `null` for most derived planted and dispersed plans: their
church stands beyond 40 m of the body's hull (a planted grid's slot is
behind the far street; a dispersed body is one hamlet). That is the survey's
definition holding, not a missing church; PlaceCheck's rank reads them.

### The church on very steep ground (VTER-PLACE-STEEP)

Castelmezzano, Masouleh and Positano (street form, 90 m site) stood at
0.25 / 0.33 / 0.33. Measured causes, in the order they bit:

1. **The site had no room on the high side.** The through road runs along a
   contour and left 20 m between itself and the site's high edge; a church
   plot is 30 m deep, so every high frontage failed `_inside_site`. A street
   village on ground that falls more than `HIGH_SIDE_GRADE` (10 %) of the
   site's depth edge to edge is grown `HIGH_SIDE_GROW_M` (26 m) on its high
   side (`VillageSitePlanner._grow_high_side`), once the through road is
   fixed and before the form lays its streets and tracks (grown afterwards,
   tracks dead-end at the old edge: vtplan `dead_ends`). Manarola (6.7 m across 90 m) and
   Ushguli (7.1 m) stay as they were; a grow at a 3 m threshold dropped
   Manarola's church from 0.75 to 0.5.
2. **A church is not a house plot.** Its lot is `terraced` (the cliff test
   gives way to the ground fit and `CHURCH_MAX_FALL`), but its mean slope
   stays within a footpath's 60 % (`edge_ground`); the high-ground search
   admits ground to `LANDMARK_PLOT_MAX` (60 %) not 35 %.
3. **Fronting the common is worth a share of the relief, not a hillside**
   (`LANDMARK_NEAR_COST_SHARE`, 0.4 of the house rows' relief): the
   near-common bump was taken whenever it beat the median, which on
   Castelmezzano was a 721 m knoll under a 736 m slope. A fixed 4 m moved
   Hallstatt thorn-hamlet's church off its common (vtplan).
4. **Stair streets are where the houses will stand**: `steps` joins the row
   classes the slot is ranked against (Positano's slot read as high until
   its stairs were counted).

The hillside form keeps the search as it was (35 % plots, no stair rows, no
terraced flag, the near-common rule unchanged): it has its own church
terrace, and vhillside's Manarola failed otherwise.

Street church rank (survey / PlaceCheck), before -> after: Castelmezzano
0.25 -> 0.80 / 0.80, Masouleh 0.33 -> 0.78 / 0.78, Positano 0.33 -> 0.40 /
0.44. All twelve real street villages are inside the world IQR 0.380-0.950.
Ushguli's derived dispersed church (0.14, span 7 m) is VTER-DISPERSED-2's,
not this ticket's: it reads the same at the commit before.

### Not yet

* **the dispersed form's main hamlet** -- Monemvasia's main common still
  lies on 50 % (`common_ground`; Hallstatt's church now passes, its hamlet's
  span being under 3 m). `_main_x` scores every through-road vertex between
  0.1 and 0.9 of the site at 0.6 or worse (sea and cliff north of the road
  in this yaw), so a wider window does not help; the lever is the siting yaw
  or the side of the road: VTER-DISPERSED-MAIN-SEAT. Taken 2026-10-26:
  `VillageDispersedForm._turned` scores the best seat on both sides of the
  road and, when the south is cheaper by `TURN_MARGIN` (0.15), re-views the
  caller's grid at yaw + 180 and plans there. Monemvasia's site plan turns
  (170.6 -> 350.6) and its main common falls from 49.9 % to 26.7 %; Ushguli,
  Rubanda, valley and spur keep their yaw. The lot plan and `common_ground`
  on Monemvasia are NOT yet measured: the sweep timed out at 500 s on a
  loaded host (it planned in 18-161 s before);
* ~~**the church on the steepest hillsides**~~ -- VTER-PLACE-STEEP, below;
* **the mill at the valley floor** -- the race is graded and the rule
  checks the mill is low, but a `river` spec's water is still laid where the
  flat village lays it, not along the ground's drainage, so the mill is low
  only where the water is the ground's own (VTER-FORM-VALLEY);
* **the waterfront share** -- `WORLD_WATERFRONT_IQR` is read and checked by
  `vworld` but no planner aims at it yet (VTER-FORM-SHORE);
* ~~**woods** as plan polygons~~ -- `VillageEnclosurePlan.woods(plan)`
  (VTER-WOOD-POLYGON): on given ground, 12 m cells outside the edge, dry, on
  30-100 % (past pasture, short of bare rock), 3 m clear of every lot, field,
  common, water and road; four-connected runs of 6 cells or more, each one
  polygon. The exporter writes them as `woods` (only on ground, only when
  there are any). Site plans with a stand-in edge, before the 100 % cap:
  Monemvasia 4 woods 5.8 ha (its first on 113 %, which the cap now leaves out), Ushguli 4 / 1.5 ha,
  Rubanda 2 / 2.4 ha. The dresser still plants only its few far-side trees;
  trees in the polygons are a dresser change, not made;
* **a crest village** -- the rank rule wants the church at or above the
  median where a crest or spur is among the houses; the compact ring on the
  summit with the church highest is VTER-FORM-CREST's.

## The shore form (VTER-FORM-SHORE)

Rows 1, 4 and 10 of the form rule, given their planner:
`src/village/forms/shore_form.gd`, `VillageShoreForm`, reached from
`VillageSitePlanner._plan` by one early dispatch (and from `plan()` for the
siting); `shore` is in `FORMS_SUPPORTED` and out of `FORM_FALLBACK`. Where the
ground has no water level the form is the straight strand, laid as before.
Without terrain the form is never derived, so nothing flat changes
(`thorn-hamlet` and `veld-070` exported before and after, `cmp` identical).
`lake` (a `water` kind) was already added by VTER-FORM-DERIVE; checked:
`VillageSpec.WATERS` holds it and `VillageWaterPlan` lays it as it lays a coast.

| Step | What |
|---|---|
| siting | `VillageShoreForm.site`, its own: anchor ON the shoreline, yaw so the water is +y. Candidates are the interpolated crossings of the water level (plus `VillageGroundWater.FREEBOARD_M`, so the two agree) on the caller's grid within 400 m of its centre, 36 m apart, nearest first; yaw from the mean direction of the wet ground about each, 7 yaws 15 degrees apart, refined. Scored over the shoreline the frame would see (13 columns): a column with none, the shore's tilt and bends, the steep and cliff share of the strip between the street and the bank, the street's grade, distance from the caller's centre. The site's corners must lie on the grid. The generic siting turns a village away from water (W_WET); this one turns it to face it |
| shoreline | per 10 m column of the frame, the first y from the inland end that is wet and stays wet for 14 m (a pond on the way is no shore); holes filled, median-filtered, smoothed. `plan.shoreline` (exported as `shoreline_m`) |
| shore street | the through road: the shoreline pulled inland by the strand's own lead (4.5 m of road, the measured waterfront row depth, 2 m of bank) along its normal, kept inside the bend rule (9 degrees a vertex), then routed by grade (`VillageRoadRouter.route_across`, the through class's 12 %) within 7 m inland and 1.5 m seaward of that curve |
| common, landmark | the common (18 x 10 m) between the street and the bank at the point among the middle half of the street where it is flattest and the bank 26 m either side is driest and gentlest; the approach path; the landmark inland of it on its own lane (the strand's reservation, unchanged) |
| water | `VillageGroundWater` turns the wet ground into plan water (`ground: true`); lots refuse it |
| lots | the lot planner's ordinary frontage cutting on the through road, both sides (the strand's one seaward row would make a `water_within_30m` of 0.9). The sited trades keep their VILLAGES 6 addresses (the mill's yard must reach the water); households are held to `SEAWARD_SHARE` (0.4) of the street's lots on the water side, so the rest stand behind the street. The lot planner's retries widen the site along the street and deepen the shore reserve exactly as for a strand |
| landing | the dresser's `strand` step: boats and drying racks on the reached bank, unchanged |

**What the fixtures say.** The real water-within-30-m distribution is in
`tests/fixtures/settlements/world_settlements.json` (`morph.water_within_30m`,
building centres within 30 m of mapped water): the 13 sites labelled `shore`
run 0.0-0.658, median 0.121; the three of high confidence 0.284 (Reine), 0.433
(Perast), 0.658 (Hallstatt); the 109 measured sites p10 0, median 0.017, p90
0.324. The suite requires 0.20-0.66.

Suite `vshore` (133 checks, ~15 min on a loaded host, 88-145 s of it measuring
the 16 buildings once): a 50-person fishing village on each ground.

| Ground | Street from water | Bow | Water side / behind | Farthest | `water_within_30m` | Site | QA |
|---|---|---|---|---|---|---|---|
| `lake_shore` (synthetic, straight) | 23.9 m flat | 0.0 | 6 / 10 | 41.4 m | 0.500 | 180 m | ok |
| cove (suite-local, bank a 140 m circle) | 21.8-24.3 m | 24.6 | 6 / 10 | 41.8 m | 0.375 | 180 m | ok |
| Hallstatt (real30, lake 503 m) | 19.8-26.3 m | 3.7 | 6 / 10 | 40.2 m | 0.375 | 144 m | ok |
| Limone sul Garda (world90, lake 62.5 m) | 22.0-27.4 m | 13.4 | 6 / 10 | 40.8 m | 0.438 | 180 m | ok |
| Perast (world90, sea) | 15.2-24.3 m | 11.9 | 6 / 10 | 41.8 m | 0.625 | 180 m | ok |
| Manarola (real30, forced; the ground derives `water`) | 18.5-27.2 m | 7.5 | 6 / 10 | 43.8 m | 0.467 | 225 m | ok |

The street keeps one distance from the water along the curve (spread at most
14 m; the checks are about the plan water, not the fixture's contour), really
bends on the cove (a chord deviation of 24.6 m), every building stands within
the street's mean distance plus 48 m of the water and none on it, boats stand
within 30 m of it, every road is within its class's grade, and VillageQA
passes. The root `tests/fixtures/terrain/limone_sul_garda.json` has no water
level (it derives `valley`), so Limone is read from `world90/`. The siting
takes 0.3-0.6 s; the plan 30-210 s (the lot fit, as for every form).

**Not yet.**

* **water-side structures (VTER-FORM-WATER)** -- no stilts, piers or
  boardwalks; the water is plan water and the boats stand on the bank.
* **a shore that folds back** -- the shoreline is read once per column
  (the first wet ground from inland), so a headland, an islet chain (Reine) or
  a river mouth is followed by its inland side only, and a shore the frame
  cannot make single-valued is smoothed, not traced. One frame, one shore.
* **other water** -- a river or stream spec on a ground with a lake is not
  drawn (the ground's water is); a spec of `none` or `pond` on a drowned site
  gets the ground's water too.
* **resolution** -- on a 30-90 m grid the shoreline is uncertain by more than
  the freeboard; the plan water is the DEM's, not the map's.
* **density** -- the retries widen the site along the street to 144-225 m, so
  the built share is 7.7-13.7 % (the floor is 5 %); the real set's shore
  villages are denser along the water than behind it.
* **the seaward share** is a fitted constant (0.4), not read from a site;
  the real set cannot say which side of its street a house stands.

Lanes at the commit: `vshore` 133 checks green; `vtplan` 1414 green (1 old
warning: Thorn on Manarola); `vdispersed` 161 green; `lane:village-fast` 47
green. `vforms` has one failure (`round` seed 17077, one entrance lane) and
`varchetype_strand` 20 (hall furnishing): the latter fails identically on the
base commit; neither form is touched here.

## The valley form (VTER-FORM-VALLEY)

Row 5 of the form rule, given its planner: `src/village/forms/valley_form.gd`,
`VillageValleyForm`, reached from `VillageSitePlanner._plan` by one early
dispatch; `valley` is in `FORMS_SUPPORTED` and out of `FORM_FALLBACK`.
Oksfjord, Sunndalsora, Hallstatt, Kandovan: a long body between a river and
steep sides. Without terrain the form is never derived, so nothing flat
changes (`thorn-hamlet` and `veld-070` exported before and after, `cmp`
identical).

| Step | What |
|---|---|
| site | long and shallow: 3 street-form sides along the road (260-400 m), 1.4 deep (120-150 m); the lot planner's retries grow it along the road only |
| siting | `VillageSiting` gains a `valley` term (only for this form): per sample of the flat road, the lateral section +-60 m is read in the frame, the lowest ground (middle of a flat floor) must lie 30 m to the road's -y side. The river's wet ground costs a tenth. The anchor keeps `VALLEY_STRETCH` 1.6 of room along the road. If the best frame is over half off a valley floor (a coarse grid, a plain slope) the term is dropped and the standard score is used |
| the river | read per column off the sited ground: the widest wet run when the grid has a water level, else the middle of the lowest ground across the site; median and moving-average smoothed. Not read in a third of the columns: laid 26 m from the road as laid |
| through road | seeded at river + the offset that makes both lot rows most buildable (the hill row beyond the road, the bank row between road and river where 14 m or more), routed by grade (`VillageRoadRouter`) with the river's bank forbidden to the router (its water cost, pointed at the strip), then relaxed above the bank. The road never runs in the river and never crosses it |
| river as plan water | kind `river` (`stream` for a stream spec), "ground": true; with a grid water level the ground's own wet polygons (`VillageGroundWater`) relabelled `river` |
| core | a common long and shallow along the road on its hill side (`_core`), approach path to the well, the landmark straight behind it. No ring street: it put a blob in the middle of a ribbon |
| ways up | `_lanes`: 3-6 (+ half the retry's extra lanes), 40 m apart, off the hill side of the road, square to it, leaning along the valley (never under 35 degrees to the road, the junction rule) as far as the grade needs: a `lane` (12 %, 36 m) where possible, else a `track` (30 %) to the site's edge, else steps |
| households | `assign_jobs` (lot planner hook): houses, cottages and farms each get a slot, four round the common (its two ends on the hill side, two across the road), the rest evenly along the road, sides alternating; each is cut the lot nearest its slot. Left alone the lot planner fills outward from the common into a blob |

Suite `vvalley` (606 checks with Ushguli, ~4 min, 106 s of it measuring the 19 buildings
once; `VALLEY_CASE=<fixture>` runs one, `VALLEY_DUMP=1` prints buildings and
roads): a farming village of 60 on a river. Checks: the ground derives
valley and plans as itself; the river is plan water, no road in it, no
crossing; the road keeps within 45 m of the river at the median; ways leave
the road, every road within its class's grade; **elongation over 3** and
**dead_end_ratio within the survey's high-relief p10-p90 band, 0.22-0.65**
(40 sites with relief >= 250 m: 0.22 / 0.44 / 0.65; elongation there 1.48 /
2.71 / 4.72); every lot fitted to its ground within its family's fall
(`_lots_on_ground`); VillageQA; the export; a flat spec is never valley.

| Ground | Site | Placed | Elongation | dead_end_ratio | Grades (through / lanes / tracks) | QA |
|---|---|---|---|---|---|---|
| river_valley | 297x139 | 19/19 | 5.93 | 0.600 | 0 % / - / 29 % | ok |
| valley | 297x139 | 19/19 | 6.50 | 0.600 | 0 % / - / 29 % | ok |
| Gangotri (world90) | 297x139 | 19/19 | 5.13 | 0.625 | 5 % / 7 % / - (steps 50 %) | ok |
| Ushguli (real30) | 386x139 | 19/19 | 3.20 | 0.600 | 10 % / 10 % / 27 % | ok |

After VTER-PLACE and VTER-FORM-SHORE merged (the church goes to the high ground
near the common; the mill's race may fall 1.5 m) the suite was re-fitted: the
ground-water polygon of a river grid is grown by its 3 m bank (a leat across
the synthetic channel's wall fell past `mill_ground`), the siting and the road
are smoothed over 15 columns (a river bend bowed Lugar de Guene's road 48 m),
and the case list is the three above. Vermont, Ushguli, Lake Argyle and Lugar
de Guene derive valley but fail `common` (23-57 % of 60 %: the church leaves
the slot behind the common for the high ground and the steep side takes the
neighbours) -- see Not yet.

Where VTER-CROSSINGS should put bridges: the body stays on the road's one
bank, the river runs 11-35 m off the road, parallel to it. A bridge belongs
at a lane or a track off the river side of the road across to the far bank;
no way is laid there today (`plan.water_crossings` is empty).

Not yet:

* **steep real gorges and bends** -- SOLVED for world90/rocamadour (now a
  vvalley case; VTER-VALLEY-GORGE, 2026-10-27), by two roots and no switchback:
  (1) the retry ladder jumped 1.0 -> 1.3 and a 1.3-wide Rocamadour has an 18 %
  through road, skipped as over its cap, so the village stayed at 297 m and 17
  of 19 placed; `cut_measured`'s caller now tries the `FINE_WIDTH_STEPS`
  (1.05..1.25) when a wide step was skipped for the cap and people are left
  unplaced (1.05 houses all 19, through 11 %). (2) A stair that runs to the
  site's edge ends in a flat ribbon cap, and `_check_paths` read the last cell
  beside its tip as 0.0 m clear; a dead end is now measured a cell short of its
  tip. A derivation rule was tried and does not separate the gorge: the window's floor
  fall reads Rocamadour 0.06 against Castelmezzano 0.29 and Masouleh 0.18, and
  read_ground (slope_p75, median, rank, relief) does not either (Gangotri has
  p75 0.81 and is a passing valley case); not kept;
  where the river bends out of the straight frame the road leaves it (Lugar
  de Guene: 20-219 m, median 33);
* **the common's fronting on steep sides** -- fixed for Ushguli (20 % -> 73 %,
  VTER-VALLEY-REAL): the common's x was the gentlest ground *behind* it only
  (the dispersed form's `_main_x`); `_common_x` also reads the road's frontage
  on both sides of it, 30 m either way, so its neighbours have ground. world90/
  vermont (57 %) and world90/lugar_de_guene (a bent river, elongation 1.39) have
  not been re-measured;
* **a 90 m grid with no floor in it** -- world90/balan (hand label *valley*:
  the derivation is right, the planner is not) housed 16 of 19. The river is not
  seen, so the road was routed by grade in the street form's half-depth band and
  stood 26 m off the site's middle; `_route` now keeps the unseen-river road to a
  14 m band with four times the dislike of leaving its seed: 19/19 housed, common
  73 %. VTER-VALLEY-THIN / VTER-USHGULI-ELONGATION found the real cause of its gap
  (x = 43..127) and of Ushguli's slide to 2.81 (it had been 3.20): **the farm rule**.
  The lot planner (and `VillagePlaceCheck._check_farms`) keep a farm's walls within
  40 % of the site's shorter side of the edge (55 m of 138); a valley's road runs
  along the middle of the site with the river on one side, so on the river side the
  lot is wet and on the hill side the farm stands 60-66 m from the edge. Of the
  fourteen strung slots the middle ones had no legal lot (probe: `tools/probe_valley_slots.gd`,
  45 spots refused by `_purpose_clear`, the rest by water, lanes and lots) and each farm took
  the nearest legal frontage, 60-300 m away, at the two ends. The slots were never the
  problem and neither was the ground. `VillageLotPlanner.farm_reach(form, shorter)` is
  now the one number both read: 0.5 of the shorter side for a valley (the whole ribbon is
  its outer band), 0.4 for every other form. Ushguli 2.81 -> 7.71, Balan 2.58 -> 6.83;
  both are in `CASES`. vrealism is identical (166 of 207). **Left:** a valley is now a
  straight line, elongation 6-8 against the survey's p90 of 4.72 (a slot span of 0.4 of
  the site brought them to 4.5-5.4 but moved five realism cells, because Cayumba and
  Haldenstein derive the valley form: not kept). A valley wants its households in a
  ribbon with some thickness, not 14 slots in one row;
* **Lake Argyle** (hand label *dispersed*) derives valley with a river forced
  into the spec: the hill row is 30-55 %, the bank row a river strip, one
  76 m stretch has no legal lot and the body splits (elongation 2.7-2.9).
  **Rocamadour** (label *hillside*) is the gorge above. A `level_share`
  floor on the valley row (Balan 0.06, Gangotri 0.10, Argyle 0.17) cannot tell
  them from the valley-labelled Haldenstein (0.30) and Batad (hillside, 0.07);
  `vworld` now notes which sites derive valley with their label and water;
* the road is often straight on a flat floor (the router prefers it);
* lots on the river side exist only where the bank row is 14 m or more;
* a lake spec with no lake in the site gets a river ribbon.

## Bridges on the ground (VTER-CROSSINGS)

Where a routed road meets water on terrain, the bridge is fitted to the
ground. **Without ground nothing changes** (flat evidence below).

| Piece | Where |
|---|---|
| the measure | `src/village/village_bridge.gd`, `VillageBridge.measure(surface, crossing)` |
| the emission | `VillageBuilder._crossing` (deck at `deck_y`, ramps of `ramp`, a `bridge_abutment` component per end) |
| the ground's river | `VillageGroundWater.add` / `channel_width` / `has_river` |
| the check | `qa/village_bridge_check.gd`, `VillageBridgeCheck.check(plan, builder, mesh)` |
| the suite | `vcrossterrain` (`tests/village_crossterrain_test.gd`, about 40 s) |

**The measure.** From the finished ground (`VillageGroundSurface.height_at`,
`ground_at`, `water_at`, `water_surface`), for a crossing route `points`:
the two landing heights, the span (route length) and the wet reach, the
highest water surface under it, and then

* deck centre `deck_y` = higher landing + 0.15, raised if need be to 0.45 m
  (soffit) over the highest water;
* ramp at each end = rise over that landing / 12 %, 1.5 to 6 m;
* abutment at each end: 1.2 m along the road under the deck's end, deck width
  + 0.5 m across, its base at the LOWEST ground under its footprint (centre,
  corners, edge midpoints) and its top 5 cm into the deck.

**The ground's river.** A reach of the ground's own water (`water_level_m`)
that is at most 40 m wide, three times longer than wide, and whose long side
is not on the site edge (a lake clipped to a strip lies along it) is plan
water of kind `river`, `"ground": true`, `"width"` its measured channel
(`river_valley`: 12.5 m). Crossing kind is then a bridge as for any river. If
the spec asks for a river or stream and the ground has one, the spec's strip
is not laid beside it.

**The check** reads the emitted Ground mesh back (`GroundProbe`):

| Rule | Measure |
|---|---|
| abutment | base within 0.1 m of the lowest mesh ground under its footprint; top reaches the deck's underside |
| clearance | the deck's underside at least 0.3 m over the water mesh at every metre of the span |
| landing | each deck end within 1.2 m of the ground it lands on (a ramp carries the rest) |
| count | exactly two abutments per bridge |

**For the valley form (and any form).** Nothing to call: the bridges come out
of the normal pipeline once `plan.water` has the river and `plan.roads`
cross it -- `VillageWaterPlan.crossings(plan.water, plan.roads)` records them,
`VillageBuilder.build(plan)` fits and emits them, `VillageBridgeCheck` judges
them. A form that lays its own river polygon should add it to `plan.water`
(kind `river` or `stream`, `"ground": false` for a sheet that follows the
terrain, `true` for a level one) before `crossings()`.

**Acceptance (river_valley).** `vcrossterrain` lays three roads across the
12.5 m channel (two straight, one oblique with two bends) and checks each:
3 bridges, 6 abutments, base worst 0.000 m of the 0.1 m allowed, deck at
least 1.38 m over the water, spans 16.7 / 16.7 / 17.9 m, and the walk crosses
every one (and does not once the crossings are taken up). Three negative
controls: an abutment 0.5 m off the ground, a deck 1.5 m low, a bridge with
one abutment. The siting's own plans on river_valley (crossroads, green)
each cross the river once and pass.

**Not yet.**

* **drainage streams as plan water** -- a stream read from the D8 drainage
  (`VillageSiteAnalysis.streams()`) on a grid without `water_level_m` is not
  yet a polygon; a river the spec draws there is still the spec's strip laid
  on the terrain (bridged and checked as above);
* **the siting and the channel** -- the siting keeps the village beside a
  channel and the roads run the contour, so a planned village on river_valley
  has one crossing, not the dozen a real river valley would; a through road
  forced along the channel (a 91 m grid, no room to move) runs inside the water
  as one long "bridge" -- the road router's to keep dry (VTER-ROADS);
* **a ford** on terrain is still the level stone slab at the higher landing;
* **abutment walls to the bank** -- the stone is a box under the deck's end,
  not a wing wall; a bank much higher than the deck shows it buried.

## The crest form (VTER-FORM-CREST)

Row 3 of the form rule, given its planner: `src/village/forms/crest_form.gd`,
`VillageCrestForm`, reached from `VillageSitePlanner._plan` by one early
dispatch; `crest` is in `FORMS_SUPPORTED` and out of `FORM_FALLBACK`.
Without terrain the form is never derived, so nothing flat changes
(`thorn-hamlet` and `veld-070` exported on b3e163d and on this branch, `cmp`
identical: `artifacts/vter_form_crest/flat.log`).

| Step | What |
|---|---|
| frame | `VillageCrestForm.frame`, called by `VillageSiting.site` for the form: the ANCHOR IS THE SUMMIT -- the highest dry point within 200 m of the caller's origin that stands 5 m over the mean of the 30-150 m ring round it (ties within 0.5 m: nearest the origin), with the site on the grid. Only the yaw is chosen: the siting's own score of the flat plan, its common term replaced (the common is on the summit whatever the yaw) and its road term doubled, plus how steeply the straight way from the through road to the ring's gate climbs. Falls back to the generic frame when the ground has no such summit |
| site | the summit is the plan's origin; the site runs from the ring's outer row and the church behind it in the north to the through road's strip in the south (an asymmetric rectangle) |
| through road | at the hill's foot, 12 m beyond the outer row's back, routed by grade within 15 m of that line; the village is not on it |
| common | a 16-gon of 8 m radius on the summit, its well, a `path` from the gate to it |
| ring | closed, of straight chords about 19 m long (a lot must not out-reach its chord: a wide church lot overlapped the next chord's ribbon on the inside of the bend at 16 m), each a `street`. Laid on a contour: the height is the mean round the ring radius, and at each bearing the ring goes where the ground is at that height, within 0.6-1.8 of the radius, then smoothed. Radius `8 + 28 + 3` = 39 m up to 25 households, 1.2 m more per household after; the lot planner's retries scale it |
| approach | a `street` from the through road's nearest vertex to the ring vertex due south of the summit; `grade_roads` makes it a path or steps where the ground says so. From 100 people a second approach, to the vertex about 65 degrees round on the gentler side |
| landmark | the church is placed first (`VillageCrestForm.place_landmark`, one hook in `cut_measured`) on the ring's inner frontage at the bearing 40 degrees or more round from the gate where the ground at its depth is highest, nearest 60 degrees on a tie. The lot planner's front-uphill preference is waived for it (`door_ok`: a church inside the ring faces downhill, its steps are the terrace's). Afterwards no other lot whose middle stands within 0.5 m of the church's height is cut (`holds_high_ground`), so it is the highest building |
| houses | on both sides of the ring; the lot planner's own orientation rule puts the big ones on the outer side (their fronts face uphill) |

`plan.crest` carries {summit, radius, ring_height, gate, approaches,
church_dir, high_m}; the exporter writes `crest` (summit, ring radius,
approaches) only when there is one.

**What the checks learned** (each a no-op for a plan without `plan.crest`):
the road check's `through ... passes Nm from the common` is not asked of a
village whose road passes at the foot; PlaceCheck's `gradient` (big houses
nearer the common) is not asked -- on a hill the wealth runs up it, and the
landmark rules say so -- and `common` fronted is a WARNING, not a failure:
the houses front the ring, and between the ring and the common stands the
church.

Suite `vcrest` (209 checks, 5 m 9 s: 65 s of it measuring 16 buildings once;
`tools/crest_probe.gd -- <case>` runs one case; `tools/list_crest_sites.gd`
lists the world sites that derive `crest`: Cayumba, Civita di Bagnoregio,
Oia, Monteriggioni, Bonifacio, Eze, Acoma Pueblo -- Beni Isguen derives
something else). 50 people, `market`, seed 4242. The first three are strict;
Eze and Civita are measured in full and their failures are warnings headed
`open:`.

| Ground | Ring (spread) | Church / tallest other | body_elev_pctile | compactness | Near ring | Through | QA |
|---|---|---|---|---|---|---|---|
| crest (synthetic) | 39 m (0.0 m) | 59.57 / 58.82 m | 0.995 | 0.837 | 0.88 | 6 % | ok |
| spur (synthetic, forced) | 39 m (10.3 m) | 81.10 / 78.28 m | 0.869 | 0.904 | 0.88 | 1 % | ok |
| Monteriggioni (world90) | 39 m (2.0 m) | 271.03 / 270.62 m | 0.991 | 0.927 | 0.88 | 10 % | ok |
| Eze (real30) | 39 m (5.5 m) | 398.40 / 398.00 m | 0.955 | 0.874 | 0.93 | **12.8 %** | tavern unplaced, 15/16 |
| Civita di Bagnoregio (world90) | 50.7 m (6.7 m) | 430.88 / 427.37 m | 0.982 | **0.589** | 0.60 | 11 % | every ring chord steps; no smithy; density 4.5 % |

The acceptance (body_elev_pctile over 0.85, compactness over 0.5, the
landmark the highest building, the walk reaching the church and the well
from the gate) holds on all five; on the three strict grounds the village QA
passes too.

### Not yet

* **a ridge's ring** -- a spur's summit is the top of a ramp, so no contour
  closes round it: the ring spans 10 m of height (the north side is cut at
  0.6 of the radius). It is a ring street all the same, in grade;
* **steep hills** -- Eze (40-50 % flanks) keeps its road 0.8 % over the cart
  cap and loses its tavern; Civita's butte (a 90 m grid, 49 % under the
  common) turns every chord into steps, so the lots lose their frontage;
  both want a ring that climbs (a spiral) where a closed contour is not
  there, and a hillside form's terraced lots (VTER-FORM-HILLSIDE);
* **the houses do not front the common** -- they front the ring;
* **no wall** -- an enclosed spec (Monteriggioni's palisade is dropped in
  the suite's spec) has not been tried round the outer row; the
  enclosure planner sees only the plan's site;
* **larger villages** -- over about 25 households the ring simply grows;
  a second ring or a lower town below the gate is not laid;
* **Beni Isguen** derives another form on its 90 m ground.

## The hillside form (VTER-FORM-HILLSIDE)

Row 7 of the form rule, given its planner: `src/village/forms/hillside_form.gd`,
`VillageHillsideForm`, reached from `VillageSitePlanner._plan` by one early
dispatch; `hillside` is in `FORMS_SUPPORTED` and its line is out of
`FORM_FALLBACK`. The old fallback was a one-street row, and on the 30 % plane
that row was the survey gap: one contour road, no stair streets, houses on
one level. Without terrain the form is never derived, so nothing flat changes.

| Step | What |
|---|---|
| site | the flat planner's square grown into a band along the contour (220 x 164 m for fifty people), deep enough for the terraces below the road and the common above it. The lot planner's retries widen it along the contour only (`site_scale`) |
| through road | routed by grade like every form's, set toward the uphill side of the band to leave room for the terraces below |
| common, landmark | on the UPHILL side of the road; the church or shrine stands over the village, its slot reserved before any lot |
| terraces | three `street`s below the road, 30 m apart, each routed by the SAME router (`VillageSitePlanner._route_through`) over a seed line parallel to the through road: on the 30 % plane all three come out at 1 % and stay streets; on a steeper real hillside `grade_roads` re-classes them as it does every way. The pitch is a lot's depth as well as a terrace: at 20-25 m a house or farm lot between two terraces was refused and the cutter put every house on the through road and the lowest terrace, splitting the survey's body |
| end risers | two `street`s from the through road down to the lowest terrace, through every terrace end. They lean 18 degrees off the fall line, so on a 30 % slope they climb 28.5 % (under a street's 30 %), and they keep real non-contour street length in the metric's denominator |
| cross-lanes | twice per gap, straight down the fall line, class `steps`: on ground this steep a way between terraces is stairs, not a path. Every gap uses the same x, so the two lanes meet a shared terrace at one junction, not two a metre apart |
| field tracks | two `track`s off the lowest terrace out to the boundary, leaning 15 degrees off the fall line (30 % tracks) -- the way to the fields above and a farm's own address |
| households | `VillageHillsideForm.assign_jobs` (the lot planner's hook): the biggest house first, round robin over the through road and the three terraces, each level's homes spread along its whole length. The distance-from-the-common floor is not applied to them: it would forbid returning to an upper terrace after a lower one, which is exactly what a terraced village does |

`plan` carries the terraces as ordinary roads with a `terrace` index (which
the exporter does not serialise; it is a planning key). The exporter's
`form_intent` note is no longer produced for `hillside`.

**Measured on the 30 % plane.** 50 people, farming, seed 4242, the same
fixture and programme as the baseline street row, measured by
`VillageShape` (`tools/village_terrain_sweep.gd -- --fixtures plane_30
--forms hillside --qa`; log `artifacts/hills_contour/after_final.txt`).
The bands are the real steep sites' p10-p90: the 46 measured sites whose
median ground slope is at least 8 %, the survey's own steep threshold
(`world_settlements.json`; recorded below and in SETTLEMENT_TESTSET.md).

| Measure | Before (street) | After (hillside) | Steep sites p10-p90 |
|---|---|---|---|
| street_contour_share | 0.65 | **0.739** | 0.389-0.798 |
| elevation span, m | 16.0 | **31.3** | 14.4-73.0 |
| steps ways | 0 | **4** | 0-46.5 |
| elongation | 2.52 | **3.54** | 1.32-4.88 |
| houses / households | 12 / 12 | **12 / 12** | -- |
| roads | 1 through, 0 terrace streets | **1 through, 3 terrace streets, 2 risers, 4 stair cross-lanes, 2 field tracks** | -- |

The road check and VillageQA pass (`qa ok`); every road is inside its class's
grade (through 1 %, terraces 1 %, risers 28.8/28.2 %, steps 30 %, tracks
28.7/29.2 %). Suite `vhillside` (`tests/suites/village_hillside_suite.gd`)
holds these four bands against the form, checks all three terraces are
streets with a house fronting each, the two risers and four cross-lanes, and
that every household is housed.

### On the real hillsides (HILLS-FIXTURES)

The same form, 50 people, seed 4242, forced to `hillside` on `real30/manarola`
and `real30/masouleh` (Manarola derives `shore`, Masouleh `hillside`). What
the plane did not need, the real ground did:

| Change | Why |
|---|---|
| siting scores a SLOPE (`VillageSiting` `hill` term, hillside only): the 40th percentile of the lattice's cross-site fall against 22 % | the standard score takes the flattest ground, and Manarola was sited on a 5 % shelf (span 3.8 m) |
| the through road and the terraces are LEVEL lines (`_level`: the router's DP over the ground's height measured from the seed's, the seed column pinned) | routed at the cart's 12 % and re-routed per terrace, the three ran together onto one least-grade line on a curved face and crossed each other |
| terrace pitch grows on gentle ground (`TERRACE_RISE_M` 6 m, 30-44 m) and the site deepens with it | Manarola's body slope is 14 %: 30 m gave a 9 m span |
| risers: the pair of tops (`pick_pair`) and each lean (`pick_lean`) are chosen so the riser really is a street on THIS ground; where the face is steeper than the plane's the pair lean the SAME way (parallel) and the site widens by the drift | a street must end on a street: one riser that is stairs re-classes every terrace to a footpath (`grade_roads`), and the contour share is then measured on the through road alone (1.0) |
| field tracks: on given ground each spot takes the least lean, either side, whose track really is one (`_field_tracks`), and four more leave the through road UPHILL | on 35-45 % ground a street that climbs at 30 % is 40-50 degrees off the contour, the only non-contour street the metric can see |
| the common stands on the flattest part of the road's middle 80 % | the place check wants it no steeper than the median lot |
| households per level 3:2:2:5, staggered from the lowest level up (`LEVEL_WEIGHTS`) | measured: the split that keeps span, elongation and contour share in band on the plane AND both fixtures; equal shares failed one or the other |

| Measure | plane_30 | Manarola | Masouleh | Rocamadour | Steep sites p10-p90 |
|---|---|---|---|---|---|
| street_contour_share | 0.611 | **0.766** | **0.794** | **0.616** | 0.389-0.798 |
| elevation span, m | 27.6 | **18.9** | **22.8** | **27.0** | 14.4-73.0 |
| steps ways | 4 | **6** | **6** | **6** | 0-46.5 |
| elongation | 1.42 | **1.67** | **1.56** | **1.61** | 1.32-4.88 |
| households unhoused | 0 | 0 | 0 | 0 | -- |
| profile | plain | plain, gate 48 m | shallow | plain | -- |

Suite `vhillside` (148 checks; 11.5 min loaded host, Manarola, Masouleh and
Rocamadour at 190, 160 and 100 s) holds the four bands, the housing, the grade
caps, the road check and VillageQA on the plane and the three real faces.
Masouleh's contour share (0.794 against 0.798) and the plane's elongation (1.42
against 1.32) have little margin.

### Not yet

* ~~**the real hillsides' own QA**~~ -- done in HILLS-QA: the road check AND
  VillageQA pass on Manarola and Masouleh, gated in `vhillside` (119 checks).
  What it took, structural first:
  * a riser's meeting with a terrace is solved, not iterated (`_riser_x`: the
    fixed-point iteration did not converge where a level line runs steeply
    across the riser); `pick_lean` requires the riser to cross the through
    road and every terrace at 35 degrees or more to the line's TANGENT, either
    hand allowed (`pick_pair` returns each riser's hand); with no pair of
    street risers the risers are stairs placed square to the lines;
  * the level lines are eased and cross-lanes stand on existing vertices
    (`_ease`, `_repair_bends`); the tavern is sited by either gate on given
    ground (the table's `side: west` left Masouleh's tavern unplaced);
  * the through road's cap now has teeth. `grade_roads` has always skipped road
    0 on purpose (a village's one through road is never re-classed; the router
    and the lot planner's `_through_over_cap` held it to a cart's 12 %), so
    nothing reported Manarola's 24 % level road. `VillageRoadCheck`
    `through_grade` fails an over-cap through road unless the plan marks it
    `stepped`: a stair street, which the hillside form sets where its level
    line still climbs past 12 % (the face is too steep for any cart; the real
    Manarola's main street is stairs). The number is unchanged. HILLS-GENERAL
    builds it as the stair street it is: `VillageGroundSurface` gives the bed of
    a `steps` road OR a `stepped` one its treads, so the builder dresses them
    (`stair_tread`, host `road<i>`), `VillageGroundCheck._stairs` holds them and
    `VillageWalk3D` bakes them (`vstepswalk`, `_stepped_case`, Masouleh as a
    hillside, asserts the `stepped` road has treads and stair stones and walks it). No
    switchback is laid; the suite holds a control (the same plan without the flag
    fails `through_grade`);
  * the tavern and a gate: the doc's gate is where a road crosses the
    settlement's edge, and an unenclosed hillside's edge is the site rectangle,
    stretched along the contour. Taking the gate to the built edge was tried and
    does not help Manarola: houses stand 80 m either side of its only tavern
    ground. What works is cutting the site (see HILLS-GENERAL below).
* ~~**the fixture-fitted constants**~~ -- HILLS-GENERAL. HILLS-QA passed on
  Manarola and Masouleh with four numbers fitted to those two faces (level weights
  [5,2,2,3] and a 148 m site on a face over 0.325, the through road's homes beside
  the common over 0.31, `TAVERN_GATE_M` 43, the only one of 40..52 that passed).
  They are replaced by rules; each rule, and what was tried and did not hold:

  | was | now | derivation |
  |---|---|---|
  | `TAVERN_GATE_M` = 43 | a ladder: from `TAVERN_NEAR_M` (56 m, the place check's reach less a lot) down in `GATE_STEP_M` (4 m) to `GATE_MIN_M` (28 m), the site cut to that gate distance from the tavern; the plan with the least `_faults`, the first with none | a gate nearer than a lot and its yard is no gate by the tavern; the plan decides, not a number. Manarola: 48 m (52 m leaves its contour share at 0.87) |
  | homes beside the common over slope 0.31 | when `VillagePlaceCheck.fronted_share` of the plain plan is under the floor (60 %, hamlet 55 %), the lot planner plans again with the through road's homes at the common's short edges (`HILL_PROFILES`, `around_common`); at `common_wants_homes` false nothing changes | what the place check asks of the common is what decides it; Manarola needs none now |
  | 148 m site over slope 0.325 | the SHALLOW profile: `DEPTH_MIN_M` less `LOT_ROW_M` (164 - 16 = 148): one row of lots less below the lowest terrace | the plane keeps two rows of lots below its lowest terrace (32 m); ground that refuses most of a row (Masouleh's 12 % buildable under the lowest terrace) keeps one |
  | level weights [5,2,2,3] over 0.325 | `LEVEL_WEIGHTS_SHALLOW`, with the shallow profile | the lowest terrace has one row where it had two: 5 -> 3 homes, the two terraces between take the two |
  | the slope thresholds 0.31 and 0.325 | the profiles are tried in `HILL_PROFILES` order (plain, around, around + shallow, shallow) and the plan with the fewest `_faults` is kept (VillageQA faults at 100, the steep sites' bands `BAND_*` missed at 1) | the band slopes the form reads IN the plan, on the sited ground, are 0.319 (Manarola) and 0.330 (Masouleh): 0.011 apart, and they want different profiles. No smooth rule of slope separates them |

  What was tried and did not hold, so the next hand does not: homes in
  proportion to the metres a home can stand on (plane and Manarola pass, Masouleh
  has a 12.9 m span against a 14.4 floor); sliding the whole band along the fall
  line to the row with most buildable metres (`pick_row`; it chose the site's far
  edge and squeezed the lowest terrace); whole lot rows below the lowest terrace
  by the fall they stand on (Manarola 1.88 rows, Masouleh 1.82: floor or round
  gives them the same, and Manarola fails at 148 m); the ground under each row
  (Manarola .44/.22/.10 buildable, Masouleh .12/.30/.48: no pattern). The two
  profiles are still two named constant sets; what is measured is which one a
  site gets.

  The third steep real site: **Rocamadour** (real30, band slope 0.422), in `vhillside`
  with Manarola and Masouleh: VillageQA clean, the four bands (contour 0.616,
  span 27.0 m, elongation 1.61, 6 steps), 12/12 housed, the plain profile, no
  cut. It failed the road check at first on a junction the form made: a field
  track off the through road 0.6 m from where the common's path joins it (and
  18 degrees to it). `TRACK_CLEAR_M` keeps a track a junction-apart (8 m) from
  that join. Sites that do NOT yet pass, planned as hillsides by
  `tools/hills_probe.gd`: **Monemvasia** (real30, 0.254): the common fronted
  50 % (60 % wanted) and on 46 % ground against lots at 31 %; **Positano** and
  **Castelmezzano** (0.534, 0.428): no smithy (every lot on the through road is
  refused, a fall of 3 to 4.5 m against the 2.6 m a house stands on), density 3 to
  4 %, a 15 degree junction; **Eze**: density 3.8 %, a 400 m site; **Hallstatt**:
  no smithy or tavern. Filed as HILLS-STEEP.

  The hillside on the 3D walk: the `stepped` through road is walked end to end
  (`vstepswalk`, `_stepped_case`: Masouleh, a path from gate 0 to gate 1 that
  climbs the bed's rise, treads and stair stones named). The rest of a hillside
  on the walk is not there yet: planned and built on Manarola, Masouleh or
  Rocamadour, 4 to 14 of its 16 doors are off the gates' island, and the cross-lanes
  (`steps`, laid straight down the fall line) are steeper than a stair can be
  (going 0.20 to 0.25 m against the check's 0.28 m: a stair of 0.15 m risers
  tops out at a 54 % grade, the class allows 100 %). Without the treads on the
  through road the same plan also had a navigation vertex 0.33 m off the ground.
  Filed as HILLS-STAIRS (cross-lanes at a stair's grade, which is the switchback
  question in small).

  HILLS-STAIRS, 2026-10-26 (cross-lanes done; risers and the walk not): a
  cross-lane is laid straight down only where its stair's shallowest inner tread
  is `CROSS_GOING_M` (0.30 m) or more, measured by `VillageHillsideForm.stair_going`
  -- the bed `VillageGroundSurface` would lay (2 m stations, smoothed, level with
  each street's bed inside its 3 m ribbon, the step eased over `JUNCTION_TAPER`),
  then `treads_of`. The ground's `grade_of` is NOT the measure: it samples at the
  grid's cell, and the eased step at each junction makes the stair steeper there
  than the face (a lane reading 0.43 laid 0.20 m goings). Otherwise `_cross_foot`
  takes the nearest column of the terrace below, outward first, that gives the
  treads and meets both lines at 35 degrees; the next gap's lane starts at that
  foot and leans back -- a zigzag with one junction per terrace. Road layout on
  Manarola, Masouleh and Rocamadour: every cross-lane at 0.30 m or more (was 0.25
  at worst). Manarola with lots: 12/12 housed, road check and VillageQA clean.
  Still short: the end RISERS, where `pick_pair` finds no street pair and
  `grade_roads` makes stairs of them (0.20 m goings on all three faces).
  Requiring a stair-legal riser in `pick_pair` (a third pass) changed Manarola's
  pair, broke a bend on the common's path, and still left 0.20 m (a riser bends
  at each terrace). The 3D walk on the hillside (`vstepswalk` `_case`, then the
  hillside in its CASES) has not been re-run.

  HILLS-STAIRS, 2026-10-28 (`tools/probe_hills_walk.gd -- manarola`: `_case` on
  the hillside, 188 s; `tools/probe_hills_roads.gd`: every road's class, grade and
  shallowest tread). `_case` on Manarola's hillside fails 7 of 44: two open seams
  (0.15 m of a 0.51 m step at (-8.1, 16.5)) and 16 seam samples; `road5` (the west
  riser) treads of 0.20-0.25 m; "components claim surface 3, mesh has 10"; 5 of 16
  doors off the gates' island (`b-001/002/004/010/012`, all beside the stepped
  through road) and no 3D path to them; one path 0.131 m off the mesh. The east
  riser and every cross-lane are at 0.30-0.45 m. What was tried on the west riser
  and did NOT hold (reverted): a stair pass in `pick_pair` (cap INF, each stretch
  of the riser between two lines measured by `stair_going`, `going` >= 0.30 or
  0.35) -- the prediction matches the built bed (pred 0.20, built 0.20 on the
  riser as planned) but on Manarola the stair-legal (x, lean) candidates are 8 of
  ~46 and no two are RISER_MIN_SEP_M (70 m) apart; at 40 m a pair is found for some
  profiles, and the plan the ladder keeps (another profile) still takes the old
  pair; Masouleh's east riser got worse (0.25 -> 0.20) and Rocamadour's west stays
  at 0.20. A going of 0.30 m reads 0.25 and 0.30 by turns (the bed is read every
  5 cm), so the figure to ask is >= 0.35. The grade is not the cause (Manarola's
  riser is 0.45 on average): the first stretch from the stepped through road is the
  steep one. Real fix is a per-stretch lean (each hop to the next terrace picks its
  own foot, as `_cross_foot` does, and the terrace ends follow) -- a rework of
  `_riser` and `pick_pair`, with `vhillside` (11 min) and `vrealism` to re-run.
* **switchbacks** -- the router is monotone along the contour, so a hairpin
  up a spur is still not laid;
* **terraces from the ground** -- the terrace lines are offsets of the
  through road re-routed at 12 %, not read from `VillageSiteAnalysis.contours`;
  on a uniform plane they coincide, on a curved hill they may converge.

## Steps and the 3D walk (VTER-STEPS-NAV)

On given ground a `steps` road is a stair, every lot has a way in from its
road, and the SitePlan's `walk` gains a 3D navigation mesh that
NavigationServer3D paths climb. **Without ground none of it runs**: thorn-hamlet
exported on 6affc0d and on the first cut of this branch is `cmp`-identical, and
`tools/fingerprint_village_ground.gd` prints the same seven lines on
terrain-villages 77d97ab (a copy of the tree with the base code) and on this
branch (`street-none-none mesh=e5da7c34d26d909e`, ...).

| Piece | Where |
|---|---|
| stair street treads | `VillageGroundSurface.treads_of` (pure, static), `road_bed(i)["treads"]`, `_tread_regions`; `bed_at` is stepped on a `steps` road or a hillside's `stepped` through road |
| stair stone | `VillageBuilder._stairs`: `stair_tread`, `stair_riser` (host `road<i>`, `lot<i>_steps`), `stair_cheek` |
| a lot's way in | `src/village/village_access_steps.gd`, `VillageAccessSteps.plan` (from `VillageLotPlanner.plan_measured`, before the dresser) -> `lots[i].ground_fit.access` |
| a house's flights in the plan | `lots[i].ground_fit.entry_flights` (`VillageAccessSteps.entry_flights`, from `HouseSlope.flights` kept by `VillageLotGround._house_parts` as `flight_rows`) |
| the 3D walk | `src/village/village_walk_3d.gd`, `VillageWalk3D.bake`; exported by `VillageWalk._add_3d` |
| the check | `VillageGroundCheck` rule `stairs` |
| the suite | `vstepswalk` (`tests/suites/village_steps_walk_suite.gd`) |

### Stair streets

A `steps` road's bed (level across, its smoothed profile along) becomes level
TREADS: the profile is read every 5 cm, and a new tread starts, one
`RISER_STEPS` = 0.15 m up or down, wherever the profile has left the current
tread's level by `STEP_SWITCH` = 0.6 risers. So every riser is 0.15 m and a
tread is never more than 9 cm off the ramp it replaces -- the lots and verges
beside it meet it as they met the ramp, and their risers close the seams as
before. A tread's going follows the grade: 0.45-0.50 m at the beds' steepest
(the smoothed `steps` beds on Manarola and Positano reach 25-31 %); on a
gentle stretch a tread is a landing metres long. Each tread is a region (its
three ribbons cut by the square slab of its stretch of centreline), so the
mesh is stepped exactly (`stairs` measures the mesh at every tread's middle:
0.000 m). On top, VillageBuilder lays a stone `stair_tread` 2 cm proud across
the carriageway and a `stair_riser` at each nosing, host `road<i>`, only where
the road's own regions hold the tread (not under a greater road's ribbon).

### A lot's way in

`VillageLotGround` grades each lot to its building, and the road bed follows
its own profile, so a pad meets its road with a step (0.4-3 m on these two
hillsides). Nothing climbed it, and the flat walk could not see it.
`VillageAccessSteps` reads the step at the lot's front edge opposite the door
(the road found within 2 m outward):

| Step | Way in | Record (`ground_fit.access`) |
|---|---|---|
| at most `STEP_FREE` 0.2 m | `layout: "level"`: the terrace and retaining walls along the front leave a gap there (`VillageBuilder._in_gate`) | `at`, `width_m` |
| more | a FLIGHT: 0.15 m risers, 0.36 m goings (the baking cell's diagonal: no cell touches three treads), 1.2 m wide, else 0.75 m | `poly`, `treads` [{`poly`, `h`, `d`, `len`}], `rise_m`, `riser_m`, `going_m`, `layout`, `width_m`, `origin`, `dir`, `foot_m`, `head_m` |
| no room | `refused`, and why (`tried`) | the walk says the door is cut off |

A flight is tried `straight` in from the front toward the door, then `along`
the front edge inside the lot, then on the `verge` outside it (its own road's
verge, never a carriageway); along the edge it starts with a landing level
with the road, one flight-width long, so a person steps on across its width,
and on the verge it ends with one at the pad's level. It keeps 0.1 m off the
walls, off the yards, off the house's own entry flights and the other lots,
with 0.6 m of pad clear past its head; the nearest head to the door wins. The
strip goes into `entry_parts`, so the dresser keeps off it. The ground cuts
its treads in as regions ahead of the roads (risers close every side), the
builder lays its stone (host `lot<i>_steps`) and a `stair_cheek` panel beside
a tread more than 0.6 m off the pad (never on a road: a verge flight drops to
its road open). On Manarola 6 lots got a flight, on Positano 12 (on terrain-villages 77d97ab, after the crest, valley, shore and place work); none was
refused (before the 0.15 m riser and the verge layout, two were: their walls
stand 0.9 m behind the front).

### The 3D walk

`VillageWalk3D.bake(plan)` bakes with Godot's own baker (Recast,
`NavigationServer3D.bake_from_source_geometry_data`, headless) from what was
BUILT, not from the plan:

* **source**: the emitted ground's upward triangles in the floor regions
  (worn line, carriageway, verge, lot, common -- the stair streets' treads
  among them), each house's entry LANDING (`entry_flights`), each crossing's
  deck and ramps, and the props' aprons;
* **obstructions** (projected, all heights): the flat walk's obstacles
  (`VillageNavCheck.sources`) except that a building is its walls
  (`footprint_poly`), not its eaves -- an eave is over head and over the
  landing -- plus the footprints of every `terrace_wall`, `retaining_wall` and
  `stair_cheek`, plus the treads of the entry flights;
* **agent**: radius 0.25 m, height 1.8 m, climb 0.24 m (12 cells of 2 cm),
  slope 46 degrees; cells 0.25 x 0.02 m; outlines simplified at most half a
  cell and 4 m long; a detail sample every 5 m within 4 cm.

Then, because Recast's heights sit a few centimetres (up to 0.4 m) off:

1. **every vertex is set on the source**: on a stair street, on its PITCH (the
   treads' heights at their middles, a long tread level between points a
   quarter metre from its ends: never more than half a riser, 0.075 m, off a
   tread), when the baker put it near that; else the nearest source layer;
   a vertex the raster set a cell past a raised edge takes the edge it belongs
   to (scored by plan distance plus height);
2. **overlaps are removed**: Godot's conversion of the detail triangles now and
   then lays two triangles on one side of an edge, and the map drops an edge
   three polygons share -- which cut Manarola's through road in two;
3. **coplanar neighbours are merged** (convex, every vertex within 3 cm of one
   plane): Godot's path search stops after 4096 polygons
   (`path_search_max_polygons`), and the raw detail triangles were 16-23 000;
4. **a sagging edge gets a vertex**: where an edge's middle is more than 3 cm
   off the ground (a 5 m edge across a curved road profile sagged 0.11 m), a
   vertex at the ground's height goes into it, in every polygon that has it;
5. **every vertex on a centimetre grid** (plan and height), so the map's vertex
   merge (cell x `MERGE_SCALE` 0.02: 5 mm in plan, 0.4 mm in height) never
   joins two nor parts one.

**Links.** A flight 1 m wide with 0.30 m goings, turned off the 0.25 m grid,
loses treads to the raster and comes out in islands and smears. So a house's
entry flight and a lot's access flight are not baked (an access flight's
strip is no floor; an entry flight's treads are obstacles, its landing floor)
and each is a LINK along its pitch: from the lower ground where the pitch line
through the treads' middles reaches it, to the upper level half a going past
the top nosing. The link's straight line is then never more than half a riser
off a tread. Stair streets (treads 0.45 m and longer, 2 m and more wide) are
baked and walked.

**The export** (only with ground; every flat key unchanged):

| Key | What |
|---|---|
| `walk.navmesh_3d` | `vertices_m` [[x, y, z]], `polygons` (Godot's winding), `cell_size_m`, `cell_height_m`, `merge_rasterizer_cell_scale`, `path_search_max_polygons`, `agent` {radius, height, climb, slope}, `links` [{`kind` entry / access, `building_id`, `door`, `from_m`, `to_m`, `bidirectional`}] |
| `walk.gates[].nav_3d_m` | the gate on the 3D mesh |
| `walk.doors[].outside_3d_m`, `reachable_3d`, `route_m` | where a walker arrives (a house with an entry flight: its landing at the threshold), whether it is on a gate's island (links counted), and the flight's route |
| `walk.stairs` | each stair street (treads, riser, least going, rise), each lot's way in (level, a flight, or refused), each entry flight's route |

**For a consumer.** A `NavigationMesh` with `vertices` = `vertices_m` and one
`add_polygon` per row; the map at `cell_size_m` / `cell_height_m` with
`map_set_merge_rasterizer_cell_scale(merge_rasterizer_cell_scale)`; one
bidirectional NavigationLink3D per `links` row; and a path query allowing
`path_search_max_polygons` (Godot's default 4096 is enough for these two,
2603 and 3817 polygons; a larger village needs the value). For synchronous
use (a headless test), `map_set_use_async_iterations(false)` and
`region_set_use_async_iterations(false)` then `map_force_update(map)`.

### The check and the suite

`VillageGroundCheck` rule `stairs`: every tread of a stair street its regions
hold and every tread of an access flight is in the MESH at its level (5 cm),
no riser over 0.18 m, no inner stair-street tread under 0.28 m, and each has
its `stair_tread` component.

`vstepswalk` (91 checks since HILLS-GENERAL, ~14 min loaded, 8 min of it the hillside's plan; 84 checks and ~5.5 min before): 50 people, seed 4242, the green form
(the one with stair streets on both), on Manarola and Positano (real30). The
ground and its components (`ComponentCheck`) and the whole `VillageGroundCheck`;
the walk read back out of JSON; one island; NavigationServer3D paths from the
first gate to every door (default query, links loaded); heights; the same
bytes twice; and a CONTROL -- the same bake without the access flights and
the level gaps strands doors.

The vertical error is measured against the emitted Ground mesh read back
(GroundProbe) and the entry flights' treads: at every mesh vertex, at every
path point, and every 0.25 m along every path on the mesh under it (on a link,
the link's own straight line against the treads). A step is a discontinuity a
mesh cannot follow and a voxel bake resolves an edge to its cell, so a point
within a cell's diagonal (0.354 m) of a riser and between its foot and top is
on the step; the "strict" figure leaves that out except at climbable steps.

| Ground | Stair streets (treads) | Access flights | Entry flights | Navmesh | Doors on the gates' island | Server paths | Vertices | Path points | Mesh along paths (strict) | Control |
|---|---|---|---|---|---|---|---|---|---|---|
| Manarola, green | 1 (67), riser 0.150, going >= 0.45 | 6, none refused | 18 | 5129 v / 2603 p, 252 KB | 16/16 | 16/16, up to 4.2 m of climb | 0.046 m | 0.043 m | 0.092 m (0.092) over 7825 samples | 5 doors stranded |
| Positano, green | 2 (241), riser 0.150, going >= 0.50 | 12, none refused | 18 | 7233 v / 3817 p, 305 KB | 14/14 | 14/14, up to 10.4 m | 0.048 m | 0.048 m | 0.088 m (0.088) over 6683 samples | 8 doors stranded |

Lanes on terrain-villages 77d97ab with this change (20 Oct, loaded host):
`vstepswalk` 84/0, `vterrain` 161/0, `vground` 13/0, `vgroundterrain` 27/0,
`vcrossterrain` 24/0, `hslope` 253/0, `lane:village-fast` 47/0, `vcrest`
209/0 (7 warnings, all the crest form's own "open" rows on Eze and Civita),
`vtplan` 1436/0 (1 warning, thorn-hamlet's band on Manarola). Logs in
`artifacts/vter_steps_nav/`.

The bake costs 4-8 s a village (11-15 s for the whole walk export, twice the
flat one's). The straight chords between path points run up to 0.20 m off on
convex ground: a consumer's agent follows the mesh, not the chord.

### For VTER-FORM-HILLSIDE

Contour streets joined by stepped lanes reuse all of it as it stands: lay a
lane as class `steps` and its bed is a stair with stone and a walk
(`treads_of` is pure, so a planner can ask how many treads a lane would take
before laying it); every lot it fronts gets its way in from
`VillageAccessSteps.plan` (or a level gap); `vstepswalk`'s case list takes a
new fixture in one row. Two things a hillside form should know: a lot whose
walls stand within a metre of a front well below or above its road needs the
verge or a narrow flight (both tried) -- a deeper front setback on falling
ground would make every flight straight; and a long uniform flight has no
landing (below).

### Not yet

* **landings in a long stair street** -- a gentle stretch is a landing, but a
  long steady climb is one flight (Positano's: 120+ treads); a landing every
  12-16 risers would move the treads off the profile by the landing's rise;
* **the flat walk's check** -- `VillageNavCheck` still judges the plan's flat
  floor; the 3D walk is measured by `vstepswalk`, not by `VillageQA`;
* **the church's and the castle's flights** -- only houses' and shops' entry
  flights are in `entry_flights` (theirs are measured off a mesh); their doors
  are reached at the ground in front;
* **a flight's foot below a higher verge** -- a house's entry flight that ends
  on its road's verge can end a few centimetres under the verge's bed (the
  flight is planned on the lot's ground model, the verge is the road's);
* **cost** -- the walk export bakes and builds the village (11-15 s); the
  exporter does both once per SitePlan;
* **the castle walk export** -- unchanged (`CastleWalkSources`, above).


## The water form (VTER-FORM-WATER)

Rows 2 and 9 of the form rule, given their planner:
`src/village/forms/water_form.gd`, `VillageWaterForm`, reached from
`VillageSitePlanner._plan` by one dispatch beside the shore form's (and from
`plan()` for the siting, which is the shore form's own); `water` is in
`FORMS_SUPPORTED` and out of `FORM_FALLBACK`. Ganvié on Lake Nokoué (the world
set's `over_water_share` 0.542), Kampong Ayer on the Brunei river (1.0): houses
on piles, joined by boardwalks, reached from a street on the bank. Without
terrain the form is never derived, so nothing flat changes (`thorn-hamlet` and
`veld-070` exported before and after, `cmp` identical; the seven flat villages
of `tools/fingerprint_village_ground.gd` and the house fingerprint identical).

| Step | What |
|---|---|
| siting, shoreline, shore street, common, landmark | the shore form's, unchanged (`VillageShoreForm.plan`) |
| piers | `_piers`: boardwalks square off the shore street on the shoreline's own columns, `PIER_SPACING` 40 m apart, nearest the common first, clear of the common (6 m) and of the street's other junctions (14 m) and 22 m inside the site's ends; one per 6 households, at least two (`piers_for`). Each runs out beyond the shoreline as far as a row of pile lots each side needs (`reach_for`: 12 m + 12.5 m a house, 30-90 m), and is laid only where the water under it and 12 m either side stays within `DEEP_MAX` (3.5 m) and where the ground SEES the bed: somewhere under it at least `BED_SEEN_M` 0.5 m below the level. A DEM that reads the sea flat at its surface says nothing of its depth -- Manarola's 30 m grid is 0 m from the shore out, and the first vtplan run drove piles into it for Thorn (which derives `water` there); now Thorn on Manarola is the shore form |
| the far walk | a boardwalk along the piers' far ends (the shoreline plus the reach, held to the bend rule), so every boardwalk is a way through and none a dead end |
| a boardwalk | a `path` road (1.2 m, verge 0.7) with `"boardwalk": true` and `"deck_m"` (the water level + `HousePiles.FREEBOARD_DEFAULT`): a footway in every check. Over the water it is a CROSSING of kind `boardwalk` (`VillageWaterPlan.crossing_kind`), its width the verged ribbon less the builder's bridge margin (`crossing_width`), so the deck the walk paints is the 2.6 m ribbon the lots front |
| the site | grown seaward to the far walk + 6 m, and the ground's water re-read over it (`VillageGroundWater.add`) BEFORE the boardwalks are laid, so the shore trim never cuts them |
| pile lots | `place_on_piles` (one hook in `VillageLotPlanner.cut_measured`): every household is offered the boardwalks first, as a house on piles measured once (`pile_job`: the request asked for piles, cached on the job's shared cache). `pile_lot_is_legal` (one hook at the top of `_lot_is_legal`): the lot fronts a boardwalk, lies WHOLLY on the ground's water (`wholly_wet`), inside the site, clear of every ribbon, common, lot and the landmark's ground, corners, walls inside, eaves off the carriageways, fire gaps; and the bed under it (read as the ground mesh will carve it: never above the level less 0.41 m) no deeper than the piles reach. The lot records `"piles"`: `deck_m`, `water_m` (snapped up to 0.25 m), `freeboard_m`, `bed_m`, `reach_m` and `landing` (the house's landing in plan: its width and gallery, from its wall to the lot's front, which is the boardwalk's deck edge). `_commit` asks the request for exactly that (`request_for`). What finds no pile lot stands on the bank, fronting the shore street |
| the build | `VillageBuilder._water_on_terrain` hands every boardwalk crossing to `VillageBoardwalk.emit` instead of `_crossing`: `boardwalk_deck` (each ribbon less those before it, in convex pieces, so no two deck faces share a plane at a junction), `boardwalk_bearer`, `boardwalk_pile` (both edges every 2.2 m, into the bed) and `boardwalk_ramp` where a crossing lands on the bank (at most 12 %) |
| standing | `VillageGroundSurface.platform_of` answers a pile lot's deck level, so the assembler sets the house there; its facade pieces stay on its gallery (`_ground_yard` skipped, the node marked `piles`); the dresser does not dress it (`VillageDressHosts.host_of` answers nothing) |
| the walk | `VillageNavCheck.build_grid` and `sources` paint each landing as floor after the water (and cut it out of the water and the building outlines), as they do a crossing; VillageWalk exports the same ground, `kind: landing` |

**What the checks learned.** `VillageLotCheck.tiling` and PlaceCheck's
`edge_ground` let a pile lot stand in the water. PlaceCheck ranks a building
on the bank among the buildings on the bank (`neighbours`): the houses in the
water stand on piles, not on the lake bed the rank would read, and the mill on
the bank came out "high" (rank 0.75) against twelve houses over the bed.
`VillageRoadCheck` expects the boardwalk kind for a boardwalk's crossing.
`VillageGroundCheck` judges a house on piles by its deck
(`VillageWaterCheck.ground`): it stands at its deck level, no ground stands
over the water under its footprint or its landing, and its piles' feet are
under the ground there; no ground stands over the water under a boardwalk; a
facade piece on a pile house is judged at its planned height on the gallery.
`qa/village_water_check.gd`, `VillageWaterCheck.check`: every pile lot wholly
wet, within the piles' range, on a boardwalk, its building asked for its
piles and valid; every boardwalk over the water carried by a boardwalk
crossing; nothing the dresser set down stands in the water (a boat excepted:
the first run had seven barrels on the lake bed, from the house recipe's
`wall` rule on pile lots); `over_water_share` (VillageShape, the survey's
definition: a building is over water when half its footprint is).

**The lagoon.** `tests/fixtures/terrain/synthetic_terrain.gd` `lagoon`: a
gentle shore (3 %) on a sine-bent shoreline, a lagoon shelving 6 % to a 2.6 m
bed; the 400 m form window is 42 % wet and the 450 m disc 46 %, so the ground
derives `water` at row 2 (not `shore` at row 1). The world90 grids of Ganvié
and Kampong Ayer cannot stand in for it: Ganvié's DEM reads its lagoon as land
1-4 m high (its water level, the lowest cell + 0.5 m, is -9.5 m), and Kampong
Ayer's river is one 90 m row of cells.

Suite `vwaterform` (32 checks, 295 s host, ~12 m loaded; 67 s of it measuring the 16
buildings once; `WATER_CASE=lagoon|lake_shore` runs one case, `WATER_DUMP=1`
prints the plan). A fishing village of 50 on a lake:

| Ground | Form | Boardwalks | On piles / on the bank | `over_water_share` | Deck parts / posts / ramps | Under the piles | QA |
|---|---|---|---|---|---|---|---|
| `lagoon` | water (derived) | 2 piers + the far walk, 3 crossings | 12 / 4 (church, smithy, tavern, mill) | **0.750** | 16 / 152 / 2 | ground at most 0.09 m under the water's surface; feet at least 0.69 m under the bed | VillageQA, VillageWaterCheck, VillageGroundCheck, ComponentCheck ok |
| `lake_shore` (forced) | water, as the shore form | none: 3.5 m of water lies 44 m out | 0 / 16, all dry | 0.0 | - | - | VillageQA ok |

Also checked: every door walked to from a gate (VillageNavCheck `arrive`)
and every door `reachable` in VillageWalk's export, with one landing per pile
house; with the boardwalk crossings taken away all 12 pile houses are
unreached (the control); a pile house asked for no depth fails
VillageWaterCheck (the control); the export writes form `water`, each
boardwalk (`roads[].boardwalk.deck_m`), each pile lot (`lots[].piles`) and
each pile request; the plan is pure; a water spec with no ground plans as the
straight strand. The acceptance -- on a lagoon, houses on piles, a boardwalk
walk graph connecting them, `over_water_share` over 0.5 -- reads 12 houses on
piles, every door reached over the boardwalks, 0.750.

**Not yet.**

* **a pier that bends** -- piers are straight and square to the street; a
  shore that shelves unevenly loses a pier rather than bending it into the
  shallows. The far walk is the only boardwalk that follows the shore.
* **the trades on piles** -- only households are offered the boardwalks; the
  smithy, the tavern, the mill and the church stand on the bank (Ganvié's
  market and church do stand in the water).
* **canoes** -- the strand step's boats stand on the bank; the pile houses'
  ladders reach the water but no canoe is moored there.
* **`piers`** -- VillageShape still reports 0 (`survey.py` counts mapped
  `man_made=pier` ways; the definition lives in both files and was not
  changed here).
* **real ground** -- no real grid in the set shows a lagoon at 90 m; on a
  steep real shore (Manarola, Hallstatt) the form is the shore form.
* **the house's own walk export** -- `BrickWild.navigation()` publishes no
  `route_m` over a pile house's landing (its door is one FLOOR_T step down
  to the deck); the village walk carries it.
* **a bed under a house deeper than the grid shows** -- the piles' depth is
  read from the terrain at 2 m under the lot; a pit between the grid's nodes
  under a post would leave it short (the ground check reads the emitted mesh
  and would say so).
## The island fill (VTER-ISLAND-FILL)

Isola dei Pescatori: 33 buildings on a lake islet, the lanes one house wide,
the whole island the village. `VillageIslandForm`
(`src/village/forms/island_form.gd`) is the island case of `water`;
`VillageIslandCheck` (`qa/village_island_check.gd`) judges it.

* **When.** Row 0 of the form rule: an ENCLOSED island (a dry component of
  the caller's grid on an 8 m lattice that touches no edge of the grid, within
  320 m of the centre, and its bounding box a margin inside the grid) whose
  area is 0.7 to 4 times what the households need (`needed_m2`: 300 m2 a
  building and 600 m2 of common and churchyard) and whose widest inscribed
  circle holds a ring (`QUAY_INSET` + `BEND_R`). The form stays `water`; the
  island ground is a different plan of it, as the lagoon is. Anything else
  (a hamlet on a big islet: row 1's `shore`; the 19 ha cone; the real Isola
  on the 90 m DEM) is exactly what it was.
* **The frame.** Origin at the island's pole (its centroid where that is
  nearly as far from the water), +x along its long axis (`site`).
* **The ring.** A closed street of eight arcs, the shore pulled in by 4.5 m,
  its long axis shortened until its frontage is `CAPACITY` (1.6) times what the
  buildings need, then OPENED by a circle of 47.5 to 50.5 m
  (`Geometry2D.offset_polygon` by -R then +R): the road check's 25 degrees in
  20 m is a 46 m radius, so the pointed end of an island is cut off by a curve
  a street can take, and an island narrower than the opening is not an island
  village (`inscribed_m`). The first ring that leaves every vertex inside the
  rule keeps.
* **The spine.** The through road, along x from a landing at one end of the
  island to the landing at the other, crossing the ring at two of its
  vertices. The walk enters at the landings (`VillageMeasure.gates`). The
  site ends exactly at the landings.
* **The common** beside the spine at the middle, a path to it, the landmark's
  slot across the spine. Houses stand on both sides of the ring and the spine;
  where the ring is drawn in from the shore they stand on its outer side too.
* **Water.** `VillageGroundWater.polygons` reads the sea as polygons and DROPS
  THE HOLE of a ring of water (its doc says so: "an island inside a lake is
  read as lake"). An island wholly inside its site would be read as lake, every
  road on it "wet from end to end" and taken up. The site therefore ends at the
  landings, the island's two ends touch its short sides, and the sea falls in
  two pieces, north and south.
* **The check** (`VillageIslandCheck`): the ring's arcs join end to end, the
  spine runs from shore to shore as far apart as the island is long, nothing
  is on the water, and 85 % of the island's dry ground is within 30 m of a
  building (`reach_share`, read on the caller's own grid so it reads a plan
  sited any other way). `VillageRoadCheck` takes two landings, side 4 twice,
  far apart, as two sides for an island plan (`plan.island`), and nowhere else.

On the islet (`SYNTH.make("islet")`: 350 x 120 m, 2.6 ha dry above the freeboard, the real Isola's
size; 89 people, fishing, as the survey records it; suite `vislandfill`):

| | form off (the water form as it was) | island form |
|---|---|---|
| form | shore (row 1: the window is mostly wet) | water, island |
| buildings placed, first attempt | 4 of 29 | 29 of 29 |
| buildings placed, the whole retry ladder | 14 of 29 (607 s) | 29 of 29 |
| VillageQA | 6 houses for 21 households; density 4.8 %; through road leaves twice by the same side; 2 doors unreached | ok |
| island within 30 m of a building | 0.28 (first attempt) | 0.97 |
| ring inside the shore (mean) | - | 14.0 m |
| `body_hull_ha` | 0.50 (real Pescatori 0.81) | 0.73 |
| `nn_median_m` | 19.2 (real 12.3) | 13.0 |
| `coverage` / `compactness` / `elongation` | 0.33 / 0.45 / 4.0 (real 0.81 / 0.64 / 2.1) | 0.38 / 0.28 / 5.8 |
| `setback_median_m` | 5.5 (real 0.9) | 5.7 |
| `water_within_30m` | 0.64 (real 0.58) | 0.35 |

The suite (`vislandfill`, 32 checks, 984 s on a loaded host: 147 s measuring
the 29 buildings, 307 s planning, 229 s building and assembling the mesh): the
derivation and its four refusals; the plan sited along the island; the check;
VillageQA; every door walked to from a landing, and the spine cut to a stub
strands 25; the exporter's `island` block; components, the assembled mesh and
`VillageGroundCheck`; the controls (east half of the buildings taken away: the
island reached 0.51 and `fill` fails; a ring arc taken up: `ring` fails; the
form off: no island plan, 0.28 reached); purity.

### Not yet
* **The 90 m DEM does not hold the real Isola.** `world90/isola_dei_pescatori`
  smears the 3.5 ha island into 19 ha (one 1 m step of lake and one of land are
  the whole signal), so it is 21 times what 89 people need (limit 4) and keeps the
  water form's shore plan. The form works on any grid that shows the island as
  it is (the islet is on 8 m cells).
  A 30 m grid does not either (VTER-ISLAND-DEM, 2026-10-26):
  `real30/isola_dei_pescatori` (`survey.py terrain --source srtm30m --half 450`,
  water level 191.5 as world90's) reads 9.15 ha (SRTM is a surface model: roofs
  and trees), 9.8 times what 21 households need. Raising the level or eroding a
  cell still leaves 4.5-5.8 ha.
  **VTER-ISLAND-DEM, 2026-10-28: the island's own outline.**
  `tests/fixtures/terrain/osm10/isola_dei_pescatori.json` is an 8 m grid
  (`tools/settlements/osm_island_terrain.py`) whose land mask is OpenStreetMap
  way 8013628 (the outline is kept beside it, ODbL); the heights are a dome of
  0.6-2.6 m over the 191.5 m lake and a bed falling away, a profile and not a
  measurement. It reads 2.5 ha, 0.7-4 times the need as it should. And the island
  form STILL refuses it, now for one reason: the island is 88 m across at its
  widest (`inscribed_m` 44) and a ring needs `QUAY_INSET + BEND_R` = 52 m, the
  opening of the road check's bend rule (25 degrees in 20 m). The real lanes
  bend sharper than that. Whether a narrow island may have a tighter ring
  (a smaller `BEND_R` here and the road check's bend allowed on an island plan) is
  a rule decision and is left open; `vislandfill` holds the fixture to this
  reason (area in range, refused for width) so either change is seen.
* **Density (VTER-ISLAND-DENSE, 2026-10-28).** Two things had kept the village a
  row. (1) `_lot_is_legal` allowed a house on a `water`-form plan only on the
  THROUGH road (the strand's one row, the lagoon's boardwalk): on the island all
  29 buildings stood on the spine and its arms to the landings and the 719 m of
  ring frontage had none. An island plan (`plan.island`) now takes lots on every
  road. (2) By the common's distance the spine's arms are still the nearest
  frontage after the middle, so `_place_on_road` takes them LAST on an island
  plan (the spine outside the ring's x-extent), and `lot_rule` gives an island's
  houses and shops the quay rule `ISLAND_RULE` (setback 0.2-2.5 m, use 0.6, fire
  0.6, yard 0.8; the real island is built to its lanes). On the islet: elongation
  5.9 to 1.8 (real 2.1), compactness 0.28 to 0.80 (0.64), hull 0.73 to 0.80 ha
  (0.81), 29 of 29 placed, island reached 0.93, road check, island check and
  VillageQA clean; suite `vislandfill` gates elongation <= 3, compactness >= 0.5
  and the hull. Not moved: `setback_median_m` 5.9 (real 0.9; it is read from the
  road CENTRE LINE, and the spine is a 6 m through road with verges), `coverage`
  0.28 (0.81) and `water_within_30m` 0.28 (0.58): the buildings are the same
  size, the island 0.8 ha, so the rest of the ring is unbuilt ground.
* **Strand dressing (VILLAGE-DRESS-STRAND-COST, 2026-10-28).** A fishing
  village's `strand` step took 190 of the islet plan's 307 s. Not the distance
  transform (1.5 s of 90 s in six `reached_grid` calls) but `WalkGrid._fill_poly`:
  a `Poly.contains_point` per cell of every polygon's bounding box (road ribbons,
  lots, the water outline). It is a scanline now (the same parity at the same
  centres, the boundary by the same `Poly._on_segment` at the cells an edge's
  half-cell samples fall in), the old loop kept as `_fill_poly_exact`. The plan
  takes 50 s, `vislandfill` 206 s (984 s). Suite `wgridfill` (in `lane:village-fast`):
  252 polygons painted both ways to identical cells and levels, and the scanline at
  least 5x faster (measured 270-380x). `fingerprint_village_ground`: the five cases
  the base finished are identical, strand-coast-hedge included.
