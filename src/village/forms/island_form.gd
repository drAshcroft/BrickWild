class_name VillageIslandForm
extends RefCounted
## The island case of `water` (VTER-ISLAND-FILL, docs/VILLAGE_TERRAIN.md "The
## island fill"): a village that IS its island -- Isola dei Pescatori, Mont-
## Saint-Michel's little cousins, every lake islet with a church on it. Houses
## stand edge to edge round a ring quay laid just inside the shore, a spine lane
## crosses the island between two landings, and the common and the church stand
## by the spine in the middle. Nothing is on piles and nothing needs a boat to
## reach but the island itself.
##
## The ground derives `water` for it (VillageSpec row 0: an ENCLOSED island, one
## the grid shows wholly inside its water, whose area the programme can fill).
## The layout, in the planners' frame -- the island's pole (the dry point
## farthest from any water) is the origin and the island's long axis is +x
## (`site` chooses both):
##
##   1. THE SHORE: the first water along each of BEARINGS bearings from the
##      pole, minimum-filtered and smoothed (`shore_radii`). The island is read
##      as a star about its pole; an island with a bay cut in it is read
##      without the bay's far side, which only makes the village smaller.
##   2. THE RING QUAY: a closed street at QUAY_INSET m inside the shore, scaled
##      inward (never past SCALE_MIN) until its frontage and the spine's are no
##      more than CAPACITY times what the programme needs (`fit_scale`): a
##      small village on a big island keeps its houses together, a village the
##      island only just holds is built to the edge. Houses stand on its inner
##      side, and on its outer side where the scaled ring leaves ground.
##   3. THE SPINE: the through road, along the long axis from a landing on the
##      shore, across the ring at its two vertices, to a landing on the other.
##      The walk enters at the landings (`VillageMeasure.gates`).
##   4. THE COMMON: a disc beside the spine at the middle, joined to it by a
##      path; the landmark's slot across the spine.
##
## `plan.shoreline` carries the closed shore (the island's own outline).
## Where the island is too big for the programme (more than FILL_FACTOR times
## what it needs) or too small to hold it, the ground is not an island village:
## the shore and water forms answer as before. Pure: the same spec on the same
## ground is the same plan.

## The lattice the island is found on, and how far from the caller's centre
## its pole may lie.
const LATTICE_M := 8.0
const REACH_M := 320.0
## An island smaller than this is a rock, not a village.
const MIN_AREA_M2 := 1500.0
## The centroid is the frame's origin when it is at least this share of the pole's
## distance from the shore.
const POLE_CENTROID := 0.85
## What the programme needs of ground: a building and the lane share with it,
## and the common and the church's yard once.
const AREA_PER_BUILDING := 300.0
const CIVIC_M2 := 600.0
## The island the programme fills: area within [FILL_MIN, FILL_MAX] times what
## it needs. Under FILL_MIN it cannot hold the programme (piles are the answer),
## over FILL_MAX the village would float inland of its own quay.
const FILL_MIN := 0.7
const FILL_MAX := 4.0
## The shore's bearings, and the shore scan.
const BEARINGS := 48
const SCAN_STEP_M := 1.0
const SCAN_MAX_M := 360.0
const WET_RUN_M := 3.0
## The ring quay's centreline, inside the shore: the street's half width and
## verge, the bank, and a metre for the shore's own uncertainty.
const QUAY_INSET := 4.5
const RING_MIN_R := 26.0
const SCALE_MIN := 0.3
## Frontage a building takes on a street (width and its gap), and how much more
## frontage than that the ring and the spine should offer.
const LOT_FRONT_M := 13.0
const CAPACITY := 1.6
## An arc is this many bearings of the ring (one road each).
const ARC_BEARINGS := 6
const COMMON_RADIUS := 9.0
const SITE_MARGIN := 8.0
## The landings stop this short of the water's edge.
const LANDING_SHORT_M := 0.0
const SPINE_STEP_M := 10.0
## The ring's tightest curve: the road check's 25 degrees in 20 m is a 45.8 m radius.
const BEND_R := 47.5
## The worst vertex the ring may keep: the road check allows 25 (+ 0.5).
const BEND_OK := 25.3
const CACHE_MAX := 16

## Off, the water form answers for an island as it did before the island fill
## (the tests' control: the same ground without the form).
static var enabled := true

static var _described := {}
static var _sited := {}
static var _order: Array[String] = []


# ================================================================ the island

## The island nearest the caller's centre that the grid shows wholly inside its
## water: {"area_m2", "pole" (a point of the caller's grid), "yaw" (the long
## axis), "a", "b" (the equivalent ellipse's semi-axes), "centroid", "bounds"}.
## {} when there is none, or the ground has no water level.
static func describe(t: VillageTerrain) -> Dictionary:
	if t == null or not t.valid() or is_nan(t.water_level_m):
		return {}
	var key := t.fingerprint()
	if _described.has(key):
		return _described[key]
	var out := _describe(t)
	_described[key] = out
	_order.append("d" + key)
	_trim()
	return out


static func _describe(t: VillageTerrain) -> Dictionary:
	var box := t.bounds()
	var wl: float = t.water_level_m + VillageGroundWater.FREEBOARD_M
	var cols: int = int(floor(box.size.x / LATTICE_M))
	var rows: int = int(floor(box.size.y / LATTICE_M))
	if cols < 4 or rows < 4:
		return {}
	var dry := PackedByteArray()
	dry.resize(cols * rows)
	for j in range(rows):
		for i in range(cols):
			var p := box.position + (Vector2(i, j) + Vector2(0.5, 0.5)) * LATTICE_M
			dry[j * cols + i] = 1 if t.height_at(p) > wl else 0
	var seen := PackedByteArray()
	seen.resize(cols * rows)
	var best := {}
	var best_d := INF
	for start in range(cols * rows):
		if dry[start] == 0 or seen[start] != 0:
			continue
		var cells: Array[int] = []
		var queue: Array[int] = [start]
		seen[start] = 1
		var enclosed := true
		while not queue.is_empty():
			var c: int = queue.pop_back()
			cells.append(c)
			var ci: int = c % cols
			var cj: int = c / cols
			if ci == 0 or cj == 0 or ci == cols - 1 or cj == rows - 1:
				enclosed = false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ni: int = ci + d.x
				var nj: int = cj + d.y
				if ni < 0 or nj < 0 or ni >= cols or nj >= rows:
					continue
				var n: int = nj * cols + ni
				if dry[n] != 0 and seen[n] == 0:
					seen[n] = 1
					queue.append(n)
		if not enclosed or float(cells.size()) * LATTICE_M * LATTICE_M < MIN_AREA_M2:
			continue
		var centroid := Vector2.ZERO
		for c in cells:
			centroid += box.position + (Vector2(c % cols, c / cols) + Vector2(0.5, 0.5)) * LATTICE_M
		centroid /= float(cells.size())
		if centroid.length() > REACH_M or centroid.length() >= best_d:
			continue
		best_d = centroid.length()
		best = {"cells": cells, "centroid": centroid}
	if best.is_empty():
		return {}
	var members: Array = best["cells"]
	var centroid: Vector2 = best["centroid"]
	# the long axis and the equivalent ellipse
	var sxx := 0.0
	var syy := 0.0
	var sxy := 0.0
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var edge: Array[Vector2] = []
	for c in members:
		var p := box.position + (Vector2(int(c) % cols, int(c) / cols) + Vector2(0.5, 0.5)) * LATTICE_M
		var d := p - centroid
		sxx += d.x * d.x
		syy += d.y * d.y
		sxy += d.x * d.y
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
		var ci: int = int(c) % cols
		var cj: int = int(c) / cols
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if dry[(cj + dd.y) * cols + ci + dd.x] == 0:
				edge.append(p)
				break
	var n := float(members.size())
	sxx /= n
	syy /= n
	sxy /= n
	var angle: float = 0.5 * atan2(2.0 * sxy, sxx - syy)
	var half_diff: float = sqrt(maxf(0.25 * (sxx - syy) * (sxx - syy) + sxy * sxy, 0.0))
	var l1: float = 0.5 * (sxx + syy) + half_diff
	var l2: float = maxf(0.5 * (sxx + syy) - half_diff, 1.0)
	# the pole: the dry cell farthest from the shore; but where the centroid is
	# nearly as far, the centroid -- an elongated island has a whole row of
	# cells as far as each other, and the frame should sit in the middle of it
	var pole := centroid
	var pole_d := -1.0
	var centroid_d := INF
	for e in edge:
		centroid_d = minf(centroid_d, centroid.distance_squared_to(e))
	for c in members:
		var p := box.position + (Vector2(int(c) % cols, int(c) / cols) + Vector2(0.5, 0.5)) * LATTICE_M
		var nearest := INF
		for e in edge:
			nearest = minf(nearest, p.distance_squared_to(e))
		if nearest > pole_d + 1e-9:
			pole_d = nearest
			pole = p
	if t.height_at(centroid) > wl and centroid_d >= POLE_CENTROID * POLE_CENTROID * pole_d:
		pole = centroid
		pole_d = maxf(pole_d, centroid_d)
	var bounds := Rect2(lo - Vector2.ONE * LATTICE_M * 0.5, hi - lo + Vector2.ONE * LATTICE_M)
	if not box.grow(-(SITE_MARGIN + LATTICE_M)).encloses(bounds):
		return {}
	return {"area_m2": n * LATTICE_M * LATTICE_M, "pole": pole, "yaw": fposmod(angle, TAU),
		"a": 2.0 * sqrt(l1), "b": 2.0 * sqrt(l2), "centroid": centroid, "bounds": bounds,
		"inscribed_m": sqrt(maxf(pole_d, 0.0)) + LATTICE_M * 0.5}


static func _trim() -> void:
	while _order.size() > CACHE_MAX:
		var key: String = _order.pop_front()
		if key.begins_with("d"):
			_described.erase(key.substr(1))
		else:
			_sited.erase(key.substr(1))


static func clear_cache() -> void:
	_described.clear()
	_sited.clear()
	_order.clear()


## Buildings a spec of `households` asks of its ground (the programme is not
## derived yet when the form is): a household each, the trades and the civic
## buildings.
static func buildings_for(households: int) -> int:
	return households + 4 + households / 5


## The ground a village of `households` needs, in m2.
static func needed_m2(households: int) -> float:
	return float(buildings_for(households)) * AREA_PER_BUILDING + CIVIC_M2


## Whether this ground, for a village of `households`, is an island village's.
static func fits_ground(t: VillageTerrain, households: int) -> bool:
	if not enabled:
		return false
	var d := describe(t)
	if d.is_empty():
		return false
	var ratio: float = float(d["area_m2"]) / needed_m2(households)
	# a ring of the bend rule's radius has to fit inside the quay's inset
	return ratio >= FILL_MIN and ratio <= FILL_MAX and float(d["inscribed_m"]) >= QUAY_INSET + BEND_R


static func fits(spec: VillageSpec) -> bool:
	return enabled and spec != null and spec.terrain != null and fits_ground(spec.terrain, spec.households)


# ================================================================== the siting

## The frame for an island village (the shape VillageShoreForm.site answers
## in): the anchor is the island's pole, the yaw its long axis.
static func site(spec: VillageSpec) -> Dictionary:
	var t: VillageTerrain = spec.terrain
	var d := describe(t)
	var key := "%s|%d" % [t.fingerprint(), spec.households]
	if _sited.has(key):
		return _sited[key]
	var w: float = VillageSitePlanner.SITE_MAX_SIDE * 0.5 + VillageSiting.VIEW_PAD_M
	var out := {"anchor": d["pole"], "yaw": d["yaw"], "score": 0.0, "terms": {}, "shore": true,
		"fixed_centre": false}
	out["ground"] = t.sited_view(d["pole"], d["yaw"], Rect2(-w, -w, 2.0 * w, 2.0 * w),
		minf(t.cell_m, VillageSiting.VIEW_CELL_MAX))
	_sited[key] = out
	_order.append("s" + key)
	_trim()
	return out


# ===================================================================== the plan

## The whole site plan of the island village on `ground` (the frame `site`
## chose). `site_scale` above 1 asks for more frontage (the lot planner's
## retries), which the ring buys by moving toward the shore.
static func plan(spec: VillageSpec, _extra_lanes := 0, site_scale := 1.0, _minimum_depth := 0.0,
		_shore_depth := 0.0, ground: VillageTerrain = null) -> VillagePlan:
	var out := VillagePlan.new(spec)
	out.ground = ground
	out.site_anchor = ground.site_anchor
	out.site_yaw = ground.site_yaw
	var wl: float = ground.water_level_m + VillageGroundWater.FREEBOARD_M
	var shore := shore_radii(ground, wl)
	if shore.is_empty():
		return out
	var outline := PackedVector2Array()
	var box_lo := Vector2(INF, INF)
	var box_hi := Vector2(-INF, -INF)
	for k in range(BEARINGS):
		var p := Vector2.from_angle(bearing(k)) * shore[k]
		outline.append(p)
		box_lo = Vector2(minf(box_lo.x, p.x), minf(box_lo.y, p.y))
		box_hi = Vector2(maxf(box_hi.x, p.x), maxf(box_hi.y, p.y))
	out.shoreline = outline
	var margin := SITE_MARGIN + VillageGroundWater.FREEBOARD_M
	# The site ends at the two landings (the island's ends touch its short sides),
	# so the ground's water falls in two pieces, north and south, and not one
	# ring round the island: VillageGroundWater.polygons drops the hole of a ring
	# and would read the island as lake.
	var x_lo: float = minf(box_lo.x, -shore[BEARINGS / 2])
	var x_hi: float = maxf(box_hi.x, shore[0])
	out.site = Rect2(Vector2(x_lo, box_lo.y - margin), Vector2(x_hi - x_lo, box_hi.y - box_lo.y + 2.0 * margin))
	var need: float = float(buildings_for(spec.households)) * LOT_FRONT_M * CAPACITY * maxf(site_scale, 1.0)
	var sx: float = fit_scale(shore, need)
	var all := ring_points(shore, sx)
	if all.is_empty():
		return VillagePlan.new(spec)
	var step: int = 2 if _perimeter(all, 1) / float(BEARINGS) < 8.0 else 1
	var ring := PackedVector2Array()
	for k in range(0, BEARINGS, step):
		ring.append(all[k])
	var n := ring.size()
	# --- the spine (the through road), landing to landing along x
	var west: float = shore[BEARINGS / 2] - LANDING_SHORT_M
	var east: float = shore[0] - LANDING_SHORT_M
	var x0: float = all[BEARINGS / 2].x
	var x1: float = all[0].x
	var spine := PackedVector2Array()
	spine.append(Vector2(-west, 0.0))
	spine.append(Vector2(x0, 0.0))
	var x := x0
	while x + SPINE_STEP_M * 1.5 < 0.0:
		x += SPINE_STEP_M
		spine.append(Vector2(x, 0.0))
	spine.append(Vector2(0.0, 0.0))
	x = 0.0
	while x + SPINE_STEP_M * 1.5 < x1:
		x += SPINE_STEP_M
		spine.append(Vector2(x, 0.0))
	spine.append(Vector2(x1, 0.0))
	spine.append(Vector2(east, 0.0))
	out.roads.append(VillageSitePlanner._road(spine, &"through", spec.wealth))
	# --- the ring, in arcs of ARC_BEARINGS bearings each
	var per_arc: int = maxi(1, ARC_BEARINGS / step)
	var arcs: int = maxi(1, n / per_arc)
	for a in range(arcs):
		var k0: int = a * n / arcs
		var k1: int = (a + 1) * n / arcs
		var pts := PackedVector2Array()
		for k in range(k0, k1 + 1):
			pts.append(ring[k % n])
		out.roads.append(VillageSitePlanner._road(pts, &"street", spec.wealth))
	# --- the common beside the spine, and the path to it
	var half: float = float(VillageSitePlanner.ROAD_CLASSES[&"through"]["width"]) * 0.5 \
		+ float(VillageSitePlanner.ROAD_CLASSES[&"through"]["verge"])
	var centre := Vector2(0.0, -(half + COMMON_RADIUS + 1.0))
	out.commons.append({"poly": VillageSitePlanner._circle_polygon(centre, COMMON_RADIUS, 16), "kind": &"common"})
	out.roads.append(VillageSitePlanner._road(PackedVector2Array([Vector2.ZERO, centre + Vector2(0.0, 1.9)]),
		&"path", spec.wealth))
	_reserve_landmark(out, spec, half)
	out.island = {"area_m2": float(describe(spec.terrain).get("area_m2", 0.0)), "ring_scale": sx,
		"landings": PackedVector2Array([spine[0], spine[spine.size() - 1]])}
	VillageSitePlanner.grade_roads(out)
	VillageGroundWater.add(out)
	out.water_crossings = VillageWaterPlan.crossings(out.water, out.roads)
	return out


## The bearing of the k-th sample, k = 0 along +x.
static func bearing(k: int) -> float:
	return TAU * float(k) / float(BEARINGS)


## The distance from the pole to the water along each bearing: the last dry
## metre before WET_RUN_M of water, minimum-filtered over three bearings and
## smoothed. Empty when the pole is wet or a bearing never finds water.
static func shore_radii(ground: VillageTerrain, wl: float) -> PackedFloat64Array:
	var raw := PackedFloat64Array()
	for k in range(BEARINGS):
		var dir := Vector2.from_angle(bearing(k))
		var last_dry := -1.0
		var wet_run := 0.0
		var found := false
		var r := 0.0
		while r <= SCAN_MAX_M:
			if ground.height_at(dir * r) <= wl:
				wet_run += SCAN_STEP_M
				if wet_run >= WET_RUN_M:
					found = true
					break
			else:
				last_dry = r
				wet_run = 0.0
			r += SCAN_STEP_M
		if not found or last_dry < 0.0:
			return PackedFloat64Array()
		raw.append(last_dry)
	# a light smoothing (a bay's far side is read as a bay's depth): never past
	# the raw scan, and the two landings' bearings are the scan itself
	var low := raw.duplicate()
	for _pass in range(2):
		var nxt := low.duplicate()
		for k in range(BEARINGS):
			nxt[k] = minf(low[k], 0.25 * low[(k + BEARINGS - 1) % BEARINGS] + 0.5 * low[k] + 0.25 * low[(k + 1) % BEARINGS])
		low = nxt
	low[0] = raw[0]
	low[BEARINGS / 2] = raw[BEARINGS / 2]
	return low


## The ring's vertices at scale `sx`: the shore pulled in by QUAY_INSET, its x
## drawn in by `sx` toward the spine's middle (only the long axis is shortened:
## the island's width is what the rows of houses between the ring and the spine
## need, its length is what a small village does not), then OPENED by BEND_R --
## shrunk by it and grown back, which leaves every curve of the ring at that
## radius or wider, the road check's bend rule. A pointed end of an island is
## cut off by a round one a street can take; nothing is pushed out of the shore.
## BEARINGS vertices, the first on the spine's east landing side and the one
## half way round on its west side (both at y = 0); empty when the island is
## narrower than the opening.
static func ring_points(shore: PackedFloat64Array, sx: float) -> PackedVector2Array:
	var cand := PackedVector2Array()
	for k in range(BEARINGS):
		var edge: float = shore[k] - QUAY_INSET
		var p := Vector2.from_angle(bearing(k)) * maxf(edge, 1.0)
		cand.append(Vector2(p.x * sx, p.y))
	# the widest opening that leaves a ring inside the bend rule, then the narrower
	for radius in [BEND_R + 3.0, BEND_R + 2.0, BEND_R + 1.0, BEND_R, BEND_R - 1.0]:
		var ring := _opened(cand, radius)
		if not ring.is_empty() and _worst_bend(ring) <= BEND_OK:
			return ring
	return PackedVector2Array()


## `cand` opened by `radius` (shrunk and grown back), resampled and smoothed;
## empty when nothing is left or it is not crossed by the spine's line.
static func _opened(cand: PackedVector2Array, radius: float) -> PackedVector2Array:
	var shrunk: Array[PackedVector2Array] = Geometry2D.offset_polygon(cand, -radius, Geometry2D.JOIN_ROUND)
	var best := PackedVector2Array()
	var best_area := 0.0
	for piece in shrunk:
		if Geometry2D.is_polygon_clockwise(piece):
			continue
		for grown in Geometry2D.offset_polygon(piece, radius, Geometry2D.JOIN_ROUND):
			var area: float = absf(Poly.area(grown))
			if not Geometry2D.is_polygon_clockwise(grown) and area > best_area:
				best_area = area
				best = grown
	if best.size() < 3:
		return PackedVector2Array()
	var ring := _resampled(best)
	if ring.is_empty():
		return ring
	# the arcs the offset draws are uneven by a vertex here and there: a light
	# smoothing, the two spine vertices kept on it (y = 0)
	for _pass in range(3):
		var nxt := ring.duplicate()
		for i in range(BEARINGS):
			var smooth: Vector2 = 0.25 * ring[(i + BEARINGS - 1) % BEARINGS] + 0.5 * ring[i] + 0.25 * ring[(i + 1) % BEARINGS]
			nxt[i] = Vector2(smooth.x, 0.0) if i == 0 or i == BEARINGS / 2 else smooth
		ring = nxt
	return ring


## The sharpest vertex of the closed ring by the road check's measure: degrees
## turned per 20 m, over the mean of its two segments.
static func _worst_bend(ring: PackedVector2Array) -> float:
	var n := ring.size()
	var worst := 0.0
	for i in range(n):
		var a: Vector2 = ring[(i + n - 1) % n]
		var b: Vector2 = ring[i]
		var c: Vector2 = ring[(i + 1) % n]
		var run: float = (b.distance_to(a) + b.distance_to(c)) * 0.5
		worst = maxf(worst, rad_to_deg(absf((b - a).angle_to(c - b))) * 20.0 / maxf(run, 0.01))
	return worst


## `poly` as BEARINGS vertices evenly spaced along it, with vertex 0 where it
## crosses y = 0 on the east and vertex BEARINGS / 2 where it crosses on the
## west. Empty when it does not cross both.
static func _resampled(poly: PackedVector2Array) -> PackedVector2Array:
	var n := poly.size()
	var east := Vector2(-INF, 0.0)
	var west := Vector2(INF, 0.0)
	var east_at := -1
	var west_at := -1
	for i in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		if (a.y <= 0.0) == (b.y <= 0.0):
			continue
		var x: float = a.x + (b.x - a.x) * (0.0 - a.y) / (b.y - a.y)
		if x > east.x:
			east = Vector2(x, 0.0)
			east_at = i
		if x < west.x:
			west = Vector2(x, 0.0)
			west_at = i
	if east_at < 0 or west_at < 0 or east_at == west_at:
		return PackedVector2Array()
	# the closed outline from the east crossing, round to the west one and back
	var path := PackedVector2Array([east])
	var i := (east_at + 1) % n
	while i != (west_at + 1) % n:
		path.append(poly[i])
		i = (i + 1) % n
	path.append(west)
	var half := path.size()
	while i != (east_at + 1) % n:
		path.append(poly[i])
		i = (i + 1) % n
	path.append(east)
	var out := PackedVector2Array()
	var cut: int = half - 1
	var first := PackedVector2Array(path.slice(0, half))
	var second := PackedVector2Array(path.slice(cut))
	var h: int = BEARINGS / 2
	for k in range(h):
		out.append(_along(first, float(k) / float(h)))
	for k in range(h):
		out.append(_along(second, float(k) / float(h)))
	return out


## The point a fraction `t` of the way along the polyline.
static func _along(pts: PackedVector2Array, t: float) -> Vector2:
	var total := 0.0
	for i in range(pts.size() - 1):
		total += pts[i].distance_to(pts[i + 1])
	var want := total * t
	var run := 0.0
	for i in range(pts.size() - 1):
		var seg: float = pts[i].distance_to(pts[i + 1])
		if run + seg >= want - 1e-9:
			return pts[i].lerp(pts[i + 1], (want - run) / maxf(seg, 1e-9))
		run += seg
	return pts[pts.size() - 1]


## The ring's length and the spine's two arms inside it, in metres of frontage
## that a house may stand on one side of.
static func frontage(ring: PackedVector2Array) -> float:
	if ring.size() < BEARINGS:
		return 0.0
	return _perimeter(ring, 1) + 2.0 * (ring[0].x - ring[BEARINGS / 2].x) - 4.0 * COMMON_RADIUS


static func _perimeter(ring: PackedVector2Array, step: int) -> float:
	var sum := 0.0
	for k in range(0, BEARINGS, step):
		sum += ring[k].distance_to(ring[(k + step) % BEARINGS])
	return sum


## The smallest x scale whose frontage reaches `need`; 1.0 when none does.
static func fit_scale(shore: PackedFloat64Array, need: float) -> float:
	if frontage(ring_points(shore, 1.0)) <= need:
		return 1.0
	var lo := SCALE_MIN
	var hi := 1.0
	if frontage(ring_points(shore, lo)) >= need:
		return lo
	for _i in range(24):
		var mid := 0.5 * (lo + hi)
		if frontage(ring_points(shore, mid)) >= need:
			hi = mid
		else:
			lo = mid
	return hi


## The landmark's slot across the spine from the common.
static func _reserve_landmark(out: VillagePlan, spec: VillageSpec, half: float) -> void:
	var kinds: Array = []
	for row in spec.programme:
		kinds.append(row["kind"])
	var kind: StringName = &"shrine"
	var area: float = VillageSitePlanner.LANDMARK_AREA_SMALL
	if &"temple" in kinds:
		kind = &"temple"
		area = VillageSitePlanner.LANDMARK_AREA
	elif &"church" in kinds:
		kind = &"church"
		area = VillageSitePlanner.LANDMARK_AREA
	var width: float = clampf(sqrt(area * 1.1), 10.0, 2.0 * COMMON_RADIUS + 8.0)
	var height: float = clampf(area / width, 8.0, 20.0)
	var rect := Rect2(Vector2(-width * 0.5, half + VillageSitePlanner.LANDMARK_GAP), Vector2(width, height))
	out.landmark_site = VillageSitePlanner._landmark_dict(rect, kind, false)
