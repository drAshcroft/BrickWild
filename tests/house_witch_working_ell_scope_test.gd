extends SceneTree
## Scope and merged-extent checks for the plan-derived Witch service ell.
## Run after applying the staged HousePlanner/HousePlanRooms/HouseGeometry changes.

const CASES := [
	{"name": "unsupported_8x10_witch", "style": &"witch_hut", "width": 8.0, "length": 10.0,
		"expected_ell": false},
	{"name": "minimum_span_8_5x10_witch", "style": &"witch_hut", "width": 8.5, "length": 10.0,
		"expected_ell": true},
	{"name": "frozen_9x12_witch", "style": &"witch_hut", "width": 9.0, "length": 12.0,
		"expected_ell": true},
	{"name": "large_grammar_12x14_witch", "style": &"witch_hut", "width": 12.0, "length": 14.0,
		"expected_ell": false},
	{"name": "rotated_ridge_control_12x9_witch", "style": &"witch_hut", "width": 12.0, "length": 9.0,
		"expected_ell": false},
	{"name": "nearby_8x10_cottage", "style": &"cottage", "width": 8.0, "length": 10.0,
		"expected_ell": false},
]

var failures: Array[String] = []

func _init() -> void:
	for row in CASES:
		_check_case(row)
	for failure in failures:
		push_error(failure)
	print("Witch working-ell scope: %d cases, %d failures" % [CASES.size(), failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _check_case(row: Dictionary) -> void:
	var spec := HouseSpec.new(8102)
	spec.style = row.style
	spec.trade = &"none"
	spec.width = float(row.width)
	spec.length = float(row.length)
	spec.height = 2.6
	spec.storeys = 1
	spec.cellars = 0
	var plan := HouseGenerator.generate(spec, spec.seed, false)
	if plan == null:
		failures.append("%s: no plan" % row.name)
		return
	var active := bool(plan.domestic_layout.get("witch_working_ell", false))
	if active != bool(row.expected_ell):
		failures.append("%s: expected working ell=%s, got %s (%s)" % [row.name,
			str(row.expected_ell), str(active), str(plan.domestic_layout)])
	if not active:
		for room in plan.rooms:
			if bool(room.get("witch_service_wing", false)) \
					and row.style == &"cottage":
				failures.append("%s: Cottage entered the Witch service-wing scope" % row.name)
		return
	var report := HousePlanCheck.new().check(plan)
	if not bool(report.get("ok", false)):
		failures.append("%s: plan rules failed: %s" % [row.name, str(report.get("failures", []))])
	if plan.rooms_of(&"hall").is_empty() or plan.rooms_of(&"bedroom").is_empty() \
			or plan.rooms_of(&"kitchen").is_empty() or plan.rooms_of(&"workshop").is_empty():
		failures.append("%s: the four required household rooms are incomplete" % row.name)
		return
	var core_rooms: Array[int] = [plan.rooms_of(&"hall")[0], plan.rooms_of(&"bedroom")[0]]
	var service_rooms: Array[int] = [plan.rooms_of(&"kitchen")[0], plan.rooms_of(&"workshop")[0]]
	for pair in [[core_rooms[0], service_rooms[0]], [core_rooms[0], core_rooms[1]],
			[service_rooms[0], service_rooms[1]]]:
		if not _has_room_door(plan, int(pair[0]), int(pair[1])):
			failures.append("%s: required Hall/Kitchen/Bedroom/Workshop edge is missing: %s" % [row.name, str(pair)])
	var layout := HouseGeometry.roof_layout(plan)
	var bay: Dictionary = layout.get("witch_bay", {})
	if bay.is_empty():
		failures.append("%s: marked service rooms have no supported lower roof" % row.name)
		return
	var core_hall: Rect2 = plan.rooms[plan.rooms_of(&"hall")[0]]["rect"]
	var roof_xf: Transform3D = layout.transform
	var ridge_world := roof_xf * Vector3(float(layout.ridge_x), float(layout.rise), 0.0)
	print(JSON.stringify({
		"case": row.name, "site_cross_span": HouseGeometry.site_rect(spec).size.x,
		"high_core_width": core_hall.size.x, "main_roof_span": layout.span,
		"ridge_station_local": layout.ridge_x, "ridge_station_world": Vector2(ridge_world.x, ridge_world.z),
		"main_gable_rise": layout.rise,
		"service_clear_span": absf(float(bay.inner) - float(bay.outer)),
		"service_join_height_world": roof_xf.origin.y + float(bay.join_y),
		"service_eave_height_world": roof_xf.origin.y + float(bay.eave_y),
	}))
	var actual_wing: Array[int] = []
	for i in range(plan.room_count()):
		if bool(plan.rooms[i].get("witch_service_wing", false)):
			actual_wing.append(i)
	var hosted: Array = bay.get("wing_rooms", [])
	if hosted.size() != actual_wing.size():
		failures.append("%s: merged roof hosts %d rooms, plan marks %d" % [row.name, hosted.size(), actual_wing.size()])
	for room_index in actual_wing:
		if not hosted.has(room_index):
			failures.append("%s: merged roof omitted marked room %d" % [row.name, room_index])
	var wing_rect: Rect2 = bay.get("wing_rect", Rect2())
	for room_index in actual_wing:
		var room_floor: Rect2 = HouseGeometry.room_floor_rect(plan, room_index)
		if not wing_rect.grow(0.01).encloses(room_floor):
			failures.append("%s: merged roof/ceiling extent misses room %d clear floor" % [row.name, room_index])
	for room_index in core_rooms:
		var core_floor: Rect2 = HouseGeometry.room_floor_rect(plan, room_index)
		if wing_rect.intersection(core_floor).get_area() > 0.001:
			failures.append("%s: merged service extent overlaps occupied core room %d" % [row.name, room_index])
	var along_is_world_y := absf(Vector2(bay.normal).x) > 0.5
	var raw_lo := INF
	var raw_hi := -INF
	var raw_length := 0.0
	for room_index in actual_wing:
		var raw: Rect2 = plan.rooms[room_index]["rect"]
		var lo := raw.position.y if along_is_world_y else raw.position.x
		var hi := raw.end.y if along_is_world_y else raw.end.x
		raw_lo = minf(raw_lo, lo)
		raw_hi = maxf(raw_hi, hi)
		raw_length += hi - lo
	if absf(float(bay.along_world_lo) - raw_lo) > 0.01 \
			or absf(float(bay.along_world_hi) - raw_hi) > 0.01:
		failures.append("%s: lower-roof run does not match the marked rooms' real outer extent" % row.name)
	if absf(raw_length - (raw_hi - raw_lo)) > 0.02:
		failures.append("%s: marked service rooms have a gap or overlap along the roof run" % row.name)


func _has_room_door(plan: HousePlan, a: int, b: int) -> bool:
	for door in plan.doors:
		if not bool(door.get("exterior", false)) \
				and ((int(door.get("a", -1)) == a and int(door.get("b", -1)) == b) \
				or (int(door.get("a", -1)) == b and int(door.get("b", -1)) == a)):
			return true
	return false
