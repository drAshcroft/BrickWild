class_name MeshKit
extends RefCounted
## Low-level mesh primitives, shared by every builder.
##
## Absorbed from the two builders that each kept their own copy: the box emitter
## existed four times over and the stepped-taper solid four times, which is how
## they drifted apart. Nothing here knows what a church is -- it takes plain
## sizes and positions, so the massing logic stays in the builder.
##
## Surfaces are indexed by the builder's own constants; surface_count decides
## how many SurfaceTools exist.

var _sts: Array[SurfaceTool] = []


func _init(surface_count: int) -> void:
	for i in range(surface_count):
		var s := SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		_sts.append(s)


func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for s in _sts:
		s.generate_normals()
		s.commit(mesh)
	return mesh


func surface(i: int) -> SurfaceTool:
	return _sts[i]


# ------------------------------------------------------------------- boxes

## Box centred at pos. rot_y turns it about Y; shear slides the top along Z
## (z += y * shear), which gives battered walls and upturned eaves.
func box(size: Vector3, pos: Vector3, surf: int, rot_y := 0.0, shear := 0.0) -> void:
	var basis := Basis(Vector3.UP, rot_y)
	var pts: Array = []
	for c in _corners(size):
		var p: Vector3 = c
		p.z += p.y * shear
		pts.append(pos + basis * p)
	_emit_box(pts, surf)


## Box placed by an arbitrary transform, for parts that are tilted or rolled.
func oriented_box(size: Vector3, xform: Transform3D, surf: int) -> void:
	var pts: Array = []
	for c in _corners(size):
		pts.append(xform * c)
	_emit_box(pts, surf)


static func _corners(size: Vector3) -> Array:
	var hx: float = size.x / 2.0
	var hy: float = size.y / 2.0
	var hz: float = size.z / 2.0
	return [
		Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz),
		Vector3(hx, -hy, hz), Vector3(-hx, -hy, hz), Vector3(-hx, hy, hz), Vector3(hx, hy, hz),
	]


## Shared triangulation for the 8 corners produced by _corners().
func _emit_box(pts: Array, surf: int) -> void:
	var quads := [
		[0, 1, 2, 3], [4, 5, 6, 7],      # -z, +z
		[1, 4, 7, 2], [5, 0, 3, 6],      # +x, -x
		[3, 2, 7, 6], [0, 5, 4, 1],      # top, bottom
	]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var st: SurfaceTool = _sts[surf]
	for q in quads:
		# Every vertex must carry a normal: SurfaceTool locks its attribute set
		# on the first vertex, and callers mix their own set_normal() calls in.
		var n: Vector3 = _face_normal(pts[q[0]], pts[q[1]], pts[q[2]])
		for tri in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
			for vi in range(3):
				st.set_normal(n)
				st.set_uv(uvs[vi])
				st.add_vertex(pts[tri[vi]])


static func _face_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var n: Vector3 = (b - a).cross(c - a)
	return n.normalized() if n.length_squared() > 0.0 else Vector3.UP


# ------------------------------------------------------------------- roofs

## One sloped roof slab: eave at (x = +/-half_span, y = y_base), ridge at
## (x = 0, y = y_base + rise). y_base is the wall top this roof sits on.
func slab(along: float, rise: float, half_span: float, side: float, zc: float,
		surf: int, y_base := 0.0, thickness := 0.24) -> void:
	var slope_len: float = sqrt(half_span * half_span + rise * rise)
	var ang: float = atan2(rise, half_span)
	var t := Transform3D(Basis(Vector3(0, 0, 1), -side * ang),
		Vector3(side * half_span / 2.0, y_base + rise / 2.0, zc))
	oriented_box(Vector3(slope_len, thickness, along), t, surf)


## Two-sided gable capping a wall whose top is at y_base.
func gable_roof(span_x: float, along_z: float, rise: float, z_center: float,
		surf: int, y_base := 0.0) -> void:
	for side in [-1.0, 1.0]:
		slab(along_z, rise, span_x / 2.0, side, z_center, surf, y_base)
	box(Vector3(0.35, 0.25, along_z + 0.2), Vector3(0, y_base + rise + 0.1, z_center), surf)


## Hipped roof: side slabs plus sloped ends, so all four sides fall away.
## Cannibalised from the house builder, the only place it existed.
func hip_roof(span_x: float, along_z: float, rise: float, z_center: float,
		surf: int, y_base := 0.0) -> void:
	for side in [-1.0, 1.0]:
		slab(along_z * 0.72, rise, span_x / 2.0, side, z_center, surf, y_base)
	var half_along: float = along_z / 2.0
	var slope_len: float = sqrt(half_along * half_along + rise * rise)
	var ang: float = atan2(rise, half_along)
	for end_v in [-1.0, 1.0]:
		var t := Transform3D(Basis(Vector3(1, 0, 0), end_v * ang),
			Vector3(0, y_base + rise / 2.0, z_center + end_v * half_along / 2.0))
		oriented_box(Vector3(span_x * 0.72, 0.24, slope_len), t, surf)
	box(Vector3(0.35, 0.25, along_z * 0.4), Vector3(0, y_base + rise + 0.1, z_center), surf)


## Lean-to (single pitch) roof, from an outer eave up to a wall.
func lean_roof(span: float, along: float, y_base: float, y_top: float,
		side: float, surf: int, zc := 0.0) -> void:
	var rise: float = y_top - y_base
	var slope_len: float = sqrt(span * span + rise * rise)
	var ang: float = atan2(rise, span)
	var t := Transform3D(Basis(Vector3(0, 0, 1), -side * ang),
		Vector3(side * span / 2.0, (y_base + y_top) / 2.0, zc))
	oriented_box(Vector3(slope_len, 0.2, along), t, surf)


# ------------------------------------------------------------ tapered solids

## Stepped taper: a stack of boxes shrinking toward a tip. Covers pyramids,
## spires, conical caps and tent roofs. Each step's TOP lands on the nominal
## profile, so the stack reaches exactly `height` and no further.
##   half:   emit half-depth steps hugging +Z from base_center.z (half cones)
##   upturn: shear per step, for flared eaves
func stepped_taper(base_center: Vector3, base_w: float, height: float, surf: int,
		steps := 4, tip := 0.2, half := false, upturn := 0.0, curve := 0.85) -> void:
	for i in range(steps):
		var t1: float = float(i + 1) / steps
		var wd: float = lerpf(base_w, tip, pow(t1, curve))
		var step_h: float = height / steps * 1.4
		var depth: float = wd / 2.0 if half else wd
		var zc: float = base_center.z + (wd / 4.0 if half else 0.0)
		box(Vector3(wd, step_h, depth),
			Vector3(base_center.x, base_center.y + height * t1 - step_h / 2.0, zc),
			surf, 0.0, upturn)


## Tiered stack of diminishing roofs. Cannibalised from the house builder's
## pagoda roof; here it gives Russian tent towers their stepped silhouette.
func tiered_taper(base_center: Vector3, base_w: float, height: float, surf: int,
		tiers := 3, upturn := 0.2) -> void:
	var y: float = base_center.y
	var w: float = base_w
	for i in range(tiers):
		var tier_h: float = height / tiers
		box(Vector3(w, tier_h * 0.28, w),
			Vector3(base_center.x, y + tier_h * 0.14, base_center.z), surf, 0.0, upturn)
		stepped_taper(Vector3(base_center.x, y + tier_h * 0.28, base_center.z),
			w * 0.92, tier_h * 0.72, surf, 2, w * 0.5)
		y += tier_h
		w *= 0.72


# ----------------------------------------------------------- revolved solids

## Surface of revolution from a profile of (radius, height) points, bottom to
## top. arc < TAU sweeps only part of the circle, which is how half-domes and
## exedrae are made. This is the workhorse behind every dome shape.
func revolve(profile: PackedVector2Array, center: Vector3, surf: int,
		segments := 16, arc := TAU, start := 0.0) -> void:
	if profile.size() < 2:
		return
	var st: SurfaceTool = _sts[surf]
	var rings: int = profile.size() - 1
	for i in range(rings):
		var p0: Vector2 = profile[i]
		var p1: Vector2 = profile[i + 1]
		for s in range(segments):
			var a0: float = start + arc * float(s) / segments
			var a1: float = start + arc * float(s + 1) / segments
			var v := [
				center + Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x),
				center + Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x),
				center + Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x),
				center + Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x),
			]
			var n: Vector3 = _face_normal(v[0], v[1], v[2])
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for vi in tri:
					st.set_normal(n)
					st.set_uv(Vector2(float(s) / segments, float(i) / rings))
					st.add_vertex(v[vi])
	# close a partial sweep, so a half-dome is not hollow along its cut
	if arc < TAU - 0.001:
		for a in [start, start + arc]:
			var dir := Vector3(cos(a), 0, sin(a))
			for i in range(rings):
				var q := [
					center + dir * profile[i].x + Vector3(0, profile[i].y, 0),
					center + dir * profile[i + 1].x + Vector3(0, profile[i + 1].y, 0),
					center + Vector3(0, profile[i + 1].y, 0),
					center + Vector3(0, profile[i].y, 0),
				]
				var cn: Vector3 = _face_normal(q[0], q[1], q[2])
				for tri in [[0, 1, 2], [0, 2, 3]]:
					for vi in tri:
						st.set_normal(cn)
						st.set_uv(Vector2(0, 0))
						st.add_vertex(q[vi])


## Half cylinder hugging +Z from center: flat face at center.y (model Z),
## bulging to center.y + radius. Used for apses.
func half_cylinder(radius: float, height: float, center: Vector2, surf: int,
		segments := 10) -> void:
	var origin := Vector3(center.x, 0, center.y)
	revolve(PackedVector2Array([Vector2(radius, 0.0), Vector2(radius, height)]),
		origin, surf, segments, PI, 0.0)
	var st: SurfaceTool = _sts[surf]
	for s in range(segments):
		var a0: float = PI * float(s) / segments
		var a1: float = PI * float(s + 1) / segments
		var c: Vector3 = origin + Vector3(0, height, 0)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0, 0)); st.add_vertex(c + Vector3(cos(a0) * radius, 0, sin(a0) * radius))
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(1, 0)); st.add_vertex(c + Vector3(cos(a1) * radius, 0, sin(a1) * radius))
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(1, 1)); st.add_vertex(c)


## Straight-sided prism: octagonal drums, crossing lanterns.
func prism(radius: float, height: float, sides: int, center: Vector3, surf: int,
		rot := 0.0) -> void:
	revolve(PackedVector2Array([Vector2(radius, 0.0), Vector2(radius, height)]),
		center, surf, sides, TAU, rot)


# ------------------------------------------------------------------- arches

## A ribbon of boxes following an arc from `from_p` to `to_p`, bowing upward by
## `rise`. This is the flyer of a flying buttress.
func arc_ribbon(from_p: Vector3, to_p: Vector3, rise: float, thickness: float,
		depth: float, surf: int, steps := 6) -> void:
	var prev: Vector3 = from_p
	for i in range(steps):
		var t: float = float(i + 1) / steps
		var p: Vector3 = from_p.lerp(to_p, t)
		p.y += rise * 4.0 * t * (1.0 - t)     # parabolic bow, zero at both ends
		var seg: Vector3 = p - prev
		var seg_len: float = seg.length()
		if seg_len < 0.001:
			prev = p
			continue
		var xf := Transform3D(Basis().looking_at(seg / seg_len, Vector3.UP),
			(prev + p) / 2.0)
		oriented_box(Vector3(depth, thickness, seg_len * 1.08), xf, surf)
		prev = p
