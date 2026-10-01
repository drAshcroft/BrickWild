class_name HammamGenerator
extends RefCounted
## Deterministic four-stage steam-bath plan (WLD-005).

const FAMILY := &"hammam"
const SUBKIND := &"steam_baths"
const STATIONS: Array[StringName] = [&"changing", &"cold", &"warm", &"hot"]


static func generate(p_seed: int, width: float, length: float,
		wall_height: float) -> Dictionary:
	var spec := HouseSpec.new(p_seed)
	spec.style = &"townhouse"
	spec.material = &"stone"
	spec.width = maxf(width, 14.0)
	spec.length = maxf(length, 10.0)
	spec.height = maxf(wall_height, 6.0)
	spec.storeys = 1
	spec.trade = &"none"
	spec.wall_thickness_override = 0.6
	spec.roof_type = &"hipped" # HammamBuilder emits the flat oculus roof.
	spec.roof_pitch = 0.0
	spec.dormers = false
	spec.dormer_count = 0
	spec.porch = false
	spec.chimney = false
	spec.timber_frame = false
	spec.stone_ground_floor = true
	spec.plinth_height = 0.35
	spec.wall_color = Color("c7bba6")
	spec.trim_color = Color("8c765e")
	spec.roof_color = Color("b7a890")
	spec.floor_color = Color("9c8d77")
	spec.clutter = 0.0
	spec.variant_name = "Steam Baths"

	var plan := HousePlan.new()
	plan.spec = spec
	plan.world_family = FAMILY
	plan.world_subkind = SUBKIND
	var inner := HouseGeometry.interior_rect(spec)
	var half := inner.size * 0.5
	var mid := inner.get_center()
	var front_left := Rect2(inner.position, half)
	var front_right := Rect2(Vector2(mid.x, inner.position.y), half)
	var back_left := Rect2(Vector2(inner.position.x, mid.y), half)
	var back_right := Rect2(mid, half)
	var rects: Array[Rect2] = [front_left, front_right, back_right, back_left]
	var ids: Dictionary = {}
	for station in range(STATIONS.size()):
		var role := STATIONS[station]
		ids[role] = station
		plan.rooms.append({"kind": &"gallery", "role": role,
			"rect": rects[station], "storey": 0})

	# The room path snakes through four near-square thermal stages. The middle
	# turns are doors in shared walls; there is no branch into the furnace.
	var entry_pos := Vector2(front_left.get_center().x, inner.position.y)
	plan.doors.append({"a": int(ids[&"changing"]), "b": -1,
		"pos": entry_pos, "normal": Vector2(0, -1),
		"width": HouseGeometry.DOOR_W, "exterior": true, "front": true,
		"storey": 0, "role": "hammam_entry"})
	plan.doors.append(_inner_door(int(ids[&"changing"]), int(ids[&"cold"]),
		Vector2(mid.x, front_left.get_center().y), Vector2(1, 0), "changing_cold"))
	plan.doors.append(_inner_door(int(ids[&"cold"]), int(ids[&"warm"]),
		Vector2(front_right.get_center().x, mid.y), Vector2(0, 1), "cold_warm"))
	plan.doors.append(_inner_door(int(ids[&"warm"]), int(ids[&"hot"]),
		Vector2(mid.x, back_right.get_center().y), Vector2(-1, 0), "warm_hot"))

	var warm := int(ids[&"warm"])
	var hot := int(ids[&"hot"])
	# Three separate roof cuts over the warm room, arranged within its raised
	# dome's open crown; the hottest room has one crown oculus of its own.
	for i in range(3):
		var offset := float(i - 1) * minf(back_right.size.x * 0.035, 0.55)
		_add_oculus(plan, warm, "warm_%d" % i,
			back_right.get_center() + Vector2(offset, 0.0), 0.22)
	_add_oculus(plan, hot, "hot_0", back_left.get_center(), 0.22)

	plan.world_meta["station_order"] = STATIONS.duplicate()
	plan.world_meta["entry"] = entry_pos
	plan.world_meta["furnace_room"] = hot
	return {"spec": spec, "plan": plan}


static func _inner_door(a: int, b: int, pos: Vector2, normal: Vector2,
		role: String) -> Dictionary:
	return {"a": a, "b": b, "pos": pos, "normal": normal,
		"width": HouseGeometry.INNER_DOOR_W, "exterior": false,
		"front": false, "storey": 0, "role": role}


static func _add_oculus(plan: HousePlan, room: int, suffix: String,
		center: Vector2, radius: float) -> void:
	var rect := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	plan.roof_openings.append({"id": "hammam_oculus_%s" % suffix,
		"kind": &"oculus", "storey": 0, "face": -1,
		"rect": rect, "room": room})
