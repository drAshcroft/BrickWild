class_name DravidaSuite
extends RefCounted
## WLD-014 focused gate: public API, axial prakara composition, period controls and failures.

static func run() -> SuiteResult:
	var res := SuiteResult.new("world Dravida / Prakara")
	var request := _request(900)
	var building: GeneratedBuilding = BigGlade.generate(request)
	res.checked += 1
	if building == null or not building.is_ok():
		res.fail("God-King's Precinct did not generate through the public API")
		return res
	if building.spec.variant_name != "God-King's Precinct" or building.plan == null \
			or building.plan.world_family != &"dravida":
		res.fail("Dravida archetype identity did not survive the public request")
	if building.spec.period != 900 or absf(building.spec.orientation - request.orientation) > 0.001:
		res.fail("period or orientation metadata was not retained")
	if not WorldFamilies.kinds_of(&"dravida").has(&"god_kings_precinct"):
		res.fail("world registry does not publish the God-King's Precinct kind")
	var descriptor := BigGlade.describe_kind(&"world")
	var published := false
	for row in descriptor.get("families", []):
		if row.get("id") == &"dravida" and &"god_kings_precinct" in row.get("kinds", []):
			published = true
	if not published:
		res.fail("public world options do not expose Dravida and its kind")
	var family := BuildingFamilyAdapter.for_building(building)
	if family == null or family.footprint(building).size == Vector2.ZERO:
		res.fail("public family adapter did not expose the prakara footprint")
	if family != null and not family.quality_report(building).get("ok", false):
		res.fail("public family quality report rejected the reference compound")
	var api_report := BigGlade.check(building)
	if not api_report.get("ok", false):
		res.fail("public BigGlade.check rejected the reference compound")
	var placement := BigGlade.placement(building)
	var north: Vector3 = placement.get("north", Vector3.ZERO)
	if placement.is_empty() or not placement.has("footprint") \
			or (north -
				Basis(Vector3.UP, request.orientation).inverse() * Vector3.BACK).length() > 0.001:
		res.fail("public placement did not expose the footprint and requested orientation")
	var mesh: ArrayMesh = BigGlade.build_mesh(building)
	if mesh == null or mesh.get_surface_count() < 3:
		res.fail("Dravida builder did not emit stone, trim and roof surfaces")
	var builder := DravidaBuilder.new()
	if mesh != null:
		builder.build(building.plan)
		for failure in WorldArchetypeSuite.assert_contains(building,
			["prakara", "colonnade_floor", "gopuram", "mandapa", "sanctum",
			"nandi", "dhvaja", "vimana_tier"]):
			res.fail("reference compound: %s" % failure)
		for failure in PrakaraCheck.new().check(building.plan, builder).get("failures", []):
			res.fail("reference compound: %s" % str(failure))
	var document := BigGlade.generate_document(request)
	res.checked += 1
	if not document.is_ok() or document.plan == null \
			or document.plan.world_family != &"dravida" or BigGlade.build_mesh(document) == null:
		res.fail("Dravida family did not survive the public document path")
	var restored := BuildingDocument.from_json(document.to_json())
	res.checked += 1
	if not restored.is_ok() or restored.plan == null \
			or restored.plan.world_family != &"dravida" or BigGlade.build_mesh(restored) == null:
		res.fail("Dravida plan did not survive document serialization")
	var late := BigGlade.generate(_request(1450))
	res.checked += 1
	if late == null or not late.is_ok():
		res.fail("late-period God-King's Precinct did not generate")
	else:
		var late_builder := DravidaBuilder.new()
		late_builder.build(late.plan)
		for failure in PrakaraCheck.new().check(late.plan, late_builder).get("failures", []):
			res.fail("late-period compound: %s" % str(failure))
	_negative_fixtures(res)
	return res


static func _request(period: int) -> BuildingRequest:
	var request := BuildingRequest.new()
	request.kind = &"world"
	request.style = &"dravida"
	request.purpose = &"god_kings_precinct"
	request.seed = 14014
	request.width = 240.0
	request.length = 120.0
	request.height = 63.0
	request.period = period
	request.orientation = 0.37
	return request


static func _fresh(period := 900) -> Dictionary:
	var made := DravidaGenerator.generate(&"god_kings_precinct", 14015,
		240.0, 120.0, 63.0, period)
	var builder := DravidaBuilder.new()
	builder.build(made["plan"])
	return {"plan": made["plan"], "builder": builder}


static func _expect(res: SuiteResult, label: String, fixture: Dictionary,
		prefix: String) -> void:
	res.checked += 1
	var report := PrakaraCheck.new().check(fixture["plan"], fixture["builder"])
	for failure in report.get("failures", []):
		if String(failure).begins_with(prefix + ":"):
			return
	res.fail("negative Dravida fixture '%s' was accepted; wanted %s" % [label, prefix])


static func _remove_mass(builder: DravidaBuilder, name: String) -> void:
	for i in range(builder.mass_log.size() - 1, -1, -1):
		if String(builder.mass_log[i].get("name", "")) == name:
			builder.mass_log.remove_at(i)
			return


static func _negative_fixtures(res: SuiteResult) -> void:
	var enclosure := _fresh()
	_remove_mass(enclosure.builder, "prakara_left")
	_expect(res, "missing prakara wall", enclosure, "enclosure")

	var gallery := _fresh()
	_remove_mass(gallery.builder, "colonnade_floor_2")
	_expect(res, "broken walk loop", gallery, "colonnade")

	var gopuram := _fresh()
	for mass in gopuram.builder.mass_log:
		if mass["name"] == "gopuram_front_tower":
			var aabb: AABB = mass["aabb"]
			mass["aabb"] = AABB(aabb.position + Vector3(3.0, 0.0, 0.0), aabb.size)
			break
	_expect(res, "off-axis gate tower", gopuram, "gopuram")

	var dominance := _fresh()
	for mass in dominance.builder.mass_log:
		if String(mass["name"]).begins_with("gopuram_") and String(mass["name"]).ends_with("_tower"):
			var aabb: AABB = mass["aabb"]
			mass["aabb"] = AABB(Vector3(aabb.position.x, 80.0, aabb.position.z),
				Vector3(aabb.size.x, aabb.size.y, aabb.size.z))
	_expect(res, "early era with gates too tall", dominance, "dominance")

	var nandi := _fresh()
	nandi.plan.world_meta["nandi_facing"] = Vector3.FORWARD
	_expect(res, "bull turned away", nandi, "nandi")

	var vimana := _fresh()
	vimana.plan.world_meta["vimana_tiers"][1]["width"] = float(vimana.plan.world_meta["vimana_tiers"][0]["width"])
	_expect(res, "non-decreasing vimana", vimana, "vimana")

	var dhvaja := _fresh()
	for mass in dhvaja.builder.mass_log:
		if mass["name"] == "dhvaja":
			var aabb: AABB = mass["aabb"]
			mass["aabb"] = AABB(Vector3(aabb.position.x, aabb.position.y,
				float(dhvaja.plan.world_meta["first_mandapa_z"]) + 1.0), aabb.size)
			break
	_expect(res, "flagstaff past mandapa", dhvaja, "dhvaja")

	var sightline := _fresh()
	sightline.builder.mass_log.append({"name": "test_sightline_blocker",
		"aabb": AABB(Vector3(-0.5, 1.0, 0.0), Vector3(1.0, 3.0, 1.0))})
	_expect(res, "blocked bull-to-sanctum ray", sightline, "sightline")
