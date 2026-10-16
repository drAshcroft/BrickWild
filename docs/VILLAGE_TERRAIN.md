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
