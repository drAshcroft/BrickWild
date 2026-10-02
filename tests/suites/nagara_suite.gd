class_name NagaraSuite
extends RefCounted
## WLD-013 focused gate: public world-family path and one failing fixture per Shikhara rule.

static func run() -> SuiteResult:
	var res := SuiteResult.new("world Nagara temple")
	var request := _request()
	var building: GeneratedBuilding = BrickWild.generate(request)
	res.checked += 1
	if building == null or not building.is_ok():
		res.fail("Spire of a Hundred Spires did not generate through the public API")
		return res
	if building.spec.variant_name != "Spire of a Hundred Spires":
		res.fail("Nagara archetype name was not preserved")
	if building.plan == null or building.plan.world_family != &"nagara":
		res.fail("public request did not retain the Nagara HousePlan")
	var family := BuildingFamilyAdapter.for_building(building)
	if family == null or family.footprint(building).size == Vector2.ZERO:
		res.fail("public family adapter did not expose the plinth footprint")
	if family != null and not family.quality_report(building).get("ok", false):
		res.fail("public family quality report rejected the reference temple")
	var instance := BrickWild.instantiate(building)
	if instance == null:
		res.fail("public API did not instantiate the Nagara mesh")
	var builder := NagaraBuilder.new()
	var mesh := builder.build(building.plan)
	if mesh == null or mesh.get_surface_count() < 3:
		res.fail("Nagara emitter did not produce stone, trim and spire surfaces")
	res.checked += 1
	for failure in ShikharaCheck.check(building.plan, builder)["failures"]:
		res.fail("reference temple: %s" % str(failure))
	for failure in WorldArchetypeSuite.assert_contains(building,
		["hall_roof", "garbhagriha", "plinth", "shikhara", "urushringa"]):
		res.fail("reference temple: %s" % failure)
	if not WorldFamilies.kinds_of(&"nagara").has(&"hundred_spires"):
		res.fail("world registry does not publish the hundred_spires kind")
	if WorldFamilies.envelope(&"nagara").get("width", {}).get("min", 0.0) != 18.0:
		res.fail("public family envelope is missing")
	_negative_fixtures(res)
	return res


static func _request() -> BuildingRequest:
	var request := BuildingRequest.new()
	request.kind = &"world"
	request.style = &"nagara"
	request.purpose = &"hundred_spires"
	request.seed = 13013
	request.width = 31.0
	request.length = 20.0
	request.height = 31.0
	return request


static func _fresh() -> Dictionary:
	var made := NagaraGenerator.generate(&"hundred_spires", 13013, 31.0, 20.0, 31.0)
	var builder := NagaraBuilder.new()
	builder.build(made["plan"])
	return {"plan": made["plan"], "builder": builder}


static func _expect(res: SuiteResult, fixture: Dictionary, prefix: String,
		label: String) -> void:
	var report := ShikharaCheck.check(fixture["plan"], fixture["builder"])
	res.checked += 1
	for failure in report["failures"]:
		if String(failure).begins_with(prefix + ":"):
			return
	res.fail("negative Nagara fixture '%s' was accepted; wanted %s" % [label, prefix])


static func _negative_fixtures(res: SuiteResult) -> void:
	var ascent := _fresh()
	ascent.plan.world_meta["hall_heights"][1] = 1.0
	_expect(res, ascent, "ascent", "descending hall")

	var axis := _fresh()
	var off_axis_door: Vector2 = axis.plan.doors[2]["pos"]
	axis.plan.doors[2]["pos"] = Vector2(3.0, off_axis_door.y)
	_expect(res, axis, "axis", "off-axis mandapa door")

	var sanctum := _fresh()
	sanctum.plan.windows.append({"room": sanctum.plan.rooms.size() - 1,
		"pos": Vector2.ZERO, "normal": Vector2.UP})
	_expect(res, sanctum, "sanctum", "daylit sanctum")

	var plinth := _fresh()
	for i in range(plinth.builder.mass_log.size()):
		if plinth.builder.mass_log[i]["name"] == "plinth":
			var aabb: AABB = plinth.builder.mass_log[i]["aabb"]
			plinth.builder.mass_log[i]["aabb"] = AABB(aabb.position, Vector3(aabb.size.x, 0.5, aabb.size.z))
			break
	_expect(res, plinth, "plinth", "low platform")

	var cluster := _fresh()
	for i in range(cluster.builder.mass_log.size() - 1, -1, -1):
		if String(cluster.builder.mass_log[i]["name"]).begins_with("urushringa_"):
			cluster.builder.mass_log.remove_at(i)
	_expect(res, cluster, "cluster", "unclustered main spire")

	var passage := _fresh()
	passage.plan.world_meta["pradakshina"].remove_at(2)
	_expect(res, passage, "pradakshina", "broken circuit")

	var sightline := _fresh()
	var plan: HousePlan = sightline.plan
	var door: Vector2 = plan.doors[2]["pos"]
	var image: Vector3 = plan.world_meta["image"]
	var from := Vector3(door.x, float(plan.world_meta["plinth_height"]) + 1.6, door.y)
	var to := Vector3(image.x, image.y + 2.0, image.z)
	var mid := from.lerp(to, 0.5)
	sightline.builder.mass_log.append({"name": "sightline_blocker",
		"aabb": AABB(mid - Vector3(0.5, 0.5, 0.35), Vector3(1.0, 1.0, 0.7))})
	_expect(res, sightline, "sightline", "blocked mandapa view")
