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
	return MeshProbe.remove_triangles(source, surface, MeshProbe.top_face_in(footprint, height))


static func _has_failure(report: Dictionary, needle: String) -> bool:
	for failure in report.get("failures", []):
		if String(failure).contains(needle):
			return true
	return false
