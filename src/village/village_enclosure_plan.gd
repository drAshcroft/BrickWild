class_name VillageEnclosurePlan
extends RefCounted
## Pure VIL-018 geometry derived from an authored VillagePlan.

const EDGE_BAND := 6.0
const GATE_MARGIN := 0.8
const EPS := 0.01

static func build(plan: VillagePlan, edge_band: float = EDGE_BAND) -> Dictionary:
	var hull := _lot_hull(plan)
	var edge := _offset_hull(hull, edge_band)
	# The site is the available ground. Clip the offset at its inner edge:
	# lots near the parcel limit must not put a wall beyond both the ground
	# mesh and the endpoints of the approach roads.
	var clipped := Geometry2D.intersect_polygons(edge, Poly.from_rect(plan.site.grow(-1.0)))
	if not clipped.is_empty():
		edge = clipped[0]
	var gates := crossings(plan.roads, edge)
	var crossings := plan.water_crossings.duplicate(true)
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
		var wet := plan.water.any(func(water: Dictionary) -> bool:
			return Poly.contains_point(water["poly"], candidate) or VillageMeasure.point_to_poly(candidate, water["poly"]) < 4.0)
		if plan.site.has_point(candidate) and not Poly.contains_point(edge, candidate) and not wet:
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

## Store final geometry, never projected near-misses. A single road segment
## can enter AND leave the boundary. Minor field routes get a postern rather
## than a ceremonial through-road gateway, but both remain passable.
static func crossings(roads: Array[Dictionary], edge: PackedVector2Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in roads.size():
		var road := roads[r]
		var points: PackedVector2Array = road["points"]
		for i in range(points.size() - 1):
			var direction := (points[i + 1] - points[i]).normalized()
			for e in edge.size():
				var a := edge[e]
				var b := edge[(e + 1) % edge.size()]
				var hit = Geometry2D.segment_intersects_segment(points[i], points[i + 1], a, b)
				if hit == null or out.any(func(g): return int(g["road"]) == r and Vector2(g["pos"]).distance_to(hit) < 0.01):
					continue
				var tangent := (b - a).normalized()
				var width := float(road["width"]) + GATE_MARGIN
				out.append({"pos": Vector2(hit), "road": r, "edge": e,
					"kind": &"gate" if road["class"] == &"through" else &"postern",
					"direction": direction, "tangent": tangent, "width": width,
					"opening": width / maxf(absf(direction.cross(tangent)), 0.05)})
	return out


static func author(plan: VillagePlan) -> void:
	plan.enclosure = PackedVector2Array()
	plan.gate_crossings.clear()
	if plan.spec.enclosure == &"none":
		return
	var derived := build(plan)
	plan.enclosure = derived["edge"]
	plan.enclosure_kept_fraction = clampf(plan.spec.enclosure_kept_fraction, 0.0, 1.0)
	plan.gate_crossings.assign(derived["gates"])

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

static func _overlap_area(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var hits: Array = Geometry2D.intersect_polygons(a, b)
	if hits.is_empty():
		return 0.0
	return Poly.area(hits[0])
