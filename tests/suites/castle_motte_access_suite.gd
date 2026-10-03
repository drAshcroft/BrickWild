extends RefCounted
## The README hero's real approach must remain walkable through its rear
## curtain. These mutations change only triangles; the route logs stay valid.

const Access = preload("res://src/castle/castle_access_geometry.gd")


static func run() -> SuiteResult:
	var res := SuiteResult.new("castle motte access")
	var spec := hero_spec()
	var builder := CastleBuilder.new()
	var mesh := builder.build(spec)
	probe(spec, builder, mesh, res)
	var qa := CastleQA.new().check(spec, mesh, builder)
	_want(res, qa.ok, "README hero complete CastleQA: " + str(qa.failures))
	_want(res, int(qa.stats.get("access_routes", {}).get("routes", 0)) == 7,
		"production CastleQA did not inspect all six tower routes and gate gallery")
	var routes := preload("res://qa/castle_route_check.gd").check(builder, mesh)
	_want(res, routes.ok and routes.courtyard_routes == 7 and routes.wall_stairs >= 1,
		"occupied tower/gate routes do not reach an emitted stair down to courtyard: " + str(routes.failures))
	_route_mutations(res, builder, mesh)
	var massing := CastleMassingCheck.new().check(spec, builder)
	_want(res, massing.ok, "README hero massing: " + str(massing.failures))
	var components := ComponentCheck.check(builder, mesh)
	_want(res, components.ok, "README hero component geometry: " + str(components.failures))
	preload("res://tests/suites/castle_occupancy_suite.gd").check_fixture(res, spec, builder, mesh)
	preload("res://tests/suites/castle_mural_suite.gd").check_fixture(res, spec, builder, mesh)
	preload("res://tests/suites/castle_gate_suite.gd").check_fixture(res, spec, builder, mesh)
	var large := CastleSpec.new()
	large.style = &"norman"
	large.width = 90.0
	large.length = 110.0
	large.height = 12.0
	large.plan_override = &"motte_bailey"
	CastleGenerator.generate(large, 8806)
	var structural := CastleBuilder.new()
	structural.spec = large
	structural.begin_metric(CastleBuilder.SURFACES)
	var plan := CastleMottePlan.generate(large, false)
	var row := CastleBuilder.Interiors.record("keep_shell", plan, CastleGeometry.shell_keep_aabb(large))
	structural._planned_interiors = {"keep_shell": row}
	structural._build_ring_walls_rect(0)
	structural._build_motte()
	var clean := _report(structural, structural.commit())
	_want(res, clean.failures.is_empty(), "seed 8806 approach: " + str(clean.failures))
	return res


static func _route_mutations(res: SuiteResult, builder: CastleBuilder, mesh: ArrayMesh) -> void:
	var routes = preload("res://qa/castle_route_check.gd")
	var omitted := _without_wall_stairs(builder, mesh)
	_want(res, omitted.removed > 0, "missing-stair negative control removed no triangles")
	var missing := routes.check(builder, omitted.mesh)
	_want(res, not missing.ok and missing.wall_stairs == 0 and missing.courtyard_routes == 0,
		"all wall stair triangles removed with intact records still permit courtyard access")
	for row in builder.interiors:
		if not bool(row.get("gate_chamber", false)):
			continue
		var at := Vector2(row.walk_route[1])
		var kit := MeshKit.new(1)
		kit.box(Vector3(1.5, 0.12, 1.5), Vector3(at.x, float(row.walk_y) + 1.5, at.y), 0)
		var blocked := _with_surface(mesh, kit.commit(), CastleBuilder.SURF_ROOF)
		var roof := routes.check(builder, blocked)
		_want(res, not roof.ok and Array(roof.failures).any(func(failure):
			return String(failure).begins_with("access_routes[gate_0]") and "blocks" in String(failure)),
			"physical roof slab across gate route escaped production headroom check")
		break


## Re-emit just the named stair components to identify the exact triangles
## being removed. Builder records stay unchanged throughout the mutation.
static func _without_wall_stairs(builder: CastleBuilder, mesh: ArrayMesh) -> Dictionary:
	var isolated := {}
	for row in builder.component_log:
		if not String(row.host).begins_with("wall_stair_"):
			continue
		var surface := int(row.surface)
		if not isolated.has(surface):
			isolated[surface] = MeshKit.new(1)
		var kit: MeshKit = isolated[surface]
		if row.form == "box":
			kit.oriented_box(row.size, row.xf, 0)
		elif row.form == "slab":
			kit.slab_poly(row.points, float(row.depth), 0, bool(row.vertical))
	var counts := {}
	for surface in isolated:
		var vertices: PackedVector3Array = (isolated[surface] as MeshKit).commit().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		counts[surface] = ComponentCheck.triangle_counts(vertices)
	var out := ArrayMesh.new()
	var removed := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		var kept := PackedInt32Array()
		var targets: Dictionary = counts.get(surface, {})
		for i in range(0, count - 2, 3):
			var a := indices[i] if not indices.is_empty() else i
			var b := indices[i + 1] if not indices.is_empty() else i + 1
			var c := indices[i + 2] if not indices.is_empty() else i + 2
			var key := ComponentCheck.triangle_key(vertices[a], vertices[b], vertices[c])
			if int(targets.get(key, 0)) > 0:
				targets[key] -= 1
				removed += 1
				continue
			kept.append_array(PackedInt32Array([a, b, c]))
		arrays[Mesh.ARRAY_INDEX] = kept
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return {"mesh": out, "removed": removed}


static func _with_surface(mesh: ArrayMesh, addition: ArrayMesh, target: int) -> ArrayMesh:
	var out := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		if surface != target:
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(surface))
			continue
		var merged := SurfaceTool.new()
		merged.begin(Mesh.PRIMITIVE_TRIANGLES)
		merged.append_from(mesh, surface, Transform3D.IDENTITY)
		merged.append_from(addition, 0, Transform3D.IDENTITY)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, merged.commit_to_arrays())
	return out


static func hero_spec() -> CastleSpec:
	var spec := CastleSpec.new()
	spec.style = &"norman"
	spec.width = 45.0
	spec.length = 55.0
	spec.height = 6.0
	spec.plan_override = &"motte_bailey"
	CastleGenerator.generate(spec, 8856)
	return spec


static func probe(spec: CastleSpec, builder: CastleBuilder, mesh: ArrayMesh,
		res: SuiteResult) -> void:
	var clean := _report(builder, mesh)
	_want(res, clean.failures.is_empty(), "README hero approach: " + str(clean.failures))
	var steps: Array[Dictionary] = []
	for part in builder.part_log:
		if String(part.get("kind", "")) == "motte_approach_step":
			steps.append(part)
	_want(res, not steps.is_empty(), "README hero emitted no approach treads")
	if steps.is_empty():
		return
	# Reproduce the former emitter exactly: restore an uninterrupted rear wall
	# in the actual mesh, leaving the complete valid tread chain untouched.
	var old := CastleBuilder.new()
	old.begin_metric(CastleBuilder.SURFACES)
	var back := CastleGeometry.wall_aabb(spec, 0, &"back")
	old._battered_wall(back, CastleGeometry.wall_thickness(spec, 0), Vector3.BACK)
	var sealed := _combine(mesh, old.commit())
	_want(res, not _report(builder, sealed).failures.is_empty(),
		"original solid rear curtain escaped emitted-route QA")
	# A thin plane can fall between both sets of tread-centre probes. The body
	# must be checked while moving between adjacent treads as well.
	var first: Dictionary = steps[0]
	var next: Dictionary = steps[1]
	var at := (Vector3(first.pos) + Vector3(next.pos)) * 0.5
	at.y = maxf(Vector3(first.pos).y + Vector3(first.size).y * 0.5,
		Vector3(next.pos).y + Vector3(next.size).y * 0.5) + 0.9
	var blocker := CastleBuilder.new()
	blocker.begin_metric(CastleBuilder.SURFACES)
	blocker._kit.box(Vector3(Vector3(first.size).x, 1.8, 0.015), at,
		CastleBuilder.SURF_STONE, float(first.rot_y))
	_want(res, not _report(builder, _combine(mesh, blocker.commit())).failures.is_empty(),
		"mesh-only wall between treads escaped emitted-route QA")
	var selected: Dictionary = steps[steps.size() / 2]
	var box := AABB(-Vector3(selected.size) * 0.5, selected.size)
	var xf := Transform3D(Basis(Vector3.UP, float(selected.rot_y)), selected.pos)
	_want(res, not _report(builder, _without_box(mesh, box, xf)).failures.is_empty(),
		"missing tread triangles with intact logs escaped emitted-route QA")


static func _report(builder: CastleBuilder, mesh: ArrayMesh) -> Dictionary:
	for row in builder.interiors:
		if String(row.id) == "keep_shell":
			var plan: HousePlan = row.plan
			return CastleQA._special_approach_report("keep_shell", builder, row,
				plan.doors[plan.entrance()], mesh)
	return {"failures": ["missing occupied shell keep"]}


static func _combine(a: ArrayMesh, b: ArrayMesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	# Keep the obstruction on the stone surface. Appending it as a new surface
	# can accidentally assign slot 4, which route QA rightly treats as water.
	var stone := SurfaceTool.new()
	stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	stone.append_from(a, 0, Transform3D.IDENTITY)
	for surface in b.get_surface_count():
		stone.append_from(b, surface, Transform3D.IDENTITY)
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, stone.commit_to_arrays())
	for surface in range(1, a.get_surface_count()):
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a.surface_get_arrays(surface))
	return out


static func _without_box(mesh: ArrayMesh, bounds: AABB, xf: Transform3D) -> ArrayMesh:
	var out := ArrayMesh.new()
	var inverse := xf.affine_inverse()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		var kept := PackedInt32Array()
		for i in range(0, count - 2, 3):
			var ia := indices[i] if not indices.is_empty() else i
			var ib := indices[i + 1] if not indices.is_empty() else i + 1
			var ic := indices[i + 2] if not indices.is_empty() else i + 2
			if bounds.grow(0.001).has_point(inverse * vertices[ia]) \
					and bounds.grow(0.001).has_point(inverse * vertices[ib]) \
					and bounds.grow(0.001).has_point(inverse * vertices[ic]):
				continue
			kept.append_array(PackedInt32Array([ia, ib, ic]))
		arrays[Mesh.ARRAY_INDEX] = kept
		if not kept.is_empty():
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


static func _want(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)
