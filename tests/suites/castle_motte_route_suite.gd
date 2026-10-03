extends RefCounted
## Structural diagnostic companion to the furnished README fixture. Reuses
## production plans and emitters, without running the large keep furnisher.

const Routes = preload("res://qa/castle_route_check.gd")
const AccessSuite = preload("res://tests/suites/castle_motte_access_suite.gd")
const Mural = preload("res://src/castle/castle_mural_plan.gd")
const Gate = preload("res://src/castle/castle_gate_plan.gd")
const Occupancy = preload("res://qa/castle_occupancy_check.gd")


static func run() -> SuiteResult:
	var result := SuiteResult.new("castle motte structural routes")
	var spec := AccessSuite.hero_spec()
	var builder := CastleBuilder.new()
	builder.spec = spec
	builder.begin_metric(CastleBuilder.SURFACES)
	builder._planned_interiors = Mural.records(spec)
	builder._planned_interiors.merge(Gate.records(spec))
	for ring in CastleGeometry.rings(spec):
		builder._build_ring(ring)
	builder._build_wall_stairs()
	var mesh := builder.commit()
	var report := Routes.check(builder, mesh)
	result.checked += 1
	if not report.ok or report.courtyard_routes != 7:
		result.fail("all seven structural routes: " + str(report.failures))
		var network := Routes.courtyard_network(builder, Routes.masonry_triangles(mesh), mesh)
		result.note("curtain thickness=%.3f merlon=%.3f" % [spec.wall_thickness, spec.merlon_h])
		for segment in CastleGeometry.wall_segments(spec, 0):
			var inward := -Vector2(segment.outward.x, segment.outward.z)
			var a := Vector2(segment.a) + inward * CastleGeometry.wall_thickness(spec, 0) * 0.5
			var b := Vector2(segment.b) + inward * CastleGeometry.wall_thickness(spec, 0) * 0.5
			var states := ""
			var count := maxi(1, ceili(a.distance_to(b) / 0.3))
			for step in range(count + 1):
				var point := a.lerp(b, float(step) / count)
				var state := "#"
				for grid in network.grids:
					var cell: Vector2i = grid.cell_of(point)
					if cell.x < 0 or cell.y < 0 or cell.x >= grid.nx or cell.y >= grid.nz:
						continue
					var index: int = cell.x * grid.nz + cell.y
					if grid._seen[index]:
						state = "+"
						break
					elif grid._walk[index]:
						state = "."
					elif grid._free[index]:
						state = "_"
				states += state
			result.note("coping %s %s -> %s: %s" % [segment.name, a, b, states])
		for row in builder.interiors:
			result.note("%s route=%s" % [row.id, row.get("walk_route", [])])
			if not row.has("walk_target"):
				continue
			for grid in network.grids:
				var cell: Vector2i = grid.cell_of(row.walk_target)
				if cell.x < 0 or cell.y < 0 or cell.x >= grid.nx or cell.y >= grid.nz:
					continue
				var index: int = cell.x * grid.nz + cell.y
				result.note("  target=%s floor=%d walk=%d reached=%d y=%.3f" % [row.walk_target, grid._free[index], grid._walk[index], grid._seen[index], grid._level[index]])
				var map := ""
				for z in range(maxi(0, cell.y - 7), mini(grid.nz, cell.y + 8)):
					var line := ""
					for x in range(maxi(0, cell.x - 7), mini(grid.nx, cell.x + 8)):
						var at: int = x * grid.nz + z
						line += "T" if Vector2i(x, z) == cell else ("+" if grid._seen[at] else ("." if grid._walk[at] else ("_" if grid._free[at] else "#")))
					map += line + "\n"
				result.note(map)
		var diagnostics: Array = network.diagnostics.duplicate()
		diagnostics.append_array(report.diagnostics)
		for diagnostic in diagnostics:
			if not diagnostic.has("ray"):
				continue
			for triangle in Routes.masonry_triangles(mesh):
				var hit: Variant = Geometry3D.segment_intersects_triangle(diagnostic.ray[0], diagnostic.ray[1], triangle[0], triangle[1], triangle[2])
				if hit == null:
					continue
				var hosts: Array[String] = []
				for component in builder.component_log:
					if MassBuilder.component_aabb(component).grow(0.005).has_point(hit):
						hosts.append("%s/%s" % [component.host, component.role])
				result.note("Blocked ray %s hit %s components=%s triangle=%s" % [diagnostic.ray, hit, hosts, triangle])
	result.note("routes=%d courtyard=%d stairs=%d" % [report.routes, report.courtyard_routes, report.wall_stairs])
	_door_clearance_controls(result, builder, mesh)
	AccessSuite._route_mutations(result, builder, mesh)
	# Keep the same mesh and logs but erase one occupied structure record.
	# An oracle that only iterates retained records would miss this defect.
	if not builder.interiors.is_empty():
		var saved := builder.interiors.duplicate()
		builder.interiors.remove_at(0)
		var missing := Routes.check(builder, mesh)
		builder.interiors.assign(saved)
		result.checked += 1
		if missing.ok or not str(missing.failures).contains("required occupied structure has no route record"):
			result.fail("missing occupied route record was accepted")
	return result


static func _door_clearance_controls(result: SuiteResult, builder: CastleBuilder,
		mesh: ArrayMesh) -> void:
	var geometry := Occupancy.prepare_mesh(mesh)
	var chosen := {}
	for row in builder.interiors:
		var plan: HousePlan = row.plan
		for door in plan.doors:
			if not door.get("exterior", false):
				continue
			var pose := Occupancy._pose(plan, row.transform, door, int(door.a), true)
			var out := {"failures": [], "stats": {"door_rays": 0}}
			Occupancy._check_door_mesh(out, row.id, pose, geometry)
			result.checked += 1
			if not out.failures.is_empty():
				result.fail("standing clearance through raised entrance: " + str(out.failures))
			if chosen.is_empty() and row.get("mural_tower", false):
				chosen = {"row": row, "pose": pose}
	if chosen.is_empty():
		result.fail("no raised tower doorway for collision control")
		return
	# A low barrier is above both real floors. Threshold-side contacts may be
	# excluded, but a barrier in a standing person's shins must still fail.
	var pose: Dictionary = chosen.pose
	var floor_y := maxf(float(pose.floor_y), float(chosen.row.walk_y))
	var kit := MeshKit.new(1)
	var centre: Vector3 = pose.pos
	centre.y = floor_y + 0.45
	var normal: Vector3 = pose.facing
	kit.oriented_box(Vector3(float(pose.width), 0.70, 0.10),
		Transform3D(Basis(Vector3.UP, atan2(normal.x, normal.z)), centre), 0)
	var obstacle := kit.commit()
	var blocked := mesh.duplicate() as ArrayMesh
	blocked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, obstacle.surface_get_arrays(0))
	var out := {"failures": [], "stats": {"door_rays": 0}}
	Occupancy._check_door_mesh(out, chosen.row.id, pose, Occupancy.prepare_mesh(blocked))
	result.checked += 1
	if out.failures.is_empty():
		result.fail("real shin-height doorway barrier escaped threshold clearance")
