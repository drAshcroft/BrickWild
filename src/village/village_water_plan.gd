class_name VillageWaterPlan
extends RefCounted
## Pure pre-lot water geometry for VIL-018.
## SitePlanner can call this before lot cutting; it never mutates its inputs.

const STREAM_WIDTH := 3.0
const RIVER_WIDTH := 8.0
const SITE_MARGIN := 3.0


static func build(spec: VillageSpec, site: Rect2,
		roads: Array[Dictionary], commons: Array[Dictionary]) -> Dictionary:
	var water: Array[Dictionary] = []
	if spec == null or spec.water == &"none":
		return {"water": water, "crossings": []}
	match spec.water:
		&"coast":
			var depth: float = maxf(18.0, site.size.y * 0.30)
			water.append({"poly": Poly.from_rect(Rect2(
				Vector2(site.position.x + SITE_MARGIN, site.end.y - depth),
				Vector2(site.size.x - SITE_MARGIN * 2.0, depth))), "kind": &"coast"})
		&"pond":
			water.append({"poly": _pond(site, commons, roads), "kind": &"pond"})
		&"stream", &"river":
			var width: float = STREAM_WIDTH if spec.water == &"stream" else RIVER_WIDTH
			var x: float = _ribbon_x(site, commons, roads, width)
			water.append({"poly": Poly.from_rect(Rect2(
				Vector2(x - width * 0.5, site.position.y + SITE_MARGIN),
				Vector2(width, site.size.y - SITE_MARGIN * 2.0))),
				"kind": spec.water})
	return {"water": water, "crossings": _crossings(water, roads)}


static func _pond(site: Rect2, commons: Array[Dictionary], roads: Array[Dictionary]) -> PackedVector2Array:
	var width: float = clampf(site.size.x * 0.22, 18.0, 42.0)
	var depth: float = clampf(site.size.y * 0.16, 12.0, 28.0)
	# Try the perimeter bays first.  A green-adjacent pond is useful, but it
	# must not consume a road ribbon: a road/pond crossing is a bridge design,
	# not an accidental consequence of centring the pond on the common.
	var candidates: Array[Vector2] = []
	var centre := site.get_center()
	if not commons.is_empty():
		var common: PackedVector2Array = commons[0]["poly"]
		var bounds := Poly.bounding_rect(common)
		# Put the pond on the settlement-facing side of the green.  The former
		# north-side choice often landed beyond the eventual lot hull/hedge,
		# making a visually inaccessible back-water despite valid road clearance.
		centre = Vector2(bounds.get_center().x, bounds.end.y + depth * 0.5 + 3.0)
	candidates.append(centre)
	for fx in [0.18, 0.50, 0.82]:
		for fy in [0.18, 0.50, 0.82]:
			candidates.append(Vector2(
				site.position.x + site.size.x * fx,
				site.position.y + site.size.y * fy))
	var best := centre
	var best_score := INF
	for candidate in candidates:
		var clamped := Vector2(
			clampf(candidate.x, site.position.x + width * 0.5 + SITE_MARGIN,
				site.end.x - width * 0.5 - SITE_MARGIN),
			clampf(candidate.y, site.position.y + depth * 0.5 + SITE_MARGIN,
				site.end.y - depth * 0.5 - SITE_MARGIN))
		var rect := Poly.from_rect(Rect2(clamped - Vector2(width, depth) * 0.5,
			Vector2(width, depth)))
		var score := 0.0
		for road in roads:
			var ribbon := _road_ribbon(road)
			score += Poly.intersection_area(rect, ribbon) * 100.0
		for common in commons:
			score += Poly.intersection_area(rect, common["poly"]) * 10.0
		if score <= 0.001:
			return rect
		if score < best_score:
			best_score = score
			best = clamped
	return Poly.from_rect(Rect2(best - Vector2(width, depth) * 0.5,
		Vector2(width, depth)))


static func _road_ribbon(road: Dictionary) -> PackedVector2Array:
	return Poly.ribbon(road["points"], float(road["width"]) * 0.5 + float(road.get("verge", 0.0)))



static func _ribbon_x(site: Rect2, commons: Array[Dictionary], roads: Array[Dictionary], width: float) -> float:
	var candidates: Array[float] = [site.get_center().x]
	for fraction in [0.16, 0.24, 0.32, 0.40, 0.60, 0.68, 0.76, 0.84]:
		candidates.append(site.position.x + site.size.x * fraction)
	var best := candidates[0]
	var best_score := INF
	var best_with_crossing := INF
	for candidate in candidates:
		var ribbon := Poly.from_rect(Rect2(Vector2(candidate - width * 0.5,
			site.position.y), Vector2(width, site.size.y)))
		var blocked := false
		for common in commons:
			if Poly.intersection_area(ribbon, common["poly"]) > 0.1:
				blocked = true
				break
		if blocked:
			continue
		var overlap := 0.0
		var crossings := 0
		for road in roads:
			var road_poly := _road_ribbon(road)
			overlap += Poly.intersection_area(ribbon, road_poly)
			if not Geometry2D.intersect_polygons(ribbon, road_poly).is_empty():
				crossings += 1
		# Prefer one genuine crossing with the least road blanket.  This leaves
		# most of a stream visible while keeping a ford/bridge test meaningful.
		if crossings > 0 and overlap < best_with_crossing:
			best_with_crossing = overlap
			best = candidate
		if crossings == 0 and best_with_crossing < INF:
			continue
		if overlap < best_score:
			best_score = overlap
			if best_with_crossing == INF:
				best = candidate
	return best


static func _crossings(water: Array[Dictionary], roads: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in range(roads.size()):
		var points: PackedVector2Array = roads[r]["points"]
		for w in range(water.size()):
			var all_hits: Array[Vector2] = []
			var poly: PackedVector2Array = water[w]["poly"]
			for i in range(points.size() - 1):
				var segment_hits: Array[Vector2] = []
				for e in range(poly.size()):
					var hit: Variant = Geometry2D.segment_intersects_segment(
						points[i], points[i + 1], poly[e], poly[(e + 1) % poly.size()])
					if hit != null:
						segment_hits.append(Vector2(hit))
				all_hits.append_array(segment_hits)
			if all_hits.size() < 2:
				continue
			var first := all_hits[0]
			var last := all_hits[0]
			for hit_point in all_hits:
				if _path_t(points, hit_point) < _path_t(points, first): first = hit_point
				if _path_t(points, hit_point) > _path_t(points, last): last = hit_point
			out.append({"road": r, "water": w, "kind": water[w]["kind"],
				"a": first, "b": last, "pos": (first + last) * 0.5})
	return out


static func _path_t(points: PackedVector2Array, point: Vector2) -> float:
	var travelled := 0.0
	var nearest_distance := INF
	var best_path := INF
	for i in range(points.size() - 1):
		var edge := points[i + 1] - points[i]
		var length := edge.length()
		var t := clampf((point - points[i]).dot(edge) / maxf(edge.length_squared(), 0.001), 0.0, 1.0)
		var distance := point.distance_to(points[i] + edge * t)
		if distance < nearest_distance:
			nearest_distance = distance
			best_path = travelled + length * t
		travelled += length
	return best_path
