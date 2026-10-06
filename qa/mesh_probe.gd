class_name MeshProbe
extends RefCounted
## Shared emitted-triangle probes for the world families (WORLD-MESH-VERIFY).
##
## A mass log or component log says what a builder INTENDED to emit. These
## helpers ask the finished triangles instead: is there an upward-facing face
## under this point, is this sight line blocked by any face at all. Nagara,
## stepwell, mountain and Dravida all read triangles through here; keep it the
## one copy. Negative controls delete real triangles with remove_triangles()
## while the logs stay, so the check cannot be satisfied by a log alone.

## Triangles of one surface as [a, b, c] vertex triples. `mesh` wins when given
## (a caller-supplied or mutated mesh); otherwise the builder's SurfaceTool is
## read. `surface` is the builder's slot, which equals the committed index only
## while no earlier slot is empty -- true for every family using this.
static func surface_triangles(builder: MassBuilder, mesh: ArrayMesh,
		surface: int) -> Array:
	var arrays: Array
	if mesh != null:
		if surface >= mesh.get_surface_count():
			return []
		arrays = mesh.surface_get_arrays(surface)
	else:
		if builder == null or builder._kit == null or surface >= builder._kit._sts.size():
			return []
		arrays = builder._kit.surface(surface).commit_to_arrays()
	if arrays.size() <= Mesh.ARRAY_INDEX:
		return []
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return []
	var index_value: Variant = arrays[Mesh.ARRAY_INDEX]
	var order: PackedInt32Array = index_value if index_value != null else PackedInt32Array()
	if order.is_empty():
		order = PackedInt32Array()
		for i in range(vertices.size()):
			order.append(i)
	var triangles: Array = []
	for i in range(0, order.size() - 2, 3):
		var ia := order[i]
		var ib := order[i + 1]
		var ic := order[i + 2]
		if ia >= 0 and ib >= 0 and ic >= 0 and ia < vertices.size() \
				and ib < vertices.size() and ic < vertices.size():
			triangles.append([vertices[ia], vertices[ib], vertices[ic]])
	return triangles


## Every surface's triangles, concatenated.
static func all_triangles(builder: MassBuilder, mesh: ArrayMesh,
		surface_count: int) -> Array:
	var out: Array = []
	for surface in range(surface_count):
		out.append_array(surface_triangles(builder, mesh, surface))
	return out


## True when an upward-facing triangle crosses (point.x, y, point.y).
static func has_upward_support(triangles: Array, point: Vector2, y: float,
		tolerance := 0.02) -> bool:
	var from := Vector3(point.x, y + tolerance + 0.005, point.y)
	var to := Vector3(point.x, y - tolerance - 0.005, point.y)
	for triangle in triangles:
		var a: Vector3 = triangle[0]
		var b: Vector3 = triangle[1]
		var c: Vector3 = triangle[2]
		if point.x < minf(a.x, minf(b.x, c.x)) - 0.01 or point.x > maxf(a.x, maxf(b.x, c.x)) + 0.01 \
				or point.y < minf(a.z, minf(b.z, c.z)) - 0.01 or point.y > maxf(a.z, maxf(b.z, c.z)) + 0.01:
			continue
		# Godot front faces are clockwise: outward normal is (c - a) x (b - a).
		var face := (c - a).cross(b - a)
		if face.length_squared() < 1e-12 or face.normalized().dot(Vector3.UP) < 0.95:
			continue
		var hit: Variant = Geometry3D.segment_intersects_triangle(from, to, a, b, c)
		if hit != null and absf((hit as Vector3).y - y) <= tolerance:
			return true
	return false


## True when ANY face, whatever its orientation, crosses the segment.
static func ray_blocked(triangles: Array, from: Vector3, to: Vector3) -> bool:
	var low := Vector3(minf(from.x, to.x), minf(from.y, to.y), minf(from.z, to.z)) - Vector3.ONE * 0.01
	var high := Vector3(maxf(from.x, to.x), maxf(from.y, to.y), maxf(from.z, to.z)) + Vector3.ONE * 0.01
	for triangle in triangles:
		var a: Vector3 = triangle[0]
		var b: Vector3 = triangle[1]
		var c: Vector3 = triangle[2]
		# Cheap reject: the triangle's box must overlap the segment's box.
		if maxf(a.x, maxf(b.x, c.x)) < low.x or minf(a.x, minf(b.x, c.x)) > high.x \
				or maxf(a.y, maxf(b.y, c.y)) < low.y or minf(a.y, minf(b.y, c.y)) > high.y \
				or maxf(a.z, maxf(b.z, c.z)) < low.z or minf(a.z, minf(b.z, c.z)) > high.z:
			continue
		if Geometry3D.segment_intersects_triangle(from, to, a, b, c) != null:
			return true
	return false


## Count of upward probes found over `samples`; callers report supported/total.
static func supported_count(triangles: Array, samples: Array[Vector2],
		y: float) -> int:
	var supported := 0
	for sample in samples:
		if has_upward_support(triangles, sample, y):
			supported += 1
	return supported


## Probe points on a rectangle: the centre line at the given fractions along
## its long axis, and (when `across` > 1) that many lines across the short axis.
static func rect_samples(rect: Rect2, along: Array = [0.25, 0.5, 0.75],
		across: Array = [0.5]) -> Array[Vector2]:
	var samples: Array[Vector2] = []
	var long_x := rect.size.x >= rect.size.y
	for fraction in along:
		for cross in across:
			if long_x:
				samples.append(Vector2(lerpf(rect.position.x, rect.end.x, fraction),
					lerpf(rect.position.y, rect.end.y, cross)))
			else:
				samples.append(Vector2(lerpf(rect.position.x, rect.end.x, cross),
					lerpf(rect.position.y, rect.end.y, fraction)))
	return samples


## A copy of `source` without the triangles for which `predicate(a, b, c)` is
## true on `surface`. Logs are not the mesh's business, so they are untouched:
## that is the point of the negative control.
static func remove_triangles(source: ArrayMesh, surface: int,
		predicate: Callable) -> Dictionary:
	if source == null or surface >= source.get_surface_count():
		return {"mesh": null, "removed_triangles": 0}
	var result := ArrayMesh.new()
	var removed := 0
	for surface_index in range(source.get_surface_count()):
		var arrays: Array = source.surface_get_arrays(surface_index).duplicate(true)
		var index_value: Variant = arrays[Mesh.ARRAY_INDEX]
		var indices: PackedInt32Array = index_value if index_value != null else PackedInt32Array()
		if indices.is_empty():
			arrays[Mesh.ARRAY_INDEX] = null
		if surface_index == surface:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var order := indices.duplicate()
			if order.is_empty():
				for i in range(vertices.size()):
					order.append(i)
			var kept := PackedInt32Array()
			for i in range(0, order.size() - 2, 3):
				var a: Vector3 = vertices[order[i]]
				var b: Vector3 = vertices[order[i + 1]]
				var c: Vector3 = vertices[order[i + 2]]
				if bool(predicate.call(a, b, c)):
					removed += 1
				else:
					kept.append(order[i])
					kept.append(order[i + 1])
					kept.append(order[i + 2])
			arrays[Mesh.ARRAY_INDEX] = kept
		result.add_surface_from_arrays(source.surface_get_primitive_type(surface_index), arrays)
		result.surface_set_material(surface_index, source.surface_get_material(surface_index))
		result.surface_set_name(surface_index, source.surface_get_name(surface_index))
	if result.get_surface_count() != source.get_surface_count():
		return {"mesh": null, "removed_triangles": removed}
	return {"mesh": result, "removed_triangles": removed}


## Predicate: an upward face whose centre lies in `footprint` at `height`.
static func top_face_in(footprint: Rect2, height: float, tolerance := 0.01) -> Callable:
	return func(a: Vector3, b: Vector3, c: Vector3) -> bool:
		var face := (c - a).cross(b - a)
		var centre := (a + b + c) / 3.0
		return face.length_squared() > 1e-12 and face.normalized().dot(Vector3.UP) > 0.95 \
			and absf(centre.y - height) <= tolerance \
			and footprint.has_point(Vector2(centre.x, centre.z))


## Predicate: any face whose centre lies inside `box` (any orientation).
static func any_face_in(box: AABB) -> Callable:
	return func(a: Vector3, b: Vector3, c: Vector3) -> bool:
		return box.has_point((a + b + c) / 3.0)


## A copy of `source` with a solid box (12 triangles) added to `surface`: the
## negative control for an aperture that must stay open. Other vertex arrays
## are padded with zeros so the surface stays well formed.
static func add_box(source: ArrayMesh, surface: int, box: AABB) -> Dictionary:
	if source == null or surface >= source.get_surface_count():
		return {"mesh": null, "added_triangles": 0}
	var corners: Array[Vector3] = []
	for i in range(8):
		corners.append(box.position + Vector3(
			box.size.x * float(i & 1), box.size.y * float((i >> 1) & 1),
			box.size.z * float((i >> 2) & 1)))
	var faces := [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6],
		[0, 2, 6, 4], [1, 5, 7, 3]]
	var result := ArrayMesh.new()
	for surface_index in range(source.get_surface_count()):
		var arrays: Array = source.surface_get_arrays(surface_index).duplicate(true)
		var index_value: Variant = arrays[Mesh.ARRAY_INDEX]
		var indices: PackedInt32Array = index_value if index_value != null else PackedInt32Array()
		if surface_index == surface:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if indices.is_empty():
				for i in range(vertices.size()):
					indices.append(i)
			var base := vertices.size()
			for face in faces:
				var start := vertices.size()
				for corner in face:
					vertices.append(corners[corner])
				for k in [0, 1, 2, 0, 2, 3]:
					indices.append(start + k)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			var added := vertices.size() - base
			for slot in range(arrays.size()):
				if slot == Mesh.ARRAY_VERTEX or slot == Mesh.ARRAY_INDEX or arrays[slot] == null:
					continue
				var column: Variant = arrays[slot]
				if column is PackedVector3Array:
					var v3: PackedVector3Array = column
					for i in range(added):
						v3.append(Vector3.UP)
					arrays[slot] = v3
				elif column is PackedVector2Array:
					var v2: PackedVector2Array = column
					for i in range(added):
						v2.append(Vector2.ZERO)
					arrays[slot] = v2
				elif column is PackedColorArray:
					var col: PackedColorArray = column
					for i in range(added):
						col.append(Color.WHITE)
					arrays[slot] = col
				elif column is PackedFloat32Array:
					var f: PackedFloat32Array = column
					for i in range(added * 4):
						f.append(0.0)
					arrays[slot] = f
			arrays[Mesh.ARRAY_INDEX] = indices
		elif indices.is_empty():
			arrays[Mesh.ARRAY_INDEX] = null
		result.add_surface_from_arrays(source.surface_get_primitive_type(surface_index), arrays)
		result.surface_set_material(surface_index, source.surface_get_material(surface_index))
		result.surface_set_name(surface_index, source.surface_get_name(surface_index))
	return {"mesh": result, "added_triangles": 12}
