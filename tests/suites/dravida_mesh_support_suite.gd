extends RefCounted
## WLD-014 emitted-triangle checks for the Dravida prakara, each with a
## log-retaining mutation that must fail the production check.


static func run() -> SuiteResult:
	var res := SuiteResult.new("Dravida mesh support")
	for period in [900, 1450]:
		_period(res, period)
	return res


static func _period(res: SuiteResult, period: int) -> void:
	var made := _fresh(period)
	var plan: HousePlan = made.plan
	var builder: DravidaBuilder = made.builder
	var mesh: ArrayMesh = made.mesh
	var label := "period %d" % period
	res.checked += 1
	var baseline := PrakaraCheck.new().check(plan, builder, mesh)
	if not baseline["ok"]:
		res.fail("%s: reference mesh failed its contract: %s" % [label, str(baseline["failures"])])
	res.checked += 1
	var builder_only := PrakaraCheck.new().check(plan, builder)
	if not builder_only["ok"]:
		res.fail("%s: builder-only check (no supplied mesh) failed: %s" %
			[label, str(builder_only["failures"])])
	if period != 900:
		return
	var before_masses: Array = builder.mass_log.duplicate(true)
	var before_components: Array = builder.component_log.duplicate(true)
	var meta: Dictionary = plan.world_meta

	var side: Rect2 = meta["colonnade"][2]
	_remove(res, "colonnade floor", plan, builder, mesh, DravidaBuilder.TRIM,
		MeshProbe.top_face_in(side, 0.28), "mesh_support: colonnade side 2")
	_remove(res, "mandapa floor", plan, builder, mesh, DravidaBuilder.STONE,
		MeshProbe.top_face_in(meta["hall"], 0.3), "mesh_support: mandapa floor")
	_remove(res, "mandapa roof", plan, builder, mesh, DravidaBuilder.ROOF,
		MeshProbe.top_face_in(meta["hall"], 11.25), "mesh_support: mandapa roof")
	_remove(res, "sanctum roof", plan, builder, mesh, DravidaBuilder.TRIM,
		MeshProbe.top_face_in(meta["sanctum"], 8.69), "mesh_support: sanctum roof")
	var gate: Dictionary = meta["gates"][0]
	var gate_z := float((gate["center"] as Vector3).z)
	_remove(res, "gopuram roof", plan, builder, mesh, DravidaBuilder.ROOF,
		MeshProbe.top_face_in(Rect2(Vector2(-6.0, gate_z - 4.0), Vector2(12.0, 8.0)),
			float(meta["gopuram_height"])), "mesh_support: %s tower roof" % gate["id"])
	var tiers: Array = meta["vimana_tiers"]
	var crown: Dictionary = tiers.back()
	var centre: Vector3 = meta["vimana_center"]
	var width := float(crown["width"])
	_remove(res, "vimana crown", plan, builder, mesh, DravidaBuilder.TRIM,
		MeshProbe.top_face_in(Rect2(Vector2(centre.x, centre.z) - Vector2(width, width) * 0.5,
			Vector2(width, width)), float(crown["base_y"]) + float(crown["height"]) + 0.175),
		"mesh_support: vimana crown")
	var east := _mass_box(builder, "prakara_right")
	_remove(res, "prakara wall", plan, builder, mesh, DravidaBuilder.STONE,
		MeshProbe.any_face_in(east), "mesh_enclosure: prakara east")
	var rear := _mass_box(builder, "sanctum_rear")
	_remove(res, "sanctum rear wall", plan, builder, mesh, DravidaBuilder.STONE,
		MeshProbe.any_face_in(rear), "mesh_enclosure: sanctum rear")
	var plug := AABB(Vector3(-2.0, 0.0, gate_z - 1.0), Vector3(4.0, 3.0, 2.0))
	_insert(res, "gopuram plug", plan, builder, mesh, DravidaBuilder.STONE, plug,
		"mesh_aperture: %s passage is closed" % gate["id"])
	var sanctum: Rect2 = meta["sanctum"]
	var door := AABB(Vector3(-1.0, 0.0, sanctum.position.y + 0.1), Vector3(2.0, 3.5, 0.3))
	_insert(res, "sanctum door plug", plan, builder, mesh, DravidaBuilder.STONE, door,
		"mesh_aperture: sanctum door is closed")

	res.checked += 1
	if builder.mass_log != before_masses or builder.component_log != before_components:
		res.fail("mesh negative controls changed the emitted logs")


static func _fresh(period: int) -> Dictionary:
	var made := DravidaGenerator.generate(&"god_kings_precinct", 14015, 240.0, 120.0, 63.0, period)
	var builder := DravidaBuilder.new()
	var mesh: ArrayMesh = builder.build(made["plan"])
	return {"plan": made["plan"], "builder": builder, "mesh": mesh}


static func _mass_box(builder: DravidaBuilder, name: String) -> AABB:
	for mass in builder.mass_log:
		if String(mass["name"]) == name:
			return (mass["aabb"] as AABB).grow(0.05)
	return AABB()


static func _remove(res: SuiteResult, label: String, plan: HousePlan,
		builder: DravidaBuilder, mesh: ArrayMesh, surface: int, predicate: Callable,
		needle: String) -> void:
	res.checked += 1
	var cut := MeshProbe.remove_triangles(mesh, surface, predicate)
	if int(cut["removed_triangles"]) == 0:
		res.fail("%s control removed no actual triangles" % label)
		return
	_expect(res, label, PrakaraCheck.new().check(plan, builder, cut["mesh"]), needle)


static func _insert(res: SuiteResult, label: String, plan: HousePlan,
		builder: DravidaBuilder, mesh: ArrayMesh, surface: int, box: AABB,
		needle: String) -> void:
	res.checked += 1
	var added := MeshProbe.add_box(mesh, surface, box)
	if added["mesh"] == null:
		res.fail("%s control could not add triangles" % label)
		return
	_expect(res, label, PrakaraCheck.new().check(plan, builder, added["mesh"]), needle)


static func _expect(res: SuiteResult, label: String, report: Dictionary,
		needle: String) -> void:
	for failure in report.get("failures", []):
		if String(failure).contains(needle):
			return
	res.fail("%s escaped Dravida mesh QA (wanted '%s'): %s" %
		[label, needle, str(report.get("failures", []))])
