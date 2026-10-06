extends RefCounted
## WLD-011 emitted-triangle checks for the temple mountain, each with a
## log-retaining mutation that must fail the production check.


static func run() -> SuiteResult:
	var res := SuiteResult.new("temple mountain mesh support")
	var made := _fresh()
	var plan: HousePlan = made.plan
	var builder: MountainBuilder = made.builder
	var mesh: ArrayMesh = made.mesh
	res.checked += 1
	var baseline := MountainCheck.new().check_mountain(plan, builder, mesh)
	if not baseline["ok"]:
		res.fail("reference mountain mesh failed its contract: %s" % str(baseline["failures"]))
	res.checked += 1
	var builder_only := MountainCheck.new().check_mountain(plan, builder)
	if not builder_only["ok"]:
		res.fail("builder-only mountain check (no supplied mesh) failed: %s" %
			str(builder_only["failures"]))
	var before_masses: Array = builder.mass_log.duplicate(true)
	var before_components: Array = builder.component_log.duplicate(true)
	var meta: Dictionary = plan.world_meta
	var rings: Array = meta["rings"]

	_remove(res, "causeway", plan, builder, mesh, MountainBuilder.STONE,
		MeshProbe.top_face_in(meta["causeway"], 0.08), "mesh_support: causeway")
	var side: Rect2 = MountainGenerator.gallery_segments(rings[1])[2]
	_remove(res, "gallery floor", plan, builder, mesh, MountainBuilder.STONE,
		MeshProbe.top_face_in(side, float(rings[1]["level"])), "mesh_support: gallery 1 side 2")
	var stair: Dictionary = meta["stairs"][3]
	_remove(res, "stair step", plan, builder, mesh, MountainBuilder.STONE,
		MeshProbe.top_face_in(stair["rect"], float(stair["level"]) + float(stair["rise"])),
		"mesh_support: %s" % stair["id"])
	_remove(res, "summit", plan, builder, mesh, MountainBuilder.STONE,
		MeshProbe.top_face_in(meta["summit"], float(meta["summit_level"])),
		"mesh_support: summit")
	var tower := _mass_box(builder, "tower_center")
	_remove(res, "tower roof", plan, builder, mesh, MountainBuilder.ROOF,
		MeshProbe.top_face_in(Rect2(Vector2(tower.position.x, tower.position.z),
			Vector2(tower.size.x, tower.size.z)), tower.end.y - 0.05),
		"mesh_support: tower_center roof")
	var water := _mass_box(builder, "water_1")
	_remove(res, "moat water", plan, builder, mesh, MountainBuilder.WATER,
		MeshProbe.any_face_in(water), "mesh_support: water_1")
	var wall := _mass_box(builder, "enclosure_1_wall_2")
	_remove(res, "ring wall", plan, builder, mesh, MountainBuilder.STONE,
		MeshProbe.any_face_in(wall), "mesh_enclosure: ring 1 east wall")
	var ring: Dictionary = rings[2]
	var rect: Rect2 = ring["rect"]
	var gate_plug := AABB(Vector3(-0.8, float(ring["level"]) + 0.5,
		rect.position.y + float(ring["wall_thickness"]) * 0.5 - 0.3), Vector3(1.6, 1.6, 0.6))
	_insert(res, "gate plug", plan, builder, mesh, MountainBuilder.STONE, gate_plug,
		"mesh_aperture: gopura 2 is closed")

	res.checked += 1
	if builder.mass_log != before_masses or builder.component_log != before_components:
		res.fail("mesh negative controls changed the emitted logs")
	return res


static func _fresh() -> Dictionary:
	var made := MountainGenerator.generate(&"angkor_mountain", 911011, 200.0, 200.0, 60.0)
	var builder := MountainBuilder.new()
	var mesh: ArrayMesh = builder.build(made["plan"])
	return {"plan": made["plan"], "builder": builder, "mesh": mesh}


static func _mass_box(builder: MountainBuilder, name: String) -> AABB:
	for mass in builder.mass_log:
		if String(mass["name"]) == name:
			return (mass["aabb"] as AABB).grow(0.05)
	return AABB()


static func _remove(res: SuiteResult, label: String, plan: HousePlan,
		builder: MountainBuilder, mesh: ArrayMesh, surface: int, predicate: Callable,
		needle: String) -> void:
	res.checked += 1
	var cut := MeshProbe.remove_triangles(mesh, surface, predicate)
	if int(cut["removed_triangles"]) == 0:
		res.fail("%s control removed no actual triangles" % label)
		return
	_expect(res, label, MountainCheck.new().check_mountain(plan, builder, cut["mesh"]), needle)


static func _insert(res: SuiteResult, label: String, plan: HousePlan,
		builder: MountainBuilder, mesh: ArrayMesh, surface: int, box: AABB,
		needle: String) -> void:
	res.checked += 1
	var added := MeshProbe.add_box(mesh, surface, box)
	if added["mesh"] == null:
		res.fail("%s control could not add triangles" % label)
		return
	_expect(res, label, MountainCheck.new().check_mountain(plan, builder, added["mesh"]), needle)


static func _expect(res: SuiteResult, label: String, report: Dictionary,
		needle: String) -> void:
	for failure in report.get("failures", []):
		if String(failure).contains(needle):
			return
	res.fail("%s escaped mountain mesh QA (wanted '%s'): %s" %
		[label, needle, str(report.get("failures", []))])
