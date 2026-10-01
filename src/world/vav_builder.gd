class_name VavBuilder
extends MassBuilder
## Emits descending landings and stairs, retaining walls, pavilions and water.

const STONE := 0
const TRIM := 1
const WATER := 2
const FLOOR_T := 0.34


func build(plan: HousePlan) -> ArrayMesh:
	begin_metric(3)
	var meta: Dictionary = plan.world_meta
	var landings: Array = plan.rooms
	var channel_width := float(meta.get("channel_width", 0.0))
	var total_drop := float(meta.get("total_drop", 0.0))
	var wall_t := 0.72
	for index in range(landings.size()):
		var landing: Dictionary = landings[index]
		var rect: Rect2 = landing["rect"]
		var y := float(landing.get("elevation", 0.0))
		var floor_size := Vector3(rect.size.x, FLOOR_T, rect.size.y)
		var floor_pos := Vector3(rect.get_center().x, y - FLOOR_T * 0.5, rect.get_center().y)
		box(floor_size, floor_pos, STONE)
		_log_mass("landing_%d" % index, AABB(floor_pos - floor_size * 0.5, floor_size), y - FLOOR_T)
		if index < landings.size() - 1:
			_emit_flight(plan, index)
	_emit_entry_apron(meta)

	# The two continuous banks are the cut face of the excavation. Their bases
	# and the bottom of every below-grade mass are measured on the same datum.
	var site: Rect2 = meta["site"]
	var tank: Rect2 = meta["tank"]
	var channel_center := float(meta.get("channel_center_z", 0.0))
	for side in [-1.0, 1.0]:
		var z := channel_center + side * (channel_width * 0.5 + wall_t * 0.5)
		var wall_x := site.position.x
		var wall_width := site.size.x
		if side > 0.0:
			# Open the bank where the stair reaches the tank and shaft.
			wall_x = tank.end.x
			wall_width = site.end.x - wall_x
		if wall_width <= 0.1:
			continue
		var wall_size := Vector3(wall_width, total_drop, wall_t)
		var pos := Vector3(wall_x + wall_width * 0.5, -total_drop * 0.5, z)
		box(wall_size, pos, STONE)
		_log_mass("retaining_wall_%s" % ("left" if side < 0 else "right"),
			AABB(pos - wall_size * 0.5, wall_size), -total_drop)

	_emit_pavilions(meta)
	_emit_tank(meta)
	_emit_shaft(meta)
	_emit_water(meta)
	return commit()


func _emit_entry_apron(meta: Dictionary) -> void:
	var rect: Rect2 = meta["entry_apron"]
	var size := Vector3(rect.size.x, FLOOR_T, rect.size.y)
	var pos := Vector3(rect.get_center().x, -FLOOR_T * 0.5, rect.get_center().y)
	box(size, pos, STONE)
	_log_mass("entry_apron", AABB(pos - size * 0.5, size), -FLOOR_T)


func _emit_flight(plan: HousePlan, index: int) -> void:
	var flight: Dictionary = plan.stairs[index]
	var rect: Rect2 = flight["rect"]
	var steps := int(flight["steps"])
	var lower_y := float(flight["lower_y"])
	var upper_y := float(flight["upper_y"])
	var step_depth := rect.size.x / float(steps)
	var step_height := (lower_y - upper_y) / float(steps)
	for step_index in range(steps):
		var top_y := lower_y - float(step_index + 1) * step_height
		var size := Vector3(step_depth + 0.04, maxf(step_height, 0.2), rect.size.y)
		var pos := Vector3(rect.end.x - (float(step_index) + 0.5) * step_depth,
			top_y - size.y * 0.5, rect.get_center().y)
		box(size, pos, TRIM)
		_log_mass("stair_%d_tread_%d" % [index, step_index],
			AABB(pos - size * 0.5, size), top_y - size.y)


func _emit_pavilions(meta: Dictionary) -> void:
	for pavilion in meta.get("pavilions", []):
		var host_name := String(pavilion["id"])
		var center: Vector2 = pavilion["center"]
		var size: Vector2 = pavilion["size"]
		var y := float(pavilion["y"])
		var col := Vector3(0.42, 2.8, 0.42)
		host(host_name, int(pavilion["storey"]))
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var p := Vector3(center.x + sx * (size.x * 0.5 - 0.35),
					y + col.y * 0.5, center.y + sz * (size.y * 0.5 - 0.35))
				var col_xf := Transform3D(Basis.IDENTITY, p)
				component_box("pavilion_column", col, col_xf, STONE)
				_log_part("box", p, col)
				_log_mass("%s_column" % host_name,
					AABB(p - col * 0.5, col), y)
		var roof := Vector3(size.x, 0.38, size.y)
		var roof_pos := Vector3(center.x, y + col.y + roof.y * 0.5, center.y)
		var roof_xf := Transform3D(Basis.IDENTITY, roof_pos)
		component_box("pavilion_roof", roof, roof_xf, TRIM)
		_log_part("box", roof_pos, roof)
		_log_mass(host_name, AABB(roof_pos - roof * 0.5, roof), y + col.y)
		total_height = maxf(total_height, roof_pos.y + roof.y * 0.5)
		host_end()


func _emit_tank(meta: Dictionary) -> void:
	var rect: Rect2 = meta["tank"]
	var floor_y := float(meta["tank_floor_y"])
	var t := 0.55
	var slab := Vector3(rect.size.x, t, rect.size.y)
	var slab_pos := Vector3(rect.get_center().x, floor_y - t * 0.5, rect.get_center().y)
	box(slab, slab_pos, STONE)
	_log_mass("tank_floor", AABB(slab_pos - slab * 0.5, slab), floor_y - t)
	for side in [-1.0, 1.0]:
		if side < 0.0:
			continue # the north edge opens directly onto the last stair landing
		var size := Vector3(rect.size.x, 1.8, t)
		var pos := Vector3(rect.get_center().x, floor_y + 0.9,
			rect.get_center().y + side * (rect.size.y * 0.5 - t * 0.5))
		box(size, pos, STONE)
		_log_mass("tank_wall", AABB(pos - size * 0.5, size), floor_y)
	for side_x in [-1.0, 1.0]:
		var end_size := Vector3(t, 1.8, rect.size.y)
		var end_pos := Vector3(rect.get_center().x + side_x * (rect.size.x * 0.5 - t * 0.5),
			floor_y + 0.9, rect.get_center().y)
		box(end_size, end_pos, STONE)
		_log_mass("tank_wall", AABB(end_pos - end_size * 0.5, end_size), floor_y)
	var strips: Array = meta.get("tank_walk", [])
	for i in range(strips.size()):
		var r: Rect2 = strips[i]
		if r.size.x <= 0.1 or r.size.y <= 0.1:
			continue
		var edge_size := Vector3(r.size.x, FLOOR_T, r.size.y)
		var edge_pos := Vector3(r.get_center().x, floor_y - FLOOR_T * 0.5, r.get_center().y)
		box(edge_size, edge_pos, STONE)
		_log_mass("tank_edge_%d" % i, AABB(edge_pos - edge_size * 0.5, edge_size),
			floor_y - FLOOR_T)


func _emit_shaft(meta: Dictionary) -> void:
	var rect: Rect2 = meta["shaft"]
	var bottom_y := float(meta["shaft_bottom_y"])
	var height := -bottom_y
	var t := 0.24
	var radius := minf(rect.size.x, rect.size.y) * 0.5
	var segments := 12
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		var chord := 2.0 * radius * sin(PI / float(segments))
		var size := Vector3(chord * 1.08, height, t)
		var radial := Vector2(cos(angle), sin(angle))
		var pos := Vector3(rect.get_center().x + radial.x * (radius - t * 0.5),
			bottom_y + height * 0.5,
			rect.get_center().y + radial.y * (radius - t * 0.5))
		# Tangential boards approximate the round shaft while leaving its core open.
		var yaw := angle + PI * 0.5
		var xf := Transform3D(Basis(Vector3.UP, yaw), pos)
		host("draw_shaft", -1)
		var component := component_box("shaft_wall", size, xf, TRIM)
		_log_part("box", pos, size, yaw)
		var aabb := MassBuilder.component_aabb(component)
		_log_mass("shaft_wall_%02d" % i, aabb, bottom_y)
		host_end()


func _emit_water(meta: Dictionary) -> void:
	var rect: Rect2 = meta["tank"]
	var y := float(meta["water_y"])
	var size := Vector3(rect.size.x - 1.0, 0.16, rect.size.y - 1.0)
	var pos := Vector3(rect.get_center().x, y, rect.get_center().y)
	box(size, pos, WATER)
	_log_mass("water", AABB(pos - size * 0.5, size), pos.y - size.y * 0.5)
