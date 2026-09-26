class_name VillageWaterPlan
extends RefCounted
## Pure pre-lot water geometry for VIL-018.
## SitePlanner can call this before lot cutting; it never mutates its inputs.

const STREAM_WIDTH := 3.0
const RIVER_WIDTH := 8.0
const SITE_MARGIN := 3.0
const WHEEL_RADIUS := 1.4
const WHEEL_AXLE := 1.15


static func mill_walls(placement: Dictionary, xf: Transform3D) -> PackedVector2Array:
	return Placement.world_rect({"footprint": placement.get("mill_wall_rect", placement["footprint"])}, xf, true)


static func wheel_openings_clear(placement: Dictionary, xf: Transform3D,
		wheel: Vector2, normal: Vector2) -> bool:
	var tangent := Vector2(-normal.y, normal.x)
	for opening in placement.get("mill_openings", []):
		var pos: Vector2 = opening["pos"]
		var local_normal: Vector2 = opening["normal"]
		var world_pos := xf * Vector3(pos.x, 0, pos.y)
		var world_normal := xf.basis * Vector3(local_normal.x, 0, local_normal.y)
		if Vector2(world_normal.x, world_normal.z).dot(normal) < 0.95:
			continue
		if float(opening["sill"]) > WHEEL_AXLE + WHEEL_RADIUS + 0.15:
			continue
		var span := absf((Vector2(world_pos.x, world_pos.z) - wheel).dot(tangent))
		if span < WHEEL_RADIUS + float(opening["width"]) * 0.5 + 0.20:
			return false
	return true


## Fit a short, visible race beside a real wall. The wheel's axis points into
## that wall; its long channel runs along the wheel, and a narrow headrace
## connects the channel to natural water. Candidate races clear every road,
## common and other lot before the mill is committed.
static func mill_race(plan: VillagePlan, placement: Dictionary, xf: Transform3D) -> Dictionary:
	var walls := mill_walls(placement, xf)
	var centre := Poly.bounding_rect(walls).get_center()
	var forward3: Vector3 = xf.basis * Vector3(0, 0, -1)
	var forward := Vector2(forward3.x, forward3.z)
	for edge in walls.size():
		var a := walls[edge]
		var b := walls[(edge + 1) % walls.size()]
		var tangent := (b - a).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		if normal.dot((a + b) * 0.5 - centre) < 0.0:
			normal = -normal
		if normal.dot(forward) > 0.5 or a.distance_to(b) < 5.0:
			continue # the working wheel never claims the public entrance
		for fraction in [0.5, 0.3, 0.7, 0.2, 0.8, 0.4, 0.6]:
			var wall: Vector2 = a.lerp(b, fraction)
			var wheel := wall + normal * 0.65
			if not wheel_openings_clear(placement, xf, wheel, normal):
				continue
			for wi in plan.water.size():
				var water: Dictionary = plan.water[wi]
				if water["kind"] == &"race":
					continue
				var shore := Vector2.INF
				var distance := INF
				var poly: PackedVector2Array = water["poly"]
				for k in poly.size():
					var closest := Geometry2D.get_closest_point_to_segment(wheel, poly[k], poly[(k + 1) % poly.size()])
					if wheel.distance_to(closest) < distance:
						distance = wheel.distance_to(closest)
						shore = closest
				# A broad coastal bank can need a longer leat than a streamside
				# mill. It still reserves real, clear ground for its entire run.
				var reach := maxf(14.0, plan.site.size.y * 0.35) if water["kind"] == &"coast" else 14.0
				if distance > reach or (shore - wall).dot(normal) < 0.3:
					continue
				var flow := (shore - wheel).normalized()
				var channel := PackedVector2Array([wheel - tangent * 2.3 - normal * 0.60,
					wheel + tangent * 2.3 - normal * 0.60, wheel + tangent * 2.3 + normal * 0.60,
					wheel - tangent * 2.3 + normal * 0.60])
				var side := Vector2(-flow.y, flow.x) * 0.6
				var connection := PackedVector2Array([wheel - side, shore + flow * 0.6 - side,
					shore + flow * 0.6 + side, wheel + side])
				var union := Geometry2D.merge_polygons(channel, connection)
				if union.size() != 1:
					continue
				var race: PackedVector2Array = union[0]
				if not _race_clear(plan, race, walls):
					continue
				return {"kind": &"race", "poly": race, "source": wi,
					"wheel": wheel, "normal": normal, "wall": wall}
	return {}


static func _race_clear(plan: VillagePlan, race: PackedVector2Array,
		walls: PackedVector2Array) -> bool:
	for p in race:
		if not plan.site.grow(-0.5).has_point(p):
			return false
	if VillageLotPlanner.overlap_area(race, walls) > 0.01:
		return false
	for road in plan.roads:
		if VillageLotPlanner.overlap_area(race, VillageSitePlanner.road_ribbon(road, true)) > 0.01:
			return false
	for common in plan.commons:
		if VillageLotPlanner.overlap_area(race, common["poly"]) > 0.01:
			return false
	if plan.landmark_reserved() and VillageLotPlanner.overlap_area(race, plan.landmark_site["poly"]) > 0.01:
		return false
	for lot in plan.lots:
		if VillageLotPlanner.overlap_area(race, lot["poly"]) > 0.01:
			return false
	return true


static func build(spec: VillageSpec, site: Rect2,
		roads: Array[Dictionary], commons: Array[Dictionary]) -> Dictionary:
	var water: Array[Dictionary] = []
	if spec == null or spec.water == &"none":
		return {"water": water, "crossings": []}
	match spec.water:
		&"coast":
			# Keep a usable dry bank between the winding road and the shore.
			# Thirty percent consumed that bank on 90m sites, leaving no legal
			# mill or service yard despite plenty of unused land inland.
			var depth: float = maxf(18.0, site.size.y * 0.20)
			# Gate settlements reserve the northern head for the measured
			# manor and its approach. Put their shore on the opposite edge so
			# widening the settlement can actually produce dry manor ground.
			var shore_y := site.position.y if spec.form == &"gate" else site.end.y - depth
			water.append({"poly": Poly.from_rect(Rect2(
				Vector2(site.position.x + SITE_MARGIN, shore_y),
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
	return {"water": water, "crossings": crossings(water, roads)}


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


## Clip the route against a bank buffer, preserving every bend and separate
## wet reach. The road's half width keeps oblique deck corners on dry banks.
static func crossings(water: Array[Dictionary], roads: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in roads.size():
		var road: Dictionary = roads[r]
		var points: PackedVector2Array = road["points"]
		for w in water.size():
			var wet := Geometry2D.intersect_polygons(Poly.ribbon(points,
				float(road["width"]) * 0.5), water[w]["poly"])
			if wet.is_empty():
				continue
			var buffers := Geometry2D.offset_polygon(water[w]["poly"],
				float(road["width"]) * 0.5 + 0.1)
			for buffer in buffers:
				for route in _wet_routes(points, buffer):
					out.append({"road": r, "water": w, "water_kind": water[w]["kind"],
						"kind": &"ford" if water[w]["kind"] == &"stream" else &"bridge",
						"points": route, "width": float(road["width"]),
						"pos": route[route.size() / 2]})
	return out


static func _wet_routes(points: PackedVector2Array, poly: PackedVector2Array) -> Array[PackedVector2Array]:
	var routes: Array[PackedVector2Array] = []
	for i in range(points.size() - 1):
		var a := points[i]
		var run := points[i + 1] - a
		if run.length_squared() < 0.000001:
			continue
		var cuts: Array[float] = [0.0, 1.0]
		for e in poly.size():
			var hit: Variant = Geometry2D.segment_intersects_segment(a, a + run,
				poly[e], poly[(e + 1) % poly.size()])
			if hit != null:
				cuts.append(clampf((Vector2(hit) - a).dot(run) / run.length_squared(), 0.0, 1.0))
		cuts.sort()
		for k in range(cuts.size() - 1):
			if (cuts[k + 1] - cuts[k]) * run.length() < 0.001:
				continue
			if not Poly.contains_point(poly, a + run * (cuts[k] + cuts[k + 1]) * 0.5):
				continue
			var start := a + run * cuts[k]
			var end := a + run * cuts[k + 1]
			if not routes.is_empty() and routes[-1][-1].distance_to(start) < 0.001:
				var joined := routes[-1]
				joined.append(end)
				routes[-1] = joined
			else:
				routes.append(PackedVector2Array([start, end]))
	return routes
