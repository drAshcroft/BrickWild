# Village terrain: reading the ground

A village used to be planned on a table. `VillageBuilder.ground_height` is 0
everywhere except the banks of the village's own water, and the C1 SiteRequest
carries one `terrain.slope` number for a 4.9 km mythsim cell. A consumer with
real ground (VoxelGames) planned the village flat, then cut one pad at the
median height under the whole site and blended a 48 m skirt back into the land
(`CityGrounds.lay`). The world survey ([SETTLEMENT_TESTSET.md](SETTLEMENT_TESTSET.md))
says how far that is from how villages are built: most real ones stand on
ground that falls metres under a single house.

This is the first half of fixing it: **BrickWild can now read the caller's
ground and say how it lies under everything it planned.** The planners do
not use it yet. That is the second half, below.

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
before**, and `vterrain` checks that the ground adds readings and changes
nothing else.

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

## Not yet: planning on the ground

The planners still lay the village out flat; `vterrain` asserts that the
ground does not change the plan, so that this step is a deliberate one. What
the survey says the planners must learn, in order of how often real villages
need it (see the gap counts from `vworld`):

* **slope-aware frontage** — streets that follow the contours on steep ground
  (most hill villages in the set do), lots cut along the contour, and the
  through road choosing a grade a cart can climb;
* **per-lot platforms and stepped plinths** — a house on 2.7 m of fall stands
  on a plinth or over a basement, not on a pad;
* **stairs as streets** — where the grade is past a cart (Hallstatt has 27
  stepped ways in one disc);
* **siting by the ground** — the landmark on the crest or the spur, the
  common on the level ground, the mill in the valley floor, the edge where
  the ground turns too steep or too wet.

When that work starts, relax the "ground changes nothing" check in `vterrain`
deliberately and replace it with the new rules.

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
