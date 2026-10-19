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
seven old forms, `dispersed` (VTER-FORM-DISPERSED, below) and `shore`
(VTER-FORM-SHORE, last section). `form_intent`
keeps the derived form; `form` is what is planned, through
`VillageSpec.FORM_FALLBACK`:

| intent | planned as | why |
|---|---|---|
| hillside | street | the one-street row a contour street will replace |
| valley | street | a ribbon along the through road, as a valley village is |
| crest | round | houses ringed round the top's common |
| ~~shore~~ | ~~strand~~ | planned as itself since VTER-FORM-SHORE |
| water | strand | the row along the water the stilts will stand in |
| ~~dispersed~~ | ~~green~~ | planned as itself since VTER-FORM-DISPERSED |

Each VTER-FORM-* task that gives a form its planner deletes that form's one
line in `FORM_FALLBACK`. The exporter writes `form_intent` beside `form`
(only with ground, so a flat SitePlan's bytes never change) and adds a note:
`the ground derives the 'hillside' form, which has no planner yet; planned as
'street' (form_intent keeps 'hillside')`.

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

* **switchbacks and a hillside form** -- the through road is monotone along
  its axis and the bend rule (25 degrees per 20 m) forbids a hairpin. On the
  two steepest real grids (Masouleh, Castelmezzano: 40-60 % hillsides) fifty
  people need a 270-315 m site and no such road crosses it at 12 % (0.27-0.50
  if allowed), so the lot planner keeps the narrower site whose road kept the
  cap and leaves households unhoused (VillageQA `housed`);
* **the real hillsides' contour share** -- on Hallstatt, Masouleh, Monemvasia
  and Ushguli the field tracks, laid straight up to 30 %, outweigh the
  contour road, and the share is 0.06-0.41 against the survey's 0.57;
  Positano and Castelmezzano have too little steep street length to measure.
  Tracks that traverse the slope would raise it -- and would lift the planes
  over 0.8 -- so this wants the hillside form, not a weight;
* ~~graded service lanes~~ -- done in VTER-LOTS: a steep one is not laid;
* **a tavern near a gate on a stretched site** -- Èze and Hallstatt stretch
  to 270-315 m to house everyone, and the tavern's 60 m from a gate goes;
* ~~per-lot platforms and stepped plinths~~ -- done in VTER-LOTS;
* **landform forms** (`hillside`, `crest`, `shore`, `valley`, ...) -- the form
  still comes from population, purpose and culture; on a crest the village
  goes to level ground within reach rather than onto the summit, because no
  cart-graded through road passes a common on a 40 m summit ringed by 20 %
  flanks;
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
`fill` under it. VTER-GROUND-MESH emits them; nothing here builds geometry.

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

* **the walk on the steps (VTER-STEPS-NAV)** -- `VillageNavCheck` and
  `VillageWalk` reach every door on the lot's flat floor; they do not see a
  flight's treads or heights (the parts are lot floor to them, never an
  obstacle, so no door is cut off). The flights are in each lot's
  `entry_parts` and in `BrickWild.navigation()`'s `route_m` per building.
* **the graded ground itself (VTER-GROUND-MESH)** -- the platform, the plane
  and the walls are recorded; nothing emits them, and VillageBuilder still
  stands the 3D village at y = 0.
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

Suite `vdispersed` (161 checks, ~5 min, most of it measuring the 19
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

Not yet: the spines run straight up the fall-line, where real hamlet links
(Ushguli's valley road, Batad's terrace paths) wind along the contour; the
site is 260-360 m where real hamlets lie two to four hundred metres apart; a
hamlet earns no shrine of its own (the programme earns one landmark); the
tavern and the smithy keep their §6 addresses at the gates and often stand
alone on the road; an enclosed dispersed village gets one enclosure round
everything.

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

**Not yet.** Yard dressing (barrels, benches, gardens, fences) still stands at
y = 0 and floats on the downhill side; the village walk (`VillageWalk`) does
not read routes; a front-downhill house in band 3 keeps its front door on the
downhill side and climbs to it by a long flight along the facade -- the
village should turn such lots so the front faces uphill or across the slope.

Suite: `hslope` (house, shop, church at 0 / 1.0 / 2.5 / 4.0 m, sideways and
front-to-back). Pictures: `godot --path . --script res://tools/render_slopes.gd`.
