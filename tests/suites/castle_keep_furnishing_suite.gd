extends RefCounted
## Regressions for the curved keeps that lost their lord's bed, and the real
## bounds of furniture turned onto a polygon wall.


static func run() -> SuiteResult:
	var res := SuiteResult.new("castle keep furnishings")
	_bounds(res)
	for row in [[&"edwardian", &"castle", 0], [&"edwardian", &"castle", 1],
			[&"edwardian", &"castle", 2], [&"edwardian", &"fortress", 0],
			[&"crusader", &"fortress", 0]]:
		var spec := CastleSweep.spec_at(row[0], row[1], int(row[2]))
		var label := "%s %s %d" % [row[0], row[1], row[2]]
		var plan := CastleGenerator.keep_plan(spec)
		_expect(res, plan.spec != null, label + ": keep has no plan")
		if plan.spec == null:
			continue
		var top := plan.spec.storeys - 1
		var beds := 0
		for index in plan.furniture_of(top):
			var placed: Dictionary = plan.furniture[index]
			if PropCatalog.category(placed.key) != "bed":
				continue
			beds += 1
			_expect(res, HouseFurnishCheck._back_gap(plan, placed) \
				<= HouseGeometry.WALL_GAP + HouseGeometry.BED_HEAD_TOL + 0.001,
				label + ": bed floats away from its headboard wall")
			for corner in Poly.from_rect(placed.zone):
				_expect(res, Poly.contains_point(plan.outline_of(top), corner, 0.01),
					label + ": bed access crosses a polygon wall")
		_expect(res, beds > 0, label + ": lord's chamber has no actual bed")
		var report := HouseQA.new().check(plan, null)
		_expect(res, report.failures.is_empty(), label + ": " + str(report.failures))
		for warning in report.warnings:
			res.warn(label + ": " + warning)
		print("keep furnishing checked: ", label, " beds=", beds, " failures=", report.failures)
	return res


static func _bounds(res: SuiteResult) -> void:
	var key := "Bed_Twin1"
	var raw := PropCatalog.footprint(key)
	var angle := PI / 4.0
	var turned := HouseFurnisher._candidate(key, Vector2.ZERO, angle)
	var diagonal := (raw.x + raw.y) / sqrt(2.0)
	_expect(res, Vector2(turned.rect.size).is_equal_approx(Vector2.ONE * diagonal),
		"45-degree bed did not include both measured width and depth")
	var zone_side := (raw.y + PropCatalog.zone_depth(key)) / sqrt(2.0)
	_expect(res, Vector2(turned.zone.size).is_equal_approx(Vector2.ONE * zone_side),
		"45-degree bed access strip collapsed or used its AABB as the model")
	for yaw in [0.0, PI / 2.0, PI, -PI / 2.0]:
		var candidate := HouseFurnisher._candidate(key, Vector2.ZERO, float(yaw))
		_expect(res, Vector2(candidate.rect.size).is_equal_approx(PropCatalog.footprint_yawed(key, float(yaw))),
			"cardinal bed footprint changed")
		var expected_zone := Vector2(PropCatalog.zone_depth(key), raw.y) \
			if absf(sin(float(yaw))) < 0.5 else Vector2(raw.y, PropCatalog.zone_depth(key))
		_expect(res, Vector2(candidate.zone.size).is_equal_approx(expected_zone),
			"cardinal bed access strip changed")
	var window := {"pos": Vector2.ZERO, "normal": Vector2.ONE.normalized(), "width": 1.4}
	var clearance := HouseGeometry.window_clear_rect(window)
	_expect(res, clearance.size.is_equal_approx(Vector2.ONE * (1.4 + 0.35) / sqrt(2.0)),
		"diagonal window clearance did not include all four corners")
	var plan := HousePlan.new()
	plan.spec = HouseSpec.new()
	plan.spec.width = 10.0
	plan.spec.length = 10.0
	plan.rooms = [{"kind": &"bedroom", "storey": 0, "rect": Rect2(-4.4, -4.4, 8.8, 8.8),
		"outline": PackedVector2Array([Vector2(-1.8,-4.4),Vector2(1.8,-4.4),
			Vector2(4.4,-1.8),Vector2(4.4,1.8),Vector2(1.8,4.4),
			Vector2(-1.8,4.4),Vector2(-4.4,1.8),Vector2(-4.4,-1.8)])}]
	turned.room = 0
	turned.storey = 0
	plan.furniture = [turned]
	var good := HouseFurnishCheck.new()
	good._check_placed(plan)
	_expect(res, good.failures.is_empty(), "correct rotated footprint was rejected: " + str(good.failures))
	plan.furniture[0].rect = Rect2(-raw * 0.5, raw)
	var false_size := HouseFurnishCheck.new()
	false_size._check_placed(plan)
	_expect(res, not false_size.failures.is_empty(), "QA accepted an unturned footprint for a rotated model")
	var overhang := HouseFurnisher._candidate(key, Vector2(2.6,2.6), angle)
	overhang.room = 0
	overhang.storey = 0
	plan.furniture = [overhang]
	_expect(res, Rect2(plan.rooms[0].rect).encloses(overhang.rect), "overhang fixture does not fit the room AABB")
	var cut_corner := HouseFurnishCheck.new()
	cut_corner._check_placed(plan)
	_expect(res, not cut_corner.failures.is_empty(), "QA accepted furniture through a polygon chamfer")


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)
