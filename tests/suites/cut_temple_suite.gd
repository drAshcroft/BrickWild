class_name CutTempleSuite
extends RefCounted
## WLD-015 focused gate: family API, retained cut, emitted rules and controls.


static func run() -> SuiteResult:
	var res := SuiteResult.new("world rock-cut temple")
	var request := _request()
	var building: GeneratedBuilding = BrickWild.generate(request)
	res.checked += 1
	if building == null or not building.is_ok():
		res.fail("Quarried Temple did not generate: %s" %
			(str(building.errors) if building != null else "null"))
		return res
	if building.plan.world_family != CutTempleGenerator.FAMILY \
			or building.plan.world_subkind != CutTempleGenerator.SUBKIND:
		res.fail("Quarried Temple family identity was not retained")
	var pit: Rect2 = building.plan.world_meta.get("pit", Rect2())
	if pit.size.distance_to(Vector2(82.0, 46.0)) > 0.02 \
			or absf(float(building.plan.world_meta.get("pit_floor_y", 0.0)) + 30.0) > 0.02:
		res.fail("Quarried Temple does not retain its 82x46x30m cut")
	var mesh := BrickWild.build_mesh(building)
	if mesh == null or mesh.get_surface_count() < 3:
		res.fail("Quarried Temple did not emit rock, carving and roof surfaces")
	var footprint: Rect2 = BrickWild.placement(building).get("footprint", Rect2())
	if footprint.position.distance_to(pit.position) > 0.02 or footprint.size.distance_to(pit.size) > 0.02:
		res.fail("rock-cut placement does not publish the pit as its site")
	var report := BrickWild.check(building)
	if not bool(report.get("ok", false)):
		res.fail("Quarried Temple public API check reports failure")
	for diagnostic in report.get("diagnostics", []):
		if String(diagnostic.get("severity", "")) == "error":
			res.fail("Quarried Temple: %s" % String(diagnostic.get("message", diagnostic)))
	if not WorldFamilies.has_family(CutTempleGenerator.FAMILY) \
			or WorldFamilies.kinds_of(CutTempleGenerator.FAMILY) != [CutTempleGenerator.SUBKIND]:
		res.fail("world family registry does not publish rock_cut_temple / quarried_temple")
	var document := BrickWild.generate_document(request)
	res.checked += 1
	if not document.is_ok() or document.plan == null \
			or document.plan.world_family != CutTempleGenerator.FAMILY \
			or BrickWild.build_mesh(document) == null:
		res.fail("rock-cut family did not survive the public document path")
	var restored := BuildingDocument.from_json(document.to_json())
	res.checked += 1
	if not restored.is_ok() or restored.plan == null \
			or restored.plan.world_family != CutTempleGenerator.FAMILY \
			or BrickWild.build_mesh(restored) == null:
		res.fail("negative-storey rock-cut plan did not survive document serialization")
	_fixtures(res)
	return res


static func _request() -> BuildingRequest:
	var request := BuildingRequest.new()
	request.kind = &"world"
	request.style = CutTempleGenerator.FAMILY
	request.purpose = CutTempleGenerator.SUBKIND
	request.seed = 1015
	request.width = 82.0
	request.length = 46.0
	request.height = 30.0
	return request


static func _fixture() -> Dictionary:
	var made := CutTempleGenerator.generate(1515, 82.0, 46.0, 30.0)
	var builder := CutTempleBuilder.new()
	builder.build(made["plan"])
	return {"plan": made["plan"], "builder": builder}


static func _expect(res: SuiteResult, label: String, fixture: Dictionary,
		prefix: String) -> void:
	res.checked += 1
	var report := CutCheck.new().check(fixture["plan"], fixture["builder"])
	for failure in report.get("failures", []):
		if String(failure).begins_with(prefix + ":"):
			return
	res.fail("negative cut fixture %s did not fail %s" % [label, prefix])


static func _fixtures(res: SuiteResult) -> void:
	var raised := _fixture()
	raised["builder"].mass_log.append({"name": "raised_fixture",
		"aabb": AABB(Vector3(-1, -0.2, 0), Vector3(2, 1.0, 2))})
	_expect(res, "mass above grade", raised, "negative")

	var wall_touch := _fixture()
	var site: Rect2 = wall_touch["plan"].world_meta["site"]
	for mass in wall_touch["builder"].mass_log:
		if mass["name"] == "nandi_plinth":
			var a: AABB = mass["aabb"]
			a.position.x = site.position.x
			mass["aabb"] = a
			break
	_expect(res, "temple against cut face", wall_touch, "free-standing")

	var no_bridge := _fixture()
	no_bridge["builder"].mass_log = no_bridge["builder"].mass_log.filter(
		func(mass: Dictionary) -> bool: return mass.get("name", "") != "bridge")
	_expect(res, "missing bridge", no_bridge, "bridge")

	var off_axis := _fixture()
	var marks: Array = off_axis["plan"].world_meta["axis_marks"]
	var sanctum: Rect2 = marks[4]["rect"]
	marks[4]["rect"] = Rect2(sanctum.position + Vector2(5.0, 0.0), sanctum.size)
	_expect(res, "crooked sanctum", off_axis, "axis")

	var roofed := _fixture()
	var sky: Rect2 = roofed["plan"].world_meta["sky_rect"]
	roofed["builder"].mass_log.append({"name": "court_canopy",
		"aabb": AABB(Vector3(sky.position.x, -7.0, sky.position.y),
			Vector3(sky.size.x, 0.5, sky.size.y))})
	_expect(res, "roofed pit", roofed, "sky")

	var broken_gallery := _fixture()
	broken_gallery["plan"].world_meta["gallery"].remove_at(2)
	_expect(res, "missing wall gallery", broken_gallery, "gallery")
