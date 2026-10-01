class_name HammamSuite
extends RefCounted
## WLD-005 focused family rules and one negative control per rule.


static func run() -> SuiteResult:
	var res := SuiteResult.new("world hammam")
	var baseline := _made(24.0, 16.0, 8.0, 95001)
	var report := HammamCheck.new().check(baseline.plan, baseline.builder)
	res.checked += 1
	if not report["ok"]:
		res.fail("Steam Baths 24x16x8 failed: %s" % str(report["failures"]))
	if baseline.plan.windows.size() != 0:
		res.fail("Steam Baths authored windows instead of roof daylight")
	if String(report.get("replaced", {}).get("daylight", "")) != "hammam.blind":
		res.fail("daylight was not explicitly replaced with hammam.blind")
	for opening in baseline.builder.roof_opening_log:
		var origin: Vector3 = opening["center"] + Vector3.DOWN * 0.8
		res.checked += 1
		if WorldArchetypeSuite._ray_hits_mesh(baseline.mesh, origin, Vector3.UP, 4.0):
			res.fail("emitted roof geometry blocks oculus %s" % String(opening.get("id", "")))
	_expect(res, "identity", "identity:")
	_expect(res, "path", "path:")
	_expect(res, "walk distance", "walk_distance:")
	_expect(res, "hot leaf", "hot_leaf:")
	_expect(res, "blind daylight", "hammam.blind")
	_expect(res, "oculi", "oculi:")
	_expect(res, "domes", "domes:")
	_expect(res, "furnace", "furnace:")
	return res


static func _made(width: float, length: float, height: float, seed: int) -> Dictionary:
	var made := HammamGenerator.generate(seed, width, length, height)
	var builder := HammamBuilder.new()
	var mesh: ArrayMesh = builder.build(made["plan"])
	return {"plan": made["plan"], "builder": builder, "mesh": mesh}


static func _expect(res: SuiteResult, label: String, needle: String) -> void:
	var made := _made(24.0, 16.0, 8.0, 95100 + label.hash() % 500)
	_mutate_fixture(made, label)
	var report: Dictionary = HammamCheck.new().check(made.plan, made.builder)
	res.checked += 1
	for failure in report.get("failures", []):
		if String(failure).contains(needle):
			return
	res.fail("negative hammam fixture %s did not fail %s: %s" % [label, needle,
		str(report.get("failures", []))])


static func _mutate_fixture(made: Dictionary, label: String) -> void:
	var plan: HousePlan = made["plan"]
	var builder: HammamBuilder = made["builder"]
	match label:
		"identity":
			plan.world_family = &"insula"
		"path":
			plan.doors.remove_at(2)
		"walk distance":
			plan.rooms[2]["rect"] = plan.rooms[1]["rect"]
		"hot leaf":
			var hot := _room(plan, &"hot")
			plan.doors.append({"a": hot, "b": -1, "pos": Vector2(0, 8),
				"normal": Vector2(0, 1), "width": 0.9, "exterior": true,
				"front": false, "storey": 0})
		"blind daylight":
			var inner := HouseGeometry.interior_rect(plan.spec)
			plan.windows.append({"room": 0, "pos": Vector2(inner.position.x,
				plan.rooms[0]["rect"].get_center().y), "normal": Vector2(-1, 0),
				"width": 0.8, "sill": 1.0, "head": 2.2, "storey": 0})
		"oculi":
			var warm := _room(plan, &"warm")
			builder.roof_opening_log = builder.roof_opening_log.filter(
				func(opening): return int(opening.get("room", -1)) != warm)
		"domes":
			builder.mass_log = builder.mass_log.filter(
				func(mass): return String(mass.get("name", "")) != "dome_hot")
		"furnace":
			var moved: AABB = builder.furnace_aabb
			moved.position.z -= 4.0
			builder.furnace_aabb = moved
			for mass in builder.mass_log:
				if String(mass.get("name", "")) == "furnace":
					mass["aabb"] = moved


static func _room(plan: HousePlan, role: StringName) -> int:
	for i in range(plan.rooms.size()):
		if StringName(plan.rooms[i].get("role", &"")) == role:
			return i
	return -1
