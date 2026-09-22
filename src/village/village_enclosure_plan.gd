class_name VillageEnclosurePlan
extends RefCounted
## Pure VIL-018 geometry derived from an authored VillagePlan.

const EDGE_BAND := 6.0
const GATE_HALF := 3.0
const EPS := 0.01

static func build(plan: VillagePlan, edge_band: float = EDGE_BAND) -> Dictionary:
	var hull := _lot_hull(plan)
	var edge := _offset_hull(hull, edge_band)
	var gates: Array[Dictionary] = []
	for r in range(plan.roads.size()):
		var road: Dictionary = plan.roads[r]
		if road["class"] != &"through":
			continue
		for i in range((road["points"] as PackedVector2Array).size() - 1):
			var a: Vector2 = road["points"][i]
			var b: Vector2 = road["points"][i + 1]
			var g: Variant = _boundary_hit(a, b, edge)
			if g != null and _far_from_gates(g, gates):
				gates.append({"pos": g, "road": r, "kind": &"gate"})
	var crossings: Array[Dictionary] = []
	for r in range(plan.roads.size()):
		var road: Dictionary = plan.roads[r]
		var pts: PackedVector2Array = road["points"]
		for i in range(pts.size() - 1):
			for w in plan.water:
				var segment := PackedVector2Array([pts[i], pts[i + 1]])
				var ribbon: PackedVector2Array = Poly.ribbon(segment, float(road["width"]) * 0.5)
				var wet: Array = Geometry2D.intersect_polygons(ribbon, w["poly"])
				if wet.is_empty():
					continue
				var key: StringName = w.get("kind", &"stream")
				var pos: Vector2 = Poly.bounding_rect(wet[0]).get_center()
				var duplicate := false
				for prior in crossings:
					if int(prior["road"]) == r and Vector2(prior["pos"]).distance_to(pos) < float(road["width"]):
						duplicate = true
						break
				if duplicate:
					continue
				crossings.append({"road": r, "water": key,
					"kind": &"bridge" if key == &"river" else (&"ford" if key == &"stream" else &"water_crossing"),
					"pos": pos})
	var fields: Array[Dictionary] = []
	for f in plan.fields:
		if _overlap_area(f["poly"], edge) <= EPS:
			fields.append(f)
	var common: PackedVector2Array = VillageMeasure.common_poly(plan)
	var preferred: Vector2 = plan.site.get_center() + Vector2(0.0, -plan.site.size.y * 0.42)
	if not common.is_empty():
		preferred = VillageMeasure.centre(common) + Vector2(0.0, -plan.site.size.y * 0.45)
	var wood: Vector2 = preferred
	var wood_candidates: Array[Vector2] = [preferred,
		Vector2(plan.site.position.x + 3.0, plan.site.position.y + 3.0),
		Vector2(plan.site.end.x - 3.0, plan.site.position.y + 3.0),
		Vector2(plan.site.position.x + 3.0, plan.site.end.y - 3.0),
		Vector2(plan.site.end.x - 3.0, plan.site.end.y - 3.0)]
	for candidate in wood_candidates:
		if plan.site.has_point(candidate) and not Poly.contains_point(edge, candidate):
			wood = candidate
			break
	return {"hull": hull, "edge": edge, "gates": gates, "crossings": crossings,
		"fields": fields, "wood": wood}

static func _lot_hull(plan: VillagePlan) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for lot in plan.lots:
		for p in lot["poly"]:
			pts.append(p)
	if pts.size() < 3:
		return Poly.from_rect(plan.site.grow(-4.0))
	return Geometry2D.convex_hull(pts)

static func _offset_hull(poly: PackedVector2Array, amount: float) -> PackedVector2Array:
	var offset_polys: Array[PackedVector2Array] = Geometry2D.offset_polygon(poly, amount)
	if not offset_polys.is_empty() and offset_polys[0].size() >= 3:
		return offset_polys[0]
	var out := PackedVector2Array()
	var c: Vector2 = VillageMeasure.centre(poly)
	for p in poly:
		out.append(p + (p - c).normalized() * amount)
	return out

static func _boundary_hit(a: Vector2, b: Vector2, poly: PackedVector2Array) -> Variant:
	for i in range(poly.size()):
		var hit: Variant = Geometry2D.segment_intersects_segment(a, b,
			poly[i], poly[(i + 1) % poly.size()])
		if hit != null:
			return hit
	for p in [a, (a + b) * 0.5, b]:
		if VillageMeasure.point_to_poly(p, poly) <= GATE_HALF + 0.5:
			return _nearest_boundary(p, poly)
	return null

static func _nearest_boundary(p: Vector2, poly: PackedVector2Array) -> Vector2:
	var best: Vector2 = poly[0]
	var d: float = INF
	for i in range(poly.size()):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var ab: Vector2 = b - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var q: Vector2 = a + ab * t
		if q.distance_squared_to(p) < d:
			d = q.distance_squared_to(p)
			best = q
	return best

static func _far_from_gates(p: Vector2, gates: Array[Dictionary]) -> bool:
	for g in gates:
		if p.distance_to(g["pos"]) < GATE_HALF * 2.0:
			return false
	return true

static func _overlap_area(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var hits: Array = Geometry2D.intersect_polygons(a, b)
	if hits.is_empty():
		return 0.0
	return Poly.area(hits[0])
