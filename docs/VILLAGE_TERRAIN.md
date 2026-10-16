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
| real ground | `tests/fixtures/terrain/` (Manarola, Limone sul Garda, Varennes), written by `tools/settlements/survey.py terrain` |

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
* **per-lot platforms and stepped plinths** -- a house on 2.7 m of fall stands
  on a plinth or over a basement, not on a pad;
* **landform forms** (`hillside`, `crest`, `shore`, `valley`, ...) -- the form
  still comes from population, purpose and culture; on a crest the village
  goes to level ground within reach rather than onto the summit, because no
  cart-graded through road passes a common on a 40 m summit ringed by 20 %
  flanks;
* **the ground's own water as plan water** -- the siting keeps the village
  off it and lots refuse it, but a river in the grid is not yet a `plan.water`
  polygon with bridges.
