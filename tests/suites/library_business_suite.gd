extends RefCounted
## INT-009: the library is a working sequence of reading room, stacks,
## scriptorium and office, measured through the shared house checks.

const BASE_WIDTH := 18.0
const BASE_LENGTH := 28.0


static func run() -> SuiteResult:
	var res := SuiteResult.new("library business")
	for scale in [0.7, 1.0, 1.4]:
		var spec := _spec(scale)
		var plan: HousePlan = ShopGenerator.generate(spec, 61000 + int(scale * 100))
		var builder := HouseBuilder.new()
		builder.build(plan)
		res.checked += 1
		for failure in _library_failures(plan):
			res.fail("scale=%.2f: %s" % [scale, failure])
		var report: Dictionary = HouseQA.new().check(plan, builder)
		for failure2 in report["failures"]:
			res.fail("scale=%.2f HouseQA: %s" % [scale, failure2])
		for warning in report["warnings"]:
			res.warn("scale=%.2f HouseQA: %s" % [scale, warning])
		if is_equal_approx(scale, 1.0):
			_negative_controls(res, plan)
	return res


static func run_seeds(seed_count := 100) -> SuiteResult:
	var res := SuiteResult.new("library %d-seed HouseQA" % seed_count)
	for offset in range(seed_count):
		_check_seed(res, 62000 + offset)
	return res


static func run_repair_regressions() -> SuiteResult:
	var res := SuiteResult.new("library navigation-repair regression seeds")
	for seed in [62006, 62029]:
		_check_seed(res, seed)
	return res


static func _check_seed(res: SuiteResult, seed: int) -> void:
	var plan: HousePlan = ShopGenerator.generate(_spec(1.0), seed)
	var builder := HouseBuilder.new()
	builder.build(plan)
	res.checked += 1
	for failure in _library_failures(plan):
		res.fail("seed %d: %s" % [seed, failure])
	var report: Dictionary = HouseQA.new().check(plan, builder)
	for failure2 in report["failures"]:
		res.fail("seed %d HouseQA: %s" % [seed, failure2])
	for warning in report["warnings"]:
		res.warn("seed %d HouseQA: %s" % [seed, warning])


static func _spec(scale: float) -> ShopSpec:
	var spec := ShopSpec.new()
	spec.business = &"library"
	spec.style = &"longhall"
	spec.width = BASE_WIDTH * scale
	spec.length = BASE_LENGTH * scale
	spec.height = 3.1
	return spec


static func _library_failures(plan: HousePlan) -> Array[String]:
	var out: Array[String] = []
	if plan.room_count() != 4:
		out.append("has %d rooms, wants reading room, stacks, scriptorium and office" % plan.room_count())
	var reading := _room(plan, &"reading_room")
	var stacks := _room(plan, &"stacks")
	var script_room := _room(plan, &"scriptorium")
	if reading < 0: out.append("no reading room")
	if stacks < 0: out.append("no stacks room")
	if script_room < 0: out.append("no scriptorium")
	if reading >= 0:
		if plan.hearth_room() != reading:
			out.append("hearth is not in the reading room")
		var hearths := 0
		for f in plan.furniture_of(reading):
			if PropCatalog.category(plan.furniture[f]["key"]) == "hearth": hearths += 1
		if hearths < 1: out.append("reading room has no hearth")
		var lecterns: Array[int] = []
		for f2 in plan.furniture_of(reading):
			if PropCatalog.category(plan.furniture[f2]["key"]) == "lectern": lecterns.append(f2)
		if lecterns.size() < 2:
			out.append("reading room has %d lecterns, wants at least 2" % lecterns.size())
		for fi in lecterns:
			if _nearest_window(plan, reading, Rect2(plan.furniture[fi]["rect"]).get_center()) > 1.5:
				out.append("reading room lectern is %.2fm from a window" % _nearest_window(plan, reading, Rect2(plan.furniture[fi]["rect"]).get_center()))
				break
	if stacks >= 0:
		var bookcases: Array[int] = []
		var rows := {}
		for f3 in plan.furniture_of(stacks):
			var item: Dictionary = plan.furniture[f3]
			if PropCatalog.category(item["key"]) != "bookcase": continue
			bookcases.append(f3)
			var row := String(item.get("row", ""))
			if not row.is_empty():
				if not rows.has(row): rows[row] = {"count": 0, "aisle": Rect2(item["zone"])}
				rows[row]["count"] += 1
				if not Rect2(item["zone"]).is_equal_approx(rows[row]["aisle"]):
					out.append("bookcase row does not share one aisle zone")
		if bookcases.size() < 6: out.append("stacks has %d bookcases, wants at least 6" % bookcases.size())
		if rows.size() < 2: out.append("stacks has fewer than two bookcase rows")
		for row_data in rows.values():
			if int(row_data["count"]) < 3: out.append("a bookcase row has fewer than three cases")
			if minf(Rect2(row_data["aisle"]).size.x, Rect2(row_data["aisle"]).size.y) < 0.99:
				out.append("a stacks aisle is narrower than 1.0m")
	for fi2 in range(plan.furniture.size()):
		var item2: Dictionary = plan.furniture[fi2]
		if PropCatalog.category(item2["key"]) == "bookcase" and plan.hearth_room() == int(item2["room"]):
			var wall := HouseFurnishSpatialCheck.fs_back_wall(plan, int(item2["room"]), item2["rect"], item2)
			if wall == plan.hearth_wall():
				out.append("bookcase stands on the hearth wall")
				break
	if script_room >= 0:
		var bench := -1
		for f4 in plan.furniture_of(script_room):
			if PropCatalog.category(plan.furniture[f4]["key"]) == "workbench": bench = f4
		if bench < 0:
			out.append("scriptorium has no workbench")
		elif HouseFurnishSpatialCheck.fs_back_wall(plan, script_room,
				plan.furniture[bench]["rect"], plan.furniture[bench]) < 0 \
				or not HouseFurnishSpatialCheck.fs_wall_lit(plan, script_room,
					HouseFurnishSpatialCheck.fs_back_wall(plan, script_room,
						plan.furniture[bench]["rect"], plan.furniture[bench])):
			out.append("scriptorium workbench is not on a window wall")
	return out


static func _nearest_window(plan: HousePlan, room: int, point: Vector2) -> float:
	var best := INF
	for wi in plan.windows_of(room):
		best = minf(best, point.distance_to(Vector2(plan.windows[wi]["pos"])))
	return best


static func _room(plan: HousePlan, kind: StringName) -> int:
	for i in range(plan.room_count()):
		if plan.kind_of(i) == kind: return i
	return -1


static func _negative_controls(res: SuiteResult, source: HousePlan) -> void:
	if not _library_failures(source).is_empty():
		res.fail("library negative controls: positive source plan is already defective")
		return
	var sparse := _copy_plan(source)
	var stacks := _room(sparse, &"stacks")
	var keep_row := ""
	var erased_rows := {}
	for item in sparse.furniture:
		if int(item["room"]) == stacks and PropCatalog.category(item["key"]) == "bookcase":
			var row_id := String(item.get("row", ""))
			if keep_row.is_empty():
				keep_row = row_id
			elif row_id != keep_row:
				erased_rows[row_id] = true
	for i in range(sparse.furniture.size() - 1, -1, -1):
		if int(sparse.furniture[i]["room"]) == stacks \
				and erased_rows.has(String(sparse.furniture[i].get("row", ""))):
			sparse.furniture.remove_at(i)
	res.checked += 1
	if not _library_failures(sparse).any(func(m: String) -> bool: return m.contains("bookcase")):
		res.fail("negative control: deleting a bookcase escaped stacks row/count rules")
	var dark_lecterns := _copy_plan(source)
	var reading := _room(dark_lecterns, &"reading_room")
	for i2 in range(dark_lecterns.furniture.size()):
		if int(dark_lecterns.furniture[i2]["room"]) == reading \
				and PropCatalog.category(dark_lecterns.furniture[i2]["key"]) == "lectern":
			dark_lecterns.furniture[i2]["rect"] = Rect2(Vector2(-20, -20), Vector2(0.5, 0.5))
	res.checked += 1
	if not _library_failures(dark_lecterns).any(func(m: String) -> bool: return m.contains("lectern is") and m.ends_with("from a window")):
		res.fail("negative control: moving a lectern away from daylight escaped")
	var blind_script := _copy_plan(source)
	var script_room := _room(blind_script, &"scriptorium")
	blind_script.windows = blind_script.windows.filter(func(w: Dictionary) -> bool:
		return int(w["room"]) != script_room)
	res.checked += 1
	if not _library_failures(blind_script).any(func(m: String) -> bool: return m.contains("workbench is not on a window wall")):
		res.fail("negative control: removing scriptorium windows escaped the workbench daylight rule")
	var heated := _copy_plan(source)
	var bookcase_index := -1
	for bi in range(heated.furniture.size()):
		if PropCatalog.category(heated.furniture[bi]["key"]) == "bookcase":
			bookcase_index = bi
			break
	if bookcase_index >= 0 and heated.hearth_room() >= 0:
		var bookcase: Dictionary = heated.furniture[bookcase_index]
		bookcase["room"] = heated.hearth_room()
		var wall: Dictionary = HouseGeometry.room_walls(heated, heated.hearth_room())[heated.hearth_wall()]
		var normal := Vector2(wall["normal"])
		var yaw := HouseFurnishGeometry.yaw_facing(normal)
		var footprint := PropCatalog.footprint_rotated(bookcase["key"], yaw) * float(bookcase.get("scale", 1.0))
		var centre: Vector2 = (Vector2(wall["from"]) + Vector2(wall["to"])) * 0.5 + normal * (footprint.dot(normal.abs()) * 0.5 + HouseGeometry.WALL_GAP)
		bookcase["yaw"] = yaw
		bookcase["rect"] = Rect2(centre - footprint * 0.5, footprint)
		res.checked += 1
		if not _library_failures(heated).any(func(m: String) -> bool: return m.contains("bookcase stands on the hearth wall")):
			res.fail("negative control: bookcase on the chimney wall escaped the heat rule")


static func _copy_plan(source: HousePlan) -> HousePlan:
	var copy := HousePlan.new()
	copy.spec = source.spec
	copy.rooms = source.rooms.duplicate(true)
	copy.doors = source.doors.duplicate(true)
	copy.windows = source.windows.duplicate(true)
	copy.hearth = source.hearth.duplicate(true)
	copy.focus = source.focus.duplicate(true)
	copy.furniture = source.furniture.duplicate(true)
	copy.rugs = source.rugs.duplicate(true)
	return copy
