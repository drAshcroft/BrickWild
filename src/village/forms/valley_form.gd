class_name VillageValleyForm
extends RefCounted
## `valley`: a long body squeezed between a river and steep sides -- Oksfjord,
## Sunndalsora, Hallstatt, Kandovan. The through road runs along the valley
## floor on the dry bank of the river, a ribbon of lots both sides of it where
## the floor is buildable, and short climbing ways go up the sides
## (VTER-FORM-VALLEY, docs/VILLAGE_TERRAIN.md "The valley form").
##
## The ground derives this form at row 5 of the form rule (water `river` or
## `lake`, p75 dry slope 25 % or more, the centre in the lower 55 % of its
## ground). The layout, in the planners' own frame (the through road along
## +X, the common on its +Y side -- the planners call that side north):
##
##   1. the site: long and shallow -- twice the street form's side along the
##      road, a street form's side deep -- grown along the road by the lot
##      planner's retries (`site_scale`), never across it
##   2. the valley read off the sited ground: per column along the road, where
##      the river runs (the wet channel when the grid has a water level, else
##      the lowest ground across the site) and how far from it the road should
##      stand, so the floor on both sides of the road is as buildable as it
##      gets. The road keeps to the river's -Y side's opposite: the hill is
##      north (+Y), the river south (-Y), so the street form's common and
##      landmark, which stand north of the road, stand on the side of the hill
##   3. the through road is seeded on that line (a little of the seeded bow
##      kept so it is never straight), routed by grade as every form's is, and
##      held clear of the river's bank
##   4. the river as plan water, kind `river`, along its own line; with a grid
##      water level the ground's own wet polygons (VillageGroundWater), kind
##      `river`. No road runs in it and none crosses it: bridges are the
##      crossings task's, and the body stays on one bank
##   5. the street form's core (common, approach path, ring street, landmark
##      behind the ring) at the gentlest place in the middle of the road --
##      the dispersed form's main hamlet, reused
##   6. climbing ways off the hill side of the road, square to it, spaced
##      LANE_PITCH_M apart: a `lane` (a cart's 12 %, ending at its last lot)
##      where the ground allows it, else a `track` (30 %) straight to the
##      site's edge -- a way up to the fields above, ending ON the boundary
##      as the road check requires of anything but a short lane. Dead ends in
##      the survey's sense, which counts every end of a street graph
##      (junction angle, 12 % lane cap and the dead-end rule together forbid
##      a lane that climbs a 30 % side at less than a right angle)
##
## `plan.hamlets` stays empty: this is one body, a ribbon.
##
## Pure: every draw comes from the same seeded stream as the other forms, and
## the spec is never written to. Without ground the form is still laid (the
## siting scores the flat plan): the river a fixed offset south of the road.

const ANALYSIS_CELL_M := 10.0
const SITE_LENGTH_X := 3.0        ## the site's length along the road, in street-form sides
const SITE_LENGTH_MIN := 260.0
const SITE_LENGTH_MAX := 400.0
const SITE_DEPTH_X := 1.4         ## its depth, in street-form sides: the hill side holds the common, the ring and the landmark
const SITE_DEPTH_MIN := 120.0
const SITE_DEPTH_MAX := 150.0
const SAMPLE_Y_M := 2.0           ## the cross-section is read every 2 m
const RIVER_EDGE_MARGIN_M := 25.0 ## a river nearer the site's edge than this is not read
## ground this near the lowest across the site is the floor of the valley
const PLATEAU_M := 0.3
## the height the router is told the river's bank stands at: under any water level it is asked about
const FORBIDDEN_M := -100000.0
const RIVER_BANK_GROW_M := 3.0   ## a ground river's polygon is grown by its bank
const BANK_M := 3.0               ## clear ground between the river's edge and the road's verge
const FLAT_RIVER_OFFSET_M := 26.0 ## without ground: the river this far south of the road
const OFFSET_STEP_M := 2.0        ## road offsets tried from the river
const OFFSET_RANGE_M := 40.0
const STRIP_M := 16.0             ## a lot row's depth, what the offset is scored on
const BOW_KEPT := 0.4             ## of the seeded bow, so the road is never straight
## the hill side the core needs behind the road: the common and the landmark
## behind it
const HILL_ROOM_M := 46.0
## relaxation passes after the bank raised the road
const RELAX_PASSES := 200
const SMOOTH_COLUMNS := 15
const MEDIAN_COLUMNS := 9         ## the offsets and the river line are median-filtered
const LANE_PITCH_M := 40.0
const LANE_LENGTH_M := 36.0
const LANE_CAP := 0.12
const TRACK_CAP := 0.30
## A way leans along the valley in steps, never so far that it meets the road
## at under the road check's junction angle (30 degrees) with a margin
const WAY_LEAN_STEP_DEG := 5.0
const WAY_LEAN_MAX_LANE_DEG := 45.0
const WAY_LEAN_MAX_DEG := 55.0
const WAY_MARGIN := 0.01        ## a track is laid this under its cap: the final points are re-measured
const LANES_MIN := 3
const LANES_MAX := 6
const HOUSEHOLDS_PER_LANE := 3.0
const LANE_SPOTS := [0.14, 0.86, 0.30, 0.70, 0.06, 0.94, 0.42, 0.58, 0.22, 0.78, 0.5]
## the households' slots: this far in from the site's ends, this far off the road's line
const SLOT_END_M := 14.0
const SLOT_OFFSET_M := 11.0
const SLOT_COMMON_END_M := 11.0   ## the neighbours of the common stand this far beyond its ends
const COMMON_CLEAR_M := 12.0      ## a lane's foot this far from the common's x range
const COMMON_ASPECT := 1.8        ## the common's width over its depth, squared: wide and shallow
const COMMON_WIDTH_MIN := 18.0
const COMMON_DEPTH_MIN := 8.0


static func plan(spec: VillageSpec, extra_lanes := 0, site_scale := 1.0,
		minimum_depth := 0.0, ground: VillageTerrain = null) -> VillagePlan:
	var out := VillagePlan.new(spec)
	out.site = site_rect(spec, site_scale, minimum_depth)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("site|%d|%s" % [spec.seed, spec.form])
	if ground != null:
		out.ground = ground
		out.site_anchor = ground.site_anchor
		out.site_yaw = ground.site_yaw
	var seeded: PackedVector2Array = VillageSitePlanner._through_road(out.site, spec, rng)
	var valley := read_valley(out.site, ground, seeded)
	var through: PackedVector2Array = _road_line(out.site, valley, seeded)
	if ground != null:
		through = _route(through, out.site, ground, valley)
		through = _keep_clear(through, valley)
	if not bool(valley["found"]):
		# no river read from the ground: it runs beside the road as laid
		var river_line: PackedFloat64Array = valley["river"]
		for i in range(mini(through.size(), river_line.size())):
			river_line[i] = through[i].y - FLAT_RIVER_OFFSET_M
		valley["river"] = river_line
	out.roads.append(VillageSitePlanner._road(through, &"through", spec.wealth))
	var a: VillageSiteAnalysis = null
	if ground != null:
		a = VillageSiteAnalysis.of(ground, out.site, ANALYSIS_CELL_M)
		if not a.valid():
			a = null
	# the core: a common lying along the road, the landmark behind it
	_core(out, spec, through, VillageDispersedForm._main_x(out, through, a))
	_lanes(out, spec, through, lane_count(spec) + extra_lanes / 2)
	var ground_shore := false
	if ground != null:
		VillageSitePlanner.grade_roads(out)
		ground_shore = VillageGroundWater.add(out)
		if ground_shore:
			# the wet channel of a river grid is the river
			for w in out.water:
				if bool(w.get("ground", false)) and spec.water in [&"river", &"stream"]:
					w["kind"] = spec.water
					# the water's margin is its bank: a leat across a 3 m channel
					# wall falls past what PlaceCheck's `mill_ground` allows
					var grown: PackedVector2Array = Poly.offset(w["poly"], RIVER_BANK_GROW_M)
					if grown.size() >= 3:
						w["poly"] = grown
	if not ground_shore and spec.water != &"none":
		var ribbon := river_polygon(valley, spec, out.site)
		if not ribbon.is_empty():
			out.water.append({"poly": ribbon, "kind": &"stream" if spec.water == &"stream" else &"river",
				"ground": ground != null, "source": "valley"})
	out.water_crossings = VillageWaterPlan.crossings(out.water, out.roads)
	return out


## Climbing ways for this many households.
static func lane_count(spec: VillageSpec) -> int:
	return clampi(int(round(float(spec.households) / HOUSEHOLDS_PER_LANE)), LANES_MIN, LANES_MAX)


## Long and shallow, within the caller's envelope, grown along the road only.
static func site_rect(spec: VillageSpec, site_scale := 1.0, minimum_depth := 0.0) -> Rect2:
	var side: float = VillageSitePlanner.site_rect(spec).size.x
	var length: float = clampf(side * SITE_LENGTH_X, SITE_LENGTH_MIN, SITE_LENGTH_MAX)
	var depth: float = clampf(side * SITE_DEPTH_X, SITE_DEPTH_MIN, SITE_DEPTH_MAX)
	if spec.requested_site_m > 0.0:
		length = minf(length, spec.requested_site_m)
		depth = minf(depth, spec.requested_site_m)
	depth = minf(maxf(depth, minimum_depth), VillageSitePlanner.SITE_MAX_SIDE)
	var w: float = minf(length * maxf(site_scale, 1.0), VillageSitePlanner.SITE_MAX_SIDE)
	if spec.requested_site_m > 0.0:
		w = minf(w, spec.requested_site_m)
	return Rect2(Vector2(-w * 0.5, -depth * 0.5), Vector2(w, depth))


# ------------------------------------------------------------ reading the valley

## The valley under the site, per column of the seeded road (`xs`):
## {"xs", "river": PackedFloat64Array (the river's y; the road's seed
## when the valley is not read), "half": river half-width, "offset": the
## road's distance from the river (+y), "found": the river was read}.
static func read_valley(site: Rect2, ground: VillageTerrain, seeded: PackedVector2Array) -> Dictionary:
	var n: int = seeded.size()
	var xs := PackedFloat64Array()
	var river := PackedFloat64Array()
	var half := PackedFloat64Array()
	var found := PackedByteArray()
	for p in seeded:
		xs.append(p.x)
		river.append(p.y - FLAT_RIVER_OFFSET_M)
		half.append(VillageWaterPlan.RIVER_WIDTH * 0.5)
		found.append(0)
	var out := {"xs": xs, "river": river, "half": half, "offset": PackedFloat64Array(),
		"found": false, "wet": false}
	var offs := PackedFloat64Array()
	offs.resize(n)
	if ground == null:
		for i in range(n):
			offs[i] = FLAT_RIVER_OFFSET_M
		out["offset"] = offs
		return out
	var wl: float = ground.water_level_m
	var wet: bool = not is_nan(wl)
	out["wet"] = wet
	var lo: float = site.position.y
	var hi: float = site.end.y
	var edge_lo: float = site.position.y + RIVER_EDGE_MARGIN_M
	var edge_hi: float = site.end.y - RIVER_EDGE_MARGIN_M
	var nfound := 0
	for i in range(n):
		var best_y := NAN
		var best_half := VillageWaterPlan.RIVER_WIDTH * 0.5
		if wet:
			# the widest wet run in the column
			var run0 := NAN
			var widest := 0.0
			var y: float = site.position.y
			while y <= site.end.y + 1e-6:
				var is_wet: bool = ground.height_at(Vector2(xs[i], y)) <= wl + VillageGroundWater.FREEBOARD_M
				if is_wet and is_nan(run0):
					run0 = y
				if (not is_wet or y + SAMPLE_Y_M > site.end.y) and not is_nan(run0):
					var width: float = y - run0
					if width > widest:
						widest = width
						best_y = (run0 + y) * 0.5
						best_half = maxf(widest * 0.5, 2.0)
					run0 = NAN
				y += SAMPLE_Y_M
			if widest < SAMPLE_Y_M or best_y < edge_lo or best_y > edge_hi:
				best_y = NAN
		else:
			# the lowest ground across the site, three samples smoothed, and
			# not at the edge of what was read (that is a slope, not a thalweg)
			var ys := PackedFloat64Array()
			var hs := PackedFloat64Array()
			var low := INF
			var y2: float = lo
			while y2 <= hi + 1e-6:
				var h := 0.0
				for k in [-1.0, 0.0, 1.0]:
					h += ground.height_at(Vector2(xs[i], y2 + k * SAMPLE_Y_M)) / 3.0
				ys.append(y2)
				hs.append(h)
				low = minf(low, h)
				y2 += SAMPLE_Y_M
			# the middle of the lowest ground: a flat floor is as wide as it is
			var first := -1
			var last2 := -1
			for k in range(hs.size()):
				if hs[k] <= low + PLATEAU_M:
					if first < 0:
						first = k
					last2 = k
			if first >= 0:
				best_y = (ys[first] + ys[last2]) * 0.5
			if first < 0 or first == 0 or last2 == hs.size() - 1 or best_y < edge_lo or best_y > edge_hi:
				best_y = NAN
		if not is_nan(best_y):
			river[i] = best_y
			half[i] = best_half
			found[i] = 1
			nfound += 1
	if nfound * 3 < n:
		# the river is not in this site, or the grid is too coarse to show it:
		# `plan` lays it a fixed offset south of the road it routed, as a flat
		# valley is, and the lot planner and the checks say what the ground
		# makes of it
		for i in range(n):
			offs[i] = FLAT_RIVER_OFFSET_M
		out["offset"] = offs
		return out
	# fill the columns that did not read from their neighbours, then smooth
	var last := -1
	for i in range(n):
		if found[i] == 1:
			if last >= 0 and i - last > 1:
				for k in range(last + 1, i):
					var t: float = float(k - last) / float(i - last)
					river[k] = lerpf(river[last], river[i], t)
					half[k] = lerpf(half[last], half[i], t)
			last = i
	var first := 0
	while first < n and found[first] == 0:
		first += 1
	for i in range(first):
		river[i] = river[first]
		half[i] = half[first]
	for i in range(last + 1, n):
		river[i] = river[last]
		half[i] = half[last]
	river = _smooth(_median(river, MEDIAN_COLUMNS))
	half = _smooth(_median(half, MEDIAN_COLUMNS))
	out["river"] = river
	out["half"] = half
	out["found"] = true
	# the road's distance from the river, per column, scored on the floor
	for i in range(n):
		offs[i] = _best_offset(ground, site, xs[i], river[i], half[i])
	out["offset"] = _smooth(_median(offs, MEDIAN_COLUMNS))
	return out


## The distance from the river's centreline at which the road's two lot rows
## are most buildable: the hill row (north) on the dry ground beyond the road,
## the river row (south) between the road and the bank where it is deep enough
## for a lot. Nearest the river on a tie.
static func _best_offset(ground: VillageTerrain, site: Rect2, x: float, river_y: float,
		half: float) -> float:
	var road_half: float = float(VillageSitePlanner.ROAD_CLASSES[&"through"]["width"]) * 0.5 \
		+ float(VillageSitePlanner.ROAD_CLASSES[&"through"]["verge"])
	var d_min: float = half + BANK_M + road_half
	var best: float = d_min
	var best_score := -INF
	var d: float = d_min
	while d <= d_min + OFFSET_RANGE_M + 1e-6:
		var road_y: float = river_y + d
		if road_y + road_half + STRIP_M > site.end.y - 4.0:
			break
		var hill: float = _row(ground, x, road_y + road_half, road_y + road_half + STRIP_M)
		var gap: float = d - half - BANK_M - road_half
		var bank := 0.0
		if gap > 4.0:
			bank = _row(ground, x, road_y - road_half - minf(gap, STRIP_M), road_y - road_half) \
				* minf(gap, STRIP_M) / STRIP_M
		var score: float = hill + bank - 0.004 * (d - d_min)
		if score > best_score + 1e-9:
			best_score = score
			best = d
		d += OFFSET_STEP_M
	return best


## How buildable the row between y0 and y1 is at column x: the mean over the
## row of 1 - slope / PLOT_MAX, dry ground only.
static func _row(ground: VillageTerrain, x: float, y0: float, y1: float) -> float:
	var sum := 0.0
	var n := 0
	var y: float = y0
	while y <= y1 + 1e-6:
		var p := Vector2(x, y)
		n += 1
		if not ground.is_wet(p):
			sum += clampf(1.0 - ground.slope_at(p) / VillageSiteAnalysis.PLOT_MAX, 0.0, 1.0)
		y += 3.0
	return sum / maxf(n, 1)


## The road's seed: the river's line plus the offset, a little of the seeded
## bow kept, inside the site.
static func _road_line(site: Rect2, valley: Dictionary, seeded: PackedVector2Array) -> PackedVector2Array:
	var river: PackedFloat64Array = valley["river"]
	var off: PackedFloat64Array = valley["offset"]
	var half: PackedFloat64Array = valley["half"]
	var road_half: float = float(VillageSitePlanner.ROAD_CLASSES[&"through"]["width"]) * 0.5 \
		+ float(VillageSitePlanner.ROAD_CLASSES[&"through"]["verge"])
	var lo: float = site.position.y + road_half + VillageSitePlanner.SITE_MARGIN_M + 1.0
	var hi: float = site.end.y - road_half - VillageSitePlanner.SITE_MARGIN_M - 1.0
	var core_hi: float = site.end.y - HILL_ROOM_M
	var out := PackedVector2Array()
	for i in range(seeded.size()):
		var bow: float = seeded[i].y * BOW_KEPT
		var d_min: float = half[i] + BANK_M + road_half
		var y: float = river[i] + maxf(off[i] + bow, d_min)
		# the core's room first, the river's bank before it
		y = minf(y, core_hi)
		y = maxf(y, river[i] + d_min)
		out.append(Vector2(seeded[i].x, clampf(y, lo, hi)))
	return out


## `VillageSitePlanner._route_through` with the river's bank forbidden: the
## router's own water cost, which it charges for ground at or under a level,
## is pointed at the strip the river and its bank take, so the road is the
## least-grade line on the dry side of it and never has to be pushed off the
## river afterwards (which a gorge's grade does not forgive).
static func _route(seeded: PackedVector2Array, site: Rect2, ground: VillageTerrain,
		valley: Dictionary) -> PackedVector2Array:
	if not bool(valley["found"]):
		return VillageSitePlanner._route_through(seeded, site, ground)
	var road_half: float = float(VillageSitePlanner.ROAD_CLASSES[&"through"]["width"]) * 0.5 \
		+ float(VillageSitePlanner.ROAD_CLASSES[&"through"]["verge"])
	var lo: float = site.position.y + road_half + VillageSitePlanner.SITE_MARGIN_M
	var hi: float = site.end.y - road_half - VillageSitePlanner.SITE_MARGIN_M
	if hi < lo:
		return seeded
	var band: float = maxf(15.0, VillageSitePlanner.ROUTE_BAND * site.size.y)
	var seed_lo := INF
	var seed_hi := -INF
	for p in seeded:
		seed_lo = minf(seed_lo, p.y)
		seed_hi = maxf(seed_hi, p.y)
	lo = maxf(lo, seed_lo - band)
	hi = minf(hi, seed_hi + band)
	var xs := PackedFloat64Array()
	var ys := PackedFloat64Array()
	for p in seeded:
		xs.append(p.x)
		ys.append(clampf(p.y, lo, hi))
	var vx: PackedFloat64Array = valley["xs"]
	var river: PackedFloat64Array = valley["river"]
	var half: PackedFloat64Array = valley["half"]
	var h := func(along: float, across: float) -> float:
		# the column nearest `along`: the strip is as wide as the river's bank
		var k: int = clampi(int(round((along - vx[0]) / maxf(vx[1] - vx[0], 1e-6))), 0, vx.size() - 1)
		if across < river[k] + half[k] + BANK_M + road_half:
			return FORBIDDEN_M
		return ground.height_at(Vector2(along, across))
	var routed := VillageRoadRouter.route_across(h, xs, ys, lo, hi,
		float(VillageSitePlanner.ROAD_CLASSES[&"through"]["grade_max"]), FORBIDDEN_M * 0.5)
	var out := PackedVector2Array()
	for i in range(seeded.size()):
		out.append(Vector2(xs[i], routed[i]))
	return out


## The routed road held off the river's bank: raised to the bank where it ran
## inside it, then relaxed -- every vertex the mean of its neighbours, never
## below its bank -- so the raising leaves no kink (the router's bend rule held
## before it).
static func _keep_clear(through: PackedVector2Array, valley: Dictionary) -> PackedVector2Array:
	if not bool(valley["found"]):
		return through
	var river: PackedFloat64Array = valley["river"]
	var half: PackedFloat64Array = valley["half"]
	var road_half: float = float(VillageSitePlanner.ROAD_CLASSES[&"through"]["width"]) * 0.5 		+ float(VillageSitePlanner.ROAD_CLASSES[&"through"]["verge"])
	var n: int = mini(through.size(), river.size())
	var floor_y := PackedFloat64Array()
	var raised := false
	var out := through.duplicate()
	for i in range(n):
		floor_y.append(river[i] + half[i] + BANK_M + road_half)
		if out[i].y < floor_y[i] - 1e-9:
			out[i].y = floor_y[i]
			raised = true
	if not raised:
		return through
	for _pass in range(RELAX_PASSES):
		var prev := out.duplicate()
		for i in range(1, n - 1):
			out[i].y = maxf(floor_y[i], (prev[i - 1].y + prev[i].y + prev[i + 1].y) / 3.0)
	return out


## The river as one polygon along its line, the width of its kind, clipped to
## the site. Empty when there is no room for one.
static func river_polygon(valley: Dictionary, spec: VillageSpec, site: Rect2) -> PackedVector2Array:
	var xs: PackedFloat64Array = valley["xs"]
	var river: PackedFloat64Array = valley["river"]
	var width: float = VillageWaterPlan.STREAM_WIDTH if spec.water == &"stream" \
		else VillageWaterPlan.RIVER_WIDTH
	var line := PackedVector2Array()
	for i in range(xs.size()):
		line.append(Vector2(xs[i], river[i]))
	if line.size() < 2:
		return PackedVector2Array()
	var poly: PackedVector2Array = Poly.ribbon(line, width * 0.5)
	var inside: Array[PackedVector2Array] = Geometry2D.intersect_polygons(poly,
		Poly.from_rect(site.grow(-VillageWaterPlan.SITE_MARGIN)))
	if inside.is_empty():
		return PackedVector2Array()
	var best: PackedVector2Array = inside[0]
	for p in inside:
		if Poly.area(p) > Poly.area(best):
			best = p
	return best


## A moving average over SMOOTH_COLUMNS: a river read off the ground has
## tributaries and bars in it that no road follows.
static func _smooth(v: PackedFloat64Array) -> PackedFloat64Array:
	var out := v.duplicate()
	var r: int = SMOOTH_COLUMNS / 2
	for i in range(v.size()):
		var sum := 0.0
		var n := 0
		for k in range(maxi(0, i - r), mini(v.size(), i + r + 1)):
			sum += v[k]
			n += 1
		out[i] = sum / float(n)
	return out


static func _median(v: PackedFloat64Array, window: int) -> PackedFloat64Array:
	var out := v.duplicate()
	var r: int = window / 2
	for i in range(v.size()):
		var w: Array[float] = []
		for k in range(maxi(0, i - r), mini(v.size(), i + r + 1)):
			w.append(v[k])
		w.sort()
		out[i] = w[w.size() / 2]
	return out


# ------------------------------------------------------------------- the core

## The common as a widening of the road: long and shallow, lying along the
## through road on its hill side, so the body keeps to the road's frontage
## and the lots across the road, at the common's ends and the landmark behind
## it front it (the street form's ring would put a blob in the middle of a
## ribbon). The approach path to the well, and the landmark slot straight
## behind the common, fronting it.
static func _core(out: VillagePlan, spec: VillageSpec, through: PackedVector2Array, x: float) -> void:
	var site: Rect2 = out.site
	var small: bool = spec.population < VillageSitePlanner.HAMLET_POPULATION
	var target: float = VillageSitePlanner.HAMLET_COMMON_AREA if small \
		else VillageSitePlanner._common_area(spec, site)
	var width: float = VillageSitePlanner.WELL_PLOT_SIDE if small \
		else clampf(sqrt(target * COMMON_ASPECT), COMMON_WIDTH_MIN, site.size.x * 0.25)
	var height: float = VillageSitePlanner.WELL_PLOT_SIDE if small else maxf(target / width, COMMON_DEPTH_MIN)
	var mid: float = through[VillageSitePlanner._vertex_near_x(through, x)].x
	var rect: Rect2 = VillageSitePlanner._rect_north_of(through, out.roads[0], mid, width, height,
		VillageSitePlanner.COMMON_ROAD_GAP)
	out.commons.append({"poly": Poly.from_rect(rect), "kind": &"common"})
	var join: Vector2 = through[VillageSitePlanner._vertex_near_x(through, mid)]
	var walk: Vector2 = (rect.get_center() - join).normalized()
	out.roads.append(VillageSitePlanner._road(PackedVector2Array([join, rect.get_center() - walk * 1.8]),
		&"path", spec.wealth))
	VillageSitePlanner._reserve_landmark(out, spec, rect, site)


# ---------------------------------------------------------------- the households

## The lot planner's hook (cut_measured): the households are strung along the
## road. Each house and cottage is given a slot -- a point on the road, a house
## depth to one side of it, sides alternating -- evenly along the road from end
## to end, the biggest at the slot nearest the common (the wealth gradient),
## and is cut the lot nearest its slot. Left to itself the lot planner fills
## outward from the common into a blob; a valley village is a ribbon. Farms
## are strung with them (the farm rule measures 40 % of the site's depth to its
## edge, which a farm beside a road in the middle of a shallow site meets); the
## trades keep their own addresses.
static func assign_jobs(plan: VillagePlan, jobs: Array[Dictionary]) -> void:
	if plan.spec.form != &"valley" or plan.roads.is_empty() or plan.roads[0]["class"] != &"through":
		return
	var homes: Array[Dictionary] = []
	for job in jobs:
		if job["class"] in [&"cottage", &"townhouse", &"farm"]:
			homes.append(job)
	if homes.is_empty():
		return
	homes.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var ax: float = VillageLotPlanner._floor_area(x)
		var ay: float = VillageLotPlanner._floor_area(y)
		if absf(ax - ay) > 0.01:
			return ax > ay
		return int(x["order"]) < int(y["order"]))
	var through: PackedVector2Array = plan.roads[0]["points"]
	var site: Rect2 = plan.site
	var x0: float = site.position.x + SLOT_END_M
	var x1: float = site.end.x - SLOT_END_M
	var centre_x: float = site.get_center().x
	if not plan.commons.is_empty():
		centre_x = Poly.bounding_rect(plan.commons[0]["poly"]).get_center().x
	var n: int = homes.size()
	# the slots round the common first -- the neighbours at its ends on the hill
	# side, two across the road -- so its edge is fronted; the rest evenly along
	# the road, clear of the common
	var slots: Array[Dictionary] = []
	var cr := Rect2()
	if not plan.commons.is_empty():
		cr = Poly.bounding_rect(plan.commons[0]["poly"])
		slots.append({"x": cr.position.x - SLOT_COMMON_END_M, "side": 1.0})
		slots.append({"x": cr.end.x + SLOT_COMMON_END_M, "side": 1.0})
		slots.append({"x": cr.position.x + cr.size.x * 0.25, "side": -1.0})
		slots.append({"x": cr.end.x - cr.size.x * 0.25, "side": -1.0})
		while slots.size() > n:
			slots.pop_back()
	var rest: int = n - slots.size()
	var side := 1.0
	var spread: Array[float] = []
	for i in range(rest):
		var x: float = lerpf(x0, x1, (float(i) + 0.5) / float(rest))
		# not on the common's own stretch, which the slots above take
		if cr.size.x > 0.0 and x > cr.position.x - SLOT_COMMON_END_M and x < cr.end.x + SLOT_COMMON_END_M:
			if x > cr.get_center().x:
				x = cr.end.x + SLOT_COMMON_END_M + float(i % 3) * 14.0
			else:
				x = cr.position.x - SLOT_COMMON_END_M - float(i % 3) * 14.0
		spread.append(x)
	spread.sort_custom(func(a: float, b: float) -> bool:
		return absf(a - centre_x) < absf(b - centre_x))
	for x in spread:
		slots.append({"x": x, "side": side})
		side = -side
	for i in range(n):
		var sx: float = slots[i]["x"]
		var sy: float = VillageLotPlanner._polyline_y_at_x(through, sx)
		homes[i]["near_point"] = Vector2(sx, sy + float(slots[i]["side"]) * SLOT_OFFSET_M)
		homes[i]["siting"] = VillageLotPlanner.SITING_DEFAULT


# ------------------------------------------------------------------- the lanes

## Climbing ways off the hill side of the through road: a way is a lane (a
## cart's 12 %) where a short stub of the ground allows it, else a track (30 %)
## to the site's edge, else a stair to it. The way leaves the road square if
## the ground lets it, and leans along the valley (never nearer the road than
## the road check's junction angle) as far as it must to stay inside its
## class's grade: a way at a lean climbs a steep side at the grade a cart or a
## mule can take. None across the common, the landmark, or another way, nor
## within LANE_PITCH_M of another's foot.
static func _lanes(out: VillagePlan, spec: VillageSpec, through: PackedVector2Array, wanted: int) -> void:
	if wanted <= 0:
		return
	var site: Rect2 = out.site
	var common_x := Vector2(INF, -INF)
	if not out.commons.is_empty():
		var cr: Rect2 = Poly.bounding_rect(out.commons[0]["poly"])
		common_x = Vector2(cr.position.x - COMMON_CLEAR_M, cr.end.x + COMMON_CLEAR_M)
	var feet: Array[Vector2] = []
	var added := 0
	for f in LANE_SPOTS:
		if added >= wanted:
			return
		var x: float = site.position.x + site.size.x * float(f)
		if x > common_x.x and x < common_x.y:
			continue
		var idx: int = VillageSitePlanner._vertex_near_x(through, x)
		var start: Vector2 = through[idx]
		var clear := true
		for foot in feet:
			if absf(foot.x - start.x) < LANE_PITCH_M:
				clear = false
		if not clear:
			continue
		var way: Dictionary = _way(out, through, idx)
		if way.is_empty():
			continue
		var stub: PackedVector2Array = way["points"]
		var ribbon: PackedVector2Array = Poly.ribbon(stub, 1.75 if way["class"] == &"lane" else 2.5)
		var blocked := false
		for c in out.commons:
			blocked = blocked or VillageLotPlanner.overlap_area(ribbon, c["poly"]) > 0.05
		if out.landmark_reserved() and VillageLotPlanner.overlap_area(ribbon, out.landmark_site["poly"]) > 0.05:
			blocked = true
		for r in out.roads:
			if r["class"] == &"through":
				continue
			blocked = blocked or VillageLotPlanner.overlap_area(ribbon,
				VillageSitePlanner.road_ribbon(r, true)) > 0.05
		if blocked:
			continue
		out.roads.append(VillageSitePlanner._road(stub, way["class"], spec.wealth))
		feet.append(stub[0])
		added += 1


## The way off `through[idx]`: {"points", "class"}, or {} when there is no room.
static func _way(out: VillagePlan, through: PackedVector2Array, idx: int) -> Dictionary:
	var site: Rect2 = out.site
	var start: Vector2 = through[idx]
	var a: int = maxi(0, idx - 1)
	var b: int = mini(through.size() - 1, idx + 1)
	var tangent: Vector2 = (through[b] - through[a]).normalized()
	var square := Vector2(-tangent.y, tangent.x)
	if square.y < 0.0:
		square = -square
	var ground: VillageTerrain = out.ground
	# [class, length (0: to the edge), grade cap, largest lean]
	for plan_row in [[&"lane", LANE_LENGTH_M, LANE_CAP, WAY_LEAN_MAX_LANE_DEG],
			[&"track", 0.0, TRACK_CAP - WAY_MARGIN, WAY_LEAN_MAX_DEG]]:
		var cls: StringName = plan_row[0]
		var leans: Array[float] = [0.0]
		var step := WAY_LEAN_STEP_DEG
		while step <= float(plan_row[3]) + 1e-6:
			leans.append(step)
			leans.append(-step)
			step += WAY_LEAN_STEP_DEG
		for lean in leans:
			var dir: Vector2 = square.rotated(deg_to_rad(lean))
			var stub := PackedVector2Array()
			if float(plan_row[1]) > 0.0:
				var reach: float = _room(start, dir, site, 3.0)
				if reach < VillageSitePlanner.LANE_MIN_LENGTH:
					continue
				stub = PackedVector2Array([start, start + dir * minf(float(plan_row[1]), reach)])
			else:
				var end: Vector2 = VillageDispersedForm._ray_to_edge(start, dir, site)
				if start.distance_to(end) < VillageSitePlanner.LANE_MIN_LENGTH:
					continue
				stub = PackedVector2Array([start, end])
			var g := 0.0
			if ground != null:
				g = VillageRoadRouter.grade_of(ground, stub)
			if g <= float(plan_row[2]):
				return {"points": stub, "class": cls}
	# no cart or mule grade at any lean: a stair straight to the edge
	var end2: Vector2 = VillageDispersedForm._ray_to_edge(start, square, site)
	if start.distance_to(end2) < VillageSitePlanner.LANE_MIN_LENGTH:
		return {}
	return {"points": PackedVector2Array([start, end2]), "class": &"steps"}


## How far a ray from `start` along `dir` runs inside the site, short of its
## edge by `inset`.
static func _room(start: Vector2, dir: Vector2, site: Rect2, inset: float) -> float:
	var t := INF
	if dir.x > 1e-9:
		t = minf(t, (site.end.x - inset - start.x) / dir.x)
	elif dir.x < -1e-9:
		t = minf(t, (site.position.x + inset - start.x) / dir.x)
	if dir.y > 1e-9:
		t = minf(t, (site.end.y - inset - start.y) / dir.y)
	elif dir.y < -1e-9:
		t = minf(t, (site.position.y + inset - start.y) / dir.y)
	return t
