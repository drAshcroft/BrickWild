extends RefCounted
## WLD-016 emitted-triangle checks for the stepwell, each with a log-retaining
## removal (or, for apertures, insertion) mutation that must fail the check.


static func run() -> SuiteResult:
	var res := SuiteResult.new("stepwell mesh support")
	var made := _fresh()
	var plan: HousePlan = made.plan
	var builder: VavBuilder = made.builder
	var mesh: ArrayMesh = made.mesh
	res.checked += 1
	var baseline := VavCheck.new().check(plan, builder, mesh)
	if not baseline["ok"]:
		res.fail("reference stepwell mesh failed its contract: %s" % str(baseline["failures"]))
	res.checked += 1
	var builder_only := VavCheck.new().check(plan, builder)
	if not builder_only["ok"]:
		res.fail("builder-only stepwell check (no supplied mesh) failed: %s" %
			str(builder_only["failures"]))
	var before_masses: Array = builder.mass_log.duplicate(true)
	var before_components: Array = builder.component_log.duplicate(true)

	var landing: Rect2 = plan.rooms[3]["rect"]
	var landing_y := float(plan.rooms[3]["elevation"])
	_remove(res, "landing floor", plan, builder, mesh, VavBuilder.STONE,
		MeshProbe.top_face_in(landing, landing_y), "mesh_support: landing 3")

	var flight: Dictionary = plan.stairs[2]
	var rect: Rect2 = flight["rect"]
	var steps := int(flight["steps"])
	var depth := rect.size.x / float(steps)
	var step_height := (float(flight["lower_y"]) - float(flight["upper_y"])) / float(steps)
	var tread := Rect2(Vector2(rect.end.x - 2.0 * depth, rect.position.y),
		Vector2(depth, rect.size.y))
	_remove(res, "stair tread", plan, builder, mesh, VavBuilder.TRIM,
		MeshProbe.top_face_in(tread, float(flight["lower_y"]) - 2.0 * step_height),
		"mesh_support: flight 2 has 1 of")

	var pavilion: Dictionary = plan.world_meta["pavilions"][3]
	var roof_y := float(pavilion["y"]) + 2.8 + 0.38
	var roof_rect := Rect2(pavilion["center"] - pavilion["size"] * 0.5, pavilion["size"])
	_remove(res, "pavilion roof", plan, builder, mesh, VavBuilder.TRIM,
		MeshProbe.top_face_in(roof_rect, roof_y), "mesh_support: %s roof" % pavilion["id"])

	var column_box := _mass_box(builder, "%s_column" % pavilion["id"])
	_remove(res, "pavilion column", plan, builder, mesh, VavBuilder.STONE,
		MeshProbe.any_face_in(column_box), "mesh_support: %s lost" % pavilion["id"])

	var tank: Rect2 = plan.world_meta["tank"]
	var water_y := float(plan.world_meta["water_y"]) + 0.08
	_remove(res, "tank water", plan, builder, mesh, VavBuilder.WATER,
		MeshProbe.top_face_in(tank, water_y), "mesh_support: tank water")

	var walls := AABB()
	var first := true
	for mass in builder.mass_log:
		if String(mass["name"]) == "tank_wall":
			walls = mass["aabb"] if first else walls.merge(mass["aabb"])
			first = false
	var wall_predicate := func(a: Vector3, b: Vector3, c: Vector3) -> bool:
		var centre := (a + b + c) / 3.0
		return centre.y > walls.position.y + 0.58 and centre.y < walls.end.y + 0.01 \
			and not tank.grow(-0.6).has_point(Vector2(centre.x, centre.z)) \
			and tank.grow(0.1).has_point(Vector2(centre.x, centre.z))
	_remove(res, "tank walls", plan, builder, mesh, VavBuilder.STONE,
		wall_predicate, "mesh_enclosure: tank leaks")

	var shaft: Rect2 = plan.world_meta["shaft"]
	var cap := AABB(Vector3(shaft.get_center().x - 0.4, 20.0, shaft.get_center().y - 0.4),
		Vector3(0.8, 0.5, 0.8))
	_insert(res, "shaft cap", plan, builder, mesh, VavBuilder.STONE, cap,
		"mesh_aperture: draw shaft core is blocked")

	var stair_centre: Vector2 = rect.get_center()
	var roof := AABB(Vector3(stair_centre.x - 0.6, 25.0, stair_centre.y - 0.6),
		Vector3(1.2, 0.4, 1.2))
	_insert(res, "stair roof", plan, builder, mesh, VavBuilder.TRIM, roof,
		"mesh_aperture: 1 of 7 flights are covered")

	res.checked += 1
	if builder.mass_log != before_masses or builder.component_log != before_components:
		res.fail("mesh negative controls changed the emitted logs")
	return res


static func _fresh() -> Dictionary:
	var made := VavGenerator.generate(1017, 65.0, 20.0, 28.0)
	var builder := VavBuilder.new()
	var mesh: ArrayMesh = builder.build(made["plan"])
	return {"plan": made["plan"], "builder": builder, "mesh": mesh}


static func _mass_box(builder: VavBuilder, name: String) -> AABB:
	var box := AABB()
	var first := true
	for mass in builder.mass_log:
		if String(mass["name"]) == name:
			box = mass["aabb"] if first else box.merge(mass["aabb"])
			first = false
	return box.grow(0.05)


static func _remove(res: SuiteResult, label: String, plan: HousePlan,
		builder: VavBuilder, mesh: ArrayMesh, surface: int, predicate: Callable,
		needle: String) -> void:
	res.checked += 1
	var cut := MeshProbe.remove_triangles(mesh, surface, predicate)
	if int(cut["removed_triangles"]) == 0:
		res.fail("%s control removed no actual triangles" % label)
		return
	_expect(res, label, VavCheck.new().check(plan, builder, cut["mesh"]), needle)


static func _insert(res: SuiteResult, label: String, plan: HousePlan,
		builder: VavBuilder, mesh: ArrayMesh, surface: int, box: AABB,
		needle: String) -> void:
	res.checked += 1
	var added := MeshProbe.add_box(mesh, surface, box)
	if added["mesh"] == null:
		res.fail("%s control could not add triangles" % label)
		return
	_expect(res, label, VavCheck.new().check(plan, builder, added["mesh"]), needle)


static func _expect(res: SuiteResult, label: String, report: Dictionary,
		needle: String) -> void:
	for failure in report.get("failures", []):
		if String(failure).contains(needle):
			return
	res.fail("%s escaped stepwell mesh QA (wanted '%s'): %s" %
		[label, needle, str(report.get("failures", []))])
