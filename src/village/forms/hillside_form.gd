class_name VillageHillsideForm
extends RefCounted
## `hillside`: a terraced village on a slope over a house plot's 17 %
## (VTER-FORM-HILLSIDE, docs/VILLAGE_TERRAIN.md "The hillside form").
##
## The ground derives this form at row 7 of the form rule: median dry slope
## 17 % or more, but not the scattered farming people row 6 sends to its
## hamlets. The real places are Rocamadour, Masouleh and the Amalfi villages:
## ways cut along the contour, one above the other, with houses one or two
## deep on each terrace, and stepped lanes dropping between them.
##
## The layout, in the planners' own frame (the through road west to east,
## which the siting turns onto the contour):
##
##   1. the site: wider along the contour than it is deep, so three terraces
##      and the ground above them fit. The lot planner's retries widen it
##      along the contour only (`site_scale`).
##   2. the through road, routed by grade like every form's, set toward the
##      uphill side of the site to leave the terrace band below it.
##   3. the common and the landmark on the UPHILL side of the road, so the
##      church stands over the village rather than under it.
##   4. TERRACES contour ways below the road, each routed by the same router
##      (`VillageSitePlanner._route_through`): on the 30 % plane they come out
##      within a degree of the contour and stay `street`; on a steeper real
##      hillside `grade_roads` re-classes them as it does every way.
##   5. two END RISERS, straight streets from the through road down to the
##      lowest terrace, each passing through the terrace ends. They lean off
##      the fall line (RISER_LEAN_DEG) so their grade is under a street's
##      30 % -- the road check's junction angle still holds (>= 30 degrees)
##      and `street_contour_share` keeps real, non-contour street length in
##      its denominator, as the survey's hillside villages have.
##   6. stepped CROSS-LANES between each pair of terraces, straight down the
##      fall line: on ground this steep a way between terraces is stairs, not
##      a path (the survey's `steps_ways`).
##   7. a field track off the lowest terrace at either end, out to the site
##      boundary (the way to the fields above, and a farm's own address).
##
## Two to four ways run along the contour (the through road and the three
## terraces), joined by stepped cross-lanes, with the houses one or two deep
## on each terrace -- the arrangement the survey's 33 contour-street and 37
## stair sites ask for.
##
## Pure: every draw comes from the same seeded stream as the other forms, and
## the spec is never written to. Without ground the form is still laid (the
## siting scores the flat plan): the fall line is +Y.

## The site: the flat planner's own square, grown into a band along the
## contour and deep enough for the terraces plus the ground above them.
const WIDTH_X := 1.70
const DEPTH_X := 1.25
const WIDTH_MIN_M := 220.0
const DEPTH_MIN_M := 164.0
## How much ground uphill of the through road the common and its gap and the
## landmark need.
const UPHILL_ROOM_M := 42.0

## Terrace bands below the through road, and the horizontal distance between
## them: at 30 % that is 9 m of height a terrace, 27 m from the top terrace
## to the lowest, inside the survey's steep-site elevation span. The pitch is
## also what a lot on one terrace needs behind it: a house and its back yard
## (and a farm, deeper still) were refused between terraces 20-25 m apart,
## and the cutter then put every house on the through road and the lowest
## terrace, splitting the survey's body.
const TERRACES := 3
const TERRACE_PITCH_M := 30.0

## The street riser at each end of the terrace band leans this far off the
## fall line. A riser of grade g on a slope s runs asin(g / s) off the
## contour, so at 18 degrees off the fall line it is 72 degrees off the
## contour: g = 0.30 * sin(72) = 28.5 %, under a street's 30 % -- and the
## lean costs the terraces less of their length than a steeper one would.
const RISER_LEAN_DEG := 18.0
const RISER_INSET_M := 8.0
## Clear of the riser at each end before a cross-lane may stand.
const CROSS_CLEAR_M := 14.0
## Where the cross-lanes stand across the terrace band, as a fraction of it.
const CROSS_SPOTS := [0.4, 0.6]
## Where the field tracks leave the lowest terrace.
const TRACK_SPOTS := [0.18, 0.82]
const TRACK_LEAN_DEG := 15.0
## A home's slot stays this far in from its terrace end, clear of the riser.
const SLOT_END_M := 18.0
const EDGE_INSET_M := 4.0
const SITE_MARGIN_M := 2.0


## The whole site plan of a hillside village. `extra_lanes` is ignored: the
## lot planner's retries buy ground along the contour (`site_scale`), and a
## lane off the through road would be one more way across the terraces.
static func plan(spec: VillageSpec, _extra_lanes := 0, site_scale := 1.0,
		ground: VillageTerrain = null, minimum_depth := 0.0) -> VillagePlan:
	var out := VillagePlan.new(spec)
	out.site = site_rect(spec, site_scale, minimum_depth)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("site|%d|%s" % [spec.seed, spec.form])
	if ground != null:
		out.ground = ground
		out.site_anchor = ground.site_anchor
		out.site_yaw = ground.site_yaw
	var down: float = _downhill(out.site, ground)
	var through: PackedVector2Array = VillageSitePlanner._through_road(out.site, spec, rng)
	# set the road toward the uphill side, leaving the terrace band below it
	var shift: float = -down * maxf(0.0, out.site.size.y * 0.5 - UPHILL_ROOM_M)
	for i in range(through.size()):
		through[i] = Vector2(through[i].x, through[i].y + shift)
	if ground != null:
		through = VillageSitePlanner._route_through(through, out.site, ground)
	out.roads.append(VillageSitePlanner._road(through, &"through", spec.wealth))

	# the common and the landmark stand uphill of the road
	var common := _common(out, spec, through, -down)
	out.commons.append({"poly": Poly.from_rect(common), "kind": &"common"})
	var join: Vector2 = through[VillageSitePlanner._vertex_near_x(through, common.get_center().x)]
	var walk: Vector2 = (common.get_center() - join).normalized()
	out.roads.append(VillageSitePlanner._road(
		PackedVector2Array([join, common.get_center() - walk * 1.9]), &"path", spec.wealth))
	_reserve_landmark(out, spec, common, -down)

	# the terraces, each routed along the contour by the one router
	var terraces: Array[PackedVector2Array] = []
	for k in range(1, TERRACES + 1):
		var seed := PackedVector2Array()
		var dy: float = down * TERRACE_PITCH_M * float(k)
		for p in through:
			seed.append(Vector2(p.x, p.y + dy))
		var line: PackedVector2Array = seed
		if ground != null:
			line = VillageSitePlanner._route_through(seed, out.site, ground)
		terraces.append(line)
	# The risers own the two ends. A terrace runs from where its end's riser
	# stands at its height, so trim it there and keep every road's index.
	var lean: float = tan(deg_to_rad(RISER_LEAN_DEG))
	var x_top_w: float = out.site.position.x + RISER_INSET_M
	var x_top_e: float = out.site.end.x - RISER_INSET_M
	var terrace_roads: Array[int] = []
	for k in range(terraces.size()):
		var x0: float = x_top_w + lean * absf(terraces[k][0].y - through[0].y)
		var x1: float = x_top_e - lean * absf(terraces[k][terraces[k].size() - 1].y - through[through.size() - 1].y)
		terraces[k] = _trim_x(terraces[k], x0, x1)
		terrace_roads.append(-1)
		if terraces[k].size() >= 2:
			terrace_roads[k] = out.roads.size()
			var road: Dictionary = VillageSitePlanner._road(terraces[k], &"street", spec.wealth)
			# the lot planner's own hook strings the households along these
			road["terrace"] = k
			out.roads.append(road)
	# the two end risers, through every terrace end on their way
	_riser(out, through, terraces, 0.0, x_top_w)
	_riser(out, through, terraces, 1.0, x_top_e)
	for k in range(terraces.size()):
		if terrace_roads[k] >= 0:
			out.roads[terrace_roads[k]]["points"] = terraces[k]

	# Stepped cross-lanes between the terraces, down the fall line. The same x
	# for every gap: a cross-lane and the one below it meet the terrace they
	# share at ONE junction, not two a metre or two apart.
	var cross_lo: float = -INF
	var cross_hi: float = INF
	for t in terraces:
		cross_lo = maxf(cross_lo, t[0].x + CROSS_CLEAR_M)
		cross_hi = minf(cross_hi, t[t.size() - 1].x - CROSS_CLEAR_M)
	for k in range(terraces.size() - 1):
		for f in CROSS_SPOTS:
			var upper: PackedVector2Array = terraces[k]
			var lower: PackedVector2Array = terraces[k + 1]
			var x: float = lerpf(cross_lo, cross_hi, float(f))
			var a: Vector2 = Vector2(x, VillageLotPlanner._polyline_y_at_x(upper, x))
			var b: Vector2 = Vector2(x, VillageLotPlanner._polyline_y_at_x(lower, x))
			if a.distance_to(b) < 4.0:
				continue
			terraces[k] = _insert_at_x(terraces[k], x)
			terraces[k + 1] = _insert_at_x(terraces[k + 1], x)
			out.roads[terrace_roads[k]]["points"] = terraces[k]
			out.roads[terrace_roads[k + 1]]["points"] = terraces[k + 1]
			out.roads.append(VillageSitePlanner._road(PackedVector2Array([a, b]), &"steps", spec.wealth))

	# way out to the fields above: tracks off the lowest terrace
	_field_tracks(out, terraces[terraces.size() - 1], down)
	var ground_shore := false
	if ground != null:
		VillageSitePlanner.grade_roads(out)
		ground_shore = VillageGroundWater.add(out)
	if spec.water != &"none" and not (ground_shore and spec.water in [&"coast", &"lake"]) \
			and not (ground_shore and spec.water in [&"river", &"stream"] and VillageGroundWater.has_river(out)):
		var water_plan: Dictionary = VillageWaterPlan.build(spec, out.site, out.roads, out.commons)
		for water in water_plan["water"]:
			out.water.append(water)
	out.water_crossings = VillageWaterPlan.crossings(out.water, out.roads)
	return out


## The site: the flat planner's square grown along the contour, deep enough
## for the terrace band and the ground above it.
static func site_rect(spec: VillageSpec, site_scale := 1.0, minimum_depth := 0.0) -> Rect2:
	var base: float = VillageSitePlanner.site_rect(spec).size.x
	var depth: float = clampf(maxf(base * DEPTH_X, minimum_depth), DEPTH_MIN_M,
		VillageSitePlanner.SITE_MAX_SIDE)
	var width: float = clampf(base * WIDTH_X, WIDTH_MIN_M, VillageSitePlanner.SITE_MAX_SIDE)
	if spec.requested_site_m > 0.0:
		width = minf(width, spec.requested_site_m)
	width = minf(width * maxf(site_scale, 1.0), VillageSitePlanner.SITE_MAX_SIDE)
	if spec.requested_site_m > 0.0:
		width = minf(width, spec.requested_site_m)
	return Rect2(Vector2(-width * 0.5, -depth * 0.5), Vector2(width, depth))


## Which way the ground falls across the frame: +1 when +Y is downhill. On
## flat ground the form's own convention is +1 (the fall line is +Y).
static func _downhill(site: Rect2, ground: VillageTerrain) -> float:
	if ground == null:
		return 1.0
	var c := site.get_center()
	var h_plus: float = ground.height_at(c + Vector2(0.0, 10.0))
	var h_minus: float = ground.height_at(c - Vector2(0.0, 10.0))
	return 1.0 if h_plus <= h_minus else -1.0


## A rectangle just off the road on `side` (+1 north, -1 south), `width` x
## `height`, centred on the road's vertex nearest the site's middle.
static func _common(out: VillagePlan, spec: VillageSpec, through: PackedVector2Array,
		side: float) -> Rect2:
	var site: Rect2 = out.site
	var small: bool = spec.population < VillageSitePlanner.HAMLET_POPULATION
	var target: float = VillageSitePlanner.HAMLET_COMMON_AREA if small \
		else VillageSitePlanner._common_area(spec, site)
	var width: float = VillageSitePlanner.WELL_PLOT_SIDE if small \
		else clampf(sqrt(target * 1.6), 12.0, site.size.x * 0.35)
	var height: float = VillageSitePlanner.WELL_PLOT_SIDE if small else maxf(target / width, 9.0)
	var mid: float = through[VillageSitePlanner._vertex_near_x(through, site.get_center().x)].x
	var left: float = mid - width * 0.5
	var right: float = mid + width * 0.5
	var road_edge: float = -INF if side > 0.0 else INF
	for p in through:
		if p.x >= left - 6.0 and p.x <= right + 6.0:
			road_edge = maxf(road_edge, p.y) if side > 0.0 else minf(road_edge, p.y)
	for edge_x in [left, right]:
		var y: float = VillageLotPlanner._polyline_y_at_x(through, edge_x)
		road_edge = maxf(road_edge, y) if side > 0.0 else minf(road_edge, y)
	if road_edge == -INF or road_edge == INF:
		road_edge = 0.0
	var half: float = float(VillageSitePlanner.ROAD_CLASSES[&"through"]["width"]) * 0.5 \
		+ float(VillageSitePlanner.ROAD_CLASSES[&"through"]["verge"])
	var bottom: float = road_edge + side * (half + VillageSitePlanner.COMMON_ROAD_GAP)
	var top: float = bottom + side * height
	var y0: float = minf(bottom, top)
	y0 = clampf(y0, site.position.y + SITE_MARGIN_M,
		site.end.y - SITE_MARGIN_M - height)
	return Rect2(Vector2(left, y0), Vector2(width, height))


## The landmark slot beyond the common on `side`, before any house lot.
static func _reserve_landmark(out: VillagePlan, spec: VillageSpec, common: Rect2,
		side: float) -> void:
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
	var width: float = clampf(sqrt(area * 1.1), 10.0, common.size.x + 8.0)
	var height: float = clampf(area / width, 8.0, maxf(common.size.y + 4.0, 8.0))
	var edge: float = common.end.y if side > 0.0 else common.position.y
	var bottom: float = edge + side * VillageSitePlanner.LANDMARK_GAP
	var y0: float = minf(bottom, bottom + side * height)
	var front := PackedVector2Array()
	if side > 0.0:
		front.append(Vector2(common.get_center().x - width * 0.5, y0))
		front.append(Vector2(common.get_center().x + width * 0.5, y0))
	else:
		front.append(Vector2(common.get_center().x - width * 0.5, y0 + height))
		front.append(Vector2(common.get_center().x + width * 0.5, y0 + height))
	out.landmark_site = {"poly": Poly.from_rect(Rect2(
		Vector2(common.get_center().x - width * 0.5, y0), Vector2(width, height))),
		"kind": kind, "front": front}


## A street from the through road down to the lowest terrace, through every
## terrace end, leaning inward by `lean` per metre of fall so its grade stays
## under a street's cap. `end` 0 is the west end, 1 the east.
static func _riser(out: VillagePlan, through: PackedVector2Array,
		terraces: Array[PackedVector2Array], end: float, x_top: float) -> void:
	if terraces.is_empty() or terraces[terraces.size() - 1].size() < 2:
		return
	var idx: int = VillageSitePlanner._vertex_near_x(through, x_top)
	var top: Vector2 = through[idx]
	var inward: float = 1.0 if end < 0.5 else -1.0
	var pts := PackedVector2Array([top])
	var lean: float = tan(deg_to_rad(RISER_LEAN_DEG))
	for k in range(terraces.size()):
		var t: PackedVector2Array = terraces[k]
		var e: int = 0 if end < 0.5 else t.size() - 1
		var p: Vector2 = t[e]
		var want_x: float = top.x + inward * lean * absf(p.y - top.y)
		want_x = clampf(want_x, out.site.position.x + EDGE_INSET_M, out.site.end.x - EDGE_INSET_M)
		t[e] = Vector2(want_x, p.y)
		terraces[k] = t
		pts.append(t[e])
	# a riser whose top and bottom are the same point has nowhere to go
	if pts.size() >= 2 and pts[0].distance_to(pts[pts.size() - 1]) >= 4.0:
		out.roads.append(VillageSitePlanner._road(pts, &"street", out.spec.wealth))


## The way out to the fields: two tracks off the lowest terrace, leaning off
## the fall line so a field track can climb at 30 %.
static func _field_tracks(out: VillagePlan, low: PackedVector2Array, down: float) -> void:
	if low.size() < 2:
		return
	for f in TRACK_SPOTS:
		var x: float = lerpf(low[0].x + CROSS_CLEAR_M, low[low.size() - 1].x - CROSS_CLEAR_M, float(f))
		var start := Vector2(x, VillageLotPlanner._polyline_y_at_x(low, x))
		var dir := Vector2(-tan(deg_to_rad(TRACK_LEAN_DEG)) * (1.0 if f < 0.5 else -1.0), down).normalized()
		var t := INF
		if dir.x > 1e-9:
			t = minf(t, (out.site.end.x - start.x) / dir.x)
		elif dir.x < -1e-9:
			t = minf(t, (out.site.position.x - start.x) / dir.x)
		if dir.y > 1e-9:
			t = minf(t, (out.site.end.y - start.y) / dir.y)
		elif dir.y < -1e-9:
			t = minf(t, (out.site.position.y - start.y) / dir.y)
		if not is_finite(t) or t < 8.0:
			continue
		var end: Vector2 = start + dir * t
		if VillageMeasure.on_boundary(out.site, end):
			out.roads.append(VillageSitePlanner._road(PackedVector2Array([start, end]),
				&"track", out.spec.wealth))


## `points` cut to the x range [x0, x1], with the crossing points
## interpolated; fewer than two points means the range misses it.
static func _trim_x(points: PackedVector2Array, x0: float, x1: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(points.size()):
		var p: Vector2 = points[i]
		if p.x >= x0 and p.x <= x1:
			out.append(p)
		if i + 1 < points.size():
			var q: Vector2 = points[i + 1]
			for edge_x: float in [x0, x1]:
				if (p.x - edge_x) * (q.x - edge_x) < 0.0:
					var t: float = (edge_x - p.x) / (q.x - p.x)
					out.append(Vector2(edge_x, lerpf(p.y, q.y, t)))
	# keep the polyline's order and drop points outside the range
	var kept := PackedVector2Array()
	for p in out:
		if p.x >= x0 - 1e-6 and p.x <= x1 + 1e-6:
			kept.append(p)
	return kept


## `points` with a vertex at x (split on its segment), returned.
static func _insert_at_x(points: PackedVector2Array, x: float) -> PackedVector2Array:
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		if (a.x - x) * (b.x - x) <= 0.0 and absf(b.x - a.x) > 1e-9:
			var t: float = (x - a.x) / (b.x - a.x)
			var p := Vector2(x, lerpf(a.y, b.y, t))
			if p.distance_to(a) <= 1e-6 or p.distance_to(b) <= 1e-6:
				return points
			var out := points.duplicate()
			out.insert(i + 1, p)
			return out
	return points


# -------------------------------------------------------------- the households

## The lot planner's hook (cut_measured): the households are distributed over
## the terraces, not all put on the through road. Left to itself the cutter
## fills the road nearest the common and the village stays a one-street row --
## the very thing this form exists to replace -- and its houses span one
## terrace instead of the whole hillside. Each home gets a slot on a level
## (the through road first, then each terrace), round robin, the biggest
## nearest the common (the wealth gradient), and is cut the lot nearest it.
static func assign_jobs(plan: VillagePlan, jobs: Array[Dictionary]) -> void:
	if plan.spec.form != &"hillside" or plan.roads.is_empty():
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
	var through: Array[int] = plan.roads_of_class(&"through")
	var levels: Array[int] = []
	if not through.is_empty():
		levels.append(through[0])
	for r in range(plan.roads.size()):
		if (plan.roads[r] as Dictionary).has("terrace"):
			levels.append(r)
	if levels.size() < 2:
		return
	var per: int = int(ceil(float(homes.size()) / float(levels.size())))
	for i in range(homes.size()):
		var r: int = levels[i % levels.size()]
		var pts: PackedVector2Array = plan.roads[r]["points"]
		var rank: int = i / levels.size()
		var t: float = 0.5 if per <= 1 else float(rank) / float(per - 1)
		var x: float = lerpf(pts[0].x + SLOT_END_M, pts[pts.size() - 1].x - SLOT_END_M, clampf(t, 0.0, 1.0))
		var y: float = VillageLotPlanner._polyline_y_at_x(pts, x)
		var side: float = 1.0 if (i / levels.size()) % 2 == 0 else -1.0
		homes[i]["near_point"] = Vector2(x, y + side * 10.0)
		homes[i]["siting"] = VillageLotPlanner.SITING_DEFAULT

