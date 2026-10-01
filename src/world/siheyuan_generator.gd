class_name SiheyuanGenerator
extends RefCounted
## WLD-007: a south-facing Chinese courtyard compound.

const FAMILY := &"siheyuan"
const SUBKIND := &"scholars_compound"
const WALL_HEIGHT := 5.0


static func generate(seed: int, width: float, length: float, height: float,
		orientation := 0.0, period: int = 1200,
		kind: StringName = SUBKIND) -> Dictionary:
	# The entry and court are laid out in a local frame. At zero yaw the front
	# gate is on local -Z (south); placement yaw rotates the whole authored plan.
	var spec := HouseSpec.new(seed)
	spec.style = &"townhouse"
	spec.material = &"stone"
	spec.width = width
	spec.length = length
	spec.height = minf(height, WALL_HEIGHT)
	spec.orientation = orientation
	spec.period = period
	spec.storeys = 1
	spec.trade = &"none"
	spec.wall_thickness_override = 0.2
	spec.roof_type = &"hipped"
	spec.roof_pitch = 0.11
	spec.dormers = false
	spec.dormer_count = 0
	spec.porch = false
	spec.chimney = false
	spec.timber_frame = false
	spec.stone_ground_floor = true
	spec.plinth_height = 0.25
	spec.wall_color = Color("c8b98d")
	spec.trim_color = Color("8b412f")
	spec.roof_color = Color("4c3430")
	spec.floor_color = Color("9a8060")
	spec.clutter = 0.0
	spec.variant_name = "Scholar's Compound"

	var plan := HousePlan.new()
	plan.spec = spec
	plan.world_family = FAMILY
	plan.world_subkind = kind
	plan.blind_entry = true
	var inner := HouseGeometry.interior_rect(spec)
	var front := inner.position.y
	var rear := inner.end.y
	# Fixed clearances are checked before layout. No hidden clamping: an
	# undersized or excessively shortened brief must be refused upstream.
	if inner.size.x < 20.0 or inner.size.y < 28.0 or spec.height < 4.0:
		return {"error": "siheyuan: site is too small for the gate, court, halls and mirrored wings"}
	if kind == SUBKIND and length > 50.0:
		return {"error": "siheyuan: a one-court compound does not use the elongated multi-court envelope"}
	if kind == &"two_court_compound" and inner.size.y < 58.0:
		return {"error": "siheyuan: terrain is too short for two courts with their intervening hall"}
	var court_w := minf(8.0, inner.size.x * 0.38)
	var court_d := minf(10.0, inner.size.y * 0.34)
	var court := Rect2(Vector2(-court_w * 0.5, -court_d * 0.5),
		Vector2(court_w, court_d))
	# The south gate sits at the east/front corner, well away from the central axis.
	var passage_w := minf(4.0, (inner.size.x - court_w) * 0.5)
	var wing_w := (inner.size.x - court_w - 4.0 - passage_w * 0.5) * 0.5
	var wing_depth := minf(12.0, court_d + 2.0)
	var hall_w := minf(inner.size.x * 0.82, wing_w * 2.0 + 0.5)
	var hall_depth := minf(7.0, inner.size.y * 0.22)
	if wing_w < 3.2 or wing_depth < 8.0 or hall_w < 7.0 or hall_depth < 5.0:
		return {"error": "siheyuan: terrain envelope cannot fit the required compound clearances"}
	var west_x := -court_w * 0.5 - 2.0 - wing_w
	var east_x := court.end.x + 2.0
	var side_y := court.position.y
	var side_h := court.size.y
	var gate_x := inner.end.x - passage_w * 0.5
	var hall_y := minf(court.end.y + 2.0, rear - hall_depth)
	var hall_rect := Rect2(Vector2(-hall_w * 0.5, hall_y), Vector2(hall_w, hall_depth))
	var left_wing := Rect2(Vector2(west_x, side_y), Vector2(wing_w, side_h))
	var right_wing := Rect2(Vector2(east_x, side_y), Vector2(wing_w, side_h))
	var west_walk := Rect2(Vector2(west_x + wing_w, court.position.y),
		Vector2(2.0, court.size.y))
	var east_walk := Rect2(Vector2(court.end.x, court.position.y), Vector2(2.0, court.size.y))
	var rear_walk := Rect2(Vector2(court.position.x - 2.0, court.end.y), Vector2(court.size.x + 4.0, 2.0))
	var front_walk := Rect2(Vector2(court.position.x - 2.0, court.position.y - 2.0),
		Vector2(gate_x - (court.position.x - 2.0), 2.0))
	var gate_room := Rect2(Vector2(gate_x - passage_w * 0.5, front),
		Vector2(passage_w, maxf(7.0, court.position.y - front)))
	var screen := Rect2(Vector2(gate_room.position.x + 0.25,
		front + 2.5), Vector2(gate_room.size.x - 0.5, 0.25))

	plan.courts.append({"rect": court, "storey": 0, "id": "scholars_court"})
	if kind == &"two_court_compound":
		var second := Rect2(Vector2(-court_w * 0.5, court.end.y + 15.0),
			Vector2(court_w, court_d * 0.8))
		if second.end.y > inner.end.y:
			return {"error": "siheyuan: second court does not fit inside the terrain envelope"}
		plan.courts.append({"rect": second, "storey": 0, "id": "scholars_inner_court"})
		spec.variant_name = "Two-Court Siheyuan"
	var fauces := _room(plan, &"antechamber", "fauces", gate_room)
	var hall := _room(plan, &"hall", "main_hall", hall_rect)
	var west := _room(plan, &"hall", "wing_west", left_wing)
	var east := _room(plan, &"hall", "wing_east", right_wing)
	var west_verandah := _room(plan, &"gallery", "verandah_west", west_walk)
	var east_verandah := _room(plan, &"gallery", "verandah_east", east_walk)
	var rear_verandah := _room(plan, &"gallery", "verandah_rear", rear_walk)
	var front_verandah := _room(plan, &"gallery", "verandah_front", front_walk)
	var street_door := Vector2(gate_x, front)
	plan.doors.append({"a": fauces, "b": -1, "pos": street_door,
		"normal": Vector2(0, -1), "width": minf(2.2, passage_w * 0.55),
		"sill": 0.0, "head": 2.8, "exterior": true, "front": true,
		"storey": 0, "role": "siheyuan_corner_gate"})
	# Doors follow the continuous three-sided verandah from hall to both wings.
	_connect(plan, hall, rear_verandah, Vector2(0, rear_walk.end.y), Vector2(0, -1), "hall_verandah")
	_connect(plan, west, west_verandah, Vector2(west_walk.position.x, 0), Vector2(1, 0), "west_verandah_door")
	_connect(plan, east, east_verandah, Vector2(east_walk.end.x, 0), Vector2(-1, 0), "east_verandah_door")
	_connect(plan, fauces, front_verandah, Vector2(gate_x, front_walk.end.y), Vector2(0, 1), "gate_verandah")
	_connect(plan, west_verandah, rear_verandah, Vector2(court.position.x - 1.0, court.end.y), Vector2(0, 1), "verandah_rear_west")
	_connect(plan, east_verandah, rear_verandah, Vector2(court.end.x + 1.0, court.end.y), Vector2(0, 1), "verandah_rear_east")
	_connect(plan, front_verandah, west_verandah, Vector2(court.position.x - 1.0, court.position.y), Vector2(0, 1), "verandah_front_west")
	_connect(plan, front_verandah, east_verandah, Vector2(court.end.x + 1.0, court.position.y), Vector2(0, 1), "verandah_front_east")
	# Four openings open the rooms and verandah onto real court walls.
	_connect(plan, west_verandah, -1, Vector2(court.position.x, 0), Vector2(1, 0), "court_west")
	_connect(plan, east_verandah, -1, Vector2(court.end.x, 0), Vector2(-1, 0), "court_east")
	_connect(plan, rear_verandah, -1, Vector2(0, court.end.y), Vector2(0, -1), "court_rear")
	_connect(plan, front_verandah, -1, Vector2(0, court.position.y), Vector2(0, 1), "court_front")
	# Exact mirror coordinates are a design invariant; do not randomize one wing.
	plan.world_meta["site_rect"] = inner
	plan.world_meta["court_rect"] = court
	plan.world_meta["blind_screen"] = screen
	plan.world_meta["street_door"] = street_door
	plan.world_meta["gate_room"] = fauces
	plan.world_meta["main_hall_room"] = hall
	plan.world_meta["main_hall_rect"] = hall_rect
	plan.world_meta["wing_rooms"] = [west, east]
	plan.world_meta["verandah_rooms"] = [west_verandah, east_verandah, rear_verandah, front_verandah]
	plan.world_meta["hall_door"] = Vector2(0, rear_walk.end.y)
	plan.world_meta["wing_doors"] = [Vector2(west_walk.position.x, 0), Vector2(east_walk.end.x, 0)]
	plan.world_meta["orientation"] = orientation
	plan.world_meta["period"] = period
	plan.world_meta["eave_height"] = spec.height
	plan.world_meta["hall_ridge_height"] = spec.height + HouseGeometry.roof_rise(spec) + 0.25
	plan.world_meta["axis_x"] = 0.0
	plan.world_meta["hall_far_wall_y"] = hall_rect.end.y
	plan.world_meta["south_front_y"] = front
	plan.world_meta["terrain_envelope"] = {"width": width, "length": length, "height": height}
	return {"spec": spec, "plan": plan}


static func _room(plan: HousePlan, kind: StringName, role: String, rect: Rect2) -> int:
	var index := plan.rooms.size()
	plan.rooms.append({"kind": kind, "role": role, "rect": rect, "storey": 0})
	return index


static func _connect(plan: HousePlan, a: int, b: int, pos: Vector2,
		normal: Vector2, role: String) -> void:
	plan.doors.append({"a": a, "b": b, "pos": pos, "normal": normal,
		"width": 1.4, "exterior": false, "front": false, "storey": 0, "role": role})
