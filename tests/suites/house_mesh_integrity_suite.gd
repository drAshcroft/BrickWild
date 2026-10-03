extends RefCounted

const Integrity := preload("res://qa/mesh_integrity_check.gd")


static func run() -> SuiteResult:
	var res := SuiteResult.new("house mesh integrity")
	var valid := _triangle_mesh()
	if not _has_surfaces(res, valid, 1, "non-indexed positive control"):
		return res
	_expect(res, Integrity.check(valid).is_empty(),
		"non-indexed clockwise face with matching unit normals was rejected")
	var indexed := _triangle_mesh(true)
	if not _has_surfaces(res, indexed, 1, "indexed positive control"):
		return res
	_expect(res, Integrity.check(indexed).is_empty(),
		"indexed clockwise face with matching unit normals was rejected")

	var flipped := _triangle_mesh()
	if not _has_surfaces(res, flipped, 1, "flipped-normal negative control"):
		return res
	var flipped_arrays: Array = flipped.surface_get_arrays(0)
	var flipped_normals: PackedVector3Array = flipped_arrays[Mesh.ARRAY_NORMAL]
	for i in range(flipped_normals.size()):
		flipped_normals[i] = -flipped_normals[i]
	flipped_arrays[Mesh.ARRAY_NORMAL] = flipped_normals
	var flipped_mesh := _mesh_with_surface(flipped_arrays)
	_expect(res, _has_failure(Integrity.check(flipped_mesh), "winding"),
		"flipped normals were not rejected")

	var non_finite := _triangle_mesh()
	if not _has_surfaces(res, non_finite, 1, "non-finite-vertex negative control"):
		return res
	var non_finite_arrays: Array = non_finite.surface_get_arrays(0)
	var non_finite_vertices: PackedVector3Array = non_finite_arrays[Mesh.ARRAY_VERTEX]
	non_finite_vertices[1].x = INF
	non_finite_arrays[Mesh.ARRAY_VERTEX] = non_finite_vertices
	_expect(res, _has_failure(Integrity.check(_mesh_with_surface(non_finite_arrays)),
		"non-finite vertices"), "non-finite vertex was not rejected")

	var degenerate := _triangle_mesh()
	if not _has_surfaces(res, degenerate, 1, "degenerate-triangle negative control"):
		return res
	var degenerate_arrays: Array = degenerate.surface_get_arrays(0)
	var degenerate_vertices: PackedVector3Array = degenerate_arrays[Mesh.ARRAY_VERTEX]
	degenerate_vertices[2] = degenerate_vertices[1]
	degenerate_arrays[Mesh.ARRAY_VERTEX] = degenerate_vertices
	var multi_surface := _triangle_mesh()
	# The defect is on surface one. This proves the checker visits every surface.
	var second_mesh := ArrayMesh.new()
	second_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
		multi_surface.surface_get_arrays(0))
	second_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, degenerate_arrays)
	if not _has_surfaces(res, second_mesh, 2, "later-surface negative control"):
		return res
	_expect(res, _has_failure(Integrity.check(second_mesh), "surface 1") and
			_has_failure(Integrity.check(second_mesh), "degenerate triangles"),
		"degenerate triangle on a later surface was not rejected")

	_actual_house_mesh(res)
	return res


static func _actual_house_mesh(res: SuiteResult) -> void:
	var spec := HouseSpec.new()
	spec.style = &"farmhouse"
	spec.width = 10.0
	spec.length = 13.0
	spec.height = 2.7
	spec.storeys = 1
	var plan: HousePlan = HouseGenerator.generate(spec, 4413, false)
	var builder := HouseBuilder.new()
	var mesh: ArrayMesh = builder.build(plan)
	res.checked += 1
	if mesh == null or mesh.get_surface_count() < 2:
		res.fail("farmhouse fixture did not emit multiple mesh surfaces")
		return
	for failure in Integrity.check(mesh, "farmhouse seed=4413"):
		res.fail(String(failure))


static func _triangle_mesh(indexed := false) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3.ZERO, Vector3(0, 1, 0), Vector3(1, 0, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([
		Vector3.BACK, Vector3.BACK, Vector3.BACK])
	if indexed:
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	return _mesh_with_surface(arrays)


static func _mesh_with_surface(arrays: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh if mesh.get_surface_count() == 1 else null


static func _has_surfaces(res: SuiteResult, mesh: ArrayMesh, expected: int,
		label: String) -> bool:
	res.checked += 1
	if mesh == null or mesh.get_surface_count() != expected:
		res.fail("%s did not construct %d surfaces" % [label, expected])
		return false
	return true


static func _has_failure(failures: Array[String], needle: String) -> bool:
	for failure in failures:
		if failure.contains(needle):
			return true
	return false


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)
