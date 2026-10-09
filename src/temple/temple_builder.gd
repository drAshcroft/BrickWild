class_name TempleBuilder
extends MassBuilder
## TempleSpec -> ArrayMesh, plus a list of props to hang on it.
##
## The architecture is emitted as geometry, the way the churches and castles
## are: floor, walls, columns, dais, altar, idol, pit, roof. The dressing is a
## list of prop placements the assembler instantiates, the way a house's
## furniture is -- braziers down the processional way, chains in the cells,
## a knife and a chalice on the altar.
##
## Both go into the logs the checks read. mass_log is what the structural rules
## measure; prop_log is what the rite check reads to ask whether the place is
## lit and whether the cells hold anything.
##
## Surfaces: 0 = stone, 1 = trim (gold, bone, whatever the cult gilds), 2 =
## roof, 3 = the dark (pit throats, gate voids, eye sockets).

const SURF_STONE := 0
const SURF_TRIM := 1
const SURF_ROOF := 2
const SURF_DARK := 3
const BRAZIER_SCALE := 0.75

var spec: TempleSpec
var _columns: Array[Dictionary] = []


func build(p_spec: TempleSpec) -> ArrayMesh:
	spec = p_spec
	_columns = TempleGeometry.column_records(spec)
	begin(4)
	total_height = spec.height

	_build_floor()
	_build_walls()
	_build_columns()
	_build_column_entablature()
	_build_dais()
	_build_altar()
	_build_idol()
	_build_pit()
	_build_cells()
	_build_roof()
	if spec.form == &"basilica":
		_build_order()
	_build_outworks()
	_dress()
	return commit()


# ------------------------------------------------------------------ floor

func _build_floor() -> void:
	tag("floor")
	var t: float = TempleGeometry.FLOOR_T
	var plates: Array[Rect2] = TempleGeometry.floor_rects(spec)
	var i := 0
	for r in plates:
		box(Vector3(r.size.x, t, r.size.y),
			Vector3(r.get_center().x, -t / 2.0 + 0.001, r.get_center().y), SURF_STONE)
		_log_mass("floor" if i == 0 else "floor_%d" % i,
			AABB(Vector3(r.position.x, -t, r.position.y),
				Vector3(r.size.x, t, r.size.y)))
		i += 1
	if spec.form == &"rotunda":
		var wing_index := 0
		for polygon in TempleGeometry.rotunda_floor_wing_polygons(spec):
			var points := PackedVector3Array()
			var min_x: float = INF
			var min_z: float = INF
			var max_x: float = -INF
			var max_z: float = -INF
			for point in polygon:
				points.append(Vector3(point.x, -t / 2.0 + 0.001, point.y))
				min_x = minf(min_x, point.x)
				min_z = minf(min_z, point.y)
				max_x = maxf(max_x, point.x)
				max_z = maxf(max_z, point.y)
			host("rotunda_floor_perimeter_%03d" % wing_index)
			component_slab("rotunda_floor_perimeter", points, t, SURF_STONE)
			host_end()
			_log_mass("floor_rotunda_perimeter_%03d" % wing_index,
				AABB(Vector3(min_x, -t + 0.001, min_z),
					Vector3(max_x - min_x, t, max_z - min_z)))
			wing_index += 1


# ------------------------------------------------------------------ walls

## The outer walls, with the gate cut through the front one on the axis. A
## ziggurat has no walls of its own -- its terraces are its walls -- so it gets
## the doorway alone, at the foot of the great stair.
func _build_walls() -> void:
	tag("wall")
	var r: Rect2 = TempleGeometry.site_rect(spec)
	var t: float = spec.wall_t
	var h: float = spec.height
	if spec.form == &"ziggurat":
		_gate_void(r.position.y + TempleGeometry.terrace_inset(spec) / 2.0)
		return
	if spec.form == &"rotunda":
		_build_rotunda_drum_walls(t, h)
		_gate_void(-TempleGeometry.rotunda_outer_radius(spec) + t * 0.5)
		return
	var runs := [
		{"name": "wall_back", "rect": Rect2(Vector2(r.position.x, r.end.y - t),
			Vector2(r.size.x, t))},
		{"name": "wall_left", "rect": Rect2(Vector2(r.position.x, r.position.y + t),
			Vector2(t, r.size.y - t * 2.0))},
		{"name": "wall_right", "rect": Rect2(Vector2(r.end.x - t, r.position.y + t),
			Vector2(t, r.size.y - t * 2.0))},
	]
	# the front wall, in two pieces either side of the gate
	var gate: float = TempleGeometry.GATE_W
	for side in [-1.0, 1.0]:
		var x0: float = r.position.x if side < 0.0 else gate / 2.0
		var w: float = (r.size.x - gate) / 2.0
		runs.append({"name": "wall_front_%s" % ("left" if side < 0.0 else "right"),
			"rect": Rect2(Vector2(x0, r.position.y), Vector2(w, t))})
	for run in runs:
		var rect: Rect2 = run["rect"]
		if rect.size.x <= 0.01 or rect.size.y <= 0.01:
			continue
		box(Vector3(rect.size.x, h, rect.size.y),
			Vector3(rect.get_center().x, h / 2.0, rect.get_center().y), SURF_STONE)
		_log_mass(String(run["name"]), AABB(Vector3(rect.position.x, 0.0, rect.position.y),
			Vector3(rect.size.x, h, rect.size.y)))
	# the lintel over the gate, and the dark of the opening
	var gh: float = minf(TempleGeometry.GATE_H, h - 0.6)
	box(Vector3(gate + t, h - gh, t), Vector3(0.0, gh + (h - gh) / 2.0,
		r.position.y + t / 2.0), SURF_STONE)
	_gate_void(r.position.y + t / 2.0)
	if spec.form == &"pylon":
		_build_pylon_sanctum_screen()
	total_height = maxf(total_height, h)


## A real inner portal and return walls turn the far end into a restricted
## shrine. The axis remains human-sized and clear.
func _build_pylon_sanctum_screen() -> void:
	var shrine: Rect2 = TempleGeometry.sanctum_rect(spec)
	var wall_rects: Array[Rect2] = TempleGeometry.pylon_sanctum_wall_rects(spec)
	var h: float = spec.height
	var doorway: float = TempleGeometry.pylon_sanctum_doorway_width(spec)
	var portal_h: float = TempleGeometry.pylon_sanctum_portal_height(spec)
	var front_z: float = shrine.position.y
	var lintel_h: float = clampf(spec.wall_t * 0.55, 0.45, 0.8)
	var bearing: float = clampf(spec.wall_t * 0.25, 0.18, 0.42)
	var lintel_left: float = -doorway * 0.5 - bearing
	var lintel_right: float = doorway * 0.5 + bearing
	host("pylon_inner_shrine")
	# The low piers define the actual clear aperture and carry the short lintel.
	for index in range(2):
		var pier: Rect2 = wall_rects[index]
		_pylon_screen_box("pylon_shrine_portal_pier", pier,
			Vector3(pier.get_center().x, portal_h * 0.5, pier.get_center().y), portal_h)
	# Upper side panels sit directly on the lower piers and meet the lintel at
	# its outer bearing edges. The transom closes the opening above the lintel.
	var upper_h: float = h - portal_h
	var left_upper := Rect2(shrine.position,
		Vector2(lintel_left - shrine.position.x, spec.wall_t))
	var right_upper := Rect2(Vector2(lintel_right, front_z),
		Vector2(shrine.end.x - lintel_right, spec.wall_t))
	var upper_rects: Array[Rect2] = [left_upper, right_upper]
	for upper_rect in upper_rects:
		_pylon_screen_box("pylon_shrine_portal_upper_pier", upper_rect,
			Vector3(upper_rect.get_center().x, portal_h + upper_h * 0.5,
				upper_rect.get_center().y), upper_h)
	var lintel := Rect2(Vector2(lintel_left, front_z),
		Vector2(lintel_right - lintel_left, spec.wall_t))
	_pylon_screen_box("pylon_shrine_portal_lintel", lintel,
		Vector3(0.0, portal_h + lintel_h * 0.5, front_z + spec.wall_t * 0.5), lintel_h)
	var spandrel_h: float = h - portal_h - lintel_h
	var spandrel := Rect2(Vector2(lintel_left, front_z),
		Vector2(lintel_right - lintel_left, spec.wall_t))
	_pylon_screen_box("pylon_shrine_portal_spandrel", spandrel,
		Vector3(0.0, portal_h + lintel_h + spandrel_h * 0.5,
			front_z + spec.wall_t * 0.5), spandrel_h)
	for index in range(2, 4):
		var side_wall: Rect2 = wall_rects[index]
		_pylon_screen_box("pylon_shrine_return_wall", side_wall,
			Vector3(side_wall.get_center().x, h * 0.5, side_wall.get_center().y), h)
	_gate_void(front_z + spec.wall_t * 0.5)
	host_end()

func _pylon_screen_box(role: String, footprint: Rect2, center: Vector3, height: float) -> void:
	var size := Vector3(footprint.size.x, height, footprint.size.y)
	component_box(role, size, Transform3D(Basis(), center), SURF_STONE)
	_log_mass(role, AABB(center - size * 0.5, size))


## A ring of load-bearing tangent stone panels forms a circular drum. Panels
## stop on both sides of the actual -Z gate; the portal remains the same width
## and height as TempleGeometry's shared ritual entry.
func _build_rotunda_drum_walls(thickness: float, height: float) -> void:
	var outer_radius: float = TempleGeometry.rotunda_outer_radius(spec)
	var mid_radius: float = outer_radius - thickness * 0.5
	var segments: int = TempleGeometry.rotunda_wall_panel_count(spec)
	var step: float = TAU / float(segments)
	var portal_half: float = TempleGeometry.rotunda_gate_panel_half_angle(spec)
	var panel_width: float = mid_radius * 2.0 * tan(step * 0.5) + 0.025
	tag("wall")
	for i in range(segments):
		var angle: float = -PI + (float(i) + 0.5) * step
		var relative: float = wrapf(angle + PI * 0.5 + PI, 0.0, TAU) - PI
		if absf(relative) <= portal_half:
			continue
		var yaw: float = PI * 0.5 - angle
		var center := Vector3(cos(angle) * mid_radius, height * 0.5,
			sin(angle) * mid_radius)
		var size := Vector3(panel_width, height, thickness)
		var xform := Transform3D(Basis(Vector3.UP, yaw), center)
		host("rotunda_drum_panel_%02d" % i)
		component_box("rotunda_drum_panel", size, xform, SURF_STONE)
		host_end()
		_log_part("box", center, size, yaw)
		_log_mass("wall_rotunda_%02d" % i, _rotated_box_bounds(size, xform))
	# The panel omission clears the true portal width plus the angular room a
	# tangent panel needs to turn. Return that excess to solid wall on both sides
	# so the clear opening remains GATE_W, then carry its head to the drum crown.
	var gate_height: float = minf(TempleGeometry.GATE_H, height - 0.6)
	var jamb: float = thickness * 0.35
	var return_start: float = TempleGeometry.GATE_W * 0.5
	# Stop each axis-aligned jamb at the actual gate-facing face of the nearest
	# tangent drum panel. The old outer-circle angular estimate crossed that
	# panel by 0.4â€“1.4 m on canonical sizes, despite the opening being clear.
	var adjacent_angle: float = minf(portal_half + step * 0.5, PI * 0.49)
	var adjacent_panel_width: float = mid_radius * 2.0 * tan(step * 0.5) + 0.025
	var return_end: float = mid_radius * sin(adjacent_angle) \
		- adjacent_panel_width * 0.5 * cos(adjacent_angle) \
		- thickness * 0.5 * sin(adjacent_angle) - 0.01
	var return_width: float = maxf(return_end - return_start, 0.0)
	var gate_z: float = -outer_radius + thickness * 0.5
	if return_width > 0.02:
		for side in [-1.0, 1.0]:
			var return_center_x: float = side * (return_start + return_end) * 0.5
			# The gate piers stop at the clear opening head. Their actual top faces
			# carry the lintel; returns extending above the portal head would overlap
			# it without a measured horizontal bearing surface.
			var return_size := Vector3(return_width, gate_height, thickness * 1.05)
			var return_pos := Vector3(return_center_x, gate_height * 0.5, gate_z)
			host("rotunda_gate_return_%s" % ("left" if side < 0.0 else "right"))
			var return_row: Dictionary = component_box("rotunda_gate_return",
				return_size, Transform3D(Basis.IDENTITY, return_pos), SURF_STONE)
			host_end()
			_log_part("box", return_pos, return_size)
			part_log.back()["component_id"] = return_row["id"]
			_log_mass("wall_rotunda_gate_return_%s" % ("left" if side < 0.0 else "right"),
				AABB(return_pos - return_size * 0.5, return_size))
	var head_height: float = height - gate_height
	var head_size := Vector3(TempleGeometry.GATE_W + jamb * 2.0,
		head_height, thickness * 1.05)
	var head_pos := Vector3(0.0, gate_height + head_height * 0.5, gate_z)
	host("rotunda_gate_head")
	var head_row: Dictionary = component_box("rotunda_gate_head", head_size,
		Transform3D(Basis.IDENTITY, head_pos), SURF_STONE)
	host_end()
	_log_part("box", head_pos, head_size)
	part_log.back()["component_id"] = head_row["id"]
	_log_mass("wall_rotunda_gate_head", AABB(head_pos - head_size * 0.5, head_size))


func _rotated_box_bounds(size: Vector3, xform: Transform3D) -> AABB:
	var bounds := AABB()
	var first := true
	for x_sign in [-1.0, 1.0]:
		for y_sign in [-1.0, 1.0]:
			for z_sign in [-1.0, 1.0]:
				var point := xform * Vector3(x_sign * size.x * 0.5,
					y_sign * size.y * 0.5, z_sign * size.z * 0.5)
				if first:
					bounds = AABB(point, Vector3.ZERO)
					first = false
				else:
					bounds = bounds.expand(point)
	return bounds


## The gate: a jamb either side and a threshold under it, and nothing in
## between.
##
## It was a black slab at first, to read as a doorway from outside. That put an
## opaque panel across the one view the whole building is arranged to give you
## -- the rite check would still have said the god was visible, because the
## slab is not a structural mass, and the check would have been describing a
## temple nobody could see into.
func _gate_void(z: float) -> void:
	var gh: float = minf(TempleGeometry.GATE_H, spec.height - 0.6)
	var jamb: float = spec.wall_t * 0.35
	for side in [-1.0, 1.0]:
		box(Vector3(jamb, gh, spec.wall_t * 1.05),
			Vector3(side * (TempleGeometry.GATE_W / 2.0 + jamb / 2.0), gh / 2.0, z),
			SURF_TRIM)
	box(Vector3(TempleGeometry.GATE_W + jamb * 2.0, 0.12, spec.wall_t * 1.05),
		Vector3(0.0, 0.06, z), SURF_TRIM)
	_log_part("window", Vector3(0.0, gh / 2.0, z),
		Vector3(TempleGeometry.GATE_W, gh, 0.0), PI, Vector3(0, 0, -1))


# ---------------------------------------------------------------- columns

func _build_columns() -> void:
	if _columns.is_empty():
		return
	tag("column")
	var i := 0
	for column in _columns:
		var c: Vector3 = column["pos"]
		var r: float = float(column["radius"])
		var h: float = float(column["height"])
		# a shaft that tapers, on a plinth, under a capital: three boxes and a
		# revolve, which is all a column has ever been
		box(Vector3(r * 2.4, 0.22, r * 2.4), Vector3(c.x, 0.11, c.z), SURF_STONE)
		_kit.drum(Vector3(c.x, 0.22, c.z), r, r * 0.86, h - 0.22, SURF_STONE, 12)
		_kit.drum(Vector3(c.x, h, c.z), r * 1.25, r * 1.1,
			TempleGeometry.COLUMN_CAP * r, SURF_TRIM, 12)
		_log_mass("column_%d" % i, AABB(Vector3(c.x - r * 1.2, 0.0, c.z - r * 1.2),
			Vector3(r * 2.4, h + TempleGeometry.COLUMN_CAP * r, r * 2.4)))
		i += 1


## Capitals should carry a visible beam course. Use the final authored column
## records, not a second spacing calculation; the rotunda receives a polygonal
## ring and rectilinear halls receive cross and longitudinal spans.
func _build_column_entablature() -> void:
	if _columns.is_empty():
		return
	tag("structure")
	host("column_entablature")
	var beam_h: float = clampf(spec.column_r * 0.34, 0.18, 0.38)
	if spec.form == &"pylon":
		# A modest flat-roof bearing course overlaps the roof soffit datum.
		beam_h = maxf(beam_h, 0.24)
	var beam_w: float = clampf(spec.column_r * 0.46, 0.24, 0.52)
	if spec.form == &"basilica":
		# The nave wall is borne by this actual inner colonnade. Give its
		# continuous architrave enough width to carry the masonry above.
		beam_w = maxf(beam_w, spec.column_r * 1.8)
	if spec.form == &"rotunda":
		for i in range(_columns.size()):
			var column_a: Dictionary = _columns[i]
			var column_b: Dictionary = _columns[(i + 1) % _columns.size()]
			var a: Vector3 = column_a["pos"]
			var b: Vector3 = column_b["pos"]
			var capital_top_a: float = TempleGeometry.column_cap_top(column_a)
			var capital_top_b: float = TempleGeometry.column_cap_top(column_b)
			if absf(capital_top_a - capital_top_b) > 0.01:
				continue
			var delta := Vector3(b.x - a.x, 0.0, b.z - a.z)
			# Filtering the portal-facing columns opens the real procession lane.
			# Do not bridge that deliberate gap with one long trim member.
			var normal_bay: float = 2.0 * TempleGeometry.ring_radius(spec) \
				* sin(PI / float(maxi(TempleGeometry.ring_columns(spec), 1)))
			if delta.length() > normal_bay * 1.25:
				continue
			var y: float = capital_top_a + beam_h * 0.5
			var length: float = delta.length() + beam_w * 0.45
			var yaw: float = atan2(-delta.z, delta.x)
			var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3((a.x + b.x) * 0.5,
				y, (a.z + b.z) * 0.5))
			component_box("rotunda_ring_architrave", Vector3(length, beam_h, beam_w),
				xf, SURF_TRIM)
		host_end()
		return
	for i in range(_columns.size()):
		var column_a: Dictionary = _columns[i]
		var a: Vector3 = column_a["pos"]
		var ring_a: int = int(_columns[i]["ring"])
		for j in range(i + 1, _columns.size()):
			var column_b: Dictionary = _columns[j]
			var b: Vector3 = column_b["pos"]
			if int(_columns[j]["ring"]) != ring_a:
				continue
			if absf(a.z - b.z) < 0.01 and absf(a.x - b.x) > 0.01:
				var left_x: float = minf(a.x, b.x)
				var right_x: float = maxf(a.x, b.x)
				var nearest_cross: bool = true
				for k in range(_columns.size()):
					if k == i or k == j or int(_columns[k]["ring"]) != ring_a:
						continue
					var middle: Vector3 = _columns[k]["pos"]
					if absf(middle.z - a.z) < 0.01 and middle.x > left_x and middle.x < right_x:
						nearest_cross = false
						break
				if not nearest_cross:
					continue
				var cross_top_a: float = TempleGeometry.column_cap_top(column_a)
				var cross_top_b: float = TempleGeometry.column_cap_top(column_b)
				if absf(cross_top_a - cross_top_b) > 0.01:
					continue
				var cross_y: float = cross_top_a + beam_h * 0.5
				var cross_xf := Transform3D(Basis(), Vector3((left_x + right_x) * 0.5, cross_y, a.z))
				component_box("column_cross_architrave",
					Vector3(right_x - left_x + beam_w * 0.45, beam_h, beam_w),
					cross_xf, SURF_TRIM)
			elif absf(a.x - b.x) < 0.01 and absf(a.z - b.z) > 0.01:
				var near_z: float = minf(a.z, b.z)
				var far_z: float = maxf(a.z, b.z)
				var nearest: bool = true
				for k in range(_columns.size()):
					if k == i or k == j or int(_columns[k]["ring"]) != ring_a:
						continue
					var c: Vector3 = _columns[k]["pos"]
					if absf(c.x - a.x) < 0.01 and c.z > near_z and c.z < far_z:
						nearest = false
						break
				if nearest:
					var along_top_a: float = TempleGeometry.column_cap_top(column_a)
					var along_top_b: float = TempleGeometry.column_cap_top(column_b)
					if absf(along_top_a - along_top_b) > 0.01:
						continue
					var along_y: float = along_top_a + beam_h * 0.5
					var along_xf := Transform3D(Basis(),
						Vector3(a.x, along_y, (near_z + far_z) * 0.5))
					component_box("column_longitudinal_architrave",
						Vector3(beam_w, beam_h, far_z - near_z + beam_w * 0.45),
						along_xf, SURF_TRIM)
	host_end()


# ------------------------------------------------------------------- dais

func _build_dais() -> void:
	tag("dais")
	var d: Rect2 = TempleGeometry.dais_rect(spec)
	var steps: int = maxi(spec.dais_steps, 1)
	var rise: float = TempleGeometry.DAIS_RISE
	var tread: float = TempleGeometry.DAIS_TREAD
	for i in range(steps):
		# each step is the one above it, grown by a tread on the three sides
		# the congregation can climb from
		var grow: float = float(steps - 1 - i) * tread
		var r: Rect2 = Rect2(d.position - Vector2(grow, grow),
			d.size + Vector2(grow * 2.0, grow))
		var step_size := Vector3(r.size.x, rise * float(i + 1), r.size.y)
		var step_center := Vector3(r.get_center().x,
			rise * float(i + 1) / 2.0, r.get_center().y)
		if spec.form == &"rotunda":
			host("rotunda_dais_step_%02d" % i)
			component_box("rotunda_dais_step", step_size,
				Transform3D(Basis.IDENTITY, step_center), SURF_STONE)
			host_end()
		else:
			box(step_size, step_center, SURF_STONE)
	var foot: Rect2 = TempleGeometry.dais_footprint(spec)
	_log_mass("dais", AABB(Vector3(foot.position.x, 0.0, foot.position.y),
		Vector3(foot.size.x, spec.dais_height, foot.size.y)))


# ------------------------------------------------------------------ altar

func _build_altar() -> void:
	tag("altar")
	var c: Vector3 = TempleGeometry.altar_center(spec)
	var w: float = spec.altar_w
	var l: float = spec.altar_l
	var h: float = spec.altar_h
	# a block, a slab on top of it, and the channel cut round the slab that
	# tells you what the slab is for
	box(Vector3(w * 0.82, h - 0.12, l * 0.82), Vector3(c.x, c.y + (h - 0.12) / 2.0, c.z),
		SURF_STONE)
	box(Vector3(w, 0.12, l), Vector3(c.x, c.y + h - 0.06, c.z), SURF_TRIM)
	for side in [-1.0, 1.0]:
		box(Vector3(w * 1.02, 0.05, 0.06),
			Vector3(c.x, c.y + h - 0.02, c.z + side * (l / 2.0 - 0.05)), SURF_DARK)
	_log_mass("altar", AABB(Vector3(c.x - w / 2.0, 0.0, c.z - l / 2.0),
		Vector3(w, c.y + h, l)))


# ------------------------------------------------------------------- idol

## The god. Five shapes, one silhouette rule: it stands on the axis behind the
## altar and it is the tallest thing in the room.
func _build_idol() -> void:
	tag("idol")
	var c: Vector3 = TempleGeometry.idol_center(spec)
	var w: float = spec.idol_width
	var h: float = spec.idol_height
	match spec.idol_kind:
		&"monolith":
			# a leaning slab, unworked, older than the temple round it
			_kit.oriented_box(Vector3(w, h, w * 0.32),
				Transform3D(Basis(Vector3(0, 0, 1), 0.05), Vector3(c.x, c.y + h / 2.0, c.z)),
				SURF_STONE)
			box(Vector3(w * 1.3, 0.3, w * 0.7), Vector3(c.x, c.y + 0.15, c.z), SURF_TRIM)
		&"figure":
			# legs, body, arms, and a head too small for them
			var leg: float = h * 0.32
			for side in [-1.0, 1.0]:
				box(Vector3(w * 0.22, leg, w * 0.24),
					Vector3(c.x + side * w * 0.22, c.y + leg / 2.0, c.z), SURF_STONE)
			box(Vector3(w * 0.78, h * 0.42, w * 0.4),
				Vector3(c.x, c.y + leg + h * 0.21, c.z), SURF_STONE)
			for side2 in [-1.0, 1.0]:
				_kit.oriented_box(Vector3(w * 0.16, h * 0.5, w * 0.16),
					Transform3D(Basis(Vector3(0, 0, 1), side2 * 0.55),
						Vector3(c.x + side2 * w * 0.5, c.y + leg + h * 0.28, c.z)),
					SURF_STONE)
			box(Vector3(w * 0.3, h * 0.18, w * 0.3),
				Vector3(c.x, c.y + leg + h * 0.42 + h * 0.09, c.z), SURF_TRIM)
			_kit.stepped_taper(Vector3(c.x, c.y + leg + h * 0.42 + h * 0.18, c.z),
				w * 0.34, h * 0.14, SURF_TRIM, 3, 0.1)
		&"coil":
			# a serpent wound up a tapering core, three turns, rising from a
			# broad coil at the foot to a raised, hooded head at the top
			var turns: float = 3.0
			var rings: int = 30
			var body_h: float = h * 0.78
			_kit.drum(Vector3(c.x, c.y, c.z), w * 0.5, w * 0.34, h * 0.06, SURF_STONE, 10)
			_kit.drum(Vector3(c.x, c.y + h * 0.06, c.z), w * 0.26, w * 0.08,
				body_h - h * 0.06, SURF_STONE, 8)
			for i in range(rings):
				var t: float = float(i) / float(rings - 1)
				var a: float = t * TAU * turns
				var rr: float = lerpf(w * 0.34, w * 0.1, t)
				var th: float = lerpf(w * 0.26, w * 0.12, t)
				var y: float = c.y + h * 0.06 + t * (body_h - h * 0.06)
				box(Vector3(th, body_h / float(rings) * 2.4, th),
					Vector3(c.x + sin(a) * rr, y, c.z + cos(a) * rr), SURF_TRIM, a)
			# the neck lifts out of the last turn and the head leans toward the altar
			box(Vector3(w * 0.11, h * 0.14, w * 0.11),
				Vector3(c.x, c.y + body_h + h * 0.05, c.z - w * 0.03), SURF_TRIM)
			box(Vector3(w * 0.32, h * 0.07, w * 0.42),
				Vector3(c.x, c.y + h * 0.935, c.z - w * 0.1), SURF_TRIM)
			box(Vector3(w * 0.5, h * 0.03, w * 0.3),
				Vector3(c.x, c.y + h * 0.985, c.z - w * 0.06), SURF_STONE)
		&"cairn":
			# a heap of skulls, stacked into a spire because somebody had time
			_kit.stepped_taper(Vector3(c.x, c.y, c.z), w, h, SURF_TRIM, 7, w * 0.12, false, 0.0, 1.15)
			box(Vector3(w * 1.15, 0.25, w * 1.15), Vector3(c.x, c.y + 0.12, c.z), SURF_STONE)
		_:
			# a pyre: a column of fire, held up by an iron basket
			_kit.drum(Vector3(c.x, c.y, c.z), w * 0.5, w * 0.34, h * 0.34,
				SURF_STONE, 8)
			_kit.drum(Vector3(c.x, c.y + h * 0.34, c.z), w * 0.44, w * 0.1,
				h * 0.66, SURF_TRIM, 8)
	_log_mass("idol", AABB(Vector3(c.x - w / 2.0, 0.0, c.z - w / 2.0),
		Vector3(w, c.y + h, w)))
	total_height = maxf(total_height, c.y + h)


# --------------------------------------------------------------------- pit

func _build_pit() -> void:
	var p: Rect2 = TempleGeometry.pit_rect(spec)
	if p.size.x <= 0.0:
		return
	tag("pit")
	# the throat: a dark shaft, so the hole reads as bottomless rather than as
	# a missing floor tile
	var depth: float = maxf(spec.height * 0.9, 4.0)
	box(Vector3(p.size.x, depth, p.size.y),
		Vector3(p.get_center().x, -depth / 2.0 - 0.3, p.get_center().y), SURF_DARK)
	# and the rim round it
	var rim: float = TempleGeometry.PIT_RIM
	for side in [-1.0, 1.0]:
		box(Vector3(p.size.x + rim * 2.0, rim, rim),
			Vector3(p.get_center().x, rim / 2.0, p.position.y + (0.0 if side < 0.0 else p.size.y)),
			SURF_TRIM)
		box(Vector3(rim, rim, p.size.y),
			Vector3(p.position.x + (0.0 if side < 0.0 else p.size.x), rim / 2.0,
				p.get_center().y), SURF_TRIM)
	var b: Rect2 = TempleGeometry.bridge_rect(spec)
	if b.size.x > 0.0:
		box(Vector3(b.size.x, 0.24, b.size.y),
			Vector3(b.get_center().x, -0.12, b.get_center().y), SURF_STONE)
		_log_mass("bridge", AABB(Vector3(b.position.x, -0.24, b.position.y),
			Vector3(b.size.x, 0.24, b.size.y)))


# ------------------------------------------------------------------- cells

func _build_cells() -> void:
	var cells: Array[Rect2] = TempleGeometry.cell_rects(spec)
	if cells.is_empty():
		return
	tag("cell")
	var h: float = minf(spec.height * 0.55, 3.2)
	if spec.form == &"ziggurat":
		h = minf(h, TempleGeometry.terrace_height(spec) - 0.35)
	var i := 0
	for c in cells:
		# the alcove reads as a recess: a dark back wall and a lintel over it
		box(Vector3(c.size.x, 0.35, c.size.y),
			Vector3(c.get_center().x, h + 0.17, c.get_center().y), SURF_STONE)
		box(Vector3(c.size.x * 0.9, h, 0.12),
			Vector3(c.get_center().x, h / 2.0,
				c.position.y + (c.size.y if c.position.x < 0.0 else 0.0)), SURF_DARK)
		_log_mass("cell_%d" % i, AABB(Vector3(c.position.x, 0.0, c.position.y),
			Vector3(c.size.x, h + 0.35, c.size.y)))
		i += 1


# -------------------------------------------------------------------- roof

func _build_roof() -> void:
	tag("roof")
	var r: Rect2 = TempleGeometry.site_rect(spec)
	var h: float = spec.height
	match TempleSpec.FORMS[spec.form]["roof"]:
		&"ridge":
			if spec.form == &"basilica" and TempleGeometry.basilica_has_nave_bearings(spec):
				_build_basilica_hierarchical_roof()
			else:
				var along_x: bool = r.size.x > r.size.y
				var yaw: float = PI / 2.0 if along_x else 0.0
				var span: float = r.size.y if along_x else r.size.x
				var along: float = r.size.x if along_x else r.size.y
				_kit.ridge_roof(Transform3D(Basis(Vector3.UP, yaw), Vector3(0.0, h, 0.0)),
					span + 1.2, along + 0.8, span * TempleGeometry.RIDGE_PITCH, SURF_ROOF,
					SURF_STONE, span, along)
				if spec.form == &"basilica" and not TempleGeometry.basilica_has_nave_bearings(spec):
					_build_basilica_shell_roof_bearings(r, along_x)
			total_height = maxf(total_height, TempleGeometry.roof_height(spec))
		&"flat":
			if spec.form == &"pylon":
				var roof_rect: Rect2 = TempleGeometry.pylon_roof_rect(spec)
				box(Vector3(roof_rect.size.x, 0.5, roof_rect.size.y),
					Vector3(roof_rect.get_center().x, h + 0.25,
						roof_rect.get_center().y), SURF_ROOF)
			else:
				box(Vector3(r.size.x + 0.8, 0.5, r.size.y + 0.8),
					Vector3(0.0, h + 0.25, 0.0), SURF_ROOF)
			total_height = maxf(total_height, h + 0.5)
		&"terraced":
			_build_terraces()
		&"dome":
			_build_dome_roof(r)
			total_height = maxf(total_height, TempleGeometry.roof_height(spec))
	if spec.spire:
		var base: float = TempleGeometry.hall_rect(spec).size.x * TempleGeometry.SPIRE_BASE
		var z: float = TempleGeometry.dais_rect(spec).get_center().y
		# The dais can be away from the dome apex or a transverse ridge.
		# Seat the entire spire footprint on masonry meeting the host roof.
		var top := TempleGeometry.roof_height(spec)
		if spec.form == &"rotunda":
			_build_rotunda_lantern()
		else:
			if top > h:
				box(Vector3(base, top - h, base), Vector3(0, (h + top) * 0.5, z), SURF_STONE)
			_kit.stepped_taper(Vector3(0.0, TempleGeometry.roof_height(spec), z),
				base, spec.spire_height, SURF_ROOF, 5, 0.2)
			total_height = maxf(total_height,
				TempleGeometry.roof_height(spec) + spec.spire_height)


func _build_rotunda_lantern() -> void:
	var base_y: float = TempleGeometry.roof_height(spec)
	var radius: float = TempleGeometry.rotunda_lantern_radius(spec)
	var shaft_h: float = spec.spire_height * 0.58
	var cap_h: float = spec.spire_height - shaft_h
	var top_r: float = radius * 0.76
	var sides: int = TempleGeometry.DOME_SEGMENTS
	host("rotunda_lantern")
	_kit.drum(Vector3(0.0, base_y, 0.0), radius, top_r, shaft_h,
		SURF_STONE, sides)
	component_note("rotunda_lantern_drum", "drum", SURF_STONE, {
		"center": Vector3(0.0, base_y, 0.0), "base_r": radius,
		"top_r": top_r, "height": shaft_h, "sides": sides,
		"aabb": AABB(Vector3(-radius, base_y, -radius),
			Vector3(radius * 2.0, shaft_h, radius * 2.0))})
	_kit.cone(top_r * 1.12, cap_h, Vector3(0.0, base_y + shaft_h, 0.0),
		SURF_ROOF, sides)
	component_note("rotunda_lantern_cap", "cone", SURF_ROOF, {
		"radius": top_r * 1.12, "height": cap_h,
		"center": Vector3(0.0, base_y + shaft_h, 0.0), "segments": sides,
		"aabb": AABB(Vector3(-top_r * 1.12, base_y + shaft_h,
			-top_r * 1.12), Vector3(top_r * 2.24, cap_h, top_r * 2.24))})
	host_end()
	_log_mass("rotunda_lantern", AABB(Vector3(-radius, base_y, -radius),
		Vector3(radius * 2.0, spec.spire_height, radius * 2.0)))
	total_height = maxf(total_height, base_y + spec.spire_height)


## When generated columns are absent, the fallback ridge still needs a real
## shell bearing. These stone heads fill the wedge between each wall top and
## the measured underside of the roof at both wall faces.
func _build_basilica_shell_roof_bearings(site: Rect2, along_x: bool) -> void:
	var profile: Vector2 = TempleGeometry.basilica_fallback_roof_wall_profile(spec)
	var span: float = minf(site.size.x, site.size.y)
	var wall_t: float = spec.wall_t
	var along: float = site.size.x if along_x else site.size.y
	var depth: float = along - wall_t * 2.0
	if depth <= 0.1:
		return
	for side in [-1.0, 1.0]:
		var points := PackedVector3Array()
		if along_x:
			var outer_z: float = side * span * 0.5
			var inner_z: float = side * (span * 0.5 - wall_t)
			points = PackedVector3Array([
				Vector3(0.0, spec.height, outer_z),
				Vector3(0.0, spec.height, inner_z),
				Vector3(0.0, profile.y, inner_z),
				Vector3(0.0, profile.x, outer_z)])
		else:
			var outer_x: float = side * span * 0.5
			var inner_x: float = side * (span * 0.5 - wall_t)
			points = PackedVector3Array([
				Vector3(outer_x, spec.height, 0.0),
				Vector3(inner_x, spec.height, 0.0),
				Vector3(inner_x, profile.y, 0.0),
				Vector3(outer_x, profile.x, 0.0)])
		host("basilica_shell_roof_bearing_%s" % ("left" if side < 0.0 else "right"))
		component_slab("basilica_shell_roof_bearing", points, depth, SURF_STONE, false)
		host_end()


## A basilica is a nave carried above lower side aisles, with a projecting
## pronaos on its own columns. Every roof sheet meets a bearing wall or beam.
func _build_basilica_hierarchical_roof() -> void:
	var site: Rect2 = TempleGeometry.site_rect(spec)
	var half: float = TempleGeometry.basilica_nave_half_width(spec)
	var nave_eave: float = TempleGeometry.basilica_nave_eave_height(spec)
	var nave_span: float = half * 2.0
	var nave_rise: float = nave_span * TempleGeometry.RIDGE_PITCH
	var nave_length: float = site.size.y + 0.8
	var nave_xf := Transform3D(Basis(), Vector3(0.0, nave_eave, 0.0))
	_build_basilica_nave_bearings(site, half, nave_eave)
	host("basilica_nave_roof")
	var roof_faces: Array[PackedVector3Array] = RoofShape.faces(nave_span, nave_length, nave_rise)
	for face in roof_faces:
		var world_face := PackedVector3Array()
		for point in face:
			world_face.append(nave_xf * point)
		# In RoofShape.gable, edge zero is the eave bearing line on either
		# slope. The wall closes this edge; keep both roof skins and the other
		# three thickness faces, including the ridge and gable end contacts.
		component_slab("basilica_nave_roof", world_face, RoofShape.DEPTH,
			SURF_ROOF, true, PackedInt32Array([0]))
	component_note("basilica_nave_roof_profile", "ridge_roof", SURF_ROOF, {
		"xf": nave_xf, "span_x": nave_span, "along_z": nave_length,
		"rise": nave_rise,
		"aabb": AABB(Vector3(-nave_span * 0.5,
			nave_eave - RoofShape.DEPTH * 0.5, -nave_length * 0.5),
			Vector3(nave_span, nave_rise + RoofShape.DEPTH, nave_length))})
	host_end()
	_build_basilica_aisle_roofs(site, half, nave_eave)
	_build_basilica_portico(site)
	_build_basilica_gable_returns(site, half, nave_eave, nave_rise)
	total_height = maxf(total_height, TempleGeometry.roof_height(spec))


func _build_basilica_nave_bearings(site: Rect2, _half: float, top: float) -> void:
	var columns: Array[Dictionary] = _columns
	if columns.is_empty():
		return
	var bearing_x := INF
	for column in columns:
		var pos: Vector3 = column["pos"]
		bearing_x = minf(bearing_x, absf(pos.x))
	var primary: Array[Dictionary] = []
	for column in columns:
		var pos: Vector3 = column["pos"]
		if absf(absf(pos.x) - bearing_x) < 0.01:
			primary.append(column)
	primary.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pos_a: Vector3 = a["pos"]
		var pos_b: Vector3 = b["pos"]
		return pos_a.z < pos_b.z)
	if primary.size() < 2:
		return
	var beam_h: float = clampf(spec.column_r * 0.34, 0.18, 0.38)
	var wall_base: float = TempleGeometry.column_cap_top(primary[0]) + beam_h
	var wall_t: float = TempleGeometry.basilica_nave_wall_thickness(spec)
	var opening_bottom: float = TempleGeometry.basilica_clerestory_opening_bottom(spec)
	var opening_top: float = top - 0.30
	var bearing_points: Array[float] = []
	for column in primary:
		var p: Vector3 = column["pos"]
		if bearing_points.is_empty() or absf(bearing_points.back() - p.z) > 0.01:
			bearing_points.append(p.z)
	host("basilica_nave_bearings")
	for side in [-1.0, 1.0]:
		var wall_x: float = side * bearing_x
		for index in range(bearing_points.size() - 1):
			var z0: float = bearing_points[index]
			var z1: float = bearing_points[index + 1]
			var mid: float = (z0 + z1) * 0.5
			var bay: float = z1 - z0
			var opening_w: float = minf(bay * 0.40, 1.65)
			var left_end: float = mid - opening_w * 0.5
			var right_start: float = mid + opening_w * 0.5
			# Continuous lower spandrel bears on the longitudinal architrave.
			var lower_h: float = opening_bottom - wall_base
			component_box("basilica_nave_lower_spandrel",
				Vector3(wall_t, lower_h, bay),
				Transform3D(Basis(), Vector3(wall_x, wall_base + lower_h * 0.5, mid)), SURF_STONE)
			var sill_h: float = minf(0.16, (opening_top - opening_bottom) * 0.22)
			component_box("basilica_clerestory_sill",
				Vector3(wall_t, sill_h, opening_w),
				Transform3D(Basis(), Vector3(wall_x, opening_bottom + sill_h * 0.5,
					mid)), SURF_STONE)
			for segment in [[z0, left_end], [right_start, z1]]:
				var segment_len: float = float(segment[1]) - float(segment[0])
				if segment_len <= 0.05:
					continue
				var z_mid: float = (float(segment[0]) + float(segment[1])) * 0.5
				component_box("basilica_nave_pier_wall",
					Vector3(wall_t, opening_top - opening_bottom, segment_len),
					Transform3D(Basis(), Vector3(wall_x,
						(opening_bottom + opening_top) * 0.5, z_mid)), SURF_STONE)
			var head_h: float = top - opening_top
			component_box("basilica_clerestory_head",
				Vector3(wall_t, head_h, bay),
				Transform3D(Basis(), Vector3(wall_x, opening_top + head_h * 0.5, mid)), SURF_STONE)
		# The terminal crossheads tie each end bay back to the existing side
		# wall, so the longitudinal bearing wall is supported at both ends too.
		var crosshead_h: float = beam_h
		var crosshead_bottom: float = wall_base - crosshead_h
		var side_wall_center: float = side * (site.size.x * 0.5 - spec.wall_t * 0.5)
		for station_z in [bearing_points.front(), bearing_points.back()]:
			var crosshead_w: float = absf(side_wall_center - wall_x) + spec.wall_t * 0.5
			var crosshead_center_x: float = (side_wall_center + wall_x) * 0.5
			component_box("basilica_nave_end_crosshead",
				Vector3(crosshead_w, crosshead_h, maxf(spec.column_r * 1.8, 0.62)),
				Transform3D(Basis(), Vector3(crosshead_center_x,
					crosshead_bottom + crosshead_h * 0.5, station_z)), SURF_TRIM)
		# Gable returns tie this elevated wall back to the front and rear shell.
		for end_z in [site.position.y, site.end.y]:
			var connector_depth: float = absf(end_z - (bearing_points[0] if end_z < 0.0 else bearing_points.back()))
			if connector_depth <= 0.02:
				continue
			var connector_center: float = (end_z + (bearing_points[0] if end_z < 0.0 else bearing_points.back())) * 0.5
			component_box("basilica_nave_end_return",
				Vector3(wall_t, top - wall_base, connector_depth),
				Transform3D(Basis(), Vector3(wall_x,
					wall_base + (top - wall_base) * 0.5, connector_center)), SURF_STONE)
	host_end()


func _build_basilica_aisle_roofs(site: Rect2, _half: float, _nave_eave: float) -> void:
	var outer: float = site.size.x * 0.5 + TempleGeometry.ORDER_REACH
	var inner: float = TempleGeometry.basilica_nave_bearing_x(spec) \
		+ TempleGeometry.basilica_nave_wall_thickness(spec) * 0.5
	var sill_bottom: float = TempleGeometry.basilica_clerestory_opening_bottom(spec)
	var inner_y: float = minf(sill_bottom - RoofShape.DEPTH * 0.5 - 0.15,
		spec.height + 0.42)
	var z0: float = site.position.y - 0.4
	var z1: float = site.end.y + 0.4
	for side in [-1.0, 1.0]:
		var outer_x: float = side * outer
		var inner_x: float = side * inner
		var outer_y: float = spec.height + 0.10
		var points := PackedVector3Array([
			Vector3(outer_x, outer_y, z0), Vector3(inner_x, inner_y, z0),
			Vector3(inner_x, inner_y, z1), Vector3(outer_x, outer_y, z1)])
		host("basilica_aisle_roof_%s" % ("left" if side < 0.0 else "right"))
		component_slab("basilica_aisle_roof", points, RoofShape.DEPTH, SURF_ROOF, true)
		host_end()
		var front_face := PackedVector3Array([
			Vector3(outer_x, spec.height, site.position.y),
			Vector3(inner_x, spec.height, site.position.y),
			Vector3(inner_x, inner_y, site.position.y)])
		var back_face := PackedVector3Array([
			Vector3(outer_x, spec.height, site.end.y),
			Vector3(inner_x, inner_y, site.end.y),
			Vector3(inner_x, spec.height, site.end.y)])
		host("basilica_aisle_rakes")
		component_slab("basilica_aisle_rake", front_face, 0.24, SURF_TRIM, false)
		component_slab("basilica_aisle_rake", back_face, 0.24, SURF_TRIM, false)
		host_end()


func _build_basilica_gable_returns(site: Rect2, half: float, eave: float, rise: float) -> void:
	var half_width: float = half
	var depth: float = maxf(spec.wall_t, 0.5)
	var profile_rect := Rect2(Vector2(-half_width, spec.height),
		Vector2(half_width * 2.0, eave - spec.height))
	for end in [-1.0, 1.0]:
		var z: float = site.position.y if end < 0.0 else site.end.y
		host("basilica_nave_gable")
		component_box("basilica_nave_gable_spandrel",
			Vector3(profile_rect.size.x, profile_rect.size.y, depth),
			Transform3D(Basis(), Vector3(0.0, spec.height + profile_rect.size.y * 0.5, z)), SURF_STONE)
		var tri := PackedVector3Array([
			Vector3(-half_width, eave, z), Vector3(half_width, eave, z),
			Vector3(0.0, eave + rise, z)])
		component_slab("basilica_nave_gable_triangle", tri, depth, SURF_STONE, false)
		host_end()
		for side in [-1.0, 1.0]:
			var inner_x: float = side * (TempleGeometry.basilica_nave_bearing_x(spec)
				+ TempleGeometry.basilica_nave_wall_thickness(spec) * 0.5)
			var outer_x: float = side * (site.size.x * 0.5 + TempleGeometry.ORDER_REACH)
			var inner_y: float = minf(
				TempleGeometry.basilica_clerestory_opening_bottom(spec) \
				- RoofShape.DEPTH * 0.5 - 0.15, spec.height + 0.42)
			var outer_y: float = spec.height + 0.10
			var points := PackedVector3Array([
				Vector3(outer_x, outer_y, z), Vector3(inner_x, spec.height, z),
				Vector3(inner_x, inner_y, z)])
			host("basilica_aisle_gable")
			component_slab("basilica_aisle_gable_fill", points, depth, SURF_STONE, false)
			host_end()


func _build_basilica_portico(site: Rect2) -> void:
	var half: float = TempleGeometry.basilica_portico_half_width(spec)
	var depth: float = TempleGeometry.basilica_portico_depth(spec)
	var eave: float = TempleGeometry.basilica_portico_eave_height(spec)
	var rise: float = TempleGeometry.basilica_portico_rise(spec)
	var column_points: Array[Vector2] = TempleGeometry.basilica_portico_column_positions(spec)
	var shaft_d: float = TempleGeometry.basilica_portico_shaft_diameter(spec)
	var base_d: float = shaft_d * 1.34
	var capital_d: float = shaft_d * 1.48
	var beam_h: float = shaft_d * 0.70
	var capital_h: float = shaft_d * 0.62
	var bearing_underside: float = eave + rise * (shaft_d * 0.5 / half) \
		- RoofShape.DEPTH * 0.5
	var capital_top: float = bearing_underside - beam_h
	var capital_bottom: float = capital_top - capital_h
	var base_h: float = shaft_d * 0.48
	var outer_z: float = site.position.y - depth + 0.5
	host("basilica_pronaos")
	for index in range(column_points.size()):
		var p: Vector2 = column_points[index]
		var base := component_box("basilica_portico_column_base", Vector3(base_d, base_h, base_d),
			Transform3D(Basis(), Vector3(p.x, base_h * 0.5, p.y)), SURF_STONE)
		var shaft_h: float = capital_bottom - base_h
		var shaft := component_box("basilica_portico_column_shaft", Vector3(shaft_d, shaft_h, shaft_d),
			Transform3D(Basis(), Vector3(p.x, base_h + shaft_h * 0.5, p.y)), SURF_STONE)
		var capital := component_box("basilica_portico_column_capital",
			Vector3(capital_d, capital_h, capital_d),
			Transform3D(Basis(), Vector3(p.x, capital_bottom + capital_h * 0.5, p.y)), SURF_TRIM)
		if base.is_empty() or shaft.is_empty() or capital.is_empty():
			continue
		_log_mass("basilica_portico_column_%d" % index,
			AABB(Vector3(p.x - base_d * 0.5, 0.0, p.y - base_d * 0.5),
				Vector3(base_d, capital_top, base_d)))
	var front_beam_z: float = outer_z
	var front_beam := component_box("basilica_portico_architrave",
		Vector3(half * 2.0, beam_h, shaft_d),
		Transform3D(Basis(), Vector3(0.0, capital_top + beam_h * 0.5, front_beam_z)), SURF_STONE)
	var side_beam_x: float = half - shaft_d * 0.5
	var side_beam_length: float = maxf(depth - 0.5 + spec.wall_t * 0.5, 0.5)
	for side in [-1.0, 1.0]:
		component_box("basilica_portico_side_beam", Vector3(shaft_d, beam_h, side_beam_length),
			Transform3D(Basis(), Vector3(side * side_beam_x, capital_top + beam_h * 0.5,
				outer_z + side_beam_length * 0.5)), SURF_STONE)
	if front_beam.is_empty():
		host_end()
		return
	var z0: float = site.position.y - depth
	var z1: float = site.position.y + 0.18
	for side in [-1.0, 1.0]:
		var x: float = side * half
		var points := PackedVector3Array([
			Vector3(x, eave, z0), Vector3(0.0, eave + rise, z0),
			Vector3(0.0, eave + rise, z1), Vector3(x, eave, z1)])
		# The outer eave edge is a wall/beam bearing. Let the bearing own its
		# vertical face; retain the two skins and the ridge/end faces.
		component_slab("basilica_portico_roof_slope", points, RoofShape.DEPTH,
			SURF_ROOF, true, PackedInt32Array([3]))
	var front_gable := PackedVector3Array([
		Vector3(-half, eave, front_beam_z), Vector3(half, eave, front_beam_z),
		Vector3(0.0, eave + rise, front_beam_z)])
	component_slab("basilica_portico_gable", front_gable, 0.35, SURF_STONE, false)
	var roof_aabb := AABB(Vector3(-half, eave - RoofShape.DEPTH * 0.5, z0),
		Vector3(half * 2.0, rise + RoofShape.DEPTH, z1 - z0))
	component_note("basilica_portico_roof", "gable_roof", SURF_ROOF,
		{"aabb": roof_aabb, "eave": eave, "rise": rise, "half_span": half,
		"z0": z0, "z1": z1})
	host_end()


# ------------------------------------------------------------------ the order

## A basilica's classical dress. Without it the form was four plain walls and a
## steep ridge, and the walker's verdict was "looks like a barn". What makes a
## hall read as a TEMPLE from outside is a short list, and this is it:
##
##   a stepped podium      the building stands on a stylobate, not on the grass
##   pilasters             the bay rhythm of the colonnade inside, shown outside
##   clerestory lights     one per bay, high in each eave wall
##   an entablature        architrave and cornice round all four walls
##   raking cornices       which turn each gable into a pediment
##   an aedicule           pilasters, lintel and a little pediment round the gate
##
## All of it is outside the walls and none of it is logged as a mass: the rite
## rules are about the inside of the building and must not see it. Nothing
## stands further out than `TempleGeometry.ORDER_REACH`, inside the roof's
## overhang, and the gate opening is left exactly as wide and as high as it was.
func _build_order() -> void:
	tag("order")
	var r: Rect2 = TempleGeometry.site_rect(spec)
	var h: float = spec.height
	var reach: float = TempleGeometry.ORDER_REACH
	var gate_half: float = TempleGeometry.GATE_W / 2.0 + spec.wall_t * 0.35
	var gh: float = minf(TempleGeometry.GATE_H, h - 0.6)
	var steps: int = TempleGeometry.PODIUM_STEPS
	var rise: float = TempleGeometry.PODIUM_RISE
	var podium: float = rise * float(steps)
	var ent_h: float = clampf(h * 0.11, 0.8, 1.6)
	var ent_y: float = h - ent_h
	var front: float = r.position.y
	var back: float = r.end.y
	var hw: float = r.size.x / 2.0

	# the podium: courses stepping in as they rise, cut down to the ground at
	# the gate so the way in stays level with the floor inside
	for k in range(steps):
		var out: float = reach * float(steps - k) / float(steps)
		var y0: float = rise * float(k)
		var cy: float = y0 + rise / 2.0
		for side in [-1.0, 1.0]:
			box(Vector3(out, rise, r.size.y + out * 2.0),
				Vector3(side * (hw + out / 2.0), cy, r.get_center().y), SURF_STONE)
			var w: float = hw - gate_half
			box(Vector3(w, rise, out), Vector3(side * (gate_half + w / 2.0), cy,
				front - out / 2.0), SURF_STONE)
		box(Vector3(r.size.x, rise, out), Vector3(0.0, cy, back + out / 2.0), SURF_STONE)

	# the entablature round all four walls: a frieze course, and the cornice
	# over it reaching out under the eaves
	var frieze_out: float = 0.24
	var cornice_y0: float = h - 0.42
	var cornice_y1: float = h - 0.13
	for band in [[ent_y, cornice_y0, frieze_out, SURF_STONE],
			[cornice_y0, cornice_y1, reach - 0.05, SURF_TRIM]]:
		var y0: float = band[0]
		var y1: float = band[1]
		var out2: float = band[2]
		var surf: int = band[3]
		var cy2: float = (y0 + y1) / 2.0
		for side in [-1.0, 1.0]:
			box(Vector3(out2, y1 - y0, r.size.y + out2 * 2.0),
				Vector3(side * (hw + out2 / 2.0), cy2, r.get_center().y), surf)
		for z in [front - out2 / 2.0, back + out2 / 2.0]:
			box(Vector3(r.size.x, y1 - y0, out2), Vector3(0.0, cy2, z), surf)

	# pilasters on every wall, on the bay rhythm, and a clerestory light in
	# each bay of the eave walls -- the walls the ridge runs along
	var along_x: bool = r.size.x > r.size.y
	var pw: float = clampf(h * 0.055, 0.5, 0.9)
	var p_out: float = 0.28
	var p_h: float = ent_y - podium
	var aedicule_half: float = gate_half + 0.45 + 0.7
	for wall in range(4):
		# 0 left, 1 right (along Z); 2 front, 3 back (along X)
		var runs_z: bool = wall < 2
		var length: float = r.size.y if runs_z else r.size.x
		var sgn: float = -1.0 if wall % 2 == 0 else 1.0
		var normal := Vector3(sgn, 0.0, 0.0) if runs_z else Vector3(0.0, 0.0, sgn)
		var face: float = hw if runs_z else (back if wall == 3 else -front)
		var n_bays: int = maxi(int(round(length / TempleGeometry.ORDER_BAY)), 2)
		var eave_wall: bool = runs_z != along_x
		var stations: Array[float] = []
		for i in range(n_bays + 1):
			stations.append(lerpf(-length / 2.0 + pw / 2.0, length / 2.0 - pw / 2.0,
				float(i) / float(n_bays)))
		for i in range(stations.size()):
			var s: float = stations[i]
			var at_gate: bool = wall == 2 and absf(s) < aedicule_half + pw
			if not at_gate:
				host("basilica_order_pilaster_%d_%d" % [wall, i])
				_pilaster(normal, face, s, runs_z, r, pw, p_out, podium, p_h)
				host_end()
			if not eave_wall or i == stations.size() - 1:
				continue
			var mid: float = (s + stations[i + 1]) / 2.0
			var bay: float = stations[i + 1] - s
			if wall == 2 and absf(mid) < aedicule_half + bay * 0.5:
				continue
			_clerestory(normal, face, mid, runs_z, r, minf(bay * 0.3, 1.4),
				clampf(h * 0.2, 1.0, 3.2), h * 0.66)

	# raking cornices: each gable end becomes a pediment framed top and bottom
	var has_nave_bearings: bool = TempleGeometry.basilica_has_nave_bearings(spec)
	var span: float = TempleGeometry.basilica_nave_half_width(spec) * 2.0 \
		if has_nave_bearings else minf(spec.width, spec.length)
	var along: float = r.size.x if along_x else r.size.y
	var roof_span: float = span
	var roof_rise: float = roof_span * TempleGeometry.RIDGE_PITCH
	var hs: float = span / 2.0
	var gable_base_y: float = TempleGeometry.basilica_nave_eave_height(spec)
	var roof_xf := Transform3D(Basis(Vector3.UP, PI / 2.0 if along_x else 0.0),
		Vector3(0.0, gable_base_y, 0.0))
	var rake_h: float = 0.32
	var rake_d: float = 0.5
	for end in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			var x0: float = side * span / 2.0
			var under0: float = roof_rise * (1.0 - absf(x0) / hs) - RoofShape.DEPTH * 0.5 - rake_h / 2.0
			var under1: float = roof_rise - RoofShape.DEPTH * 0.5 - rake_h / 2.0
			var a := Vector3(x0, under0, 0.0)
			var b := Vector3(0.0, under1, 0.0)
			var d: Vector3 = (b - a).normalized()
			var basis := Basis(d, Vector3(-d.y, d.x, 0.0), Vector3(0.0, 0.0, 1.0))
			var mid3: Vector3 = (a + b) / 2.0 + Vector3(0.0, 0.0, end * (along / 2.0 + rake_d / 2.0))
			host("basilica_nave_rakes")
			component_box("basilica_nave_rake", Vector3(a.distance_to(b), rake_h, rake_d),
				roof_xf * Transform3D(basis, mid3), SURF_TRIM)
			host_end()

	# the aedicule round the gate: two pilasters, a lintel, a little pediment
	host("basilica_gate")
	var capital_top: float = gh + 0.8
	var capital_h: float = 0.34
	var capital_bottom: float = capital_top - capital_h
	var lintel_h: float = 0.48
	var ped_y: float = capital_top + lintel_h
	var pier_w: float = clampf(r.size.x * 0.085, 0.9, 1.45)
	var pier_d: float = 0.55
	var pier_offset: float = gate_half + pier_w * 0.5 + 0.28
	for side in [-1.0, 1.0]:
		var pier_center := Vector3(side * pier_offset, (podium + capital_bottom) / 2.0,
			front - pier_d * 0.45)
		var pier_xf := Transform3D(Basis(), pier_center)
		component_box("basilica_gate_pier", Vector3(pier_w, capital_bottom - podium, pier_d),
			pier_xf, SURF_STONE)
		component_box("basilica_gate_base", Vector3(pier_w + 0.24, 0.24, pier_d + 0.12),
			Transform3D(Basis(), Vector3(pier_center.x, podium + 0.12,
				front - pier_d * 0.45)), SURF_TRIM)
		component_box("basilica_gate_capital", Vector3(pier_w + 0.32, capital_h,
			pier_d + 0.18), Transform3D(Basis(), Vector3(pier_center.x,
				capital_top - capital_h * 0.5, front - pier_d * 0.45)), SURF_TRIM)
	var lintel_w: float = pier_offset * 2.0 + pier_w
	component_box("basilica_gate_lintel", Vector3(lintel_w, lintel_h, 0.62),
		Transform3D(Basis(), Vector3(0.0, capital_top + lintel_h * 0.5,
			front - 0.31)), SURF_STONE)
	var ped_half: float = gate_half + 1.2
	var ped_rise: float = ped_half * 0.32
	if ped_y + ped_rise < ent_y - 0.2:
		_kit.gable_end_at(Transform3D(Basis(), Vector3(0.0, ped_y, front)),
			ped_half, ped_rise, -0.5, 0.0, SURF_TRIM)
	host_end()


## One pilaster on an outer wall: a shaft standing a little proud, on a base,
## under a capital. `s` is its station along the wall.
func _pilaster(normal: Vector3, face: float, s: float, runs_z: bool, r: Rect2,
		pw: float, out: float, y0: float, height: float) -> void:
	var c: Vector3 = _on_wall(normal, face, s, runs_z, r)
	var sz := func(w: float, hh: float, d: float) -> Vector3:
		return Vector3(d, hh, w) if runs_z else Vector3(w, hh, d)
	# The shaft carries its capital. It must stop at the capital's underside,
	# rather than extending through it and duplicating its visible top face.
	var shaft_height := height - 0.34
	_order_pilaster_box("basilica_order_pilaster_shaft", sz.call(pw, shaft_height, out),
		c + normal * (out / 2.0) + Vector3(0.0, y0 + shaft_height / 2.0, 0.0), SURF_STONE)
	_order_pilaster_box("basilica_order_pilaster_base", sz.call(pw + 0.16, 0.3, out + 0.08), c + normal * ((out + 0.08) / 2.0)
		+ Vector3(0.0, y0 + 0.15, 0.0), SURF_STONE)
	_order_pilaster_box("basilica_order_pilaster_capital", sz.call(pw + 0.22, 0.34, out + 0.14), c + normal * ((out + 0.14) / 2.0)
		+ Vector3(0.0, y0 + height - 0.17, 0.0), SURF_TRIM)


func _order_pilaster_box(role: String, size: Vector3, position: Vector3, surface: int) -> void:
	component_box(role, size, Transform3D(Basis(), position), surface)
	_log_part("box", position, size)


## A clerestory light: a dark opening on the outer face with a stone sill and
## a trim head, high in the wall between two pilasters.
func _clerestory(normal: Vector3, face: float, s: float, runs_z: bool, r: Rect2,
		w: float, hh: float, cy: float) -> void:
	var c: Vector3 = _on_wall(normal, face, s, runs_z, r)
	var sz := func(ww: float, yy: float, d: float) -> Vector3:
		return Vector3(d, yy, ww) if runs_z else Vector3(ww, yy, d)
	box(sz.call(w, hh, 0.04), c + normal * 0.03 + Vector3(0.0, cy, 0.0), SURF_DARK)
	box(sz.call(w + 0.3, 0.18, 0.2), c + normal * 0.1
		+ Vector3(0.0, cy - hh / 2.0 - 0.09, 0.0), SURF_STONE)
	box(sz.call(w + 0.3, 0.22, 0.16), c + normal * 0.08
		+ Vector3(0.0, cy + hh / 2.0 + 0.11, 0.0), SURF_TRIM)


## The point on an outer wall face at station `s` along it, at ground level.
static func _on_wall(normal: Vector3, face: float, s: float, runs_z: bool,
		r: Rect2) -> Vector3:
	if runs_z:
		return Vector3(normal.x * face, 0.0, r.get_center().y + s)
	return Vector3(s, 0.0, normal.z * face)


func _build_dome_roof(rect: Rect2) -> void:
	var radius := TempleGeometry.dome_radius(spec)
	if spec.form == &"rotunda":
		# The horizontal drum cap is a circular annulus. Its inner edge overlaps
		# the dome spring by 8 cm and its outer edge bears on the wall crown.
		var wall_outer: float = TempleGeometry.rotunda_outer_radius(spec)
		var outer: float = wall_outer + 0.45
		var half_depth: float = RoofShape.DEPTH * 0.5
		var profile := PackedVector2Array([
			Vector2(outer, half_depth), Vector2(radius - 0.08, half_depth),
			Vector2(radius - 0.08, -half_depth), Vector2(outer, -half_depth),
			Vector2(outer, half_depth)])
		var center := Vector3(0.0, spec.height, 0.0)
		host("rotunda_drum_crown")
		_kit.revolve(profile, center, SURF_ROOF, TempleGeometry.DOME_SEGMENTS)
		component_note("rotunda_drum_crown", "revolve", SURF_ROOF, {
			"profile": profile, "center": center,
			"segments": TempleGeometry.DOME_SEGMENTS, "arc": TAU,
			"start": 0.0, "ellipse_scale": Vector2.ONE, "close_ends": true,
			"aabb": AABB(Vector3(-outer, spec.height - half_depth, -outer),
				Vector3(outer * 2.0, RoofShape.DEPTH, outer * 2.0))})
		host_end()
	else:
		var rim := PackedVector2Array()
		for i in range(TempleGeometry.DOME_SEGMENTS):
			var angle := TAU * float(i) / float(TempleGeometry.DOME_SEGMENTS)
			rim.append(Vector2(cos(angle), sin(angle)) * radius)
		var deck := rect.grow(0.4)
		var outline := PackedVector2Array([deck.position, Vector2(deck.end.x, deck.position.y),
			deck.end, Vector2(deck.position.x, deck.end.y)])
		for piece in RoofShape.subtract(outline, rim):
			var face := PackedVector3Array()
			for p in piece:
				face.append(Vector3(p.x, spec.height, p.y))
			_kit.slab_poly(face, RoofShape.DEPTH, SURF_ROOF, true)
	# Closed shell with matching upper and lower seams at the deck.
	var rise: float = radius * 0.55
	var top_radius: float = TempleGeometry.rotunda_lantern_radius(spec) \
		if spec.form == &"rotunda" and spec.spire else 0.0
	var mid := _dome_profile(radius, rise, top_radius)
	var shell := PackedVector2Array()
	for p in mid:
		shell.append(p + Vector2(0, RoofShape.DEPTH * 0.5))
	for i in range(mid.size() - 1, -1, -1):
		shell.append(mid[i] - Vector2(0, RoofShape.DEPTH * 0.5))
	shell.append(shell[0])
	_kit.revolve(shell, Vector3(0, spec.height, 0), SURF_ROOF, TempleGeometry.DOME_SEGMENTS)
	if spec.form == &"rotunda" and spec.spire:
		# A closed round cap gives the optional lantern an actual horizontal seat.
		var cap_bottom := spec.height + rise - RoofShape.DEPTH * 0.5
		host("rotunda_lantern_seat")
		_kit.drum(Vector3(0.0, cap_bottom, 0.0), top_radius, top_radius,
			RoofShape.DEPTH, SURF_ROOF, TempleGeometry.DOME_SEGMENTS)
		component_note("rotunda_lantern_seat", "drum", SURF_ROOF, {
			"center": Vector3(0.0, cap_bottom, 0.0), "base_r": top_radius,
			"top_r": top_radius, "height": RoofShape.DEPTH,
			"sides": TempleGeometry.DOME_SEGMENTS,
			"aabb": AABB(Vector3(-top_radius, cap_bottom, -top_radius),
				Vector3(top_radius * 2.0, RoofShape.DEPTH, top_radius * 2.0))})
		host_end()


## The lowest terrace as a ring of four slabs, with the doorway left out of the
## front one. What is inside it is the chamber; what is on top of it is the
## rest of the mountain.
func _terrace_ring(r: Rect2, th: float) -> void:
	var t: float = TempleGeometry.terrace_inset(spec)
	var gate: float = TempleGeometry.GATE_W
	var runs := [
		Rect2(Vector2(r.position.x, r.end.y - t), Vector2(r.size.x, t)),
		Rect2(Vector2(r.position.x, r.position.y + t), Vector2(t, r.size.y - t * 2.0)),
		Rect2(Vector2(r.end.x - t, r.position.y + t), Vector2(t, r.size.y - t * 2.0)),
		Rect2(Vector2(r.position.x, r.position.y), Vector2((r.size.x - gate) / 2.0, t)),
		Rect2(Vector2(gate / 2.0, r.position.y), Vector2((r.size.x - gate) / 2.0, t)),
	]
	for run in runs:
		if run.size.x <= 0.01 or run.size.y <= 0.01:
			continue
		box(Vector3(run.size.x, th, run.size.y),
			Vector3(run.get_center().x, th / 2.0, run.get_center().y), SURF_STONE)
	# the lintel over the doorway
	var gh: float = minf(TempleGeometry.GATE_H, th - 0.6)
	if th - gh > 0.05:
		box(Vector3(gate + t, th - gh, t),
			Vector3(0.0, gh + (th - gh) / 2.0, r.position.y + t / 2.0), SURF_STONE)


static func _dome_profile(radius: float, rise: float, top_radius := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps: int = 6
	for i in range(steps + 1):
		var t: float = float(i) / steps
		var ring_radius: float = top_radius + (radius - top_radius) * cos(t * PI / 2.0)
		pts.append(Vector2(ring_radius, rise * sin(t * PI / 2.0)))
	return pts


## The stepped mountain, and the stair up the front of it.
func _build_terraces() -> void:
	var th: float = TempleGeometry.terrace_height(spec)
	for level in range(spec.terraces):
		var r: Rect2 = TempleGeometry.terrace_rect(spec, level)
		if r.size.x <= 1.0 or r.size.y <= 1.0:
			break
		if level == 0:
			# the lowest terrace is hollow: the chamber where the rite is held
			# is inside it, so it goes up as four thick slabs round a room
			# rather than as a solid block of stone
			_terrace_ring(r, th)
		else:
			# stone, not roof. The cutaway view hides the roof surface, and a
			# mountain built out of roof vanished from under its own god, who
			# was left hanging in the sky above an empty chamber.
			box(Vector3(r.size.x, th, r.size.y),
				Vector3(r.get_center().x, th * float(level) + th / 2.0, r.get_center().y),
				SURF_STONE)
		# a coping course round the lip of each terrace. It is what a stepped
		# mountain actually has, and it is also the only thing a ziggurat puts
		# on the roof surface -- without it that surface is empty, the mesh
		# comes back with three surfaces instead of four, and every material
		# after it is handed the wrong colour.
		var lip: float = 0.28
		var y: float = th * float(level + 1)
		for side in [-1.0, 1.0]:
			box(Vector3(r.size.x, lip, lip * 1.6),
				Vector3(r.get_center().x, y - lip / 2.0,
					r.position.y + (0.0 if side < 0.0 else r.size.y)), SURF_ROOF)
			box(Vector3(lip * 1.6, lip, r.size.y),
				Vector3(r.position.x + (0.0 if side < 0.0 else r.size.x),
					y - lip / 2.0, r.get_center().y), SURF_ROOF)
		_log_mass("terrace_%d" % level, AABB(Vector3(r.position.x, 0.0, r.position.y),
			Vector3(r.size.x, th * float(level + 1), r.size.y)))
	var top: float = TempleGeometry.terrace_top(spec)
	var flights: Array[Rect2] = TempleGeometry.stair_rects(spec)
	var names := ["stair_left", "stair_right"]
	for f in range(flights.size()):
		_stair_flight(flights[f], top, names[f])
	total_height = maxf(total_height, top)


func _stair_flight(s: Rect2, top: float, name: String) -> void:
	var steps := maxi(ceili(top / 0.35), 4)
	var chamber_front := TempleGeometry.hall_rect(spec).position.y
	var ceiling := TempleGeometry.terrace_height(spec)
	var masses := {}
	for i in range(steps):
		# Solid blocks rise toward the summit; centres sit halfway along
		# their treads and no riser exceeds 350 mm, including the landing.
		var y := top * float(i + 1) / steps
		var z := lerpf(s.position.y, s.end.y, (float(i) + 0.5) / steps)
		var half := (s.size.y / steps + 0.05) * 0.5
		# Outdoor flights are solid to ground. Within the chamber footprint
		# their masonry starts at the stone ceiling, preserving the room below.
		for upper in [false, true]:
			var front := maxf(z - half, chamber_front) if upper else z - half
			var back := z + half if upper else minf(z + half, chamber_front)
			var bottom := ceiling if upper else 0.0
			if back <= front or y <= bottom:
				continue
			var bounds := AABB(Vector3(s.position.x, bottom, front), Vector3(s.size.x, y - bottom, back - front))
			box(bounds.size, bounds.get_center(), SURF_STONE)
			masses[upper] = AABB(masses[upper]).merge(bounds) if masses.has(upper) else bounds
	for upper in masses:
		_log_mass(name + ("_upper" if upper else ""), masses[upper], ceiling if upper else 0.0)


# ---------------------------------------------------------------- outworks

func _build_outworks() -> void:
	var r: Rect2 = TempleGeometry.site_rect(spec)
	if spec.form == &"pylon":
		tag("pylon")
		for i in range(TempleGeometry.pylon_rects(spec).size()):
			var p: Rect2 = TempleGeometry.pylon_rects(spec)[i]
			var h: float = spec.height * 1.35
			_build_battered_pylon_tower(p, h, i)
	if spec.obelisks:
		tag("obelisk")
		var oh: float = TempleGeometry.obelisk_height(spec)
		for side in [-1.0, 1.0]:
			var c: Vector2 = TempleGeometry.obelisk_center(spec, side)
			var x: float = c.x
			var z: float = c.y
			box(Vector3(oh * 0.14, oh * 0.82, oh * 0.14), Vector3(x, oh * 0.41, z),
				SURF_STONE)
			_kit.stepped_taper(Vector3(x, oh * 0.82, z), oh * 0.14, oh * 0.18,
				SURF_TRIM, 3, 0.05)
			_log_mass("obelisk_%s" % ("left" if side < 0.0 else "right"),
				AABB(Vector3(x - oh * 0.07, 0.0, z - oh * 0.07),
					Vector3(oh * 0.14, oh, oh * 0.14)))
			total_height = maxf(total_height, oh)


## A rectangular Pylon is battered on four continuous sloped faces. The same
## source rectangles bound the emitted slabs, their component rows, and mass.
func _build_battered_pylon_tower(rect: Rect2, height: float, index: int) -> void:
	var depth: float = TempleGeometry.pylon_tower_shell_depth(spec)
	var half: float = depth * 0.5
	# Inset each profile by half the slab depth. The emitted outer face stays
	# within its published tower rectangle instead of growing beyond the lot.
	var left: float = rect.position.x + half
	var right: float = rect.end.x - half
	var front: float = rect.position.y + half
	var back: float = rect.end.y - half
	var inset_x: float = (right - left) * 0.07
	var inset_z: float = (back - front) * 0.07
	var base_course_h: float = clampf(depth, 0.18, 0.36)
	var base_y: float = base_course_h
	var top_y: float = height - half
	var top_front: float = front + inset_z
	var top_back: float = back - inset_z
	var top_left: float = left + inset_x
	var top_right: float = right - inset_x
	host("pylon_tower_%d" % index)
	# A continuous stone footing reaches the ground and supports the sloped
	# shell faces. Their centre profiles begin at its top plane; slab thickness
	# embeds each lower edge into the course instead of leaving an air gap.
	var base_size := Vector3(rect.size.x, base_course_h, rect.size.y)
	var base_center := Vector3(rect.get_center().x, base_course_h * 0.5,
		rect.get_center().y)
	component_box("pylon_tower_base_course", base_size,
		Transform3D(Basis.IDENTITY, base_center), SURF_STONE)
	component_slab("pylon_battered_face", PackedVector3Array([
		Vector3(left, base_y, front), Vector3(right, base_y, front),
		Vector3(top_right, top_y, top_front), Vector3(top_left, top_y, top_front)]),
		depth, SURF_STONE, false)
	component_slab("pylon_battered_face", PackedVector3Array([
		Vector3(right, base_y, back), Vector3(left, base_y, back),
		Vector3(top_left, top_y, top_back), Vector3(top_right, top_y, top_back)]),
		depth, SURF_STONE, false)
	component_slab("pylon_battered_face", PackedVector3Array([
		Vector3(left, base_y, front), Vector3(left, base_y, back),
		Vector3(top_left, top_y, top_back), Vector3(top_left, top_y, top_front)]),
		depth, SURF_STONE, false)
	component_slab("pylon_battered_face", PackedVector3Array([
		Vector3(right, base_y, front), Vector3(top_right, top_y, top_front),
		Vector3(top_right, top_y, top_back), Vector3(right, base_y, back)]),
		depth, SURF_STONE, false)
	component_slab("pylon_battered_cap", PackedVector3Array([
		Vector3(top_left, top_y, top_front), Vector3(top_right, top_y, top_front),
		Vector3(top_right, top_y, top_back), Vector3(top_left, top_y, top_back)]),
		depth, SURF_STONE, false)
	_log_mass("pylon_%d" % index, AABB(Vector3(rect.position.x, 0.0, rect.position.y),
		Vector3(rect.size.x, height, rect.size.y)))
	total_height = maxf(total_height, height)
	host_end()

# ---------------------------------------------------------------- dressing

## What the cult puts in the place once the masons have gone: braziers down the
## processional way, a knife and a cup on the altar, chains and cages in the
## cells, banners on the walls.
##
## These are prop placements rather than geometry, and they are logged so the
## rite check can ask the questions that matter about them -- above all whether
## the way to the altar is lit.
func _dress() -> void:
	tag("dressing")
	_dress_braziers()
	_dress_pit()
	_dress_altar()
	_dress_cells()
	_dress_walls()


## Braziers in pairs down the axis, flanking the way without standing in it.
##
## Spaced by the rule the rite check tests rather than by a count: walk the
## axis, and whenever the last flame is further behind than a brazier throws
## light, set down another pair. A pair that would land in the hole steps
## forward to the far lip of it instead of being dropped -- which is what left
## a ten metre stretch of the walk dark when they were merely skipped.
func _dress_braziers() -> void:
	var z0: float = TempleGeometry.entry_point(spec).y + 1.2
	var z1: float = TempleGeometry.altar_center(spec).z - 1.5
	if z1 <= z0:
		return
	var x: float = TempleGeometry.axis_half_width(spec) + 0.5
	var pit: Rect2 = TempleGeometry.pit_rect(spec)
	if spec.form == &"rotunda" and pit.size.x > 0.0:
		var light_size: Vector2 = PropCatalog.footprint("Cauldron") * BRAZIER_SCALE
		x = maxf(x, pit.size.x * 0.5 + TempleGeometry.PIT_RIM \
			+ light_size.x * 0.5 + 0.15)
	var reach: float = TempleGeometry.LIGHT_REACH * 0.45
	var z: float = z0
	var placed := 0
	while z <= z1 + 0.01 and placed < 24:
		var at: float = z
		if pit.size.x > 0.0 and at > pit.position.y - 0.6 and at < pit.end.y + 0.6:
			# step past the hole rather than into it
			at = pit.end.y + 0.8
		if at > z1:
			break
		_brazier_pair(x, at)
		placed += 1
		z = at + reach
	# and one pair at the foot of the dais, so the altar is never approached
	# out of the dark
	_brazier_pair(x, z1)


## A centre beside the axis is not enough: a bowl has width, and the pylon
## extends further into the court than the front wall. Search a small local
## neighbourhood, keeping both members of the pair clear and on real floor.
func _brazier_pair(x: float, z: float) -> void:
	for dz in [0.0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8, 2.4, -2.4]:
		for dx in [0.0, 0.6, 1.2]:
			var left := Vector2(-x - float(dx), z + float(dz))
			var right := Vector2(x + float(dx), z + float(dz))
			if _brazier_clear(left) and _brazier_clear(right):
				_prop("Cauldron", Vector3(left.x, 0.002, left.y), 0.0, BRAZIER_SCALE, &"light")
				_prop("Cauldron", Vector3(right.x, 0.002, right.y), 0.0, BRAZIER_SCALE, &"light")
				return


func _brazier_clear(pos: Vector2) -> bool:
	var size := PropCatalog.footprint("Cauldron") * BRAZIER_SCALE + Vector2.ONE * 0.12
	var rect := Rect2(pos - size * 0.5, size)
	var supported := false
	if spec.form == &"rotunda":
		# The walk-grid floor rectangles are conservative 0.45 m bands; the
		# builder fills their circular perimeter wings with emitted stone slabs.
		# The later exact-circle corner test and pit-clearance test prove this
		# whole prop footprint lies on the continuous emitted floor.
		supported = true
	else:
		for floor_rect in TempleGeometry.floor_rects(spec):
			supported = supported or floor_rect.encloses(rect)
	if not supported:
		return false
	if spec.form == &"rotunda":
		var inner: float = TempleGeometry.rotunda_inner_radius(spec) - 0.12
		for x_sign in [-1.0, 1.0]:
			for z_sign in [-1.0, 1.0]:
				var corner := pos + Vector2(float(x_sign) * size.x * 0.5,
					float(z_sign) * size.y * 0.5)
				if corner.length() > inner:
					return false
	var pit := TempleGeometry.pit_rect(spec)
	if pit.size.x > 0.0 and pit.grow(TempleGeometry.PIT_RIM).intersects(rect):
		return false
	for mass in mass_log:
		var name := String(mass["name"])
		# Tangent wall panels have radial triangles; their conservative AABBs
		# overlap far inside the room. The circle test above is their true bound.
		if spec.form == &"rotunda" and name.begins_with("wall_rotunda_"):
			continue
		if not (name.begins_with("wall_") or name.begins_with("pylon_") \
				or name.begins_with("column_") or name == "dais"):
			continue
		var b: AABB = mass["aabb"]
		if Rect2(Vector2(b.position.x, b.position.z), Vector2(b.size.x, b.size.z)).intersects(rect):
			return false
	for p in prop_log:
		if p["key"] == "Cauldron":
			var v: Vector3 = p["pos"]
			if Rect2(Vector2(v.x, v.z) - size * 0.5, size).intersects(rect):
				return false
	return true


## Fire along the lip of the pit.
##
## The braziers down the way step round the hole, which leaves the crossing --
## the most frightening part of the walk, and the part a congregation actually
## remembers -- unlit. These stand along both lips at the same spacing, so a
## wide pit is lit the whole way over rather than only at its corners: with
## corner braziers alone, a twelve metre hole left the middle of its own bridge
## nine metres from the nearest flame.
func _dress_pit() -> void:
	var pit: Rect2 = TempleGeometry.pit_rect(spec)
	if pit.size.x <= 0.0:
		return
	var out: float = TempleGeometry.PIT_RIM + PropCatalog.footprint("Cauldron").x * BRAZIER_SCALE * 0.5 + 0.07
	var x: float = pit.size.x / 2.0 + out
	var reach: float = TempleGeometry.LIGHT_REACH * 0.62
	var z0: float = pit.position.y - out
	var z1: float = pit.end.y + out
	var n: int = maxi(int(ceil((z1 - z0) / reach)), 1)
	# Reserve the middle pair first: the centre of a wide bridge is the point
	# furthest from either lip, and neighbouring bowls must not displace it.
	_brazier_pair(x, pit.get_center().y)
	for i in range(n + 1):
		var z: float = lerpf(z0, z1, float(i) / float(n))
		_brazier_pair(x, z)


## The altar furniture. A cup, a blade, and candles: the whole apparatus of the
## rite is four small objects and a great deal of stone.
func _dress_altar() -> void:
	var c: Vector3 = TempleGeometry.altar_center(spec)
	var top: float = c.y + spec.altar_h
	_prop("Chalice", Vector3(c.x - spec.altar_w * 0.28, top, c.z), 0.0, 1.0, &"vessel")
	_prop("Table_Knife", Vector3(c.x + spec.altar_w * 0.2, top, c.z), PI / 2.0, 1.4,
		&"blade")
	for side in [-1.0, 1.0]:
		_prop("CandleStick_Triple", Vector3(c.x + side * spec.altar_w * 0.42, top,
			c.z + spec.altar_l * 0.2), 0.0, 1.0, &"light")


## What the cells hold.
func _dress_cells() -> void:
	var cells: Array[Rect2] = TempleGeometry.cell_rects(spec)
	var chance: float = float(TempleSpec.CULTS[spec.cult]["chains"])
	var i := 0
	for cell in cells:
		var c: Vector2 = cell.get_center()
		var yaw: float = PI / 2.0 if c.x < 0.0 else -PI / 2.0
		if float(i) / maxf(float(cells.size()), 1.0) < chance:
			_prop("Cage_Small", Vector3(c.x, 0.0, c.y), yaw, 1.0, &"cage")
		else:
			_prop("Chain_Coil", Vector3(c.x, 0.0, c.y), yaw, 1.0, &"chain")
		i += 1


## Banners between the columns, and torches on the walls, which is where the
## light that is not fire in a bowl comes from.
func _dress_walls() -> void:
	if spec.form == &"rotunda":
		_dress_rotunda_walls()
		return
	var hall: Rect2 = TempleGeometry.hall_rect(spec)
	var n: int = clampi(int(hall.size.y / 6.0), 1, 5)
	for i in range(n):
		var t: float = (float(i) + 0.5) / float(n)
		var z: float = lerpf(hall.position.y + 1.5, hall.end.y - 2.0, t)
		for side in [-1.0, 1.0]:
			var x: float = (hall.end.x if side > 0.0 else hall.position.x) - side * 0.12
			var yaw: float = -PI / 2.0 if side > 0.0 else PI / 2.0
			_prop("Torch_Metal", Vector3(x, 2.4, z), yaw, 1.0, &"light")
			if i % 2 == 0:
				_prop("Banner_1", Vector3(x, spec.height * 0.62, z + 1.2), yaw, 1.0,
					&"banner")


## Wall dressings follow the emitted circular inner face. The old square-AABB
## stations put torches and banners in the four empty corners of a round room.
func _dress_rotunda_walls() -> void:
	var radius: float = TempleGeometry.rotunda_inner_radius(spec) - 0.12
	var count: int = clampi(int(ceil(TAU * radius / 6.0)), 8, 32)
	var gate_half: float = asin(clampf(TempleGeometry.GATE_W * 0.5 / radius,
		0.0, 0.98)) + 0.28
	var idol_half: float = asin(clampf(spec.idol_width * 0.5 / radius,
		0.0, 0.95)) + 0.24
	for i in range(count):
		var angle: float = TAU * (float(i) + 0.5) / float(count)
		var back_delta: float = minf(angle, TAU - angle)
		if absf(angle - PI) < gate_half or back_delta < idol_half:
			continue
		var x: float = sin(angle) * radius
		var z: float = cos(angle) * radius
		var yaw: float = -angle
		_prop("Torch_Metal", Vector3(x, 2.4, z), yaw, 1.0, &"light")
		if i % 2 == 0:
			_prop("Banner_1", Vector3(x, spec.height * 0.62, z), yaw, 1.0,
				&"banner")


func _prop(key: String, pos: Vector3, yaw: float, scale: float,
		kind: StringName) -> void:
	prop_log.append({"key": key, "pos": pos, "yaw": yaw, "scale": scale,
		"kind": kind})
