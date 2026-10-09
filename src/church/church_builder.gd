class_name ChurchBuilder
extends MassBuilder
## ChurchSpec -> ArrayMesh. Massing-first: nave box, optional aisles, transept,
## apse (half-cylinder), west tower + roof, then window/door/trim detailing.
##
## Surfaces: 0 = stone/plinth, 1 = trim, 2 = roof, 3 = openings,
##           4 = painted domes, 5 = Nordic stave timber.

const SURF_STONE := 0
const SURF_TRIM := 1
const SURF_ROOF := 2
const SURF_OPEN := 3
const SURF_ACCENT := 4
const SURF_WOOD := 5

## How far attached masses penetrate the host wall, so they read as joined
## rather than floating beside it or swallowing the nave.
## Joint depths live in ChurchGeometry so the blueprint reads the same values.
const TOWER_EMBED := ChurchGeometry.TOWER_EMBED
const APSE_EMBED := ChurchGeometry.APSE_EMBED
const PENDENTIVE_PROFILE_STEPS := 6
const PENDENTIVE_LEDGE_ROWS := [2, 4, 5]
const PENDENTIVE_LEDGE_WIDTH := 0.22
const PENDENTIVE_LEDGE_RISE := 0.06
const PODIUM_STEP_INSET := 1.0
## The painted onions of St Basil's: gold, green, blue, red, cream, orange,
## teal and violet, in the order the chapels take them.
const BASIL_COLOURS: Array[Color] = [Color("c9a227"), Color("2f7d57"),
	Color("2d5fa8"), Color("b7352b"), Color("e8e0c8"), Color("d98a2b"),
	Color("3f8f8a"), Color("8e3d8f")]

var spec: ChurchSpec
var _roof_volumes: Array[PackedVector3Array] = []

func build(p_spec: ChurchSpec) -> ArrayMesh:
	spec = p_spec
	begin_metric(6)
	_roof_volumes.clear()

	var w: float = spec.width
	var l: float = spec.length
	var h: float = spec.height

	total_height = h

	# ---------- nave ----------
	tag("nave")
	_nave_shell()
	_build_nave_structure()
	_build_apse_entrance_arch()
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
				var aisle: AABB = ChurchGeometry.aisle_aabb(spec, side, ring)
				var aisle_windows: Array[Dictionary] = []
				if ring == spec.aisles - 1 and ChurchGeometry.hero_bays(spec):
					for bay_window in ChurchGeometry.hero_aisle_windows(spec):
						aisle_windows.append({"face": 1 if side > 0.0 else 3,
							"u": bay_window.z, "y": bay_window.y,
							"width": bay_window.width, "height": bay_window.height,
							"style": spec.window_style})
				elif ring == spec.aisles - 1:
					var nwin: int = int(al / 3.0)
					for i in range(nwin):
						var wz: float = az0 + al / float(nwin + 1) * (i + 1)
						aisle_windows.append({"face": 1 if side > 0.0 else 3,
							"u": wz, "y": ah * 0.5, "width": 0.7,
							"height": ah * 0.33, "style": spec.window_style})
				_windowed_box_shell(aisle, aisle_windows, true, false)
				_log_mass("aisle_%s_%d" % ["left" if side < 0.0 else "right", ring],
					aisle)
				# Only the OUTERMOST ring gets side windows. Every ring used to,
				# so on a double-aisled church the inner ring's windows were cut
				# into a wall the outer ring stands hard against -- glazing that
				# looks into the next aisle's masonry.
	_build_clerestory()

	# ---------- transept ----------
	tag("transept")
	if spec.transept:
		var tz_len: float = spec.transept_len
		var tz_w: float = ChurchGeometry.transept_depth(spec)
		var tz_z: float = ChurchGeometry.transept_center_z(spec)
		var transept: AABB = ChurchGeometry.transept_aabb(spec)
		var transept_windows: Array[Dictionary] = []
		var crossing_arch := _crossing_arch_profile()
		var crossing_opening_w: float = float(crossing_arch["half_span"]) * 2.0
		var crossing_spring: float = float(crossing_arch["spring_y"])
		var crossing_peak: float = float(crossing_arch["peak_y"])
		for face in [0, 2]:
			transept_windows.append({"face": face, "u": 0.0,
				"y": crossing_peak * 0.5, "width": crossing_opening_w,
				"height": crossing_peak, "spring_y": crossing_spring,
				"arch": crossing_arch["kind"], "style": &"pointed", "door": true, "log": true})
		for sx_v in [-1.0, 1.0]:
			transept_windows.append({"face": 1 if sx_v > 0.0 else 3,
				"u": tz_z, "y": h * 0.55, "width": spec.window_w,
				"height": spec.window_h, "style": spec.window_style})
		_windowed_box_shell(transept, transept_windows, true, false)
		_log_mass("transept", transept)
		_build_nave_arch(tz_z - tz_w * 0.5 + NAVE_WALL_T * 0.5, crossing_spring,
			clampf(spec.width * 0.04, 0.28, 0.48),
			clampf(spec.width * 0.045, 0.32, 0.58), false, crossing_arch)
		_build_nave_arch(tz_z + tz_w * 0.5 - NAVE_WALL_T * 0.5, crossing_spring,
			clampf(spec.width * 0.04, 0.28, 0.48),
			clampf(spec.width * 0.045, 0.32, 0.58), false, crossing_arch)
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
		# An ambulatory covers the lower drum. Put its apse lights above that
		# roof, where they can actually be seen from outside.
		var apse_light_y: float = h * (0.75 if spec.ambulatory else 0.42)
		var apse_light_h: float = h * (0.16 if spec.ambulatory else 0.25)
		_arc_window_shell(Vector3(0, 0, cy), spec.apse_radius,
			h * ChurchGeometry.APSE_HEIGHT_RATIO, 11, PI, 0.0,
			[-0.6, 0.0, 0.6], 0.6, apse_light_h,
			apse_light_y, spec.window_style, false, true)
		# The drum is a HALF cylinder, so its roof is a HALF cone: it must cover
		# z in [cy, cy + r] only. A full cone here would overhang the void west
		# of the drum -- which is exactly what hid the detached apse from the
		# voxel connectivity check.
		_half_cone_cap(Vector3(0, h * ChurchGeometry.APSE_HEIGHT_RATIO, cy),
			spec.apse_radius + ChurchGeometry.APSE_EAVE, spec.apse_radius * 0.9, SURF_ROOF)

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
		var tower_windows := _tower_openings(lx, lz, tw, th)
		_windowed_box_shell(ChurchGeometry.tower_aabb(spec, side), tower_windows, true, false)
		_log_mass(mass_name, ChurchGeometry.tower_aabb(spec, side))
		total_height = maxf(total_height, th)
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
		for side_v in [-1.0, 1.0]:
			for i in range(n):
				var bz: float = ChurchGeometry.nave_buttress_z(spec, i, n)
				_stepped_buttress("nave_%s_%d" % ["left" if side_v < 0.0 else "right", i],
					Vector3(side_v * w / 2.0, 0.0, bz), Vector3(side_v, 0.0, 0.0),
					h * 0.72, bd, ChurchGeometry.BUTTRESS_FACE, false)
		if spec.tower:
			var tw2: float = spec.tower_width
			var th2: float = spec.tower_height
			# A corner buttress may not stand in the way in, inside the nave
			# the tower is embedded in, or on its twin's buttress. Twin towers
			# 0.6 m apart put two of them, overlapping, on the axis in front of
			# the portal (walk-QA, Wolfmarch Green pin 14) and two more inside
			# the nave behind it.
			var keep_out: Array[Rect2] = []
			for door in ChurchGeometry.west_door_layout(spec):
				var half_w: float = float(door.width) * 0.5 + 0.3
				keep_out.append(Rect2(float(door.x) - half_w, -l * 2.0, half_w * 2.0, l * 4.0))
			keep_out.append(Rect2(-w / 2.0 + NAVE_WALL_T, -l / 2.0 + NAVE_WALL_T,
				w - NAVE_WALL_T * 2.0, l - NAVE_WALL_T))
			var feet: Array[Rect2] = []
			var names: Array[String] = []
			var rows: Array = []
			for tower_side in ChurchGeometry.west_tower_sides(spec):
				var tx: float = ChurchGeometry.tower_center_x(spec, tower_side)
				var tz: float = ChurchGeometry.tower_center_z(spec)
				for cx_v in [-1.0, 1.0]:
					for cz_v in [-1.0, 1.0]:
						var corner := Vector2(tx + cx_v * tw2 / 2.0, tz + cz_v * tw2 / 2.0)
						var foot := Rect2(corner + Vector2(cx_v, cz_v) * bd * 0.5 - Vector2(bd, bd) * 0.5,
							Vector2(bd, bd))
						feet.append(foot)
						rows.append([tower_side, cx_v, cz_v])
			for k in feet.size():
				var clear := not keep_out.any(func(r: Rect2) -> bool: return r.intersects(feet[k].grow(-0.02)))
				for j in feet.size():
					if j != k and feet[j].grow(-0.02).intersects(feet[k]):
						clear = false
				if not clear:
					continue
				var tower_side: float = rows[k][0]
				var cx_v: float = rows[k][1]
				var cz_v: float = rows[k][2]
				var tx: float = ChurchGeometry.tower_center_x(spec, tower_side)
				var tz: float = ChurchGeometry.tower_center_z(spec)
				_stepped_buttress("tower_%s_%s_%s" % [
					"left" if tower_side < 0.0 else "right",
					"left" if cx_v < 0.0 else "right",
					"front" if cz_v < 0.0 else "rear"],
					Vector3(tx + cx_v * tw2 / 2.0, 0.0,
						tz + cz_v * tw2 / 2.0), Vector3(cx_v, 0.0, cz_v),
					th2 * 0.8, bd, bd, true)

	# ---------- string course ----------
	tag("trim")
	if spec.string_course:
		var course_y: float = h * 0.62
		var course_t: float = 0.18
		_emit_perimeter_course("nave_string_course",
			AABB(Vector3(-w * 0.5, 0.0, -l * 0.5), Vector3(w, h, l)),
			_nave_openings(), course_y, course_t)
		for side_v in ChurchGeometry.west_tower_sides(spec):
			var side: float = side_v
			var tower_aabb: AABB = ChurchGeometry.tower_aabb(spec, side)
			if course_y - course_t * 0.5 < tower_aabb.position.y \
					or course_y + course_t * 0.5 > tower_aabb.end.y:
				continue
			var lx: float = ChurchGeometry.tower_center_x(spec, side)
			var lz: float = ChurchGeometry.tower_center_z(spec)
			var tower_name := "tower_%s" % ("left" if side < 0.0 else "right")
			if spec.west_towers == 1:
				tower_name = "tower"
			_emit_perimeter_course("%s_string_course" % tower_name,
				tower_aabb, _tower_openings(lx, lz, spec.tower_width,
					spec.tower_height), course_y, course_t)

	# ---------- main door ----------
	tag("door")
	# A single axial tower carries the door out to its own west face. The
	# tower, narthex and nave hosts each cut the same route below.
	var door_h: float = minf(h * 0.32, 3.4)
	var door_z: float = _west_door_z()
	var west_doors := _west_door_openings()
	for opening_index in range(west_doors.size()):
		var opening: Dictionary = west_doors[opening_index]
		window(opening.pos, PI, opening.width, opening.height,
			opening.style, true, true)
		_portal_moulding(opening, opening_index)
	box(Vector3((w * 0.34 if spec.door_style == &"portal" else 2.4) + 0.7, 0.22, 0.14),
		Vector3(0, door_h + 0.35 + ChurchGeometry.podium_height(spec), door_z - 0.02), SURF_TRIM)

	# ---------- nave windows when there are no aisles ----------
	tag("window")
	if spec.aisles == 0 and spec.hero != &"basil":
		for wz2 in ChurchGeometry.nave_window_zs(spec):
			for sx_v in [-1.0, 1.0]:
				window(Vector3(sx_v * (w / 2.0 + 0.02), h * 0.58, wz2),
					sx_v * PI / 2.0, spec.window_w, spec.window_h,
					spec.window_style, false, true)

	# ---------- rose window ----------
	tag("facade")
	if spec.rose_window:
		# The west front is at -Z: that is where the door and the towers are.
		# The rose was at +l/2, i.e. the east end, buried against the apse.
		rose(Vector3(0, _rose_y(), _west_door_z() if spec.west_towers == 1
			else -l / 2.0 - ChurchGeometry.OPENING_EPS), PI)

	_build_podium()
	_build_floor()
	_build_narthex()
	_build_ambulatory_and_chapels()
	_build_tribunes()
	_build_flying_buttresses()
	_build_crossing_tower()
	_build_dome()
	preload("church_roofs.gd").emit(spec, _kit, mass_log, _roof_volumes)

	# The masons are finished; the parish moves in. The dressing is prop
	# PLACEMENTS rather than geometry, so it costs the mesh nothing and
	# ChurchAssembler is the only thing that ever loads a model.
	prop_log = ChurchFurnisher.dress(spec)

	return commit_named()


## The nave shell is split at its wall faces. Each masonry panel has measured
## thickness; its exposed ends become the jambs, head and sill of a real hole.
const NAVE_WALL_T := 0.36


func _rose_radius() -> float:
	return minf(spec.width * 0.18, 1.6)


func _rose_y() -> float:
	var radius: float = _rose_radius()
	return minf(spec.height - radius - 0.3,
		maxf(spec.height * 0.68, spec.height * 0.62 + radius + 0.35))


func _rose_holes(face: int, u: float, y: float, radius: float) -> Array[Dictionary]:
	var holes: Array[Dictionary] = []
	var bands := 9
	for i in range(bands):
		var bottom: float = -radius + 2.0 * radius * float(i) / bands
		var top: float = -radius + 2.0 * radius * float(i + 1) / bands
		var edge: float = maxf(absf(bottom), absf(top))
		var half: float = sqrt(maxf(radius * radius - edge * edge, 0.0))
		holes.append({"face": face, "u": u, "y": y + (bottom + top) * 0.5,
			"width": half * 2.0, "height": top - bottom,
			"style": &"round", "log": false})
	return holes


## A rectangular host has four thin stone walls and caps. Divide each wall at
## the actual window bounds; the exposed box ends make physical stone returns.
## Rows use world-space u (X on north/south, Z on east/west) and a face index:
## +Z, +X, -Z, -X. Portal rows may set log=false when logged elsewhere.
func _church_wall_surface() -> int:
	return SURF_WOOD if spec.style == &"nordic_stave" else SURF_STONE


func _windowed_box_shell(a: AABB, openings: Array[Dictionary],
		cap_bottom := true, cap_top := true) -> void:
	var wall_surface: int = _church_wall_surface()
	for face in range(4):
		var holes: Array[Dictionary] = []
		for opening in openings:
			if int(opening["face"]) == face:
				holes.append(opening)
		_box_wall_with_holes(a, face, holes, wall_surface)
	for cap_index in range(2):
		if (cap_index == 0 and not cap_bottom) or (cap_index == 1 and not cap_top):
			continue
		var y: float = a.position.y if cap_index == 0 else a.end.y
		var cap_surface: int = SURF_STONE if cap_index == 0 else wall_surface
		_nave_plane(_kit.surface(cap_surface), Vector3(a.position.x, y, a.position.z),
			Vector3(a.end.x, y, a.position.z), Vector3(a.end.x, y, a.end.z),
			Vector3(a.position.x, y, a.end.z),
			Vector3.DOWN if cap_index == 0 else Vector3.UP)
	for opening in openings:
		if not bool(opening.get("log", true)):
			continue
		var face: int = int(opening["face"])
		var center := a.position + a.size * 0.5
		var pos := Vector3(center.x, float(opening["y"]), center.z)
		match face:
			0:
				pos.x = float(opening["u"])
				pos.z = a.end.z + ChurchGeometry.OPENING_EPS
			1:
				pos.x = a.end.x + ChurchGeometry.OPENING_EPS
				pos.z = float(opening["u"])
			2:
				pos.x = float(opening["u"])
				pos.z = a.position.z - ChurchGeometry.OPENING_EPS
			3:
				pos.x = a.position.x - ChurchGeometry.OPENING_EPS
				pos.z = float(opening["u"])
		window(pos, face * PI * 0.5, float(opening["width"]),
			float(opening["height"]), opening["style"],
			bool(opening.get("door", false)), true)


func _box_wall_with_holes(a: AABB, face: int, holes: Array[Dictionary],
		wall_surface: int = SURF_STONE) -> void:
	var u0: float = a.position.x if face % 2 == 0 else a.position.z
	var u1: float = a.end.x if face % 2 == 0 else a.end.z
	var edges: Array[float] = [u0, u1]
	for hole in holes:
		edges.append(clampf(float(hole["u"]) - float(hole["width"]) * 0.5, u0, u1))
		edges.append(clampf(float(hole["u"]) + float(hole["width"]) * 0.5, u0, u1))
		if hole.has("arch"):
			for sample in range(1, 33):
				edges.append(clampf(float(hole["u"]) - float(hole["width"]) * 0.5
					+ float(sample) * float(hole["width"]) / 32.0, u0, u1))
	edges.sort()
	for i in range(edges.size() - 1):
		var left: float = edges[i]
		var right: float = edges[i + 1]
		if right - left < 0.001:
			continue
		var mid: float = (left + right) * 0.5
		var bands: Array[float] = [a.position.y, a.end.y]
		for hole in holes:
			if absf(mid - float(hole["u"])) >= float(hole["width"]) * 0.5:
				continue
			bands.append(clampf(float(hole["y"]) - float(hole["height"]) * 0.5,
				a.position.y, a.end.y))
			bands.append(clampf(_box_opening_top(hole, mid), a.position.y, a.end.y))
		bands.sort()
		for j in range(bands.size() - 1):
			var bottom: float = bands[j]
			var top: float = bands[j + 1]
			if top - bottom < 0.001:
				continue
			var y: float = (bottom + top) * 0.5
			var cut := false
			for hole in holes:
				var hole_bottom: float = float(hole["y"]) - float(hole["height"]) * 0.5
				if absf(mid - float(hole["u"])) < float(hole["width"]) * 0.5 \
						and y > hole_bottom and y < _box_opening_top(hole, mid):
					cut = true
					break
			if cut:
				continue
			var size := Vector3(right - left, top - bottom, NAVE_WALL_T)
			var pos := Vector3(mid, y, a.end.z - NAVE_WALL_T * 0.5)
			match face:
				1:
					size = Vector3(NAVE_WALL_T, top - bottom, right - left)
					pos = Vector3(a.end.x - NAVE_WALL_T * 0.5, y, mid)
				2:
					pos.z = a.position.z + NAVE_WALL_T * 0.5
				3:
					size = Vector3(NAVE_WALL_T, top - bottom, right - left)
					pos = Vector3(a.position.x + NAVE_WALL_T * 0.5, y, mid)
			box(size, pos, wall_surface)


func _crossing_arch_profile() -> Dictionary:
	var half_span: float = spec.width * 0.5 - NAVE_WALL_T - 0.28
	var spring: float = spec.height * 0.78
	var peak: float = spring + minf(spec.height * 0.18, half_span * 0.42)
	var kind: StringName = &"gothic" if spec.style == &"gothic" else &"round"
	return {"half_span": half_span, "spring_y": spring, "peak_y": peak, "kind": kind}


func _box_opening_top(opening: Dictionary, u: float) -> float:
	if not opening.has("arch"):
		return float(opening["y"]) + float(opening["height"]) * 0.5
	var spring: float = float(opening["spring_y"])
	var peak: float = float(opening["y"]) + float(opening["height"]) * 0.5
	return ChurchGeometry.arch_head_y(u - float(opening["u"]),
		float(opening["width"]) * 0.5, spring, peak, StringName(opening["arch"]))


## Revolved wall facets are chords. The selected window is centred on its
## actual chord and the neighbouring stone panels stop at its jamb, head and
## sill. An odd half-sweep count supplies a central facet for the apse/chapel.
func _arc_window_shell(center: Vector3, radius: float, height: float,
		segments: int, arc: float, start: float, face_angles: Array,
		width: float, opening_h: float, opening_y: float,
		style: StringName, cap_top := false, open_ends := false) -> void:
	var cut_faces: Dictionary = {}
	var step: float = arc / float(segments)
	for angle in face_angles:
		var theta: float = wrapf(PI * 0.5 - float(angle) - start, 0.0, TAU)
		var index: int = clampi(roundi(theta / step - 0.5), 0, segments - 1)
		cut_faces[index] = true
	var wall_surface: int = _church_wall_surface()
	var st: SurfaceTool = _kit.surface(wall_surface)
	var thickness: float = minf(NAVE_WALL_T, radius * 0.24)
	for i in range(segments):
		var a0: float = start + step * float(i)
		var a1: float = start + step * float(i + 1)
		var p0 := center + Vector3(cos(a0) * radius, 0, sin(a0) * radius)
		var p1 := center + Vector3(cos(a1) * radius, 0, sin(a1) * radius)
		var normal := Vector3(cos((a0 + a1) * 0.5), 0,
			sin((a0 + a1) * 0.5))
		var face: float = atan2(normal.x, normal.z)
		var chord: float = p0.distance_to(p1)
		if not cut_faces.has(i):
			_arc_wall_panel(p0, p1, normal, face, 0.0, 1.0,
				0.0, height, thickness)
		else:
			var w: float = minf(width, chord * 0.72)
			var lo: float = 0.5 - w / (chord * 2.0)
			var hi: float = 0.5 + w / (chord * 2.0)
			var bottom: float = clampf(opening_y - opening_h * 0.5, 0.0, height)
			var top: float = clampf(opening_y + opening_h * 0.5, 0.0, height)
			_arc_wall_panel(p0, p1, normal, face, 0.0, lo,
				0.0, height, thickness)
			_arc_wall_panel(p0, p1, normal, face, hi, 1.0,
				0.0, height, thickness)
			_arc_wall_panel(p0, p1, normal, face, lo, hi,
				0.0, bottom, thickness)
			_arc_wall_panel(p0, p1, normal, face, lo, hi,
				top, height, thickness)
			window((p0 + p1) * 0.5 + normal * ChurchGeometry.OPENING_EPS
				+ Vector3.UP * opening_y, face, w, opening_h, style, false, true)
		if cap_top:
			_kit._tri(st, center + Vector3.UP * height,
				p0 + Vector3.UP * height, p1 + Vector3.UP * height)
	if arc < TAU - 0.001 and not open_ends:
		for angle in [start, start + arc]:
			var outer := center + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
			if angle == start:
				_kit._quad(st, center, outer, outer + Vector3.UP * height,
					center + Vector3.UP * height)
			else:
				_kit._quad(st, outer, center, center + Vector3.UP * height,
					outer + Vector3.UP * height)


func _arc_wall_panel(p0: Vector3, p1: Vector3, normal: Vector3,
		face: float, u0: float, u1: float, y0: float, y1: float,
		thickness: float) -> void:
	if u1 - u0 < 0.001 or y1 - y0 < 0.001:
		return
	var q0: Vector3 = p0.lerp(p1, u0)
	var q1: Vector3 = p0.lerp(p1, u1)
	box(Vector3(q0.distance_to(q1), y1 - y0, thickness),
		(q0 + q1) * 0.5 - normal * thickness * 0.5
			+ Vector3.UP * (y0 + y1) * 0.5, _church_wall_surface(), face)


func _cuts_clerestory() -> bool:
	return spec.style == &"gothic" and ChurchGeometry.has_clerestory(spec)


func _west_door_z() -> float:
	if spec.tower and spec.west_towers == 1:
		return -spec.length / 2.0 + TOWER_EMBED - spec.tower_width - ChurchGeometry.OPENING_EPS
	return -spec.length / 2.0 - ChurchGeometry.OPENING_EPS


func _west_door_openings() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var door_h: float = minf(spec.height * 0.32, 3.4)
	var z: float = _west_door_z()
	var lift: float = ChurchGeometry.podium_height(spec)
	# A doorway is cut to the floor it serves. Started 5-10 cm up, each wall
	# it passed through kept a strip of stone across the way in, proud of the
	# bare ground on both sides -- two trip steps between the west front and
	# the nave (walk-QA, Abbey Ivo pin 2, "stuck in door").
	for door in ChurchGeometry.west_door_layout(spec):
		out.append({"pos": Vector3(float(door.x), door_h / 2.0 + lift, z),
			"width": door.width, "height": door_h, "style": door.style})
	return out


func _nave_openings() -> Array[Dictionary]:
	var w: float = spec.width
	var h: float = spec.height
	var holes: Array[Dictionary] = []
	if _cuts_clerestory():
		for opening in ChurchGeometry.clerestory_windows(spec):
			holes.append({"face": 1 if opening.pos.x > 0.0 else 3,
				"u": opening.pos.z, "y": opening.pos.y,
				"width": opening.width, "height": opening.height,
				"style": spec.window_style, "log": false})
	if spec.aisles == 0 and spec.hero != &"basil":
		for z in ChurchGeometry.nave_window_zs(spec):
			for face in [1, 3]:
				holes.append({"face": face, "u": z, "y": h * 0.58,
					"width": spec.window_w, "height": spec.window_h,
					"style": spec.window_style, "log": false})
	for opening in _west_door_openings():
		holes.append({"face": 2, "u": opening.pos.x,
			"y": opening.pos.y, "width": opening.width,
			"height": opening.height, "style": opening.style,
			"log": false})
	if spec.rose_window and spec.west_towers != 1:
		holes.append_array(_rose_holes(2, 0.0, _rose_y(), _rose_radius()))
	if spec.apse:
		var portal_spring: float = h * 0.72
		var portal_half: float = w * 0.5 - NAVE_WALL_T - 0.28
		var portal_rise: float = minf(h * 0.24, portal_half * 0.42)
		var portal_peak: float = portal_spring + portal_rise
		holes.append({"face": 0, "u": 0.0, "y": portal_peak * 0.5,
			"width": portal_half * 2.0, "height": portal_peak,
			"spring_y": portal_spring,
			"arch": "gothic" if spec.style == &"gothic" else "round",
			"style": &"pointed", "door": true, "log": true})
	return holes


func _tower_openings(lx: float, lz: float, tw: float, th: float) -> Array[Dictionary]:
	var holes: Array[Dictionary] = []
	for face in range(4):
		holes.append({"face": face, "u": lz if face % 2 == 1 else lx,
			"y": th - tw * 0.28, "width": tw * 0.32,
			"height": tw * 0.26, "style": &"square"})
	if spec.west_towers > 0:
		var x0: float = lx - tw * 0.5
		var x1: float = lx + tw * 0.5
		for portal in _west_door_openings():
			var left: float = maxf(x0, portal.pos.x - portal.width * 0.5)
			var right: float = minf(x1, portal.pos.x + portal.width * 0.5)
			if right <= left:
				continue
			for face in [0, 2]:
				holes.append({"face": face, "u": (left + right) * 0.5,
					"y": portal.pos.y, "width": right - left,
					"height": portal.height, "style": portal.style, "log": false})
			if left <= x0 + NAVE_WALL_T:
				holes.append({"face": 3, "u": lz, "y": portal.pos.y,
					"width": tw, "height": portal.height,
					"style": portal.style, "log": false})
			if right >= x1 - NAVE_WALL_T:
				holes.append({"face": 1, "u": lz, "y": portal.pos.y,
					"width": tw, "height": portal.height,
					"style": portal.style, "log": false})
	if spec.west_towers == 1 and spec.rose_window:
		holes.append_array(_rose_holes(2, lx, _rose_y(), _rose_radius()))
	return holes


func _nave_shell() -> void:
	var w: float = spec.width
	var h: float = spec.height
	var l: float = spec.length
	_windowed_box_shell(AABB(Vector3(-w * 0.5, 0, -l * 0.5),
		Vector3(w, h, l)), _nave_openings(), true, false)


## Emit a string course as four exterior runs. Apertures crossing the course
## elevation are removed from the run so the trim cannot cap a real opening.
func _emit_perimeter_course(course_host: String, bounds: AABB,
		openings: Array[Dictionary], course_y: float,
		thickness: float) -> void:
	var x0: float = bounds.position.x - 0.175
	var x1: float = bounds.end.x + 0.175
	var z0: float = bounds.position.z - 0.175
	var z1: float = bounds.end.z + 0.175
	var face_centres := {
		0: Vector3(0.0, course_y, bounds.end.z + thickness * 0.5),
		1: Vector3(bounds.end.x + thickness * 0.5, course_y, 0.0),
		2: Vector3(0.0, course_y, bounds.position.z - thickness * 0.5),
		3: Vector3(bounds.position.x - thickness * 0.5, course_y, 0.0)}
	for face in range(4):
		var is_end: bool = face == 0 or face == 2
		var span_min: float = x0 if is_end else z0
		var span_max: float = x1 if is_end else z1
		var cuts: Array[Vector2] = []
		for opening in openings:
			if int(opening.get("face", -1)) != face:
				continue
			var low_y: float = float(opening["y"]) - float(opening["height"]) * 0.5
			var high_y: float = _box_opening_top(opening, float(opening["u"]))
			if high_y <= course_y - thickness * 0.5 or low_y >= course_y + thickness * 0.5:
				continue
			var half_opening: float = float(opening["width"]) * 0.5 + 0.04
			var cut_min: float = maxf(span_min, float(opening["u"]) - half_opening)
			var cut_max: float = minf(span_max, float(opening["u"]) + half_opening)
			if cut_max > cut_min:
				cuts.append(Vector2(cut_min, cut_max))
		cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var merged: Array[Vector2] = []
		for cut in cuts:
			if merged.is_empty() or cut.x > merged.back().y:
				merged.append(cut)
			else:
				var previous: Vector2 = merged.back()
				merged[merged.size() - 1] = Vector2(previous.x, maxf(previous.y, cut.y))
		var cursor: float = span_min
		var segment_index: int = 0
		for cut in merged:
			if cut.x > cursor + 0.02:
				_emit_course_segment(course_host, face, segment_index,
					cursor, cut.x, is_end, face_centres[face], thickness)
				segment_index += 1
			cursor = maxf(cursor, cut.y)
		if span_max > cursor + 0.02:
			_emit_course_segment(course_host, face, segment_index,
				cursor, span_max, is_end, face_centres[face], thickness)


func _emit_course_segment(course_host: String, face: int,
		segment_index: int, low: float, high: float, is_end: bool,
		face_center: Vector3, thickness: float) -> void:
	var size: Vector3
	var pos: Vector3 = face_center
	if is_end:
		size = Vector3(high - low, thickness, thickness)
		pos.x = (low + high) * 0.5
	else:
		size = Vector3(thickness, thickness, high - low)
		pos.z = (low + high) * 0.5
	var face_name: String = ["east", "right", "west", "left"][face]
	var role := "string_course_%s_%d" % [face_name, segment_index]
	host(course_host)
	var row: Dictionary = component_box(role, size,
		Transform3D(Basis.IDENTITY, pos), SURF_TRIM)
	_log_part("box", pos, size)
	part_log.back()["component_id"] = row["id"]
	host_end()


## The east wall opening is a real nave-to-apse passage. Its curved ring bears
## on the two surviving wall returns rather than floating over a solid wall.
func _build_apse_entrance_arch() -> void:
	if not spec.apse:
		return
	tag("apse")
	host("apse_entrance_arch")
	var spring: float = spec.height * 0.72
	var z: float = spec.length * 0.5 - NAVE_WALL_T * 0.5
	_build_nave_arch(z, spring, clampf(spec.width * 0.05, 0.34, 0.56),
		clampf(spec.width * 0.055, 0.38, 0.62), true)
	host_end()


## Give the nave a visible load path. Frames follow outside buttress stations;
## only stations and spans inside a dome/lantern crossing bay are omitted.
func _build_nave_structure() -> void:
	var zs: Array[float] = ChurchGeometry.nave_support_zs(spec)
	var crossing_center: float = ChurchGeometry.crossing_center_z(spec)
	var crossing_half: float = ChurchGeometry.crossing_bay_depth(spec) * 0.5
	var has_crossing_roof: bool = spec.dome or spec.crossing_tower \
			or spec.hero in [&"hagia", &"florence", &"basil"]
	if has_crossing_roof:
		var outside: Array[float] = []
		for z in zs:
			if z < crossing_center - crossing_half - 0.05 \
					or z > crossing_center + crossing_half + 0.05:
				outside.append(z)
		zs = outside
	if zs.size() < 2:
		return
	var wall_inner: float = spec.width * 0.5 - NAVE_WALL_T
	var pier_projection: float = 0.34
	var pier_width: float = clampf(spec.width * 0.065, 0.42, 0.78)
	var spring: float = _stave_eave_y() if spec.style == &"nordic_stave" \
		else minf(spec.height * 0.72, spec.height - 1.4)
	var rib_depth: float = clampf(spec.width * 0.045, 0.32, 0.58)
	var rib_thickness: float = clampf(spec.width * 0.04, 0.28, 0.48)
	for bay_index in range(zs.size()):
		var z: float = zs[bay_index]
		var has_next: bool = bay_index < zs.size() - 1
		var next_z: float = zs[bay_index + 1] if has_next else z
		var crosses_roof_bay: bool = has_crossing_roof and has_next \
			and z < crossing_center + crossing_half - 0.05 \
			and next_z > crossing_center - crossing_half + 0.05
		host("nave_bay_%d" % bay_index)
		var pier_surface: int = SURF_WOOD if spec.style == &"nordic_stave" else SURF_STONE
		for side in [-1.0, 1.0]:
			var x: float = side * (wall_inner - pier_projection / 2.0)
			var floor_y: float = ChurchGeometry.FLOOR_LIFT
			var shaft_h: float = maxf(spring - floor_y - 0.16, 0.8)
			var shaft_size := Vector3(pier_projection, shaft_h, pier_width)
			var shaft_xf := Transform3D(Basis(), Vector3(x, floor_y + shaft_h / 2.0, z))
			component_box("nave_engaged_pier", shaft_size, shaft_xf, pier_surface)
			var cap_size := Vector3(pier_projection + 0.14, 0.32, pier_width + 0.2)
			var cap_xf := Transform3D(Basis(), Vector3(x, spring, z))
			component_box("nave_pier_capital", cap_size, cap_xf,
				SURF_WOOD if spec.style == &"nordic_stave" else SURF_TRIM)
		if has_next and not crosses_roof_bay and spec.style != &"nordic_stave":
			var sanctuary: bool = spec.apse and bay_index == zs.size() - 2
			_build_nave_arch(z, spring, rib_thickness, rib_depth, sanctuary)
		if spec.style == &"nordic_stave":
			_build_stave_truss(z, spring, rib_thickness, rib_depth)
		host_end()
		if spec.style == &"nordic_stave" and has_next and not crosses_roof_bay:
			_build_stave_longitudinals(z, next_z, spring, rib_thickness, rib_depth)


func _build_nave_arch(z: float, spring: float, thickness: float, depth: float,
		sanctuary: bool = false, profile: Dictionary = {}) -> void:
	var half_span: float = spec.width * 0.5 - NAVE_WALL_T - 0.28
	var rise_ratio: float = 0.24 if sanctuary else 0.18
	var peak: float = spring + minf(spec.height * rise_ratio, half_span * 0.42)
	var arch_kind: StringName = &"gothic" if spec.style == &"gothic" else &"round"
	if not profile.is_empty():
		half_span = float(profile["half_span"])
		spring = float(profile["spring_y"])
		peak = float(profile["peak_y"])
		arch_kind = StringName(profile["kind"])
	var surface: int = SURF_TRIM if sanctuary else SURF_STONE
	var role: String = "sanctuary_triumphal_arch" if sanctuary else "nave_transverse_arch"
	var arch_depth: float = depth * 1.35 if sanctuary else depth
	var arch_thickness: float = thickness * 1.2 if sanctuary else thickness
	if sanctuary:
		var impost_width: float = 0.80
		for side in [-1.0, 1.0]:
			var impost_x: float = side * (half_span + impost_width * 0.5 - 0.11)
			var impost_size := Vector3(impost_width, arch_thickness, arch_depth * 1.1)
			var impost_xf := Transform3D(Basis(), Vector3(impost_x, spring, z))
			component_box("sanctuary_arch_impost", impost_size, impost_xf, SURF_TRIM)
	var segments_per_side: int = 6
	for side in [-1.0, 1.0]:
		var previous := Vector3(side * half_span, spring, z)
		for step in range(1, segments_per_side + 1):
			var t: float = float(step) / float(segments_per_side)
			var x: float = lerpf(side * half_span, 0.0, t)
			# The wall cut and every emitted rib sample this same profile.
			var y: float = ChurchGeometry.arch_head_y(x, half_span, spring, peak, arch_kind)
			var current := Vector3(x, y, z)
			var delta: Vector2 = Vector2(current.x - previous.x, current.y - previous.y)
			var angle: float = atan2(delta.y, delta.x)
			var centre := (current + previous) * 0.5
			var xf := Transform3D(Basis(Vector3.BACK, angle), centre)
			component_box(role, Vector3(delta.length() * 1.04,
				arch_thickness, arch_depth), xf, surface)
			previous = current


func _stave_eave_y() -> float:
	var half_span: float = spec.width * 0.5 - NAVE_WALL_T + 0.12
	var roof_rise: float = spec.width * spec.roof_pitch
	var roof_half: float = spec.width * 0.5 + ChurchGeometry.ROOF_EAVE_X * 0.5
	var roof_line: float = spec.height + roof_rise * (1.0 - half_span / roof_half)
	var rafter: float = clampf(spec.width * 0.04, 0.28, 0.48)
	return roof_line - RoofShape.DEPTH * 0.5 - rafter * 0.5 + 0.005


func _stave_ridge_y() -> float:
	var rafter: float = clampf(spec.width * 0.04, 0.28, 0.48)
	return spec.height + spec.width * spec.roof_pitch \
		- RoofShape.DEPTH * 0.5 - rafter * 0.5 + 0.005


func _build_stave_truss(z: float, spring: float, thickness: float, depth: float) -> void:
	# Rafters rise to the underside of the generated gable roof and seat inside
	# the nave wall thickness at their feet.
	var half_span: float = spec.width * 0.5 - NAVE_WALL_T + 0.12
	var peak: float = _stave_ridge_y()
	var tie_xf := Transform3D(Basis(), Vector3(0.0, spring, z))
	component_box("stave_tie_beam", Vector3(half_span * 2.0, thickness, depth),
		tie_xf, SURF_WOOD)
	for side in [-1.0, 1.0]:
		var from_p := Vector3(side * half_span, spring, z)
		var to_p := Vector3(0.0, peak, z)
		var delta: Vector2 = Vector2(to_p.x - from_p.x, to_p.y - from_p.y)
		var xf := Transform3D(Basis(Vector3.BACK, atan2(delta.y, delta.x)),
			(from_p + to_p) * 0.5)
		component_box("stave_raised_rafter", Vector3(delta.length() * 1.04,
			thickness, depth), xf, SURF_WOOD)


func _build_stave_longitudinals(z0: float, z1: float, spring: float,
		thickness: float, depth: float) -> void:
	var half_span: float = spec.width * 0.5 - NAVE_WALL_T + 0.12
	var run: float = z1 - z0 + depth * 0.18
	var center_z: float = (z0 + z1) * 0.5
	var peak: float = _stave_ridge_y()
	host("stave_roof_bay")
	var roof_half: float = spec.width * 0.5 + ChurchGeometry.ROOF_EAVE_X * 0.5
	var rafter: float = clampf(spec.width * 0.04, 0.28, 0.48)
	var ridge_center_y: float = peak + rafter * 0.5 - 0.32 * 0.5
	component_box("stave_ridge_beam", Vector3(0.34, 0.32, run),
		Transform3D(Basis(), Vector3(0.0, ridge_center_y, center_z)), SURF_WOOD)
	for side in [-1.0, 1.0]:
		var x: float = side * half_span * 0.55
		var roof_y: float = spec.height + spec.width * spec.roof_pitch \
			* (1.0 - absf(x) / roof_half)
		var purlin_center_y: float = roof_y - RoofShape.DEPTH * 0.5 \
			- 0.28 * 0.5 + 0.005
		component_box("stave_purlin", Vector3(0.28, 0.28, run),
			Transform3D(Basis(), Vector3(x, purlin_center_y, center_z)), SURF_WOOD)
	host_end()


func _nave_plane(st: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3, normal: Vector3) -> void:
	if (c - a).cross(b - a).dot(normal) < 0.0:
		_kit._tri(st, a, d, c)
		_kit._tri(st, a, c, b)
	else:
		_kit._tri(st, a, b, c)
		_kit._tri(st, a, c, d)


## Entrance vestibule across the west front.
func _build_narthex() -> void:
	if not spec.narthex:
		return
	tag("narthex")
	var a: AABB = ChurchGeometry.narthex_aabb(spec)
	var holes: Array[Dictionary] = []
	for opening in _west_door_openings():
		for face in [2, 0]:
			holes.append({"face": face, "u": opening.pos.x,
				"y": opening.pos.y, "width": opening.width,
				"height": opening.height, "style": opening.style,
				"door": true, "log": face == 2})
	_windowed_box_shell(a, holes, true, false)
	_log_mass("narthex", a)


## The ambulatory carries the aisle around the apse; radiating chapels are the
## alcoves that open off it. Chartres has seven, Notre-Dame a full ring.
func _build_ambulatory_and_chapels() -> void:
	if not spec.apse and spec.radiating_chapels <= 0:
		return
	var cy: float = ChurchGeometry.apse_springing_z(spec)
	if spec.ambulatory and spec.apse:
		_build_ambulatory_ring(cy)
	if spec.radiating_chapels <= 0:
		return
	tag("chapel")
	var chr_r: float = spec.chapel_radius
	for i in range(spec.radiating_chapels):
		var c: Vector3 = ChurchGeometry.chapel_center(spec, i)
		var a: float = ChurchGeometry.chapel_angle(spec, i)
		var chh: float = ChurchGeometry.chapel_body_height(spec, i)
		var domed: bool = spec.hero == &"basil"
		# each alcove is a little apse in its own right, facing outward
		_arc_window_shell(Vector3(c.x, 0.0, c.z), chr_r, chh, 7, PI,
			ChurchGeometry.chapel_arc_start(spec, i), [a], 0.6,
			chh * 0.4, chh * 0.45, spec.window_style, domed)
		_log_mass("chapel_%d" % i, ChurchGeometry.chapel_aabb(spec, i))
		if domed:
			_basil_chapel_tower(i)
		else:
			_kit.stepped_taper(Vector3(c.x, chh, c.z), chr_r * 2.0 + 0.2, chr_r * 0.6,
				SURF_ROOF, 3, 0.15, true, 0.0, 0.8)


## A half-annular ambulatory is a real roofed walk around the apse, not a
## semicylinder with a disk over its void. The nave paving carries its west
## half; clipped annular slabs continue the floor only beyond the nave end.
func _build_ambulatory_ring(cy: float) -> void:
	tag("ambulatory")
	var outer_radius: float = ChurchGeometry.ambulatory_radius(spec)
	var roof_outer: float = outer_radius + ChurchGeometry.APSE_EAVE
	var floor_inner: float = ChurchGeometry.ambulatory_inner_radius(spec)
	var roof_inner: float = ChurchGeometry.ambulatory_roof_inner_radius(spec)
	var wall_inner: float = outer_radius - NAVE_WALL_T
	var height: float = spec.height * ChurchGeometry.AISLE_HEIGHT_RATIO
	var segments := 20
	var origin := Vector3(0.0, 0.0, cy)
	var stone := _kit.surface(SURF_STONE)
	var roof := _kit.surface(SURF_ROOF)
	var roof_bottom := Vector3.DOWN * 0.18
	host("ambulatory")
	for i in range(segments):
		var a0: float = PI * float(i) / float(segments)
		var a1: float = PI * float(i + 1) / float(segments)
		var o0 := origin + Vector3(cos(a0) * outer_radius, 0.0, sin(a0) * outer_radius)
		var o1 := origin + Vector3(cos(a1) * outer_radius, 0.0, sin(a1) * outer_radius)
		var i0 := origin + Vector3(cos(a0) * wall_inner, 0.0, sin(a0) * wall_inner)
		var i1 := origin + Vector3(cos(a1) * wall_inner, 0.0, sin(a1) * wall_inner)
		_kit._quad(stone, o0, o1, o1 + Vector3.UP * height, o0 + Vector3.UP * height)
		_kit._quad(stone, i1, i0, i0 + Vector3.UP * height, i1 + Vector3.UP * height)
		_kit._quad(stone, o0 + Vector3.UP * height, o1 + Vector3.UP * height,
			i1 + Vector3.UP * height, i0 + Vector3.UP * height)
		_kit._quad(stone, i0, i1, o1, o0)
		var roof_outer0 := origin + Vector3(cos(a0) * roof_outer, height, sin(a0) * roof_outer)
		var roof_outer1 := origin + Vector3(cos(a1) * roof_outer, height, sin(a1) * roof_outer)
		var roof_inner0 := origin + Vector3(cos(a0) * roof_inner, height, sin(a0) * roof_inner)
		var roof_inner1 := origin + Vector3(cos(a1) * roof_inner, height, sin(a1) * roof_inner)
		_kit._quad(roof, roof_outer0, roof_outer1, roof_inner1, roof_inner0)
		_kit._quad(roof, roof_inner0 + roof_bottom, roof_inner1 + roof_bottom,
			roof_outer1 + roof_bottom, roof_outer0 + roof_bottom)
		_kit._quad(roof, roof_outer0 + roof_bottom, roof_outer1 + roof_bottom,
			roof_outer1, roof_outer0)
		_kit._quad(roof, roof_inner1 + roof_bottom, roof_inner0 + roof_bottom,
			roof_inner0, roof_inner1)
		var floor_outer0 := origin + Vector3(cos(a0) * wall_inner, 0.0, sin(a0) * wall_inner)
		var floor_outer1 := origin + Vector3(cos(a1) * wall_inner, 0.0, sin(a1) * wall_inner)
		var floor_inner0 := origin + Vector3(cos(a0) * floor_inner, 0.0, sin(a0) * floor_inner)
		var floor_inner1 := origin + Vector3(cos(a1) * floor_inner, 0.0, sin(a1) * floor_inner)
		var floor_points := PackedVector2Array([
			Vector2(floor_outer0.x, floor_outer0.z), Vector2(floor_outer1.x, floor_outer1.z),
			Vector2(floor_inner1.x, floor_inner1.z), Vector2(floor_inner0.x, floor_inner0.z)])
		floor_points = _clip_polygon_z_min(floor_points, spec.length * 0.5)
		if floor_points.size() >= 3:
			var floor_poly := PackedVector3Array()
			for point in floor_points:
				floor_poly.append(Vector3(point.x,
					ChurchGeometry.FLOOR_LIFT - ChurchGeometry.FLOOR_T * 0.5, point.y))
			_kit.slab_poly(floor_poly, ChurchGeometry.FLOOR_T, SURF_STONE, true)
		var disk_points := PackedVector2Array([
			Vector2(0.0, cy), Vector2(floor_inner0.x, floor_inner0.z),
			Vector2(floor_inner1.x, floor_inner1.z)])
		disk_points = _clip_polygon_z_min(disk_points, spec.length * 0.5)
		if disk_points.size() >= 3:
			var disk_poly := PackedVector3Array()
			for point in disk_points:
				disk_poly.append(Vector3(point.x,
					ChurchGeometry.FLOOR_LIFT - ChurchGeometry.FLOOR_T * 0.5, point.y))
			_kit.slab_poly(disk_poly, ChurchGeometry.FLOOR_T, SURF_STONE, true)
	for angle in [0.0, PI]:
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var inner_end := origin + direction * wall_inner
		var outer_end := origin + direction * outer_radius
		if is_zero_approx(angle):
			_kit._quad(stone, inner_end, outer_end,
				outer_end + Vector3.UP * height, inner_end + Vector3.UP * height)
		else:
			_kit._quad(stone, outer_end, inner_end,
				inner_end + Vector3.UP * height, outer_end + Vector3.UP * height)
		var roof_in := origin + direction * roof_inner
		var roof_out := origin + direction * roof_outer
		if is_zero_approx(angle):
			_kit._quad(roof, roof_in + roof_bottom, roof_out + roof_bottom,
				roof_out, roof_in)
		else:
			_kit._quad(roof, roof_out + roof_bottom, roof_in + roof_bottom,
				roof_in, roof_out)
	host_end()
	_log_mass("ambulatory", ChurchGeometry.ambulatory_aabb(spec))
	component_note("ambulatory", "half_annular_walk", SURF_STONE, {
		"center": Vector2(0.0, cy), "outer_radius": outer_radius,
		"floor_inner_radius": floor_inner, "roof_inner_radius": roof_inner,
		"roof_outer_radius": roof_outer, "wall_inner_radius": wall_inner,
		"height": height, "segments": segments})


func _clip_polygon_z_min(poly: PackedVector2Array, minimum_z: float) -> PackedVector2Array:
	var clipped := PackedVector2Array()
	for i in range(poly.size()):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var a_inside: bool = a.y >= minimum_z - 0.0001
		var b_inside: bool = b.y >= minimum_z - 0.0001
		if a_inside:
			clipped.append(a)
		if a_inside != b_inside:
			var t: float = (minimum_z - a.y) / (b.y - a.y)
			clipped.append(a.lerp(b, t))
	return clipped


## A base, two set-backs and stone shoulders make the bearing legible. Every
## box remains in part_log and has a stable named component for exterior QA.
func _stepped_buttress(name: String, anchor: Vector3, outward: Vector3,
		height: float, depth: float, face_width: float, corner: bool) -> void:
	host(name)
	var levels := [0.0, 0.38, 0.70, 1.0]
	var widths := [1.0, 0.72, 0.44]
	for i in range(3):
		var d: float = depth * widths[i]
		var y0: float = height * levels[i]
		var y1: float = height * levels[i + 1]
		var z_width: float = d if corner else face_width * (1.0 - i * 0.12)
		_buttress_piece("shaft_%d" % i,
			Vector3(d, y1 - y0, z_width),
			anchor + outward * (d / 2.0 - ChurchGeometry.BUTTRESS_INSET)
				+ Vector3.UP * ((y0 + y1) / 2.0), SURF_STONE)
	for i in range(3):
		var d: float = depth * widths[i]
		var y: float = height * levels[i + 1]
		var z_width: float = d if corner else face_width * (1.1 - i * 0.12)
		_buttress_piece("shoulder_%d" % i,
			Vector3(d, clampf(height * 0.012, 0.12, 0.28), z_width),
			anchor + outward * (d / 2.0 - ChurchGeometry.BUTTRESS_INSET)
				+ Vector3.UP * y, SURF_TRIM)
	host_end()


func _buttress_piece(role: String, size: Vector3, pos: Vector3, surf: int) -> void:
	_log_part("box", pos, size)
	component_box(role, size, Transform3D(Basis.IDENTITY, pos), surf)


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
				var from_p := Vector3(px, from_y, pz)
				var to_p := Vector3(wall_x, to_y, pz)
				var side_name: String = "left" if side < 0.0 else "right"
				host("flyer_%s_%d_tier_%d" % [side_name, i, tier])
				_kit.arc_ribbon(from_p, to_p, bow, arch_t, pw * 0.88, SURF_STONE, 8)
				var coping_lift: float = arch_t * 0.58
				_kit.arc_ribbon(from_p + Vector3.UP * coping_lift,
					to_p + Vector3.UP * coping_lift, bow, arch_t * 0.24,
					pw * 0.96, SURF_TRIM, 8)
				# The arch is what ties an otherwise free-standing pier to the
				# nave, so it counts as a mass: without it the pier reads as
				# floating, which is exactly what a flyer is meant to avoid.
				var x0: float = minf(px, wall_x)
				var y0: float = minf(from_y, to_y) - arch_t
				var y1: float = maxf(from_y, to_y) + bow + arch_t * 1.2
				var arch_aabb := AABB(Vector3(x0, y0, pz - pw * 0.48),
					Vector3(absf(px - wall_x), y1 - y0, pw * 0.96))
				component_note("arch_web", "arc_ribbon", SURF_STONE,
					{"from_p": from_p, "to_p": to_p, "rise": bow,
						"thickness": arch_t, "depth": pw * 0.88,
						"steps": 8, "aabb": arch_aabb})
				component_note("arch_coping", "arc_ribbon", SURF_TRIM,
					{"from_p": from_p + Vector3.UP * coping_lift,
						"to_p": to_p + Vector3.UP * coping_lift, "rise": bow,
						"thickness": arch_t * 0.24, "depth": pw * 0.96,
						"steps": 8, "aabb": arch_aabb})
				_log_mass("flyer_arch_%s_%d_%d"
					% ["left" if side < 0.0 else "right", i, tier],
					arch_aabb)
				host_end()


## A lantern tower over the crossing: the silhouette of Durham and Salisbury.
func _build_crossing_tower() -> void:
	if not spec.crossing_tower:
		return
	tag("crossing_tower")
	var a: AABB = ChurchGeometry.crossing_tower_aabb(spec)
	var side: float = a.size.x
	var cz: float = ChurchGeometry.crossing_center_z(spec)
	var th: float = spec.crossing_tower_height
	var bearing_thickness: float = 0.28
	var bearing_top: float = a.position.y + 0.03
	var bay: float = a.size.z
	# Tie the four crossing walls into a bearing frame; leave the crossing open.
	host("crossing_tower_bearing")
	for side_sign in [-1.0, 1.0]:
		component_box("crossing_tower_bearing_side",
			Vector3(NAVE_WALL_T, bearing_thickness, bay),
			Transform3D(Basis(), Vector3(side_sign * (side * 0.5 - NAVE_WALL_T * 0.5),
				bearing_top - bearing_thickness * 0.5, cz)), SURF_STONE)
		component_box("crossing_tower_bearing_end",
			Vector3(side, bearing_thickness, NAVE_WALL_T),
			Transform3D(Basis(), Vector3(0.0,
				bearing_top - bearing_thickness * 0.5,
				cz + side_sign * (bay * 0.5 - NAVE_WALL_T * 0.5))), SURF_STONE)
	host_end()
	# the tower stands on the crossing BAY, so its plan is span x depth --
	# emitting a square here made the mesh overhang its own logged mass
	var tower_windows: Array[Dictionary] = []
	for face in range(4):
		tower_windows.append({"face": face,
			"u": cz if face % 2 == 1 else 0.0,
			"y": th - side * 0.22, "width": side * 0.22,
			"height": side * 0.3, "style": spec.window_style})
	_windowed_box_shell(a, tower_windows, false, false)
	_log_mass("crossing_tower", a, a.position.y)
	total_height = maxf(total_height, th)
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

	# What carries the drum. Randomly generated churches get a closed,
	# sloped square-to-drum loft whose upper ring shares the drum's sides and
	# phase. The three hero landmarks get masonry that reads as masonry: a
	# crossing octagon (Florence), a square bearing with piers and great arches
	# (Hagia Sophia).
	var drum_radius: float = r * (ChurchGeometry.OCTAGONAL_RADIUS_FACTOR if octagonal else 1.0)
	var rounded_hero: bool = spec.style == &"byzantine" and spec.dome_shape == &"hemisphere"
	var shell_segments: int = 8 if octagonal else (32 if rounded_hero else 16)
	var shell_start: float = PI / 8.0 if octagonal else 0.0
	var pendentive_h: float = ChurchGeometry.pendentive_height(spec)
	if ChurchGeometry.octagon_crossing(spec):
		_octagon_crossing(cz, base, drum_radius, pendentive_h)
	elif ChurchGeometry.hagia_bearing(spec):
		_hagia_bearing(cz, base, pendentive_h)
	else:
		_pendentive_support(Vector3(0.0, base, cz), r + 0.3, drum_radius,
			pendentive_h, shell_segments, shell_start, rounded_hero)
	_log_mass("pendentive", ChurchGeometry.pendentive_aabb(spec))
	# the corona of windows that lights every one of these domes
	var lights: int = 8 if octagonal else 12
	if ChurchGeometry.hagia_bearing(spec):
		lights = 16
	elif ChurchGeometry.basil_core(spec):
		lights = 8
	var angles: Array = []
	for i in range(lights):
		angles.append(TAU / lights * i)
	tag("dome")
	_arc_window_shell(Vector3(0, base + pendentive_h, cz),
		drum_radius, drum_h, shell_segments, TAU,
		shell_start, angles,
		r * 0.16, drum_h * 0.45, drum_h * 0.70, &"round")
	_log_mass("dome_drum", ChurchGeometry.dome_drum_aabb(spec))

	var top: float = base + pendentive_h + drum_h
	var rise: float = ChurchGeometry.dome_shell_rise(spec)
	if ChurchGeometry.basil_core(spec):
		_tent_core(Vector3(0, top, cz), drum_radius, rise, shell_segments)
		total_height = maxf(total_height, top + rise + ChurchGeometry.tent_cap_height(spec))
		return
	# Round hero shells use explicit fine tessellation. Florence stays an
	# eight-sided shell; its vertical profile is refined without changing that
	# deliberate plan.
	var segs: int = shell_segments
	# The octagonal drum uses a circumradius of 1.06r. Its shell must spring
	# from that same ring; using r left an open slot around all eight sides.
	preload("church_roofs.gd").dome(_kit, _dome_profile(
		drum_radius, rise), Vector3(0, top, cz), segs, _roof_volumes, TAU, shell_start)
	total_height = maxf(total_height, top + rise)

	if spec.dome_lantern:
		var lh: float = ChurchGeometry.lantern_height(spec)
		var lr: float = ChurchGeometry.lantern_radius(spec)
		_kit.prism(lr, lh, 8, Vector3(0, top + rise, cz), SURF_STONE)
		_kit.stepped_taper(Vector3(0, top + rise + lh, cz), ChurchGeometry.lantern_cap_width(spec),
			ChurchGeometry.lantern_cap_height(spec), SURF_ROOF, 3, 0.1)
		total_height = maxf(total_height, top + rise + lh)

	# Hagia Sophia braces its dome with half-domes east and west, themselves
	# carried on smaller semi-domed exedrae.
	if spec.half_domes:
		var hr: float = ChurchGeometry.half_dome_radius(spec)
		var half_rise: float = ChurchGeometry.half_dome_rise(spec)
		var half_segs: int = 12 if ChurchGeometry.hagia_bearing(spec) else 10
		for dir_v in [-1.0, 1.0]:
			var d: float = dir_v
			var start: float = 0.0 if d > 0.0 else PI
			var face_z: float = ChurchGeometry.half_dome_face_z(spec, d)
			preload("church_roofs.gd").dome(_kit, _dome_profile(hr, half_rise,
				8 if ChurchGeometry.hagia_bearing(spec) else 0),
				Vector3(0, base, face_z), half_segs, _roof_volumes, PI, start)
			if spec.exedrae:
				for ex_v in [-1.0, 1.0]:
					var er: float = hr * 0.4
					var ec := Vector3(ex_v * hr * 0.5, base * 0.55, cz + d * hr * 0.62)
					_kit.revolve(PackedVector2Array([Vector2(er, 0.0),
						Vector2(er, base * 0.3)]), ec, SURF_STONE, 8, PI, start)
					_kit.revolve(_dome_profile(er, er * 0.8),
						ec + Vector3(0, base * 0.3, 0), SURF_ROOF, 8, PI, start)


# ------------------------------------------------------------ Florence

## The octagonal crossing: eight masonry faces as wide as the dome, with a
## window in each face the nave does not enter, and a cornice that carries the
## drum. The nave runs into the west face; three tribunes ring the rest.
func _octagon_crossing(cz: float, base: float, drum_radius: float,
		pendentive_h: float) -> void:
	tag("crossing")
	var lights: Array = []
	for k in range(8):
		var bearing: float = wrapf(float(k) * PI / 4.0, -PI + 0.001, PI + 0.001)
		if absf(absf(bearing) - PI) < 0.01:
			continue          # the west face opens onto the nave
		lights.append(bearing)
	var block_radius: float = ChurchGeometry.octagon_circumradius(spec)
	_arc_window_shell(Vector3(0, 0, cz), block_radius, base, 8, TAU, PI / 8.0,
		lights, block_radius * 0.13, base * 0.17, base * 0.82, &"round")
	_log_mass("crossing_octagon", ChurchGeometry.octagon_aabb(spec))
	# two string courses divide the tall block, and the drum stands back from
	# it on a chamfered stone ledge
	for course in [0.40, 0.66]:
		_kit.drum(Vector3(0, base * course, cz), block_radius * 1.012,
			block_radius * 1.012, maxf(base * 0.008, 0.15), SURF_TRIM, 8, PI / 8.0)
	_kit.drum(Vector3(0, base, cz), block_radius * 1.01, drum_radius,
		pendentive_h, SURF_TRIM, 8, PI / 8.0)


## Three tribunes -- east, south and north -- as half-drums as wide as an
## octagon face, each lit by three windows and roofed by a half cone.
func _build_tribunes() -> void:
	var count: int = ChurchGeometry.tribune_count(spec)
	if count <= 0:
		return
	tag("tribune")
	var rt: float = ChurchGeometry.tribune_radius(spec)
	var ht: float = ChurchGeometry.tribune_height(spec)
	for i in range(count):
		var c: Vector3 = ChurchGeometry.tribune_center(spec, i)
		var phi: float = ChurchGeometry.tribune_angle(spec, i)
		var start: float = ChurchGeometry.tribune_arc_start(spec, i)
		_arc_window_shell(Vector3(c.x, 0.0, c.z), rt, ht, 7, PI, start,
			[phi - PI / 7.0, phi, phi + PI / 7.0], rt * 0.2, ht * 0.42, ht * 0.5,
			spec.window_style, true)
		_log_mass("tribune_%d" % i, ChurchGeometry.tribune_aabb(spec, i))
		_oriented_half_cone(Vector3(c.x, ht, c.z), rt + ChurchGeometry.APSE_EAVE,
			rt * 0.9, start, SURF_ROOF)


## A half cone over a half-drum whose arc starts at `start` (revolve angle
## space). The apse's own cap is the start = 0 case.
func _oriented_half_cone(pos: Vector3, radius: float, height: float, start: float,
		s: int) -> void:
	for i in range(10):
		var a: float = start + PI * float(i) / 10.0
		var b: float = start + PI * float(i + 1) / 10.0
		_kit.slab_poly(PackedVector3Array([pos + Vector3(cos(a) * radius, 0, sin(a) * radius),
			pos + Vector3(cos(b) * radius, 0, sin(b) * radius), pos + Vector3(0, height, 0)]),
			RoofShape.DEPTH, s, true)


# ------------------------------------------------------------ Hagia Sophia

## A square masonry bearing under the drum: the crossing square the dome circle
## is inscribed in, closed top and bottom, with the four great arches drawn on
## its faces, windows under the north and south arches, and a pier at each
## corner that climbs past it. Half-domes spring from the east and west faces.
func _hagia_bearing(cz: float, base: float, pendentive_h: float) -> void:
	tag("bearing")
	var half: float = ChurchGeometry.hagia_bearing_half(spec)
	var hr: float = ChurchGeometry.half_dome_radius(spec)
	var bearing := AABB(Vector3(-half, base, cz - half),
		Vector3(half * 2.0, pendentive_h, half * 2.0))
	var holes: Array[Dictionary] = []
	for face in [1, 3]:
		for k in range(5):
			holes.append({"face": face, "u": cz + float(k - 2) * hr * 0.34,
				"y": base + pendentive_h * 0.42, "width": hr * 0.12,
				"height": pendentive_h * 0.40, "style": &"round"})
	_windowed_box_shell(bearing, holes, true, false)
	var top: float = ChurchGeometry.hagia_pier_top(spec)
	var size: float = ChurchGeometry.hagia_pier_size(spec)
	for sx_v in [-1.0, 1.0]:
		for sz_v in [-1.0, 1.0]:
			var pc: Vector3 = ChurchGeometry.hagia_pier_center(spec, sx_v, sz_v)
			box(Vector3(size, top - base, size),
				Vector3(pc.x, (base + top) * 0.5, pc.z), SURF_STONE)
			box(Vector3(size * 1.14, 0.3, size * 1.14),
				Vector3(pc.x, top + 0.15, pc.z), SURF_TRIM)
			_kit.spike(Vector2(size * 1.0, size * 1.0), size * 0.7,
				Vector3(pc.x, top + 0.3, pc.z), SURF_STONE)
	var arch_rise: float = pendentive_h * 0.97
	var thick: float = clampf(spec.dome_radius * 0.05, 0.25, 1.0)
	var index := 0
	for dir_v in [-1.0, 1.0]:
		host("great_arch_%d" % index)
		_great_arch(Vector3(0, base, cz + dir_v * (half + thick * 0.3)),
			Vector3.RIGHT, hr, arch_rise, thick)
		host_end()
		index += 1
		host("great_arch_%d" % index)
		_great_arch(Vector3(dir_v * (half + thick * 0.3), base, cz),
			Vector3.BACK, hr, arch_rise, thick)
		host_end()
		index += 1


## A semi-elliptical ring of dressed stones standing proud of the wall plane.
## `along` is the horizontal direction in that plane.
func _great_arch(center: Vector3, along: Vector3, rx: float, ry: float,
		thick: float) -> void:
	var steps := 16
	var prev: Vector3 = center + along * rx
	for k in range(1, steps + 1):
		var phi: float = PI * float(k) / float(steps)
		var p: Vector3 = center + along * (rx * cos(phi)) + Vector3.UP * (ry * sin(phi))
		var seg: Vector3 = p - prev
		var seg_len: float = seg.length()
		if seg_len > 0.001:
			var xf := Transform3D(Basis().looking_at(seg / seg_len, Vector3.UP),
				(prev + p) * 0.5)
			component_box("great_arch", Vector3(thick * 1.1, thick, seg_len * 1.08),
				xf, SURF_TRIM)
		prev = p


# ------------------------------------------------------------ floor

## The paving under nave, aisles, transept, tower bases and narthex
## (ChurchGeometry.floor_rects). Without it the closed shells' downward
## bottoms were the only faces at floor level: no floor to see from inside,
## and none for a walker to stand on.
func _build_floor() -> void:
	tag("floor")
	var t: float = ChurchGeometry.FLOOR_T
	for r in ChurchGeometry.floor_rects(spec):
		box(Vector3(r.size.x, t, r.size.y),
			Vector3(r.get_center().x, ChurchGeometry.FLOOR_LIFT - t / 2.0, r.get_center().y),
			SURF_STONE)


# ------------------------------------------------------------ St Basil's

## Podium: two stone courses reaching past the outermost chapel, so the whole
## cluster stands on one raised platform. The door is lifted onto it.
func _build_podium() -> void:
	var ph: float = ChurchGeometry.podium_height(spec)
	if ph <= 0.0:
		return
	tag("podium")
	var a: AABB = ChurchGeometry.podium_aabb(spec)
	var c: Vector3 = a.get_center()
	var inset: float = minf(1.0, PODIUM_STEP_INSET)
	box(Vector3(a.size.x, ph * 0.5, a.size.z), Vector3(c.x, ph * 0.25, c.z), SURF_STONE)
	box(Vector3(a.size.x - inset * 2.0, ph, a.size.z - inset * 2.0),
		Vector3(c.x, ph * 0.5, c.z), SURF_STONE)
	box(Vector3(a.size.x - inset * 2.0 + 0.3, 0.18, a.size.z - inset * 2.0 + 0.3),
		Vector3(c.x, ph + 0.09, c.z), SURF_TRIM)
	_log_mass("podium", a)


## The core is tented. An eight-gored tent, banded in stone, narrows to a small
## drum and a gilded onion with its cross.
func _tent_core(pos: Vector3, radius: float, rise: float, segments: int) -> void:
	var tent := PackedVector2Array()
	for row in [Vector2(1.0, 0.0), Vector2(0.96, 0.10), Vector2(0.80, 0.30),
			Vector2(0.58, 0.55), Vector2(0.36, 0.78), Vector2(0.18, 0.93),
			Vector2(0.14, 1.0)]:
		tent.append(Vector2(radius * row.x, rise * row.y))
	_kit.revolve(tent, pos, SURF_ROOF, segments)
	for band in [Vector2(0.80, 0.30), Vector2(0.58, 0.55), Vector2(0.36, 0.78)]:
		_kit.prism(radius * band.x + 0.12, maxf(rise * 0.025, 0.18), segments,
			pos + Vector3(0, rise * band.y, 0), SURF_TRIM)
	var cap: float = ChurchGeometry.tent_cap_height(spec)
	var tip: Vector3 = pos + Vector3(0, rise, 0)
	var neck: float = cap * 0.26
	_kit.prism(radius * 0.17, neck, 8, tip, SURF_STONE)
	_onion(tip + Vector3(0, neck, 0), radius * 0.26, cap * 0.5, Color("c9a227"), 12)
	_kit.spike(Vector2(radius * 0.05, radius * 0.05), cap * 0.24,
		tip + Vector3(0, neck + cap * 0.5, 0), SURF_TRIM)


## One chapel's tower: cornice, eight-sided windowed drum, painted onion and
## cross. Colour and heights come from the chapel's index, so neighbours differ.
func _basil_chapel_tower(i: int) -> void:
	var body_h: float = ChurchGeometry.chapel_body_height(spec, i)
	var dc: Vector3 = ChurchGeometry.chapel_drum_center(spec, i)
	var rd: float = ChurchGeometry.chapel_drum_radius(spec)
	var hd: float = ChurchGeometry.chapel_drum_height(spec, i)
	_arc_window_shell(Vector3(dc.x, body_h, dc.z), rd, hd, 8, TAU, PI / 8.0,
		[0.0, PI / 2.0, PI, -PI / 2.0], rd * 0.36, hd * 0.5, hd * 0.5, &"round", true)
	var top_y: float = body_h + hd
	_kit.prism(rd * 1.1, 0.25, 8, Vector3(dc.x, top_y - 0.25, dc.z), SURF_TRIM, PI / 8.0)
	var colour: Color = BASIL_COLOURS[(i * 3 + 1) % BASIL_COLOURS.size()]
	_onion(Vector3(dc.x, top_y, dc.z), rd, ChurchGeometry.chapel_onion_rise(spec),
		colour, 12)
	var spike: float = ChurchGeometry.chapel_spike_height(spec)
	_kit.spike(Vector2(rd * 0.12, rd * 0.12), spike,
		Vector3(dc.x, top_y + ChurchGeometry.chapel_onion_rise(spec), dc.z), SURF_TRIM)


## A painted onion: its own vertex-coloured surface.
func _onion(center: Vector3, radius: float, rise: float, colour: Color,
		segments: int) -> void:
	var st: SurfaceTool = _kit.surface(SURF_ACCENT)
	st.set_color(colour)
	_kit.revolve(_onion_profile(radius, rise), center, SURF_ACCENT, segments)
	st.set_color(Color.WHITE)


static func _onion_profile(radius: float, rise: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	# bulges past the springing radius, then draws in to a point
	for v in [Vector2(1.0, 0.0), Vector2(1.14, 0.24), Vector2(1.05, 0.46),
			Vector2(0.78, 0.68), Vector2(0.42, 0.86), Vector2(0.0, 1.0)]:
		pts.append(Vector2(radius * v.x, rise * v.y))
	return pts


## A closed loft from the square crossing to the drum's exact lower ring. The
## inclined facets are the support, not four detached triangular blades.
func _pendentive_support(center: Vector3, lower_half: float, upper_radius: float,
		height: float, segments: int, start: float, articulated: bool = false) -> void:
	# Several metric stone courses turn the old straight-sided funnel into a
	# curved bearing. The lower ring is exactly the square crossing; the final
	# ring uses the drum's exact radius, phase and vertex count.
	var rings: Array[PackedVector3Array] = []
	for row in range(PENDENTIVE_PROFILE_STEPS + 1):
		var t := float(row) / float(PENDENTIVE_PROFILE_STEPS)
		rings.append(_pendentive_ring(center, lower_half, upper_radius, height,
			segments, start, t, false))
		if articulated and PENDENTIVE_LEDGE_ROWS.has(row):
			# Each corbel course steps out, rises as a short fascia, then returns
			# to the curved bearing. The overhang is clamped to the crossing's
			# square envelope, so the roof-cut boundary does not grow.
			rings.append(_pendentive_ring(center, lower_half, upper_radius, height,
				segments, start, t, true))
			var ledge_top := t + PENDENTIVE_LEDGE_RISE / height
			rings.append(_pendentive_ring(center, lower_half, upper_radius, height,
				segments, start, ledge_top, true))
			rings.append(_pendentive_ring(center, lower_half, upper_radius, height,
				segments, start, ledge_top, false))
	var wall_thickness: float = NAVE_WALL_T
	var inner_rings: Array[PackedVector3Array] = []
	var all_points := PackedVector3Array()
	for ring in rings:
		all_points.append_array(ring)
		var inner := PackedVector3Array()
		for point in ring:
			var radial := Vector2(point.x - center.x, point.z - center.z)
			var inner_radius: float = maxf(radial.length() - wall_thickness, 0.05)
			var direction: Vector2 = radial.normalized()
			var inner_point := Vector3(center.x + direction.x * inner_radius,
				point.y, center.z + direction.y * inner_radius)
			inner.append(inner_point)
			all_points.append(inner_point)
		inner_rings.append(inner)
	var st: SurfaceTool = _kit.surface(SURF_STONE)
	for row in range(rings.size() - 1):
		var lower := rings[row]
		var upper := rings[row + 1]
		var inner_lower := inner_rings[row]
		var inner_upper := inner_rings[row + 1]
		for i in range(segments):
			var next := (i + 1) % segments
			_kit._quad(st, lower[i], lower[next], upper[next], upper[i])
			_kit._quad(st, inner_lower[i], inner_upper[i], inner_upper[next], inner_lower[next])
	var bottom := rings[0]
	var inner_bottom := inner_rings[0]
	var top: PackedVector3Array = rings[rings.size() - 1]
	var inner_top: PackedVector3Array = inner_rings[inner_rings.size() - 1]
	for i in range(segments):
		var next := (i + 1) % segments
		# Close only the bearing bands. The square and drum centers remain open.
		_kit._quad(st, bottom[i], inner_bottom[i], inner_bottom[next], bottom[next])
		_kit._quad(st, top[i], top[next], inner_top[next], inner_top[i])
	var envelope := AABB(center + Vector3(-lower_half, 0.0, -lower_half),
		Vector3(lower_half * 2.0, height, lower_half * 2.0))
	_log_part("pendentive", center + Vector3.UP * (height * 0.5),
		Vector3(lower_half * 2.0, height, lower_half * 2.0))
	host("dome")
	component_note("pendentive_support", "curved_loft", SURF_STONE, {
		"center": center, "lower_half": lower_half, "upper_radius": upper_radius,
		"height": height, "segments": segments, "start": start,
		"profile_steps": PENDENTIVE_PROFILE_STEPS, "articulated": articulated,
		"vertices": all_points,
		"aabb": envelope})
	host_end()


func _pendentive_ring(center: Vector3, lower_half: float, upper_radius: float,
		height: float, segments: int, start: float, t: float,
		ledge: bool) -> PackedVector3Array:
	var eased := t * t * (3.0 - 2.0 * t)
	var curve := pow(eased, 1.35)
	var ring := PackedVector3Array()
	for i in range(segments):
		var angle := start + TAU * float(i) / float(segments)
		var direction := Vector2(cos(angle), sin(angle))
		var square_radius: float = lower_half / maxf(absf(direction.x), absf(direction.y))
		var radius: float = lerpf(square_radius, upper_radius, curve)
		if ledge:
			radius += minf(PENDENTIVE_LEDGE_WIDTH, maxf(0.0, square_radius - radius))
		ring.append(center + Vector3(direction.x * radius, height * t,
			direction.y * radius))
	return ring


## Profile of a dome shell, bottom to top: hemispherical, or the ogee curve
## that gives an onion dome its shoulder and point.
func _dome_profile(radius: float, rise: float, steps_override := 0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if spec.dome_shape == &"onion":
		return _onion_profile(radius, rise)
	var hero_shell: bool = (spec.style == &"byzantine" and spec.dome_shape == &"hemisphere") \
		or (spec.style == &"renaissance" and spec.dome_shape == &"octagonal")
	var steps: int = 12 if hero_shell else 6
	if steps_override > 0:
		steps = steps_override
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
func half_cylinder(radius: float, height: float, center: Vector2, s: int,
		open_ends: bool = false) -> void:
	_kit.half_cylinder(radius, height, center, s, 10, open_ends)

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
			# Seat the glazed pane at the inner lip. The ray fixture probes stone,
			# so glazing cannot disguise an uncut masonry host.
			_kit.surface(SURF_OPEN).set_color(Color.BLACK)
			component_box("clerestory_pane",
				Vector3(width - 0.08, height - 0.08, 0.025),
				xf.translated_local(Vector3(0, 0, -NAVE_WALL_T + 0.035)), SURF_OPEN)
			_kit.surface(SURF_OPEN).set_color(Color.WHITE)
			# Two stone spandrels fill the rectangular cut above its pointed
			# crown. The pane remains at the far reveal, behind real wall depth.
			var crown_y: float = height * 0.18
			var wall_mid: float = -NAVE_WALL_T * 0.5 + ChurchGeometry.OPENING_EPS
			for side in [-1.0, 1.0]:
				var points := PackedVector3Array([
					xf * Vector3(side * width * 0.5, crown_y, wall_mid),
					xf * Vector3(side * width * 0.5, height * 0.5, wall_mid),
					xf * Vector3(0, height * 0.5, wall_mid),
				])
				component_slab("clerestory_spandrel", points, NAVE_WALL_T,
					SURF_STONE, false)
		component_box("clerestory_mullion", Vector3(mullion, height, 0.09),
			xf.translated_local(Vector3(0, 0, 0.03)), SURF_TRIM)
		if _cuts_clerestory():
			component_box("clerestory_transom",
				Vector3(width - 0.06, mullion * 0.75, 0.09),
				xf.translated_local(Vector3(0, height * 0.07, 0.03)), SURF_TRIM)
		component_box("clerestory_sill", Vector3(width + mullion * 3, mullion, 0.18),
			xf.translated_local(Vector3(0, -height / 2.0, 0.02)), SURF_TRIM)
		host_end()


## A dressed but deliberately open entrance. Its jambs and hood sit outside
## the throat, so they do not seal the approach tested by the aperture suite.
func _portal_moulding(opening: Dictionary, index: int) -> void:
	var width: float = opening.width
	var height: float = opening.height
	var face_pos: Vector3 = opening.pos
	if spec.west_towers >= 2:
		face_pos.z = ChurchGeometry.tower_center_z(spec) - spec.tower_width * 0.5 \
			- ChurchGeometry.OPENING_EPS
	var xf := Transform3D(Basis(Vector3.UP, PI), face_pos)
	host("west_portal_%d" % index)
	var jamb := 0.18
	for side in [-1.0, 1.0]:
		component_box("portal_jamb", Vector3(jamb, height, 0.24),
			xf.translated_local(Vector3(side * (width * 0.5 + jamb * 0.5),
				0, 0.08)), SURF_TRIM)
	component_box("portal_lintel", Vector3(width + jamb * 2.0, jamb, 0.28),
		xf.translated_local(Vector3(0, height * 0.5 + jamb * 0.5, 0.08)), SURF_TRIM)
	if opening.style == &"pointed":
		var spring := height * 0.5 + jamb * 0.5
		var crown := spring + minf(width * 0.23, 0.85)
		for side in [-1.0, 1.0]:
			_portal_hood_segment(xf, Vector2(side * width * 0.5, spring),
				Vector2(0, crown))
	host_end()


func _portal_hood_segment(xf: Transform3D, start: Vector2, finish: Vector2) -> void:
	var edge := (finish - start).normalized()
	var cross := Vector2(-edge.y, edge.x) * 0.075
	var points := PackedVector3Array()
	for p in [start + cross, finish + cross, finish - cross, start - cross]:
		points.append(xf * Vector3(p.x, p.y, 0.08))
	component_slab("portal_hood", points, 0.24, SURF_TRIM, false)

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
		if not door and _tag != "clerestory":
			var glass := Transform3D(Basis(Vector3.UP, face), pos).translated_local(
				Vector3(0, 0, -NAVE_WALL_T + 0.035))
			host("glazing_%s_%d" % [_tag, part_log.size()])
			_kit.surface(SURF_OPEN).set_color(Color.BLACK)
			component_box("window_pane", Vector3(w - 0.08, h - 0.08, 0.025),
				glass, SURF_OPEN)
			_kit.surface(SURF_OPEN).set_color(Color.WHITE)
			host_end()
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
	var rr: float = _rose_radius()
	_log_part("window", pos, Vector3(rr * 2.0, rr * 2.0, 0.0),
		face, basis * Vector3(0, 0, 1))
	part_log.back()["aperture"] = "through"
	var t := Transform3D(basis, pos)
	var st: SurfaceTool = _kit.surface(SURF_OPEN)
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
	# The inscribed masonry cut is hidden by a continuous stone ring, not a
	# stair-step silhouette around the circular tracery.
	host("west_rose")
	for i in range(seg):
		var a: float = TAU / seg * (float(i) + 0.5)
		var ring := t * Transform3D(Basis(Vector3(0, 0, 1), a + PI * 0.5),
			Vector3(cos(a) * rr, sin(a) * rr, 0.045))
		component_box("rose_ring", Vector3(rr * TAU / seg * 1.05, 0.14, 0.12),
			ring, SURF_TRIM)
	host_end()
