extends RefCounted
## CAS-REG-005: a raised Crusader entrance must lead past, not into, the first
## occupied-storey stair. Both cases are real one- and two-ring builds.


static func run() -> SuiteResult:
	var res := SuiteResult.new("castle keep stair clearance")
	var castle := CastleSweep.spec_at(&"crusader", &"castle", 1)
	var fortress := CastleSpec.new()
	fortress.style = &"crusader"
	fortress.width = 90.0
	fortress.length = 140.0
	fortress.height = 20.0
	CastleGenerator.generate(fortress, 9118)
	for spec in [castle, fortress]:
		var who := "Crusader %s seed=%d" % [String(spec.tier), spec.seed]
		var plan := CastleKeepPlan.generate(spec, false)
		_expect(res, plan.room_count() >= 3 and plan.stairs.size() == plan.room_count() - 1,
			"%s lost the occupied keep stair chain" % who)
		if plan.room_count() == 0:
			continue
		var door: Dictionary = plan.doors[plan.entrance()]
		var entry := int(door.a)
		_expect(res, entry == 1 and bool(door.exterior),
			"%s lost its protected first-floor entrance" % who)
		var report := HousePlanCheck.new().check(plan)
		_expect(res, report.ok, "%s keep plan: %s" % [who, report.failures])
		var line := HousePlanLevels.door_line(plan, entry, door)
		var foot := -1
		for index in range(plan.stairs.size()):
			if int(plan.stairs[index].a) == entry:
				foot = index
				break
		_expect(res, foot >= 0, "%s has no stair from the entrance storey" % who)
		if foot >= 0:
			var rect: Rect2 = plan.stairs[foot].lower_rect
			var hit := line.intersection(rect)
			_expect(res, hit.size.x <= HousePlanCheck.TOL or hit.size.y <= HousePlanCheck.TOL,
				"%s stair %d blocks the front-door line by %s" % [who, foot, hit])
			# The unchanged checker must reject a stair returned to the route.
			var original: Dictionary = plan.stairs[foot].duplicate()
			var bad := rect
			bad.position.x = line.position.x - rect.size.x * 0.5 + line.size.x * 0.5
			plan.stairs[foot]["lower_rect"] = bad
			plan.stairs[foot]["rect"] = bad
			var negative := HousePlanCheck.new().check(plan)
			_expect(res, negative.failures.any(func(f: String) -> bool:
				return f.begins_with("stair_line: the foot of stair")),
				"%s blocked-route negative control was not detected" % who)
			plan.stairs[foot] = original
		var builder := CastleBuilder.new()
		var mesh := builder.build(spec)
		var qa := CastleQA.new().check(spec, mesh, builder)
		_expect(res, qa.ok, "%s full CastleQA: %s" % [who, qa.failures])
	return res


static func _expect(res: SuiteResult, condition: bool, message: String) -> void:
	res.checked += 1
	if not condition:
		res.fail(message)
