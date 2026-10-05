class_name MeshIntegrityCheck
extends RefCounted
## Structural integrity rules for an emitted triangle mesh.
## This deliberately checks each face against its own winding. It does not
## infer whether separate architectural parts intersect: joined and embedded
## components are normal in building shells.

const MIN_AREA := 1e-6
const AGREE_COS := 0.5


static func check(mesh: ArrayMesh, where := "mesh") -> Array[String]:
	var failures: Array[String] = []
	if mesh == null:
		failures.append("mesh_integrity: %s has no emitted mesh" % where)
		return failures
	if mesh.get_surface_count() == 0:
		failures.append("mesh_integrity: %s has no surfaces" % where)
		return failures

	for surface in range(mesh.get_surface_count()):
		var prefix := "mesh_integrity: %s surface %d" % [where, surface]
		if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			failures.append("%s is not a triangle surface" % prefix)
			continue
		var arrays: Array = mesh.surface_get_arrays(surface)
		if arrays.size() <= Mesh.ARRAY_NORMAL or arrays[Mesh.ARRAY_VERTEX] == null:
			failures.append("%s has no vertex array" % prefix)
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals_value: Variant = arrays[Mesh.ARRAY_NORMAL]
		if normals_value == null:
			failures.append("%s has no normal array" % prefix)
			continue
		var normals: PackedVector3Array = normals_value
		if vertices.is_empty():
			failures.append("%s has no vertices" % prefix)
			continue
		if normals.size() != vertices.size():
			failures.append("%s has %d normals for %d vertices" %
				[prefix, normals.size(), vertices.size()])
			continue

		var invalid_vertices := 0
		for vertex in vertices:
			if not _finite(vertex):
				invalid_vertices += 1
		if invalid_vertices > 0:
			failures.append("%s has %d non-finite vertices" %
				[prefix, invalid_vertices])
			continue

		var invalid_normals := 0
		for normal in normals:
			if not _finite(normal) or absf(normal.length() - 1.0) > 0.01:
				invalid_normals += 1
		if invalid_normals > 0:
			failures.append("%s has %d non-finite or non-unit normals" %
				[prefix, invalid_normals])

		var index_value: Variant = arrays[Mesh.ARRAY_INDEX]
		var order: PackedInt32Array = index_value if index_value != null else PackedInt32Array()
		# Existing mesh probes treat both a null and empty ARRAY_INDEX as a
		# non-indexed triangle list. Only a non-empty array defines an index stream.
		if order.is_empty():
			for vertex_index in range(vertices.size()):
				order.append(vertex_index)
		if order.size() % 3 != 0:
			failures.append("%s has %d indices, not a multiple of three" %
				[prefix, order.size()])
			continue

		var degenerate := 0
		var bad_index := 0
		var bad_winding := 0
		var triangle_count := 0
		for offset in range(0, order.size(), 3):
			var ia := order[offset]
			var ib := order[offset + 1]
			var ic := order[offset + 2]
			if ia < 0 or ib < 0 or ic < 0 or ia >= vertices.size() \
					or ib >= vertices.size() or ic >= vertices.size():
				bad_index += 1
				continue
			var a := vertices[ia]
			var b := vertices[ib]
			var c := vertices[ic]
			# Godot treats clockwise faces as front-facing.
			var cross := (c - a).cross(b - a)
			if not _finite(cross) or cross.length() < MIN_AREA:
				degenerate += 1
				continue
			triangle_count += 1
			var geometric_normal := cross.normalized()
			if geometric_normal.dot(normals[ia]) < AGREE_COS \
					or geometric_normal.dot(normals[ib]) < AGREE_COS \
					or geometric_normal.dot(normals[ic]) < AGREE_COS:
				bad_winding += 1

		if bad_index > 0:
			failures.append("%s references %d out-of-range triangle indices" %
				[prefix, bad_index])
		if triangle_count == 0:
			failures.append("%s has no non-degenerate triangles" % prefix)
		if degenerate > 0:
			failures.append("%s has %d degenerate triangles" %
				[prefix, degenerate])
		if bad_winding > 0:
			failures.append("%s has %d triangles whose normals disagree with clockwise winding" %
				[prefix, bad_winding])
	return failures


static func _finite(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
