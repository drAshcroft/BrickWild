extends RefCounted
## INT-011: the focus axis, raised throne, banners, and private rear branches.

const SCALES := [0.7, 1.0, 1.4]
const BASE_WIDTH := 20.0
const BASE_LENGTH := 30.0


static func run() -> SuiteResult:
	var result := SuiteResult.new("palace focus-axis family")
	for scale in SCALES:
		var spec := _spec(float(scale))
		var plan: HousePlan = ShopGenerator.generate(spec, 71100 + int(scale * 100))
		var builder := HouseBuilder.new()
		builder.build(plan)
		var who := "scale %.2f" % float(scale)
		result.checked += 1
		for failure in _palace_failures(plan):
			result.fail("%s: %s" % [who, failure])
		var report: Dictionary = HouseQA.new().check(plan, builder)
		for failure2 in report["failures"]:
			result.fail("%s HouseQA: %s" % [who, failure2])
		for warning in report["warnings"]:
			result.warn("%s HouseQA: %s" % [who, warning])
		if is_equal_approx(float(scale), 1.0):
			_negative_controls(result, plan)
	return result


static func _spec(scale: float) -> ShopSpec:
	var spec := ShopSpec.new()
	spec.business = &"palace"
	spec.style = &"townhouse"
	spec.width = BASE_WIDTH * scale
	spec.length = BASE_LENGTH * scale
	spec.height = 3.2
	return spec


static func _palace_failures(plan: HousePlan) -> Array[String]:
	var out: Array[String] = []
	if plan.room_count() != 4:
		out.append("has %d rooms, wants the four-room palace programme" % plan.room_count())
	var expected: Array[StringName] = [&"antechamber", &"throne_room", &"treasury", &"royal_chamber"]
	for i in mini(plan.room_count(), expected.size()):
		if plan.kind_of(i) != expected[i]:
			out.append("room %d is %s, wants %s" % [i, String(plan.kind_of(i)), String(expected[i])])
	if plan.room_count() != 4:
		return out
	var entry := plan.entrance()
	if entry < 0 or plan.entrance_room() != 0:
		out.append("front door does not open into the antechamber")
	var throne := _room(plan, &"throne_room")
	var treasury := _room(plan, &"treasury")
	var royal := _room(plan, &"royal_chamber")
	var focus := -1
	for f in plan.furniture_of(throne):
		if String(plan.furniture[f]["key"]) == "Chair_1":
			focus = f
	if focus < 0:
		out.append("throne room has no measured Chair_1 throne")
	else:
		var axis_x: float = plan.doors[entry]["pos"].x
		var throne_centre: Vector2 = Rect2(plan.furniture[focus]["rect"]).get_center()
		if absf(throne_centre.x - axis_x) > HouseGeometry.room_floor_rect(plan, throne).size.x * 0.05:
			out.append("throne is not centred on the entrance axis")
		if plan.focus_room() != throne or plan.focus_cat() != "seat":
			out.append("plan.focus does not identify the throne room seat")
		if absf(plan.focus_pos().x - axis_x) > HouseGeometry.room_floor_rect(plan, throne).size.x * 0.05:
			out.append("plan.focus has moved the throne away from the entrance axis")
		if plan.dais_room() != throne or not plan.dais_rect().has_point(throne_centre):
			out.append("throne is not on its raised dais")
		if plan.dais_rise() <= 0.0:
			out.append("throne dais is not raised")
	var banners: Array[Dictionary] = []
	for f2 in plan.furniture_of(throne):
		var item: Dictionary = plan.furniture[f2]
		if String(item["key"]) == "Banner_2" and bool(item.get("mounted", false)):
			banners.append(item)
	if banners.size() < 2:
		out.append("throne room has %d measured banners, wants at least two" % banners.size())
	elif focus >= 0:
		var throne_pos: Vector3 = plan.furniture[focus]["pos"]
		var a: Vector3 = banners[0]["pos"]
		var b: Vector3 = banners[1]["pos"]
		if absf((a.x + b.x) * 0.5 - throne_pos.x) > 0.15 \
				or absf(a.z - b.z) > 0.15 \
				or absf(absf(a.x - throne_pos.x) - absf(b.x - throne_pos.x)) > 0.15:
			out.append("banners do not mirror around the throne within 0.15m")
	if treasury >= 0:
		var doors := plan.doors_of(treasury)
		if doors.size() != 1:
			out.append("treasury has %d doors, wants exactly one" % doors.size())
		elif _other_room(plan, treasury, doors[0]) != throne:
			out.append("treasury door does not lead to the throne room")
		if not plan.windows_of(treasury).is_empty():
			out.append("treasury has a window")
		if not _has_category(plan, treasury, "chest"):
			out.append("treasury has no measured chest")
	if royal >= 0:
		if plan.kind_of(royal) not in HouseGeometry.SLEEPING:
			out.append("royal chamber is not classified as sleeping")
		var doors2 := plan.doors_of(royal)
		if doors2.size() != 1 or _other_room(plan, royal, doors2[0]) != throne:
			out.append("royal chamber is not a single-door leaf of the throne room")
		if not _has_category(plan, royal, "bed"):
			out.append("royal chamber has no measured bed")
	if focus >= 0:
		var axis_door := -1
		for d in plan.doors_of(throne):
			if _other_room(plan, throne, d) == 0:
				axis_door = d
				break
		if axis_door < 0:
			out.append("throne room has no door to the antechamber")
		else:
			var door_pos: Vector2 = plan.doors[axis_door]["pos"]
			var eye := Vector3(door_pos.x, 1.6, door_pos.y)
			var chair_top: Vector3 = plan.furniture[focus]["pos"]
			chair_top.y += PropCatalog.height("Chair_1") * 0.75
			var blockers: Array[AABB] = []
			for f3 in plan.furniture_of(throne):
				if f3 == focus or bool(plan.furniture[f3].get("mounted", false)):
					continue
				var item2: Dictionary = plan.furniture[f3]
				var rect := Rect2(item2["rect"])
				blockers.append(AABB(Vector3(rect.position.x, 0.0, rect.position.y),
					Vector3(rect.size.x, PropCatalog.height(item2["key"]), rect.size.y)))
			if not Sightline.clear(eye, chair_top, blockers):
				out.append("sightline from the antechamber door to the throne is blocked")
	return out


static func _negative_controls(result: SuiteResult, source: HousePlan) -> void:
	if not _palace_failures(source).is_empty():
		result.fail("palace negative controls: source plan is not clean")
		return
	var no_dais := _copy_plan(source)
	no_dais.dais = {}
	result.checked += 1
	if not _palace_failures(no_dais).any(func(m: String) -> bool: return m.contains("raised dais")):
		result.fail("negative control: removing the dais escaped palace QA")
	var glazed_treasury := _copy_plan(source)
	glazed_treasury.windows.append({"room": _room(glazed_treasury, &"treasury"),
		"pos": Vector2.ZERO, "normal": Vector2(0, -1), "width": 0.8, "sill": 1.0, "head": 2.0})
	result.checked += 1
	if not _palace_failures(glazed_treasury).any(func(m) -> bool: return m == "treasury has a window"):
		result.fail("negative control: a treasury window escaped palace QA")
	var shifted_banner := _copy_plan(source)
	for f in shifted_banner.furniture.size():
		if String(shifted_banner.furniture[f]["key"]) == "Banner_2":
			var pos: Vector3 = shifted_banner.furniture[f]["pos"]
			pos.x += 0.5
			shifted_banner.furniture[f]["pos"] = pos
			break
	result.checked += 1
	if not _palace_failures(shifted_banner).any(func(m) -> bool: return m.contains("banners do not mirror")):
		result.fail("negative control: shifting one banner escaped pair symmetry QA")


static func _room(plan: HousePlan, kind: StringName) -> int:
	for i in range(plan.room_count()):
		if plan.kind_of(i) == kind:
			return i
	return -1


static func _other_room(plan: HousePlan, room: int, door: int) -> int:
	var record: Dictionary = plan.doors[door]
	return int(record["b"]) if int(record["a"]) == room else int(record["a"])


static func _has_category(plan: HousePlan, room: int, cat: String) -> bool:
	for f in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[f]["key"]) == cat:
			return true
	return false


static func _copy_plan(source: HousePlan) -> HousePlan:
	var copy := HousePlan.new()
	copy.spec = source.spec
	copy.rooms = source.rooms.duplicate(true)
	copy.doors = source.doors.duplicate(true)
	copy.windows = source.windows.duplicate(true)
	copy.furniture = source.furniture.duplicate(true)
	copy.focus = source.focus.duplicate(true)
	copy.dais = source.dais.duplicate(true)
	return copy
