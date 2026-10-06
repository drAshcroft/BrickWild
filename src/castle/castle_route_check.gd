class_name CastleRouteCheck
extends RefCounted
## Production mesh proof for occupied towers and gatehouse galleries. Route
## records locate probes; emitted masonry proves support and body clearance.
##
## Moved out of qa/ because it reads castle access geometry. Both the source tree
## and the packaged addon must resolve that link, and only a file that sits beside
## its dependency can do so with a relative path. The occupancy helper is reached
## by its global class_name, which is layout-independent.

const Access = preload("castle_access_geometry.gd")


static func check(builder: CastleBuilder, mesh: ArrayMesh) -> Dictionary:
	var out := {"ok": true, "failures": [], "routes": 0, "wall_stairs": 0,
		"courtyard_routes": 0, "diagnostics": []}
	var triangles := masonry_triangles(mesh)
	var network := courtyard_network(builder, triangles, mesh)
	out.wall_stairs = network.stairs.size()
	# Missing records cannot make the route check pass by reducing its work.
	# The inventory comes from the site, independently of the planner.
	if CastleGeometry.is_enclosed(builder.spec):
		for required in CastleOccupancyCheck.expected_ids(builder.spec):
			if not required.begins_with("tower_") and not required.begins_with("gate_"):
				continue
			var present := false
			for row in builder.interiors:
				if String(row.get("id", "")) == required and (bool(row.get("mural_tower", false)) or bool(row.get("gate_chamber", false))):
					present = true
					break
			if not present:
				out.failures.append("access_routes[%s]: required occupied structure has no route record" % required)
	for row in builder.interiors:
		var mural := bool(row.get("mural_tower", false))
		var gate := bool(row.get("gate_chamber", false))
		if not mural and not gate:
			continue
		if bool(row.get("ground_entry", false)):
			continue # entered from the ward; there is no curtain route to prove
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
		if row.has("walk_route"):
			route.assign(row.get("walk_route", []))
		elif row.has("walk_outer") and row.has("walk_target"):
			var inside := Vector2(door.pos) - Vector2(door.normal) * 0.35 + Vector2(origin.x, origin.z)
			route.assign([inside, row.walk_outer, row.walk_target])
		if route.size() < 2:
			out.failures.append("access_routes[%s]: no authored connection to curtain walk" % id)
			continue
		var walk_y := minf(y, float(row.walk_y))
		var diagnostics: Array = []
		var failure := route_failure(near_route(triangles, route, walk_y), route, walk_y, diagnostics)
		if not failure.is_empty():
			out.failures.append("access_routes[%s]: %s" % [id, failure])
			for diagnostic in diagnostics:
				diagnostic["id"] = id
				out.diagnostics.append(diagnostic)
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


## The walking graph is made from the finished mesh, not from curtain AABBs.
## Only stairs with real treads, clear turns and a supported coping arrival
## may seed a flood. Removing their triangles must disconnect the towers.
static func courtyard_network(builder: CastleBuilder, triangles: Array, mesh: ArrayMesh) -> Dictionary:
	var out := {"stairs": [], "grids": [], "failures": [], "diagnostics": []}
	var spec := builder.spec
	var support := triangles.duplicate()
	if mesh != null and CastleBuilder.SURF_GROUND < mesh.get_surface_count():
		support.append_array(HouseQA._mesh_triangles(mesh, CastleBuilder.SURF_GROUND))
	for stair in CastleGeometry.wall_stairs(spec):
		var checked := _wall_stair_route(stair, support, spec)
		if not checked.ok:
			out.failures.append(checked.failure)
			out.diagnostics.append(checked)
			continue
		out.stairs.append(checked)
		var grid := _coping_grid(triangles, CastleGeometry.enceinte_rect(spec, int(stair.ring)).grow(5.0), float(stair.height))
		if grid.flood_from(checked.coping, grid.cell):
			out.grids.append(grid)
		else:
			out.failures.append("wall stair has no standable coping arrival at %s" % checked.coping)
	return out


static func _wall_stair_route(stair: Dictionary, triangles: Array, spec: CastleSpec) -> Dictionary:
	var along := Vector2(stair.along)
	var across := Vector2(stair.inside)
	var origin := Vector2(stair.at)
	var route: Array[Vector3] = []
	var run := float(stair.run)
	for flight in int(stair.flights):
		var lane := (int(stair.flights) - 1 - flight) % 2
		var lane_at := Access.LANE * 0.5 + lane * (Access.LANE + Access.SPINE)
		var forward := (1.0 if flight % 2 == 0 else -1.0) * float(stair.get("start_forward", 1.0))
		var base := float(flight) * float(stair.rise)
		for step in int(stair.steps):
			var u := forward * (-run * 0.5 + (step + 0.5) * Access.TREAD)
			var point := origin + along * u + across * lane_at
			var y := base + float(stair.rise) * float(step + 1) / float(stair.steps)
			route.append(Vector3(point.x, y, point.y))
		var end := forward * (run + Access.LANDING) * 0.5
		var landing := origin + along * end + across * lane_at
		route.append(Vector3(landing.x, base + float(stair.rise), landing.y))
		if flight < int(stair.flights) - 1:
			var other_lane := Access.LANE * 0.5 + (1 - lane) * (Access.LANE + Access.SPINE)
			var turn := origin + along * end + across * other_lane
			route.append(Vector3(turn.x, base + float(stair.rise), turn.y))
	var start := route[0]
	# All authored stair flights start within one riser of courtyard ground.
	if start.y > 0.3:
		return {"ok": false, "failure": "wall stair first tread exceeds a courtyard step"}
	var first_forward := float(stair.get("start_forward", 1.0))
	var ground_at := Vector2(start.x, start.z) - along * first_forward * Access.TREAD * 1.5
	var ring := int(stair.ring)
	var last := route[-1]
	var endpoint := Vector2(last.x, last.z)
	var coping := endpoint
	var best := INF
	for segment in CastleGeometry.wall_segments(spec, ring):
		var inward := -Vector2(segment.outward.x, segment.outward.z)
		var offset := inward * CastleGeometry.wall_thickness(spec, ring) * 0.5
		var at := Geometry2D.get_closest_point_to_segment(endpoint, Vector2(segment.a) + offset, Vector2(segment.b) + offset)
		if at.distance_squared_to(endpoint) < best:
			best = at.distance_squared_to(endpoint)
			coping = at
	route.append(Vector3(coping.x, float(stair.height), coping.y))
	# The route spans every floor height, so retain all triangles in its XZ box.
	var bounds := Rect2(Vector2(start.x, start.z), Vector2.ZERO)
	for point in route:
		bounds = bounds.expand(Vector2(point.x, point.z))
	var nearby := _triangles_in_xz(triangles, bounds.grow(0.6))
	# The bare building API uses the caller's y=0 site datum; courtyard earth
	# is optional dressing, not a mandatory floor slab. Prove the first solid
	# tread actually meets that datum, then sweep the step from the site into it.
	var footing := Vector3(start.x, 0.0, start.z)
	if _hits(nearby, footing + Vector3.UP * 0.025, footing - Vector3.UP * 0.025).is_empty():
		return {"ok": false, "failure": "wall stair first tread is not grounded at the site datum"}
	var previous := Vector3(ground_at.x, 0.0, ground_at.y)
	var have_previous := true
	for point in route:
		if have_previous and absf(point.y - previous.y) > 0.3:
			return {"ok": false, "failure": "wall stair route skips a riser"}
		var lateral := Vector2(-along.y, along.x) if not have_previous else Vector2(-(point.z - previous.z), point.x - previous.x).normalized()
		if lateral.length_squared() < 0.5:
			lateral = across
		for side in [-0.24, 0.0, 0.24]:
			var offset := Vector3(lateral.x, 0.0, lateral.y) * float(side)
			var at := point + offset
			if _hits(nearby, at + Vector3.UP * 0.025, at - Vector3.UP * 0.025).is_empty():
				return {"ok": false, "failure": "wall stair lacks emitted tread/landing support at %s" % at}
			if not _hits(nearby, at + Vector3.UP * 0.08, at + Vector3.UP * 1.95).is_empty():
				return {"ok": false, "failure": "wall stair headroom is blocked at %s" % at,
					"ray": [at + Vector3.UP * 0.08, at + Vector3.UP * 1.95]}
			if have_previous:
				for body_y in [0.12, 0.9, 1.9]:
					var height := maxf(point.y, previous.y) + float(body_y)
					var a := Vector3(previous.x, height, previous.z) + offset
					var b := Vector3(point.x, height, point.z) + offset
					if not _hits(nearby, a, b).is_empty():
						return {"ok": false, "failure": "wall stair body route crosses masonry at %s" % point,
							"ray": [a, b]}
		previous = point
		have_previous = true
	return {"ok": true, "coping": coping, "ring": ring, "route": route}


static func _coping_grid(triangles: Array, bounds: Rect2, y: float) -> WalkGrid:
	var grid := WalkGrid.new()
	grid.setup(bounds, HouseGeometry.NAV_CELL)
	var obstacles: Array[PackedVector2Array] = []
	for triangle in _triangles_in_xz(triangles, bounds):
		var normal: Vector3 = (triangle[2] - triangle[0]).cross(triangle[1] - triangle[0]).normalized()
		if normal.y > 0.9 and absf(float(triangle[0].y) - y) < 0.3 \
				and absf(float(triangle[1].y) - y) < 0.3 and absf(float(triangle[2].y) - y) < 0.3:
			grid.add_floor_poly(PackedVector2Array([Vector2(triangle[0].x, triangle[0].z), Vector2(triangle[1].x, triangle[1].z), Vector2(triangle[2].x, triangle[2].z)]), float(triangle[0].y))
		var clipped := CastleQA._clip_walk_height(PackedVector3Array(triangle), y + 0.1, true)
		clipped = CastleQA._clip_walk_height(clipped, y + 1.95, false)
		if clipped.size() < 3:
			continue
		var points := PackedVector2Array()
		var pad := grid.cell * 0.5
		for vertex in clipped:
			for dx in [-pad, pad]:
				for dz in [-pad, pad]:
					points.append(Vector2(vertex.x + dx, vertex.z + dz))
		var hull := Geometry2D.convex_hull(points)
		if hull.size() > 1 and hull[0].distance_squared_to(hull[-1]) < 1e-10:
			hull.resize(hull.size() - 1)
		obstacles.append(hull)
	for polygon in obstacles:
		grid.add_obstacle_poly(polygon)
	grid.build(HouseGeometry.PERSON_RADIUS)
	return grid


static func _triangles_in_xz(triangles: Array, bounds: Rect2) -> Array:
	var out: Array = []
	for triangle in triangles:
		var rect := Rect2(Vector2(triangle[0].x, triangle[0].z), Vector2.ZERO)
		for vertex in triangle:
			rect = rect.expand(Vector2(vertex.x, vertex.z))
		if bounds.intersects(rect.grow(0.001)):
			out.append(triangle)
	return out


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


static func route_failure(triangles: Array, route: Array[Vector2], expected_y: float, diagnostics: Array = []) -> String:
	var offsets: Array[float] = [-0.25, 0.0, 0.25]
	var previous_floors: Array[float] = [expected_y, expected_y, expected_y]
	for segment in range(route.size() - 1):
		var a := route[segment]
		var b := route[segment + 1]
		var tangent := Vector2(-(b - a).y, (b - a).x).normalized()
		var samples := maxi(2, ceili(a.distance_to(b) / 0.2))
		for step in range(samples + 1):
			var centre := a.lerp(b, float(step) / float(samples))
			var current_floors: Array[float] = []
			for side in offsets.size():
				var lateral := offsets[side]
				var at: Vector2 = centre + tangent * lateral
				var hits := _hits(triangles,
					Vector3(at.x, expected_y + WalkGrid.MAX_STEP + 0.05, at.y),
					Vector3(at.x, expected_y - WalkGrid.MAX_STEP - 0.1, at.y))
				if hits.is_empty():
					return "wall-walk route has no emitted floor at %s" % at
				var floor_y := -INF
				for point in hits:
					floor_y = maxf(floor_y, point.y)
				current_floors.append(floor_y)
				if absf(floor_y - previous_floors[side]) > WalkGrid.MAX_STEP + 0.01:
					return "wall-walk route exceeds one step at %s" % at
				if not _hits(triangles, Vector3(at.x, floor_y + 0.08, at.y),
						Vector3(at.x, floor_y + 1.95, at.y)).is_empty():
					diagnostics.append({"ray": [Vector3(at.x, floor_y + 0.08, at.y), Vector3(at.x, floor_y + 1.95, at.y)]})
					return "masonry blocks wall-walk route at %s" % at
				if step > 0:
					# A thin wall can fall between both vertical sample columns.
					# Sweep the traveller's body along the connecting movement too.
					var prior: Vector2 = a.lerp(b, float(step - 1) / float(samples)) + tangent * lateral
					for body_y in [0.12, 0.9, 1.9]:
						var height := maxf(floor_y, previous_floors[side]) + float(body_y)
						if not _hits(triangles, Vector3(prior.x, height, prior.y),
								Vector3(at.x, height, at.y)).is_empty():
							diagnostics.append({"ray": [Vector3(prior.x, height, prior.y), Vector3(at.x, height, at.y)]})
							return "masonry blocks movement between wall-walk samples at %s" % at
			# Keep the three prior contact heights until every side has swept
			# this movement. Updating the centre inside the loop made the last
			# side use the new centre height and collide with a legal slab edge.
			previous_floors = current_floors
	return ""


static func _hits(triangles: Array, start: Vector3, end: Vector3) -> Array[Vector3]:
	var hits: Array[Vector3] = []
	for triangle in triangles:
		var hit: Variant = Geometry3D.segment_intersects_triangle(start, end,
			triangle[0], triangle[1], triangle[2])
		if hit != null:
			hits.append(hit)
	return hits
