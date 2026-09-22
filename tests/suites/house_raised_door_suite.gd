extends RefCounted
## Focused contract for optional raised exterior-door sill/head intervals.

static func run() -> SuiteResult:
	var res := SuiteResult.new("house raised doors")
	var raised := _plan()
	var door: Dictionary = raised.doors[raised.entrance()]
	door["sill"] = 1.8
	door["head"] = 2.6
	var builder := HouseBuilder.new()
	var mesh := builder.build(raised, false)
	var emitted: Array = builder.part_log.filter(func(p: Dictionary) -> bool:
		return String(p.get("opening_kind", "")) == "door" and String(p.get("tag", "")) == "wall")
	_expect(res, emitted.size() == 1, "raised door did not emit one door aperture")
	if emitted.size() == 1:
		_expect(res, is_equal_approx(float(emitted[0]["pos"].y), 2.2),
			"raised door part log has the wrong vertical centre")
		_expect(res, is_equal_approx(float(emitted[0]["size"].y), 0.8),
			"raised door part log has the wrong vertical height")
	var triangles := _triangles(mesh, HouseBuilder.SURF_WALL)
	_expect(res, not _clear(triangles, door, 1.0), "raised aperture left a hole below its sill")
	_expect(res, _clear(triangles, door, 2.2), "raised aperture is filled at its authored interval")

	var ordinary_a := _plan()
	var ordinary_b := _plan()
	for d in ordinary_b.doors:
		d.erase("sill")
		d.erase("head")
	var mesh_a := HouseBuilder.new().build(ordinary_a, false)
	var mesh_b := HouseBuilder.new().build(ordinary_b, false)
	_expect(res, _same_mesh(mesh_a, mesh_b), "legacy door without sill/head changed shell geometry")

	var misplaced := _plan()
	var misplaced_door: Dictionary = misplaced.doors[misplaced.entrance()]
	misplaced_door["sill"] = 1.8
	misplaced_door["head"] = 2.6
	misplaced_door["pos"] = Vector2(100.0, 100.0)
	var misplaced_builder := HouseBuilder.new()
	misplaced_builder.build(misplaced, false)
	var misplaced_parts: Array = misplaced_builder.part_log.filter(func(p: Dictionary) -> bool:
		return String(p.get("opening_kind", "")) == "door" and String(p.get("tag", "")) == "wall")
	_expect(res, misplaced_parts.is_empty(), "misplaced raised door emitted an aperture")
	var report := HousePlanCheck.new().check(misplaced)
	_expect(res, not bool(report["ok"]), "misplaced raised door escaped plan QA")
	return res


static func _plan() -> HousePlan:
	var spec := HouseSpec.new(91827)
	spec.material = &"stone"
	spec.width = 10.0
	spec.length = 12.0
	spec.height = 3.0
	spec.storeys = 1
	spec.room_count = 3
	spec.program = [&"hall", &"bedroom", &"kitchen"]
	spec.plinth_height = 0.45
	spec.exterior_props = false
	spec.bargeboards = false
	return HousePlanner.plan(spec)


static func _triangles(mesh: ArrayMesh, surface: int) -> Array:
	var out: Array = []
	var arrays := mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count := indices.size() if not indices.is_empty() else vertices.size()
	for i in range(0, count, 3):
		out.append([vertices[indices[i] if not indices.is_empty() else i],
			vertices[indices[i + 1] if not indices.is_empty() else i + 1],
			vertices[indices[i + 2] if not indices.is_empty() else i + 2]])
	return out


static func _clear(triangles: Array, door: Dictionary, y: float) -> bool:
	var pos: Vector2 = door["pos"]
	var normal: Vector2 = door["normal"]
	var centre := Vector3(pos.x, y, pos.y)
	var span := Vector3(normal.x, 0.0, normal.y) * 0.8
	for tri in triangles:
		if Geometry3D.segment_intersects_triangle(centre - span, centre + span,
			tri[0], tri[1], tri[2]) != null:
			return false
	return true


static func _same_mesh(a: ArrayMesh, b: ArrayMesh) -> bool:
	if a.get_surface_count() != b.get_surface_count():
		return false
	for s in a.get_surface_count():
		var aa := a.surface_get_arrays(s)
		var bb := b.surface_get_arrays(s)
		for field in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_INDEX]:
			if aa[field] != bb[field]:
				return false
	return true


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)
