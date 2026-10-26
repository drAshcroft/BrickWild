class_name VillageDispersedForm
extends RefCounted
## `dispersed`: several hamlets on the best level shelves of a hillside,
## each with its own well, linked to the through road by tracks laid by
## grade; the shared landmark stands in the central hamlet on the through
## road, and fields lie on the gentle ground between (VTER-FORM-DISPERSED,
## docs/VILLAGE_TERRAIN.md "The dispersed form").
##
## The ground derives this form at row 6 of the form rule (a farming or
## forest people on a hillside whose median dry slope is 17 % or more, under
## 150 people or with three separate level shelves). Ushguli, Batad, the hill
## farms of Uganda: hamlets two to five hundred metres apart, not one nucleus.
##
## The layout, in the planners' own frame (through road west to east):
##
##   1. the site: wider than a nucleated village's, sized by its hamlet count
##   2. the through road, routed by grade as every form's is
##   3. the MAIN hamlet on the through road, where the ground beside the
##      road is gentlest near the middle: a common north of the road, a ring
##      street round it, the landmark behind the ring -- the street form's
##      core, at its own x. The most central hamlet gets the landmark.
##   4. the other hamlets on the best shelves of the site (the share of
##      gentle, dry ground within SEAT_RADIUS_M), at least HAMLET_SEP_M from
##      each other and from the main one; each on a SPINE, a track from the
##      through road through the hamlet and out to the site edge (a way to
##      the fields above), graded: over 30 % it is steps. Each has its own
##      small common with a well beside the spine and a path to the well.
##   5. households split across the hamlets in proportion to each one's
##      shelf area, at least QUOTA_MIN each (`assign_jobs`, called by the lot
##      planner: every household is cut a lot nearest its own hamlet's well)
##   6. fields on gentle ground along the spines beyond the hamlets
##      (`finish`), and a well on every hamlet's common (`dress_hamlets`).
##
## `plan.hamlets` carries the hamlets: {"seat": Vector2 (the common's
## centre), "common": int (index into plan.commons), "spine": int (road index,
## -1 for the main hamlet), "households": int (the quota), "shelf": float
## (gentle ground within SEAT_RADIUS_M, m^2), "main": bool, "ground":
## PackedVector2Array (the hamlet's own ground, HAMLET_GROUND_M square about
## its seat, clipped to the site -- what ScaleCheck's density is measured
## over: the settlement is its hamlets, not the fields between them)}.
##
## Pure: every draw comes from the same seeded stream as the other forms, and
## the spec is never written to.

const HAMLETS_MIN := 2
const HAMLETS_MAX := 5
## One hamlet per this many households: Ushguli's four hamlets hold about
## twenty households between them.
const HOUSEHOLDS_PER_HAMLET := 4.5
## Every hamlet houses at least this many households.
const QUOTA_MIN := 3
## And one hamlet beside the main one at least this many, where there are
## households enough: a hamlet is a cluster of five buildings or more in the
## survey's own terms (VillageShape clusters_ge5).
const QUOTA_SECOND := 5
## Seats this far apart: two hamlets' houses, each within about 25 m of its
## well, stay further apart than the survey's 45 m linkage.
const HAMLET_SEP_M := 160.0
## A link passes no hamlet's seat nearer than this: its houses would string along it.
const HAMLET_PASS_M := 45.0
## The link track (VTER-DISPERSED-2): routed from the through road to the
## seat at the track's own grade cap, trying a foot every LINK_FOOT_STEP_M
## along the road within LINK_FOOT_REACH_M of the seat's x, across a band of
## LINK_BAND_M either side of the straight line.
const LINK_FOOT_STEP_M := 20.0
const LINK_FOOT_REACH_M := 200.0
const LINK_BAND_M := 70.0
const LINK_MIN_M := 40.0
## The ring's two joins to the through road are at least this long (junctions 8 m apart fail the road check).
const RING_JOIN_MIN_M := 9.0
## A foot keeps this far from the end of any other road (the junction spacing is 8 m).
const LINK_JUNCTION_CLEAR_M := 14.0
const HAMLET_GROUND_M := 90.0
const SEAT_RADIUS_M := 30.0
## A seat whose ground is on average steeper than a house plot
## (VillageSiteAnalysis.PLOT_MAX, 35 %) is no shelf: 1 - 0.35 / SHELF_ZERO.
const SEAT_SHELF_MIN := 0.42
const SEAT_STEP_M := 10.0
const SEAT_MARGIN_M := 40.0
## A seat nearer the through road than this stands on it: its spine leaves
## the road square and the hamlet's common goes this far along it.
const SEAT_ON_ROAD_M := 30.0
const SEAT_ROAD_STEP_M := 22.0
const EDGE_INSET_M := 0.25
const SPINE_VERTEX_M := 30.0
## The hamlet's common: a well plot, 14 m square, so every house that does
## not stand on it is at least 7 m from the well (WELL_CLEAR is 6).
const COMMON_SIDE := 14.0
const COMMON_GAP := 0.5
const ANALYSIS_CELL_M := 10.0
const FIELD_SIZE := Vector2(22.0, 16.0)
const FIELD_GENTLE := 0.15
const FIELD_PASTURE := 0.30
const FIELD_CLEAR := 3.0
const FIELD_FROM_SEAT_M := 40.0
const SITE_BASE_M := 230.0
const SITE_PER_HAMLET_M := 40.0
const SITE_MIN_M := 320.0
const SITE_MAX_M := 400.0


## The whole site plan of a dispersed village. `extra_lanes` is ignored: the
## lot planner's retries buy ground (`site_scale`), and a back lane off the
## through road would be frontage in no hamlet.
static func plan(spec: VillageSpec, _extra_lanes := 0, site_scale := 1.0,
		ground: VillageTerrain = null) -> VillagePlan:
	var out := VillagePlan.new(spec)
	out.site = site_rect(spec, site_scale)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("site|%d|%s" % [spec.seed, spec.form])
	if ground != null:
		out.ground = ground
		out.site_anchor = ground.site_anchor
		out.site_yaw = ground.site_yaw
	var through: PackedVector2Array = VillageSitePlanner._through_road(out.site, spec, rng)
	if ground != null:
		through = VillageSitePlanner._route_through(through, out.site, ground)
	out.roads.append(VillageSitePlanner._road(through, &"through", spec.wealth))
	var a: VillageSiteAnalysis = null
	if ground != null:
		a = VillageSiteAnalysis.of(ground, out.site, ANALYSIS_CELL_M)
		if not a.valid():
			a = null
	var main := _main_hamlet(out, spec, through, _main_x(out, through, a))
	out.hamlets.append({"seat": main["seat"], "common": 0, "spine": -1, "households": 0,
		"shelf": _shelf(a, main["seat"]), "main": true})
	var want: int = hamlet_count(spec)
	# the shelves first; then, if the ground has fewer than two, the least
	# steep ground there is -- a dispersed village is never one hamlet
	for strict in [true, false]:
		var enough: int = want if strict else HAMLETS_MIN
		for seat in _seat_candidates(out, a, strict):
			if out.hamlets.size() >= enough:
				break
			var h := _secondary_hamlet(out, spec, through, seat, a)
			if not h.is_empty():
				out.hamlets.append(h)
	for h in out.hamlets:
		h["ground"] = _hamlet_ground(out.site, h["seat"])
	_quotas(out, spec)
	var ground_shore := false
	if ground != null:
		VillageSitePlanner.grade_roads(out)
		# the ground's own lake or sea as plan water, roads cut back to its
		# shore (VTER-LOTS), as VillageSitePlanner._plan does
		var spines: Array = []
		for h in out.hamlets:
			spines.append(out.roads[int(h["spine"])] if int(h["spine"]) >= 0 and int(h["spine"]) < out.roads.size() else null)
		ground_shore = VillageGroundWater.add(out)
		# a spine cut back or taken up at the shore keeps its hamlet's index right
		for k in range(out.hamlets.size()):
			if spines[k] != null:
				out.hamlets[k]["spine"] = out.roads.find(spines[k])
	if spec.water != &"none" and not (ground_shore and spec.water in [&"coast", &"lake"]) \
			and not (ground_shore and spec.water in [&"river", &"stream"] and VillageGroundWater.has_river(out)):
		var water_plan: Dictionary = VillageWaterPlan.build(spec, out.site, out.roads, out.commons)
		for water in water_plan["water"]:
			out.water.append(water)
	out.water_crossings = VillageWaterPlan.crossings(out.water, out.roads)
	return out


## Hamlets for this many households, before the ground has its say.
static func hamlet_count(spec: VillageSpec) -> int:
	var n: int = int(round(float(spec.households) / HOUSEHOLDS_PER_HAMLET))
	n = mini(n, maxi(1, spec.households / QUOTA_MIN))
	return clampi(n, HAMLETS_MIN, HAMLETS_MAX)


## A square sized by the hamlet count, within the caller's envelope, grown
## along the road by the lot planner's retries.
static func site_rect(spec: VillageSpec, site_scale := 1.0) -> Rect2:
	var side: float = clampf(SITE_BASE_M + SITE_PER_HAMLET_M * hamlet_count(spec), SITE_MIN_M, SITE_MAX_M)
	if spec.requested_site_m > 0.0:
		side = minf(side, spec.requested_site_m)
	side = minf(side, VillageSitePlanner.SITE_MAX_SIDE)
	var w: float = minf(side * maxf(site_scale, 1.0), VillageSitePlanner.SITE_MAX_SIDE)
	if spec.requested_site_m > 0.0:
		w = minf(w, spec.requested_site_m)
	return Rect2(Vector2(-w * 0.5, -side * 0.5), Vector2(w, side))


# ---------------------------------------------------------- the main hamlet

## Where along the through road the main hamlet stands: the vertex in the
## middle half of the road whose ground just north of it (the common, the
## ring and the landmark) is gentlest, and nearest the middle on a tie.
static func _main_x(out: VillagePlan, through: PackedVector2Array, a: VillageSiteAnalysis) -> float:
	var site: Rect2 = out.site
	var best_x: float = 0.0
	var best := INF
	for i in range(1, through.size() - 1):
		var p: Vector2 = through[i]
		var t: float = (p.x - site.position.x) / site.size.x
		if t < 0.3 or t > 0.7:
			continue
		var cost: float = 0.1 * absf(p.x - site.get_center().x) / (site.size.x * 0.5)
		if a != null:
			var sum := 0.0
			var n := 0
			for dy in [8.0, 18.0, 28.0, 38.0]:
				for dx in [-12.0, 0.0, 12.0]:
					var q: Vector2 = p + Vector2(dx, dy)
					var s: float = a.slope_at(q)
					if is_nan(s):
						continue
					sum += s + (1.0 if a.wet_at(q) else 0.0)
					n += 1
			cost += sum / maxf(n, 1)
		if cost < best - 1e-9:
			best = cost
			best_x = p.x
	return best_x


## The street form's core at `x`: the common north of the through road with
## its approach path, the ring street round it where the ground has room,
## and the landmark slot behind the ring. {"seat": the common's centre}
static func _main_hamlet(out: VillagePlan, spec: VillageSpec, through: PackedVector2Array,
		x: float) -> Dictionary:
	var site: Rect2 = out.site
	var small: bool = spec.population < VillageSitePlanner.HAMLET_POPULATION
	var target: float = VillageSitePlanner.HAMLET_COMMON_AREA if small \
		else VillageSitePlanner._common_area(spec, site)
	var width: float = VillageSitePlanner.WELL_PLOT_SIDE if small \
		else clampf(sqrt(target * 1.6), 12.0, site.size.x * 0.35)
	var height: float = VillageSitePlanner.WELL_PLOT_SIDE if small else maxf(target / width, 9.0)
	# the common on a real vertex, so the approach path runs straight in
	var mid: float = through[VillageSitePlanner._vertex_near_x(through, x)].x
	var rect: Rect2 = VillageSitePlanner._rect_north_of(through, out.roads[0], mid, width, height,
		VillageSitePlanner.COMMON_ROAD_GAP)
	out.commons.append({"poly": Poly.from_rect(rect), "kind": &"common"})
	var join: Vector2 = through[VillageSitePlanner._vertex_near_x(through, mid)]
	var walk: Vector2 = (rect.get_center() - join).normalized()
	out.roads.append(VillageSitePlanner._road(PackedVector2Array([join, rect.get_center() - walk * 1.9]),
		&"path", spec.wealth))
	var ring_y: float = _ring(out, spec, through, rect)
	var behind: float = -INF if ring_y == -INF \
		else ring_y + VillageSitePlanner._ring_half() + VillageSitePlanner.LANDMARK_GAP
	VillageSitePlanner._reserve_landmark(out, spec, rect, site, behind)
	return {"seat": rect.get_center()}


## The street form's ring round the far side of the common (VillageSitePlanner
## ._ring_street, with the street form's circumradius: a rectangular common
## reaches its corners). Returns the far side's y, or -INF when there is no
## room for the ring and the landmark behind it.
static func _ring(out: VillagePlan, spec: VillageSpec, through: PackedVector2Array,
		common: Rect2) -> float:
	var site: Rect2 = out.site
	var clear: float = VillageSitePlanner._ring_half() + VillageSitePlanner.COMMON_ROAD_GAP
	var centre := common.get_center()
	var radius: float = common.size.length() * 0.5
	var arc_radius: float = (radius + clear) / cos(PI / 8.0)
	var far_y: float = centre.y + arc_radius
	if 2.0 * arc_radius * sin(PI / 8.0) < VillageSitePlanner.JUNCTION_MIN_SPACING_M:
		return -INF
	if far_y + VillageSitePlanner._ring_half() + VillageSitePlanner.LANDMARK_GAP \
			+ VillageSitePlanner.RING_LANDMARK_DEPTH > site.end.y - VillageSitePlanner.SITE_MARGIN_M:
		return -INF
	var ia: int = VillageSitePlanner._vertex_outside_x(through, common.position.x - clear, -1.0)
	var ib: int = VillageSitePlanner._vertex_outside_x(through, common.end.x + clear, 1.0)
	if ia < 0 or ib < 0 or ib - ia < 1:
		return -INF
	var west := centre + Vector2(-arc_radius, 0.0)
	var east := centre + Vector2(arc_radius, 0.0)
	# a join shorter than the junction spacing would put two junctions closer
	# than the road check allows (the ring's first bend, the through road):
	# take the next vertex out along the road
	var tries := 0
	while through[ia].distance_to(west) < RING_JOIN_MIN_M and tries < 6:
		ia = VillageSitePlanner._vertex_outside_x(through, through[ia].x - 1.0, -1.0)
		tries += 1
		if ia < 0:
			return -INF
	tries = 0
	while through[ib].distance_to(east) < RING_JOIN_MIN_M and tries < 6:
		ib = VillageSitePlanner._vertex_outside_x(through, through[ib].x + 1.0, 1.0)
		tries += 1
		if ib < 0:
			return -INF
	if west.x < site.position.x + VillageSitePlanner.SITE_MARGIN_M \
			or east.x > site.end.x - VillageSitePlanner.SITE_MARGIN_M:
		return -INF
	var arc := PackedVector2Array()
	for i in range(5):
		var angle: float = PI - PI * float(i) / 4.0
		arc.append(centre + Vector2(cos(angle), sin(angle)) * arc_radius)
	out.roads.append(VillageSitePlanner._road(PackedVector2Array([through[ia], west]), &"street", spec.wealth))
	for i in range(arc.size() - 1):
		out.roads.append(VillageSitePlanner._road(PackedVector2Array([arc[i], arc[i + 1]]), &"street", spec.wealth))
	out.roads.append(VillageSitePlanner._road(PackedVector2Array([east, through[ib]]), &"street", spec.wealth))
	return far_y


# ------------------------------------------------------ the other hamlets

## How much of a shelf the ground within SEAT_RADIUS_M of `p` is, as an
## area in m^2: each dry cell counts 1 when level, falling linearly to 0 at
## SHELF_ZERO (a footpath's grade), wet ground 0. The whole disc on flat
## ground. Relative, not a threshold: on a uniform 30 % hillside every seat is
## half a shelf and the middle wins; on a valley the floor does.
const SHELF_ZERO := 0.60
static func _shelf(a: VillageSiteAnalysis, p: Vector2) -> float:
	var disc: float = PI * SEAT_RADIUS_M * SEAT_RADIUS_M
	if a == null:
		return disc
	var n := 0
	var good := 0.0
	var r := int(SEAT_RADIUS_M / ANALYSIS_CELL_M)
	for j in range(-r, r + 1):
		for i in range(-r, r + 1):
			var off := Vector2(i, j) * ANALYSIS_CELL_M
			if off.length() > SEAT_RADIUS_M + 0.01:
				continue
			var s: float = a.slope_at(p + off)
			if is_nan(s):
				continue
			n += 1
			if not a.wet_at(p + off):
				good += clampf(1.0 - s / SHELF_ZERO, 0.0, 1.0)
	return disc * good / maxf(n, 1)


## Every lattice point that could seat a hamlet, best first: the most gentle
## ground round it, then nearest the middle (a hamlet the others can reach),
## then lattice order. Points too near the main hamlet are left out here;
## the rest of the spacing is the caller's, as seats are taken.
static func _seat_candidates(out: VillagePlan, a: VillageSiteAnalysis, strict := true) -> Array:
	var inner: Rect2 = out.site.grow(-SEAT_MARGIN_M)
	var main: Vector2 = out.hamlets[0]["seat"]
	var disc: float = PI * SEAT_RADIUS_M * SEAT_RADIUS_M
	var half: float = out.site.size.length() * 0.5
	var cands: Array = []
	var ny := int(floor(inner.size.y / SEAT_STEP_M))
	var nx := int(floor(inner.size.x / SEAT_STEP_M))
	for j in range(ny + 1):
		for i in range(nx + 1):
			var p := inner.position + Vector2(i, j) * SEAT_STEP_M
			if p.distance_to(main) < HAMLET_SEP_M:
				continue
			var shelf: float = _shelf(a, p)
			if strict and shelf < SEAT_SHELF_MIN * disc:
				continue
			var score: float = shelf / disc - 0.25 * p.length() / half
			cands.append({"p": p, "score": score, "k": j * (nx + 1) + i})
	cands.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if not is_equal_approx(float(x["score"]), float(y["score"])):
			return float(x["score"]) > float(y["score"])
		return int(x["k"]) < int(y["k"]))
	var pts: Array[Vector2] = []
	for c in cands:
		pts.append(c["p"])
	return pts


## A hamlet at `seat`: its spine from the through road through the seat and
## out to the edge, its common beside the spine, a path to the well. {} when
## the seat cannot be served -- too near another hamlet, a spine that would
## cross the main hamlet or another spine, a common on a road.
static func _secondary_hamlet(out: VillagePlan, spec: VillageSpec, through: PackedVector2Array,
		seat: Vector2, a: VillageSiteAnalysis) -> Dictionary:
	var site: Rect2 = out.site
	var linked := _link_hamlet(out, spec, through, seat, a)
	if not linked.is_empty():
		return linked
	# No cart track reaches the seat: the straight way up the fall line,
	# which is a stair where it is steep (steps only where nothing else reaches).
	# The spine leaves the through road square to the frame, at the seat's
	# own x: the road runs along the frame's X (on a hillside, the contour),
	# so the spine is the way straight up or down the slope -- a stair where
	# it is steep -- and it meets the site edge square, where a footway that
	# met it obliquely would have no clear width in its last metre. Its foot
	# is a point on the road, not a vertex: a T on the carriageway.
	var v := Vector2(seat.x, VillageLotPlanner._polyline_y_at_x(through, seat.x))
	var side: float = 1.0 if seat.y >= v.y else -1.0
	var dir := Vector2(0.0, side)
	var along: float = absf(seat.y - v.y)
	if along < SEAT_ON_ROAD_M:
		along = SEAT_ROAD_STEP_M
	var end: Vector2 = _ray_to_edge(v, dir, site)
	if v.distance_to(end) < along + 25.0:
		return {}
	var on_spine: Vector2 = v + dir * along
	# the spine's vertices: the road, the hamlet, then every SPINE_VERTEX_M
	# to the edge -- collinear, so no bend, and a vertex every field can touch
	var pts := PackedVector2Array([v, on_spine])
	var d: float = along + SPINE_VERTEX_M
	while d < v.distance_to(end) - SPINE_VERTEX_M * 0.5:
		pts.append(v + dir * d)
		d += SPINE_VERTEX_M
	pts.append(end)
	# the common beside the spine, on whichever side is gentler
	var n := Vector2(-dir.y, dir.x)
	var off: float = float(VillageSitePlanner.ROAD_CLASSES[&"track"]["width"]) * 0.5 + COMMON_GAP + COMMON_SIDE * 0.5
	var sides: Array[float] = [1.0, -1.0]
	if a != null:
		var s1: float = a.slope_at(on_spine + n * off)
		var s2: float = a.slope_at(on_spine - n * off)
		if not is_nan(s1) and not is_nan(s2) and s2 < s1:
			sides = [-1.0, 1.0]
	var spine_ribbon: PackedVector2Array = Poly.ribbon(pts, float(VillageSitePlanner.ROAD_CLASSES[&"track"]["width"]) * 0.5 + 1.0)
	if _blocked(out, spine_ribbon, pts, true):
		return {}
	for s in sides:
		var cc: Vector2 = on_spine + n * s * off
		if not out.site.grow(-VillageSitePlanner.SITE_MARGIN_M - COMMON_SIDE).has_point(cc):
			continue
		var ok := true
		for h in out.hamlets:
			if cc.distance_to(h["seat"]) < HAMLET_SEP_M:
				ok = false
		if not ok:
			continue
		var poly := _square(cc, dir, COMMON_SIDE)
		if _blocked(out, poly, PackedVector2Array(), false):
			continue
		var spine := VillageSitePlanner._road(pts, &"track", spec.wealth)
		if out.ground != null and VillageRoadRouter.grade_of(out.ground, pts) \
				> float(VillageSitePlanner.ROAD_CLASSES[&"track"]["grade_max"]) + 1e-6:
			# a way too steep to lead a mule up is a stair, from the start:
			# grade_roads would otherwise straighten a re-classed track
			spine = VillageSitePlanner._road(pts, &"steps", spec.wealth)
		out.roads.append(spine)
		var spine_index: int = out.roads.size() - 1
		out.commons.append({"poly": poly, "kind": &"common"})
		var walk: Vector2 = (cc - on_spine).normalized()
		out.roads.append(VillageSitePlanner._road(PackedVector2Array([on_spine, cc - walk * 1.9]),
			&"path", spec.wealth))
		return {"seat": cc, "common": out.commons.size() - 1, "spine": spine_index,
			"households": 0, "shelf": _shelf(a, cc), "main": false}
	return {}


## The hamlet at `seat` joined to the through road by a track that follows the
## ground (VTER-DISPERSED-2): `VillageRoadRouter.route_across` in the frame of
## the line from a foot on the road to the seat, both ends pinned, laid at the
## track's own grade cap; of the feet tried, the shortest track whose measured
## grade is within the cap and that crosses nothing. The common stands beside
## the track's last metres. {} when no foot gives a track (the caller falls
## back to a stair up the fall line), or without ground.
static func _link_hamlet(out: VillagePlan, spec: VillageSpec, through: PackedVector2Array,
		seat: Vector2, a: VillageSiteAnalysis) -> Dictionary:
	if out.ground == null:
		return {}
	var cap: float = float(VillageSitePlanner.ROAD_CLASSES[&"track"]["grade_max"])
	var width: float = float(VillageSitePlanner.ROAD_CLASSES[&"track"]["width"])
	var best := PackedVector2Array()
	var best_len := INF
	var inner: Rect2 = out.site.grow(-VillageSitePlanner.SITE_MARGIN_M - width)
	# the feet, nearest the seat first: a track is never shorter than its chord,
	# so the search stops at the first foot whose chord passes the best track
	var feet: Array[Vector2] = []
	var k := -int(LINK_FOOT_REACH_M / LINK_FOOT_STEP_M)
	while k <= int(LINK_FOOT_REACH_M / LINK_FOOT_STEP_M):
		var fx: float = seat.x + k * LINK_FOOT_STEP_M
		k += 1
		if fx < inner.position.x or fx > inner.end.x:
			continue
		var foot := Vector2(fx, VillageLotPlanner._polyline_y_at_x(through, fx))
		if foot.distance_to(seat) >= LINK_MIN_M and not _near_junction(out, foot):
			feet.append(foot)
	feet.sort_custom(func(p: Vector2, q: Vector2) -> bool:
		var dp: float = p.distance_to(seat)
		var dq: float = q.distance_to(seat)
		if not is_equal_approx(dp, dq):
			return dp < dq
		return p.x < q.x)
	for foot in feet:
		if foot.distance_to(seat) >= best_len:
			break
		var pts: PackedVector2Array = _route_link(out.ground, foot, seat, inner, cap)
		if pts.size() < 2:
			continue
		var length := 0.0
		for i in range(pts.size() - 1):
			length += pts[i].distance_to(pts[i + 1])
		if length >= best_len - 1e-9:
			continue
		if VillageRoadRouter.grade_of(out.ground, pts) > cap + 1e-6:
			continue
		if _blocked(out, Poly.ribbon(pts, width * 0.5 + 1.0), pts, true):
			continue
		best = pts
		best_len = length
	if best.is_empty():
		return {}
	var last: Vector2 = best[best.size() - 1]
	var dir: Vector2 = (last - best[best.size() - 2]).normalized()
	var n := Vector2(-dir.y, dir.x)
	var off: float = width * 0.5 + COMMON_GAP + COMMON_SIDE * 0.5
	var sides: Array[float] = [1.0, -1.0]
	if a != null:
		var s1: float = a.slope_at(last + n * off)
		var s2: float = a.slope_at(last - n * off)
		if not is_nan(s1) and not is_nan(s2) and s2 < s1:
			sides = [-1.0, 1.0]
	for s in sides:
		var cc: Vector2 = last + n * s * off
		# the hamlet's ground is whole inside the site (a farm is measured to its edge)
		if not out.site.grow(-HAMLET_GROUND_M * 0.5 + 2.0).has_point(cc):
			continue
		var apart := true
		for h in out.hamlets:
			if cc.distance_to(h["seat"]) < HAMLET_SEP_M:
				apart = false
		if not apart:
			continue
		var poly := _square(cc, dir, COMMON_SIDE)
		if _blocked(out, poly, PackedVector2Array(), false):
			continue
		out.roads.append(VillageSitePlanner._road(best, &"track", spec.wealth))
		var spine_index: int = out.roads.size() - 1
		out.commons.append({"poly": poly, "kind": &"common"})
		var walk: Vector2 = (cc - last).normalized()
		out.roads.append(VillageSitePlanner._road(PackedVector2Array([last, cc - walk * 1.9]),
			&"path", spec.wealth))
		return {"seat": cc, "common": out.commons.size() - 1, "spine": spine_index,
			"households": 0, "shelf": _shelf(a, cc), "main": false}
	return {}


## Whether `p` lies within the junction spacing of any end of a road already
## planned, or of a bend of the through road: a foot there would make a second
## junction too near the first.
static func _near_junction(out: VillagePlan, p: Vector2) -> bool:
	for r in range(1, out.roads.size()):
		var pts: PackedVector2Array = out.roads[r]["points"]
		if pts[0].distance_to(p) < LINK_JUNCTION_CLEAR_M or pts[pts.size() - 1].distance_to(p) < LINK_JUNCTION_CLEAR_M:
			return true
	return false


## The least-cost line from `from` to `to` at grade `cap`, in the frame whose
## axis is the straight line between them; both ends fixed. Empty when the
## ends are too near for a column or the band leaves `inner`.
static func _route_link(ground: VillageTerrain, from: Vector2, to: Vector2, inner: Rect2,
		cap: float) -> PackedVector2Array:
	var total: float = from.distance_to(to)
	var cols := int(round(total / VillageRoadRouter.COLUMN_M)) + 1
	if cols < 3:
		return PackedVector2Array()
	var u: Vector2 = (to - from) / total
	var v := Vector2(-u.y, u.x)
	var xs := PackedFloat64Array()
	var seed := PackedFloat64Array()
	for i in range(cols):
		xs.append(total * float(i) / float(cols - 1))
		seed.append(0.0)
	var h := func(along: float, across: float) -> float:
		return ground.height_at(from + u * along + v * across)
	var offs := VillageRoadRouter.route_across(h, xs, seed, -LINK_BAND_M, LINK_BAND_M, cap,
		ground.water_level_m, 0, 0.0, 1.0, true)
	var out := PackedVector2Array()
	for i in range(cols):
		var p: Vector2 = from + u * xs[i] + v * offs[i]
		if i > 0 and i < cols - 1 and not inner.has_point(p):
			return PackedVector2Array()
		out.append(p)
	out[0] = from
	out[cols - 1] = to
	return out


## Whether `poly` (a spine's ribbon, or a common) would stand on what is
## already planned: a common, the landmark slot, a road other than the
## through road (`spine` true: the spine's own first metres leave the
## through road and are allowed to touch it), or another hamlet's ground.
static func _blocked(out: VillagePlan, poly: PackedVector2Array, line: PackedVector2Array,
		spine: bool) -> bool:
	for c in out.commons:
		if VillageLotPlanner.overlap_area(poly, Poly.offset(c["poly"], 2.0)) > 0.05:
			return true
	if out.landmark_reserved() and VillageLotPlanner.overlap_area(poly,
			Poly.offset(out.landmark_site["poly"], 2.0)) > 0.05:
		return true
	for r in range(out.roads.size()):
		var road: Dictionary = out.roads[r]
		if spine and r == 0:
			continue
		var rib: PackedVector2Array = VillageSitePlanner.road_ribbon(road, true)
		if not spine:
			if r == 0:
				rib = Poly.ribbon(road["points"], float(road["width"]) * 0.5 + float(road["verge"]) + 1.0)
			if VillageLotPlanner.overlap_area(poly, rib) > 0.05:
				return true
			continue
		# a spine may not cross or touch another way at all
		var pts: PackedVector2Array = road["points"]
		for i in range(line.size() - 1):
			for k in range(pts.size() - 1):
				if Geometry2D.segment_intersects_segment(line[i], line[i + 1], pts[k], pts[k + 1]) != null:
					return true
		if VillageLotPlanner.overlap_area(poly, rib) > 0.05:
			return true
	if spine:
		# nor pass through another hamlet: its houses would string along it
		for h in out.hamlets:
			if VillageMeasure.point_to_polyline(h["seat"], line) < HAMLET_PASS_M:
				return true
	return false


## Where a ray from inside the site leaves it.
static func _ray_to_edge(from: Vector2, dir: Vector2, site: Rect2) -> Vector2:
	var t := INF
	if dir.x > 1e-9:
		t = minf(t, (site.end.x - from.x) / dir.x)
	elif dir.x < -1e-9:
		t = minf(t, (site.position.x - from.x) / dir.x)
	if dir.y > 1e-9:
		t = minf(t, (site.end.y - from.y) / dir.y)
	elif dir.y < -1e-9:
		t = minf(t, (site.position.y - from.y) / dir.y)
	var p: Vector2 = from + dir * t
	# a quarter metre inside the far edges: the walk grid covers [position,
	# end), so a stair ending exactly on the north edge measured no clear
	# width in its last sample; still on the boundary for the road check
	return Vector2(clampf(p.x, site.position.x, site.end.x - EDGE_INSET_M),
		clampf(p.y, site.position.y, site.end.y - EDGE_INSET_M))


## A square of `side` about `c`, one pair of sides along `dir`.
static func _square(c: Vector2, dir: Vector2, side: float) -> PackedVector2Array:
	var u: Vector2 = dir * side * 0.5
	var w := Vector2(-dir.y, dir.x) * side * 0.5
	return PackedVector2Array([c - u - w, c + u - w, c + u + w, c - u + w])


static func _hamlet_ground(site: Rect2, seat: Vector2) -> PackedVector2Array:
	var r := Rect2(seat - Vector2.ONE * HAMLET_GROUND_M * 0.5, Vector2.ONE * HAMLET_GROUND_M)
	return Poly.from_rect(r.intersection(site))


# ---------------------------------------------------------- the households

## Households per hamlet, in proportion to each one's shelf, at least
## QUOTA_MIN each; and where there are households enough, one hamlet beside
## the main one with QUOTA_SECOND, so the village reads as more than one
## cluster and not as a nucleus with a few farms round it.
static func _quotas(out: VillagePlan, spec: VillageSpec) -> void:
	var hs: Array[Dictionary] = out.hamlets
	var total: int = spec.households
	var n: int = hs.size()
	var weight := 0.0
	for h in hs:
		weight += maxf(float(h["shelf"]), 1.0)
	var floor_q: int = mini(QUOTA_MIN, total / maxi(n, 1))
	var given := 0
	var frac: Array = []
	for i in range(n):
		var want: float = float(total) * maxf(float(hs[i]["shelf"]), 1.0) / weight
		var q: int = maxi(floor_q, int(floor(want)))
		hs[i]["households"] = q
		given += q
		frac.append([want - floor(want), i])
	frac.sort_custom(func(x: Array, y: Array) -> bool:
		if not is_equal_approx(float(x[0]), float(y[0])):
			return float(x[0]) > float(y[0])
		return int(x[1]) < int(y[1]))
	var k := 0
	while given < total and n > 0:
		hs[int(frac[k % n][1])]["households"] += 1
		given += 1
		k += 1
	# too many (every floor raised): take back from the largest
	while given > total:
		var big := 0
		for i in range(n):
			if int(hs[i]["households"]) > int(hs[big]["households"]):
				big = i
		if int(hs[big]["households"]) <= floor_q:
			break
		hs[big]["households"] -= 1
		given -= 1
	if n >= 2:
		var second := 1
		for i in range(1, n):
			if int(hs[i]["households"]) > int(hs[second]["households"]):
				second = i
		while int(hs[second]["households"]) < QUOTA_SECOND:
			var donor := -1
			for i in range(n):
				if i != second and int(hs[i]["households"]) > floor_q \
						and (donor < 0 or int(hs[i]["households"]) > int(hs[donor]["households"])):
					donor = i
			if donor < 0:
				break
			hs[donor]["households"] -= 1
			hs[second]["households"] += 1


## The lot planner's hook (cut_measured): each household to a hamlet, by
## the quotas, biggest house first round the hamlets so each hamlet has its
## own large and small houses; each is cut its lot nearest its own hamlet's
## well, on any road. The trades keep their own addresses (VILLAGES §6: the
## smithy at the edge, the tavern by a gate) and the landmark its slot.
static func assign_jobs(plan: VillagePlan, jobs: Array[Dictionary]) -> void:
	if plan.hamlets.is_empty():
		return
	var homes: Array[Dictionary] = []
	for job in jobs:
		if job["class"] in [&"cottage", &"townhouse", &"farm"]:
			homes.append(job)
	homes.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var ax: float = VillageLotPlanner._floor_area(x)
		var ay: float = VillageLotPlanner._floor_area(y)
		if absf(ax - ay) > 0.01:
			return ax > ay
		return int(x["order"]) < int(y["order"]))
	var given: Array[int] = []
	for _h in plan.hamlets:
		given.append(0)
	for job in homes:
		var pick := 0
		var room := -INF
		for i in range(plan.hamlets.size()):
			var quota: int = maxi(int(plan.hamlets[i]["households"]), 1)
			var left: float = float(quota - given[i]) / float(quota)
			if left > room + 1e-9:
				room = left
				pick = i
		given[pick] += 1
		job["hamlet"] = pick
		job["near_point"] = plan.hamlets[pick]["seat"]
		job["siting"] = VillageLotPlanner.SITING_DEFAULT


## The road index of hamlet `i`'s spine, found by its geometry (the lot
## planner adds and drops service lanes after the site plan, so a stored
## index can go stale): the track or stair passing beside the hamlet's
## common. -1 for the main hamlet, which stands on the through road.
static func spine_of(plan: VillagePlan, i: int) -> int:
	if i < 0 or i >= plan.hamlets.size() or bool(plan.hamlets[i]["main"]):
		return -1
	var seat: Vector2 = plan.hamlets[i]["seat"]
	var reach: float = float(VillageSitePlanner.ROAD_CLASSES[&"track"]["width"]) * 0.5 \
		+ COMMON_GAP + COMMON_SIDE * 0.5 + 0.5
	for r in range(plan.roads.size()):
		if plan.roads[r]["class"] in [&"track", &"steps"] \
				and VillageMeasure.point_to_polyline(seat, plan.roads[r]["points"]) <= reach:
			return r
	return -1


## The hamlet a point belongs to: the one whose seat is nearest.
static func hamlet_of(plan: VillagePlan, p: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in range(plan.hamlets.size()):
		var d: float = p.distance_to(plan.hamlets[i]["seat"])
		if d < best_d:
			best_d = d
			best = i
	return best


# ---------------------------------------------------------- fields and wells

## The lot planner's hook before dressing: fields on the gentle ground along
## each spine beyond its hamlet, clear of everything planned, each touching
## its track. Strip fields where the ground is gentle, pasture where it is
## not; nothing on ground steeper than FIELD_PASTURE.
static func finish(plan: VillagePlan) -> void:
	if plan.hamlets.is_empty():
		return
	var blockers: Array[PackedVector2Array] = []
	for lot in plan.lots:
		blockers.append(lot["poly"])
	for road in plan.roads:
		blockers.append(VillageSitePlanner.road_ribbon(road, true))
	for c in plan.commons:
		blockers.append(c["poly"])
	for w in plan.water:
		blockers.append(w["poly"])
	for b in plan.buildings:
		blockers.append(VillageMeasure.bounds_poly(b))
	if plan.landmark_reserved():
		blockers.append(plan.landmark_site["poly"])
	var t: VillageTerrain = plan.terrain()
	for i in range(plan.hamlets.size()):
		var h: Dictionary = plan.hamlets[i]
		var spine: int = spine_of(plan, i)
		if spine < 0:
			continue
		var road: Dictionary = plan.roads[spine]
		if road["class"] != &"track":
			continue
		var pts: PackedVector2Array = road["points"]
		var off: float = float(road["width"]) * 0.5 + FIELD_CLEAR + FIELD_SIZE.y * 0.5
		for k in range(1, pts.size() - 1):
			if pts[k].distance_to(h["seat"]) < FIELD_FROM_SEAT_M:
				continue
			# a winding link: the field lies along the track here, not along its chord
			var dir: Vector2 = (pts[k + 1] - pts[k - 1]).normalized()
			var n := Vector2(-dir.y, dir.x)
			for s in [1.0, -1.0]:
				var c: Vector2 = pts[k] + n * s * off
				var poly := _rect_along(c, dir, FIELD_SIZE)
				if not _inside(plan.site, poly):
					continue
				var slope := 0.0
				if t != null:
					var u: Dictionary = t.under(poly)
					slope = float(u["slope_mean"])
					if float(u["dry_share"]) < 1.0:
						continue
				if slope > FIELD_PASTURE:
					continue
				var clear := true
				for bl in blockers:
					if VillageLotPlanner.overlap_area(Poly.offset(poly, FIELD_CLEAR), bl) > 0.05:
						clear = false
						break
				if not clear:
					continue
				plan.fields.append({"poly": poly, "kind": &"field" if slope <= FIELD_GENTLE else &"pasture"})
				blockers.append(poly)


## The lot planner's hook after dressing: a well on every hamlet's common
## but the main one (the dresser's own common recipe put that one), placed by
## the same recipe step and the same rules as the main well.
static func dress_hamlets(plan: VillagePlan) -> void:
	if plan.hamlets.size() < 2 or plan.buildings.is_empty():
		return
	var well_step: Dictionary = {}
	for step in VillageDressCatalog.RECIPES[&"common"]:
		if String(step["cat"]) == "well":
			well_step = step
			break
	if well_step.is_empty():
		return
	var ctx: Dictionary = VillageDressContext.make_context(plan)
	for i in range(plan.hamlets.size()):
		var h: Dictionary = plan.hamlets[i]
		if bool(h["main"]):
			continue
		ctx["common"] = plan.commons[int(h["common"])]["poly"]
		var rng := VillageDressPlacement.rng(plan, "hamlet|%d" % i)
		VillageDressRules.apply(plan, ctx, well_step, rng, -1, &"common")


static func _rect_along(c: Vector2, dir: Vector2, size: Vector2) -> PackedVector2Array:
	var u: Vector2 = dir * size.x * 0.5
	var w := Vector2(-dir.y, dir.x) * size.y * 0.5
	return PackedVector2Array([c - u - w, c + u - w, c + u + w, c - u + w])


static func _inside(site: Rect2, poly: PackedVector2Array) -> bool:
	var r: Rect2 = site.grow(-VillageSitePlanner.SITE_MARGIN_M)
	for p in poly:
		if not r.has_point(p):
			return false
	return true
