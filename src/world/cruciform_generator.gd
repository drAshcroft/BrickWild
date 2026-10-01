class_name CruciformGenerator
extends RefCounted
## WLD-012: a four-entrance shrine with a linked pair of ambulatory rings.

const FAMILY := &"cruciform_temple"
const KIND := &"temple_of_four_winds"
const HALL_H := 14.0
const WALL_T := 0.8

static func generate(_kind: StringName, seed: int, width: float, length: float,
		height: float) -> Dictionary:
	var spec := HouseSpec.new(seed)
	spec.style = &"townhouse"
	spec.material = &"stone"
	spec.width = clampf(width, 60.0, 180.0)
	spec.length = clampf(length, 60.0, 180.0)
	spec.height = HALL_H
	spec.storeys = 1
	spec.trade = &"none"
	spec.wall_thickness_override = WALL_T
	spec.roof_type = &"flat"
	spec.roof_pitch = 0.0
	spec.porch = false
	spec.chimney = false
	spec.timber_frame = false
	spec.stone_ground_floor = true
	spec.variant_name = "Temple of Four Winds"

	var plan := HousePlan.new()
	plan.spec = spec
	plan.world_family = FAMILY
	plan.world_subkind = KIND
	var half_x := spec.width * 0.5
	var half_z := spec.length * 0.5
	var image_radius := minf(spec.width, spec.length) * 0.22
	var outer_ring_half := minf(spec.width, spec.length) * 0.36
	var inner_ring_half := minf(spec.width, spec.length) * 0.22
	var ring_width := 4.0
	var image_h := 3.2
	var images: Array[Dictionary] = []
	var entrances: Array[Dictionary] = []
	var directions := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	var roles := ["north", "east", "south", "west"]
	for i in range(4):
		var dir: Vector2 = directions[i]
		var entrance_pos := Vector2(dir.x * (half_x - WALL_T * 0.5), dir.y * (half_z - WALL_T * 0.5))
		var image_pos := Vector2(dir.x * image_radius, dir.y * image_radius)
		var image := {"id": "image_%s" % roles[i], "role": &"image",
			"pos": Vector3(image_pos.x, 0.0, image_pos.y), "height": image_h,
			"facing": Vector3(dir.x, 0.0, dir.y)}
		images.append(image)
		var door := {"id": "entrance_%s" % roles[i], "pos": entrance_pos,
			"normal": dir, "width": 4.0, "exterior": true, "front": i == 0,
			"storey": 0, "role": "cardinal_entrance"}
		entrances.append(door)
		plan.doors.append(door)
	var outer := _ring_segments(outer_ring_half, ring_width)
	var inner := _ring_segments(inner_ring_half, ring_width)
	var links: Array[Rect2] = []
	for dir2 in directions:
		var center := Vector2(dir2.x * (outer_ring_half + inner_ring_half) * 0.5,
			dir2.y * (outer_ring_half + inner_ring_half) * 0.5)
		var size := Vector2(ring_width, outer_ring_half - inner_ring_half)
		if absf(dir2.x) > 0.5:
			size = Vector2(outer_ring_half - inner_ring_half, ring_width)
		links.append(Rect2(center - size * 0.5, size))
	plan.world_meta = {"outer_ring": outer, "inner_ring": inner,
		"ring_links": links, "entrances": entrances, "images": images,
		"hall_rect": Rect2(Vector2(-half_x, -half_z), Vector2(spec.width, spec.length)),
		"hall_height": HALL_H, "sikhara_height": clampf(height, 32.0, 50.0),
		"sikhara_center": Vector3.ZERO, "ring_width": ring_width,
		"image_height": image_h}
	return {"spec": spec, "plan": plan}


static func _ring_segments(half: float, width: float) -> Array[Rect2]:
	var span := half * 2.0
	var edge := half - width * 0.5
	return [
		Rect2(Vector2(-half, -edge - width * 0.5), Vector2(span, width)),
		Rect2(Vector2(-half, edge - width * 0.5), Vector2(span, width)),
		Rect2(Vector2(-edge - width * 0.5, -half), Vector2(width, span)),
		Rect2(Vector2(edge - width * 0.5, -half), Vector2(width, span)),
	]
