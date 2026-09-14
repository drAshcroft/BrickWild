extends RefCounted
## Fast, unfurnished regression for the hotel caller's rotated ridge roof.
##
## This deliberately goes through the same public plan/build path as the hotel
## family, while keeping the assertion set about the shell and roof only.  It
## is intended for the inner loop; the full hotel landmark suite remains the
## place for programme, furnishing, and circulation coverage.

const ROOF_SURFACE := 2
const WALL_SURFACE := 0
const ROOF_DEPTH := 0.24
const YAW := PI / 2.0


static func run() -> SuiteResult:
	var res := SuiteResult.new("hotel roof smoke")
	var spec := HotelSpec.new()
	spec.style = &"grand_budapest"
	spec.width = 42.0
	spec.length = 24.0
	spec.height = 3.6
	var plan := HotelGenerator.generate(spec, 48117, false)
	var builder := HotelBuilder.new()
	var mesh := builder.build(plan)

	_expect(res, plan.furniture.is_empty(), "smoke plan unexpectedly furnished")
	_expect(res, mesh != null and mesh.get_surface_count() == 4,
		"hotel build did not produce four expected surfaces")
	if mesh == null or mesh.get_surface_count() < 3:
		return res

	_check_surface(res, mesh, WALL_SURFACE, "wall")
	_check_surface(res, mesh, ROOF_SURFACE, "roof")
	_check_rotated_roof(res, mesh, spec)
	_check_wall_roof_contact(res, mesh, spec)
	return res


static func _expect(res: SuiteResult, condition: bool, message: String) -> void:
	res.checked += 1
	if not condition:
		res.fail(message)


static func _check_surface(res: SuiteResult, mesh: ArrayMesh, surface: int,
		label: String) -> void:
	var arrays := mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var valid := not vertices.is_empty() and vertices.size() == normals.size() \
		and vertices.size() % 3 == 0
	for p in vertices:
		if not p.is_finite():
			valid = false
	for n in normals:
		if not n.is_finite() or n.length_squared() < 0.9:
			valid = false
	_expect(res, valid, "%s surface is empty, malformed, or non-finite" % label)


## HotelBuilder supplies ridge_roof() a ninety-degree yaw: its local ridge
## (local Z) therefore runs along world X, while local span (local X) runs
## along world Z. Probe actual emitted vertices at both transformed eaves so a
## future caller can not silently drop that transform or swap the dimensions.
static func _check_rotated_roof(res: SuiteResult, mesh: ArrayMesh,
		spec: HotelSpec) -> void:
	var arrays := mesh.surface_get_arrays(ROOF_SURFACE)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var top := HotelGeometry.wall_top(spec)
	var span := spec.length + 1.0
	var along := spec.width + 1.0
	var xf := Transform3D(Basis(Vector3.UP, YAW), Vector3(0.0, top, 0.0))
	# RoofShape stores the eave as its four corner endpoints (rather than
	# inserting a midpoint on each long edge), so probe two real corners.
	var span_eave := xf * Vector3(span * 0.5, 0.0, along * 0.5)
	var along_eave := xf * Vector3(-span * 0.5, 0.0, along * 0.5)
	_expect(res, _has_eave_vertex(vertices, span_eave),
		"rotated hotel roof lost transformed span eave")
	_expect(res, _has_eave_vertex(vertices, along_eave),
		"rotated hotel roof lost transformed ridge-axis eave")

	# Restrict the bounds to the main eave band so dormers and cupolas do not
	# affect the footprint measurement.
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for p in vertices:
		if p.y < top - 0.14 or p.y > top + 0.14:
			continue
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_z = minf(min_z, p.z)
		max_z = maxf(max_z, p.z)
	_expect(res, is_finite(min_x) and absf((max_x - min_x) - along) < 0.05,
		"hotel roof yaw did not place local ridge axis along world X")
	_expect(res, is_finite(min_z) and max_z - min_z >= span - 0.01 \
			and max_z - min_z <= span + 0.4,
		"hotel roof yaw did not place local span along world Z")


static func _has_eave_vertex(vertices: PackedVector3Array, target: Vector3) -> bool:
	for p in vertices:
		if absf(p.y - target.y) <= ROOF_DEPTH * 0.51 \
				and Vector2(p.x, p.z).distance_squared_to(Vector2(target.x, target.z)) <= 0.0001:
			return true
	return false


## The roof's underside is sampled on all four wall runs.  At every interior
## sample, a short vertical segment must cross an emitted roof triangle and a
## horizontal segment at that same height must cross an emitted wall/closure
## triangle.  This measures actual mesh contact, including ridge_roof's wall
## profiles, instead of trusting part or mass counts.
static func _check_wall_roof_contact(res: SuiteResult, mesh: ArrayMesh,
		spec: HotelSpec) -> void:
	var roof_tris := _triangles(mesh, ROOF_SURFACE)
	var wall_tris := _triangles(mesh, WALL_SURFACE)
	var top := HotelGeometry.wall_top(spec)
	var span := spec.length + 1.0
	var along := spec.width + 1.0
	var wall_span := spec.length
	var wall_along := spec.width
	var xf := Transform3D(Basis(Vector3.UP, YAW), Vector3(0.0, top, 0.0))
	var faces := RoofShape.faces(span, along, spec.roof_rise)
	var h := wall_span * 0.5
	var f := wall_along * 0.5
	var edges := [
		[Vector2(-h, -f), Vector2(h, -f)],
		[Vector2(h, -f), Vector2(h, f)],
		[Vector2(h, f), Vector2(-h, f)],
		[Vector2(-h, f), Vector2(-h, -f)],
	]
	var all_contact := true
	for edge in edges:
		for i in range(1, 5):
			var p: Vector2 = edge[0].lerp(edge[1], float(i) / 5.0)
			var roof_y := RoofShape.height_at(faces, p) - ROOF_DEPTH * 0.5
			if is_nan(roof_y):
				all_contact = false
				continue
			var world := xf * Vector3(p.x, roof_y, p.y)
			var roof_hit := _hits(roof_tris,
				world + Vector3.UP * 0.32, world - Vector3.UP * 0.32)
			# Probe through the wall thickness in the horizontal direction. The
			# segment is long enough for either an exterior wall or ridge_roof's
			# end-wall closure profile, but remains local to this sample.
			var tangent: Vector2 = (edge[1] - edge[0]).normalized()
			var outward: Vector2 = Vector2(-tangent.y, tangent.x)
			# Move just inside the closure (2.5 cm below the underside) so the
			# segment crosses its solid rather than grazing a coplanar boundary.
			var wall_y := roof_y - 0.025
			var a := xf * Vector3(p.x + outward.x * 0.35, wall_y, p.y + outward.y * 0.35)
			var b := xf * Vector3(p.x - outward.x * 0.35, wall_y, p.y - outward.y * 0.35)
			var wall_hit := _hits(wall_tris, a, b)
			if roof_hit.is_empty() or wall_hit.is_empty():
				all_contact = false
	_expect(res, all_contact,
		"hotel roof underside does not continuously contact emitted wall closure")


static func _triangles(mesh: ArrayMesh, surface: int) -> Array:
	var out: Array = []
	if surface < 0 or surface >= mesh.get_surface_count():
		return out
	var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
	if vertices.size() % 3 != 0:
		return out
	for i in range(0, vertices.size(), 3):
		out.append([vertices[i], vertices[i + 1], vertices[i + 2]])
	return out


static func _hits(tris: Array, a: Vector3, b: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for tri in tris:
		var hit = Geometry3D.segment_intersects_triangle(a, b, tri[0], tri[1], tri[2])
		if hit != null:
			out.append(hit)
	return out
