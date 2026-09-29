extends RefCounted
## Small stone bailey shops still need a usable, correctly facing focus and
## daylight at their working furniture. These seeds failed composed CastleQA.

static func run() -> SuiteResult:
	var res := SuiteResult.new("castle shops")
	for row in [[&"castle", 0, &"stable"], [&"fortress", 0, &"blacksmith"]]:
		var spec := CastleSweep.spec_at(&"norman", row[0], row[1])
		var plan: HousePlan
		for entry in CastleGenerator.bailey_buildings(spec):
			if entry.business == row[2]:
				plan = preload("res://src/castle/castle_interiors.gd").yard(spec, entry).plan
		_want(res, plan != null, "bailey fixture lost " + String(row[2]))
		if plan == null:
			continue
		for report in [HousePlanCheck.new().check(plan), HouseFurnishCheck.new().check(plan), HouseNavCheck.new().check(plan)]:
			_want(res, report.ok, "%s: %s" % [row[2], report.failures])
		if row[2] == &"stable":
			_stall(res, plan)
		else:
			_workbench(res, plan)
	ShopSuite._internal_room_focus(res)
	return res


static func _stall(res: SuiteResult, plan: HousePlan) -> void:
	var room := plan.focus_room()
	var index := -1
	for item in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[item].key) == "stall":
			index = item
	_want(res, index >= 0, "the stall was removed instead of facing its entrance")
	if index < 0:
		return
	var piece: Dictionary = plan.furniture[index]
	var door: Dictionary = plan.doors[HouseFurnishScore.focus_door(plan, room)]
	var inward_clear := HouseGeometry.door_clear_rect(door, -1.0)
	_want(res, not Rect2(piece.rect).intersects(inward_clear), "stall body blocks entrance")
	_want(res, Rect2(piece.zone).intersects(inward_clear), "fixture no longer shares its clear entrance approach")
	piece.yaw += PI
	var check := HouseFurnishCheck.new()
	check._check_focus(plan)
	_want(res, not check.failures.is_empty(), "reversed stall facing escaped QA")


static func _workbench(res: SuiteResult, plan: HousePlan) -> void:
	var room := plan.rooms_of(&"workshop")[0]
	var cross_light := false
	for wi in plan.windows_of(room):
		if absf(Vector2(plan.windows[wi].normal).x) > 0.9:
			cross_light = true
	_want(res, cross_light, "workshop has no side window for its working wall")
	var bench := -1
	for item in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[item].key) == "workbench":
			bench = item
	_want(res, bench >= 0, "workbench was removed instead of receiving daylight")
	if bench < 0:
		return
	# Restore the previously dark pose and remove the new cross-light. This
	# isolates daylight from the unrelated circulation and spacing checks.
	var keep: Array[Dictionary] = []
	for window in plan.windows:
		if int(window.room) != room or absf(Vector2(window.normal).x) < 0.5:
			keep.append(window)
	plan.windows = keep
	plan.furniture[bench].rect = Rect2(-1.612338, -1.432662, 1.53444, 0.77824)
	plan.furniture[bench].free_standing = false
	var check := HouseFurnishCheck.new()
	check._check_workbench_daylight(plan)
	_want(res, not check.failures.is_empty(), "dark bench pose escaped daylight QA")


static func _want(res: SuiteResult, okay: bool, message: String) -> void:
	res.checked += 1
	if not okay:
		res.fail(message)
