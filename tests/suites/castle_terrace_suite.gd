class_name CastleTerraceSuite
extends RefCounted


static func run() -> SuiteResult:
	var res := SuiteResult.new("castle terraced baileys")
	for dims in [Vector3(60.0, 50.0, 15.0), Vector3(76.0, 62.0, 18.0)]:
		var spec := CastleSpec.new(601001 + int(dims.x))
		spec.style = &"japanese"
		spec.width = dims.x
		spec.length = dims.y
		spec.height = dims.z
		spec.tier_override = &"castle"
		spec.plan_override = &"terraced"
		spec.sides_override = 5
		CastleGenerator.generate(spec, spec.seed)
		var builder := CastleBuilder.new()
		var mesh: ArrayMesh = builder.build(spec)
		var who := "terraced %.0fx%.0f" % [dims.x, dims.y]
		if spec.plan_kind != &"terraced" or not spec.inner_ward:
			res.fail("%s: generator did not preserve the two-ring plan" % who)
		if CastleGeometry.plan_sides(spec) < CastleGeometry.POLY_MIN_SIDES:
			res.fail("%s: terraced rings are not polygons" % who)
		var inner_walls := 0
		for mass in builder.mass_log:
			if String(mass["name"]).begins_with("wall_1_"):
				inner_walls += 1
				if not is_equal_approx((mass["aabb"] as AABB).position.y,
						CastleGeometry.ring_ground_y(spec, 1)):
					res.fail("%s: inner curtain is not on its raised ground" % who)
				if not is_equal_approx(float(mass.get("ground", -1.0)),
						CastleGeometry.ring_ground_y(spec, 1)):
					res.fail("%s: inner curtain lost its ground metadata" % who)
		if inner_walls == 0:
			res.fail("%s: no inner curtain was emitted" % who)
		if not builder.has_mass("terrace"):
			res.fail("%s: no filled terrace mass was logged" % who)
		if not builder.has_mass("terrace_stair_"):
			res.fail("%s: no raised stair was logged" % who)
		var terrace: AABB = builder.mass_aabb("terrace")
		if terrace.size.y < 3.0:
			res.fail("%s: terrace fill is under 3 m high" % who)
		var route: Dictionary = CastleQA.terrace_route_report(spec, builder, mesh)
		for failure in route.failures:
			res.fail("%s: %s" % [who, str(failure)])
		var gates: Dictionary = CastleQA.gate_access_report(spec, builder, mesh)
		for failure in gates.failures:
			res.fail("%s: %s" % [who, str(failure)])
		if int(route.floor_samples) < 8 or int(route.support_samples) < 4:
			res.fail("%s: physical stair or terrace-cap probes did not cover both rings" % who)
		_check_mesh_log_parity(spec, builder, mesh, who, res)
		_negative_controls(spec, builder, mesh, who, res)
		var keep: AABB = CastleGeometry.keep_aabb(spec)
		if keep.position.y < 3.0:
			res.fail("%s: keep does not stand on the top terrace" % who)
		var keep_plan := CastleKeepPlan.generate(spec, false)
		if keep_plan.entrance() < 0 or HousePlan.record_storey(keep_plan.doors[keep_plan.entrance()]) != 0:
			res.fail("%s: tenshu entrance is not on the terrace-level base" % who)
		if builder.has_mass("forebuilding"):
			res.fail("%s: terrace-level tenshu should not emit an external stair crossing the ward" % who)
		var report: Dictionary = CastleMassingCheck.new().check(spec, builder)
		for failure in report["failures"]:
			res.fail("%s: %s" % [who, str(failure)])
		res.checked += 1

	var invalid := CastleSpec.new(601099)
	invalid.style = &"japanese"
	invalid.width = 60.0
	invalid.length = 50.0
	invalid.height = 15.0
	invalid.tier_override = &"castle"
	invalid.plan_override = &"terraced"
	invalid.terrace_rise = 2.0
	CastleGenerator.generate(invalid, invalid.seed)
	if invalid.terrace_rise < 3.0:
		res.fail("negative fixture: a terraced rise below 3 m was accepted")
	res.checked += 1
	return res


static func _check_mesh_log_parity(spec: CastleSpec, builder: CastleBuilder,
		mesh: ArrayMesh, who: String, res: SuiteResult) -> void:
	var rise: float = CastleGeometry.ring_ground_y(spec, 1)
	var checked := 0
	for mass in builder.mass_log:
		if not String(mass["name"]).begins_with("wall_1_"):
			continue
		var a: AABB = mass["aabb"]
		var min_y := INF
		var max_y := -INF
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				if a.grow(0.2).has_point(Vector3(vertex.x, clampf(vertex.y, a.position.y,
						a.end.y + CastleGeometry.PARAPET_RISE + spec.merlon_h),
					vertex.z)) and vertex.y >= rise - 0.05 \
						and vertex.y <= a.end.y + CastleGeometry.PARAPET_RISE + spec.merlon_h + 0.05:
					min_y = minf(min_y, vertex.y)
					max_y = maxf(max_y, vertex.y)
		if min_y > rise + 0.05 or max_y < a.end.y - 0.05:
			res.fail("%s: emitted inner curtain vertices do not match logged vertical bounds for %s"
				% [who, String(mass["name"])])
		else:
			checked += 1
	if checked == 0:
		res.fail("%s: no lifted curtain had a triangle/log parity probe" % who)


static func _negative_controls(spec: CastleSpec, builder: CastleBuilder,
		mesh: ArrayMesh, who: String, res: SuiteResult) -> void:
	var checker := CastleMassingCheck.new()
	var terrace_index := -1
	for i in builder.mass_log.size():
		if builder.mass_log[i]["name"] == "terrace":
			terrace_index = i
			break
	if terrace_index >= 0:
		var terrace: Dictionary = builder.mass_log[terrace_index].duplicate(true)
		builder.mass_log.remove_at(terrace_index)
		var report: Dictionary = checker.check(spec, builder)
		if not _has_failure(report, "terrace: logged fill"):
			res.fail("%s: negative control did not detect a missing terrace fill" % who)
		builder.mass_log.insert(terrace_index, terrace)
	else:
		res.fail("%s: missing-terrace negative control could not run" % who)
	var wall_index := -1
	for i in builder.mass_log.size():
		if String(builder.mass_log[i]["name"]).begins_with("wall_1_"):
			wall_index = i
			break
	if wall_index >= 0:
		var wall: Dictionary = builder.mass_log[wall_index]
		var ground: Variant = wall.get("ground", null)
		wall.erase("ground")
		var report2: Dictionary = checker.check(spec, builder)
		if not _has_failure(report2, "is not grounded on the raised floor"):
			res.fail("%s: negative control did not detect missing inner-ground metadata" % who)
		if ground != null:
			wall["ground"] = ground
	var keep_index := -1
	var stair_index := -1
	for i in builder.mass_log.size():
		if builder.mass_log[i]["name"] == "keep":
			keep_index = i
		if builder.mass_log[i]["name"] == "terrace_stair_1":
			stair_index = i
	if keep_index >= 0:
		var keep_row: Dictionary = builder.mass_log[keep_index]
		var keep_a: AABB = keep_row["aabb"]
		keep_row["aabb"] = AABB(keep_a.position, Vector3(keep_a.size.x, 1.0, keep_a.size.z))
		var report3: Dictionary = checker.check(spec, builder)
		if not _has_failure(report3, "10 m clear of every curtain"):
			res.fail("%s: negative control did not detect a short Himeji tenshu" % who)
		keep_row["aabb"] = keep_a
	if stair_index >= 0:
		var stair_row: Dictionary = builder.mass_log[stair_index]
		var stair_a: AABB = stair_row["aabb"]
		stair_row["aabb"] = AABB(stair_a.position + Vector3(0, 0, 3), stair_a.size)
		var report4: Dictionary = checker.check(spec, builder)
		if not _has_failure(report4, "stair does not continuously join"):
			res.fail("%s: negative control did not detect a disconnected terrace stair" % who)
		stair_row["aabb"] = stair_a
	var blocker := MeshKit.new(1)
	blocker.box(Vector3(3.2, 1.9, 0.32),
		Vector3(0.0, spec.terrace_rise * 0.5 + 0.8,
			builder.mass_aabb("terrace_stair_1").get_center().z), CastleBuilder.SURF_STONE)
	var block_mesh := blocker.commit()
	var blocked := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		blocked.add_surface_from_arrays(mesh.surface_get_primitive_type(surface),
			mesh.surface_get_arrays(surface))
	blocked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
		block_mesh.surface_get_arrays(0))
	var blocked_report: Dictionary = CastleQA.terrace_route_report(spec, builder, blocked)
	if not _has_failure(blocked_report, "block body clearance"):
		res.fail("%s: blocking-mesh mutation did not fail the physical stair probe" % who)


static func _has_failure(report: Dictionary, phrase: String) -> bool:
	for failure in report.get("failures", []):
		if String(failure).contains(phrase):
			return true
	return false
