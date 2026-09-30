extends RefCounted
## CAS-REG-002: the Crusader inner gate towers must leave the outer wall stairs
## clear in both logged bounds and emitted geometry.

static func run() -> SuiteResult:
	var result := SuiteResult.new("castle gate and wall stair clearance")
	var spec := CastleSpec.new()
	spec.style = &"crusader"
	spec.width = 90.0
	spec.length = 140.0
	spec.height = 20.0
	CastleGenerator.generate(spec, 9118)
	var builder := CastleBuilder.new()
	builder.spec = spec
	builder.begin(4)
	for ring in CastleGeometry.rings(spec):
		builder._build_ring(ring)
	builder._build_wall_stairs()
	var mesh := builder.commit()
	NormalsSuite.check_mesh(result, mesh, "Crusader 9118 gate/stair mesh")
	NormalsSuite.check_openings(result, builder, "Crusader 9118 gate/stair mesh")
	var check := CastleMassingCheck.new()
	check._check_wall_stairs(spec, builder)
	_expect(result, check.failures.is_empty(), "Crusader 9118 stair routes: " + str(check.failures))
	_expect(result, ComponentCheck.check(builder, mesh).ok,
		"Crusader 9118 stair component log differs from emitted triangles")
	var gates: Array = builder.mass_log.filter(func(row): return String(row.name).begins_with("tower_") and "_gate_" in String(row.name))
	var stairs: Array = builder.mass_log.filter(func(row): return String(row.name).begins_with("wall_stair_"))
	var overlaps := _gate_stair_overlaps(gates, stairs)
	_expect(result, gates.size() == 4, "expected all four gate-tower mass records; got %d" % gates.size())
	_expect(result, stairs.size() == 4, "expected both stair routes on both rings; got %d" % stairs.size())
	_expect(result, overlaps.is_empty(), "gate tower and wall stair bounds overlap: " + str(overlaps))
	# A deliberate overlap proves the clearance probe would reject the original
	# seed 9118 defect. The production rows above remain untouched.
	if not gates.is_empty() and not stairs.is_empty():
		var intruding_gate: Dictionary = gates[0].duplicate()
		intruding_gate["aabb"] = stairs[0].aabb
		_expect(result, not _gate_stair_overlaps([intruding_gate], [stairs[0]]).is_empty(),
			"gate/stair overlap negative control was not detected")
	var gate_report := CastleQA.gate_access_report(spec, builder, mesh)
	_expect(result, gate_report.failures.is_empty(), "gate passage access: " + str(gate_report.failures))
	var triangles: Array = []
	for surface in mesh.get_surface_count():
		triangles.append_array(HouseQA._mesh_triangles(mesh, surface))
	var blocked_routes: Array[String] = []
	for row in builder.component_log:
		if row.role not in ["wall_stair_tread", "wall_stair_landing"]:
			continue
		var centre: Vector3 = row.xf.origin + Vector3.UP * row.size.y * 0.5
		if _hit(triangles, centre + Vector3.UP * 0.05, centre + Vector3.UP * 1.95):
			blocked_routes.append("%s/%s" % [row.host, row.role])
	_expect(result, blocked_routes.is_empty(), "stair headroom obstructed: " + str(blocked_routes))
	print("GATE_STAIR crusader seed=9118 gates=", gates.size(), " stairs=", stairs.size(),
		" failures=", result.failures.size())
	return result


static func _hit(triangles: Array, from: Vector3, to: Vector3) -> bool:
	for tri in triangles:
		if Geometry3D.segment_intersects_triangle(from, to, tri[0], tri[1], tri[2]) != null:
			return true
	return false


static func _gate_stair_overlaps(gates: Array, stairs: Array) -> Array[String]:
	var overlaps: Array[String] = []
	for gate in gates:
		for stair in stairs:
			var hit: AABB = gate.aabb.intersection(stair.aabb)
			if hit.size.x > 0.001 and hit.size.z > 0.001:
				overlaps.append("%s / %s (%0.2f x %0.2f m)" % [gate.name, stair.name, hit.size.x, hit.size.z])
	return overlaps


static func _expect(result: SuiteResult, ok: bool, message: String) -> void:
	result.checked += 1
	if not ok:
		result.fail(message)
		print("FAIL: ", message)
