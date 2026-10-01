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
const PENDENTIVE_PROFILE_STEPS := 6

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
				var aisle: AABB = ChurchGeometry.aisle_aabb(spec, side, ring)
				var aisle_windows: Array[Dictionary] = []
				if ring == spec.aisles - 1:
					var nwin: int = int(al / 3.0)
					for i in range(nwin):
						var wz: float = az0 + al / float(nwin + 1) * (i + 1)
						aisle_windows.append({"face": 1 if side > 0.0 else 3,
							"u": wz, "y": ah * 0.5, "width": 0.7,
							"height": ah * 0.33, "style": spec.window_style})
				_windowed_box_shell(aisle, aisle_windows)
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
		for sx_v in [-1.0, 1.0]:
			transept_windows.append({"face": 1 if sx_v > 0.0 else 3,
				"u": tz_z, "y": h * 0.55, "width": spec.window_w,
				"height": spec.window_h, "style": spec.window_style})
		_windowed_box_shell(transept, transept_windows)
		_log_mass("transept", transept)
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
			apse_light_y, spec.window_style, true)
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
		var tower_windows: Array[Dictionary] = []
		for face in range(4):
			tower_windows.append({"face": face,
				"u": lz if face % 2 == 1 else lx,
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
					tower_windows.append({"face": face, "u": (left + right) * 0.5,
						"y": portal.pos.y, "width": right - left,
						"height": portal.height, "style": portal.style, "log": false})
				if left <= x0 + NAVE_WALL_T:
					tower_windows.append({"face": 3, "u": lz,
						"y": portal.pos.y, "width": tw,
						"height": portal.height, "style": portal.style, "log": false})
				if right >= x1 - NAVE_WALL_T:
					tower_windows.append({"face": 1, "u": lz,
						"y": portal.pos.y, "width": tw,
						"height": portal.height, "style": portal.style, "log": false})
		if spec.west_towers == 1 and spec.rose_window:
			tower_windows.append_array(_rose_holes(2, lx, _rose_y(),
				_rose_radius()))
		_windowed_box_shell(ChurchGeometry.tower_aabb(spec, side), tower_windows)
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
				_stepped_buttress("nave_%s_%d" % ["left" if side_v < 0.0 else "right", i],
					Vector3(side_v * w / 2.0, 0.0, bz), Vector3(side_v, 0.0, 0.0),
					h * 0.72, bd, 0.5, false)
		if spec.tower:
			var tw2: float = spec.tower_width
			var th2: float = spec.tower_height
			for tower_side in ChurchGeometry.west_tower_sides(spec):
				var tx: float = ChurchGeometry.tower_center_x(spec, tower_side)
				var tz: float = ChurchGeometry.tower_center_z(spec)
				for cx_v in [-1.0, 1.0]:
					for cz_v in [-1.0, 1.0]:
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
		box(Vector3(w + 0.35, 0.18, l + 0.35), Vector3(0, h * 0.62, 0), SURF_TRIM)
		if spec.tower:
			var lz3: float = -l / 2.0 + TOWER_EMBED - spec.tower_width / 2.0
			box(Vector3(spec.tower_width + 0.3, 0.18, spec.tower_width + 0.3),
				Vector3(0, h * 0.62, lz3), SURF_TRIM)

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
		Vector3(0, door_h + 0.35, door_z - 0.02), SURF_TRIM)

	# ---------- nave windows when there are no aisles ----------
	tag("window")
	if spec.aisles == 0:
		var nw2: int = int(l / 3.2)
		for i in range(nw2):
			var wz2: float = -l / 2.0 + l / float(nw2 + 1) * (i + 1)
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
func _windowed_box_shell(a: AABB, openings: Array[Dictionary]) -> void:
	for face in range(4):
		var holes: Array[Dictionary] = []
		for opening in openings:
			if int(opening["face"]) == face:
				holes.append(opening)
		_box_wall_with_holes(a, face, holes)
	var st: SurfaceTool = _kit.surface(SURF_STONE)
	for y in [a.position.y, a.end.y]:
		_nave_plane(st, Vector3(a.position.x, y, a.position.z),
			Vector3(a.end.x, y, a.position.z), Vector3(a.end.x, y, a.end.z),
			Vector3(a.position.x, y, a.end.z),
			Vector3.DOWN if y == a.position.y else Vector3.UP)
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


func _box_wall_with_holes(a: AABB, face: int, holes: Array[Dictionary]) -> void:
	var u0: float = a.position.x if face % 2 == 0 else a.position.z
	var u1: float = a.end.x if face % 2 == 0 else a.end.z
	var edges: Array[float] = [u0, u1]
	for hole in holes:
		edges.append(clampf(float(hole["u"]) - float(hole["width"]) * 0.5, u0, u1))
		edges.append(clampf(float(hole["u"]) + float(hole["width"]) * 0.5, u0, u1))
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
			bands.append(clampf(float(hole["y"]) + float(hole["height"]) * 0.5,
				a.position.y, a.end.y))
		bands.sort()
		for j in range(bands.size() - 1):
			var bottom: float = bands[j]
			var top: float = bands[j + 1]
			if top - bottom < 0.001:
				continue
			var y: float = (bottom + top) * 0.5
			var cut := false
			for hole in holes:
				if absf(mid - float(hole["u"])) < float(hole["width"]) * 0.5 \
						and absf(y - float(hole["y"])) < float(hole["height"]) * 0.5:
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
			box(size, pos, SURF_STONE)


## Revolved wall facets are chords. The selected window is centred on its
## actual chord and the neighbouring stone panels stop at its jamb, head and
## sill. An odd half-sweep count supplies a central facet for the apse/chapel.
func _arc_window_shell(center: Vector3, radius: float, height: float,
		segments: int, arc: float, start: float, face_angles: Array,
		width: float, opening_h: float, opening_y: float,
		style: StringName, cap_top := false) -> void:
	var cut_faces: Dictionary = {}
	var step: float = arc / float(segments)
	for angle in face_angles:
		var theta: float = wrapf(PI * 0.5 - float(angle) - start, 0.0, TAU)
		var index: int = clampi(roundi(theta / step - 0.5), 0, segments - 1)
		cut_faces[index] = true
	var st: SurfaceTool = _kit.surface(SURF_STONE)
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
	if arc < TAU - 0.001:
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
			+ Vector3.UP * (y0 + y1) * 0.5, SURF_STONE, face)


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
	var holes: Array[Dictionary] = []
	if _cuts_clerestory():
		for opening in ChurchGeometry.clerestory_windows(spec):
			holes.append({"face": 1 if opening.pos.x > 0.0 else 3,
				"u": opening.pos.z, "y": opening.pos.y,
				"width": opening.width, "height": opening.height,
				"style": spec.window_style, "log": false})
	if spec.aisles == 0:
		var count: int = int(l / 3.2)
		for i in range(count):
			var z: float = -l * 0.5 + l / float(count + 1) * (i + 1)
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
	_windowed_box_shell(AABB(Vector3(-w * 0.5, 0, -l * 0.5),
		Vector3(w, h, l)), holes)


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
	_windowed_box_shell(a, holes)
	_log_mass("narthex", a)


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
		_arc_window_shell(Vector3(c.x, 0.0, c.z), chr_r, chh, 7, PI,
			ChurchGeometry.chapel_arc_start(spec, i), [a], 0.6,
			chh * 0.4, chh * 0.45, spec.window_style)
		_log_mass("chapel_%d" % i, ChurchGeometry.chapel_aabb(spec, i))
		_kit.stepped_taper(Vector3(c.x, chh, c.z), chr_r * 2.0 + 0.2, chr_r * 0.6,
			SURF_ROOF, 3, 0.15, true, 0.0, 0.8)


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
	# the tower stands on the crossing BAY, so its plan is span x depth --
	# emitting a square here made the mesh overhang its own logged mass
	var tower_windows: Array[Dictionary] = []
	for face in range(4):
		tower_windows.append({"face": face,
			"u": cz if face % 2 == 1 else 0.0,
			"y": th - side * 0.22, "width": side * 0.22,
			"height": side * 0.3, "style": spec.window_style})
	_windowed_box_shell(a, tower_windows)
	_log_mass("crossing_tower", a)
	total_height = maxf(total_height, th)
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

	# pendentives: a closed, sloped square-to-drum transition. The upper ring
	# uses the same sides and phase as the drum, so the latter rests on it.
	var drum_radius: float = r * (ChurchGeometry.OCTAGONAL_RADIUS_FACTOR if octagonal else 1.0)
	var rounded_hero: bool = spec.style == &"byzantine" and spec.dome_shape == &"hemisphere"
	var shell_segments: int = 8 if octagonal else (32 if rounded_hero else 16)
	var shell_start: float = PI / 8.0 if octagonal else 0.0
	_pendentive_support(Vector3(0.0, base, cz), r + 0.3, drum_radius,
		ChurchGeometry.PENDENTIVE_H, shell_segments, shell_start)
	_log_mass("pendentive", ChurchGeometry.pendentive_aabb(spec))
	# the corona of windows that lights every one of these domes
	var lights: int = 8 if octagonal else 12
	var angles: Array = []
	for i in range(lights):
		angles.append(TAU / lights * i)
	_arc_window_shell(Vector3(0, base + ChurchGeometry.PENDENTIVE_H, cz),
		drum_radius, drum_h, shell_segments, TAU,
		shell_start, angles,
		r * 0.16, drum_h * 0.45, drum_h * 0.70, &"round")
	_log_mass("dome_drum", ChurchGeometry.dome_drum_aabb(spec))

	var top: float = base + ChurchGeometry.PENDENTIVE_H + drum_h
	var rise: float = ChurchGeometry.dome_shell_rise(spec)
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


## A closed loft from the square crossing to the drum's exact lower ring. The
## inclined facets are the support, not four detached triangular blades.
func _pendentive_support(center: Vector3, lower_half: float, upper_radius: float,
		height: float, segments: int, start: float) -> void:
	# Several metric stone courses turn the old straight-sided funnel into a
	# curved bearing. The lower ring is exactly the square crossing; the final
	# ring uses the drum's exact radius, phase and vertex count.
	var rings: Array[PackedVector3Array] = []
	for row in range(PENDENTIVE_PROFILE_STEPS + 1):
		var t := float(row) / float(PENDENTIVE_PROFILE_STEPS)
		var eased := t * t * (3.0 - 2.0 * t)
		var curve := pow(eased, 1.35)
		var ring := PackedVector3Array()
		for i in range(segments):
			var angle := start + TAU * float(i) / float(segments)
			var direction := Vector2(cos(angle), sin(angle))
			var square_radius: float = lower_half / maxf(absf(direction.x), absf(direction.y))
			var radius: float = lerpf(square_radius, upper_radius, curve)
			ring.append(center + Vector3(direction.x * radius, height * t,
				direction.y * radius))
		rings.append(ring)
	var all_points := PackedVector3Array()
	for ring in rings:
		all_points.append_array(ring)
	var st: SurfaceTool = _kit.surface(SURF_STONE)
	for row in range(rings.size() - 1):
		var lower := rings[row]
		var upper := rings[row + 1]
		for i in range(segments):
			var next := (i + 1) % segments
			_kit._quad(st, lower[i], lower[next], upper[next], upper[i])
	var bottom := rings[0]
	var top := rings.back()
	for i in range(segments):
		var next := (i + 1) % segments
		_kit._tri(st, center, bottom[next], bottom[i])
		_kit._tri(st, center + Vector3.UP * height, top[i], top[next])
	var envelope := AABB(center + Vector3(-lower_half, 0.0, -lower_half),
		Vector3(lower_half * 2.0, height, lower_half * 2.0))
	_log_part("pendentive", center + Vector3.UP * (height * 0.5),
		Vector3(lower_half * 2.0, height, lower_half * 2.0))
	host("dome")
	component_note("pendentive_support", "curved_loft", SURF_STONE, {
		"center": center, "lower_half": lower_half, "upper_radius": upper_radius,
		"height": height, "segments": segments, "start": start,
		"profile_steps": PENDENTIVE_PROFILE_STEPS, "vertices": all_points,
		"aabb": envelope})
	host_end()


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
	var hero_shell: bool = (spec.style == &"byzantine" and spec.dome_shape == &"hemisphere") \
		or (spec.style == &"renaissance" and spec.dome_shape == &"octagonal")
	var steps: int = 12 if hero_shell else 6
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
