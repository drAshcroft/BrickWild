class_name TulouGenerator
extends RefCounted
## Hakka clan ring plan (WLD-010). Rooms are polygon sectors; the custom
## emitter shares their radii with the galleries and the battered wall.

const FAMILY := &"tulou"
const SUBKIND := &"clan_ring"
const ROOM_COUNT := 48
const STOREYS := 4
const SEGMENTS_PER_ROOM := 3


static func generate(p_seed: int, width: float, length: float,
		total_height: float, requested_storeys := STOREYS) -> Dictionary:
	var side := minf(width, length)
	var levels := clampi(requested_storeys, 3, 5)
	var floor_height := total_height / float(levels)
	var spec := HouseSpec.new(p_seed)
	spec.style = &"townhouse"
	spec.material = &"stone"
	spec.width = maxf(side, 40.0)
	spec.length = maxf(side, 40.0)
	spec.height = floor_height
	spec.storeys = levels
	spec.trade = &"none"
	spec.wall_thickness_override = 1.2
	spec.roof_type = &"gable"
	spec.roof_pitch = 0.0
	spec.dormers = false
	spec.porch = false
	spec.chimney = false
	spec.timber_frame = false
	spec.clutter = 0.0
	spec.variant_name = "Clan Ring"

	var plan := HousePlan.new()
	plan.spec = spec
	plan.world_family = FAMILY
	plan.world_subkind = SUBKIND
	plan.blind_entry = true
	var center := Vector2.ZERO
	var outer_radius := side * 0.5 - 1.0
	var room_inner := side * 0.5 * 0.44
	var room_outer := outer_radius - 1.8
	var gallery_inner := room_inner - 3.6
	var gallery_outer := room_inner
	var hall_radius := side * 0.5 * 0.055
	var court_half := gallery_inner - 0.3
	var room_ids: Array[int] = []
	var gallery_ids: Array[int] = []
	var angle_step := TAU / float(ROOM_COUNT)
	var sector_width := maxf(2.0 * room_inner * sin(angle_step * 0.5), 0.01)

	# One continuous walkable ring room per storey; the builder emits its floor
	# as a full circle and the plan retains a closed polygon outline for QA.
	for level in range(levels):
		var gallery_outline := _annulus(gallery_inner, gallery_outer, 96)
		gallery_ids.append(plan.rooms.size())
		plan.rooms.append({"kind": &"gallery", "role": "gallery",
			"rect": Rect2(Vector2(-gallery_outer, -gallery_outer),
				Vector2.ONE * gallery_outer * 2.0),
			"outline": gallery_outline, "storey": level})
		for i in range(ROOM_COUNT):
			var a0 := (float(i) - 0.5) * angle_step
			var a1 := (float(i) + 0.5) * angle_step
			var outline := _sector(room_inner, room_outer, a0, a1, SEGMENTS_PER_ROOM)
			var bounds := Poly.bounding_rect(outline)
			room_ids.append(plan.rooms.size())
			plan.rooms.append({"kind": &"clan_room", "role": "clan_room",
				"rect": bounds, "outline": outline, "storey": level,
				"sector": i, "width": sector_width})
			var mid := (a0 + a1) * 0.5
			var door_pos := center + Vector2(cos(mid), sin(mid)) * room_inner
			var inward := (center - door_pos).normalized()
			plan.doors.append({"a": room_ids[-1], "b": gallery_ids[level],
				"pos": door_pos, "normal": inward, "width": 1.0,
				"exterior": false, "front": false, "storey": level,
				"role": "inward_clan_door"})

	# The centre hall is a separate, raised room. The surrounding open court is
	# kept as a CourtCheck-visible rectangle and the emitter leaves it unroofed.
	var hall_id := plan.rooms.size()
	var hall_side := hall_radius * 1.5
	var hall_rect := Rect2(Vector2(-hall_side, -hall_side), Vector2.ONE * hall_side * 2.0)
	plan.rooms.append({"kind": &"hall", "role": "ancestral_hall", "rect": hall_rect,
		"outline": Poly.from_rect(hall_rect), "storey": 0})
	var court_rect := Rect2(Vector2(-court_half, -court_half), Vector2.ONE * court_half * 2.0)
	plan.courts.append({"rect": court_rect, "outline": Poly.from_rect(court_rect),
		"storey": 0, "role": "ancestral_court"})
	# The gallery opens once onto the central court on the main axis. Clan-room
	# doors remain exactly one per room and always point inward.
	var court_door_pos := Vector2(0.0, -gallery_inner + 0.15)
	plan.doors.append({"a": gallery_ids[0], "b": -1, "pos": court_door_pos,
		"normal": Vector2(0.0, -1.0), "width": 1.8, "exterior": true,
		"front": false, "storey": 0, "role": "court_axis_door"})
	var gate_pos := Vector2(0.0, -outer_radius)
	plan.doors.append({"a": room_ids[int(ROOM_COUNT * 3 / 4)], "b": -1, "pos": gate_pos,
		"normal": Vector2(0.0, -1.0), "width": 2.6, "exterior": true,
		"front": true, "storey": 0, "role": "main_gate"})

	var stair_count := 4
	var stair_radius := (gallery_inner + room_outer) * 0.5
	var stair_rect_size := Vector2(2.1, 2.1)
	for i2 in range(stair_count):
		var angle := TAU * float(i2) / float(stair_count)
		var pos := center + Vector2(cos(angle), sin(angle)) * stair_radius
		for level2 in range(levels - 1):
			var r := Rect2(pos - stair_rect_size * 0.5, stair_rect_size)
			plan.stairs.append({"a": gallery_ids[level2], "b": gallery_ids[level2 + 1],
				"storey": level2, "to_storey": level2 + 1, "pos": pos,
				"lower_pos": pos, "upper_pos": pos, "rect": r,
				"lower_rect": r, "upper_rect": r, "width": 1.0, "run": 2.0,
				"role": "gallery_stair", "index": i2})

	plan.world_meta = {
		"family": FAMILY, "total_height": floor_height * float(levels),
		"storeys": levels, "room_count_per_storey": ROOM_COUNT,
		"room_width": sector_width, "room_inner_radius": room_inner,
		"room_outer_radius": room_outer, "gallery_inner_radius": gallery_inner,
		"gallery_outer_radius": gallery_outer, "outer_radius": outer_radius,
		"wall_ground_thickness": 1.5, "wall_top_thickness": 1.0,
		"hall_room": hall_id, "hall_radius": hall_radius,
		"court_rect": court_rect, "gate_axis": Vector2(0.0, -1.0),
		"gate_count": 1, "stair_count": stair_count,
		"wall_segments": 96, "ring_closed": true,
		"stair_angles": [0.0, PI * 0.5, PI, PI * 1.5],
		"sector_widths": _widths(room_inner, ROOM_COUNT),
		"room_ids": room_ids, "gallery_ids": gallery_ids,
		"gallery_open": true, "blind_outer_wall": true,
	}
	return {"spec": spec, "plan": plan}


static func _sector(r0: float, r1: float, a0: float, a1: float,
		segments: int) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for i in range(segments + 1):
		var a := lerpf(a0, a1, float(i) / float(segments))
		poly.append(Vector2(cos(a), sin(a)) * r1)
	for j in range(segments, -1, -1):
		var a2 := lerpf(a0, a1, float(j) / float(segments))
		poly.append(Vector2(cos(a2), sin(a2)) * r0)
	return poly


static func _annulus(r0: float, r1: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		points.append(Vector2(cos(a), sin(a)) * r1)
	for j in range(segments - 1, -1, -1):
		var a2 := TAU * float(j) / float(segments)
		points.append(Vector2(cos(a2), sin(a2)) * r0)
	return points


static func _widths(radius: float, count: int) -> Array[float]:
	var out: Array[float] = []
	var width := 2.0 * radius * sin(PI / float(count))
	for _i in range(count):
		out.append(width)
	return out
