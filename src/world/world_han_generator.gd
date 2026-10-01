class_name WorldHanGenerator
extends RefCounted
## WLD-006: Sultan's Han, a caravanserai arranged around a flooded court.

const FAMILY := &"caravanserai"
const KIND := &"sultan_han"
const WALL_HEIGHT := 7.0
const GATE_WIDTH := 2.8
const CELL_DOOR_WIDTH := 1.0
const STABLE_DOOR_WIDTH := 1.6


static func generate(seed: int, width: float, length: float, _height: float) -> Dictionary:
	var spec := HouseSpec.new(seed)
	spec.style = &"townhouse"
	spec.material = &"stone"
	spec.width = clampf(width, 49.0, 133.0)
	spec.length = clampf(length, 38.5, 105.0)
	spec.height = WALL_HEIGHT
	spec.storeys = 1
	spec.trade = &"none"
	spec.wall_thickness_override = 0.6
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
	spec.variant_name = "Sultan's Han"

	var plan := HousePlan.new()
	plan.spec = spec
	plan.world_family = FAMILY
	plan.world_subkind = KIND
	var inner := HouseGeometry.interior_rect(spec)
	var court_side := clampf(minf(inner.size.x, inner.size.y) * 0.28, 10.5, 12.0)
	var court := Rect2(inner.get_center() - Vector2.ONE * court_side * 0.5,
		Vector2.ONE * court_side)
	plan.courts.append({"rect": court, "storey": 0, "id": "han_court"})

	var ids: Array[int] = []
	var front_depth := court.position.y - inner.position.y
	var passage_width := GATE_WIDTH + 2.0
	var passage_x := inner.get_center().x - passage_width * 0.5
	var gate_passage := _add_room(plan, &"antechamber", "gate_passage",
		Rect2(Vector2(passage_x, inner.position.y), Vector2(passage_width, front_depth)))
	ids.append(gate_passage)
	var front_left := Rect2(inner.position, Vector2(passage_x - inner.position.x, front_depth))
	var front_right := Rect2(Vector2(passage_x + passage_width, inner.position.y),
		Vector2(inner.end.x - passage_x - passage_width, front_depth))
	ids.append(_add_cell(plan, &"guest_room", "lodging_cell", front_left, court,
		Vector2(0, 1), CELL_DOOR_WIDTH))
	ids.append(_add_cell(plan, &"guest_room", "lodging_cell", front_right, court,
		Vector2(0, 1), CELL_DOOR_WIDTH))

	# The side ranges are cut into two stable/lodging cells each. Every stall
	# threshold opens straight to the court, where animals can be watered.
	var half_court_depth := court.size.y * 0.5
	for side in [-1, 1]:
		var band_x := Rect2(Vector2(inner.position.x, court.position.y),
			Vector2(court.position.x - inner.position.x, court.size.y)) if side < 0 else \
			Rect2(Vector2(court.end.x, court.position.y),
			Vector2(inner.end.x - court.end.x, court.size.y))
		var side_normal := Vector2(1, 0) if side < 0 else Vector2(-1, 0)
		for segment in range(2):
			var band := Rect2(Vector2(band_x.position.x,
				court.position.y + half_court_depth * segment),
				Vector2(band_x.size.x, half_court_depth))
			var kind := &"stable" if segment == 0 else &"guest_room"
			var role := "stable_cell" if kind == &"stable" else "lodging_cell"
			ids.append(_add_cell(plan, kind, role, band, court, side_normal,
				STABLE_DOOR_WIDTH if kind == &"stable" else CELL_DOOR_WIDTH))

	# The domed winter hall is opposite the gate, on the far court range. The
	# two flanking cells keep the back edge inhabited without stealing its axis.
	var rear_depth := inner.end.y - court.end.y
	var winter_width := minf(inner.size.x * 0.52, maxf(8.0, court_side * 0.96))
	var winter_left := inner.get_center().x - winter_width * 0.5
	var winter_hall := _add_room(plan, &"great_hall", "winter_hall",
		Rect2(Vector2(winter_left, court.end.y), Vector2(winter_width, rear_depth)))
	ids.append(winter_hall)
	plan.doors.append({"a": winter_hall, "b": -1,
		"pos": Vector2(inner.get_center().x, court.end.y), "normal": Vector2(0, -1),
		"width": 2.4, "exterior": false, "front": false,
		"storey": 0, "role": "winter_hall_entry"})
	var rear_left := Rect2(Vector2(inner.position.x, court.end.y),
		Vector2(winter_left - inner.position.x, rear_depth))
	var rear_right := Rect2(Vector2(winter_left + winter_width, court.end.y),
		Vector2(inner.end.x - winter_left - winter_width, rear_depth))
	ids.append(_add_cell(plan, &"guest_room", "lodging_cell", rear_left, court,
		Vector2(0, -1), CELL_DOOR_WIDTH))
	ids.append(_add_cell(plan, &"guest_room", "lodging_cell", rear_right, court,
		Vector2(0, -1), CELL_DOOR_WIDTH))

	var gate_pos := Vector2(inner.get_center().x, inner.position.y)
	plan.doors.append({"a": gate_passage, "b": -1, "pos": gate_pos,
		"normal": Vector2(0, -1), "width": GATE_WIDTH, "sill": 0.0,
		"head": 3.0, "exterior": true, "front": true,
		"storey": 0, "role": "han_gate"})
	var passage_court_pos := Vector2(inner.get_center().x, court.position.y)
	plan.doors.append({"a": gate_passage, "b": -1, "pos": passage_court_pos,
		"normal": Vector2(0, 1), "width": GATE_WIDTH, "exterior": false,
		"front": false, "storey": 0, "role": "court_entry"})

	var kiosk_side := minf(4.8, court_side * 0.45)
	var kiosk := Rect2(court.get_center() - Vector2.ONE * kiosk_side * 0.5,
		Vector2.ONE * kiosk_side)
	var flood := court.grow(-0.2)
	var dome_radius := minf(5.2, minf(winter_width, rear_depth) * 0.42)
	var roof_rise := minf(HouseGeometry.roof_rise(spec) * 0.12,
		minf(spec.width, spec.length) * 0.04)
	var dome_base := WALL_HEIGHT + roof_rise * 0.55
	var dome_rise := maxf(0.2, 12.0 - dome_base)
	plan.world_meta["court_rect"] = court
	plan.world_meta["gate_room"] = gate_passage
	plan.world_meta["winter_hall_room"] = winter_hall
	plan.world_meta["winter_hall_rect"] = plan.rooms[winter_hall]["rect"]
	plan.world_meta["kiosk_rect"] = kiosk
	plan.world_meta["flood_rect"] = flood
	plan.world_meta["water_rect"] = flood
	plan.world_meta["water_pos"] = court.get_center()
	plan.world_meta["dome_radius"] = dome_radius
	plan.world_meta["dome_base_y"] = dome_base
	plan.world_meta["dome_rise"] = dome_rise
	plan.world_meta["eave_height"] = WALL_HEIGHT
	plan.world_meta["total_height"] = dome_base + dome_rise
	plan.world_meta["han_rooms"] = ids
	plan.water_plane = 0.18
	plan.roof_openings.append({"id": "han_court_sky", "kind": &"compluvium",
		"storey": 0, "face": -1, "rect": court, "room": -1})
	return {"spec": spec, "plan": plan}


static func _add_room(plan: HousePlan, kind: StringName, role: String,
		rect: Rect2) -> int:
	var index := plan.rooms.size()
	plan.rooms.append({"kind": kind, "role": role, "rect": rect, "storey": 0})
	return index


static func _add_cell(plan: HousePlan, kind: StringName, role: String,
		rect: Rect2, court: Rect2, normal: Vector2, door_width: float) -> int:
	var room := _add_room(plan, kind, role, rect)
	var pos: Vector2
	if absf(normal.x) > 0.5:
		pos = Vector2(court.position.x if normal.x > 0 else court.end.x,
			clampf(rect.get_center().y, court.position.y + 0.4, court.end.y - 0.4))
	else:
		pos = Vector2(clampf(rect.get_center().x, court.position.x + 0.4,
			court.end.x - 0.4), court.position.y if normal.y > 0 else court.end.y)
	plan.doors.append({"a": room, "b": -1, "pos": pos, "normal": normal,
		"width": door_width, "exterior": false, "front": false,
		"storey": 0, "role": "court_cell_door" if role != "stable_cell" else "stable_court_door"})
	return room
