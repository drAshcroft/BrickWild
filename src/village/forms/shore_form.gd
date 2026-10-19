class_name VillageShoreForm
extends RefCounted
## `shore`: one row of houses along a shoreline that CURVES, the shore street
## laid by following the ground's own water level (VTER-FORM-SHORE,
## docs/VILLAGE_TERRAIN.md "The shore form").
##
## The ground derives this form at rows 1, 4 and 10 of the form rule (a
## drowned window; a coast or a lake with wet ground within 350 m; a fishing
## coast). Reine on its fjord, Perast on its bay, Limone on Garda, Hallstatt
## under its mountain: the old strand laid a straight row at a fixed distance
## from a rectangle of water, which is no shore any of them has.
##
## The strand's own composition, bent to the ground:
##
##   1. SITING (`site`): the frame is turned and set so the water is on +y
##      and the shoreline runs along x -- an anchor ON the shoreline and a
##      yaw, scored over the shoreline the frame would see (does every column
##      have one, how it tilts and bends, how steep the strip and how steep
##      the street's grade) -- not the generic siting's, which keeps a village
##      off the water and so turns its back to it.
##   2. THE SHORELINE (`shoreline_in`): per column, the first y from the
##      inland end at which the ground is wet (at or under the level plus the
##      freeboard `VillageGroundWater` uses, so the two agree) and stays wet
##      for WET_RUN_M; a pond on the way is not a shore. Smoothed.
##   3. THE SHORE STREET: the through road, the shoreline offset inland by
##      the strand's own waterfront depth (a native row house's setback, back
##      and yard, the lot planner's measure, 4.5 m of road and 2 m of bank)
##      and routed by grade (VillageRoadRouter) within SEAT_BAND of that
##      curve, kept inside the bend rule.
##   4. THE ROW: the lot planner cuts lots on the water side of the street
##      exactly as it does for a strand; `VillageGroundWater` turns the wet
##      ground into plan water, which the lots refuse. The common is a plot
##      between the street and the bank at the street's flattest point, the
##      landmark inland of it on its own lane.
##
## `plan.shoreline` carries the shoreline (x, y) per column, in the plan's
## frame: what a later form (stilts and boardwalks over the shallows) reads.
##
## Without ground, or on ground with no water level, the form is the straight
## strand (`VillageSitePlanner` plans it so: nothing flat changes). Pure: the
## same spec on the same ground is the same plan.

## The raster step along a scan and the shoreline's column spacing, metres.
const SCAN_STEP_M := 1.0
const COLUMN_M := 10.0
## Water must run this far to be a shore (a hollow is not a lake).
const WET_RUN_M := 14.0
## The inland end of the scan and the water end, from the anchor.
const SCAN_INLAND_M := 150.0
const SCAN_WATER_M := 60.0
## The strand's own constants: road centre to the bank.
const ROAD_HALF_M := 4.5
const BANK_M := 2.0
const ROW_DEPTH_MIN_M := 28.0
## The water band beyond the shore the site keeps, and the landmark's inland.
const WATER_BAND_M := 24.0
const INLAND_MIN_M := 62.0
## The street may stray from the shore-parallel curve by this much inland and
## this much seaward when the router finds easier ground.
const SEAT_BAND_INLAND := 7.0
const SEAT_BAND_SEA := 1.5
## Largest turn at a 10 m vertex: 25 degrees per 20 m is the rule (§5); this
## leaves a margin for the grade clamp.
const TURN_MAX_DEG := 9.0
## Smoothing, columns each side.
const SMOOTH_COLS := 2

# --- siting
const REACH_M := 400.0
const ANCHOR_SPACING_M := 36.0
const ANCHORS_MAX := 44
const YAW_STEP := TAU / 24.0
const YAW_FAN := 3
const SITE_SCALE_COVER := 1.5
const CACHE_MAX := 16
const W_MISS := 300.0
const W_TILT := 12.0
const W_BEND := 25.0
const W_STEEP := 4.0
const W_CLIFF := 20.0
const W_ROAD_OVER := 20.0
const W_ROAD_MEAN := 2.0
const W_CENTRE := 1.0
const W_LAKE_SMALL := 40.0
const ROAD_FREE := 0.10

static var _cache := {}
static var _order: Array[String] = []


# ======================================================================= siting

## The frame for `spec` on its ground: {"anchor", "yaw", "score", "terms",
## "ground" (the village-frame view), "shore" (whether a shoreline was found)}.
## Without a water level there is no shore to follow and the generic siting
## answers (and the planner lays a straight strand).
static func site(spec: VillageSpec) -> Dictionary:
	var t: VillageTerrain = spec.terrain
	if is_nan(t.water_level_m):
		var generic := VillageSiting.site(spec)
		generic["shore"] = false
		return generic
	var key := "%s|%d|%s|%s|%s|%d" % [t.fingerprint(), spec.seed, spec.water, spec.purpose,
		spec.population, spec.households]
	if _cache.has(key):
		return _cache[key]
	var out := choose(t, spec)
	var w: float = VillageSitePlanner.SITE_MAX_SIDE * 0.5 + VillageSiting.VIEW_PAD_M
	out["ground"] = t.sited_view(out["anchor"], out["yaw"], Rect2(-w, -w, 2.0 * w, 2.0 * w),
		minf(t.cell_m, VillageSiting.VIEW_CELL_MAX))
	_cache[key] = out
	_order.append(key)
	while _order.size() > CACHE_MAX:
		_cache.erase(_order.pop_front())
	return out


static func clear_cache() -> void:
	_cache.clear()
	_order.clear()


## The extent of the site about the anchor (an estimate, for coverage and
## scoring): {"x": half width, "up": inland, "down": seaward}.
static func extent(spec: VillageSpec, scale := 1.0) -> Dictionary:
	var base: Rect2 = VillageSitePlanner.site_rect(spec)
	var w: float = minf(base.size.x * scale, VillageSitePlanner.SITE_MAX_SIDE)
	var lead: float = ROAD_HALF_M + 36.0 + BANK_M
	return {"x": w * 0.5, "up": lead + maxf(INLAND_MIN_M, base.size.y * 0.5 + 14.0), "down": WATER_BAND_M + 6.0}


static func choose(t: VillageTerrain, spec: VillageSpec) -> Dictionary:
	var wl: float = t.water_level_m + VillageGroundWater.FREEBOARD_M
	var bounds := t.bounds()
	var cover := extent(spec, SITE_SCALE_COVER)
	var plain := extent(spec, 1.0)
	var starts := _shore_points(t, wl)
	var best := {}
	for ext in [cover, plain]:
		for a in starts:
			var normal := _toward_water(t, a, wl)
			if normal == Vector2.ZERO:
				continue
			var yaw0 := atan2(-normal.x, normal.y)
			for k in range(-YAW_FAN, YAW_FAN + 1):
				var yaw := yaw0 + float(k) * YAW_STEP
				if not _inside(bounds, ext, a, yaw):
					continue
				var s := _score(t, wl, ext, a, yaw)
				if best.is_empty() or float(s["score"]) < float(best["score"]) - 1e-9:
					best = s
		if not best.is_empty():
			break
	if best.is_empty():
		# no shore to be found on the grid within reach: the generic frame
		var generic := VillageSiting.choose(t, VillageSitePlanner.plan_flat(spec), true)
		generic["shore"] = false
		return generic
	# refine yaw and the slide along the shore, then set the origin ON it
	var ext_best: Dictionary = best["ext"]
	var dyaw := YAW_STEP
	var dstep := ANCHOR_SPACING_M
	for _round in range(3):
		dyaw *= 0.5
		dstep *= 0.5
		var centre: Dictionary = best
		var along := Vector2.from_angle(float(centre["yaw"]))
		for dj in [-1, 0, 1]:
			for dk in [-1, 0, 1]:
				if dj == 0 and dk == 0:
					continue
				var a2: Vector2 = Vector2(centre["anchor"]) + along * (dj * dstep)
				var yaw2: float = float(centre["yaw"]) + dk * dyaw
				if not _inside(bounds, ext_best, a2, yaw2):
					continue
				var s2 := _score(t, wl, ext_best, a2, yaw2)
				if float(s2["score"]) < float(best["score"]) - 1e-9:
					best = s2
	var anchor: Vector2 = best["anchor"]
	var yaw_b: float = fposmod(float(best["yaw"]), TAU)
	if yaw_b > TAU - 1e-4:
		yaw_b = 0.0
	var y0 := _first_wet(func(p: Vector2) -> float: return t.height_at(anchor + p.rotated(yaw_b)),
		0.0, -SCAN_INLAND_M, SCAN_WATER_M, wl, 0.25)
	if not is_nan(y0):
		anchor += Vector2(0.0, y0).rotated(yaw_b)
	best["anchor"] = anchor
	best["yaw"] = yaw_b
	best["shore"] = true
	best["fixed_centre"] = false
	return best


## Where the shoreline is on the caller's grid: interpolated crossings of the
## water level (plus freeboard) between neighbouring nodes, within reach of the
## caller's centre, thinned and ordered nearest first.
static func _shore_points(t: VillageTerrain, wl: float) -> Array[Vector2]:
	var found: Array[Vector2] = []
	var step := maxi(1, int(round(10.0 / t.cell_m)))
	for r in range(0, t.rows - step, step):
		for c in range(0, t.cols - step, step):
			var h0: float = t.heights[r * t.cols + c]
			var p0 := t.origin + Vector2(c, r) * t.cell_m
			for off in [Vector2i(step, 0), Vector2i(0, step)]:
				var h1: float = t.heights[(r + off.y) * t.cols + c + off.x]
				if (h0 <= wl) == (h1 <= wl):
					continue
				var s: float = (wl - h0) / (h1 - h0)
				var p := p0 + Vector2(off) * t.cell_m * s
				if p.length() <= REACH_M:
					found.append(p)
	found.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		var la := a.length()
		var lb := b.length()
		if absf(la - lb) > 1e-6:
			return la < lb
		return a.x < b.x if a.x != b.x else a.y < b.y)
	var kept: Array[Vector2] = []
	for p in found:
		var clash := false
		for q in kept:
			if p.distance_to(q) < ANCHOR_SPACING_M:
				clash = true
				break
		if not clash:
			kept.append(p)
			if kept.size() >= ANCHORS_MAX:
				break
	return kept


## The unit vector from `a` toward the water about it (the mean direction of
## the wet samples on two rings), or zero where the ground about it is all one
## thing.
static func _toward_water(t: VillageTerrain, a: Vector2, wl: float) -> Vector2:
	var sum := Vector2.ZERO
	var wet := 0
	var total := 0
	for radius in [35.0, 70.0, 110.0]:
		for k in range(16):
			var d := Vector2.from_angle(TAU * float(k) / 16.0)
			total += 1
			if t.height_at(a + d * radius) <= wl:
				sum += d
				wet += 1
	if wet < 2 or wet > total - 2 or sum.length() < 0.5:
		return Vector2.ZERO
	return sum.normalized()


static func _inside(bounds: Rect2, ext: Dictionary, anchor: Vector2, yaw: float) -> bool:
	var b := bounds.grow(0.01)
	var hx: float = ext["x"]
	for p in [Vector2(-hx, -float(ext["up"])), Vector2(hx, -float(ext["up"])),
			Vector2(hx, float(ext["down"])), Vector2(-hx, float(ext["down"]))]:
		if not b.has_point(anchor + (p as Vector2).rotated(yaw)):
			return false
	return true


## The first y from `y_from` toward `y_to` at which `height` (a Callable of a
## frame point) is at or under `wl` and stays so for WET_RUN_M; NAN if none, or
## if the scan starts wet. Linear between the last dry sample and the first
## wet one.
static func _first_wet(height: Callable, x: float, y_from: float, y_to: float, wl: float,
		step := SCAN_STEP_M) -> float:
	var y := y_from
	var prev_h: float = float(height.call(Vector2(x, y)))
	if prev_h <= wl:
		return NAN
	y += step
	while y <= y_to:
		var h: float = float(height.call(Vector2(x, y)))
		if h <= wl:
			var ok := true
			var run := step
			while run < WET_RUN_M and y + run <= y_to + WET_RUN_M:
				if float(height.call(Vector2(x, y + run))) > wl:
					ok = false
					break
				run += maxf(step, 2.0)
			if ok:
				var s: float = (prev_h - wl) / maxf(prev_h - h, 1e-9)
				return y - step + s * step
		prev_h = h
		y += step
	return NAN


static func _score(t: VillageTerrain, wl: float, ext: Dictionary, anchor: Vector2, yaw: float) -> Dictionary:
	var c := cos(yaw)
	var s := sin(yaw)
	var height := func(p: Vector2) -> float:
		return t.height_at(anchor + Vector2(p.x * c - p.y * s, p.x * s + p.y * c))
	var hx: float = ext["x"]
	var cols := 13
	var lead: float = ROAD_HALF_M + 36.0 + BANK_M
	var ys := PackedFloat64Array()
	var miss := 0
	for i in range(cols):
		var x: float = -hx + 2.0 * hx * float(i) / float(cols - 1)
		var y: float = _first_wet(height, x, -SCAN_INLAND_M, SCAN_WATER_M, wl, 4.0)
		ys.append(y)
		if is_nan(y):
			miss += 1
	var dx: float = 2.0 * hx / float(cols - 1)
	var tilt := 0.0
	var bend := 0
	var n_tilt := 0
	var prev_ang := NAN
	var steep := 0
	var cliff := 0
	var samples := 0
	var over := 0.0
	var mean_g := 0.0
	var road_len := 0.0
	var prev_road_h := NAN
	for i in range(cols):
		if is_nan(ys[i]):
			prev_ang = NAN
			prev_road_h = NAN
			continue
		var x: float = -hx + dx * float(i)
		if i + 1 < cols and not is_nan(ys[i + 1]):
			var m: float = (ys[i + 1] - ys[i]) / dx
			tilt += absf(m)
			n_tilt += 1
			var ang: float = atan(m)
			if not is_nan(prev_ang) and absf(rad_to_deg(ang - prev_ang)) > 25.0:
				bend += 1
			prev_ang = ang
		# the strip between the road and the bank
		var h_bank: float = height.call(Vector2(x, ys[i] - 2.0))
		var h_road: float = height.call(Vector2(x, ys[i] - lead))
		var g: float = absf(h_road - h_bank) / maxf(lead - 2.0, 1.0)
		samples += 1
		if g > VillageSiteAnalysis.PATH_MAX:
			cliff += 1
		if g > VillageSiteAnalysis.PLOT_MAX:
			steep += 1
		if not is_nan(prev_road_h):
			var gr: float = absf(h_road - prev_road_h) / dx
			over += maxf(0.0, gr - ROAD_FREE) * dx
			mean_g += gr * dx
			road_len += dx
		prev_road_h = h_road
	var terms := {
		"miss": W_MISS * float(miss) / float(cols),
		"tilt": W_TILT * (tilt / maxf(n_tilt, 1)),
		"bend": W_BEND * float(bend) / float(maxi(cols - 2, 1)),
		"steep": W_STEEP * float(steep) / maxf(samples, 1),
		"cliff": W_CLIFF * float(cliff) / maxf(samples, 1),
		"road": W_ROAD_OVER * over / maxf(road_len, 1.0) + W_ROAD_MEAN * mean_g / maxf(road_len, 1.0),
		"centre": W_CENTRE * anchor.length() / 400.0,
	}
	var total := 0.0
	for k in terms:
		total += float(terms[k])
	return {"anchor": anchor, "yaw": yaw, "score": total, "terms": terms, "ext": ext}


# ============================================================== the two sides

## Real shore villages are not one row on the bank: Perast, Reine and Limone
## stand a street back from the water as well as on it, and the survey's
## `water_within_30m` for the sites labelled shore runs 0.0-0.66 (median 0.12;
## the three high-confidence ones 0.28-0.66). The shore street takes houses on
## both sides, and the seaward side is held to this share of the street's
## frontages so the other houses stand behind it.
const SEAWARD_SHARE := 0.4


## Would this household's lot (on the shore street) make the seaward row more
## than SEAWARD_SHARE of the street's lots? The landmark and the seat stand off
## the street on their own lanes and are not counted; the trades keep the
## addresses VILLAGES 6 gives them (a mill's yard must reach the water, the
## smithy and the tavern stand where they stand) -- only households are held.
static func seaward_full(plan: VillagePlan, lot: Dictionary, job: Dictionary) -> bool:
	if Vector2(lot["normal"]).y <= 0.0 or int(lot["road"]) != 0 or VillageLotPlanner._order_of(job) != VillageLotPlanner._ORDER_HOUSE:
		return false
	var sea := 0
	var all := 0
	for l in plan.lots:
		if int(l["road"]) != 0 or bool(l.get("landmark", false)):
			continue
		all += 1
		if Vector2(l["normal"]).y > 0.0:
			sea += 1
	return float(sea + 1) > ceil(SEAWARD_SHARE * float(all + 1)) + 0.5


# ===================================================================== the plan

## The whole site plan of a shore village on `ground` (the frame `site` chose).
## `extra_lanes` is ignored, as the strand's is: a back lane would be a second
## row; the lot planner's retries buy ground along the street (`site_scale`)
## and a deeper shore reserve (`shore_depth`).
static func plan(spec: VillageSpec, _extra_lanes := 0, site_scale := 1.0, minimum_depth := 0.0,
		shore_depth := 0.0, ground: VillageTerrain = null) -> VillagePlan:
	var out := VillagePlan.new(spec)
	out.ground = ground
	out.site_anchor = ground.site_anchor
	out.site_yaw = ground.site_yaw
	var base: Rect2 = VillageSitePlanner.site_rect(spec)
	var width: float = minf(base.size.x * maxf(site_scale, 1.0), VillageSitePlanner.SITE_MAX_SIDE)
	var wl: float = ground.water_level_m + VillageGroundWater.FREEBOARD_M
	var cols: int = maxi(VillageSitePlanner.THROUGH_MIN_SAMPLES, int(ceil(width / COLUMN_M)))
	var xs := PackedFloat64Array()
	for i in range(cols + 1):
		xs.append(-width * 0.5 + width * float(i) / float(cols))
	var shore := shoreline_in(ground, xs, wl)
	if shore.is_empty():
		# no shoreline in this frame: nothing to follow
		return out
	out.shoreline = shore
	var row_depth: float = shore_depth if shore_depth > 0.0 else ROW_DEPTH_MIN_M
	var lead: float = ROAD_HALF_M + row_depth + BANK_M
	var seed := _seed_street(shore, lead)
	var ys := _route(ground, xs, seed, wl)
	var street := PackedVector2Array()
	for i in range(xs.size()):
		street.append(Vector2(xs[i], ys[i]))
	# the site: the street and a landmark's inland to the north, the water
	# band beyond the farthest shore to the south
	var top := INF
	var bottom := -INF
	for i in range(xs.size()):
		top = minf(top, ys[i])
		bottom = maxf(bottom, shore[i].y)
	var inland: float = maxf(INLAND_MIN_M, base.size.y * 0.5 + 14.0)
	var site_top: float = top - inland
	var site_bottom: float = bottom + WATER_BAND_M
	if site_bottom - site_top < minimum_depth:
		site_top = site_bottom - minimum_depth
	out.site = Rect2(Vector2(-width * 0.5, site_top), Vector2(width, site_bottom - site_top))
	out.roads.append(VillageSitePlanner._road(street, &"through", spec.wealth))
	_common_and_landmark(out, spec, street)
	VillageSitePlanner.grade_roads(out)
	VillageGroundWater.add(out)
	out.water_crossings = VillageWaterPlan.crossings(out.water, out.roads)
	return out


## The shoreline, per column of `xs`, as (x, y) in the frame: the first wet y
## from the inland end, holes filled from their neighbours, median-filtered
## and smoothed. Empty when fewer than half the columns have one.
static func shoreline_in(ground: VillageTerrain, xs: PackedFloat64Array, wl: float) -> PackedVector2Array:
	var height := func(p: Vector2) -> float: return ground.height_at(p)
	var raw := PackedFloat64Array()
	var have := 0
	for x in xs:
		var y: float = _first_wet(height, x, -SCAN_INLAND_M, SCAN_WATER_M, wl)
		raw.append(y)
		if not is_nan(y):
			have += 1
	if have * 2 < xs.size():
		return PackedVector2Array()
	# fill holes from the nearest column with a shore
	var filled := raw.duplicate()
	for i in range(xs.size()):
		if not is_nan(filled[i]):
			continue
		for d in range(1, xs.size()):
			if i - d >= 0 and not is_nan(raw[i - d]):
				filled[i] = raw[i - d]
				break
			if i + d < xs.size() and not is_nan(raw[i + d]):
				filled[i] = raw[i + d]
				break
	var med := filled.duplicate()
	for i in range(1, xs.size() - 1):
		var tri := [filled[i - 1], filled[i], filled[i + 1]]
		tri.sort()
		med[i] = tri[1]
	var sm := _smooth(med, SMOOTH_COLS, 2)
	var out := PackedVector2Array()
	for i in range(xs.size()):
		out.append(Vector2(xs[i], sm[i]))
	return out


## `passes` of a moving mean over +-`half` columns, the ends held.
static func _smooth(v: PackedFloat64Array, half: int, passes: int) -> PackedFloat64Array:
	var cur := v.duplicate()
	for _p in range(passes):
		var nxt := cur.duplicate()
		for i in range(cur.size()):
			var lo: int = maxi(0, i - half)
			var hi: int = mini(cur.size() - 1, i + half)
			# symmetric window so an end is not dragged
			var h: int = mini(i - lo, hi - i)
			var sum := 0.0
			for j in range(i - h, i + h + 1):
				sum += cur[j]
			nxt[i] = sum / float(2 * h + 1)
		cur = nxt
	return cur


## The shore-parallel curve: the shoreline pulled inland by `lead` along its
## normal (the vertical offset times sqrt(1 + slope^2)), then kept inside the
## bend rule.
static func _seed_street(shore: PackedVector2Array, lead: float) -> PackedFloat64Array:
	var n := shore.size()
	var ys := PackedFloat64Array()
	for i in range(n):
		var a: Vector2 = shore[maxi(i - 1, 0)]
		var b: Vector2 = shore[mini(i + 1, n - 1)]
		var m: float = (b.y - a.y) / maxf(b.x - a.x, 1e-6)
		ys.append(shore[i].y - lead * sqrt(1.0 + m * m))
	return limit_bend(ys, shore[1].x - shore[0].x)


## Smooth a street's offsets until no vertex turns more than TURN_MAX_DEG.
static func limit_bend(ys: PackedFloat64Array, dx: float) -> PackedFloat64Array:
	var cur := ys.duplicate()
	for _pass in range(120):
		var worst := 0.0
		var at := -1
		for i in range(1, cur.size() - 1):
			var a1: float = atan2(cur[i] - cur[i - 1], dx)
			var a2: float = atan2(cur[i + 1] - cur[i], dx)
			var turn: float = absf(rad_to_deg(a2 - a1))
			if turn > worst:
				worst = turn
				at = i
		if worst <= TURN_MAX_DEG:
			break
		var nxt := cur.duplicate()
		for i in range(1, cur.size() - 1):
			var a1: float = atan2(cur[i] - cur[i - 1], dx)
			var a2: float = atan2(cur[i + 1] - cur[i], dx)
			if absf(rad_to_deg(a2 - a1)) > TURN_MAX_DEG * 0.8:
				nxt[i] = 0.25 * cur[i - 1] + 0.5 * cur[i] + 0.25 * cur[i + 1]
		cur = nxt
	return cur


## The seed street routed by grade, within a band of the seed.
static func _route(ground: VillageTerrain, xs: PackedFloat64Array, seed: PackedFloat64Array,
		wl: float) -> PackedFloat64Array:
	var lo := INF
	var hi := -INF
	for y in seed:
		lo = minf(lo, y)
		hi = maxf(hi, y)
	lo -= SEAT_BAND_INLAND
	hi += SEAT_BAND_SEA
	var h := func(along: float, across: float) -> float: return ground.height_at(Vector2(along, across))
	var cap: float = float(VillageSitePlanner.ROAD_CLASSES[&"through"]["grade_max"])
	var routed := VillageRoadRouter.route_across(h, xs, seed, lo, hi, cap, ground.water_level_m)
	var out := PackedFloat64Array()
	for i in range(xs.size()):
		out.append(clampf(routed[i], seed[i] - SEAT_BAND_INLAND, seed[i] + SEAT_BAND_SEA))
	return limit_bend(out, xs[1] - xs[0])


## The common between the street and the bank where the street is flattest in
## the middle of the site, the approach path to it, and the landmark inland of
## it (the strand's own reservation).
static func _common_and_landmark(out: VillagePlan, spec: VillageSpec, street: PackedVector2Array) -> void:
	var n := street.size()
	var lo: int = int(floor(float(n) * 0.25))
	var hi: int = int(ceil(float(n) * 0.75))
	var best := clampi(n / 2, 1, n - 2)
	var best_cost := INF
	for i in range(maxi(lo, 1), mini(hi, n - 2) + 1):
		var m: float = absf((street[i + 1].y - street[i - 1].y) / (street[i + 1].x - street[i - 1].x))
		var cost: float = 10.0 * m + COMMON_W_BANK * _bank_trouble(out.ground, street[i], out.ground.water_level_m)
		cost += 0.002 * absf(street[i].x)      # ties go to the middle
		if cost < best_cost - 1e-9:
			best_cost = cost
			best = i
	var anchor: Vector2 = street[best]
	# the common's span must clear the street: lowest street y under it
	var low := anchor.y
	for p in street:
		if absf(p.x - anchor.x) <= 10.0:
			low = maxf(low, p.y)
	var common_y: float = low + ROAD_HALF_M + 0.5
	var common := Rect2(Vector2(anchor.x - 9.0, common_y), Vector2(18.0, 10.0))
	out.commons.append({"poly": Poly.from_rect(common), "kind": &"common"})
	out.roads.append(VillageSitePlanner._road(PackedVector2Array([anchor,
		common.get_center() - Vector2(0.0, 1.9)]), &"path", spec.wealth))
	var civic := Rect2(Vector2(common.position.x, anchor.y - 5.0), common.size)
	VillageSitePlanner._reserve_strand_landmark(out, spec, civic, out.site)


## The share of the bank either side of a street point that a house cannot
## stand on: the strip between the street and the shore, 26 m each way along
## it, wet or steeper than a house plot. The common's neighbours front it, so
## it stands where the bank is gentlest.
const COMMON_W_BANK := 6.0


static func _bank_trouble(ground: VillageTerrain, at: Vector2, level: float) -> float:
	var bad := 0
	var total := 0
	for dx in range(-26, 27, 4):
		for dy in [7.0, 12.0, 17.0]:
			var p := at + Vector2(float(dx), dy)
			total += 1
			if ground.height_at(p) <= level + VillageGroundWater.FREEBOARD_M \
					or ground.slope_at(p) > VillageSiteAnalysis.PLOT_MAX:
				bad += 1
	return float(bad) / float(maxi(total, 1))
