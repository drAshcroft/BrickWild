class_name ChurchBuilder
extends RefCounted
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
var _sts: Array = []
var total_height := 0.0
## QA log: one entry per primitive placed during build().
## {kind:"box", pos:Vector3, size:Vector3, rot_y:float, tag:String}
var part_log: Array = []
## QA log: one entry per STRUCTURAL MASS (the load-bearing volumes a person
## would name when describing the building). Unlike part_log this records the
## true world-space AABB of the volume as actually emitted, so correctness
## checks measure geometry rather than re-deriving it from the spec.
## {name:String, aabb:AABB}
var mass_log: Array[Dictionary] = []
var _tag := ""

func _log_part(kind: String, pos: Vector3, size := Vector3.ZERO, rot_y := 0.0) -> void:
	part_log.append({"kind": kind, "pos": pos, "size": size, "rot_y": rot_y, "tag": _tag})

## Record a structural mass by its true world AABB.
func _log_mass(mass_name: String, aabb: AABB) -> void:
	mass_log.append({"name": mass_name, "aabb": aabb.abs()})


## Tag subsequent parts (e.g. "nave", "transept", "tower") for diagnostics.
func tag(t: String) -> void:
	_tag = t

func build(p_spec: ChurchSpec) -> ArrayMesh:
	spec = p_spec
	part_log.clear()
	mass_log.clear()
	_sts.clear()
	for i in range(4):
		var s := SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		_sts.append(s)

	var w: float = spec.width
	var l: float = spec.length
	var h: float = spec.height

	total_height = h

	# ---------- nave ----------
	tag("nave")
	box(Vector3(w, h, l), Vector3(0, h / 2.0, 0), SURF_STONE)
	_log_mass("nave", AABB(Vector3(-w / 2.0, 0.0, -l / 2.0), Vector3(w, h, l)))
	gable_roof(w + 0.5, l + 0.4, w * spec.roof_pitch, 0.0, SURF_ROOF, h)
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
		if true:
			for side_v in [-1.0, 1.0]:
				var side: float = side_v
				var ax: float = ChurchGeometry.aisle_center_x(spec, side)
				box(Vector3(aw, h * 0.55, al), Vector3(ax, h * 0.275, az), SURF_STONE)
				_log_mass("aisle_%s" % ("left" if side < 0.0 else "right"),
					ChurchGeometry.aisle_aabb(spec, side))
				_lean_roof(aw + 0.6, al + 0.4, h * 0.55, h * 0.55 + aw * 0.8, side, SURF_ROOF, az)
				var nwin: int = int(al / 3.0)
				for i in range(nwin):
					var wz: float = az0 + al / float(nwin + 1) * (i + 1)
					window(Vector3(ax + side * (aw / 2.0 + 0.02), h * 0.28, wz), 0.0,
						0.7, h * 0.18, spec.window_style)
		if spec.clerestory and spec.aisles > 0:
			var ncl: int = int(al / 3.5)
			for i in range(ncl):
				var cz: float = az0 + al / float(ncl + 1) * (i + 1)
				for side_v2 in [-1.0, 1.0]:
					window(Vector3(side_v2 * (w / 2.0 + 0.02), h * 0.78, cz), 0.0,
						0.55, 0.7, &"round")

	# ---------- transept ----------
	tag("transept")
	if spec.transept:
		var tz_len: float = spec.transept_len
		var tz_w: float = ChurchGeometry.transept_depth(spec)
		var tz_z: float = ChurchGeometry.transept_center_z(spec)
		box(Vector3(tz_len, h, tz_w), Vector3(0, h / 2.0, tz_z), SURF_STONE)
		_log_mass("transept", ChurchGeometry.transept_aabb(spec))
		gable_roof(tz_len + 0.5, tz_w + 0.4, w * spec.roof_pitch * 0.9, tz_z, SURF_ROOF, h)
		for sx_v in [-1.0, 1.0]:
			window(Vector3(sx_v * (tz_len / 2.0 + 0.02), h * 0.55, tz_z), PI / 2.0,
				spec.window_w, spec.window_h, spec.window_style)
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
	if spec.tower:
		var tw: float = spec.tower_width
		var th: float = spec.tower_height
		# Tower abuts the west wall: only EMBED m penetrates the nave so the
		# mass reads as joined, not swallowed. Front (east) face at -l/2+EMBED.
		var lz: float = ChurchGeometry.tower_center_z(spec)
		box(Vector3(tw, th, tw), Vector3(0, th / 2.0, lz), SURF_STONE)
		_log_mass("tower", ChurchGeometry.tower_aabb(spec))
		total_height = maxf(total_height, th)
		for side_i in range(4):
			var ang: float = PI / 2.0 * side_i
			var off := Vector3(sin(ang) * (tw / 2.0 + 0.02), 0, cos(ang) * (tw / 2.0 + 0.02))
			window(Vector3(off.x, th - tw * 0.28, lz + off.z), ang,
				tw * 0.32, tw * 0.26, &"square")
		match spec.tower_roof:
			&"spire":
				_pyramid_roof(Vector3(0, th, lz), tw + 0.5, tw * spec.spire_pitch * 2.2, SURF_ROOF, true)
				total_height = maxf(total_height, th + tw * spec.spire_pitch * 2.2)
				pinnacle(Vector3(0, th + tw * spec.spire_pitch * 2.2, lz))
			&"pyramid":
				_pyramid_roof(Vector3(0, th, lz), tw + 0.5, tw * 0.75, SURF_ROOF, false)
				total_height = maxf(total_height, th + tw * 0.75)
			&"belfry":
				_pyramid_roof(Vector3(0, th, lz), tw + 0.5, tw * 0.4, SURF_ROOF, false)
				for cx_v in [-1.0, 1.0]:
					for cz_v in [-1.0, 1.0]:
						box(Vector3(0.22, tw * 0.35, 0.22),
							Vector3(cx_v * (tw / 2.0 - 0.15), th + tw * 0.17, lz + cz_v * (tw / 2.0 - 0.15)), SURF_STONE)
			_:
				box(Vector3(tw + 0.4, 0.3, tw + 0.4), Vector3(0, th + 0.15, lz), SURF_TRIM)

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
	var door_z: float = -l / 2.0 - 0.02
	if spec.tower:
		door_z = -l / 2.0 + TOWER_EMBED - spec.tower_width - 0.02
	var door_h: float = minf(h * 0.32, 3.4)
	match spec.door_style:
		&"twin":
			window(Vector3(-0.8, door_h / 2.0 + 0.1, door_z), PI, 0.85, door_h, &"round", true)
			window(Vector3(0.8, door_h / 2.0 + 0.1, door_z), PI, 0.85, door_h, &"round", true)
		&"portal":
			window(Vector3(0, door_h / 2.0 + 0.05, door_z), PI, w * 0.34, door_h, &"pointed", true)
		_:
			window(Vector3(0, door_h / 2.0 + 0.1, door_z), PI, 1.4, door_h, &"round", true)
	box(Vector3((w * 0.34 if spec.door_style == &"portal" else 2.4) + 0.7, 0.22, 0.14),
		Vector3(0, door_h + 0.35, door_z - 0.02), SURF_TRIM)

	# ---------- nave windows when there are no aisles ----------
	tag("window")
	if spec.aisles == 0:
		var nw2: int = int(l / 3.2)
		for i in range(nw2):
			var wz2: float = -l / 2.0 + l / float(nw2 + 1) * (i + 1)
			for sx_v in [-1.0, 1.0]:
				window(Vector3(sx_v * (w / 2.0 + 0.02), h * 0.58, wz2), 0.0,
					spec.window_w, spec.window_h, spec.window_style)

	# ---------- rose window ----------
	tag("facade")
	if spec.rose_window:
		rose(Vector3(0, h * 0.68, l / 2.0 + 0.02))

	var mesh := ArrayMesh.new()
	for st_v in _sts:
		var s2: SurfaceTool = st_v
		s2.generate_normals()
		s2.commit(mesh)
	return mesh

# ---------------------------------------------------------------- primitives

func box(size: Vector3, pos: Vector3, s: int, rot_y := 0.0) -> void:
	_log_part("box", pos, size, rot_y)
	var hx: float = size.x / 2.0
	var hy: float = size.y / 2.0
	var hz: float = size.z / 2.0
	var local := [
		Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz),
		Vector3(hx, -hy, hz), Vector3(-hx, -hy, hz), Vector3(-hx, hy, hz), Vector3(hx, hy, hz),
	]
	var basis := Basis(Vector3.UP, rot_y)
	var pts: Array = []
	for c in local:
		pts.append(pos + basis * c)
	var quads := [
		[0, 1, 2, 3], [4, 5, 6, 7],
		[1, 4, 7, 2], [5, 0, 3, 6],
		[3, 2, 7, 6], [0, 5, 4, 1],
	]
	var normals := [
		Vector3(0, 0, -1), Vector3(0, 0, 1),
		Vector3(1, 0, 0), Vector3(-1, 0, 0),
		Vector3(0, 1, 0), Vector3(0, -1, 0),
	]
	var uv3 := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]
	var st: SurfaceTool = _sts[s]
	for qi in range(quads.size()):
		var q: Array = quads[qi]
		for tri in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
			for vi in range(3):
				st.set_normal(normals[qi])
				st.set_uv(uv3[vi])
				st.add_vertex(pts[tri[vi]])

## Gable roof running along Z, centered at x=0.
## Gable roof capping a wall whose top is at y_base.
func gable_roof(span_x: float, along_z: float, rise: float, z_center: float, s: int,
		y_base := 0.0) -> void:
	var half_span: float = span_x / 2.0
	for side_v in [-1.0, 1.0]:
		_slab(along_z, rise, half_span, side_v, z_center, s, y_base)
	box(Vector3(0.35, 0.25, along_z + 0.2), Vector3(0, y_base + rise + 0.1, z_center), s)

## One sloped roof slab from eave (x=+/-half_span, y=y_base) to ridge
## (x=0, y=y_base+rise). y_base is the wall top this roof sits on.
func _slab(along: float, rise: float, half_span: float, side: float, zc: float,
		s: int, y_base := 0.0) -> void:
	var slope_len: float = sqrt(half_span * half_span + rise * rise)
	var ang: float = atan2(rise, half_span)
	var mid_x: float = side * half_span / 2.0
	var t := Transform3D(Basis(Vector3(0, 0, 1), -side * ang),
		Vector3(mid_x, y_base + rise / 2.0, zc))
	var corners := [
		Vector3(-slope_len / 2.0, -0.12, -along / 2.0), Vector3(slope_len / 2.0, -0.12, -along / 2.0),
		Vector3(slope_len / 2.0, 0.12, -along / 2.0), Vector3(-slope_len / 2.0, 0.12, -along / 2.0),
		Vector3(-slope_len / 2.0, -0.12, along / 2.0), Vector3(slope_len / 2.0, -0.12, along / 2.0),
		Vector3(slope_len / 2.0, 0.12, along / 2.0), Vector3(-slope_len / 2.0, 0.12, along / 2.0),
	]
	var pts: Array = []
	for c in corners:
		pts.append(t * c)
	# outward normal of the top face: perpendicular to slope, pointing away from ridge
	var n_top := Vector3(cos(ang) * side, sin(ang), 0)
	var quads := [[0, 1, 2, 3], [4, 5, 6, 7], [1, 5, 6, 2], [0, 4, 7, 3], [3, 2, 6, 7], [0, 1, 5, 4]]
	var normals := [Vector3(0, 0, -1), Vector3(0, 0, 1), n_top, -n_top, Vector3(0, 1, 0), Vector3(0, -1, 0)]
	var uv3 := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]
	var st: SurfaceTool = _sts[s]
	for qi in range(quads.size()):
		var q: Array = quads[qi]
		for tri in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
			for vi in range(3):
				st.set_normal(normals[qi])
				st.set_uv(uv3[vi])
				st.add_vertex(pts[tri[vi]])

## Lean-to aisle roof from y_base (outer eave) up to y_top (against nave wall).
func _lean_roof(span: float, along: float, y_base: float, y_top: float, side: float, s: int,
		z_center := 0.0) -> void:
	var rise: float = y_top - y_base
	var slope_len: float = sqrt(span * span + rise * rise)
	var ang: float = atan2(rise, span)
	var t := Transform3D(Basis(Vector3(0, 0, 1), -side * ang),
		Vector3(side * (span / 2.0 - 0.15), (y_base + y_top) / 2.0, z_center))
	var corners := [
		Vector3(-slope_len / 2.0, -0.1, -along / 2.0), Vector3(slope_len / 2.0, -0.1, -along / 2.0),
		Vector3(slope_len / 2.0, 0.1, -along / 2.0), Vector3(-slope_len / 2.0, 0.1, -along / 2.0),
		Vector3(-slope_len / 2.0, -0.1, along / 2.0), Vector3(slope_len / 2.0, -0.1, along / 2.0),
		Vector3(slope_len / 2.0, 0.1, along / 2.0), Vector3(-slope_len / 2.0, 0.1, along / 2.0),
	]
	var pts: Array = []
	for c in corners:
		pts.append(t * c)
	var n_top := Vector3(cos(ang) * side, sin(ang), 0)
	var quads := [[0, 1, 2, 3], [4, 5, 6, 7], [1, 5, 6, 2], [0, 4, 7, 3]]
	var normals := [Vector3(0, 0, -1), Vector3(0, 0, 1), n_top, -n_top]
	var uv3 := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]
	var st: SurfaceTool = _sts[s]
	for qi in range(quads.size()):
		var q: Array = quads[qi]
		for tri in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
			for vi in range(3):
				st.set_normal(normals[qi])
				st.set_uv(uv3[vi])
				st.add_vertex(pts[tri[vi]])

## Half-cylinder apse bulging toward +Z around center (x, z).
func half_cylinder(radius: float, height: float, center: Vector2, s: int) -> void:
	var segs: int = 10
	var st: SurfaceTool = _sts[s]
	var prev := Vector3(center.x, 0, center.y + radius)
	var prev_n := Vector3(0, 0, 1)
	for i in range(1, segs + 1):
		var a: float = PI - PI / segs * i
		var p := Vector3(center.x + cos(a) * radius, 0, center.y + sin(a) * radius)
		var n := Vector3(cos(a), 0, sin(a))
		_quad_wall(prev, p, prev_n, n, height, st)
		prev = p
		prev_n = n
	for i in range(segs):
		var a0: float = PI - PI / segs * i
		var a1: float = PI - PI / segs * (i + 1)
		var p0 := Vector3(center.x + cos(a0) * radius, height, center.y + sin(a0) * radius)
		var p1 := Vector3(center.x + cos(a1) * radius, height, center.y + sin(a1) * radius)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0, 0)); st.add_vertex(p0)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(1, 0)); st.add_vertex(p1)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(1, 1)); st.add_vertex(Vector3(center.x, height, center.y))

func _quad_wall(p0: Vector3, p1: Vector3, n0: Vector3, n1: Vector3, height: float, st: SurfaceTool) -> void:
	var t0: Vector3 = p0 + Vector3(0, height, 0)
	var t1: Vector3 = p1 + Vector3(0, height, 0)
	st.set_normal(n0); st.set_uv(Vector2(0, 0)); st.add_vertex(p0)
	st.set_normal(n1); st.set_uv(Vector2(1, 0)); st.add_vertex(p1)
	st.set_normal(n1); st.set_uv(Vector2(1, 1)); st.add_vertex(t1)
	st.set_normal(n0); st.set_uv(Vector2(0, 0)); st.add_vertex(p0)
	st.set_normal(n1); st.set_uv(Vector2(1, 1)); st.add_vertex(t1)
	st.set_normal(n0); st.set_uv(Vector2(0, 1)); st.add_vertex(t0)

## Conical cap over a HALF cylinder: each step spans z in [pos.z, pos.z + rad]
## so the roof covers the drum's bulge and nothing west of its flat face.
func _half_cone_cap(pos: Vector3, radius: float, height: float, s: int) -> void:
	var steps: int = 4
	for i in range(steps):
		var t1: float = float(i + 1) / steps
		var rad: float = lerpf(radius, 0.15, pow(t1, 0.8))
		var step_h: float = height / steps * 1.5
		box(Vector3(rad * 2.0, step_h, rad),
			Vector3(pos.x, pos.y + height * t1 - step_h / 2.0, pos.z + rad / 2.0), s)


func _pyramid_roof(base_center: Vector3, width: float, height: float, s: int, tall := false) -> void:
	var steps: int = 5 if tall else 3
	for i in range(steps):
		var t1: float = float(i + 1) / steps
		var wd: float = lerpf(width, 0.2, pow(t1, 0.85))
		# centre each step so its TOP lands on the nominal profile; otherwise the
		# stack overshoots the height it claims and the elevation under-reports.
		var step_h: float = height / steps * 1.4
		box(Vector3(wd, step_h, wd),
			Vector3(base_center.x, base_center.y + height * t1 - step_h / 2.0,
				base_center.z), s)

func pinnacle(pos: Vector3) -> void:
	box(Vector3(0.35, 1.2, 0.35), pos + Vector3(0, 0.6, 0), SURF_STONE)
	box(Vector3(0.55, 0.16, 0.55), pos + Vector3(0, 0.08, 0), SURF_TRIM)
	_pyramid_roof(pos + Vector3(0, 1.2, 0), 0.4, 0.6, SURF_ROOF, false)

# ---------------------------------------------------------------- openings

## Dark recessed opening facing local +Z, rotated by `face` around Y.
func window(pos: Vector3, face: float, w: float, h: float, style: StringName, door := false) -> void:
	_log_part("window", pos)
	var depth: float = 0.16 if door else 0.1
	var t := Transform3D(Basis(Vector3.UP, face), pos)
	var st: SurfaceTool = _sts[SURF_OPEN]
	_push_poly_box(st, t, Vector3(w, h, depth))
	if style == &"pointed":
		var apex := Vector3(0, h * 0.35, 0)
		var bl := Vector3(-w / 2.0, h / 2.0, 0)
		var br := Vector3(w / 2.0, h / 2.0, 0)
		for p in [bl, br, apex]:
			st.set_normal(Vector3(0, 0, 1))
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
			for p in [c, p0, p1]:
				st.set_normal(Vector3(0, 0, 1))
				st.set_uv(Vector2(0.5, 0.5))
				st.add_vertex(t * p)
	if not door:
		var ft: float = 0.12
		_push_poly_box(st, t, Vector3(w + ft * 2, ft, depth + 0.04), Vector3(0, h / 2.0 + ft / 2.0, 0))
		_push_poly_box(st, t, Vector3(ft, h, depth + 0.04), Vector3(-w / 2.0 - ft / 2.0, 0, 0))
		_push_poly_box(st, t, Vector3(ft, h, depth + 0.04), Vector3(w / 2.0 + ft / 2.0, 0, 0))

func rose(pos: Vector3) -> void:
	_log_part("window", pos)
	var t := Transform3D(Basis(), pos)
	var st: SurfaceTool = _sts[SURF_OPEN]
	var rr: float = minf(spec.width * 0.18, 1.6)
	var seg: int = 12
	for i in range(seg):
		var a0: float = TAU / seg * i
		var a1: float = TAU / seg * (i + 1)
		var c := Vector3.ZERO
		var p0 := Vector3(cos(a0) * rr, sin(a0) * rr, 0)
		var p1 := Vector3(cos(a1) * rr, sin(a1) * rr, 0)
		for p in [c, p0, p1]:
			st.set_normal(Vector3(0, 0, 1))
			st.set_uv(Vector2(0.5, 0.5))
			st.add_vertex(t * p)
	var tt: SurfaceTool = _sts[SURF_TRIM]
	for i in range(seg):
		var a: float = TAU / seg * i
		var bx: Transform3D = t * Transform3D(Basis(Vector3(0, 0, 1), a),
			Vector3(cos(a) * rr * 0.5, sin(a) * rr * 0.5, -0.03))
		var cs := _corners_of(Vector3(rr * 0.55, 0.09, 0.08))
		for c in cs:
			tt.set_normal(Vector3(0, 0, 1))
			tt.set_uv(Vector2(0, 0))
			tt.add_vertex(bx * c)

func _push_poly_box(st: SurfaceTool, t: Transform3D, size: Vector3, offset := Vector3.ZERO) -> void:
	var cs := _corners_of(size)
	var pts: Array = []
	for c in cs:
		pts.append(t * (c + offset))
	var quads := [[0, 1, 2, 3], [4, 5, 6, 7], [1, 4, 7, 2], [5, 0, 3, 6], [3, 2, 7, 6], [0, 5, 4, 1]]
	var normals := [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0)]
	var uv3 := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]
	for qi in range(quads.size()):
		var q: Array = quads[qi]
		for tri in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
			for vi in range(3):
				st.set_normal(t.basis * normals[qi])
				st.set_uv(uv3[vi])
				st.add_vertex(pts[tri[vi]])

func _corners_of(size: Vector3) -> Array:
	var hx: float = size.x / 2.0
	var hy: float = size.y / 2.0
	var hz: float = size.z / 2.0
	return [
		Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz),
		Vector3(hx, -hy, hz), Vector3(-hx, -hy, hz), Vector3(-hx, hy, hz), Vector3(hx, hy, hz),
	]
