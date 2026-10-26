extends RefCounted
## Preloaded by VillageLotPlanner as `_StreetNet` (no class_name).
##
## A village's streets are a NET, not a spine (VTER-REAL-STREETNET).
##
## Every form lays its own roads and the lot planner cuts lots on them; what
## comes out, on a 50-person village, is one through road with a few stubs that
## end at a lot. Measured against the 109 real settlements (docs/
## VILLAGE_REALISM.md) that is nothing but dead ends: a through road has two,
## each stub one, and the only junctions are the stubs' own feet, so
## `dead_end_ratio` is 0.75-1.0 where real villages sit at 0.15-0.67, and
## `intersections_per_ha` is 0 where real ones have a crossing per hectare.
## A straight spine with right-angle stubs also reads as a grid
## (`orientation_order` 0.93-0.98): two bearings and nothing else.
##
## The real structure is the BACK STREET: a street that leaves the road, runs
## round behind a block of houses and comes back to it, so the houses behind
## the row are reached two ways and the road has a loop. `close` lays up to
## MAX_LOOPS of them, once the lots are cut and the dead-end lanes trimmed,
## while the net's dead-end share is above TARGET_DEAD_END.
##
## A loop is three straight streets -- out, along, back -- as the crest and
## planted forms lay their rings: the road check holds a bend to 25 degrees in
## 20 m WITHIN a road, so a round-cornered loop is a hundred metres across and
## no hamlet has room for one, while a corner BETWEEN two roads is a junction of
## two, held only to 30 degrees and 8 m. Its legs leave the road through the
## gaps the lots left (a foot may stand anywhere on the road: a vertex is
## inserted there), and it keeps every other rule too: clear of every lot,
## building, common, landmark slot, field, water and other road by a metre, a
## street's grade at most, and on the side of the road away from the water. It
## is laid where it fits and nowhere else: a village with no room round its
## houses keeps its stubs.
##
## `enabled` exists for the probe that measures a plan with and without it.

static var enabled := true
## Why candidates were refused, by reason; the probe prints it.
static var refused := {}
static var _blocker_kinds: Array[String] = []

const MAX_LOOPS := 3
const TARGET_DEAD_END := 0.40       ## stop closing when no more than this share of the net's nodes are ends
## How far behind the road the back street runs, and the angle it leaves the
## road at (the junction check wants 30). Shallow first: the shortest loop wins.
const DEPTHS: Array[float] = [10.0, 14.0, 18.0, 24.0, 30.0, 36.0, 42.0]
const LEADS_DEG: Array[float] = [90.0, 70.0, 55.0]
const FOOT_STEP_M := 3.0            ## feet are tried this far apart along the road
const MIN_SPAN_M := 28.0            ## along the road between a loop's two feet
const MAX_SPAN_M := 150.0
const FOOT_APART_M := 9.0           ## a foot this near another junction breaks the 8 m rule
const CLEAR_M := 0.6                ## air between a loop's ribbon and anything else
const MIN_LEG_M := 9.0              ## a leg shorter than this puts two junctions inside 8 m
const MINOR: Array[String] = ["path", "steps", "footway", "cycleway", "bridleway", "pedestrian"]


## Close the net. Returns the number of loops laid.
static func close(plan: VillagePlan) -> int:
	if not _wanted(plan):
		return 0
	return _add(plan, MAX_LOOPS, DEPTHS)


static func _wanted(plan: VillagePlan) -> bool:
	if not enabled or plan == null or plan.roads.is_empty() or plan.spec == null or plan.ground == null:
		return false
	# a round village's road graph is its one lane in and its ring; the compact
	# display is a drawn layout, not a settlement
	return not (plan.spec.compact_display or plan.spec.form == &"round")


static func _add(plan: VillagePlan, most: int, depths: Array[float]) -> int:
	var laid := 0
	while laid < most and dead_end_ratio(plan) > TARGET_DEAD_END:
		if not _lay_one(plan, depths):
			break
		laid += 1
	return laid


## The share of the net's junction-or-end nodes that are ends, counted as
## VillageShape counts it (a node is an end at degree 1, a junction at 3+;
## paths and steps are not streets).
static func dead_end_ratio(plan: VillagePlan) -> float:
	var ends := 0
	var inter := 0
	for v in node_degrees(plan).values():
		if int(v) == 1:
			ends += 1
		elif int(v) >= 3:
			inter += 1
	return float(ends) / maxi(ends + inter, 1)


static func node_degrees(plan: VillagePlan) -> Dictionary:
	var lines: Array = []
	var street: Array[bool] = []
	for r in plan.roads:
		var pts: PackedVector2Array = r["points"]
		if pts.size() < 2:
			continue
		lines.append(pts)
		var cls := String(r["class"])
		street.append(not (cls in MINOR or cls.contains("steps")))
	var net: Dictionary = VillageShape.road_network(lines)
	var deg := {}
	for i in range(lines.size()):
		if not street[i]:
			continue
		var nds: Array = net["ids"][i]
		for k in range(nds.size()):
			var add := 1 if k == 0 or k == nds.size() - 1 else 2
			deg[nds[k]] = int(deg.get(nds[k], 0)) + add
	return deg


# ---------------------------------------------------------------- candidates

## Lay the shortest loop that fits: out from the road through a gap the lots
## left, along behind them, back through another. Returns whether one fitted.
static func _lay_one(plan: VillagePlan, depths: Array[float]) -> bool:
	var blockers: Array[PackedVector2Array] = _blockers(plan)
	var rects: Array[Rect2] = []
	for poly in blockers:
		rects.append(Poly.bounding_rect(poly).grow(CLEAR_M + 4.0))
	var room: Rect2 = plan.site.grow(-(VillageLotPlanner.SITE_MARGIN + VillageLotPlanner.LANE_HALF + CLEAR_M))
	var edge := PackedVector2Array()
	if plan.spec.enclosure != &"none":
		# a walled village keeps its loop inside the wall it will be given
		edge = Poly.offset(VillageEnclosurePlan.build(plan)["edge"], -2.0)
	var taboo: Array[Vector2] = _taboo_points(plan)
	var water: Array[PackedVector2Array] = []
	for w in plan.water:
		water.append(w["poly"])
	var cands: Array[Dictionary] = []
	for ri in range(plan.roads.size()):
		if plan.roads[ri]["class"] != &"through":
			continue
		var pts: PackedVector2Array = plan.roads[ri]["points"]
		var cum := _cumulative(pts)
		var feet: Array[Dictionary] = []
		var s: float = FOOT_APART_M
		while s <= cum[cum.size() - 1] - FOOT_APART_M:
			var at := _at(pts, cum, s)
			if not _near(at["p"], taboo):
				at["s"] = s
				feet.append(at)
			s += FOOT_STEP_M
		for sgn in [1.0, -1.0]:
			for depth in depths:
				for lead in LEADS_DEG:
					cands.append_array(_pairs(plan, ri, feet, sgn, depth, lead, blockers, rects, room, water))
	refused["cands"] = int(refused.get("cands", 0)) + cands.size()
	cands.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if not is_equal_approx(float(x["len"]), float(y["len"])):
			return float(x["len"]) < float(y["len"])
		if not is_equal_approx(float(x["sa"]), float(y["sa"])):
			return float(x["sa"]) < float(y["sa"])
		if not is_equal_approx(float(x["sb"]), float(y["sb"])):
			return float(x["sb"]) < float(y["sb"])
		if float(x["sgn"]) != float(y["sgn"]):
			return float(x["sgn"]) > float(y["sgn"])
		return float(x["depth"]) < float(y["depth"]))
	for c in cands:
		var streets: Array[Dictionary] = _as_streets(plan, c["legs"])
		if streets.is_empty():
			_no("ground")
			continue
		if _fits(plan, streets, int(c["road"]), blockers, rects, room, edge):
			_join(plan, int(c["road"]), streets)
			return true
	return false


## The loops from the feet whose legs are clear: each foot's out-leg is paired
## with the nearest two feet beyond it whose back-leg is clear too.
static func _pairs(plan: VillagePlan, ri: int, feet: Array[Dictionary], sgn: float, depth: float,
		lead: float, blockers: Array[PackedVector2Array], rects: Array[Rect2], room: Rect2,
		water: Array[PackedVector2Array]) -> Array[Dictionary]:
	var reach: float = depth / tan(deg_to_rad(lead))
	var outs: Array[Dictionary] = []
	var backs: Array[Dictionary] = []
	for f in feet:
		var t: Vector2 = f["t"]
		var n: Vector2 = Vector2(-t.y, t.x) * sgn
		var p: Vector2 = f["p"]
		for dir in [1.0, -1.0]:
			var corner: Vector2 = p + n * depth + t * (reach * dir)
			# away from the water: the shore side is where a shore village houses itself
			if not water.is_empty() and _water_distance(water, corner) < _water_distance(water, p) + 1.0:
				continue
			if not _leg_clear(plan, ri, p, corner, blockers, rects, room):
				continue
			if dir > 0.0:
				outs.append({"foot": f, "corner": corner})
			else:
				backs.append({"foot": f, "corner": corner})
	var out: Array[Dictionary] = []
	for a in outs:
		var found := 0
		for b in backs:
			var span: float = float(b["foot"]["s"]) - float(a["foot"]["s"])
			if span < MIN_SPAN_M:
				continue
			if span > MAX_SPAN_M:
				break
			var c: Vector2 = a["corner"]
			var d: Vector2 = b["corner"]
			var pa: Vector2 = a["foot"]["p"]
			var pb: Vector2 = b["foot"]["p"]
			# the back street runs the way the road does, and is long enough to be a street
			if c.distance_to(d) < MIN_LEG_M or (d - c).dot(pb - pa) <= 0.0:
				continue
			var legs: Array = [PackedVector2Array([pa, c]), PackedVector2Array([c, d]), PackedVector2Array([d, pb])]
			out.append({"road": ri, "sa": a["foot"]["s"], "sb": b["foot"]["s"], "sgn": sgn,
				"depth": depth, "lead": lead, "legs": legs, "len": _length(legs)})
			found += 1
			if found >= 2:
				break
	return out


## A leg from the road to a corner: long enough for its junction, in the
## room, clear of everything that is not the road it leaves.
static func _leg_clear(plan: VillagePlan, base_road: int, from: Vector2, to: Vector2,
		blockers: Array[PackedVector2Array], rects: Array[Rect2], room: Rect2) -> bool:
	if from.distance_to(to) < MIN_LEG_M or not room.has_point(to):
		return _no("leg_room")
	var street: Dictionary = VillageSitePlanner.ROAD_CLASSES[&"street"]
	var half: float = float(street["width"]) * 0.5 + float(street["verge"]) + CLEAR_M
	var ribbon: PackedVector2Array = Poly.ribbon(PackedVector2Array([from, to]), half)
	if ribbon.size() < 4:
		return false
	var box: Rect2 = Poly.bounding_rect(ribbon)
	for i in range(blockers.size()):
		if rects[i].intersects(box) and VillageLotPlanner.overlap_area(ribbon, blockers[i]) > VillageLotPlanner.AREA_EPS:
			return _no("leg_" + _blocker_kinds[i])
	var seg := PackedVector2Array([from, to])
	for j in range(plan.roads.size()):
		if j == base_road:
			continue
		var op: PackedVector2Array = plan.roads[j]["points"]
		var keep: float = half + float(plan.roads[j]["width"]) * 0.5 + float(plan.roads[j]["verge"])
		for k in range(op.size() - 1):
			if Geometry2D.segment_intersects_segment(from, to, op[k], op[k + 1]) != null:
				return _no("leg_cross")
		for q in [from, to]:
			if VillageMeasure.point_to_polyline(q, op) < keep:
				return _no("leg_near")
		for q in op:
			if VillageMeasure.point_to_polyline(q, seg) < keep:
				return _no("leg_near")
	refused["legs_ok"] = int(refused.get("legs_ok", 0)) + 1
	return true


## The point and direction of the road `s` metres along it.
static func _at(pts: PackedVector2Array, cum: PackedFloat64Array, s: float) -> Dictionary:
	var i: int = 0
	while i < pts.size() - 2 and cum[i + 1] < s:
		i += 1
	var t: Vector2 = (pts[i + 1] - pts[i]).normalized()
	var p: Vector2 = pts[i] + t * (s - cum[i])
	# at a vertex the direction is the mean of the two it joins
	if i > 0 and s - cum[i] < 0.5:
		t = (t + (pts[i] - pts[i - 1]).normalized()).normalized()
	elif i < pts.size() - 2 and cum[i + 1] - s < 0.5:
		t = (t + (pts[i + 2] - pts[i + 1]).normalized()).normalized()
	return {"p": p, "t": t}


## Put the loop's feet on the road: a vertex where there is none (the road's
## shape does not change), the legs' ends snapped to a vertex that is there.
static func _join(plan: VillagePlan, ri: int, streets: Array[Dictionary]) -> void:
	var base: PackedVector2Array = plan.roads[ri]["points"]
	var first: PackedVector2Array = streets[0]["points"]
	var last: PackedVector2Array = streets[2]["points"]
	var ends: Array[Vector2] = [first[0], last[1]]
	for e in range(2):
		var foot: Vector2 = ends[e]
		var done := false
		for v in base:
			if v.distance_to(foot) < 0.5:
				foot = v
				done = true
				break
		if not done:
			for i in range(base.size() - 1):
				var q: Vector2 = Geometry2D.get_closest_point_to_segment(foot, base[i], base[i + 1])
				if q.distance_to(foot) < 0.05:
					base.insert(i + 1, foot)
					break
		ends[e] = foot
	first[0] = ends[0]
	last[1] = ends[1]
	streets[0]["points"] = first
	streets[2]["points"] = last
	plan.roads[ri]["points"] = base
	for s in streets:
		s["loop"] = true
		plan.roads.append(s)


static func _length(legs: Array) -> float:
	var s := 0.0
	for leg in legs:
		s += leg[0].distance_to(leg[1])
	return s


static func _water_distance(water: Array[PackedVector2Array], p: Vector2) -> float:
	var best := INF
	for w in water:
		best = minf(best, VillageMeasure.point_to_poly(p, w))
	return best


## The legs as streets, [] where the ground refuses them: steeper than a
## street's grade, or into the ground's own water.
static func _as_streets(plan: VillagePlan, legs: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for leg in legs:
		if plan.ground != null:
			var wl: float = plan.ground.water_level_m
			if not is_nan(wl):
				for p in leg:
					if plan.ground.height_at(p) <= wl:
						return []
			if VillageRoadRouter.grade_of(plan.ground, leg) > float(VillageSitePlanner.ROAD_CLASSES[&"street"]["grade_max"]) + 1e-6:
				return []
		out.append(VillageSitePlanner._road(leg, &"street", plan.spec.wealth))
	return out


## Everything a loop may not touch, as polygons.
static func _blockers(plan: VillagePlan) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	_blocker_kinds.clear()
	for lot in plan.lots:
		out.append(lot["poly"])
		_blocker_kinds.append("lot")
	for b in plan.buildings:
		out.append(VillageMeasure.bounds_poly(b))
		_blocker_kinds.append("building")
	for c in plan.commons:
		out.append(c["poly"])
		_blocker_kinds.append("common")
	for w in plan.water:
		out.append(w["poly"])
		_blocker_kinds.append("water")
	for f in plan.fields:
		out.append(f["poly"])
		_blocker_kinds.append("field")
	if plan.landmark_reserved():
		out.append(plan.landmark_site["poly"])
		_blocker_kinds.append("landmark")
	return out


## Every road end: a new foot keeps FOOT_APART_M from each (the road check
## measures the spacing of junctions, which are vertices).
static func _taboo_points(plan: VillagePlan) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for r in plan.roads:
		var pts: PackedVector2Array = r["points"]
		out.append(pts[0])
		out.append(pts[pts.size() - 1])
	return out


static func _near(p: Vector2, taboo: Array[Vector2]) -> bool:
	for q in taboo:
		if p.distance_to(q) < FOOT_APART_M:
			return true
	return false


static func _cumulative(pts: PackedVector2Array) -> PackedFloat64Array:
	var cum := PackedFloat64Array()
	cum.resize(pts.size())
	for i in range(1, pts.size()):
		cum[i] = cum[i - 1] + pts[i].distance_to(pts[i - 1])
	return cum


# ---------------------------------------------------------------- validation

static func _no(why: String) -> bool:
	refused[why] = int(refused.get(why, 0)) + 1
	return false


## What the legs' own clearance test did not cover: the walls, the back street
## between the corners (against lots, buildings and every road), and the
## ground it crosses.
static func _fits(plan: VillagePlan, streets: Array[Dictionary], base_road: int,
		blockers: Array[PackedVector2Array], rects: Array[Rect2], room: Rect2,
		edge: PackedVector2Array) -> bool:
	var base: PackedVector2Array = plan.roads[base_road]["points"]
	for s in streets:
		for p in (s["points"] as PackedVector2Array):
			if not room.has_point(p):
				return _no("room")
			if not edge.is_empty() and not Poly.contains_point(edge, p):
				return _no("wall")
	var mid: Dictionary = streets[1]
	var pts: PackedVector2Array = mid["points"]
	var half: float = float(mid["width"]) * 0.5 + float(mid["verge"]) + CLEAR_M
	var ribbon: PackedVector2Array = Poly.ribbon(pts, half)
	if ribbon.size() < 4:
		return _no("ribbon")
	var box: Rect2 = Poly.bounding_rect(ribbon)
	for bi in range(blockers.size()):
		if rects[bi].intersects(box) and VillageLotPlanner.overlap_area(ribbon, blockers[bi]) > VillageLotPlanner.AREA_EPS:
			return _no("blocked_" + _blocker_kinds[bi])
	# the back street keeps its distance from every road, the one it leaves included
	for j in range(plan.roads.size()):
		var other: Dictionary = plan.roads[j]
		var op: PackedVector2Array = other["points"]
		var keep: float = half + float(other["width"]) * 0.5 + float(other["verge"])
		for k in range(op.size() - 1):
			if Geometry2D.segment_intersects_segment(pts[0], pts[1], op[k], op[k + 1]) != null:
				return _no("crosses_road")
		var n := 10
		for i in range(n + 1):
			if VillageMeasure.point_to_polyline(pts[0].lerp(pts[1], float(i) / float(n)), op) < keep:
				return _no("near_road_" + ("base" if j == base_road else "other"))
		if j != base_road:
			for q in op:
				if VillageMeasure.point_to_polyline(q, pts) < keep:
					return _no("near_road_other")
	# and no corner on the road's other side of the base from its feet
	if VillageMeasure.point_to_polyline(pts[0], base) < half or VillageMeasure.point_to_polyline(pts[1], base) < half:
		return _no("corner_on_road")
	return true
