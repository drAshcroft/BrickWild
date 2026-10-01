class_name InsulaGenerator
extends RefCounted
## WLD-002 port tenement: shops below, six flats around a light court, one stair.

const FAMILY := &"insula"
const KIND := &"port_tenement"
const STOREYS := 5
const FLAT_LEVELS := 3
const STAIR_W := 3.8


static func generate(seed: int, width: float, length: float, _height: float) -> Dictionary:
	var spec := InsulaSpec.new(seed)
	spec.style = &"townhouse"
	spec.material = &"stone"
	spec.width = clampf(width, 20.0, 45.0)
	spec.length = clampf(length, 18.0, 38.0)
	spec.height = 3.6
	spec.storeys = STOREYS
	spec.trade = &"none"
	spec.wall_thickness_override = 0.55
	spec.roof_type = &"hipped"
	spec.roof_pitch = 0.14
	spec.porch = false
	spec.chimney = false
	spec.timber_frame = false
	spec.stone_ground_floor = true
	spec.plinth_height = 0.3
	spec.wall_color = Color("b9a98e")
	spec.trim_color = Color("665340")
	spec.roof_color = Color("4b3d32")
	spec.floor_color = Color("88785d")
	spec.clutter = 0.0
	spec.variant_name = "Port Tenement"

	var plan := HousePlan.new()
	plan.spec = spec
	plan.world_family = FAMILY
	plan.world_subkind = KIND
	var inner := HouseGeometry.interior_rect(spec)
	var stair_w := minf(STAIR_W, inner.size.x * 0.24)
	var stair_x := inner.get_center().x - stair_w * 0.5
	var left := Rect2(inner.position, Vector2(stair_x - inner.position.x, inner.size.y))
	var stair := Rect2(Vector2(stair_x, inner.position.y), Vector2(stair_w, inner.size.y))
	var right := Rect2(Vector2(stair.end.x, inner.position.y),
		Vector2(inner.end.x - stair.end.x, inner.size.y))
	var court_z := inner.position.y + inner.size.y * 0.34
	var court := Rect2(Vector2(stair.position.x, court_z),
		Vector2(stair.size.x, inner.end.y - court_z))
	var stair_rooms: Array[int] = []
	var flat_count := 0

	for level in range(STOREYS):
		var stair_front_depth := court.position.y - inner.position.y
		var stair_room_rect := Rect2(stair.position, Vector2(stair.size.x, stair_front_depth))
		var stair_room := _add_room(plan, &"stair", "stair", stair_room_rect, level)
		stair_rooms.append(stair_room)
		if level == 0:
			_add_room(plan, &"shop", "taberna_left", left, level)
			_add_room(plan, &"shop", "taberna_right", right, level)
			var ground_store := _add_room(plan, &"store", "ground_store", Rect2(Vector2(stair.position.x, stair_room_rect.end.y),
				Vector2(stair.size.x, inner.end.y - stair_room_rect.end.y)), level)
			_add_door(plan, stair_room, ground_store,
				Vector2(stair.get_center().x, stair_room_rect.end.y), Vector2(0, 1), level, "service")
			continue

		plan.courts.append({"rect": court, "storey": level, "id": "insula_court_%d" % level})
		var front_end := court.position.y
		var front_depth := front_end - inner.position.y
		var left_half := left.size.x * 0.5
		var side_front_a := Rect2(left.position, Vector2(left_half, front_depth))
		var side_front_b := Rect2(Vector2(left.position.x + left_half, left.position.y), Vector2(left.size.x - left_half, front_depth))
		var side_middle := Rect2(Vector2(left.position.x, court.position.y), Vector2(left.size.x, court.size.y))
		var right_half := right.size.x * 0.5
		var right_front_a := Rect2(right.position, Vector2(right_half, front_depth))
		var right_front_b := Rect2(Vector2(right.position.x + right_half, right.position.y), Vector2(right.size.x - right_half, front_depth))
		var right_middle := Rect2(Vector2(right.position.x, court.position.y), Vector2(right.size.x, court.size.y))

		if level <= FLAT_LEVELS:
			var left_unit := "flat_%d" % (flat_count + 1)
			flat_count += 1
			var right_unit := "flat_%d" % (flat_count + 1)
			flat_count += 1
			var lf := _add_room(plan, &"bedroom", "cubiculum_side", side_front_a, level, left_unit)
			var lm := _add_room(plan, &"parlour", "medianum", side_middle, level, left_unit)
			var lf2 := _add_room(plan, &"bedroom", "cubiculum_front", side_front_b, level, left_unit)
			var rf := _add_room(plan, &"bedroom", "cubiculum_front", right_front_a, level, right_unit)
			var rm := _add_room(plan, &"parlour", "medianum", right_middle, level, right_unit)
			var rf2 := _add_room(plan, &"bedroom", "cubiculum_side", right_front_b, level, right_unit)
			_add_door(plan, lf, lm, Vector2(side_front_a.get_center().x, front_end), Vector2(0, 1), level, "flat_room")
			_add_door(plan, lf2, lm, Vector2(side_front_b.get_center().x, front_end), Vector2(0, 1), level, "flat_room")
			_add_door(plan, rf, rm, Vector2(right_front_a.get_center().x, front_end), Vector2(0, 1), level, "flat_room")
			_add_door(plan, rf2, rm, Vector2(right_front_b.get_center().x, front_end), Vector2(0, 1), level, "flat_room")
			_add_medianum_windows(plan, lm, side_middle, true, level, spec)
			_add_medianum_windows(plan, rm, right_middle, false, level, spec)
			_add_exterior_window(plan, lf, side_front_a, Vector2(0, -1), level, spec)
			_add_exterior_window(plan, lf2, side_front_b, Vector2(0, -1), level, spec)
			_add_exterior_window(plan, rf, right_front_a, Vector2(0, -1), level, spec)
			_add_exterior_window(plan, rf2, right_front_b, Vector2(0, -1), level, spec)
		else:
			var service_left_front := Rect2(left.position, Vector2(left.size.x, front_depth))
			var service_right_front := Rect2(right.position, Vector2(right.size.x, front_depth))
			var service_lf := _add_room(plan, &"laundry", "upper_service_front_left", service_left_front, level)
			var service_lm := _add_room(plan, &"laundry", "upper_service_court_left", side_middle, level)
			var service_rf := _add_room(plan, &"laundry", "upper_service_front_right", service_right_front, level)
			var service_rm := _add_room(plan, &"laundry", "upper_service_court_right", right_middle, level)
			_add_door(plan, stair_room, service_lf, Vector2(stair.position.x, service_left_front.get_center().y), Vector2(-1, 0), level, "service")
			_add_door(plan, stair_room, service_rf, Vector2(stair.end.x, service_right_front.get_center().y), Vector2(1, 0), level, "service")
			_add_door(plan, service_lf, service_lm, Vector2(left.get_center().x, front_end), Vector2(0, 1), level, "service")
			_add_door(plan, service_rf, service_rm, Vector2(right.get_center().x, front_end), Vector2(0, 1), level, "service")
			_add_medianum_windows(plan, service_lm, side_middle, true, level, spec)
			_add_medianum_windows(plan, service_rm, right_middle, false, level, spec)
			_add_exterior_window(plan, service_lf, service_left_front, Vector2(0, -1), level, spec)

	# Ground-floor tabernae have their own street thresholds. The sole residential
	# entrance belongs to the continuous stair; shop customers do not use it.
	var shop_opening_w := minf(2.2, minf(left.size.x, right.size.x) - 0.6)
	for i in range(2):
		var shop_room := i + 1
		var shop_rect: Rect2 = plan.rooms[shop_room]["rect"]
		var p := Vector2(shop_rect.get_center().x, inner.position.y)
		plan.doors.append({"a": shop_room, "b": -1, "pos": p, "normal": Vector2(0, -1),
			"width": maxf(2.0, shop_opening_w), "exterior": true, "front": false,
			"storey": 0, "role": "taberna"})
		plan.windows.append({"room": shop_room, "pos": p, "normal": Vector2(0, -1),
			"width": shop_opening_w, "sill": 2.3, "head": minf(spec.height - 0.25, 3.25),
			"storey": 0, "role": "taberna_display"})
	var street := Vector2(stair.get_center().x, inner.position.y)
	plan.doors.append({"a": stair_rooms[0], "b": -1, "pos": street, "normal": Vector2(0, -1),
		"width": HouseGeometry.DOOR_W, "exterior": true, "front": true,
		"storey": 0, "role": "stair_entry"})
	for level in range(STOREYS - 1):
		var sr: Rect2 = plan.rooms[stair_rooms[level]]["rect"]
		var run := minf(3.0, sr.size.y * 0.32)
		var rise_rect := Rect2(Vector2(sr.get_center().x - 1.05, sr.position.y + 1.6), Vector2(1.3, run))
		plan.stairs.append({"a": stair_rooms[level], "b": stair_rooms[level + 1],
			"storey": level, "to_storey": level + 1, "pos": rise_rect.get_center(),
			"lower_pos": rise_rect.get_center(), "upper_pos": rise_rect.get_center(),
			"rect": rise_rect, "lower_rect": rise_rect, "upper_rect": rise_rect,
			"width": rise_rect.size.x, "run": run, "steps": int(spec.height / 0.22)})
	for level in range(1, STOREYS):
		var up_stair := stair_rooms[level]
		var front_ids: Array[int] = []
		for i in range(plan.rooms.size()):
			if int(plan.rooms[i].get("storey", 0)) != level:
				continue
			if String(plan.rooms[i].get("role", "")) == "cubiculum_front":
				front_ids.append(i)
		for room in front_ids:
			var rr: Rect2 = plan.rooms[room]["rect"]
			var side_normal := Vector2(-1, 0) if rr.get_center().x < stair.get_center().x else Vector2(1, 0)
			var wall_x := stair.position.x if side_normal.x < 0 else stair.end.x
			_add_door(plan, up_stair, room, Vector2(wall_x, rr.get_center().y), side_normal, level, "flat_entry")

	plan.world_meta["court_rect"] = court
	plan.world_meta["stair_rooms"] = stair_rooms
	plan.world_meta["flat_count"] = flat_count
	plan.world_meta["street_door"] = street
	plan.world_meta["shop_rooms"] = [1, 2]
	plan.world_meta["total_height"] = spec.height * STOREYS + HouseGeometry.roof_rise(spec)
	plan.world_meta["eave_height"] = spec.height * STOREYS
	plan.world_meta["unit_count"] = flat_count
	plan.roof_openings.append({"id": "insula_court_light", "kind": &"compluvium",
		"storey": STOREYS - 1, "face": -1, "rect": court, "room": -1})
	return {"spec": spec, "plan": plan}


static func _add_room(plan: HousePlan, kind: StringName, role: String, rect: Rect2,
		storey: int, unit := "") -> int:
	var index := plan.rooms.size()
	var row := {"kind": kind, "role": role, "rect": rect, "storey": storey}
	if not unit.is_empty():
		row["unit"] = unit
	plan.rooms.append(row)
	return index


static func _add_door(plan: HousePlan, a: int, b: int, pos: Vector2,
		normal: Vector2, storey: int, role: String) -> void:
	plan.doors.append({"a": a, "b": b, "pos": pos, "normal": normal,
		"width": HouseGeometry.INNER_DOOR_W, "exterior": false, "front": false,
		"storey": storey, "role": role})


static func _add_medianum_windows(plan: HousePlan, room: int, rect: Rect2,
		left_side: bool, storey: int, spec: HouseSpec) -> void:
	var x := rect.end.x if left_side else rect.position.x
	var n := Vector2(1, 0) if left_side else Vector2(-1, 0)
	for offset in [-0.72, 0.72]:
		plan.windows.append({"room": room, "pos": Vector2(x, rect.get_center().y + offset),
			"normal": n, "width": HouseGeometry.WINDOW_W, "sill": 1.0,
			"head": minf(spec.height - 0.25, 2.55), "storey": storey,
			"role": "court_daylight"})


static func _add_exterior_window(plan: HousePlan, room: int, rect: Rect2,
		normal: Vector2, storey: int, spec: HouseSpec) -> void:
	var pos := Vector2(rect.get_center().x, rect.position.y if normal.y < 0 else rect.end.y)
	plan.windows.append({"room": room, "pos": pos, "normal": normal,
		"width": minf(HouseGeometry.WINDOW_W, rect.size.x - 0.9), "sill": 1.0,
		"head": minf(spec.height - 0.25, 2.55), "storey": storey,
		"role": "exterior_daylight"})
