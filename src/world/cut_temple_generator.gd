class_name CutTempleGenerator
extends RefCounted
## WLD-015: a monolithic temple left standing inside a quarried court.

const FAMILY := &"rock_cut_temple"
const SUBKIND := &"quarried_temple"
const GALLERY_Y := -12.0
const WALL_T := 0.8


static func generate(seed: int, width: float, length: float, depth: float) -> Dictionary:
	var spec := HouseSpec.new(seed)
	spec.style = &"townhouse"
	spec.material = &"stone"
	spec.width = clampf(width, 57.4, 155.8)
	spec.length = clampf(length, 32.2, 87.4)
	spec.height = clampf(depth, 21.0, 38.0)
	spec.storeys = 1
	spec.trade = &"none"
	spec.wall_thickness_override = WALL_T
	spec.roof_type = &"flat"
	spec.porch = false
	spec.chimney = false
	spec.timber_frame = false
	spec.stone_ground_floor = true
	spec.wall_color = Color("9b8060")
	spec.trim_color = Color("6d5037")
	spec.roof_color = Color("5d402b")
	spec.floor_color = Color("806549")
	spec.variant_name = "Quarried Temple"

	var plan := HousePlan.new()
	plan.spec = spec
	plan.world_family = FAMILY
	plan.world_subkind = SUBKIND
	var site := Rect2(Vector2(-spec.width * 0.5, -spec.length * 0.5),
		Vector2(spec.width, spec.length))
	var floor_y := -spec.height
	var gallery_y := maxf(GALLERY_Y * minf(spec.height / 30.0, 1.0), floor_y + 7.0)
	var gallery_width := maxf(2.2, minf(spec.width, spec.length) * 0.065)
	var inner := site.grow(-WALL_T)
	var gallery := _ring(inner, gallery_width)
	var scale := minf(spec.width / 82.0, spec.length / 46.0)
	var temple_width := 20.0 * scale
	var porch := Rect2(Vector2(-6.0 * scale, -7.0 * scale),
		Vector2(12.0 * scale, 5.0 * scale))
	var hall := Rect2(Vector2(-9.0 * scale, -2.0 * scale),
		Vector2(18.0 * scale, 11.0 * scale))
	var sanctum := Rect2(Vector2(-5.0 * scale, 9.0 * scale),
		Vector2(10.0 * scale, 9.0 * scale))
	var temple_rect := Rect2(Vector2(-temple_width * 0.5, porch.position.y - 1.0 * scale),
		Vector2(temple_width, sanctum.end.y - porch.position.y + 2.0 * scale))
	var nandi := Rect2(Vector2(-4.0 * scale, -15.0 * scale),
		Vector2(8.0 * scale, 5.0 * scale))
	var bridge := Rect2(Vector2(-1.3 * scale, gallery[0].end.y - 0.3),
		Vector2(2.6 * scale, porch.position.y - gallery[0].end.y + 0.6))
	var gateway := Rect2(Vector2(-4.0 * scale, site.position.y),
		Vector2(8.0 * scale, WALL_T + 0.4))

	# Negative storeys retain the real occupied datum. The gateway alone starts
	# at grade; every ritual room is twelve metres down in the cut.
	plan.rooms.append({"kind": &"antechamber", "role": "gateway",
		"rect": gateway, "storey": 0, "elevation": 0.0})
	plan.rooms.append({"kind": &"shrine", "role": "nandi_mandapa",
		"rect": nandi, "storey": -2, "elevation": gallery_y})
	plan.rooms.append({"kind": &"antechamber", "role": "porch",
		"rect": porch, "storey": -2, "elevation": gallery_y})
	plan.rooms.append({"kind": &"great_hall", "role": "temple_hall",
		"rect": hall, "storey": -2, "elevation": gallery_y})
	plan.rooms.append({"kind": &"shrine", "role": "sanctum",
		"rect": sanctum, "storey": -2, "elevation": gallery_y})
	plan.doors.append({"a": 0, "b": -1, "pos": Vector2(0.0, site.position.y),
		"normal": Vector2(0, -1), "width": gateway.size.x * 0.45,
		"exterior": true, "front": true, "storey": 0, "role": "cut_gateway"})
	for row in [[1, 2, porch.position.y], [2, 3, hall.position.y],
			[3, 4, sanctum.position.y]]:
		plan.doors.append({"a": row[0], "b": row[1],
			"pos": Vector2(0.0, float(row[2])), "normal": Vector2(0, -1),
			"width": 2.0 * scale, "exterior": false, "storey": -2})
	plan.courts.append({"rect": inner, "storey": -2, "id": "quarried_court"})

	var sky_rect := Rect2(Vector2(inner.position.x + gallery_width,
		maxf(nandi.position.y, inner.position.y + gallery_width)),
		Vector2(temple_rect.position.x - inner.position.x - gallery_width - 1.0,
			minf(temple_rect.end.y, inner.end.y - gallery_width) -
			maxf(nandi.position.y, inner.position.y + gallery_width)))
	plan.world_meta = {"site": site, "pit": site, "ground_level": 0.0,
		"pit_floor_y": floor_y, "gallery_y": gallery_y,
		"gallery_width": gallery_width, "gallery": gallery,
		"gateway_rect": gateway, "nandi_rect": nandi, "porch_rect": porch,
		"hall_rect": hall, "sanctum_rect": sanctum,
		"temple_rect": temple_rect, "bridge_rect": bridge,
		"sky_rect": sky_rect, "axis_x": 0.0,
		"axis_marks": [
			{"name": "gateway", "rect": gateway},
			{"name": "nandi", "rect": nandi},
			{"name": "porch", "rect": porch},
			{"name": "hall", "rect": hall},
			{"name": "sanctum", "rect": sanctum},
		]}
	return {"spec": spec, "plan": plan}


static func _ring(outer: Rect2, width: float) -> Array[Rect2]:
	return [
		Rect2(outer.position, Vector2(outer.size.x, width)),
		Rect2(Vector2(outer.position.x, outer.end.y - width),
			Vector2(outer.size.x, width)),
		Rect2(Vector2(outer.position.x, outer.position.y),
			Vector2(width, outer.size.y)),
		Rect2(Vector2(outer.end.x - width, outer.position.y),
			Vector2(width, outer.size.y)),
	]
