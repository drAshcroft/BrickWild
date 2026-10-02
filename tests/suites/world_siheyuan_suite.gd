class_name WorldSiheyuanSuite
extends RefCounted
## WLD-007 focused contract, including one deliberate fixture per rule.


static func run() -> SuiteResult:
	var res := SuiteResult.new("siheyuan")
	var request := _request(22007)
	request.orientation = PI / 2.0
	request.period = 1400
	var building: GeneratedBuilding = BrickWild.generate(request)
	res.checked += 1
	if building == null or not building.is_ok():
		res.fail("Scholar's Compound did not generate: %s" % (str(building.errors) if building != null else "null"))
		return res
	if building.spec.variant_name != "Scholar's Compound" \
			or absf(building.spec.width - 22.0) > 0.01 \
			or absf(building.spec.length - 32.0) > 0.01 \
			or absf(building.spec.height - 5.0) > 0.01 \
			or absf(building.spec.orientation - PI / 2.0) > 0.001 \
			or building.spec.period != 1400:
		res.fail("Scholar's Compound did not preserve archetype dimensions and INT-021 orientation metadata")
	var builder := HouseBuilder.new()
	var mesh := builder.build(building.plan)
	if mesh == null or mesh.get_surface_count() == 0:
		res.fail("Scholar's Compound has no emitted shell")
	for failure in SiheyuanCheck.new().check(building.plan, builder).get("failures", []):
		res.fail("Scholar's Compound: %s" % str(failure))
	var public_check := BrickWild.check(building)
	res.checked += 1
	if not bool(public_check.get("ok", false)):
		res.fail("public adapter rejected the Scholar's Compound: %s" % str(public_check.get("diagnostics", [])))
	var placement := BrickWild.placement(building)
	var expected_north := Basis(Vector3.UP, request.orientation).inverse() * Vector3.BACK
	res.checked += 1
	if Vector3(placement.get("north", Vector3.ZERO)).distance_to(expected_north) > 0.001:
		res.fail("INT-021 compass orientation did not reach public placement metadata")
	var document := BrickWild.generate_document(request)
	res.checked += 1
	if document.spec == null or document.plan == null or document.plan.world_family != &"siheyuan":
		res.fail("public building document rejected the Siheyuan family")
	var double_request := _request(22015)
	double_request.purpose = &"two_court_compound"
	double_request.length = 60.0
	var double_building: GeneratedBuilding = BrickWild.generate(double_request)
	res.checked += 1
	if not double_building.is_ok() or double_building.plan.courts.size() != 2:
		res.fail("two-court Siheyuan variant did not produce its ordered court pair")
	else:
		var double_builder := HouseBuilder.new()
		double_builder.build(double_building.plan)
		for failure in SiheyuanCheck.new().check(double_building.plan, double_builder).get("failures", []):
			res.fail("two-court Siheyuan: %s" % str(failure))
	var short_double := _request(22016)
	short_double.purpose = &"two_court_compound"
	short_double.length = 40.0
	var short_refused: GeneratedBuilding = BrickWild.generate(short_double)
	res.checked += 1
	if short_refused.is_ok() or short_refused.errors.is_empty():
		res.fail("the two-court variant did not refuse a too-short terrain envelope")
	var impossible := _request(22008)
	impossible.height = 2.2
	var refused: GeneratedBuilding = BrickWild.generate(impossible)
	res.checked += 1
	if refused.is_ok() or refused.errors.is_empty():
		res.fail("an undersized-height site brief was not explicitly refused")
	_negative_fixtures(res)
	return res


static func _request(seed: int) -> BuildingRequest:
	var request := BuildingRequest.new()
	request.kind = &"world"
	request.style = &"siheyuan"
	request.purpose = &"scholars_compound"
	request.seed = seed
	request.width = 22.0
	request.length = 32.0
	request.height = 5.0
	return request


static func _fixture_plan(seed: int) -> HousePlan:
	return SiheyuanGenerator.generate(seed, 22.0, 32.0, 5.0)["plan"]


static func _expect(res: SuiteResult, label: String, prefix: String,
		plan: HousePlan, builder: HouseBuilder = null) -> void:
	res.checked += 1
	for failure in SiheyuanCheck.new().check(plan, builder).get("failures", []):
		if String(failure).begins_with(prefix + ":"):
			return
	res.fail("negative Siheyuan fixture %s did not fail %s" % [label, prefix])


static func _negative_fixtures(res: SuiteResult) -> void:
	var gate := _fixture_plan(22009)
	for door in gate.doors:
		if String(door.get("role", "")) == "siheyuan_corner_gate":
			door["pos"] = Vector2(0.0, door["pos"].y)
			break
	_expect(res, "central gate", "corner_gate", gate)

	var no_screen := _fixture_plan(22010)
	no_screen.blind_entry = false
	var screen_builder := HouseBuilder.new()
	screen_builder.build(no_screen)
	_expect(res, "missing blind screen", "screen", no_screen, screen_builder)

	var short_hall := _fixture_plan(22011)
	for room in short_hall.rooms:
		if String(room.get("role", "")) == "main_hall":
			var rect: Rect2 = room["rect"]
			rect.position.x += 1.0
			room["rect"] = rect
			break
	_expect(res, "off-axis main hall", "south", short_hall)

	var unmatched_wing := _fixture_plan(22012)
	for room in unmatched_wing.rooms:
		if String(room.get("role", "")) == "wing_east":
			var rect: Rect2 = room["rect"]
			rect.size.x -= 0.5
			room["rect"] = rect
			break
	_expect(res, "unequal wings", "wings", unmatched_wing)

	var broken_walk := _fixture_plan(22013)
	for room in broken_walk.rooms:
		if String(room.get("role", "")) == "verandah_west":
			var rect: Rect2 = room["rect"]
			rect.position.y += 1.0
			room["rect"] = rect
			break
	_expect(res, "disconnected verandah", "walk", broken_walk)

	var off_axis_court := _fixture_plan(22014)
	var second := Rect2(Vector2(-2.0, 18.0), Vector2(8.0, 8.0))
	off_axis_court.courts.append({"rect": second, "storey": 0, "id": "outer_court"})
	_expect(res, "off-axis second court", "courts_in_line", off_axis_court)
