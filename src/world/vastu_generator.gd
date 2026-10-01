class_name VastuGenerator
extends RefCounted
## WLD-019: a two-storey haveli around a small central light-well court.

const FAMILY := &"vastu"
const SUBKIND := &"merchants_haveli"


static func generate(seed: int, width: float, length: float,
		total_height: float) -> Dictionary:
	var spec := HouseSpec.new(seed)
	spec.style = &"townhouse"
	spec.material = &"stone"
	spec.width = clampf(width, 12.0, 36.0)
	spec.length = clampf(length, 18.0, 48.0)
	spec.storeys = 2
	spec.height = clampf(total_height, 7.0, 16.0) / float(spec.storeys)
	spec.trade = &"none"
	spec.wall_thickness_override = 0.35
	spec.roof_type = &"flat"
	spec.roof_pitch = 0.04
	spec.dormers = false
	spec.dormer_count = 0
	spec.porch = false
	spec.chimney = false
	spec.timber_frame = false
	spec.stone_ground_floor = true
	spec.plinth_height = 0.35
	spec.wall_color = Color("c9a66b")
	spec.trim_color = Color("7f4f32")
	spec.roof_color = Color("8a6a45")
	spec.floor_color = Color("b9935a")
	spec.clutter = 0.0
	spec.variant_name = "Merchant's Haveli"

	var plan := HousePlan.new()
	plan.spec = spec
	plan.world_family = FAMILY
	plan.world_subkind = SUBKIND
	var site := HouseGeometry.site_rect(spec)
	var inner := HouseGeometry.interior_rect(spec)
	var court_size := Vector2(minf(4.5, inner.size.x * 0.38),
		minf(5.0, inner.size.y * 0.24))
	var court := Rect2(inner.get_center() - court_size * 0.5, court_size)
	plan.courts.append({"rect": court, "storey": 0, "id": "vastu_court_0"})
	plan.courts.append({"rect": court, "storey": 1, "id": "vastu_court_1"})

	var split_x := inner.get_center().x
	var front_depth := court.position.y - inner.position.y
	var rear_depth := inner.end.y - court.end.y
	var front_west := Rect2(inner.position,
		Vector2(split_x - inner.position.x, front_depth))
	var kitchen_rect := Rect2(Vector2(split_x, inner.position.y),
		Vector2(inner.end.x - split_x, front_depth))
	var rear := Rect2(Vector2(inner.position.x, court.end.y),
		Vector2(inner.size.x, rear_depth))
	var west := Rect2(Vector2(inner.position.x, court.position.y),
		Vector2(court.position.x - inner.position.x, court.size.y))
	var east := Rect2(Vector2(court.end.x, court.position.y),
		Vector2(inner.end.x - court.end.x, court.size.y))

	var entry := _room(plan, &"antechamber", "vastu_entry_hall", front_west, 0)
	var kitchen := _room(plan, &"kitchen", "vastu_kitchen", kitchen_rect, 0)
	var main_hall := _room(plan, &"great_hall", "vastu_main_hall", rear, 0)
	var west_wing := _room(plan, &"gallery", "vastu_west_wing", west, 0)
	var east_wing := _room(plan, &"gallery", "vastu_east_wing", east, 0)
	for row in [
		[&"bedroom", "vastu_upper_front_west", front_west],
		[&"bedroom", "vastu_upper_front_east", kitchen_rect],
		[&"great_hall", "vastu_upper_main_hall", rear],
		[&"gallery", "vastu_upper_west_wing", west],
		[&"gallery", "vastu_upper_east_wing", east],
	]:
		_room(plan, row[0], row[1], row[2], 1)

	var entrance_pos := Vector2(front_west.get_center().x, site.position.y)
	plan.doors.append({"a": entry, "b": -1, "pos": entrance_pos,
		"normal": Vector2(0, -1), "width": 1.4, "sill": 0.0, "head": 2.4,
		"exterior": true, "front": true, "storey": 0, "role": "vastu_entry"})
	_connect(plan, entry, kitchen, Vector2(split_x, front_west.get_center().y),
		Vector2(1, 0), "entry_kitchen")
	_open_court(plan, entry, Vector2(front_west.get_center().x, court.position.y),
		Vector2(0, 1), "entry_court")
	_open_court(plan, kitchen, Vector2(kitchen_rect.get_center().x, court.position.y),
		Vector2(0, 1), "kitchen_court")
	_open_court(plan, main_hall, Vector2(court.get_center().x, court.end.y),
		Vector2(0, -1), "hall_court")
	_open_court(plan, west_wing, Vector2(court.position.x, court.get_center().y),
		Vector2(1, 0), "west_court")
	_open_court(plan, east_wing, Vector2(court.end.x, court.get_center().y),
		Vector2(-1, 0), "east_court")

	# The well belongs to the north-east quarter, clear of the central cell.
	var well_side := minf(1.5, minf(east.size.x, rear.size.y) * 0.42)
	var well_center := Vector2(court.end.x + east.size.x * 0.55,
		court.end.y + rear.size.y * 0.35)
	var well_rect := Rect2(well_center - Vector2.ONE * well_side * 0.5,
		Vector2.ONE * well_side)
	plan.world_meta = {
		"site": site, "court_rect": court, "kitchen_room": kitchen,
		"main_hall_room": main_hall, "entry_room": entry,
		"well_rect": well_rect, "water_rect": well_rect,
		"eave_height": spec.height, "jharokha_floor": spec.height,
	}
	plan.water_plane = 0.16
	return {"spec": spec, "plan": plan}


static func _room(plan: HousePlan, kind: StringName, role: String,
		rect: Rect2, storey: int) -> int:
	var index := plan.rooms.size()
	plan.rooms.append({"kind": kind, "role": role, "rect": rect, "storey": storey})
	return index


static func _connect(plan: HousePlan, a: int, b: int, pos: Vector2,
		normal: Vector2, role: String) -> void:
	plan.doors.append({"a": a, "b": b, "pos": pos, "normal": normal,
		"width": 1.2, "exterior": false, "front": false,
		"storey": 0, "role": role})


static func _open_court(plan: HousePlan, room: int, pos: Vector2,
		normal: Vector2, role: String) -> void:
	plan.doors.append({"a": room, "b": -1, "pos": pos, "normal": normal,
		"width": 1.4, "exterior": false, "front": false,
		"storey": 0, "role": role})
