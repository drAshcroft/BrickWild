extends SceneTree
## Actual imported triangles verify book contact independently of plan rectangles.
var failures: Array[String] = []

func _init() -> void:
	var spec := HouseSpec.new()
	spec.style = &"witch_hut"
	spec.width = 11.0
	spec.length = 14.0
	spec.height = 2.6
	spec.storeys = 1
	var plan := HouseGenerator.generate(spec, 1, true)
	var tested := 0
	for item in plan.furniture:
		if String(item.get("activity_group", "")) != "witchwork" or String(item.get("cat", "")) != "books":
			continue
		var index := int(item.get("host", -1))
		if index < 0 or index >= plan.furniture.size():
			failures.append("book lacks a support index")
			continue
		var host := HouseAssembler._instance(plan.furniture[index])
		var child := HouseAssembler._instance(item)
		if host == null or child == null:
			failures.append("imported book or workbench did not assemble")
			if host != null: host.free()
			if child != null: child.free()
			continue
		var host_triangles := _triangles(host)
		if not _rests_on_mesh(child, host_triangles):
			failures.append("actual book bottom is not supported by actual workbench triangles")
		child.position.y += 0.1
		if _rests_on_mesh(child, host_triangles):
			failures.append("floating-book negative was accepted")
		host.free()
		child.free()
		tested += 1
	if tested != 1:
		failures.append("expected exactly one actual Witchwork book")
	for failure in failures: printerr("FAIL ", failure)
	print("witch book actual mesh contact: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

func _rests_on_mesh(child: Node3D, host_triangles: Array) -> bool:
	var triangles := _triangles(child)
	if triangles.is_empty() or host_triangles.is_empty(): return false
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for triangle in triangles:
		for point in triangle:
			low = low.min(point)
			high = high.max(point)
	for sample in [Vector2((low.x + high.x) * 0.5, (low.z + high.z) * 0.5),
		Vector2(low.x + 0.01, low.z + 0.01), Vector2(high.x - 0.01, low.z + 0.01),
		Vector2(low.x + 0.01, high.z - 0.01), Vector2(high.x - 0.01, high.z - 0.01)]:
		var top := -INF
		for triangle in host_triangles:
			top = maxf(top, _height_at(triangle, sample))
		if not is_finite(top) or absf(top - low.y) > 0.02:
			print("MESH_CONTACT sample=", sample, " actual_top=", top, " book_bottom=", low.y)
			return false
	return true

func _height_at(triangle: Array, sample: Vector2) -> float:
	var a: Vector3 = triangle[0]
	var b: Vector3 = triangle[1]
	var c: Vector3 = triangle[2]
	var u := Vector2(b.x - a.x, b.z - a.z)
	var v := Vector2(c.x - a.x, c.z - a.z)
	var q := sample - Vector2(a.x, a.z)
	var determinant := u.cross(v)
	if absf(determinant) < 0.000001: return -INF
	var s := q.cross(v) / determinant
	var t := u.cross(q) / determinant
	if s < -0.0001 or t < -0.0001 or s + t > 1.0001: return -INF
	return a.y + s * (b.y - a.y) + t * (c.y - a.y)

func _triangles(node: Node3D) -> Array:
	var out: Array = []
	var pending: Array[Node] = [node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current is MeshInstance3D and (current as MeshInstance3D).mesh != null:
			var instance := current as MeshInstance3D
			var transform := instance.transform
			var parent := instance.get_parent()
			while parent is Node3D:
				transform = (parent as Node3D).transform * transform
				parent = parent.get_parent()
			for surface in instance.mesh.get_surface_count():
				var arrays := instance.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: Variant = arrays[Mesh.ARRAY_INDEX]
				var indexed: bool = indices is PackedInt32Array and not indices.is_empty()
				var count: int = indices.size() if indexed else vertices.size()
				for i in range(0, count - 2, 3):
					var triangle: Array = []
					for j in 3:
						triangle.append(transform * vertices[int(indices[i + j]) if indexed else i + j])
					out.append(triangle)
		for next in current.get_children(): pending.append(next)
	return out
