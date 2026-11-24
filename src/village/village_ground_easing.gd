class_name VillageGroundEasing
extends RefCounted
## Easing a caller's ground so a whole programme stands on it
## (CITY-GROUND-CONTRACT, docs/VILLAGE_TERRAIN.md "The caller shapes the
## ground"). Only ever called for a caller that said it will cut and fill
## (`--ground-policy shape`); nothing here runs for any other plan.
##
## THE MODEL. A consumer that builds its own terrain (VoxelGames: voxels) is
## not bound by the ground as it lies. When the lot search leaves a building
## out, the answer is not a smaller city but gentler ground: the DRY relief of
## the grid is scaled by `keep` about its own mean height,
##
##     eased = datum + keep * (given - datum)
##
## so every slope and every bump is `keep` of what it was and the land keeps
## its shape -- the hill is still the hill, and the form the planner derives
## from the ground is derived from that. `keep` 1 is the ground as given, 0 is
## level. Cut and fill balance about the datum, which is the least earth moved
## for the gentleness bought.
##
## Two things are never moved. WATER: a node at or below the water level
## stays, and the easing fades in over the first SHORE_BAND_M above it, so the
## shoreline is where the caller put it and no bank is raised out of the sea.
## THE EDGE: the easing fades out over a band inside the grid's border, so the
## eased ground meets the caller's own ground there and nothing outside the
## grid changes.
##
## `lift` is what the caller applies: eased minus given, metres per node,
## negative where it cuts. Adding it to the caller's own surface (which has
## more detail than a 5 m grid) eases the land without smoothing it.

## What the exporter tries, in order, until every building stands.
const LADDER: Array[float] = [1.0, 0.5, 0.25, 0.1, 0.0]
## The easing fades out over this much inside the grid's border...
const BAND_M := 80.0
## ...or this share of the grid's shorter side, on a small grid.
const BAND_SHARE := 0.2
## Ground this far above the water is eased in full; at the water, not at all.
const SHORE_BAND_M := 3.0
## A node moved less than this is not counted as changed.
const CHANGED_M := 0.05


## How much of the easing a node takes: 0 at the grid's border and at or below
## the water, 1 in the dry middle.
static func weight(given: VillageTerrain, col: int, row: int, band: float) -> float:
	var b := given.bounds()
	var p := given.origin + Vector2(col, row) * given.cell_m
	var inside: float = minf(minf(p.x - b.position.x, b.end.x - p.x), minf(p.y - b.position.y, b.end.y - p.y))
	var w: float = smoothstep(0.0, band, inside)
	if not is_nan(given.water_level_m):
		w *= smoothstep(0.0, SHORE_BAND_M, given.heights[row * given.cols + col] - given.water_level_m)
	return w


## `given` eased to `keep` of its dry relief:
##   {"terrain": VillageTerrain, "keep", "datum_m", "band_m", "cut_max_m",
##    "fill_max_m", "cut_m3", "fill_m3", "changed_m2", "changed_share"}
## `keep` >= 1 returns `given` itself and zeros. The cut and fill are what the
## caller moves to make the eased ground, before any lot is graded on it.
static func eased(given: VillageTerrain, keep: float) -> Dictionary:
	keep = clampf(keep, 0.0, 1.0)
	var out := {"terrain": given, "keep": keep, "datum_m": 0.0, "band_m": 0.0, "cut_max_m": 0.0,
		"fill_max_m": 0.0, "cut_m3": 0.0, "fill_m3": 0.0, "changed_m2": 0.0, "changed_share": 0.0}
	if given == null or not given.valid() or keep >= 1.0:
		return out
	var b := given.bounds()
	var band: float = minf(BAND_M, BAND_SHARE * minf(b.size.x, b.size.y))
	var n: int = given.cols * given.rows
	var weights := PackedFloat32Array()
	weights.resize(n)
	var sum_w := 0.0
	var sum_h := 0.0
	for r in range(given.rows):
		for c in range(given.cols):
			var w: float = weight(given, c, r, band)
			weights[r * given.cols + c] = w
			sum_w += w
			sum_h += w * given.heights[r * given.cols + c]
	if sum_w <= 0.0:
		return out   # all water, or no room inside the band: nothing to ease
	var datum: float = sum_h / sum_w
	var heights := PackedFloat32Array()
	heights.resize(n)
	var node_m2: float = given.cell_m * given.cell_m
	var changed := 0
	for i in range(n):
		var h: float = given.heights[i]
		var g: float = h + weights[i] * ((datum + keep * (h - datum)) - h)
		heights[i] = g
		var d: float = g - h
		if d < 0.0:
			out["cut_max_m"] = maxf(float(out["cut_max_m"]), -d)
			out["cut_m3"] = float(out["cut_m3"]) - d * node_m2
		else:
			out["fill_max_m"] = maxf(float(out["fill_max_m"]), d)
			out["fill_m3"] = float(out["fill_m3"]) + d * node_m2
		if absf(d) > CHANGED_M:
			changed += 1
	out["terrain"] = given.with_heights(heights, "%s eased to %s" % [given.source, String.num(keep, 2)])
	out["datum_m"] = datum
	out["band_m"] = band
	out["changed_m2"] = float(changed) * node_m2
	out["changed_share"] = float(changed) / float(n)
	return out


## What the caller adds to its own ground to make `eased_ground` of `given`:
## a grid on the same lattice, metres per node, negative where it cuts.
static func lift(given: VillageTerrain, eased_ground: VillageTerrain) -> VillageTerrain:
	var d := PackedFloat32Array()
	d.resize(given.heights.size())
	for i in range(d.size()):
		d[i] = eased_ground.heights[i] - given.heights[i]
	var out := given.with_heights(d, "lift")
	out.water_level_m = NAN   # a difference has no water level
	return out
