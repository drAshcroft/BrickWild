class_name PagodaGenerator
extends RefCounted
## WLD-009: polygonal pagoda floors, a narrowing roof tier per storey, and an
## axial mast beneath a compact crown. HousePlan remains the floor truth.

const FAMILY := &"pagoda"
const FLOOR_FRACTION := 0.85
const TAPER := 0.93


static func generate(kind: StringName, seed: int, width: float, length: float,
		height: float) -> Dictionary:
	var spec := HouseSpec.new(seed)
	spec.style = &"townhouse"
	spec.material = &"stone"
	spec.width = clampf(width, 20.0, 57.0)
	spec.length = clampf(length, 20.0, 57.0)
	var total_height := clampf(height, 40.0, 144.0)
	var storeys := clampi(roundi(total_height / 7.2222), 3, 15)
	if storeys % 2 == 0:
		storeys += 1 if storeys < 15 else -1
	spec.height = total_height * FLOOR_FRACTION / float(storeys)
	spec.storeys = storeys
	spec.trade = &"none"
	spec.wall_thickness_override = 0.42
	spec.roof_pitch = 0.0
	spec.roof_type = &"flat"
	spec.porch = false
	spec.chimney = false
	spec.timber_frame = false
	spec.stone_ground_floor = true
	spec.plinth_height = 0.35
	spec.variant_name = "Nine-Storey Pagoda" if storeys == 9 else "%d-Storey Pagoda" % storeys

	var sides := _side_count(kind)
	var rotation := _rotation(sides)
	var base_radius := minf(spec.width, spec.length) * (0.62 if sides == 4 else 0.43)
	var plan := HousePlan.new()
	plan.spec = spec
	plan.world_family = FAMILY
	plan.world_subkind = kind
	var tiers: Array[Dictionary] = []
	var floor_radii: Array[float] = []
	for level in range(storeys):
		var tier_width := minf(spec.width, spec.length) * 0.92 * pow(TAPER, level)
		var tier_height := maxf(0.28, 0.82 * pow(0.94, level))
		var floor_radius := base_radius * pow(TAPER, level)
		var tier_y := spec.height * float(level + 1) - tier_height * 0.5
		var outline := _polygon(floor_radius, sides, rotation)
		plan.rooms.append({"kind": &"hall", "role": "pagoda_storey_%d" % level,
			"rect": Poly.bounding_rect(outline), "outline": outline,
			"storey": level, "wall_thickness": HouseGeometry.wall_thickness(spec)})
		floor_radii.append(floor_radius)
		tiers.append({"storey": level, "width": tier_width,
			"height": tier_height, "y": tier_y, "room": room_index})

	# A single front entrance on the lowest edge, with its opening cut by the
	# ordinary polygon shell emitter.
	var base_outline := plan.outline_of(0)
	var front_edge := _front_edge(base_outline)
	var from: Vector2 = front_edge["from"]
	var to: Vector2 = front_edge["to"]
	var normal: Vector2 = front_edge["normal"]
	var entry := (from + to) * 0.5
	plan.doors.append({"a": 0, "b": -1, "pos": entry, "normal": normal,
		"width": minf(2.4, from.distance_to(to) * 0.45), "exterior": true,
		"front": true, "storey": 0, "role": "pagoda_entry"})

	var stair_rooms: Array[int] = []
	var stair_rects: Array[Rect2] = []
	for level in range(storeys):
		stair_rooms.append(level)
		var angle := rotation + TAU * float(level % 4) / 4.0 + PI / 4.0
		var landing_center := Vector2(cos(angle), sin(angle)) * floor_radii[level] * 0.30
		var stair_rect := Rect2(landing_center - Vector2(1.25, 1.65), Vector2(2.5, 3.3))
		stair_rects.append(stair_rect)
	for level in range(storeys - 1):
		var lower := stair_rects[level]
		var upper := stair_rects[level + 1]
		plan.stairs.append({"a": stair_rooms[level], "b": stair_rooms[level + 1],
			"storey": level, "to_storey": level + 1, "pos": lower.get_center(),
			"lower_pos": lower.get_center(), "upper_pos": upper.get_center(),
			"rect": lower, "lower_rect": lower, "upper_rect": upper,
			"width": 1.8, "run": 3.3, "steps": 12})

	var footprint_side := minf(spec.width, spec.length) * 0.92
	var footprint := Rect2(Vector2(-footprint_side * 0.5, -footprint_side * 0.5),
		Vector2(footprint_side, footprint_side))
	plan.world_meta = {"total_height": total_height, "base_width": minf(spec.width, spec.length),
		"storey_count": storeys, "side_count": sides, "rotation": rotation,
		"eave_tiers": tiers, "floor_radii": floor_radii,
		"stair_rooms": stair_rooms, "stair_rects": stair_rects,
		"mast_height": total_height * FLOOR_FRACTION,
		"mast_radius": 0.34, "finial_height": total_height * (1.0 - FLOOR_FRACTION),
		"footprint": footprint, "entry": entry}
	return {"spec": spec, "plan": plan}


static func _side_count(kind: StringName) -> int:
	match kind:
		&"octagonal_pagoda": return 8
		&"dodecagonal_pagoda": return 12
		_: return 4


static func _rotation(sides: int) -> float:
	return PI / 4.0 if sides == 4 else PI / float(sides)


static func _polygon(radius: float, sides: int, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := rotation + TAU * float(i) / float(sides)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


static func _front_edge(outline: PackedVector2Array) -> Dictionary:
	var best := {"from": outline[0], "to": outline[1], "normal": Vector2(0.0, -1.0)}
	var front_y := INF
	for i in range(outline.size()):
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var mid := (a + b) * 0.5
		if mid.y >= front_y:
			continue
		var d := (b - a).normalized()
		front_y = mid.y
		best = {"from": a, "to": b, "normal": Vector2(d.y, -d.x)}
	return best
