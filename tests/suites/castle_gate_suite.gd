extends RefCounted
## Gatehouse windows belong to a room reached from the curtain walk.
const Routes = preload("res://src/castle/castle_route_check.gd")
const Probe = preload("res://tests/suites/stone_shell_suite.gd")


static func check_fixture(result: SuiteResult, _spec: CastleSpec,
		builder: CastleBuilder, mesh: ArrayMesh) -> void:
	var triangles := Routes.masonry_triangles(mesh)
	var count := 0
	for row in builder.interiors:
		if not bool(row.get("gate_chamber", false)):
			continue
		count += 1
		var plan: HousePlan = row.plan
		_expect(result, plan.rooms.size() == 1 and plan.windows.size() == 3,
			"gate guard chamber must back all three front lights")
		var report := HouseQA.new().check(plan, null)
		_expect(result, report.ok, "gate %s: %s" % [row.id, report.failures])
		var route: Array[Vector2] = []
		route.assign(row.walk_route)
		var nearby := Routes.near_route(triangles, route, float(row.walk_y))
		var failure := Routes.route_failure(nearby, route, float(row.walk_y))
		_expect(result, failure.is_empty(), "gate %s gallery: %s" % [row.id, failure])
		var fault := MeshKit.new(1)
		var at: Vector2 = route[1].lerp(route[2], 0.5)
		fault.box(Vector3(0.12, 1.8, 1.5), Vector3(at.x, float(row.walk_y) + 0.9, at.y), 0)
		nearby.append_array(Probe._triangles(fault.commit()))
		_expect(result, not Routes.route_failure(nearby, route, float(row.walk_y)).is_empty(),
			"gate gallery accepted a mesh-only wall across its access route")
	_expect(result, count == 1, "README fixture has no occupied gatehouse chamber")


static func _expect(result: SuiteResult, passed: bool, detail: String) -> void:
	result.checked += 1
	if not passed:
		result.fail(detail)
