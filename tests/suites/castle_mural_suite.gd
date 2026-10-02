extends RefCounted
## Guard towers must have a walkable inside and a real connection to the wall.
const Probe = preload("res://tests/suites/stone_shell_suite.gd")
const Routes = preload("res://qa/castle_route_check.gd")


static func check_fixture(result: SuiteResult, _spec: CastleSpec,
		builder: CastleBuilder, mesh: ArrayMesh) -> void:
	var triangles := Routes.masonry_triangles(mesh)
	var count := 0
	for row in builder.interiors:
		if not bool(row.get("mural_tower", false)):
			continue
		count += 1
		var plan: HousePlan = row.plan
		_expect(result, plan.stairs.size() == plan.rooms.size() - 1,
			"mural %s: occupied floors lack a complete stair chain" % row.id)
		# The castle owns the roof; HouseQA owns this plan and its navigation.
		var report := HouseQA.new().check(plan, null)
		_expect(result, report.failures.is_empty(),
			"mural %s: %s" % [row.id, report.failures])
		var door: Dictionary = plan.doors[plan.entrance()]
		var y := HousePlan.record_storey(door) * plan.spec.height + HouseGeometry.FLOOR_T
		_expect(result, absf(y - float(row.walk_y)) <= WalkGrid.MAX_STEP,
			"mural %s: entrance cannot step onto curtain walk" % row.id)
		var origin: Vector3 = row.transform.origin
		var inside := Vector2(door.pos) - Vector2(door.normal) * 0.35 + Vector2(origin.x, origin.z)
		var route: Array[Vector2] = [inside, row.walk_outer, row.walk_target]
		var nearby := _near_route(triangles, route, minf(y, row.walk_y))
		var failure := _route_failure(nearby, route, minf(y, row.walk_y))
		_expect(result, failure.is_empty(), "mural %s: %s" % [row.id, failure])
		if count == 1:
			var fault := MeshKit.new(1)
			var blocker := Vector2(row.walk_outer)
			fault.box(Vector3(1.6, 1.8, 1.6),
				Vector3(blocker.x, minf(y, row.walk_y) + 0.9, blocker.y), 0)
			var broken := nearby.duplicate()
			broken.append_array(Probe._triangles(fault.commit()))
			_expect(result, not _route_failure(broken, route, minf(y, row.walk_y)).is_empty(),
				"mural route accepted a mesh-only masonry blocker")
	_expect(result, count == 6, "README fixture should retain all six occupied mural towers")
	result.note("Mural towers: %d occupied shells, internal navigation and emitted wall-walk joins" % count)


static func _near_route(triangles: Array, route: Array[Vector2], y: float) -> Array:
	return Routes.near_route(triangles, route, y)


static func _route_failure(triangles: Array, route: Array[Vector2], expected_y: float) -> String:
	return Routes.route_failure(triangles, route, expected_y)


static func _expect(result: SuiteResult, passed: bool, detail: String) -> void:
	result.checked += 1
	if not passed:
		result.fail(detail)
