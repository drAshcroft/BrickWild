class_name VavSuite
extends RefCounted
## WLD-016 focused gate: Queen's Well API, emitted descent, and negative controls.

static func run() -> SuiteResult:
	var res := SuiteResult.new("world stepwell / Vav")
	var request := _request()
	var building: GeneratedBuilding = BigGlade.generate(request)
	res.checked += 1
	if building == null or not building.is_ok():
		res.fail("Queen's Well did not generate: %s" %
			str(building.errors) if building != null else "null")
		return res
	if building.plan.world_family != &"stepwell" or building.plan.world_subkind != &"queens_well":
		res.fail("Queen's Well family identity was not retained in its HousePlan")
	var tank: Rect2 = building.plan.world_meta.get("tank", Rect2())
	if absf(float(building.plan.world_meta.get("total_drop", 0.0)) - 23.0) > 0.02 \
			or absf(tank.size.x - 9.5) > 0.02 or absf(tank.size.y - 9.4) > 0.02 \
			or building.plan.stairs.size() != 7 or building.plan.rooms.size() != 8:
		res.fail("Queen's Well does not retain its seven-flight, 23 m, 9.5 x 9.4 m descent")
	var mesh: ArrayMesh = BigGlade.build_mesh(building)
	if mesh == null or mesh.get_surface_count() < 3:
		res.fail("Queen's Well did not emit stone, trim and water surfaces")
	var footprint: Rect2 = BigGlade.placement(building).get("footprint", Rect2())
	if absf(footprint.size.x - 65.0) > 0.02 or absf(footprint.size.y - 20.0) > 0.02:
		res.fail("stepwell placement does not publish the authored site footprint")
	var report := BigGlade.check(building)
	if not bool(report.get("ok", false)):
		res.fail("Queen's Well public API check reports a failure")
	for failure in report.get("failures", []):
		res.fail("Queen's Well: %s" % String(failure))
	if not WorldFamilies.has_family(&"stepwell") \
			or WorldFamilies.kinds_of(&"stepwell") != [&"queens_well"]:
		res.fail("world family registry does not publish stepwell / queens_well")
	var document := BigGlade.generate_document(request)
	res.checked += 1
	if not document.is_ok() or document.plan == null \
			or document.plan.world_family != &"stepwell" or BigGlade.build_mesh(document) == null:
		res.fail("stepwell family did not survive the public building document path")
	var restored := BuildingDocument.from_json(document.to_json())
	res.checked += 1
	if not restored.is_ok() or restored.plan == null \
			or restored.plan.world_family != &"stepwell" or BigGlade.build_mesh(restored) == null:
		res.fail("stepwell negative-storey plan did not survive document serialization")
	_fixtures(res)
	return res


static func _request() -> BuildingRequest:
	var request := BuildingRequest.new()
	request.kind = &"world"
	request.style = &"stepwell"
	request.purpose = &"queens_well"
	request.seed = 1016
	request.width = 65.0
	request.length = 20.0
	request.height = 28.0
	return request


static func _fixture() -> Dictionary:
	var made := VavGenerator.generate(1017, 65.0, 20.0, 28.0)
	var builder := VavBuilder.new()
	builder.build(made["plan"])
	return {"plan": made["plan"], "builder": builder}


static func _expect(res: SuiteResult, label: String, fixture: Dictionary, prefix: String) -> void:
	res.checked += 1
	var report := VavCheck.new().check(fixture["plan"], fixture["builder"])
	for failure in report.get("failures", []):
		if String(failure).begins_with(prefix + ":"):
			return
	res.fail("negative stepwell fixture %s did not fail %s" % [label, prefix])


static func _fixtures(res: SuiteResult) -> void:
	var broken_descent := _fixture()
	broken_descent["plan"].stairs.remove_at(3)
	_expect(res, "missing flight", broken_descent, "descent")
	var unbuilt_flight := _fixture()
	unbuilt_flight["builder"].mass_log = unbuilt_flight["builder"].mass_log.filter(
		func(mass: Dictionary) -> bool: return not String(mass.get("name", "")).begins_with("stair_2_tread_"))
	_expect(res, "unemitted flight", unbuilt_flight, "descent")

	var wrong_storey := _fixture()
	wrong_storey["plan"].rooms[2]["storey"] = 2
	_expect(res, "raised level", wrong_storey, "descent")
	var steep := _fixture()
	steep["plan"].stairs[0]["run"] = 1.0
	_expect(res, "steep flight", steep, "descent")
	var broken_profile := _fixture()
	var profile_rect: Rect2 = broken_profile["plan"].rooms[2]["rect"]
	var previous_rect: Rect2 = broken_profile["plan"].rooms[1]["rect"]
	broken_profile["plan"].rooms[2]["rect"] = Rect2(profile_rect.position,
		Vector2(previous_rect.size.x + 1.0, profile_rect.size.y))
	_expect(res, "widening tier", broken_profile, "narrowing")

	var missing_pavilion := _fixture()
	missing_pavilion["builder"].mass_log = missing_pavilion["builder"].mass_log.filter(
		func(mass: Dictionary) -> bool: return mass.get("name", "") != "pavilion_1")
	_expect(res, "missing pavilion", missing_pavilion, "pavilions")

	var missing_tank := _fixture()
	missing_tank["builder"].mass_log = missing_tank["builder"].mass_log.filter(
		func(mass: Dictionary) -> bool: return mass.get("name", "") != "tank_floor")
	_expect(res, "missing tank", missing_tank, "tank")

	var missing_shaft := _fixture()
	missing_shaft["builder"].mass_log = missing_shaft["builder"].mass_log.filter(
		func(mass: Dictionary) -> bool: return not String(mass.get("name", "")).begins_with("shaft_wall"))
	_expect(res, "missing draw shaft", missing_shaft, "shaft")
	var crooked_shaft := _fixture()
	var shaft_components: Array[Dictionary] = crooked_shaft["builder"].components_of("draw_shaft")
	var shaft_component: Dictionary = shaft_components[0]
	var shaft_xf: Transform3D = shaft_component["xf"]
	shaft_component["xf"] = Transform3D(shaft_xf.basis, shaft_xf.origin + Vector3(2.0, 0.0, 0.0))
	_expect(res, "off-axis shaft wall", crooked_shaft, "shaft")

	var missing_water := _fixture()
	missing_water["builder"].mass_log = missing_water["builder"].mass_log.filter(
		func(mass: Dictionary) -> bool: return mass.get("name", "") != "water")
	_expect(res, "dry tank", missing_water, "water")

	var blocked_edge := _fixture()
	blocked_edge["plan"].world_meta["tank_walk"] = []
	_expect(res, "inaccessible tank", blocked_edge, "water")

	var covered_corridor := _fixture()
	covered_corridor["builder"].mass_log.append({"name": "roof_fixture",
		"aabb": AABB(Vector3(0.0, 0.2, -8.0), Vector3(2.0, 0.6, 1.0))})
	_expect(res, "roof over stair", covered_corridor, "sky")
