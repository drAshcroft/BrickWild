extends RefCounted
## VIS-003: architectural emitters carry metres in UV while ordinary meshes
## retain the historical unit-square/constant UV contract.

static func run() -> SuiteResult:
	var res := SuiteResult.new("metric coordinates")
	_check_box(res, Vector3(2.0, 2.0, 2.0), "2 m box")
	_check_box(res, Vector3(20.0, 20.0, 0.6), "20 m wall")
	_check_roof(res)
	_check_drums(res, 12)
	_check_drums(res, 16)
	_check_half_cylinder(res)
	_check_partial_sweep(res)
	_check_default_uvs(res)
	_check_builders(res)
	return res


static func _check_box(res: SuiteResult, size: Vector3, label: String) -> void:
	var kit := MeshKit.new(1, true)
	kit.box(size, Vector3.ZERO, 0)
	_check_projected_faces(res, kit.commit(), label)


static func _check_roof(res: SuiteResult) -> void:
	var kit := MeshKit.new(1, true)
	var points := PackedVector3Array([
		Vector3(-10.0, 0.0, -10.0), Vector3(10.0, 0.0, -10.0),
		Vector3(0.0, 8.0, 10.0)])
	kit.slab_poly(points, 0.24, 0)
	_check_projected_faces(res, kit.commit(), "sloped roof")


static func _check_drums(res: SuiteResult, sides: int) -> void:
	var kit := MeshKit.new(1, true)
	kit.drum(Vector3.ZERO, 5.0, 4.0, 12.0, 0, sides)
	var mesh := kit.commit()
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	res.checked += 1
	if vertices.size() != uvs.size() or vertices.size() % 3 != 0:
		res.fail("%d-sided drum has mismatched UV and vertex arrays" % sides)
		return
	for i in range(0, vertices.size(), 3):
		if vertices[i].y > 11.999 and vertices[i + 1].y > 11.999 \
				and vertices[i + 2].y > 11.999:
			continue # planar top cap has its own planar chart
		for j in range(3):
			var p: Vector3 = vertices[i + j]
			var radius := Vector2(p.x, p.z).length()
			var angle := atan2(p.z, p.x)
			if angle < 0.0:
				angle += TAU
			var expected_u := angle * radius
			var expected_v := sqrt(145.0) * p.y / 12.0
			if absf(uvs[i + j].x - expected_u) > 0.003 \
					or absf(uvs[i + j].y - expected_v) > 0.003:
				res.fail("%d-sided drum coordinates do not follow circumference/profile metres" % sides)
				return
	# Adjacent angular segments and profile bands share the same metric value at
	# every common vertex. The one permitted discontinuity is the circumference
	# wrap where the texture repeats.
	for a in range(vertices.size()):
		for b in range(a + 1, vertices.size()):
			if vertices[a].y > 11.999 or vertices[b].y > 11.999:
				continue # cap chart meets the barrel at this edge
			if vertices[a].distance_to(vertices[b]) > 0.0001:
				continue
			if absf(uvs[a].y - uvs[b].y) > 0.0001:
				res.fail("%d-sided drum resets course height at a shared vertex" % sides)
				return
			if absf(uvs[a].x - uvs[b].x) > 0.0001 \
					and absf(uvs[a].x - uvs[b].x) < 20.0:
				res.fail("%d-sided drum has an interior U reset" % sides)
				return
	res.checked += 1


static func _check_half_cylinder(res: SuiteResult) -> void:
	var metric := MeshKit.new(1, true)
	metric.half_cylinder(4.0, 6.0, Vector2.ZERO, 0, 12)
	var arrays: Array = metric.commit().surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var top_triangles := 0
	for i in range(0, vertices.size(), 3):
		if normals[i].y < 0.99:
			continue
		top_triangles += 1
		for j in range(3):
			if uvs[i + j].distance_to(Vector2(vertices[i + j].x,
					-vertices[i + j].z)) > 0.0001:
				res.fail("half-cylinder top fan does not use its planar metre chart")
				return
	res.checked += 1
	if top_triangles != 12:
		res.fail("half-cylinder top fan emitted %d metric triangles, expected 12" % top_triangles)
		return
	var legacy := MeshKit.new(1)
	legacy.half_cylinder(4.0, 6.0, Vector2.ZERO, 0, 12)
	var legacy_uvs: PackedVector2Array = legacy.commit().surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var start := legacy_uvs.size() - 36
	var first_cap := [Vector2.ZERO, Vector2(1, 0), Vector2(1, 1)]
	for i in range(3):
		if legacy_uvs[start + i] != first_cap[i]:
			res.fail("legacy half-cylinder UV chart changed")
			return


static func _check_partial_sweep(res: SuiteResult) -> void:
	var metric := MeshKit.new(1, true)
	metric.revolve(PackedVector2Array([Vector2(4.0, 0.0),
		Vector2(4.0, 6.0)]), Vector3.ZERO, 0, 12, PI)
	var arrays: Array = metric.commit().surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var cap_triangles := 0
	for i in range(0, vertices.size(), 3):
		if absf(normals[i].z) < 0.99 \
				or absf(vertices[i].z - vertices[i + 1].z) > 0.001 \
				or absf(vertices[i].z - vertices[i + 2].z) > 0.001:
			continue
		cap_triangles += 1
		var u := Vector3.UP.cross(normals[i]).normalized()
		if u.length_squared() < 0.001:
			u = Vector3.RIGHT
		var v := normals[i].cross(u).normalized()
		for j in range(3):
			var expected := Vector2(vertices[i + j].dot(u), vertices[i + j].dot(v))
			if uvs[i + j].distance_to(expected) > 0.0001:
				res.fail("partial-sweep end cap does not use planar metre coordinates")
				return
	res.checked += 1
	if cap_triangles < 4:
		res.fail("partial sweep lost one or both planar end caps")
		return
	var legacy := MeshKit.new(1)
	legacy.revolve(PackedVector2Array([Vector2(4.0, 0.0),
		Vector2(4.0, 6.0)]), Vector3.ZERO, 0, 12, PI)
	var legacy_uvs: PackedVector2Array = legacy.commit().surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	for i in range(legacy_uvs.size() - cap_triangles * 3, legacy_uvs.size()):
		if legacy_uvs[i] != Vector2.ZERO:
			res.fail("legacy partial-sweep cap UVs changed")
			return
static func _check_projected_faces(res: SuiteResult, mesh: ArrayMesh, label: String) -> void:
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		res.checked += 1
		if vertices.size() != normals.size() or vertices.size() != uvs.size():
			res.fail("%s surface %d has mismatched vertex, normal, and UV counts" % [label, surface])
			continue
		if vertices.size() % 3 != 0:
			res.fail("%s surface %d is not triangle aligned" % [label, surface])
			continue
		for i in range(0, vertices.size(), 3):
			for edge in [[0, 1], [1, 2], [2, 0]]:
				var a: int = i + int(edge[0])
				var b: int = i + int(edge[1])
				if not uvs[a].is_finite() or not uvs[b].is_finite() \
						or absf(uvs[a].distance_to(uvs[b]) \
						- vertices[a].distance_to(vertices[b])) > 0.002:
					res.fail("%s has a triangle-local UV reset or non-metric edge" % label)
					return


static func _check_default_uvs(res: SuiteResult) -> void:
	var legacy := MeshKit.new(1)
	legacy.box(Vector3(2.0, 2.0, 2.0), Vector3.ZERO, 0)
	var arrays: Array = legacy.commit().surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	res.checked += 1
	# Each face is one 0..1 square, both triangles reading its corners. The
	# second triangle used to repeat the first's UVs, which sheared every
	# per-face texture along the diagonal (castle walk pin 11, 6 Oct).
	var expected := [Vector2.ZERO, Vector2(1, 0), Vector2.ONE,
		Vector2.ZERO, Vector2.ONE, Vector2(0, 1)]
	for i in range(expected.size()):
		if uvs[i] != expected[i]:
			res.fail("default MeshKit UVs are not one 0..1 square per face")
			return


static func _check_builders(res: SuiteResult) -> void:
	var church_spec := ChurchSpec.new()
	ChurchGenerator.generate(church_spec, 3067)
	var church := ChurchBuilder.new().build(church_spec)
	var castle_spec := CastleSpec.new()
	CastleGenerator.generate(castle_spec, 3067)
	var castle := CastleBuilder.new().build(castle_spec)
	for pair in [[church, "church"], [castle, "castle"]]:
		var mesh: ArrayMesh = pair[0]
		var label: String = pair[1]
		res.checked += 1
		if mesh == null or mesh.get_surface_count() != 4:
			res.fail("%s builder changed its four-surface material contract" % label)
			continue
		var arrays: Array = mesh.surface_get_arrays(0)
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var finite_uvs := not uvs.is_empty()
		for uv in uvs:
			finite_uvs = finite_uvs and uv.is_finite()
		if not finite_uvs:
			res.fail("%s stone surface has no finite metric coordinates" % label)
	var church_again := ChurchBuilder.new().build(church_spec)
	var castle_again := CastleBuilder.new().build(castle_spec)
	for pair in [[church, church_again, "church"], [castle, castle_again, "castle"]]:
		var first: ArrayMesh = pair[0]
		var second: ArrayMesh = pair[1]
		var label: String = pair[2]
		res.checked += 1
		if first.get_surface_count() != second.get_surface_count():
			res.fail("%s material surface order changed on repeat build" % label)
			continue
		for surface in range(first.get_surface_count()):
			var a: Array = first.surface_get_arrays(surface)
			var b: Array = second.surface_get_arrays(surface)
			if a[Mesh.ARRAY_VERTEX] != b[Mesh.ARRAY_VERTEX] \
					or a[Mesh.ARRAY_NORMAL] != b[Mesh.ARRAY_NORMAL] \
					or a[Mesh.ARRAY_TEX_UV] != b[Mesh.ARRAY_TEX_UV]:
				res.fail("%s surface %d is not stable across regeneration" % [label, surface])
				break
