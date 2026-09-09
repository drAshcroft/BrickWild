extends RefCounted
## Join the nave, transverse arms and aisle roofs into one upper envelope.
## Every slab uses vertical depth so its two skins meet at ridges and valleys.

static func emit(spec: ChurchSpec, kit: MeshKit, masses: Array[Dictionary],
		volumes: Array[PackedVector3Array] = []) -> void:
	var faces: Array[PackedVector3Array] = []
	_gable(kit, faces, ChurchGeometry.nave_aabb(spec), spec.width * spec.roof_pitch)
	if spec.transept:
		_gable(kit, faces, ChurchGeometry.transept_aabb(spec),
			spec.width * spec.roof_pitch * 0.9, true)
	if spec.narthex:
		_gable(kit, faces, ChurchGeometry.narthex_aabb(spec), spec.width * spec.roof_pitch * 0.5)
	for ring in range(spec.aisles):
		for side in [-1.0, 1.0]:
			_aisle(spec, kit, faces, ring, side)

	var covers: Array[PackedVector3Array] = faces.duplicate()
	if spec.dome:
		# The drum is solid below the shell; use its actual polygon, not the
		# shell's projected shadow (an onion bulges past its supporting drum).
		var drum := PackedVector3Array()
		var octagonal := spec.dome_shape == &"octagonal"
		var count := 8 if octagonal else 16
		var radius := spec.dome_radius * (ChurchGeometry.OCTAGONAL_RADIUS_FACTOR if octagonal else 1.0)
		var top := spec.height + ChurchGeometry.PENDENTIVE_H + spec.dome_drum_height
		for i in range(count):
			var a := TAU * float(i) / count + (PI / 8.0 if octagonal else 0.0)
			drum.append(Vector3(cos(a) * radius, top, ChurchGeometry.crossing_center_z(spec) + sin(a) * radius))
		covers.append(drum)
	for mass in masses:
		if not String(mass["name"]).begins_with("tower") and mass["name"] != "crossing_tower":
			continue
		var box: AABB = mass["aabb"]
		covers.append(PackedVector3Array([Vector3(box.position.x, box.end.y, box.position.z),
			Vector3(box.end.x, box.end.y, box.position.z), box.end,
			Vector3(box.position.x, box.end.y, box.end.z)]))
	var bounds: Array[Rect2] = []
	for cover in covers:
		bounds.append(_bounds(cover))
	for fi in range(faces.size()):
		var face := faces[fi]
		var pieces: Array[PackedVector2Array] = [RoofShape.footprint(face)]
		for ci in range(covers.size()):
			if ci == fi:
				continue
			var cover := covers[ci]
			if not bounds[fi].intersects(bounds[ci]):
				continue
			var hole := _above(cover, face)
			if Poly.area(hole) < 0.000001:
				continue
			var remaining: Array[PackedVector2Array] = []
			for piece in pieces:
				remaining.append_array(RoofShape.subtract(piece, hole))
			pieces = remaining
			if pieces.is_empty():
				break
		for volume in volumes:
			if not bounds[fi].intersects(_bounds(volume)):
				continue
			var hole := _section(volume, face)
			if Poly.area(hole) < 0.000001:
				continue
			var remaining: Array[PackedVector2Array] = []
			for piece in pieces:
				remaining.append_array(RoofShape.subtract(piece, hole))
			pieces = remaining
		for piece in pieces:
			kit.slab_poly(RoofShape.lift(piece, face), RoofShape.DEPTH, ChurchBuilder.SURF_ROOF, true)


## A dome is star-shaped about the centre of its base. Its rendered triangles
## and that centre make tetrahedra, so slicing them gives the exact roof joint,
## including an onion's underside. No square gap or roof through the shell.
static func dome(kit: MeshKit, profile: PackedVector2Array, center: Vector3,
		segments: int, volumes: Array[PackedVector3Array], arc := TAU, start := 0.0) -> void:
	kit.revolve(profile, center, ChurchBuilder.SURF_ROOF, segments, arc, start)
	for ring in range(profile.size() - 1):
		for i in range(segments):
			var a := start + arc * float(i) / segments
			var b := start + arc * float(i + 1) / segments
			var lo := profile[ring]
			var hi := profile[ring + 1]
			var p := PackedVector3Array([
				center + Vector3(cos(a) * lo.x, lo.y, sin(a) * lo.x),
				center + Vector3(cos(b) * lo.x, lo.y, sin(b) * lo.x),
				center + Vector3(cos(b) * hi.x, hi.y, sin(b) * hi.x),
				center + Vector3(cos(a) * hi.x, hi.y, sin(a) * hi.x)])
			for t in [[0, 1, 2], [0, 2, 3]]:
				volumes.append(PackedVector3Array([center, p[t[0]], p[t[1]], p[t[2]]]))


static func _section(volume: PackedVector3Array, face: PackedVector3Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(4):
		var a := volume[i]
		var da := a.y - RoofShape.plane_height(face, Vector2(a.x, a.z))
		for j in range(i + 1, 4):
			var b := volume[j]
			var db := b.y - RoofShape.plane_height(face, Vector2(b.x, b.z))
			if (da > 0.0) != (db > 0.0):
				var p := a.lerp(b, da / (da - db))
				points.append(Vector2(p.x, p.z))
	if points.size() < 3:
		return PackedVector2Array()
	var hull := Geometry2D.convex_hull(points)
	hull.resize(hull.size() - 1)
	return hull


static func _bounds(face: PackedVector3Array) -> Rect2:
	var bounds := Rect2(Vector2(face[0].x, face[0].z), Vector2.ZERO)
	for p in face:
		bounds = bounds.expand(Vector2(p.x, p.z))
	return bounds


## The portion of a competing face above this face, clipped at equal height.
static func _above(cover: PackedVector3Array, face: PackedVector3Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var poly := RoofShape.footprint(cover)
	var start := poly[poly.size() - 1]
	var ds := RoofShape.plane_height(cover, start) - RoofShape.plane_height(face, start)
	for end in poly:
		var de := RoofShape.plane_height(cover, end) - RoofShape.plane_height(face, end)
		if (de > 0.0) != (ds > 0.0):
			out.append(start.lerp(end, ds / (ds - de)))
		if de > 0.0:
			out.append(end)
		start = end
		ds = de
	return out


static func _gable(kit: MeshKit, faces: Array[PackedVector3Array], wall: AABB,
		rise: float, transverse := false) -> void:
	var span := wall.size.z if transverse else wall.size.x
	var along := wall.size.x if transverse else wall.size.z
	var xf := Transform3D(Basis(Vector3.UP, PI / 2.0) if transverse else Basis(),
		Vector3(wall.get_center().x, wall.end.y, wall.get_center().z))
	var local := RoofShape.faces(span + ChurchGeometry.ROOF_EAVE_X,
		along + ChurchGeometry.ROOF_EAVE_Z, rise)
	for face in local:
		faces.append(xf * face)
	_wall_heads(kit, local, Rect2(-span / 2.0, -along / 2.0, span, along), xf)


static func _aisle(spec: ChurchSpec, kit: MeshKit, faces: Array[PackedVector3Array],
		ring: int, side: float) -> void:
	var wall := ChurchGeometry.aisle_aabb(spec, side, ring)
	var inner := absf(wall.get_center().x) - wall.size.x / 2.0
	var outer := inner + wall.size.x + 0.3
	var high := wall.end.y + spec.aisle_width * 0.8
	if ring > 0:
		# The next roof meets the inner aisle WALL below its eave.
		high = minf(high, ChurchGeometry.aisle_height(spec, ring - 1) - RoofShape.DEPTH)
	else:
		high = minf(high, spec.height - RoofShape.DEPTH)
	var z0 := wall.position.z - 0.2
	var z1 := wall.end.z + 0.2
	var face := PackedVector3Array([Vector3(side * inner, high, z0),
		Vector3(side * outer, wall.end.y, z0), Vector3(side * outer, wall.end.y, z1),
		Vector3(side * inner, high, z1)])
	faces.append(face)
	var local: Array[PackedVector3Array] = []
	var xf := Transform3D(Basis(), Vector3(0, wall.end.y, 0))
	local.append(xf.affine_inverse() * face)
	_wall_heads(kit, local, Rect2(wall.position.x, wall.position.z, wall.size.x, wall.size.z), xf)


static func _wall_heads(kit: MeshKit, roof: Array[PackedVector3Array], rect: Rect2,
		xf: Transform3D) -> void:
	var corners := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y)])
	for i in range(4):
		var a := corners[i]
		var b := corners[(i + 1) % 4]
		var profile := RoofShape.wall_profile(roof, a, b)
		# Inset the wall's thickness; the external face stays on its footprint.
		var inward := Vector3(-(b - a).y, 0, (b - a).x).normalized() * 0.15
		for j in range(profile.size()):
			profile[j] += inward
		kit.slab_poly(xf * profile, 0.3, ChurchBuilder.SURF_STONE)
