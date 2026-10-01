class_name VavGenerator
extends RefCounted
## WLD-016: a descending baoli stepwell with pavilions, a draw shaft and a tank.

const FAMILY := &"stepwell"
const SUBKIND := &"queens_well"
const LEVELS := 7
const TAPER := 0.98


static func generate(seed: int, width: float, length: float, depth: float) -> Dictionary:
	var spec := HouseSpec.new(seed)
	spec.style = &"townhouse"
	spec.material = &"stone"
	spec.width = clampf(width, 45.5, 123.5)
	spec.length = clampf(length, 14.0, 38.0)
	spec.height = 4.0
	spec.storeys = 1
	spec.trade = &"none"
	spec.wall_thickness_override = 0.55
	spec.roof_type = &"flat"
	spec.porch = false
	spec.chimney = false
	spec.timber_frame = false
	spec.stone_ground_floor = true
	spec.wall_color = Color("b9aa8d")
	spec.trim_color = Color("725f43")
	spec.roof_color = Color("3d8caf") # VavBuilder's third surface is the water.
	spec.floor_color = Color("907b5c")
	spec.variant_name = "The Queen's Well"

	var plan := HousePlan.new()
	plan.spec = spec
	plan.world_family = FAMILY
	plan.world_subkind = SUBKIND
	var site := Rect2(Vector2(-spec.width * 0.5, -spec.length * 0.5),
		Vector2(spec.width, spec.length))
	var scale := spec.width / 65.0
	var total_drop := clampf(depth * (23.0 / 28.0) * minf(scale, 1.0), 10.0, 23.0)
	var level_drop := total_drop / float(LEVELS)
	var landing_count := LEVELS + 1
	var landing_width := 3.5 * scale
	var stair_width := 1.8 * scale
	var channel_width := spec.length * 0.11
	var tank_width := minf(9.5 * scale, spec.width * 0.22)
	var tank_depth := minf(9.4 * scale, spec.length * 0.47)
	var shaft_diameter := minf(10.0 * scale,
		minf(spec.length * 0.40, spec.length - 0.3 - channel_width - tank_depth))
	var corridor_center := site.position.y + 0.3 + channel_width * 0.5
	var landings: Array[Dictionary] = []
	var descent: Array[Dictionary] = []
	var stair_rows: Array[Dictionary] = []
	var start_x := site.end.x - landing_width * 0.5
	var end_width := landing_width * pow(TAPER, LEVELS)
	var end_x := site.position.x + 1.2 + tank_width - end_width * 0.5
	var centre_step := (start_x - end_x) / float(LEVELS)
	for index in range(landing_count):
		var storey := -index
		var this_width := landing_width * pow(TAPER, index)
		var center_x := start_x - float(index) * centre_step
		var rect := Rect2(Vector2(center_x - this_width * 0.5,
			corridor_center - channel_width * 0.5), Vector2(this_width, channel_width))
		var level_y := -float(index) * level_drop
		var room_id := plan.rooms.size()
		plan.rooms.append({"kind": &"hall", "role": "stepwell_level_%d" % index,
			"rect": rect, "storey": storey, "elevation": level_y})
		landings.append({"id": room_id, "index": index, "storey": storey,
			"rect": rect, "y": level_y})
		descent.append({"from_storey": storey, "elevation": level_y,
			"landing": room_id})
		if index == LEVELS:
			continue
		var next_width := landing_width * pow(TAPER, index + 1)
		var next_center := start_x - float(index + 1) * centre_step
		var flight_west := next_center + next_width * 0.5
		var flight_east := center_x - this_width * 0.5
		var flight_run := flight_east - flight_west
		var flight_rect := Rect2(Vector2(flight_west,
			corridor_center - stair_width * 0.5), Vector2(flight_run, stair_width))
		var next_level_y := -float(index + 1) * level_drop
		var steps := maxi(6, ceili(level_drop / 0.28))
		var stair := {"a": room_id, "b": room_id + 1, "storey": storey,
			"to_storey": storey - 1, "rect": flight_rect, "lower_rect": flight_rect,
			"upper_rect": flight_rect, "lower_y": level_y, "upper_y": next_level_y,
			"rise": level_drop, "run": flight_run, "width": stair_width, "steps": steps}
		plan.stairs.append(stair)
		stair_rows.append(stair)

	var entrance := Vector2(landings[0]["rect"].get_center().x, site.position.y)
	var entry_rect: Rect2 = landings[0]["rect"]
	var entry_apron := Rect2(Vector2(entry_rect.position.x, site.position.y),
		Vector2(entry_rect.size.x, entry_rect.position.y - site.position.y))
	plan.doors.append({"a": 0, "b": -1, "pos": entrance, "normal": Vector2(0, -1),
		"width": minf(3.0, channel_width * 0.35), "exterior": true, "front": true,
		"storey": 0, "role": "stepwell_entry"})
	var tank_rect := Rect2(Vector2(site.position.x + 1.2,
		corridor_center + channel_width * 0.5), Vector2(tank_width, tank_depth))
	var shaft_rect := Rect2(Vector2(site.position.x + 1.2 + (tank_width - shaft_diameter) * 0.5,
		tank_rect.end.y),
		Vector2(shaft_diameter, shaft_diameter))
	var pavilions: Array[Dictionary] = []
	for pavilion_index in range(landing_count):
		var level_index := pavilion_index
		var landing: Dictionary = landings[level_index]
		var pavilion_width := (landing["rect"] as Rect2).size.x * 0.94
		pavilions.append({"id": "pavilion_%d" % pavilion_index,
			"storey": int(landing["storey"]), "y": float(landing["y"]),
			"center": Vector2(landing["rect"].get_center().x,
				corridor_center),
			"size": Vector2(pavilion_width, minf(channel_width * 0.86, pavilion_width))})
	var tank_floor_y := -total_drop
	var shaft_depth := maxf(total_drop + 2.0, minf(30.0 * scale, 30.0))
	var tank_access := tank_rect.grow(1.1)
	var tank_walk: Array[Rect2] = [
		Rect2(Vector2(tank_access.position.x, tank_access.position.y),
			Vector2(tank_access.size.x, tank_rect.position.y - tank_access.position.y)),
		Rect2(Vector2(tank_access.position.x, tank_rect.end.y),
			Vector2(tank_access.size.x, tank_access.end.y - tank_rect.end.y)),
		Rect2(Vector2(tank_access.position.x, tank_rect.position.y),
			Vector2(tank_rect.position.x - tank_access.position.x, tank_rect.size.y)),
		Rect2(Vector2(tank_rect.end.x, tank_rect.position.y),
			Vector2(tank_access.end.x - tank_rect.end.x, tank_rect.size.y)),
	]
	var corridor := Rect2(Vector2(tank_rect.end.x, corridor_center - channel_width * 0.5),
		Vector2(site.end.x - tank_rect.end.x, channel_width))

	plan.world_meta = {"site": site, "total_drop": total_drop,
		"level_drop": level_drop, "level_count": LEVELS, "landings": landings,
		"descent": descent, "stair_flights": stair_rows, "pavilions": pavilions,
		"entry_apron": entry_apron,
		"tank": tank_rect, "tank_access": tank_access, "tank_walk": tank_walk,
		"tank_storey": -LEVELS,
		"tank_floor_y": tank_floor_y, "water_y": tank_floor_y + 0.42,
		"shaft": shaft_rect, "shaft_bottom_y": -shaft_depth, "entry": entrance,
		"corridor": corridor, "channel_width": channel_width,
		"channel_center_z": corridor_center,
		"stair_width": stair_width, "retaining_wall_height": total_drop}
	return {"spec": spec, "plan": plan}
