class_name ChurchBuilder
extends MassBuilder
## ChurchSpec -> ArrayMesh. Massing-first: nave box, optional aisles, transept,
## apse (half-cylinder), west tower + roof, then window/door/trim detailing.
##
## Surfaces: 0 = stone walls, 1 = trim/string courses, 2 = roof, 3 = openings
##           (dark recesses for windows/doors).

const SURF_STONE := 0
const SURF_TRIM := 1
const SURF_ROOF := 2
const SURF_OPEN := 3

## How far attached masses penetrate the host wall, so they read as joined
## rather than floating beside it or swallowing the nave.
## Joint depths live in ChurchGeometry so the blueprint reads the same values.
const TOWER_EMBED := ChurchGeometry.TOWER_EMBED
const APSE_EMBED := ChurchGeometry.APSE_EMBED

var spec: ChurchSpec
var _roof_volumes: Array[PackedVector3Array] = []

func build(p_spec: ChurchSpec) -> ArrayMesh:
	spec = p_spec
	begin_metric(4)
	_roof_volumes.clear()

	var w: float = spec.width
	var l: float = spec.length
	var h: float = spec.height

	total_height = h

	# ---------- nave ----------
	tag("nave")
	_nave_shell()
	_log_mass("nave", AABB(Vector3(-w / 2.0, 0.0, -l / 2.0), Vector3(w, h, l)))
	total_height = maxf(total_height, h + w * spec.roof_pitch)

	# ---------- side aisles ----------
	tag("aisle")
	if spec.aisles > 0:
		var aw: float = spec.aisle_width
		# Aisles fit BETWEEN the tower zone (west) and the transept crossing
		# (east) so they never slice through either. Whether there is room is
		# decided in ChurchGenerator: build() must not rewrite its own input.
		var zr: Vector2 = ChurchGeometry.aisle_z_range(spec)
		var az0: float = zr.x
		var al: float = zr.y - zr.x
		var az: float = (zr.x + zr.y) / 2.0
		# One pair of aisles per ring: single for most, double for Notre-Dame,
		# and the outer pair of Cologne's five-aisled section.
		for ring in range(spec.aisles):
			var ah: float = ChurchGeometry.aisle_height(spec, ring)
			for side_v in [-1.0, 1.0]:
				var side: float = side_v
				var ax: float = ChurchGeometry.aisle_center_x(spec, side, ring)
				box(Vector3(aw, ah, al), Vector3(ax, ah / 2.0, az), SURF_STONE)
				_log_mass("aisle_%s_%d" % ["left" if side < 0.0 else "right", ring],
					ChurchGeometry.aisle_aabb(spec, side, ring))
				# Only the OUTERMOST ring gets side windows. Every ring used to,
				# so on a double-aisled church the inner ring's windows were cut
				# into a wall the outer ring stands hard against -- glazing that
				# looks into the next aisle's masonry.
				if ring == spec.aisles - 1:
					var nwin: int = int(al / 3.0)
					for i in range(nwin):
						var wz: float = az0 + al / float(nwin + 1) * (i + 1)
						window(Vector3(ax + side * (aw / 2.0 + 0.02), ah * 0.5, wz),
							side * PI / 2.0, 0.7, ah * 0.33, spec.window_style)
	_build_clerestory()

	# ---------- transept ----------
	tag("transept")
	if spec.transept:
		var tz_len: float = spec.transept_len
		var tz_w: float = ChurchGeometry.transept_depth(spec)
		var tz_z: float = ChurchGeometry.transept_center_z(spec)
		box(Vector3(tz_len, h, tz_w), Vector3(0, h / 2.0, tz_z), SURF_STONE)
		_log_mass("transept", ChurchGeometry.transept_aabb(spec))
		for sx_v in [-1.0, 1.0]:
			window(Vector3(sx_v * (tz_len / 2.0 + 0.02), h * 0.55, tz_z),
				sx_v * PI / 2.0, spec.window_w, spec.window_h, spec.window_style)
		if spec.corner_turrets:
			for sx_v in [-1.0, 1.0]:
				pinnacle(Vector3(sx_v * (tz_len / 2.0 - 0.3), h + 0.4, tz_z - tz_w / 2.0 + 0.3))
				pinnacle(Vector3(sx_v * (tz_len / 2.0 - 0.3), h + 0.4, tz_z + tz_w / 2.0 - 0.3))

	# ---------- apse ----------
	tag("apse")
	if spec.apse:
		# Apse springs FROM the east wall: flat face sits APSE_EMBED inside the
		# nave, dome bulges outward. half_cylinder() sweeps a in [0, PI], so the
		# drum occupies z in [cy, cy + radius] with its flat face AT cy. cy is
		# therefore the springing plane itself, not a full cylinder's centre.
		var cy: float = ChurchGeometry.apse_springing_z(spec)
		var adrum: AABB = ChurchGeometry.apse_aabb(spec)
		_log_part("apse", adrum.position + adrum.size / 2.0, adrum.size)
		_log_mass("apse", adrum)
		half_cylinder(spec.apse_radius, h * ChurchGeometry.APSE_HEIGHT_RATIO,
			Vector2(0, cy), SURF_STONE)
		# The drum is a HALF cylinder, so its roof is a HALF cone: it must cover
		# z in [cy, cy + r] only. A full cone here would overhang the void west
		# of the drum -- which is exactly what hid the detached apse from the
		# voxel connectivity check.
		_half_cone_cap(Vector3(0, h * ChurchGeometry.APSE_HEIGHT_RATIO, cy),
			spec.apse_radius + ChurchGeometry.APSE_EAVE, spec.apse_radius * 0.9, SURF_ROOF)
		for a_v in [-0.6, 0.0, 0.6]:
			var a: float = a_v
			var dx: float = sin(a)
			var dz: float = cos(a)
			window(Vector3(dx * (spec.apse_radius + 0.02), h * 0.42, cy + dz * spec.apse_radius),
				a, 0.6, h * 0.25, spec.window_style)

	# ---------- west tower ----------
	tag("tower")
	for side_v in ChurchGeometry.west_tower_sides(spec):
		var side: float = side_v
		var tw: float = spec.tower_width
		var th: float = spec.tower_height
		# Towers abut the west wall: only EMBED m penetrates the nave so the
		# mass reads as joined, not swallowed. A pair flanks the nave axis.
		var lz: float = ChurchGeometry.tower_center_z(spec)
		var lx: float = ChurchGeometry.tower_center_x(spec, side)
		var mass_name: String = "tower"
		if spec.west_towers >= 2:
			mass_name = "tower_%s" % ("left" if side < 0.0 else "right")
		if spec.west_towers >= 2 and _cuts_west_portal():
			_west_tower_portal_shell(lx, lz, tw, th)
		else:
			box(Vector3(tw, th, tw), Vector3(lx, th / 2.0, lz), SURF_STONE)
		_log_mass(mass_name, ChurchGeometry.tower_aabb(spec, side))
		total_height = maxf(total_height, th)
		for side_i in range(4):
			var ang: float = PI / 2.0 * side_i
			var off := Vector3(sin(ang) * (tw / 2.0 + 0.02), 0, cos(ang) * (tw / 2.0 + 0.02))
			window(Vector3(lx + off.x, th - tw * 0.28, lz + off.z), ang,
				tw * 0.32, tw * 0.26, &"square")
		var rise: float = ChurchGeometry.tower_roof_rise(spec)
		match spec.tower_roof:
			&"spire":
				var sp: float = tw * spec.spire_pitch * ChurchGeometry.SPIRE_RISE_FACTOR
				_pyramid_roof(Vector3(lx, th, lz), tw + 0.5, sp, SURF_ROOF, true)
				pinnacle(Vector3(lx, th + sp, lz), ChurchGeometry.ornament_scale(spec))
			&"pyramid":
				_pyramid_roof(Vector3(lx, th, lz), tw + 0.5, rise, SURF_ROOF, false)
			&"belfry":
				_pyramid_roof(Vector3(lx, th, lz), tw + 0.5, rise, SURF_ROOF, false)
				for cx_v in [-1.0, 1.0]:
					for cz_v in [-1.0, 1.0]:
						box(Vector3(0.22, tw * 0.35, 0.22),
							Vector3(lx + cx_v * (tw / 2.0 - 0.15), th + tw * 0.17,
								lz + cz_v * (tw / 2.0 - 0.15)), SURF_STONE)
			_:
				box(Vector3(tw + 0.4, 0.3, tw + 0.4), Vector3(lx, th + 0.15, lz), SURF_TRIM)
		total_height = maxf(total_height, th + rise)

	# ---------- buttresses ----------
	tag("buttress")
	if spec.buttresses:
		var n: int = spec.buttress_count_per_side
		var bd: float = spec.buttress_depth
		# keep buttresses clear of the tower (west) and transept crossing (east)
		var bz0: float = -l / 2.0 + 0.8
		if spec.tower:
			bz0 = -l / 2.0 + TOWER_EMBED + spec.tower_width + 0.4
		var bz1: float = l / 2.0 - 0.8
		if spec.transept:
			bz1 = ChurchGeometry.transept_front_z(spec) - 0.6
		var span_bz: float = maxf(bz1 - bz0, 2.0)
		for side_v in [-1.0, 1.0]:
			for i in range(n):
				var bz: float = bz0 + span_bz / float(maxi(n - 1, 1)) * i
				box(Vector3(bd, h * 0.72, 0.5),
					Vector3(side_v * (w / 2.0 + bd / 2.0 - 0.05), h * 0.36, bz), SURF_STONE)
				box(Vector3(bd * 0.6, 0.3, 0.42),
					Vector3(side_v * (w / 2.0 + bd * 0.3 - 0.05), h * 0.72 + 0.15, bz), SURF_STONE)
		if spec.tower:
			var tw2: float = spec.tower_width
			var th2: float = spec.tower_height
			var lz2: float = -l / 2.0 + TOWER_EMBED - tw2 / 2.0
			for cx_v in [-1.0, 1.0]:
				for cz_v in [-1.0, 1.0]:
					box(Vector3(bd, th2 * 0.8, bd),
						Vector3(cx_v * (tw2 / 2.0 + bd / 2.0 - 0.05), th2 * 0.4,
							lz2 + cz_v * (tw2 / 2.0 + bd / 2.0 - 0.05)), SURF_STONE)

	# ---------- string course ----------
	tag("trim")
	if spec.string_course:
		box(Vector3(w + 0.35, 0.18, l + 0.35), Vector3(0, h * 0.62, 0), SURF_TRIM)
		if spec.tower:
			var lz3: float = -l / 2.0 + TOWER_EMBED - spec.tower_width / 2.0
			box(Vector3(spec.tower_width + 0.3, 0.18, spec.tower_width + 0.3),
				Vector3(0, h * 0.62, lz3), SURF_TRIM)

	# ---------- main door ----------
	tag("door")
	# Only a SINGLE axial tower carries the door out to its own west face. Twin
	# towers flank the axis, so that same offset left the door hanging in the
	# gap between them with no wall behind it at all.
	var door_h: float = minf(h * 0.32, 3.4)
	var door_z: float = _west_door_z()
	for opening in _west_door_openings():
		window(opening.pos, PI, opening.width, opening.height,
			opening.style, true, _cuts_west_portal())
	box(Vector3((w * 0.34 if spec.door_style == &"portal" else 2.4) + 0.7, 0.22, 0.14),
		Vector3(0, door_h + 0.35, door_z - 0.02), SURF_TRIM)

	# ---------- nave windows when there are no aisles ----------
	tag("window")
	if spec.aisles == 0:
		var nw2: int = int(l / 3.2)
		for i in range(nw2):
			var wz2: float = -l / 2.0 + l / float(nw2 + 1) * (i + 1)
			for sx_v in [-1.0, 1.0]:
				window(Vector3(sx_v * (w / 2.0 + 0.02), h * 0.58, wz2),
					sx_v * PI / 2.0, spec.window_w, spec.window_h, spec.window_style)

	# ---------- rose window ----------
	tag("facade")
	if spec.rose_window:
		# The west front is at -Z: that is where the door and the towers are.
		# The rose was at +l/2, i.e. the east end, buried against the apse.
		rose(Vector3(0, h * 0.68, -l / 2.0 - 0.02), PI)

	_build_narthex()
	_build_ambulatory_and_chapels()
	_build_flying_buttresses()
	_build_crossing_tower()
	_build_dome()
	preload("church_roofs.gd").emit(spec, _kit, mass_log, _roof_volumes)

	# The masons are finished; the parish moves in. The dressing is prop
	# PLACEMENTS rather than geometry, so it costs the mesh nothing and
	# ChurchAssembler is the only thing that ever loads a model.
	prop_log = ChurchFurnisher.dress(spec)

	return commit()


## The nave shell is split at its wall faces. Each masonry panel has measured
## thickness; its exposed ends become the jambs, head and sill of a real hole.
const NAVE_WALL_T := 0.36


func _cuts_clerestory() -> bool:
	return spec.style == &"gothic" and ChurchGeometry.has_clerestory(spec)


func _cuts_west_portal() -> bool:
	# A single axial tower or narthex owns a different exterior host wall.
	return spec.west_towers != 1 and not spec.narthex


func _west_door_z() -> float:
	if spec.tower and spec.west_towers == 1:
		return -spec.length / 2.0 + TOWER_EMBED - spec.tower_width - ChurchGeometry.OPENING_EPS
	return -spec.length / 2.0 - ChurchGeometry.OPENING_EPS


func _west_door_openings() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var door_h: float = minf(spec.height * 0.32, 3.4)
	var z: float = _west_door_z()
	match spec.door_style:
		&"twin":
			for x in [-0.8, 0.8]:
				out.append({"pos": Vector3(x, door_h / 2.0 + 0.1, z),
					"width": 0.85, "height": door_h, "style": &"round"})
		&"portal":
			out.append({"pos": Vector3(0, door_h / 2.0 + 0.05, z),
				"width": spec.width * 0.34, "height": door_h, "style": &"pointed"})
		_:
			out.append({"pos": Vector3(0, door_h / 2.0 + 0.1, z),
				"width": 1.4, "height": door_h, "style": &"round"})
	return out


func _nave_shell() -> void:
	var w: float = spec.width
	var h: float = spec.height
	var l: float = spec.length
	if not _cuts_clerestory() and not _cuts_west_portal():
		box(Vector3(w, h, l), Vector3(0, h / 2.0, 0), SURF_STONE)
		return
	var clerestory: Array[Dictionary] = []
	if _cuts_clerestory():
		clerestory = ChurchGeometry.clerestory_windows(spec)
	for side in [-1.0, 1.0]:
		var holes: Array[Dictionary] = []
		for opening in clerestory:
			if signf(opening.pos.x) != side:
				continue
			holes.append({"u": opening.pos.z, "width": opening.width,
				"bottom": opening.pos.y - opening.height / 2.0,
				"top": opening.pos.y + opening.height / 2.0})
		_nave_wall_run(-l / 2.0, l / 2.0, h, holes, side, false)
	var doors: Array[Dictionary] = []
	if _cuts_west_portal():
		for opening in _west_door_openings():
			doors.append({"u": opening.pos.x, "width": opening.width,
				"bottom": opening.pos.y - opening.height / 2.0,
				"top": opening.pos.y + opening.height / 2.0})
	_nave_wall_run(-w / 2.0, w / 2.0, h, doors, 0.0, true)
	box(Vector3(w, h, NAVE_WALL_T),
		Vector3(0, h / 2.0, l / 2.0 - NAVE_WALL_T / 2.0), SURF_STONE)
	var st: SurfaceTool = _kit.surface(SURF_STONE)
	_nave_plane(st, Vector3(-w / 2.0, 0, -l / 2.0),
		Vector3(w / 2.0, 0, -l / 2.0), Vector3(w / 2.0, 0, l / 2.0),
		Vector3(-w / 2.0, 0, l / 2.0), Vector3.DOWN)
	_nave_plane(st, Vector3(-w / 2.0, h, -l / 2.0),
		Vector3(w / 2.0, h, -l / 2.0), Vector3(w / 2.0, h, l / 2.0),
		Vector3(-w / 2.0, h, l / 2.0), Vector3.UP)


func _nave_wall_run(u_min: float, u_max: float, wall_h: float,
		holes: Array[Dictionary], side: float, west: bool) -> void:
	holes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["u"]) < float(b["u"]))
	var cursor: float = u_min
	for opening in holes:
		var lo: float = maxf(u_min, float(opening["u"]) - float(opening["width"]) / 2.0)
		var hi: float = minf(u_max, float(opening["u"]) + float(opening["width"]) / 2.0)
		if hi <= lo or lo < cursor - 0.001:
			continue
		_nave_wall_piece(cursor, lo, 0.0, wall_h, side, west)
		var bottom: float = clampf(float(opening["bottom"]), 0.0, wall_h)
		var top: float = clampf(float(opening["top"]), 0.0, wall_h)
		_nave_wall_piece(lo, hi, 0.0, bottom, side, west)
		_nave_wall_piece(lo, hi, top, wall_h, side, west)
		cursor = hi
	_nave_wall_piece(cursor, u_max, 0.0, wall_h, side, west)


func _nave_wall_piece(u0: float, u1: float, y0: float, y1: float,
		side: float, west: bool) -> void:
	if u1 - u0 <= 0.001 or y1 - y0 <= 0.001:
		return
	var middle: float = (u0 + u1) / 2.0
	var y: float = (y0 + y1) / 2.0
	if west:
		box(Vector3(u1 - u0, y1 - y0, NAVE_WALL_T),
			Vector3(middle, y, -spec.length / 2.0 + NAVE_WALL_T / 2.0), SURF_STONE)
	else:
		box(Vector3(NAVE_WALL_T, y1 - y0, u1 - u0),
			Vector3(side * (spec.width / 2.0 - NAVE_WALL_T / 2.0),
				y, middle), SURF_STONE)


func _nave_plane(st: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3, normal: Vector3) -> void:
	if (c - a).cross(b - a).dot(normal) < 0.0:
		_kit._tri(st, a, d, c)
		_kit._tri(st, a, c, b)
	else:
		_kit._tri(st, a, b, c)
		_kit._tri(st, a, c, d)


## Twin towers straddle the west entrance. Their front and rear faces both
## cross the doorway route; cutting only the nave leaves a walled-in portal.
func _west_tower_portal_shell(cx: float, cz: float, width: float, height: float) -> void:
	var x0: float = cx - width / 2.0
	var x1: float = cx + width / 2.0
	var z0: float = cz - width / 2.0
	var z1: float = cz + width / 2.0
	var holes: Array[Dictionary] = []
	for opening in _west_door_openings():
		var lo: float = maxf(x0, opening.pos.x - opening.width / 2.0)
		var hi: float = minf(x1, opening.pos.x + opening.width / 2.0)
		if hi <= lo:
			continue
		holes.append({"u": (lo + hi) / 2.0, "width": hi - lo,
			"bottom": opening.pos.y - opening.height / 2.0,
			"top": opening.pos.y + opening.height / 2.0})
	_tower_portal_wall(x0, x1, height, holes.duplicate(true), z0, true)
	_tower_portal_wall(x0, x1, height, holes, z1, false)
	_tower_portal_side(x0, x0 + NAVE_WALL_T, cz, width, height, holes)
	_tower_portal_side(x1 - NAVE_WALL_T, x1, cz, width, height, holes)
	var st: SurfaceTool = _kit.surface(SURF_STONE)
	_nave_plane(st, Vector3(x0, 0, z0), Vector3(x1, 0, z0),
		Vector3(x1, 0, z1), Vector3(x0, 0, z1), Vector3.DOWN)
	_nave_plane(st, Vector3(x0, height, z0), Vector3(x1, height, z0),
		Vector3(x1, height, z1), Vector3(x0, height, z1), Vector3.UP)


func _tower_portal_side(x0: float, x1: float, cz: float, width: float,
		height: float, holes: Array[Dictionary]) -> void:
	holes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["u"]) < float(b["u"]))
	var cursor: float = x0
	for opening in holes:
		var lo: float = maxf(x0,
			float(opening["u"]) - float(opening["width"]) / 2.0)
		var hi: float = minf(x1,
			float(opening["u"]) + float(opening["width"]) / 2.0)
		if hi <= lo or lo < cursor - 0.001:
			continue
		_tower_portal_side_piece(cursor, lo, 0.0, height, cz, width)
		var bottom: float = clampf(float(opening["bottom"]), 0.0, height)
		var top: float = clampf(float(opening["top"]), 0.0, height)
		_tower_portal_side_piece(lo, hi, 0.0, bottom, cz, width)
		_tower_portal_side_piece(lo, hi, top, height, cz, width)
		cursor = hi
	_tower_portal_side_piece(cursor, x1, 0.0, height, cz, width)


func _tower_portal_side_piece(x0: float, x1: float, y0: float, y1: float,
		cz: float, width: float) -> void:
	if x1 - x0 <= 0.001 or y1 - y0 <= 0.001:
		return
	box(Vector3(x1 - x0, y1 - y0, width),
		Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, cz), SURF_STONE)


func _tower_portal_wall(x0: float, x1: float, height: float,
		holes: Array[Dictionary], z_face: float, front: bool) -> void:
	holes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["u"]) < float(b["u"]))
	var cursor: float = x0
	for opening in holes:
		var lo: float = float(opening["u"]) - float(opening["width"]) / 2.0
		var hi: float = float(opening["u"]) + float(opening["width"]) / 2.0
		if hi <= lo or lo < cursor - 0.001:
			continue
		_tower_portal_piece(cursor, lo, 0.0, height, z_face, front)
		var bottom: float = clampf(float(opening["bottom"]), 0.0, height)
		var top: float = clampf(float(opening["top"]), 0.0, height)
		_tower_portal_piece(lo, hi, 0.0, bottom, z_face, front)
		_tower_portal_piece(lo, hi, top, height, z_face, front)
		cursor = hi
	_tower_portal_piece(cursor, x1, 0.0, height, z_face, front)


func _tower_portal_piece(x0: float, x1: float, y0: float, y1: float,
		z_face: float, front: bool) -> void:
	if x1 - x0 <= 0.001 or y1 - y0 <= 0.001:
		return
	box(Vector3(x1 - x0, y1 - y0, NAVE_WALL_T),
		Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0,
			z_face + (NAVE_WALL_T / 2.0 if front else -NAVE_WALL_T / 2.0)),
		SURF_STONE)


## Entrance vestibule across the west front.
func _build_narthex() -> void:
	if not spec.narthex:
		return
	tag("narthex")
	var a: AABB = ChurchGeometry.narthex_aabb(spec)
	var c: Vector3 = a.position + a.size / 2.0
	box(a.size, Vector3(c.x, a.size.y / 2.0, c.z), SURF_STONE)
	_log_mass("narthex", a)
	window(Vector3(0, a.size.y * 0.42, a.position.z - ChurchGeometry.OPENING_EPS),
		PI, 1.6, a.size.y * 0.5, spec.window_style, true)


## The ambulatory carries the aisle around the apse; radiating chapels are the
## alcoves that open off it. Chartres has seven, Notre-Dame a full ring.
func _build_ambulatory_and_chapels() -> void:
	if not spec.apse and spec.radiating_chapels <= 0:
		return
	var cy: float = ChurchGeometry.apse_springing_z(spec)
	if spec.ambulatory and spec.apse:
		tag("ambulatory")
		var ar: float = ChurchGeometry.ambulatory_radius(spec)
		var ah: float = spec.height * ChurchGeometry.AISLE_HEIGHT_RATIO
		half_cylinder(ar, ah, Vector2(0, cy), SURF_STONE)
		_log_mass("ambulatory", ChurchGeometry.ambulatory_aabb(spec))
		_half_cone_cap(Vector3(0, ah, cy), ar + ChurchGeometry.APSE_EAVE,
			ar * 0.55, SURF_ROOF)
	if spec.radiating_chapels <= 0:
		return
	tag("chapel")
	var chr_r: float = spec.chapel_radius
	var chh: float = spec.height * 0.42
	for i in range(spec.radiating_chapels):
		var c: Vector3 = ChurchGeometry.chapel_center(spec, i)
		var a: float = ChurchGeometry.chapel_angle(spec, i)
		# each alcove is a little apse in its own right, facing outward
		_kit.revolve(PackedVector2Array([Vector2(chr_r, 0.0), Vector2(chr_r, chh)]),
			Vector3(c.x, 0.0, c.z), SURF_STONE, 8, PI,
			ChurchGeometry.chapel_arc_start(spec, i))
		_log_mass("chapel_%d" % i, ChurchGeometry.chapel_aabb(spec, i))
		_kit.stepped_taper(Vector3(c.x, chh, c.z), chr_r * 2.0 + 0.2, chr_r * 0.6,
			SURF_ROOF, 3, 0.15, true, 0.0, 0.8)
		window(Vector3(c.x + sin(a) * (chr_r + ChurchGeometry.OPENING_EPS), chh * 0.45,
			c.z + cos(a) * (chr_r + ChurchGeometry.OPENING_EPS)), a,
			0.6, chh * 0.4, spec.window_style)


## Flying buttress: an outer pier, an arch springing from it to the clerestory
## wall, and a pinnacle weighting the pier. The Gothic signature.
func _build_flying_buttresses() -> void:
	if not spec.flying_buttresses:
		return
	tag("flyer")
	var pw: float = ChurchGeometry.flyer_pier_width(spec)
	var ph: float = ChurchGeometry.flyer_pier_height(spec)
	var arch_t: float = ChurchGeometry.flyer_arch_thickness(spec)
	var orn: float = ChurchGeometry.ornament_scale(spec)
	var spring: float = ChurchGeometry.flyer_spring_height(spec)
	var n: int = ChurchGeometry.flyer_count(spec)
	for side_v in [-1.0, 1.0]:
		var side: float = side_v
		var px: float = ChurchGeometry.flyer_pier_x(spec, side)
		var wall_x: float = side * (spec.width / 2.0)
		for i in range(n):
			var pz: float = ChurchGeometry.flyer_z(spec, i)
			box(Vector3(pw, ph, pw), Vector3(px, ph / 2.0, pz), SURF_STONE)
			_log_mass("flyer_pier_%s_%d" % ["left" if side < 0.0 else "right", i],
				AABB(Vector3(px - pw / 2.0, 0.0, pz - pw / 2.0), Vector3(pw, ph, pw)))
			pinnacle(Vector3(px, ph, pz), orn)
			# one flyer per tier, each springing higher up the nave wall
			for tier in range(spec.flyer_tiers):
				# each lower tier drops by a full share of the wall height, so
				# stacked flyers stay visibly clear of one another
				var drop: float = tier * ChurchGeometry.flyer_tier_drop(spec)
				var from_y: float = ph - drop
				var to_y: float = spring - drop
				var bow: float = absf(px - wall_x) * 0.16
				_kit.arc_ribbon(Vector3(px, from_y, pz), Vector3(wall_x, to_y, pz),
					bow, arch_t, pw * 0.72, SURF_STONE)
				# The arch is what ties an otherwise free-standing pier to the
				# nave, so it counts as a mass: without it the pier reads as
				# floating, which is exactly what a flyer is meant to avoid.
				var x0: float = minf(px, wall_x)
				var y0: float = minf(from_y, to_y) - arch_t
				var y1: float = maxf(from_y, to_y) + bow + arch_t
				_log_mass("flyer_arch_%s_%d_%d"
					% ["left" if side < 0.0 else "right", i, tier],
					AABB(Vector3(x0, y0, pz - pw * 0.36),
						Vector3(absf(px - wall_x), y1 - y0, pw * 0.72)))


## A lantern tower over the crossing: the silhouette of Durham and Salisbury.
func _build_crossing_tower() -> void:
	if not spec.crossing_tower:
		return
	tag("crossing_tower")
	var a: AABB = ChurchGeometry.crossing_tower_aabb(spec)
	var side: float = a.size.x
	var cz: float = ChurchGeometry.crossing_center_z(spec)
	var th: float = spec.crossing_tower_height
	# the tower stands on the crossing BAY, so its plan is span x depth --
	# emitting a square here made the mesh overhang its own logged mass
	box(Vector3(side, th, a.size.z), Vector3(0, th / 2.0, cz), SURF_STONE)
	_log_mass("crossing_tower", a)
	total_height = maxf(total_height, th)
	for face in range(4):
		var ang: float = PI / 2.0 * face
		window(Vector3(sin(ang) * (side / 2.0 + ChurchGeometry.OPENING_EPS),
			th - side * 0.22,
			cz + cos(ang) * (a.size.z / 2.0 + ChurchGeometry.OPENING_EPS)),
			ang, side * 0.22, side * 0.3, spec.window_style)
	var bay: float = a.size.z
	_kit.hip_roof(side + 0.4, bay + 0.4, side * 0.42, cz, SURF_ROOF, th)
	for cx_v in [-1.0, 1.0]:
		for cz_v in [-1.0, 1.0]:
			pinnacle(Vector3(cx_v * (side / 2.0 - 0.4), th, cz + cz_v * (bay / 2.0 - 0.4)),
				ChurchGeometry.ornament_scale(spec))


## Dome on a drum over the crossing. Hemispherical (Hagia Sophia), onion
## (St Basil), or carried on an octagonal drum (Florence).
func _build_dome() -> void:
	if not spec.dome or spec.dome_radius <= 0.0:
		return
	tag("dome")
	var r: float = spec.dome_radius
	var cz: float = ChurchGeometry.crossing_center_z(spec)
	var base: float = ChurchGeometry.dome_base_height(spec)
	var drum_h: float = spec.dome_drum_height
	var octagonal: bool = spec.dome_shape == &"octagonal"

	# pendentives: the square-to-round transition the drum sits on
	box(Vector3(r * 2.0 + 0.6, ChurchGeometry.PENDENTIVE_H, r * 2.0 + 0.6),
		Vector3(0, base + ChurchGeometry.PENDENTIVE_H / 2.0, cz), SURF_TRIM)
	_log_mass("pendentive", ChurchGeometry.pendentive_aabb(spec))
	if octagonal:
		_kit.prism(r * ChurchGeometry.OCTAGONAL_RADIUS_FACTOR, drum_h, 8,
			Vector3(0, base + ChurchGeometry.PENDENTIVE_H, cz), SURF_STONE, PI / 8.0)
	else:
		_kit.prism(r, drum_h, 16, Vector3(0, base + ChurchGeometry.PENDENTIVE_H, cz), SURF_STONE)
	_log_mass("dome_drum", ChurchGeometry.dome_drum_aabb(spec))

	# the corona of windows that lights every one of these domes
	var lights: int = 8 if octagonal else 12
	for i in range(lights):
		var a: float = TAU / lights * i
		window(Vector3(sin(a) * (r + ChurchGeometry.OPENING_EPS), base + drum_h * 0.55,
			cz + cos(a) * (r + ChurchGeometry.OPENING_EPS)), a,
			r * 0.16, drum_h * 0.45, &"round")

	var top: float = base + ChurchGeometry.PENDENTIVE_H + drum_h
	var rise: float = ChurchGeometry.dome_shell_rise(spec)
	var segs: int = 8 if octagonal else 16
	# The octagonal drum uses a circumradius of 1.06r. Its shell must spring
	# from that same ring; using r left an open slot around all eight sides.
	preload("church_roofs.gd").dome(_kit, _dome_profile(
		r * (ChurchGeometry.OCTAGONAL_RADIUS_FACTOR if octagonal else 1.0), rise),
		Vector3(0, top, cz), segs, _roof_volumes, TAU, PI / 8.0 if octagonal else 0.0)
	total_height = maxf(total_height, top + rise)

	if spec.dome_lantern:
		var lh: float = r * ChurchGeometry.LANTERN_RATIO
		_kit.prism(r * 0.16, lh, 8, Vector3(0, top + rise, cz), SURF_STONE)
		_kit.stepped_taper(Vector3(0, top + rise + lh, cz), r * 0.34,
			r * ChurchGeometry.LANTERN_CAP_RATIO, SURF_ROOF, 3, 0.1)
		total_height = maxf(total_height, top + rise + lh)

	# Hagia Sophia braces its dome with half-domes east and west, themselves
	# carried on smaller semi-domed exedrae.
	if spec.half_domes:
		var hr: float = ChurchGeometry.half_dome_radius(spec)
		for dir_v in [-1.0, 1.0]:
			var d: float = dir_v
			var start: float = 0.0 if d > 0.0 else PI
			preload("church_roofs.gd").dome(_kit, _dome_profile(hr, hr * 0.85),
				Vector3(0, base, cz), 10, _roof_volumes, PI, start)
			if spec.exedrae:
				for ex_v in [-1.0, 1.0]:
					var er: float = hr * 0.4
					var ec := Vector3(ex_v * hr * 0.5, base * 0.55, cz + d * hr * 0.62)
					_kit.revolve(PackedVector2Array([Vector2(er, 0.0),
						Vector2(er, base * 0.3)]), ec, SURF_STONE, 8, PI, start)
					_kit.revolve(_dome_profile(er, er * 0.8),
						ec + Vector3(0, base * 0.3, 0), SURF_ROOF, 8, PI, start)


## Profile of a dome shell, bottom to top: hemispherical, or the ogee curve
## that gives an onion dome its shoulder and point.
func _dome_profile(radius: float, rise: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if spec.dome_shape == &"onion":
		# bulges past the springing radius, then draws in to a point
		var ogee := [Vector2(1.0, 0.0), Vector2(1.14, 0.24), Vector2(1.05, 0.46),
			Vector2(0.78, 0.68), Vector2(0.42, 0.86), Vector2(0.0, 1.0)]
		for v in ogee:
			pts.append(Vector2(radius * v.x, rise * v.y))
		return pts
	var steps: int = 6
	for i in range(steps + 1):
		var t: float = float(i) / steps
		pts.append(Vector2(radius * cos(t * PI / 2.0), rise * sin(t * PI / 2.0)))
	return pts

# ---------------------------------------------------------------- primitives

## Gable capping a wall whose top is at y_base.
func gable_roof(span_x: float, along_z: float, rise: float, z_center: float, s: int,
		y_base := 0.0, end_span := 0.0, end_along := 0.0) -> void:
	_kit.gable_roof(span_x, along_z, rise, z_center, s, y_base,
		SURF_STONE if end_span > 0.0 else -1, end_span, end_along)

## Lean-to aisle roof, outer eave at y_base up to y_top against the nave wall.
func _lean_roof(span: float, along: float, y_base: float, y_top: float, side: float,
		s: int, zc := 0.0) -> void:
	_kit.lean_roof(span, along, y_base, y_top, side, s, zc)

## Apse drum: flat face at center.y (model Z), bulging to center.y + radius.
func half_cylinder(radius: float, height: float, center: Vector2, s: int) -> void:
	_kit.half_cylinder(radius, height, center, s)

## Conical cap over a HALF cylinder: covers z in [pos.z, pos.z + radius] only,
## so nothing overhangs the void west of the drum's flat face.
func _half_cone_cap(pos: Vector3, radius: float, height: float, s: int) -> void:
	# Match the drum's ten-sided semicircle. Stacked half-boxes left its
	# curved shoulders uncovered and put square corners out in empty air.
	for i in range(10):
		var a := PI * float(i) / 10.0
		var b := PI * float(i + 1) / 10.0
		_kit.slab_poly(PackedVector3Array([pos + Vector3(cos(a) * radius, 0, sin(a) * radius),
			pos + Vector3(cos(b) * radius, 0, sin(b) * radius), pos + Vector3(0, height, 0)]),
			RoofShape.DEPTH, s, true)

func _pyramid_roof(base_center: Vector3, width: float, height: float, s: int,
		tall := false) -> void:
	_kit.stepped_taper(base_center, width, height, s, 5 if tall else 3, 0.2)

## `sc` scales the whole finial: a 1.8 m pinnacle is invisible on a cathedral.
func pinnacle(pos: Vector3, sc := 1.0) -> void:
	box(Vector3(0.35 * sc, 1.2 * sc, 0.35 * sc), pos + Vector3(0, 0.6 * sc, 0), SURF_STONE)
	box(Vector3(0.55 * sc, 0.16 * sc, 0.55 * sc), pos + Vector3(0, 0.08 * sc, 0), SURF_TRIM)
	_pyramid_roof(pos + Vector3(0, 1.2 * sc, 0), 0.4 * sc, 0.6 * sc, SURF_ROOF, false)

# ---------------------------------------------------------------- openings

func _build_clerestory() -> void:
	tag("clerestory")
	for opening in ChurchGeometry.clerestory_windows(spec):
		var pos: Vector3 = opening.pos
		var width: float = opening.width
		var height: float = opening.height
		window(pos, opening.face, width, height, spec.window_style, false,
			_cuts_clerestory())
		# A slender mullion and pale sill make the tall glazing read as a
		# deliberate course, while leaving the main silhouette quiet.
		var xf := Transform3D(Basis(Vector3.UP, opening.face), pos)
		var mullion: float = clampf(width * 0.06, 0.055, 0.16)
		host("clerestory_%d" % part_log.size())
		if _cuts_clerestory():
			# Set the dark pane at the inner lip. The ray fixture probes stone,
			# so glazing cannot disguise an uncut masonry host.
			component_box("clerestory_pane",
				Vector3(width - 0.08, height - 0.08, 0.025),
				xf.translated_local(Vector3(0, 0, -NAVE_WALL_T + 0.035)), SURF_OPEN)
		component_box("clerestory_mullion", Vector3(mullion, height, 0.09),
			xf.translated_local(Vector3(0, 0, 0.03)), SURF_TRIM)
		component_box("clerestory_sill", Vector3(width + mullion * 3, mullion, 0.18),
			xf.translated_local(Vector3(0, -height / 2.0, 0.02)), SURF_TRIM)
		host_end()

## Dark recessed opening facing local +Z, rotated by `face` around Y.
func window(pos: Vector3, face: float, w: float, h: float, style: StringName,
		door := false, through := false) -> void:
	# Facing is logged so the normals suite can prove the opening looks OUT of
	# the wall. Windows on the +/-X walls were once all given face = 0, which
	# stood them edge-on to the wall like panels bolted across it.
	_log_part("window", pos, Vector3(w, h, 0.0), face,
		Basis(Vector3.UP, face) * Vector3(0, 0, 1))
	if through:
		part_log.back()["aperture"] = "through"
		return # the host wall owns the open throat and its stone returns
	var depth: float = 0.16 if door else 0.1
	# `pos` is the wall face. The recess box is centred, so it has to be pushed
	# half its depth INTO the wall -- left on `pos` it read as a panel glued to
	# the outside instead of an opening cut into it.
	var t := Transform3D(Basis(Vector3.UP, face), pos)
	var t_in: Transform3D = t.translated_local(Vector3(0, 0, -depth / 2.0))
	var st: SurfaceTool = _kit.surface(SURF_OPEN)
	_kit.oriented_box(Vector3(w, h, depth), t_in, SURF_OPEN)
	# Heads are drawn on the face plane. Two things were wrong with every one of
	# them: the normal was the LOCAL +Z written straight out as a world vector,
	# so a rotated window lit as though it faced down the nave, and the fan was
	# wound counter-clockwise -- back-facing, so Godot culled it outright.
	var face_n: Vector3 = t.basis * Vector3(0, 0, 1)
	if style == &"pointed":
		# The apex sat at 0.35h, BELOW the opening's own top edge at 0.5h, so the
		# "pointed" head pointed down into the glass.
		var apex := Vector3(0, h / 2.0 + w * 0.35, 0)
		var bl := Vector3(-w / 2.0, h / 2.0, 0)
		var br := Vector3(w / 2.0, h / 2.0, 0)
		for p in [bl, apex, br]:
			st.set_normal(face_n)
			st.set_uv(Vector2(0.5, 0.5))
			st.add_vertex(t * p)
	elif style == &"round":
		var seg: int = 5
		var rr: float = w * 0.5
		for i in range(seg):
			var a0: float = TAU / seg * i
			var a1: float = TAU / seg * (i + 1)
			var c := Vector3(0, h / 2.0, 0)
			var p0 := Vector3(cos(a0) * rr, h / 2.0 + sin(a0) * rr * 0.5, 0)
			var p1 := Vector3(cos(a1) * rr, h / 2.0 + sin(a1) * rr * 0.5, 0)
			for p in [c, p1, p0]:
				st.set_normal(face_n)
				st.set_uv(Vector2(0.5, 0.5))
				st.add_vertex(t * p)
	if not door:
		var ft: float = 0.12
		_kit.oriented_box(Vector3(w + ft * 2, ft, depth + 0.04),
			t_in.translated_local(Vector3(0, h / 2.0 + ft / 2.0, 0)), SURF_OPEN)
		_kit.oriented_box(Vector3(ft, h, depth + 0.04),
			t_in.translated_local(Vector3(-w / 2.0 - ft / 2.0, 0, 0)), SURF_OPEN)
		_kit.oriented_box(Vector3(ft, h, depth + 0.04),
			t_in.translated_local(Vector3(w / 2.0 + ft / 2.0, 0, 0)), SURF_OPEN)

func rose(pos: Vector3, face := 0.0) -> void:
	var basis := Basis(Vector3.UP, face)
	_log_part("window", pos, Vector3.ZERO, face, basis * Vector3(0, 0, 1))
	var t := Transform3D(basis, pos)
	var st: SurfaceTool = _kit.surface(SURF_OPEN)
	var rr: float = minf(spec.width * 0.18, 1.6)
	var seg: int = 12
	for i in range(seg):
		var a0: float = TAU / seg * i
		var a1: float = TAU / seg * (i + 1)
		var c := Vector3.ZERO
		var p0 := Vector3(cos(a0) * rr, sin(a0) * rr, 0)
		var p1 := Vector3(cos(a1) * rr, sin(a1) * rr, 0)
		for p in [c, p1, p0]:
			st.set_normal(basis * Vector3(0, 0, 1))
			st.set_uv(Vector2(0.5, 0.5))
			st.add_vertex(t * p)
	# tracery spokes. These previously pushed 8 raw box corners straight into a
	# triangle list -- not a multiple of 3, so the spokes were malformed.
	for i in range(seg):
		var a: float = TAU / seg * i
		var bx: Transform3D = t * Transform3D(Basis(Vector3(0, 0, 1), a),
			Vector3(cos(a) * rr * 0.5, sin(a) * rr * 0.5, -0.03))
		_kit.oriented_box(Vector3(rr * 0.55, 0.09, 0.08), bx, SURF_TRIM)
