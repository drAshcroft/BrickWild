class_name TulouBuilder
extends MassBuilder
## Faceted circular shell for the clan ring. Room and gallery radii come from
## the generated plan, so the QA records and the emitted sectors agree.

const WALL := 0
const TRIM := 1
const ROOF := 2
const FLOOR := 3
const ROUND_SEGMENTS := 96
const SEGMENTS_PER_ROOM := 3
const WALL_GROUND := 1.5
const WALL_TOP := 1.0

var plan: HousePlan
var spec: HouseSpec


func build(p_plan: HousePlan) -> ArrayMesh:
	plan = p_plan
	spec = plan.spec
	begin(4)
	var meta := plan.world_meta
	var levels := int(meta.get("storeys", spec.storeys))
	var r_outer := float(meta.get("outer_radius", spec.width * 0.5 - 1.0))
	var r_top := r_outer - (WALL_GROUND - WALL_TOP)
	var room_inner := float(meta.get("room_inner_radius", r_outer * 0.44))
	var room_outer := float(meta.get("room_outer_radius", r_outer - WALL_GROUND))
	var gallery_inner := float(meta.get("gallery_inner_radius", room_inner - 3.6))
	var gallery_outer := float(meta.get("gallery_outer_radius", room_inner - 0.4))
	var h := spec.height
	var room_count := int(meta.get("room_count_per_storey", 48))
	var angle_step := TAU / float(room_count)
	for level in range(levels):
		var y0 := float(level) * h
		var y1 := y0 + h
		_emit_ring_floor(gallery_inner, gallery_outer, y0 + HouseGeometry.FLOOR_T * 0.5,
			HouseGeometry.FLOOR_T, FLOOR, "gallery_floor_%d" % level, level)
		for room in range(room_count):
			var a0 := (float(room) - 0.5) * angle_step
			var a1 := (float(room) + 0.5) * angle_step
			_emit_sector_floor(room_inner, room_outer, a0, a1,
				y0 + HouseGeometry.FLOOR_T * 0.5, HouseGeometry.FLOOR_T,
				"clan_floor_%d_%d" % [level, room], level)
		# The masonry tapers from a broad plinth to a thinner crown. Two panels
		# at the south axis form the single ground-level gate.
		for segment in range(ROUND_SEGMENTS):
			if level == 0 and segment in [71, 72]:
				continue
			var a2 := TAU * float(segment) / float(ROUND_SEGMENTS)
			var a3 := TAU * float(segment + 1) / float(ROUND_SEGMENTS)
			var b0 := Vector2(cos(a2), sin(a2)) * r_outer
			var b1 := Vector2(cos(a3), sin(a3)) * r_outer
			var t0 := Vector2(cos(a2), sin(a2)) * r_top
			var t1 := Vector2(cos(a3), sin(a3)) * r_top
			var wall_depth := lerpf(WALL_GROUND, WALL_TOP,
				float(level) / float(maxi(levels - 1, 1)))
			_emit_vertical_quad(b0, b1, t1, t0, y0, y1, WALL,
				"outer_wall", level, AABB(Vector3(minf(b0.x, b1.x)-wall_depth*0.5, y0,
					minf(b0.y, b1.y)-wall_depth*0.5), Vector3(absf(b1.x-b0.x)+wall_depth,
					h, absf(b1.y-b0.y)+wall_depth)), wall_depth)
		# Radial partitions make the rooms separate without closing the gallery.
		for room2 in range(room_count):
			var boundary := (float(room2) - 0.5) * angle_step
			var dir := Vector2(cos(boundary), sin(boundary))
			_emit_vertical_quad(dir * room_inner, dir * room_outer,
				dir * room_outer, dir * room_inner, y0, y1, WALL,
				"room_partition", level,
				AABB(Vector3(minf(dir.x * room_inner, dir.x * room_outer)-0.07, y0,
					minf(dir.y * room_inner, dir.y * room_outer)-0.07),
					Vector3(absf(dir.x) * (room_outer-room_inner)+0.14, h,
						absf(dir.y) * (room_outer-room_inner)+0.14)))
		# Inner and outer gallery arcades are low stone walls; inward doors are
		# explicitly retained on the inward-facing room threshold in the plan.
		_emit_ring_walls(gallery_inner, y0, y1, ROUND_SEGMENTS,
			"gallery_inner_wall", level, 72 if level == 0 else -1)
		_emit_gallery_outer_wall(gallery_outer, y0, y1, level, room_count)
		_log_mass("gallery_floor_%d" % level,
			AABB(Vector3(-gallery_outer, y0, -gallery_outer),
				Vector3(gallery_outer * 2.0, HouseGeometry.FLOOR_T,
					gallery_outer * 2.0)), y0)
	# Ancestral hall at the centre and the unroofed air court around it.
	var hall_r := float(meta.get("hall_radius", 3.3)) * 1.5
	var hall_y := h
	var hall_box := AABB(Vector3(-hall_r, 0.0, -hall_r),
		Vector3(hall_r * 2.0, hall_y, hall_r * 2.0))
	tag("ancestral_hall")
	host("ancestral_hall", 0)
	component_box("ancestral_hall_mass", Vector3(hall_r * 2.0, hall_y, hall_r * 2.0),
		Transform3D(Basis.IDENTITY, hall_box.get_center()), WALL)
	_log_mass("ancestral_hall", hall_box, 0.0)
	host_end()
	var hall_floor := PackedVector3Array([Vector3(-hall_r, HouseGeometry.FLOOR_T * 0.5, -hall_r),
		Vector3(hall_r, HouseGeometry.FLOOR_T * 0.5, -hall_r),
		Vector3(hall_r, HouseGeometry.FLOOR_T * 0.5, hall_r),
		Vector3(-hall_r, HouseGeometry.FLOOR_T * 0.5, hall_r)])
	tag("hall_floor")
	host("hall_floor", 0)
	component_slab("hall_floor", hall_floor, HouseGeometry.FLOOR_T, FLOOR, false)
	host_end()
	_emit_ring_floor(hall_r * 1.5, gallery_inner, HouseGeometry.FLOOR_T * 0.5,
		HouseGeometry.FLOOR_T, FLOOR, "ancestral_court_floor", 0)
	# Four circulation towers, repeated at each landing, evenly on cardinal axes.
	var stairs_count := int(meta.get("stair_count", 4))
	var stair_radius := (gallery_inner + room_outer) * 0.5
	for stair in range(stairs_count):
		var angle := TAU * float(stair) / float(stairs_count)
		var pos := Vector2(cos(angle), sin(angle)) * stair_radius
		for landing in range(levels - 1):
			var size := Vector3(2.1, h, 2.1)
			var center := Vector3(pos.x, (float(landing) + 0.5) * h, pos.y)
			tag("stair")
			host("stair_%d" % stair, landing)
			component_box("gallery_stair", size,
				Transform3D(Basis.IDENTITY, center), TRIM)
			var stair_box := AABB(center - size * 0.5, size)
			_log_mass("stair_%d_%d" % [stair, landing], stair_box, stair_box.position.y)
			host_end()
	# Flat ring roof. The inner opening keeps the court column open to the sky.
	_emit_ring_floor(gallery_inner, r_top, float(levels) * h,
			0.22, ROOF, "roof_ring", levels)
	_log_mass("roof_ring", AABB(Vector3(-r_outer, levels * h - 0.11, -r_outer),
		Vector3(r_outer * 2.0, 0.22, r_outer * 2.0)), levels * h)
	total_height = levels * h
	return commit()


func _emit_ring_floor(r0: float, r1: float, y: float, depth: float,
		surface: int, mass_name: String, level: int) -> void:
	var start := 1
	for i in range(ROUND_SEGMENTS):
		var a0 := TAU * float(i) / float(ROUND_SEGMENTS)
		var a1 := TAU * float(i + 1) / float(ROUND_SEGMENTS)
		for sub in range(start):
			var lo := lerpf(r0, r1, float(sub) / float(start))
			var hi := lerpf(r0, r1, float(sub + 1) / float(start))
			var pts := PackedVector3Array([
				Vector3(cos(a0)*lo, y, sin(a0)*lo), Vector3(cos(a0)*hi, y, sin(a0)*hi),
				Vector3(cos(a1)*hi, y, sin(a1)*hi), Vector3(cos(a1)*lo, y, sin(a1)*lo)])
			tag(mass_name)
			host(mass_name, level)
			component_slab("%s_panel" % mass_name, pts, depth, surface, false)
			host_end()
	if r0 <= 0.001:
		var center := PackedVector3Array([Vector3(-r1, y, -r1), Vector3(r1, y, -r1),
			Vector3(r1, y, r1), Vector3(-r1, y, r1)])
		tag(mass_name)
		host(mass_name, level)
		component_slab("%s_center" % mass_name, center, depth, surface, false)
		host_end()


func _emit_sector_floor(r0: float, r1: float, a0: float, a1: float,
		y: float, depth: float, mass_name: String, level: int) -> void:
	for segment in range(SEGMENTS_PER_ROOM):
		var part0 := lerpf(a0, a1, float(segment) / float(SEGMENTS_PER_ROOM))
		var part1 := lerpf(a0, a1, float(segment + 1) / float(SEGMENTS_PER_ROOM))
		var inner0 := Vector2(cos(part0), sin(part0)) * r0
		var outer0 := Vector2(cos(part0), sin(part0)) * r1
		var outer1 := Vector2(cos(part1), sin(part1)) * r1
		var inner1 := Vector2(cos(part1), sin(part1)) * r0
		var pts := PackedVector3Array([Vector3(inner0.x,y,inner0.y),
			Vector3(outer0.x,y,outer0.y), Vector3(outer1.x,y,outer1.y),
			Vector3(inner1.x,y,inner1.y)])
		tag(mass_name)
		host(mass_name, level)
		component_slab("clan_room_floor", pts, depth, FLOOR, false)
		host_end()


func _emit_ring_walls(radius: float, y0: float, y1: float, segments: int,
		name: String, level: int, skip_segment := -1) -> void:
	for i in range(segments):
		if skip_segment >= 0 and absi(i - skip_segment) <= 1:
			continue
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var p0 := Vector2(cos(a0), sin(a0)) * radius
		var p1 := Vector2(cos(a1), sin(a1)) * radius
		_emit_vertical_quad(p0, p1, p1, p0, y0, y1, WALL, name, level,
			AABB(Vector3(minf(p0.x,p1.x)-0.12, y0, minf(p0.y,p1.y)-0.12),
				Vector3(absf(p1.x-p0.x)+0.24, y1-y0, absf(p1.y-p0.y)+0.24)))


func _emit_gallery_outer_wall(radius: float, y0: float, y1: float,
		level: int, room_count: int) -> void:
	# A faceted segment at each clan-room threshold is left open. This is the
	# gallery-to-room door, and it lines up with the single plan door record.
	var segments := ROUND_SEGMENTS * 2
	var panels_per_room := int(segments / room_count)
	for i in range(segments):
		if (i % panels_per_room) in [1, 2]:
			continue
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var p0 := Vector2(cos(a0), sin(a0)) * radius
		var p1 := Vector2(cos(a1), sin(a1)) * radius
		_emit_vertical_quad(p0, p1, p1, p0, y0, y1, WALL, "gallery_outer_wall", level,
			AABB(Vector3(minf(p0.x,p1.x)-0.12, y0, minf(p0.y,p1.y)-0.12),
				Vector3(absf(p1.x-p0.x)+0.24, y1-y0, absf(p1.y-p0.y)+0.24)))


func _emit_vertical_quad(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2,
		y0: float, y1: float, surface: int, name: String, level: int,
		box: AABB, depth := 0.14) -> void:
	var pts := PackedVector3Array([Vector3(p0.x,y0,p0.y), Vector3(p1.x,y0,p1.y),
		Vector3(p2.x,y1,p2.y), Vector3(p3.x,y1,p3.y)])
	tag(name)
	host(name, level)
	component_slab("%s_panel" % name, pts, depth, surface, false)
	host_end()
	_log_mass(name, box, y0)
