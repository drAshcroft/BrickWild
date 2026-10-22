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
		var plan := CastleKeepPlan.generate(spec)
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
			_expect(res, HouseFurnishArrangementCheck.back_gap(plan, placed) \
				<= HouseGeometry.WALL_GAP + HouseGeometry.BED_HEAD_TOL + 0.001,
				label + ": bed floats away from its headboard wall")
			# The access strip is a turned rectangle; on a drum or an octagon
			# its bounding box reaches into the cut-off corners while the
			# floor a person stands on is inside (CASTLE-CHANGE-17).
			var strip := HouseFurnishGeometry.zone_strip(String(placed.key),
				Rect2(placed.rect), float(placed.yaw), float(placed.get("zone_side", 1.0)))
			_expect(res, Poly.encloses_corners(plan.outline_of(top), strip, 0.01),
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
	var turned := HouseFurnishGeometry.candidate(key, Vector2.ZERO, angle)
	var diagonal := (raw.x + raw.y) / sqrt(2.0)
	_expect(res, Vector2(turned.rect.size).is_equal_approx(Vector2.ONE * diagonal),
		"45-degree bed did not include both measured width and depth")
	var zone_side := (raw.y + PropCatalog.zone_depth(key)) / sqrt(2.0)
	_expect(res, Vector2(turned.zone.size).is_equal_approx(Vector2.ONE * zone_side),
		"45-degree bed access strip collapsed or used its AABB as the model")
	for yaw in [0.0, PI / 2.0, PI, -PI / 2.0]:
		var candidate := HouseFurnishGeometry.candidate(key, Vector2.ZERO, float(yaw))
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
	var good := HouseFurnishPhysicalCheck.new()
	good.check_placed(plan)
	_expect(res, good.failures.is_empty(), "correct rotated footprint was rejected: " + str(good.failures))
	plan.furniture[0].rect = Rect2(-raw * 0.5, raw)
	var false_size := HouseFurnishPhysicalCheck.new()
	false_size.check_placed(plan)
	_expect(res, not false_size.failures.is_empty(), "QA accepted an unturned footprint for a rotated model")
	var overhang := HouseFurnishGeometry.candidate(key, Vector2(2.6,2.6), angle)
	overhang.room = 0
	overhang.storey = 0
	plan.furniture = [overhang]
	_expect(res, Rect2(plan.rooms[0].rect).encloses(overhang.rect), "overhang fixture does not fit the room AABB")
	var cut_corner := HouseFurnishPhysicalCheck.new()
	cut_corner.check_placed(plan)
	_expect(res, not cut_corner.failures.is_empty(), "QA accepted furniture through a polygon chamfer")
	_turned_wall(res, key, angle)
	_notch(res)


## A piece square against a diagonal facet is inside the room although the
## corners of its axis-aligned box are not: the box reaches into the triangle
## the chamfer cuts off. The physical check must test the piece, not the box,
## or every wall piece on a drum is reported as being in the masonry
## (CASTLE-CHANGE-17).
static func _turned_wall(res: SuiteResult, key: String, angle: float) -> void:
	var room := PackedVector2Array([Vector2(-1.8,-4.4),Vector2(1.8,-4.4),
		Vector2(4.4,-1.8),Vector2(4.4,1.8),Vector2(1.8,4.4),
		Vector2(-1.8,4.4),Vector2(-4.4,1.8),Vector2(-4.4,-1.8)])
	var plan := HousePlan.new()
	plan.spec = HouseSpec.new()
	plan.rooms = [{"kind": &"bedroom", "storey": 0, "rect": Rect2(-4.4,-4.4,8.8,8.8),
		"outline": room}]
	var raw := PropCatalog.footprint(key)
	var normal := Vector2(1.0, 1.0).normalized()
	var centre := Vector2(3.1, 3.1) - normal * (raw.y * 0.5 + HouseGeometry.WALL_GAP)
	var seated := HouseFurnishGeometry.candidate(key, centre,
		HouseFurnishGeometry.yaw_facing(-normal))
	seated.room = 0
	seated.storey = 0
	plan.furniture = [seated]
	# the fixture must exercise the bug: its AABB corner is in the cut-off
	# triangle, so the old corner-of-the-box test rejected it
	var box_out := false
	for corner in Poly.from_rect(Rect2(seated.rect)):
		box_out = box_out or not Poly.contains_point(room, corner, 0.01)
	_expect(res, box_out, "turned-wall fixture: its AABB does not reach the chamfer")
	var check := HouseFurnishPhysicalCheck.new()
	check.check_placed(plan)
	_expect(res, check.failures.is_empty(),
		"a piece square against a diagonal wall was called masonry: " + str(check.failures))


## The negative control for the same rule: a piece whose four corners are all
## on the floor, but which spans a notch cut into it. A corner-only test says
## yes; the edge test must say no.
static func _notch(res: SuiteResult) -> void:
	var room := PackedVector2Array([Vector2(-5,-5),Vector2(5,-5),Vector2(5,5),
		Vector2(0.6,5),Vector2(0.6,1),Vector2(-0.6,1),Vector2(-0.6,5),Vector2(-5,5)])
	var key := "Table_Large"
	var raw := PropCatalog.footprint(key)
	var plan := HousePlan.new()
	plan.spec = HouseSpec.new()
	plan.rooms = [{"kind": &"hall", "storey": 0, "rect": Rect2(-5,-5,10,10), "outline": room}]
	var across := HouseFurnishGeometry.candidate(key, Vector2(0.0, 3.0), 0.0)
	across.room = 0
	across.storey = 0
	plan.furniture = [across]
	var corners_in := true
	for corner in Poly.from_rect(Rect2(across.rect)):
		corners_in = corners_in and Poly.contains_point(room, corner, 0.01)
	_expect(res, corners_in, "notch fixture: corners are not all on the floor")
	var check := HouseFurnishPhysicalCheck.new()
	check.check_placed(plan)
	_expect(res, not check.failures.is_empty(),
		"QA accepted a piece spanning a notch with all four corners on the floor")


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)
