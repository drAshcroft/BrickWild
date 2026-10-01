class_name PagodaSuite
extends RefCounted
## WLD-009 focused family gate. It exercises all three supported outlines and
## keeps one deliberate defect for each independent acceptance rule.

const KINDS: Array[StringName] = [&"square_pagoda", &"octagonal_pagoda", &"dodecagonal_pagoda"]


static func run() -> SuiteResult:
	var res := SuiteResult.new("world pagoda")
	for kind in KINDS:
		var made := PagodaGenerator.generate(kind, 9901 + KINDS.find(kind), 30.0, 30.0, 65.0)
		var plan: HousePlan = made["plan"]
		var builder := PagodaBuilder.new()
		var mesh := builder.build(plan)
		res.checked += 1
		if mesh == null or mesh.get_surface_count() == 0:
			res.fail("%s: pagoda emitted no mesh" % String(kind))
		var report := PagodaCheck.new().check(plan, builder)
		for failure in report["failures"]:
			res.fail("%s: %s" % [String(kind), str(failure)])
		if int(plan.spec.storeys) != 9:
			res.fail("%s: 30x30x65 archetype must have nine storeys" % String(kind))
		if plan.stairs.size() != 8:
			res.fail("%s: nine-storey stair must have eight connected flights" % String(kind))
	_fixtures(res)
	return res


static func _fixture() -> Dictionary:
	var made := PagodaGenerator.generate(&"square_pagoda", 9990, 30.0, 30.0, 65.0)
	var builder := PagodaBuilder.new()
	builder.build(made["plan"])
	return {"plan": made["plan"], "builder": builder}


static func _expect(res: SuiteResult, label: String, fixture: Dictionary, prefix: String) -> void:
	res.checked += 1
	var report := PagodaCheck.new().check(fixture["plan"], fixture["builder"])
	for failure in report["failures"]:
		if String(failure).begins_with(prefix + ":"):
			return
	res.fail("negative pagoda fixture %s did not fail %s" % [label, prefix])


static func _fixtures(res: SuiteResult) -> void:
	var odd := _fixture()
	odd.plan.world_meta["storey_count"] = 8
	_expect(res, "even-storeys", odd, "odd")

	var taper := _fixture()
	taper.plan.world_meta["eave_tiers"][1]["width"] = float(taper.plan.world_meta["eave_tiers"][0]["width"]) * 0.80
	_expect(res, "over-tapered", taper, "taper")

	var mast := _fixture()
	for i in range(mast.builder.mass_log.size() - 1, -1, -1):
		if String(mast.builder.mass_log[i].get("name", "")) == "mast":
			mast.builder.mass_log.remove_at(i)
	_expect(res, "missing-mast", mast, "mast")

	var plan_fault := _fixture()
	plan_fault.plan.rooms[0]["outline"] = PackedVector2Array([
		Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10), Vector2(0, 0)])
	_expect(res, "invalid-polygon", plan_fault, "plan")

	var slender := _fixture()
	slender.plan.world_meta["total_height"] = 30.0
	_expect(res, "short-building", slender, "slender")

	var crown := _fixture()
	crown.plan.world_meta["finial_height"] = 0.04 * float(crown.plan.world_meta["total_height"])
	_expect(res, "short-finial", crown, "crown")

	var climb := _fixture()
	climb.plan.stairs.remove_at(3)
	_expect(res, "broken-stair-chain", climb, "climb")

	var hidden := _fixture()
	hidden.plan.world_meta["eave_tiers"][8]["width"] = 0.1
	_expect(res, "uncovered-upper-floor", hidden, "hidden_floors")
