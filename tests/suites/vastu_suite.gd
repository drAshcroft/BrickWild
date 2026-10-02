class_name VastuSuite
extends RefCounted
## WLD-019 bounded gate: public haveli plus one negative control per rule.


static func run() -> SuiteResult:
	var res := SuiteResult.new("world vastu haveli")
	var request := BuildingRequest.new()
	request.kind = &"world"
	request.style = &"vastu"
	request.purpose = &"merchants_haveli"
	request.seed = 1019
	request.width = 15.0
	request.length = 28.0
	request.height = 10.0
	var building: GeneratedBuilding = BrickWild.generate(request)
	res.checked += 1
	if building == null or not building.is_ok() or building.plan == null:
		res.fail("Merchant's Haveli did not generate through the public API")
		return res
	var mesh := BrickWild.build_mesh(building)
	var report := BrickWild.check(building)
	if mesh == null or mesh.get_surface_count() < 4 or not bool(report.get("ok", false)):
		res.fail("Merchant's Haveli public mesh/check contract failed: %s" %
			str(report.get("diagnostics", [])))
	var restored := BuildingDocument.from_json(BrickWild.generate_document(request).to_json())
	res.checked += 1
	if not restored.is_ok() or restored.plan == null \
			or restored.plan.world_family != &"vastu" or BrickWild.build_mesh(restored) == null:
		res.fail("haveli did not survive the public document round trip")

	var broken_centre := _fixture()
	broken_centre["plan"].world_meta["court_rect"] = Rect2(Vector2(2, 2), Vector2(2, 2))
	_expect(res, "shifted court", broken_centre, "brahmasthana")
	var broken_kitchen := _fixture()
	var kitchen := int(broken_kitchen["plan"].world_meta["kitchen_room"])
	broken_kitchen["plan"].rooms[kitchen]["rect"] = Rect2(Vector2(-6, 3), Vector2(2, 2))
	_expect(res, "north-west kitchen", broken_kitchen, "agni")
	var broken_well := _fixture()
	broken_well["plan"].world_meta["well_rect"] = Rect2(Vector2(-6, -12), Vector2.ONE)
	_expect(res, "south-west well", broken_well, "jal")
	var broken_door := _fixture()
	broken_door["plan"].doors[broken_door["plan"].entrance()]["normal"] = Vector2(0, 1)
	_expect(res, "south door", broken_door, "door")
	var broken_light := _fixture()
	broken_light["plan"].world_meta["eave_height"] = 2.0
	_expect(res, "wide light well", broken_light, "light_well")
	var broken_projection := _fixture()
	broken_projection["builder"].mass_log = broken_projection["builder"].mass_log.filter(
		func(row: Dictionary) -> bool:
			return not String(row.get("name", "")).begins_with("jharokha"))
	_expect(res, "missing projection", broken_projection, "jharokha")
	return res


static func _fixture() -> Dictionary:
	var made := VastuGenerator.generate(2019, 15.0, 28.0, 10.0)
	var builder := HouseBuilder.new()
	builder.build(made["plan"])
	return {"plan": made["plan"], "builder": builder}


static func _expect(res: SuiteResult, label: String, fixture: Dictionary,
		prefix: String) -> void:
	res.checked += 1
	var report := VastuCheck.new().check(fixture["plan"], fixture["builder"])
	for failure in report.get("failures", []):
		if String(failure).begins_with(prefix + ":"):
			return
	res.fail("negative vastu fixture %s did not fail %s" % [label, prefix])
