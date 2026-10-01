class_name QiblaSuite
extends RefCounted
## WLD-004: one clean mosque and an intentionally failing control per rule.

static func run() -> SuiteResult:
	var result := SuiteResult.new("qibla")
	var plan := _plan()
	var builder := MosqueBuilder.new()
	builder.build(plan)
	var report := QiblaCheck.new().check(plan, builder)
	result.checked += 1
	for failure in report["failures"]:
		result.fail("valid mosque: %s" % failure)
	result.checked += 1
	var bad_qibla := _plan()
	var wall: Rect2 = bad_qibla.world_meta["qibla_wall"]
	bad_qibla.doors.append({"pos": wall.get_center(), "role": "bad_qibla_door"})
	_expect(result, bad_qibla, "qibla:", "prayer wall door")
	var bad_grid := _plan()
	var c: Dictionary = bad_grid.columns[0]
	var p: Vector3 = c["pos"]
	c["pos"] = p + Vector3(1.0, 0.0, 0.0)
	_expect(result, bad_grid, "grid:", "misaligned column")
	var bad_sightline := _plan()
	var sight_builder := MosqueBuilder.new()
	sight_builder.build(bad_sightline)
	sight_builder.mass_log.append({"name": "control_blocker", "aabb": AABB(Vector3(-1.0, 0.0, -1.0), Vector3(2.0, 10.0, 2.0))})
	_expect_with_builder(result, bad_sightline, sight_builder, "sightline:", "blocked aisle")
	var bad_sahn := _plan()
	bad_sahn.furniture.clear()
	_expect(result, bad_sahn, "sahn:", "dry sahn")
	var bad_minaret := _plan()
	var min_builder := MosqueBuilder.new()
	min_builder.build(bad_minaret)
	for mass in min_builder.mass_log:
		if String(mass["name"]) == "minaret":
			mass["name"] = "tower_control"
	_expect_with_builder(result, bad_minaret, min_builder, "minaret:", "untagged tallest tower")
	var bad_rows := _plan()
	for column in bad_rows.columns:
		column["radius"] = 8.0
	_expect(result, bad_rows, "rows:", "columns consume standing floor")
	return result


static func _plan() -> HousePlan:
	return MosqueGenerator.generate(&"hypostyle", 944, 90.0, 60.0, 12.0)["plan"]


static func _expect(result: SuiteResult, plan: HousePlan, prefix: String, label: String) -> void:
	var builder := MosqueBuilder.new()
	builder.build(plan)
	_expect_with_builder(result, plan, builder, prefix, label)


static func _expect_with_builder(result: SuiteResult, plan: HousePlan,
		builder: MosqueBuilder, prefix: String, label: String) -> void:
	var report := QiblaCheck.new().check(plan, builder)
	result.checked += 1
	for failure in report["failures"]:
		if String(failure).begins_with(prefix):
			return
	result.fail("negative control '%s' was accepted; wanted %s" % [label, prefix])
