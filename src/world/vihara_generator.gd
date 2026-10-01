class_name ViharaGenerator
extends RefCounted
## WLD-018: monastic cells around a four-sided verandah and open court.

const FAMILY := &"vihara"
const SUBKIND := &"monks_cloister"
const CELL_SIDE := 3.0
const VERANDAH := 2.0
const WALL_HEIGHT := 5.0
const PASSAGE_WIDTH := 3.0


static func generate(seed: int, width: float, length: float, _height: float) -> Dictionary:
	var spec := HouseSpec.new(seed)
	spec.style = &"townhouse"
	spec.material = &"stone"
	spec.width = clampf(width, 35.0, 95.0)
	spec.length = clampf(length, 28.0, 76.0)
	spec.height = WALL_HEIGHT
	spec.storeys = 1
	spec.trade = &"none"
	spec.wall_thickness_override = 0.2
	spec.roof_type = &"hipped"
	spec.roof_pitch = 0.08
	spec.dormers = false
	spec.dormer_count = 0
	spec.porch = false
	spec.chimney = false
	spec.timber_frame = false
	spec.stone_ground_floor = true
	spec.plinth_height = 0.25
	spec.wall_color = Color("c8bca5")
	spec.trim_color = Color("89785f")
	spec.roof_color = Color("63594d")
	spec.floor_color = Color("a2947a")
	spec.clutter = 0.0
	spec.variant_name = "Monks' Cloister"

	var plan := HousePlan.new()
	plan.spec = spec
	plan.world_family = FAMILY
	plan.world_subkind = SUBKIND
	var inner := HouseGeometry.interior_rect(spec)
	var court_size := Vector2(minf(inner.size.x * 0.42, inner.size.x - 8.0),
		minf(inner.size.y * 0.40, inner.size.y - 10.0))
	var court := Rect2(inner.get_center() - court_size * 0.5, court_size)
	plan.courts.append({"rect": court, "storey": 0, "id": "vihara_court"})

	# Four straight runs and four square returns tile a single continuous
	# cloister walk. Their shared edges are doors, not accidental wall seams.
	var west := _room(plan, &"gallery", "verandah_west",
		Rect2(Vector2(court.position.x - VERANDAH, court.position.y),
		Vector2(VERANDAH, court.size.y)))
	var east := _room(plan, &"gallery", "verandah_east",
		Rect2(Vector2(court.end.x, court.position.y),
		Vector2(VERANDAH, court.size.y)))
	var front := _room(plan, &"gallery", "verandah_front",
		Rect2(Vector2(court.position.x, court.position.y - VERANDAH),
		Vector2(court.size.x, VERANDAH)))
	var rear := _room(plan, &"gallery", "verandah_rear",
		Rect2(Vector2(court.position.x, court.end.y),
		Vector2(court.size.x, VERANDAH)))
	var front_west := _corner(plan, "verandah_corner_front_west",
		Vector2(court.position.x - VERANDAH, court.position.y - VERANDAH))
	var front_east := _corner(plan, "verandah_corner_front_east",
		Vector2(court.end.x, court.position.y - VERANDAH))
	var rear_west := _corner(plan, "verandah_corner_rear_west",
		Vector2(court.position.x - VERANDAH, court.end.y))
	var rear_east := _corner(plan, "verandah_corner_rear_east", court.end)
	var front_rect: Rect2 = plan.rooms[front]["rect"]
	var rear_rect: Rect2 = plan.rooms[rear]["rect"]
	var west_rect: Rect2 = plan.rooms[west]["rect"]
	var east_rect: Rect2 = plan.rooms[east]["rect"]
	_connect(plan, front, front_west, Vector2(court.position.x, front_rect.get_center().y), Vector2(-1, 0), "verandah_join")
	_connect(plan, front, front_east, Vector2(court.end.x, front_rect.get_center().y), Vector2(1, 0), "verandah_join")
	_connect(plan, rear, rear_west, Vector2(court.position.x, rear_rect.get_center().y), Vector2(-1, 0), "verandah_join")
	_connect(plan, rear, rear_east, Vector2(court.end.x, rear_rect.get_center().y), Vector2(1, 0), "verandah_join")
	_connect(plan, west, front_west, Vector2(west_rect.get_center().x, court.position.y), Vector2(0, -1), "verandah_join")
	_connect(plan, west, rear_west, Vector2(west_rect.get_center().x, court.end.y), Vector2(0, 1), "verandah_join")
	_connect(plan, east, front_east, Vector2(east_rect.get_center().x, court.position.y), Vector2(0, -1), "verandah_join")
	_connect(plan, east, rear_east, Vector2(east_rect.get_center().x, court.end.y), Vector2(0, 1), "verandah_join")

	# The main gate feeds the front verandah through a short axial passage.
	var entry_rect := Rect2(Vector2(inner.get_center().x - PASSAGE_WIDTH * 0.5,
		inner.position.y), Vector2(PASSAGE_WIDTH,
		front_rect.position.y - inner.position.y))
	var entry := _room(plan, &"antechamber", "vihara_entry_passage", entry_rect)
	plan.doors.append({"a": entry, "b": -1, "pos": Vector2(inner.get_center().x, inner.position.y),
		"normal": Vector2(0, -1), "width": 1.8, "sill": 0.0, "head": 2.4,
		"exterior": true, "front": true, "storey": 0, "role": "vihara_entry"})
	_connect(plan, entry, front, Vector2(inner.get_center().x,
		front_rect.position.y), Vector2(0, 1), "entry_verandah")

	# The shrine occupies the central rear bay, looking straight through the
	# court and gate. Cells keep the same measured 3 m module on every side.
	var shrine_width := minf(6.0, court.size.x * 0.5)
	var shrine_rect := Rect2(Vector2(court.get_center().x - shrine_width * 0.5,
		court.end.y + VERANDAH), Vector2(shrine_width, CELL_SIDE))
	var shrine := _room(plan, &"shrine", "vihara_shrine", shrine_rect)
	_connect(plan, shrine, rear, Vector2(court.get_center().x, shrine_rect.position.y),
		Vector2(0, -1), "shrine_axis_door")
	_add_row_cells(plan, court, rear, "rear", shrine_width)
	_add_row_cells(plan, court, front, "front", PASSAGE_WIDTH)
	_add_side_cells(plan, court, west, "west")
	_add_side_cells(plan, court, east, "east")

	# Four open thresholds let the cloister walk onto the court. These preserve
	# CourtCheck's real sky and ring tests while cells remain one doorway away.
	_open_court(plan, front, Vector2(court.get_center().x, court.position.y), Vector2(0, 1), "court_front")
	_open_court(plan, rear, Vector2(court.get_center().x, court.end.y), Vector2(0, -1), "court_rear")
	_open_court(plan, west, Vector2(court.position.x, court.get_center().y), Vector2(1, 0), "court_west")
	_open_court(plan, east, Vector2(court.end.x, court.get_center().y), Vector2(-1, 0), "court_east")

	var well_side := 1.8
	var well_rect := Rect2(court.get_center() - Vector2.ONE * well_side * 0.5,
		Vector2.ONE * well_side)
	plan.world_meta["court_rect"] = court
	plan.world_meta["verandah_rect"] = court.grow(VERANDAH)
	plan.world_meta["verandah_rooms"] = [west, east, front, rear,
		front_west, front_east, rear_west, rear_east]
	plan.world_meta["shrine_room"] = shrine
	plan.world_meta["entry_room"] = entry
	plan.world_meta["well_rect"] = well_rect
	plan.world_meta["water_rect"] = well_rect
	plan.world_meta["water_pos"] = court.get_center()
	plan.world_meta["eave_height"] = WALL_HEIGHT
	plan.water_plane = 0.18
	return {"spec": spec, "plan": plan}


static func _room(plan: HousePlan, kind: StringName, role: String,
		rect: Rect2) -> int:
	var index := plan.rooms.size()
	plan.rooms.append({"kind": kind, "role": role, "rect": rect, "storey": 0})
	return index


static func _corner(plan: HousePlan, role: String, position: Vector2) -> int:
	return _room(plan, &"gallery", role,
		Rect2(position, Vector2.ONE * VERANDAH))


static func _connect(plan: HousePlan, a: int, b: int, pos: Vector2,
		normal: Vector2, role: String) -> void:
	plan.doors.append({"a": a, "b": b, "pos": pos, "normal": normal,
		"width": 1.4, "exterior": false, "front": false,
		"storey": 0, "role": role})


static func _add_row_cells(plan: HousePlan, court: Rect2, veranda: int,
		side: String, reserved_width: float) -> void:
	var center_x := court.get_center().x
	var usable := maxf(0.0, court.size.x - reserved_width) * 0.5
	var count := int(floor(usable / CELL_SIDE))
	for i in range(count):
		var left_x := court.position.x + float(i) * CELL_SIDE
		var right_x := court.end.x - float(i + 1) * CELL_SIDE
		if side == "rear":
			_add_cell(plan, veranda, Rect2(Vector2(left_x, court.end.y + VERANDAH),
				Vector2.ONE * CELL_SIDE), Vector2(0, -1), "cell_rear")
			_add_cell(plan, veranda, Rect2(Vector2(right_x, court.end.y + VERANDAH),
				Vector2.ONE * CELL_SIDE), Vector2(0, -1), "cell_rear")
		else:
			front_y := court.position.y - VERANDAH - CELL_SIDE
			left_end := center_x - PASSAGE_WIDTH * 0.5
			right_start := center_x + PASSAGE_WIDTH * 0.5
			if left_x + CELL_SIDE <= left_end + 0.001:
				_add_cell(plan, veranda, Rect2(Vector2(left_x, front_y),
					Vector2.ONE * CELL_SIDE), Vector2(0, 1), "cell_front")
			if right_x >= right_start - 0.001:
				_add_cell(plan, veranda, Rect2(Vector2(right_x, front_y),
					Vector2.ONE * CELL_SIDE), Vector2(0, 1), "cell_front")


static func _add_side_cells(plan: HousePlan, court: Rect2, veranda: int,
		side: String) -> void:
	var count := int(floor(court.size.y / CELL_SIDE))
	var start_y := court.position.y + (court.size.y - float(count) * CELL_SIDE) * 0.5
	for i in range(count):
		var y := start_y + float(i) * CELL_SIDE
		if side == "west":
			_add_cell(plan, veranda, Rect2(Vector2(court.position.x - VERANDAH - CELL_SIDE, y),
				Vector2.ONE * CELL_SIDE), Vector2(1, 0), "cell_west")
		else:
			_add_cell(plan, veranda, Rect2(Vector2(court.end.x + VERANDAH, y),
				Vector2.ONE * CELL_SIDE), Vector2(-1, 0), "cell_east")


static func _add_cell(plan: HousePlan, veranda: int, rect: Rect2,
		normal: Vector2, role: String) -> void:
	var room := _room(plan, &"cell", role, rect)
	var pos := rect.get_center()
	if absf(normal.x) > 0.5:
		pos.x = rect.end.x if normal.x > 0.0 else rect.position.x
	else:
		pos.y = rect.end.y if normal.y > 0.0 else rect.position.y
	_connect(plan, room, veranda, pos, normal, "cell_verandah_door")


static func _open_court(plan: HousePlan, room: int, pos: Vector2,
		normal: Vector2, role: String) -> void:
	plan.doors.append({"a": room, "b": -1, "pos": pos, "normal": normal,
		"width": 1.8, "exterior": false, "front": false,
		"storey": 0, "role": role})
