extends RefCounted
## WLD-013 actual mesh checks for the circumambulatory floor and plinth stair.


static func run() -> SuiteResult:
	var res := SuiteResult.new("Nagara mesh support")
	var made := _fresh()
	var baseline: Dictionary = ShikharaCheck.check(made.plan, made.builder, made.mesh)
	res.checked += 1
	if not baseline["ok"]:
		res.fail("reference Nagara mesh failed its contract: %s" % str(baseline["failures"]))
	var plan_only: Dictionary = ShikharaCheck.check(made.plan)
	res.checked += 1
	if not plan_only["ok"]:
		res.fail("plan-only Nagara check rejected its connected axis/ring: %s" %
			str(plan_only["failures"]))
	var before_masses: Array = made.builder.mass_log.duplicate(true)
	var before_parts: Array = made.builder.part_log.duplicate(true)

	var ring: Array = made.plan.world_meta["pradakshina"]
	var ring_rect: Rect2 = ring[0]
	var ring_y := float(made.plan.world_meta["plinth_height"]) + 0.18
	var no_ring := _without_top(made.mesh, NagaraBuilder.TRIM, ring_rect, ring_y)
	res.checked += 1
	if int(no_ring["removed_triangles"]) == 0:
		res.fail("ring negative control removed no actual floor triangles")
	else:
		var ring_report: Dictionary = ShikharaCheck.check(made.plan, made.builder, no_ring["mesh"])
		if not _has_failure(ring_report, "pradakshina_mesh_support: segment 0"):
			res.fail("removed ring floor triangles escaped mesh QA: %s" %
				str(ring_report["failures"]))

	var stair: Dictionary = made.plan.stairs[0]
	var tread := 2
	var count := int(stair["steps"])
	var width := float(stair["width"])
	var run := float(stair["run"])
	var plinth: Rect2 = made.plan.world_meta["plinth_rect"]
	var depth := run / float(count)
	var tread_rect := Rect2(Vector2(-width * 0.5,
		plinth.position.y - run + depth * float(tread)), Vector2(width, depth))
	var tread_y := float(made.plan.world_meta["plinth_height"]) * float(tread + 1) / float(count)
	var no_tread := _without_top(made.mesh, NagaraBuilder.STONE, tread_rect, tread_y)
	res.checked += 1
	if int(no_tread["removed_triangles"]) == 0:
		res.fail("tread negative control removed no actual stair-top triangles")
	else:
		var tread_report: Dictionary = ShikharaCheck.check(made.plan, made.builder, no_tread["mesh"])
		if not _has_failure(tread_report, "plinth_mesh_support: tread 2"):
			res.fail("removed plinth tread triangles escaped mesh QA: %s" %
				str(tread_report["failures"]))
	if made.builder.mass_log != before_masses or made.builder.part_log != before_parts:
		res.fail("mesh negative controls changed the emitted logs")
	return res


static func _fresh() -> Dictionary:
	var made := NagaraGenerator.generate(&"hundred_spires", 13013, 31.0, 20.0, 31.0)
	var builder := NagaraBuilder.new()
	var mesh: ArrayMesh = builder.build(made["plan"])
	return {"plan": made["plan"], "builder": builder, "mesh": mesh}


static func _without_top(source: ArrayMesh, surface: int, footprint: Rect2,
		height: float) -> Dictionary:
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
				var face := (c - a).cross(b - a)
				var centre := (a + b + c) / 3.0
				var inside := footprint.has_point(Vector2(centre.x, centre.z))
				if face.length_squared() > 1e-12 and face.normalized().dot(Vector3.UP) > 0.95 \
						and absf(centre.y - height) <= 0.01 and inside:
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


static func _has_failure(report: Dictionary, needle: String) -> bool:
	for failure in report.get("failures", []):
		if String(failure).contains(needle):
			return true
	return false
