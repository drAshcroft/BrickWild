class_name MountainSuite
extends RefCounted
## WLD-011 focused gate: archetype generation and one negative control per rule.

const SCALES: Array[float] = [1.0]


static func run() -> SuiteResult:
	var res := SuiteResult.new("world temple mountain")
	if not WorldFamilies.has_family(&"temple_mountain") \
			or WorldFamilies.kinds_of(&"temple_mountain") != [&"angkor_mountain"]:
		res.fail("world registry does not publish angkor_mountain")
	for scale in SCALES:
		var request := BuildingRequest.new()
		request.kind = &"world"
		request.style = &"temple_mountain"
		request.purpose = &"angkor_mountain"
		request.seed = 41011 + roundi(scale * 100.0)
		request.width = 200.0 * scale
		request.length = 200.0 * scale
		request.height = 60.0
		var building: GeneratedBuilding = BigGlade.generate(request)
		res.checked += 1
		var label := "temple_mountain scale=%.2f" % scale
		if building == null or not building.is_ok():
			res.fail("%s: failed to generate: %s" % [label,
				str(building.errors) if building != null else "null"])
			continue
		var api_mesh: ArrayMesh = BigGlade.build_mesh(building)
		if api_mesh == null or api_mesh.get_surface_count() == 0:
			res.fail("%s: world API did not dispatch the mountain mesh" % label)
		var builder := MountainBuilder.new()
		var mesh := builder.build(building.plan)
		if mesh == null or mesh.get_surface_count() == 0:
			res.fail("%s: no emitted mountain mesh" % label)
		for failure in MountainCheck.new().check_mountain(building.plan, builder)["failures"]:
			res.fail("%s: %s" % [label, str(failure)])
		for required_mass in ["water", "causeway", "enclosure", "gopura", "tower_center"]:
			if not builder.has_mass(required_mass):
				res.fail("%s: emitted mass log has no %s" % [label, required_mass])
	_negative_controls(res)
	return res


static func _fixture() -> Dictionary:
	var made := MountainGenerator.generate(&"angkor_mountain", 911011,
		200.0, 200.0, 60.0)
	var builder := MountainBuilder.new()
	builder.build(made["plan"])
	return {"plan": made["plan"], "builder": builder}


static func _expect(res: SuiteResult, label: String, fixture: Dictionary,
		prefix: String) -> void:
	var report: Dictionary = MountainCheck.new().check_mountain(fixture["plan"], fixture["builder"])
	res.checked += 1
	for failure in report.get("failures", []):
		if String(failure).begins_with(prefix + ":"):
			return
	res.fail("negative mountain fixture %s did not fail %s" % [label, prefix])


static func _rebuild(fixture: Dictionary) -> Dictionary:
	var builder := MountainBuilder.new()
	builder.build(fixture["plan"])
	fixture["builder"] = builder
	return fixture


static func _negative_controls(res: SuiteResult) -> void:
	var nest := _fixture()
	var rings: Array = nest.plan.world_meta["rings"]
	var middle: Dictionary = rings[1]
	middle["rect"] = rings[0]["rect"]
	rings[1] = middle
	nest.plan.world_meta["rings"] = rings
	_expect(res, "un-nested-ring", _rebuild(nest), "nest")

	var quincunx := _fixture()
	for i in range(quincunx.builder.mass_log.size() - 1, -1, -1):
		if String(quincunx.builder.mass_log[i]["name"]) == "tower_corner_4":
			quincunx.builder.mass_log.remove_at(i)
	_expect(res, "missing-corner-tower", quincunx, "quincunx")

	var axis := _fixture()
	var causeway: Rect2 = axis.plan.world_meta["causeway"]
	causeway.position.x += 2.0
	axis.plan.world_meta["causeway"] = causeway
	_expect(res, "off-axis-causeway", _rebuild(axis), "axis")

	var moat := _fixture()
	var moat_rect: Rect2 = moat.plan.world_meta["moat"]
	moat_rect.position += Vector2(5.0, 5.0)
	moat_rect.size -= Vector2(10.0, 10.0)
	moat.plan.world_meta["moat"] = moat_rect
	_expect(res, "narrow-moat", _rebuild(moat), "moat")

	var climb := _fixture()
	climb.plan.world_meta["stairs"].clear()
	_expect(res, "broken-stair-links", _rebuild(climb), "climb")

	var circuit := _fixture()
	var circuit_rings: Array = circuit.plan.world_meta["rings"]
	var outer: Dictionary = circuit_rings[0]
	outer["gallery_segments"] = MountainGenerator.gallery_segments(outer)
	outer["gallery_segments"].remove_at(0)
	circuit_rings[0] = outer
	circuit.plan.world_meta["rings"] = circuit_rings
	_expect(res, "open-gallery", _rebuild(circuit), "pradakshina")

	var symmetry := _fixture()
	for i in range(symmetry.builder.mass_log.size()):
		if String(symmetry.builder.mass_log[i]["name"]) == "tower_corner_4":
			var row: Dictionary = symmetry.builder.mass_log[i]
			var aabb: AABB = row["aabb"]
			aabb.position.x += 1.0
			row["aabb"] = aabb
			symmetry.builder.mass_log[i] = row
			break
	_expect(res, "asymmetric-tower", symmetry, "symmetry")

	var dominance := _fixture()
	for i in range(dominance.builder.mass_log.size()):
		if String(dominance.builder.mass_log[i]["name"]) == "tower_center":
			var row: Dictionary = dominance.builder.mass_log[i]
			var aabb: AABB = row["aabb"]
			aabb.size.y *= 0.5
			row["aabb"] = aabb
			dominance.builder.mass_log[i] = row
			break
	_expect(res, "short-central-tower", dominance, "dominance")
