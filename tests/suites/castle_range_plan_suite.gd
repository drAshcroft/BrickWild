extends RefCounted
## Castle ranges use their actual bailey facade, not the curtain behind them.


static func run() -> SuiteResult:
	var res := SuiteResult.new("castle range plans")
	var canonical := _spec(40.0, 55.0, 14.0, 42)
	_check_range(res, canonical, false, "canonical hall")
	var chapel_case := _spec(80.0, 120.0, 16.0, 8802)
	chapel_case.hall = true
	chapel_case.chapel = true
	CastleGenerator.refit(chapel_case)
	_check_range(res, chapel_case, false, "chapel fixture hall")
	_check_range(res, chapel_case, true, "chapel fixture")
	var broad := CastleSweep.spec_at(&"norman", &"castle", 1)
	var chapel_box := CastleGeometry.chapel_aabb(broad)
	_expect(res, chapel_box.size.x > chapel_box.size.z,
		"broad chapel fixture no longer puts its entrance on the bailey wall")
	_check_range(res, broad, true, "broad chapel")
	# Nine metres asks for three hall windows; the clear floor is only 7.8m
	# along that facade. This catches blindly retaining the old sparse bays.
	var compact := _spec(40.0, 55.0, 14.0, 42)
	compact.hall_w = 8.0
	compact.hall_l = 9.0
	compact.hall_height = 4.5
	_check_range(res, compact, false, "compact three-bay hall")
	for tier in [&"house", &"manor"]:
		var free := CastleSweep.spec_at(&"norman", tier, 0)
		var plan := CastleInteriorPlans.hall_plan(free)
		_expect(res, plan.spec != null, "%s hall fixture has no plan" % tier)
		if plan.spec == null:
			continue
		_expect(res, not CastleGeometry.is_enclosed(free), "%s fixture is enclosed" % tier)
		var opposite := false
		for a in plan.windows:
			for b in plan.windows:
				if Vector2(a.normal).dot(Vector2(b.normal)) < -0.9:
					opposite = true
		_expect(res, opposite, "%s hall lost its two free window walls" % tier)
		_check_qa(res, plan, "%s hall" % tier)
	return res


static func _spec(width: float, length: float, height: float, seed_value: int) -> CastleSpec:
	var spec := CastleSpec.new()
	spec.style = &"norman"
	spec.width = width
	spec.length = length
	spec.height = height
	CastleGenerator.generate(spec, seed_value)
	return spec


static func _check_range(res: SuiteResult, spec: CastleSpec, chapel: bool, label: String) -> void:
	var plan := CastleInteriorPlans.chapel_plan(spec) if chapel else CastleInteriorPlans.hall_plan(spec)
	_expect(res, plan.spec != null, label + ": expected a valid interior plan")
	if plan.spec == null:
		return
	var normal := Vector2.LEFT if chapel else Vector2.RIGHT
	var minimum := 1 if chapel else mini(3,
		int(CastleGeometry.hall_aabb(spec).size.z / CastleBuilder.RANGE_BAY))
	_expect(res, plan.windows.size() >= minimum,
		label + ": %d bailey windows, requires %d" % [plan.windows.size(), minimum])
	var rect := HouseGeometry.interior_rect(plan.spec)
	for window in plan.windows:
		_expect(res, Vector2(window.normal).dot(normal) > 0.99,
			label + ": a window faces the curtain or range end")
		var x := rect.position.x if chapel else rect.end.x
		_expect(res, absf(window.pos.x - x) < 0.001,
			label + ": window is not on the actual bailey wall")
	_check_qa(res, plan, label)


static func _check_qa(res: SuiteResult, plan: HousePlan, label: String) -> void:
	# Match the composed castle rule: its joined roof belongs to CastleBuilder.
	var report := HouseQA.new().check(plan, null)
	_expect(res, report.failures.is_empty(), label + ": " + str(report.failures))
	for warning in report.warnings:
		res.warn(label + ": " + warning)


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)
