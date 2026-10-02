extends RefCounted
## Production mesh proof for occupied towers and gatehouse galleries. Route
## records locate probes; emitted masonry proves support and body clearance.


static func check(builder: CastleBuilder, mesh: ArrayMesh) -> Dictionary:
	var out := {"ok": true, "failures": [], "routes": 0, "wall_stairs": 0,
		"courtyard_routes": 0}
	var triangles := masonry_triangles(mesh)
	var network := courtyard_network(builder, triangles)
	out.wall_stairs = network.stairs.size()
	for row in builder.interiors:
		var mural := bool(row.get("mural_tower", false))
		var gate := bool(row.get("gate_chamber", false))
		if not mural and not gate:
			continue
		out.routes += 1
		var id := String(row.id)
		var plan: HousePlan = row.plan
		if plan.spec == null or plan.entrance() < 0:
			out.failures.append("access_routes[%s]: occupied structure has no route entrance" % id)
			continue
		var door: Dictionary = plan.doors[plan.entrance()]
		var origin: Vector3 = row.transform.origin
		var y := origin.y + HousePlan.record_storey(door) * plan.spec.height + HouseGeometry.FLOOR_T
		if not row.has("walk_y") or absf(y - float(row.walk_y)) > WalkGrid.MAX_STEP:
			out.failures.append("access_routes[%s]: entrance cannot step onto curtain walk" % id)
			continue
		var route: Array[Vector2] = []
		if gate:
			route.assign(row.get("walk_route", []))
		elif row.has("walk_outer") and row.has("walk_target"):
			var inside := Vector2(door.pos) - Vector2(door.normal) * 0.35 + Vector2(origin.x, origin.z)
			route.assign([inside, row.walk_outer, row.walk_target])
		if route.size() < 2:
			out.failures.append("access_routes[%s]: no authored connection to curtain walk" % id)
			continue
		var walk_y := minf(y, float(row.walk_y))
		var failure := route_failure(near_route(triangles, route, walk_y), route, walk_y)
		if not failure.is_empty():
			out.failures.append("access_routes[%s]: %s" % [id, failure])
		var connected := false
		for grid in network.grids:
			if grid.reached(Rect2(route[-1] - Vector2.ONE * 0.18, Vector2.ONE * 0.36)):
				connected = true
				break
		if not connected:
			out.failures.append("access_routes[%s]: curtain route does not reach an emitted stair down to the courtyard" % id)
		else:
			out.courtyard_routes += 1
	if out.routes > 0 and network.stairs.is_empty():
		out.failures.append("access_routes: no physically clear wall stair reaches courtyard ground: %s" % str(network.failures))
	out.ok = out.failures.is_empty()
	return out


static func masonry_triangles(mesh: ArrayMesh) -> Array:
	var triangles: Array = []
	if mesh == null:
		return triangles
	for surface in [CastleBuilder.SURF_STONE, CastleBuilder.SURF_TRIM, CastleBuilder.SURF_ROOF]:
		if surface < mesh.get_surface_count():
			triangles.append_array(HouseQA._mesh_triangles(mesh, surface))
	return triangles


static func near_route(triangles: Array, route: Array[Vector2], y: float) -> Array:
	var rect := Rect2(route[0], Vector2.ZERO)
	for point in route:
		rect = rect.expand(point)
	rect = rect.grow(0.8)
	var bounds := AABB(Vector3(rect.position.x, y - 0.8, rect.position.y),
		Vector3(rect.size.x, 3.0, rect.size.y))
	var out: Array = []
	for triangle in triangles:
		var box := AABB(triangle[0], Vector3.ZERO)
		box = box.expand(triangle[1]).expand(triangle[2]).grow(0.001)
		if bounds.intersects(box):
			out.append(triangle)
	return out


static func route_failure(triangles: Array, route: Array[Vector2], expected_y: float) -> String:
	var previous_y := expected_y
	for segment in range(route.size() - 1):
		var a := route[segment]
		var b := route[segment + 1]
		var tangent := Vector2(-(b - a).y, (b - a).x).normalized()
		var samples := maxi(2, ceili(a.distance_to(b) / 0.2))
		for step in range(samples + 1):
			var centre := a.lerp(b, float(step) / float(samples))
			for lateral in [-0.25, 0.0, 0.25]:
				var at: Vector2 = centre + tangent * lateral
				var hits := _hits(triangles,
					Vector3(at.x, expected_y + WalkGrid.MAX_STEP + 0.05, at.y),
					Vector3(at.x, expected_y - WalkGrid.MAX_STEP - 0.1, at.y))
				if hits.is_empty():
					return "wall-walk route has no emitted floor at %s" % at
				var floor_y := -INF
				for point in hits:
					floor_y = maxf(floor_y, point.y)
				if absf(floor_y - previous_y) > WalkGrid.MAX_STEP + 0.01:
					return "wall-walk route exceeds one step at %s" % at
				if not _hits(triangles, Vector3(at.x, floor_y + 0.08, at.y),
						Vector3(at.x, floor_y + 1.8, at.y)).is_empty():
					return "masonry blocks wall-walk route at %s" % at
				if step > 0:
					# A thin wall can fall between both vertical sample columns.
					# Sweep the traveller's body along the connecting movement too.
					var prior: Vector2 = a.lerp(b, float(step - 1) / float(samples)) + tangent * lateral
					for body_y in [0.12, 0.9, 1.8]:
						var height := maxf(floor_y, previous_y) + float(body_y)
						if not _hits(triangles, Vector3(prior.x, height, prior.y),
								Vector3(at.x, height, at.y)).is_empty():
							return "masonry blocks movement between wall-walk samples at %s" % at
				if is_zero_approx(lateral):
					previous_y = floor_y
	return ""


static func _hits(triangles: Array, start: Vector3, end: Vector3) -> Array[Vector3]:
	var hits: Array[Vector3] = []
	for triangle in triangles:
		var hit: Variant = Geometry3D.segment_intersects_triangle(start, end,
			triangle[0], triangle[1], triangle[2])
		if hit != null:
			hits.append(hit)
	return hits
