extends RefCounted
## WLD-005 emitted dome support against actual roof triangles.


static func run() -> SuiteResult:
	var res := SuiteResult.new("hammam mesh support")
	var made := _made(95005)
	var baseline: Dictionary = HammamCheck.new().check(made.plan, made.builder)
	res.checked += 1
	if not baseline["ok"]:
		res.fail("Steam Baths emitted mesh failed its full hammam contract: %s" %
			str(baseline["failures"]))
	var before_masses: Array = made.builder.mass_log.duplicate(true)
	var before_components: Array = made.builder.component_log.duplicate(true)
	var stripped := _without_dome(made.plan, made.builder, &"warm")
	res.checked += 1
	if int(stripped.get("removed_triangles", 0)) == 0:
		res.fail("negative control removed no warm-dome roof triangles")
		return res
	made.builder.emitted_mesh = stripped["mesh"]
	var broken: Dictionary = HammamCheck.new().check(made.plan, made.builder)
	if not _has_failure(broken, "dome_mesh_support: warm dome"):
		res.fail("warm dome triangle removal escaped mesh support QA: %s" %
			str(broken.get("failures", [])))
	if made.builder.mass_log != before_masses \
			or made.builder.component_log != before_components:
		res.fail("mesh negative control changed the mass or component logs")
	return res


static func _made(seed: int) -> Dictionary:
	var made := HammamGenerator.generate(seed, 24.0, 16.0, 8.0)
	var builder := HammamBuilder.new()
	var mesh: ArrayMesh = builder.build(made["plan"])
	return {"plan": made["plan"], "builder": builder, "mesh": mesh}


static func _without_dome(plan: HousePlan, builder: HammamBuilder,
		role: StringName) -> Dictionary:
	var room_id := -1
	for i in range(plan.rooms.size()):
		if StringName(plan.rooms[i].get("role", &"")) == role:
			room_id = i
			break
	if room_id < 0 or builder.emitted_mesh == null:
		return {"mesh": null, "removed_triangles": 0}
	var room := HouseGeometry.room_floor_rect(plan, room_id)
	var rx := room.size.x * 0.51
	var rz := room.size.y * 0.51
	var centre := room.get_center()
	var base_y := plan.spec.height
	var mesh := ArrayMesh.new()
	var removed := 0
	for surface in range(builder.emitted_mesh.get_surface_count()):
		var arrays: Array = builder.emitted_mesh.surface_get_arrays(surface)
		var source_index_value: Variant = arrays[Mesh.ARRAY_INDEX]
		var source_indices: PackedInt32Array = source_index_value \
			if source_index_value != null else PackedInt32Array()
		if source_indices.is_empty():
			# ArrayMesh rejects an explicitly supplied empty index array. Null is
			# the engine's representation of a non-indexed triangle surface.
			arrays[Mesh.ARRAY_INDEX] = null
		if surface == HouseBuilder.SURF_ROOF:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var order := source_indices.duplicate()
			if order.is_empty():
				for i in range(vertices.size()):
					order.append(i)
			var kept := PackedInt32Array()
			for i in range(0, order.size() - 2, 3):
				var a := vertices[order[i]]
				var b := vertices[order[i + 1]]
				var c := vertices[order[i + 2]]
				var mid := (a + b + c) / 3.0
				var normalized := Vector2((mid.x - centre.x) / maxf(rx, 0.01),
					(mid.z - centre.y) / maxf(rz, 0.01))
				if mid.y > base_y + 0.005 and normalized.length_squared() <= 1.08 * 1.08:
					removed += 1
				else:
					kept.append(order[i])
					kept.append(order[i + 1])
					kept.append(order[i + 2])
			if kept.is_empty():
				return {"mesh": null, "removed_triangles": removed}
			arrays[Mesh.ARRAY_INDEX] = kept
		mesh.add_surface_from_arrays(
			builder.emitted_mesh.surface_get_primitive_type(surface), arrays)
	if mesh.get_surface_count() != builder.emitted_mesh.get_surface_count():
		return {"mesh": null, "removed_triangles": removed}
	return {"mesh": mesh, "removed_triangles": removed}


static func _has_failure(report: Dictionary, needle: String) -> bool:
	for failure in report.get("failures", []):
		if String(failure).contains(needle):
			return true
	return false
