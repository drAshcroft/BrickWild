extends SceneTree
## Contract for MeshKit.slab_poly(open_edges): indices refer to the caller's
## original boundary segments even after duplicate/collinear cleanup or winding normalization.

var failures: Array[String] = []

func _initialize() -> void:
	var forward := PackedVector3Array([
		Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0),
		Vector3(2.0, 0.0, 0.0), Vector3(2.0, 0.0, 2.0),
		Vector3(0.0, 0.0, 2.0), Vector3(0.0, 0.0, 0.0)])
	# Edge 1 is absorbed into a single cleaned bottom edge; the explicit
	# duplicate closing vertex is absorbed too. Winding normalization reverses it.
	_check_open_edge(forward, 1, "forward input with collinear and repeated vertices")

	var reverse := PackedVector3Array([
		Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 2.0),
		Vector3(2.0, 0.0, 2.0), Vector3(2.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0)])
	# Edge 4 is the second collinear bottom segment in the other winding.
	_check_open_edge(reverse, 4, "reverse input with collinear and repeated vertices")
	_check_wrong_edge_control(reverse)
	for failure in failures:
		push_error(failure)
	print("MeshKit open-edge mapping fixture: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _check_open_edge(points: PackedVector3Array, edge_index: int, label: String) -> void:
	var kit := MeshKit.new(1)
	kit.slab_poly(points, 0.2, 0, true, PackedInt32Array([edge_index]))
	var mesh: ArrayMesh = kit.commit()
	if _edge_face_count(mesh, 0.0) != 0:
		failures.append("%s: original edge %d still emitted after cleanup/winding" % [label, edge_index])
	if _edge_face_count(mesh, 2.0) != 2:
		failures.append("%s: unselected opposing boundary face was lost" % label)
	var closed := MeshKit.new(1)
	closed.slab_poly(points, 0.2, 0, true)
	if _edge_face_count(closed.commit(), 0.0) != 2:
		failures.append("%s: closed-edge control did not emit the actual boundary face" % label)


func _check_wrong_edge_control(points: PackedVector3Array) -> void:
	var kit := MeshKit.new(1)
	# Edge 2 is a side, not the bottom bearing edge. The same plane predicate
	# must still see the z=0 side when the caller selects the wrong edge.
	kit.slab_poly(points, 0.2, 0, true, PackedInt32Array([2]))
	if _edge_face_count(kit.commit(), 0.0) != 2:
		failures.append("wrong-edge negative passed without the actual z=0 face")


func _edge_face_count(mesh: ArrayMesh, z: float) -> int:
	if mesh == null or mesh.get_surface_count() == 0:
		return 0
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
		if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for i in range(vertices.size()):
			indices.append(i)
	var count := 0
	for i in range(0, indices.size(), 3):
		var a: Vector3 = vertices[indices[i]]
		var b: Vector3 = vertices[indices[i + 1]]
		var c: Vector3 = vertices[indices[i + 2]]
		if absf(a.z - z) < 0.00001 and absf(b.z - z) < 0.00001 \
				and absf(c.z - z) < 0.00001:
			count += 1
	return count
