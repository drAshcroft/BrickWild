class_name CruciformSuite
extends RefCounted
## WLD-012: Temple of Four Winds, plus one failing control per rule.

static func run() -> SuiteResult:
	var res := SuiteResult.new("world cruciform temple")
	var request := BuildingRequest.new()
	request.kind = &"world"
	request.style = &"cruciform_temple"
	request.purpose = &"temple_of_four_winds"
	request.seed = 12012
	request.width = 90.0
	request.length = 90.0
	request.height = 50.0
	var building: GeneratedBuilding = BrickWild.generate(request)
	res.checked += 1
	if building == null or not building.is_ok():
		res.fail("Temple of Four Winds did not generate")
		return res
	if building.spec.variant_name != "Temple of Four Winds":
		res.fail("archetype name was not preserved")
	var plan: HousePlan = building.plan
	var builder := CruciformBuilder.new()
	var mesh := builder.build(plan)
	if mesh == null or mesh.get_surface_count() < 2:
		res.fail("cruciform mesh has no stone and roof surfaces")
	var clean := CruciformCheck.check(plan, builder)
	res.checked += 1
	for failure in clean["failures"]:
		res.fail("valid shrine: %s" % failure)

	var bad_entrances: HousePlan = _fresh_plan()
	bad_entrances.doors.pop_back()
	_expect(res, bad_entrances, "entrances:", "three entrances")

	var bad_facing: HousePlan = _fresh_plan()
	var images: Array = bad_facing.world_meta["images"]
	images[0]["facing"] = Vector3.RIGHT
	_expect(res, bad_facing, "images:", "north image faces east")

	var blocked_builder := CruciformBuilder.new()
	blocked_builder.build(plan)
	blocked_builder.mass_log.append({"name": "sightline_blocker",
		"aabb": AABB(Vector3(-2.0, 0.1, -30.0), Vector3(4.0, 3.0, 2.0))})
	_expect_with_builder(res, plan, blocked_builder, "images:", "blocked entrance sightline")

	var bad_outer: HousePlan = _fresh_plan()
	bad_outer.world_meta["outer_ring"].pop_back()
	_expect(res, bad_outer, "rings:", "outer ring gap")
	var bad_inner: HousePlan = _fresh_plan()
	bad_inner.world_meta["inner_ring"].pop_back()
	_expect(res, bad_inner, "rings:", "inner ring gap")
	var unlinked: HousePlan = _fresh_plan()
	unlinked.world_meta["ring_links"].clear()
	_expect(res, unlinked, "rings:", "rings are disconnected")

	var off_center: HousePlan = _fresh_plan()
	off_center.world_meta["sikhara_center"] = Vector3(1.0, 0.0, 0.0)
	_expect(res, off_center, "sikhara:", "off-center sikhara")
	var squat_builder := CruciformBuilder.new()
	squat_builder.build(plan)
	for mass in squat_builder.mass_log:
		if mass["name"] == "sikhara":
			var aabb: AABB = mass["aabb"]
			mass["aabb"] = AABB(aabb.position, Vector3(aabb.size.x, 8.0, aabb.size.z))
	_expect_with_builder(res, plan, squat_builder, "sikhara:", "sikhara not tallest")
	return res


static func _fresh_plan() -> HousePlan:
	return CruciformGenerator.generate(&"temple_of_four_winds", 12012,
		90.0, 90.0, 50.0)["plan"]


static func _expect(res: SuiteResult, plan: HousePlan, prefix: String, label: String) -> void:
	var builder := CruciformBuilder.new()
	builder.build(plan)
	_expect_with_builder(res, plan, builder, prefix, label)


static func _expect_with_builder(res: SuiteResult, plan: HousePlan,
		builder: CruciformBuilder, prefix: String, label: String) -> void:
	var report := CruciformCheck.check(plan, builder)
	res.checked += 1
	for failure in report["failures"]:
		if String(failure).begins_with(prefix):
			return
	res.fail("negative cruciform fixture '%s' was accepted; wanted %s" % [label, prefix])
