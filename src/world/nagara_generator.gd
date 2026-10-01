class_name NagaraGenerator
extends RefCounted
## WLD-013: axial North Indian temple with ascending halls and a clustered shikhara.

const FAMILY := &"nagara"
const KIND := &"hundred_spires"
const WALL_T := 0.55
const PLINTH_FRACTION := 0.15

static func generate(kind: StringName, seed: int, width: float, length: float,
		height: float) -> Dictionary:
	var spec := HouseSpec.new(seed)
	spec.style = &"townhouse"
	spec.material = &"stone"
	spec.width = clampf(width, 18.0, 52.0)
	spec.length = clampf(length, 20.0, 64.0)
	spec.height = 8.0
	spec.storeys = 1
	spec.trade = &"none"
	spec.wall_thickness_override = WALL_T
	spec.roof_type = &"flat"
	spec.roof_pitch = 0.0
	spec.porch = false
	spec.chimney = false
	spec.timber_frame = false
	spec.stone_ground_floor = true
	spec.variant_name = "Spire of a Hundred Spires"
	var total_height := clampf(height, 24.0, 60.0)
	var plinth_h := total_height * PLINTH_FRACTION
	var shikhara_h := total_height - plinth_h
	var plan := HousePlan.new()
	plan.spec = spec
	plan.world_family = FAMILY
	plan.world_subkind = kind
	var axis_len := minf(spec.length * 0.92, 26.0)
	var front_z := -axis_len * 0.5
	var hall_rows: Array[Dictionary] = [
		{"role": "ardhamandapa", "kind": &"ardhamandapa", "width": spec.width * 0.48, "depth": axis_len * 0.17, "height": shikhara_h * 0.23},
		{"role": "mandapa", "kind": &"mandapa", "width": spec.width * 0.62, "depth": axis_len * 0.19, "height": shikhara_h * 0.31},
		{"role": "mahamandapa", "kind": &"mahamandapa", "width": spec.width * 0.76, "depth": axis_len * 0.32, "height": shikhara_h * 0.40},
		{"role": "antarala", "kind": &"antarala", "width": spec.width * 0.43, "depth": axis_len * 0.10, "height": shikhara_h * 0.48},
	]
	var rooms: Array[Dictionary] = []
	var cursor := front_z
	for row in hall_rows:
		var rect := Rect2(Vector2(-float(row["width"]) * 0.5, cursor),
			Vector2(float(row["width"]), float(row["depth"])))
		rooms.append({"kind": row["kind"], "role": row["role"], "rect": rect,
			"outline": _rect_outline(rect), "storey": 0, "wall_thickness": WALL_T})
		cursor = rect.end.y
	var sanctum_side := minf(spec.width * 0.15, 4.0)
	var sanctum_rect := Rect2(Vector2(-sanctum_side * 0.5, cursor),
		Vector2(sanctum_side, sanctum_side))
	rooms.append({"kind": &"garbhagriha", "role": "garbhagriha", "rect": sanctum_rect,
		"outline": _rect_outline(sanctum_rect), "storey": 0, "wall_thickness": WALL_T})
	plan.rooms.assign(rooms)
	var entry := Vector2(0.0, front_z)
	plan.doors.append({"a": 0, "b": -1, "pos": entry, "normal": Vector2(0, -1),
		"width": minf(2.4, float(hall_rows[0]["width"]) * 0.45), "exterior": true,
		"front": true, "storey": 0, "role": "temple_entry"})
	for i in range(rooms.size() - 1):
		var partition_z := (rooms[i]["rect"] as Rect2).end.y
		plan.doors.append({"a": i, "b": i + 1, "pos": Vector2.ZERO + Vector2(0, partition_z),
			"normal": Vector2(0, 1), "width": minf(2.0, sanctum_side * 0.65),
			"exterior": false, "front": false, "storey": 0,
			"role": "sanctum_door" if i + 1 == rooms.size() - 1 else "axial_passage"})
	var plinth_rect := Rect2(Vector2(-spec.width * 0.46, front_z - 3.2),
		Vector2(spec.width * 0.92, axis_len + 6.4))
	var ring_gap := 1.25
	var ring_outer := sanctum_rect.grow(ring_gap * 2.0)
	var ring_inner := sanctum_rect.grow(ring_gap)
	var ring := _ring_rects(ring_inner, ring_outer)
	var hall_heights: Array[float] = []
	for row in hall_rows:
		hall_heights.append(float(row["height"]))
	var spire_center := Vector3(0.0, plinth_h, sanctum_rect.get_center().y)
	var image := Vector3(0.0, plinth_h, sanctum_rect.get_center().y)
	var hall_rects: Array[Rect2] = []
	for i in range(4):
		var hall_rect: Rect2 = rooms[i]["rect"]
		hall_rects.append(hall_rect)
	plan.stairs.append({"a": 0, "b": 0, "pos": Vector2(0.0, front_z - 1.4),
		"width": minf(3.2, spec.width * 0.25), "run": 3.2, "steps": 6,
		"role": "plinth_stair", "exterior": true})
	plan.world_meta = {"total_height": total_height, "plinth_height": plinth_h,
		"plinth_rect": plinth_rect, "hall_rects": hall_rects,
		"hall_heights": hall_heights, "sanctum_rect": sanctum_rect,
		"ring_inner": ring_inner, "ring_outer": ring_outer, "pradakshina": ring,
		"shikhara_height": shikhara_h, "shikhara_center": spire_center,
		"spire_base_radius": maxf(sanctum_side * 1.30, 3.3), "image": image,
		"entry": entry, "door_count_sanctum": 1}
	return {"spec": spec, "plan": plan}


static func _rect_outline(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,
		Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)])


static func _ring_rects(inner: Rect2, outer: Rect2) -> Array[Rect2]:
	return [
		Rect2(Vector2(outer.position.x, outer.position.y), Vector2(outer.size.x, inner.position.y - outer.position.y)),
		Rect2(Vector2(inner.end.x, outer.position.y), Vector2(outer.end.x - inner.end.x, outer.size.y)),
		Rect2(Vector2(outer.position.x, inner.end.y), Vector2(outer.size.x, outer.end.y - inner.end.y)),
		Rect2(Vector2(outer.position.x, outer.position.y), Vector2(inner.position.x - outer.position.x, outer.size.y)),
	]
