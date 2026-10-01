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
## Metric texture coordinates are opt-in. Church and castle stone uses physical
## metres; houses retain their established UV regions and roof materials.
var metric_coordinates := false
## Temporary world-space offset applied at the final vertex write. Ring builders
## use this while emitting an elevated enceinte, then reset it before the next
## mass. Geometry arguments and normals remain in their local frame.
var emission_offset := Vector3.ZERO


func _init(surface_count: int, p_metric_coordinates := false) -> void:
	metric_coordinates = p_metric_coordinates
	for i in range(surface_count):
		var s := SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		s.set_color(Color.WHITE)
		_sts.append(s)


func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for s in _sts:
		# No generate_normals() here. Every emitter below already sets a correct
		# per-face normal, and generate_normals() SMOOTHS across a whole surface:
		# one smooth group covers the entire building, so a wall corner was being
		# averaged with whatever roof slab happened to share the vertex. Flat
		# masonry shaded like a lump. It was also the only thing hiding the
		# inverted _face_normal below.
		s.commit(mesh)
	return mesh


## Copy an emitted mesh with every vertex moved by `offset`. Normals are
## directions and remain unchanged. Used when a whole procedural building has
## a local ground plane above world zero, as the sky citadel does.
static func translated(mesh: ArrayMesh, offset: Vector3) -> ArrayMesh:
	var out := ArrayMesh.new()
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface).duplicate(true)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in range(vertices.size()):
			vertices[i] += offset
		arrays[Mesh.ARRAY_VERTEX] = vertices
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(surface), arrays)
		out.surface_set_material(surface, mesh.surface_get_material(surface))
		out.surface_set_name(surface, mesh.surface_get_name(surface))
	return out


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
	var st: SurfaceTool = _sts[surf]
	for q in quads:
		# Every vertex must carry a normal: SurfaceTool locks its attribute set
		# on the first vertex, and callers mix their own set_normal() calls in.
		for tri in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
			var n: Vector3 = _face_normal(pts[tri[0]], pts[tri[1]], pts[tri[2]])
			var axes: Array = []
			if metric_coordinates:
				axes = _surface_uv_axes(n)
			for vi in range(3):
				st.set_normal(n)
				if metric_coordinates:
					st.set_uv(_project_uv(pts[tri[vi]], axes))
				else:
					st.set_uv(Vector2(0.0 if vi == 0 else 1.0,
						0.0 if vi < 2 else 1.0))
				_add_vertex(st, pts[tri[vi]])


## A deterministic basis for a face. U follows its horizontal/eave direction;
## V climbs the face. Absolute dot products make coplanar triangles continuous.
static func _surface_uv_axes(normal: Vector3) -> Array:
	var n := normal.normalized()
	var u := Vector3.UP.cross(n).normalized()
	if u.length_squared() < 0.001:
		u = Vector3.RIGHT
	var v := n.cross(u).normalized()
	return [u, v]


static func _project_uv(point: Vector3, axes: Array) -> Vector2:
	return Vector2(point.dot(axes[0]), point.dot(axes[1]))


## Outward normal for a triangle wound (a, b, c).
##
## Godot's front faces are CLOCKWISE, so the outward normal is (c-a) x (b-a) --
## the opposite hand from the usual CCW formula this used to carry. The windings
## here were right all along; the normals they were paired with pointed into the
## building, and generate_normals() overwrote them before anyone could see.
static func _face_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var n: Vector3 = (c - a).cross(b - a)
	return n.normalized() if n.length_squared() > 0.0 else Vector3.UP


## A triangle with no area: two of its corners coincide. The apex ring of a
## cone is a whole row of them, and a zero-area triangle can only carry an
## invented normal, so emitters drop these rather than shipping them.
static func _degenerate(a: Vector3, b: Vector3, c: Vector3) -> bool:
	return (c - a).cross(b - a).length_squared() < 1e-12


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


## Two-sided gable capping a wall whose top is at y_base, ridge along Z.
##
## end_surf >= 0 also walls in the triangle under each slope. Without those the
## roof was two floating planes and you looked straight into the void along the
## ridge; a gabled roof is only gabled once its ends are closed. end_span /
## end_along are the WALL's footprint, not the roof's -- the slabs overhang.
func gable_roof(span_x: float, along_z: float, rise: float, z_center: float,
		surf: int, y_base := 0.0, end_surf := -1, end_span := 0.0,
		end_along := 0.0, end_thick := 0.3) -> void:
	ridge_roof(Transform3D(Basis(), Vector3(0.0, y_base, z_center)),
		span_x, along_z, rise, surf, end_surf, end_span, end_along, end_thick)


## The same roof, placed by an arbitrary transform. Local space has the wall top
## at y = 0 and the ridge running along local Z, so a yaw of PI/2 turns a range
## that runs across X instead of along it -- which is most of a manor.
##
## gable_roof() is this function with the identity basis; keeping one
## implementation is what stops the two drifting, as the four copies of the box
## emitter once did.
func ridge_roof(xf: Transform3D, span_x: float, along_z: float, rise: float,
		surf: int, end_surf := -1, end_span := 0.0, end_along := 0.0,
		end_thick := 0.3, end_cut := 0.0, deferred_faces: Variant = null) -> void:
	var roof := RoofShape.faces(span_x, along_z, rise)
	for face in roof:
		if deferred_faces != null:
			deferred_faces.append(xf * face)
		else:
			slab_poly(xf * face, RoofShape.DEPTH, surf, true)
	if end_surf < 0:
		return
	var ex: float = (end_span if end_span > 0.0 else span_x) / 2.0
	var ez: float = (end_along if end_along > 0.0 else along_z) / 2.0
	# Close all four wall heads against the actual underside. Scaling only
	# the gable apex leaves a strip of daylight under an overhanging roof.
	var corners := PackedVector2Array([Vector2(-ex, -ez), Vector2(ex, -ez),
		Vector2(ex, ez), Vector2(-ex, ez)])
	for i in range(4):
		var a := corners[i]
		var b := corners[(i + 1) % 4]
		var profile := RoofShape.wall_profile(roof, a, b)
		var inward := Vector3(-(b - a).y, 0, (b - a).x).normalized() * end_thick * 0.5
		for j in range(profile.size()):
			if end_cut > 0:
				profile[j].y = minf(profile[j].y, end_cut)
			profile[j] += inward
		slab_poly(xf * profile, end_thick, end_surf)


## The triangular wall under a gable: apex over x = 0 at y_base + rise, extruded
## between the two z planes. Emitted as a closed prism, wound so the caps face
## out along their own side of the extrusion rather than both the same way.
func gable_end(half_span: float, rise: float, y_base: float,
		z_back: float, z_front: float, surf: int) -> void:
	gable_end_at(Transform3D(Basis(), Vector3(0.0, y_base, 0.0)),
		half_span, rise, z_back, z_front, surf)


## gable_end() in the local space of `xf`, whose origin is the wall top.
##
## `cut` truncates the apex at that height, which turns the triangle into a
## TRAPEZOID: a half hip takes the top off the gable, and the wall has to stop
## where the hip starts. Left full height, the wall carries on up behind the
## hip and the hip reads as a stray plane lying across the roof rather than as
## the end of it.
func gable_end_at(xf: Transform3D, half_span: float, rise: float,
		z_back: float, z_front: float, surf: int, cut := 0.0) -> void:
	var lo: float = minf(z_back, z_front)
	var hi: float = maxf(z_back, z_front)
	var xy: Array[Vector2] = [Vector2(-half_span, 0.0), Vector2(half_span, 0.0)]
	if cut > 0.0 and cut < rise:
		var w: float = half_span * (1.0 - cut / rise)
		xy.append(Vector2(w, cut))
		xy.append(Vector2(-w, cut))
	else:
		xy.append(Vector2(0.0, rise))
	var n: int = xy.size()
	var at_lo: Array = []
	var at_hi: Array = []
	for p in xy:
		at_lo.append(xf * Vector3(p.x, p.y, lo))
		at_hi.append(xf * Vector3(p.x, p.y, hi))
	var st: SurfaceTool = _sts[surf]
	# fanned from corner 0, which is safe: the outline is convex either way
	for i in range(1, n - 1):
		_tri(st, at_lo[0], at_lo[i], at_lo[i + 1])      # faces -Z
		_tri(st, at_hi[0], at_hi[i + 1], at_hi[i])      # faces +Z
	for i2 in range(n):
		var j: int = (i2 + 1) % n
		_quad(st, at_lo[i2], at_hi[i2], at_hi[j], at_lo[j])


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n: Vector3 = _face_normal(a, b, c)
	var axes: Array = _surface_uv_axes(n) if metric_coordinates else []
	for p in [a, b, c]:
		st.set_normal(n)
		st.set_uv(_project_uv(p, axes) if metric_coordinates else Vector2(0.5, 0.5))
		_add_vertex(st, p)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, b, c)
	_tri(st, a, c, d)


func _add_vertex(st: SurfaceTool, point: Vector3) -> void:
	st.add_vertex(point + emission_offset)


## A flat slab of `thickness` through any planar polygon, given its corners in
## order round the face.
##
## Roof slabs are oriented boxes everywhere else, and a box is a rectangle: it
## cannot be cut back on the diagonal. That is exactly what a hip needs -- the
## slope beside it has a triangle taken out of its top corner, and the hip
## fills that triangle. Built from rectangles instead, the two either leave a
## hole or lie across each other, and both were happening.
##
## The polygon must be planar and convex, which every roof face here is.
func slab_poly(points: PackedVector3Array, thickness: float, surf: int,
		vertical_depth := false) -> void:
	# Clipping can retain a repeated corner or a point on a straight edge.
	# Remove those before choosing a normal and fanning the convex polygon.
	points = points.duplicate()
	var changed := true
	while changed and points.size() >= 3:
		changed = false
		for i in range(points.size()):
			var before := points[(i + points.size() - 1) % points.size()]
			var after := points[(i + 1) % points.size()]
			if (points[i] - before).cross(after - points[i]).length_squared() < 1e-12:
				points.remove_at(i)
				changed = true
				break
	var n: int = points.size()
	if n < 3:
		return
	var nrm: Vector3 = (points[1] - points[0]).cross(points[2] - points[0])
	if nrm.length_squared() < 1e-12:
		return
	# wind so the outer face is the upper one
	var pts: PackedVector3Array = points
	if nrm.y < 0.0:
		pts = PackedVector3Array()
		for i in range(n - 1, -1, -1):
			pts.append(points[i])
		nrm = -nrm
	var off: Vector3 = (Vector3.UP if vertical_depth else nrm.normalized()) * (thickness / 2.0)
	var lo: Array = []
	var hi: Array = []
	for p in pts:
		lo.append(p - off)
		hi.append(p + off)
	var st: SurfaceTool = _sts[surf]
	# Metre-sized face coordinates, shared by every coplanar clipped piece.
	# Horizontal U follows the eave; V climbs the slope. Absolute projections
	# keep courses continuous across triangles and around dormer roof cuts.
	var uv_u := Vector3.UP.cross(nrm).normalized()
	if uv_u.length_squared() < 0.001:
		uv_u = Vector3.RIGHT
	var uv_v := nrm.normalized().cross(uv_u).normalized()
	for i2 in range(1, n - 1):
		_tri_metric(st, lo[0], lo[i2], lo[i2 + 1], uv_u, uv_v)
		_tri_metric(st, hi[0], hi[i2 + 1], hi[i2], uv_u, uv_v)
	for i3 in range(n):
		var j: int = (i3 + 1) % n
		_quad(st, lo[i3], hi[i3], hi[j], lo[j])


func _tri_metric(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		u: Vector3, v: Vector3) -> void:
	var normal := _face_normal(a, b, c)
	for p in [a, b, c]:
		st.set_normal(normal)
		st.set_uv(Vector2(p.dot(u), p.dot(v)))
		_add_vertex(st, p)


## Hipped roof: side slabs plus sloped ends, so all four sides fall away.
## Cannibalised from the house builder, the only place it existed.
func hip_roof(span_x: float, along_z: float, rise: float, z_center: float,
		surf: int, y_base := 0.0) -> void:
	hip_roof_at(Transform3D(Basis(), Vector3(0.0, y_base, z_center)),
		span_x, along_z, rise, surf)


## The four roof faces share actual hip/ridge endpoints. Vertical slab
## depth preserves those joins on both sides of the roof skin.
func hip_roof_at(xf: Transform3D, span_x: float, along_z: float, rise: float,
		surf: int) -> void:
	for face in RoofShape.faces(span_x, along_z, rise, &"hipped"):
		var world := PackedVector3Array()
		for p in face:
			world.append(xf * p)
		slab_poly(world, RoofShape.DEPTH, surf, true)


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
## exedrae are made. `ellipse_scale` applies a plan-space X/Z scale after the
## sweep for oval domes; its default preserves a true circular revolution.
func revolve(profile: PackedVector2Array, center: Vector3, surf: int,
		segments := 16, arc := TAU, start := 0.0,
		ellipse_scale := Vector2.ONE) -> void:
	if profile.size() < 2:
		return
	var st: SurfaceTool = _sts[surf]
	var rings: int = profile.size() - 1
	var profile_v := PackedFloat32Array()
	if metric_coordinates:
		profile_v.append(0.0)
		for profile_index in range(1, profile.size()):
			profile_v.append(profile_v[profile_index - 1]
				+ profile[profile_index - 1].distance_to(profile[profile_index]))
	for i in range(rings):
		var p0: Vector2 = profile[i]
		var p1: Vector2 = profile[i + 1]
		for s in range(segments):
			var a0: float = start + arc * float(s) / segments
			var a1: float = start + arc * float(s + 1) / segments
			var v := [
				center + Vector3(cos(a0) * p0.x * ellipse_scale.x, p0.y, sin(a0) * p0.x * ellipse_scale.y),
				center + Vector3(cos(a1) * p0.x * ellipse_scale.x, p0.y, sin(a1) * p0.x * ellipse_scale.y),
				center + Vector3(cos(a1) * p1.x * ellipse_scale.x, p1.y, sin(a1) * p1.x * ellipse_scale.y),
				center + Vector3(cos(a0) * p1.x * ellipse_scale.x, p1.y, sin(a0) * p1.x * ellipse_scale.y),
			]
			# Per TRIANGLE, not per quad: four points on a dome are not coplanar,
			# and sharing the first triangle's normal with the second left a
			# visible crease running up every ring of every revolved surface.
			for tri in [[0, 1, 2], [0, 2, 3]]:
				if _degenerate(v[tri[0]], v[tri[1]], v[tri[2]]):
					continue
				var n: Vector3 = _face_normal(v[tri[0]], v[tri[1]], v[tri[2]])
				for vi in tri:
					st.set_normal(n)
					if metric_coordinates:
						var angle := a0 if vi == 0 or vi == 3 else a1
						var radius := p0.x if vi == 0 or vi == 1 else p1.x
						var height := profile_v[i] if vi == 0 or vi == 1 else profile_v[i + 1]
						st.set_uv(Vector2((angle - start) * radius, height))
					else:
						st.set_uv(Vector2(float(s) / segments, float(i) / rings))
					_add_vertex(st, v[vi])
	# close a partial sweep, so a half-dome is not hollow along its cut
	if arc < TAU - 0.001:
		for a in [start, start + arc]:
			var dir := Vector3(cos(a) * ellipse_scale.x, 0,
				sin(a) * ellipse_scale.y)
			for i in range(rings):
				var q := [
					center + dir * profile[i].x + Vector3(0, profile[i].y, 0),
					center + dir * profile[i + 1].x + Vector3(0, profile[i + 1].y, 0),
					center + Vector3(0, profile[i + 1].y, 0),
					center + Vector3(0, profile[i].y, 0),
				]
				for tri in [[0, 1, 2], [0, 2, 3]]:
					if _degenerate(q[tri[0]], q[tri[1]], q[tri[2]]):
						continue
					# End cap faces away from the swept arc, opposite the start.
					if a == start + arc:
						tri = [tri[0], tri[2], tri[1]]
					var cn: Vector3 = _face_normal(q[tri[0]], q[tri[1]], q[tri[2]])
					var cap_axes: Array = _surface_uv_axes(cn) if metric_coordinates else []
					for vi in tri:
						st.set_normal(cn)
						st.set_uv(_project_uv(q[vi], cap_axes)
							if metric_coordinates else Vector2.ZERO)
						_add_vertex(st, q[vi])


## Battered drum with a capped top: the shaft of every castle tower.
##
## `sides` chooses the plan -- 4 is a square tower, 8 polygonal, 12 or more a
## round one -- and `rot` turns a flat face outward. One primitive for all three
## shapes is what keeps a square tower from drifting away from a round one.
## base_r/top_r are CIRCUMradii; a wider base is the talus.
func drum(center: Vector3, base_r: float, top_r: float, height: float, surf: int,
		sides := 12, rot := 0.0) -> void:
	revolve(PackedVector2Array([Vector2(base_r, 0.0), Vector2(top_r, height)]),
		center, surf, sides, TAU, rot)
	var st: SurfaceTool = _sts[surf]
	var top: Vector3 = center + Vector3(0, height, 0)
	for s in range(sides):
		var a0: float = rot + TAU * float(s) / sides
		var a1: float = rot + TAU * float(s + 1) / sides
		var p0: Vector3 = top + Vector3(cos(a0) * top_r, 0, sin(a0) * top_r)
		var p1: Vector3 = top + Vector3(cos(a1) * top_r, 0, sin(a1) * top_r)
		_tri(st, p0, p1, top)


## Cone: the conical cap of a drum tower, the spire of a round turret.
func cone(radius: float, height: float, center: Vector3, surf: int,
		segments := 12, rotation := 0.0) -> void:
	revolve(PackedVector2Array([Vector2(radius, 0.0), Vector2(0.0, height)]),
		center, surf, segments, TAU, rotation)


## A thin annular balcony slab. `radius` is the outside edge, `width` reaches
## inward toward the host tower, and `arc`/`start` can leave an open sector so
## successive balconies read as a spiral instead of stacked collars. The four
## skins and both cut ends are closed; a full ring naturally has no cut ends.
func balcony_ring(radius: float, width: float, y: float, arc: float,
		surf := 0, center := Vector2.ZERO, start := 0.0, thickness := 0.28,
		segments := 24) -> void:
	var outer: float = maxf(radius, 0.05)
	var inner: float = clampf(outer - width, 0.02, outer - 0.01)
	var sweep: float = clampf(arc, 0.01, TAU)
	var n: int = maxi(1, int(ceil(float(segments) * sweep / TAU)))
	var st: SurfaceTool = _sts[surf]
	for i in range(n):
		var a0: float = start + sweep * float(i) / float(n)
		var a1: float = start + sweep * float(i + 1) / float(n)
		var ob0 := Vector3(center.x + cos(a0) * outer, y, center.y + sin(a0) * outer)
		var ob1 := Vector3(center.x + cos(a1) * outer, y, center.y + sin(a1) * outer)
		var ot0 := ob0 + Vector3.UP * thickness
		var ot1 := ob1 + Vector3.UP * thickness
		var ib0 := Vector3(center.x + cos(a0) * inner, y, center.y + sin(a0) * inner)
		var ib1 := Vector3(center.x + cos(a1) * inner, y, center.y + sin(a1) * inner)
		var it0 := ib0 + Vector3.UP * thickness
		var it1 := ib1 + Vector3.UP * thickness
		_quad(st, ot0, ot1, it1, it0) # top
		_quad(st, ob1, ob0, ib0, ib1) # underside
		_quad(st, ob0, ob1, ot1, ot0) # outside rim
		_quad(st, ib1, ib0, it0, it1) # inside rim
	if sweep < TAU - 0.001:
		for a in [start, start + sweep]:
			var ob := Vector3(center.x + cos(a) * outer, y, center.y + sin(a) * outer)
			var ib := Vector3(center.x + cos(a) * inner, y, center.y + sin(a) * inner)
			var flip: bool = is_equal_approx(a, start)
			if flip:
				_quad(st, ob, ob + Vector3.UP * thickness,
					ib + Vector3.UP * thickness, ib)
			else:
				_quad(st, ib, ib + Vector3.UP * thickness,
					ob + Vector3.UP * thickness, ob)


## A four-sided pointed merlon. Dimensions are deliberately independent so a
## narrow dark-fortress spike can still span the depth of its parapet.
func spike(size: Vector2, height: float, center: Vector3, surf: int,
		rotation := 0.0) -> void:
	# Scale a unit square cone in X/Z without teaching revolve about ellipses.
	var st: SurfaceTool = _sts[surf]
	var basis := Basis(Vector3.UP, rotation)
	var base: Array[Vector3] = []
	for p in [Vector3(-size.x / 2.0, 0, -size.y / 2.0),
			Vector3(size.x / 2.0, 0, -size.y / 2.0),
			Vector3(size.x / 2.0, 0, size.y / 2.0),
			Vector3(-size.x / 2.0, 0, size.y / 2.0)]:
		base.append(center + basis * p)
	var apex: Vector3 = center + Vector3.UP * height
	for i in range(4):
		_tri(st, base[i], base[(i + 1) % 4], apex)
	_quad(st, base[3], base[2], base[1], base[0])


## A floating-island rock: a broad, capped top at `center.y`, breaking through
## a few narrowing courses to one point `depth` below it. The emitter owns its
## top cap so the citadel has an actual surface to stand on.
func inverted_batter(radius: float, depth: float, center: Vector3, surf: int,
		segments := 20, rotation := 0.0) -> void:
	var r: float = maxf(radius, 0.1)
	var d: float = maxf(depth, 0.1)
	revolve(PackedVector2Array([
		Vector2(0.0, -d), Vector2(r * 0.42, -d * 0.58),
		Vector2(r * 0.76, -d * 0.22), Vector2(r, 0.0), Vector2(0.0, 0.0),
	]), center, surf, maxi(segments, 5), TAU, rotation)


## Half cylinder hugging +Z from center: flat face at center.y (model Z),
## bulging to center.y + radius. Used for apses.
func half_cylinder(radius: float, height: float, center: Vector2, surf: int,
		segments := 10) -> void:
	var origin := Vector3(center.x, 0, center.y)
	revolve(PackedVector2Array([Vector2(radius, 0.0), Vector2(radius, height)]),
		origin, surf, segments, PI, 0.0)
	var st: SurfaceTool = _sts[surf]
	var top_axes: Array = _surface_uv_axes(Vector3.UP) if metric_coordinates else []
	for s in range(segments):
		var a0: float = PI * float(s) / segments
		var a1: float = PI * float(s + 1) / segments
		var c: Vector3 = origin + Vector3(0, height, 0)
		st.set_normal(Vector3.UP)
		var p0 := c + Vector3(cos(a0) * radius, 0, sin(a0) * radius)
		st.set_uv(_project_uv(p0, top_axes) if metric_coordinates else Vector2.ZERO); _add_vertex(st, p0)
		st.set_normal(Vector3.UP)
		var p1 := c + Vector3(cos(a1) * radius, 0, sin(a1) * radius)
		st.set_uv(_project_uv(p1, top_axes) if metric_coordinates else Vector2(1, 0)); _add_vertex(st, p1)
		st.set_normal(Vector3.UP)
		st.set_uv(_project_uv(c, top_axes) if metric_coordinates else Vector2(1, 1)); _add_vertex(st, c)


## A hollow ring in plan, elliptical: the wall of a shell keep. `rx`/`rz` are
## the OUTER semi-axes; the wall is `thickness` thick, `height` tall, and
## closed with a flat top. Emitted as flat quads per segment, outside,
## inside and top, each with its own normal.
func oval_ring(center: Vector3, rx: float, rz: float, thickness: float,
		height: float, surf: int, segments := 24) -> void:
	var st: SurfaceTool = _sts[surf]
	var irx: float = maxf(rx - thickness, 0.05)
	var irz: float = maxf(rz - thickness, 0.05)
	for s in range(segments):
		var a0: float = TAU * float(s) / segments
		var a1: float = TAU * float(s + 1) / segments
		var o0 := center + Vector3(cos(a0) * rx, 0.0, sin(a0) * rz)
		var o1 := center + Vector3(cos(a1) * rx, 0.0, sin(a1) * rz)
		var i0 := center + Vector3(cos(a0) * irx, 0.0, sin(a0) * irz)
		var i1 := center + Vector3(cos(a1) * irx, 0.0, sin(a1) * irz)
		var up := Vector3(0.0, height, 0.0)
		# Godot fronts are clockwise. These orders put the outer skin away from
		# the centre, the inner skin into the void, and the caps up/down. The old
		# order paired internally consistent normals with inward-facing fronts,
		# so winding-only QA passed while backface culling exposed the wizard.
		_quad(st, o0, o1, o1 + up, o0 + up)
		_quad(st, i1, i0, i0 + up, i1 + up)
		_quad(st, o0 + up, o1 + up, i1 + up, i0 + up)
		_quad(st, o0, i0, i1, o1)

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
