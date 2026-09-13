extends RefCounted
## INT-007 integration: retained HousePlans must be the shells and furnishings
## that CastleBuilder and CastleAssembler actually emit, at the same transform.
const ShellProbe = preload("res://tests/suites/stone_shell_suite.gd")
const RoofProbe = preload("res://tests/roof_probe.gd")


static func run() -> SuiteResult:
	var res := SuiteResult.new("castle plan shells")
	_polygon_hearth(res)
	for shape in [&"square", &"round", &"shell", &"tiered"]:
		var spec := _spec(shape)
		var builder := CastleBuilder.new()
		var mesh := builder.build(spec)
		_emission(res, spec, builder, mesh)
		if shape == &"square":
			_composition(res, builder)
			_assembly(res, spec, builder)
	return res


static func _polygon_hearth(res: SuiteResult) -> void:
	var plan := HousePlan.new()
	plan.spec = HouseSpec.new()
	plan.spec.material = &"stone"
	var room := Rect2(-4, -4, 8, 8)
	plan.rooms.append({"kind": &"lords_chamber", "rect": room,
		"outline": Poly.from_rect(room), "storey": 0})
	plan.hearth = {"room": 0, "wall": 3}
	var key: String = PropCatalog.of_category("hearth")[0]
	plan.furniture.append({"room": 0, "key": key, "yaw": -PI / 2.0})
	_expect(res, HouseFurnishCheck._wall_of(plan, plan.furniture[0]) == 3,
		"polygon left-wall hearth was mapped to rectangular wall index")
	var check := HouseFurnishCheck.new()
	check._check_hearth(plan)
	_expect(res, check.failures.is_empty(), "polygon hearth does not agree with its planned flue")
	plan.furniture[0].yaw = 0.0
	_expect(res, HouseFurnishCheck._wall_of(plan, plan.furniture[0]) == 2,
		"polygon back-wall control was mapped to rectangular wall index")
	check._check_hearth(plan)
	_expect(res, not check.failures.is_empty(), "hearth rule accepted a fire rotated away from its planned chimney")


static func _spec(shape: StringName) -> CastleSpec:
	var spec := CastleSpec.new()
	spec.style = &"norman"
	spec.width = 40.0
	spec.length = 55.0
	spec.height = 14.0
	CastleGenerator.generate(spec, 42)
	spec.keep_shape = shape
	return spec


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)


static func _vertex_key(p: Vector3) -> String:
	return "%d,%d,%d" % [roundi(p.x * 1000), roundi(p.y * 1000), roundi(p.z * 1000)]


static func _emission(res: SuiteResult, spec: CastleSpec, builder: CastleBuilder,
		mesh: ArrayMesh) -> void:
	var who := "norman seed42 keep=%s" % spec.keep_shape
	_expect(res, builder.interior_errors.is_empty(), who + ": interior generation errors " + str(builder.interior_errors))
	var names := {}
	for mass in builder.mass_log:
		names[mass.name] = int(names.get(mass.name, 0)) + 1
	var emitted: Array[Dictionary] = []
	for surface in mesh.get_surface_count():
		var points := {}
		for point in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			points[_vertex_key(point)] = true
		emitted.append(points)
	var final_triangles := ShellProbe._triangles(mesh)
	var ids := {}
	for row in builder.interiors:
		var id: String = row.id
		var label := who + " building=" + id
		_expect(res, not ids.has(id), label + ": duplicate interior id")
		ids[id] = true
		_expect(res, int(names.get(id, 0)) == 1, label + ": expected one retained top-level mass")
		var plan: HousePlan = row.plan
		_expect(res, plan.spec.material == &"stone", label + ": plan is not stone")
		_expect(res, HouseGeometry.wall_thickness(plan.spec) >= 0.6,
			label + ": planning wall is thinner than stone contract")
		_expect(res, row.builder is HouseBuilder and row.mesh is ArrayMesh,
			label + ": no emitted HouseBuilder shell retained")
		var local_mesh: ArrayMesh = row.mesh
		var transform: Transform3D = row.transform
		if id == "keep":
			_expect(res, absf(plan.spec.height * plan.spec.storeys - row.bounds.size.y) < 0.001,
				label + ": occupied storeys do not reach the keep roof")
			# Each floor is protected by its own shoulder or the crown above.
			# Sample the occupied polygon, including the square keep corners
			# outside its smaller pitched crown.
			for level in range(plan.spec.storeys):
				var outline := PackedVector2Array()
				for point in plan.outline_of(level):
					var world := transform * Vector3(point.x, 0, point.y)
					outline.append(Vector2(world.x, world.z))
				var covered := RoofProbe.coverage(mesh, outline,
					transform.origin.y + (level + 1) * plan.spec.height - 0.4, [], false, 7)
				res.checked += int(covered.checked)
				if not covered.misses.is_empty():
					res.fail(label + ": uncovered floor %d samples %s" % [level, covered.misses])
		var missing := 0
		for source in [HouseBuilder.SURF_WALL, HouseBuilder.SURF_TRIM,
				HouseBuilder.SURF_ROOF, HouseBuilder.SURF_FLOOR]:
			var arrays: Array = row.builder._kit.surface(source).commit_to_arrays()
			if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
				continue
			var mapped: int = [CastleBuilder.SURF_STONE, CastleBuilder.SURF_TRIM,
				CastleBuilder.SURF_OPEN, CastleBuilder.SURF_STONE][source]
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				if not emitted[mapped].has(_vertex_key(transform * vertex)):
					missing += 1
		_expect(res, missing == 0, label + ": %d local shell vertices missing from transformed castle mesh" % missing)
		var entrance := plan.entrance()
		_expect(res, entrance >= 0, label + ": no planned exterior entrance")
		if entrance >= 0:
			var door: Dictionary = plan.doors[entrance]
			var pos: Vector2 = door.pos
			var normal: Vector2 = door.normal
			var center := Vector3(pos.x, 1.05 + HousePlan.record_storey(door) * plan.spec.height, pos.y)
			var span := Vector3(normal.x, 0, normal.y) * 0.9
			_expect(res, ShellProbe._hits(final_triangles, transform * (center - span),
				transform * (center + span)).is_empty(), label + ": final castle mesh blocks entrance")
		for stair in plan.stairs:
			var floor_mesh: ArrayMesh = row.builder._kit.surface(HouseBuilder.SURF_FLOOR).commit()
			var floor_triangles := ShellProbe._triangles(floor_mesh, 0)
			_expect(res, ShellProbe._floor_hole_clear(floor_triangles, stair.upper_rect,
				float(stair.to_storey) * plan.spec.height), label + ": upper stair opening filled by shell floor")
	_expect(res, ids.has("keep") and ids.has("hall"), who + ": canonical keep or hall plan was not emitted")
	var yard_count := 0
	for id in ids:
		if String(id).begins_with("yard_"):
			yard_count += 1
	_expect(res, yard_count > 0, who + ": canonical yard buildings were not emitted from plans")


static func _interior_report(builder: CastleBuilder) -> CastleQA:
	# Exercise the composition rule directly here. The general CastleQA suite
	# separately drives RULES over the expensive full voxel raster.
	var qa := CastleQA.new()
	qa.builder = builder
	qa._check_interiors()
	return qa


static func _composition(res: SuiteResult, builder: CastleBuilder) -> void:
	_expect(res, &"interiors" in CastleQA.RULES, "CastleQA does not dispatch interior composition")
	var clean := _interior_report(builder)
	_expect(res, clean.buildings.size() == builder.interiors.size(), "CastleQA omitted a per-building report")
	for row in builder.interiors:
		_expect(res, clean.buildings.has(row.id), "CastleQA report lost building " + String(row.id))
		var report: Dictionary = clean.buildings[row.id]
		_expect(res, report.failures.is_empty(), "canonical interior " + String(row.id) + ": " + str(report.failures))
	# Remove the real entrance/room connections while retaining the shell;
	# forwarding must not be a constant all-clear result or one shared report.
	var target: Dictionary = builder.interiors[0]
	var plan: HousePlan = target.plan
	var saved_doors := plan.doors.duplicate(true)
	plan.doors.clear()
	var expected := HouseQA.new().check(plan, null)
	var broken := _interior_report(builder)
	_expect(res, not expected.failures.is_empty(), "plan mutation failed to produce a HouseQA error")
	for failure in expected.failures:
		_expect(res, ("interiors[%s]: %s" % [target.id, failure]) in broken.failures,
			"CastleQA did not forward HouseQA failure with stable building id: " + str(failure))
	plan.doors.assign(saved_doors)
	for row in builder.interiors:
		if row.id == target.id:
			continue
		_expect(res, broken.buildings[row.id].failures == clean.buildings[row.id].failures,
			"mutating one interior changed another building report: " + String(row.id))
	var furnished: Dictionary = {}
	for row in builder.interiors:
		if not row.plan.furniture.is_empty():
			furnished = row
			break
	_expect(res, not furnished.is_empty(), "canonical castle has no furniture mutation control")
	if not furnished.is_empty():
		var furniture: Array[Dictionary] = furnished.plan.furniture
		var saved: Dictionary = furniture[0].duplicate(true)
		furniture[0].pos = Vector3(10000, 0, 10000)
		furniture[0].rect = Rect2(10000, 10000, 1, 1)
		var furniture_error := HouseQA.new().check(furnished.plan, null)
		var forwarded := _interior_report(builder)
		_expect(res, not furniture_error.failures.is_empty(), "furniture mutation failed to produce a HouseQA error")
		for failure in furniture_error.failures:
			_expect(res, ("interiors[%s]: %s" % [furnished.id, failure]) in forwarded.failures,
				"CastleQA lost furniture failure: " + str(failure))
		furniture[0] = saved
	_expect(res, _interior_report(builder).failures == clean.failures, "composition retained stale failure after restoration")


static func _lights(node: Node) -> int:
	var out := 1 if node is OmniLight3D else 0
	for child in node.get_children():
		out += _lights(child)
	return out


static func _assembly(res: SuiteResult, spec: CastleSpec, builder: CastleBuilder) -> void:
	var assembled := CastleAssembler.build(spec, true)
	var expected_lights := 0
	for row in builder.interiors:
		var node := assembled.get_node_or_null(NodePath(String(row.id)))
		_expect(res, node is Node3D, "assembler omitted furnished building " + String(row.id))
		if not node is Node3D:
			continue
		_expect(res, node.transform.is_equal_approx(row.transform), "assembler transform disagrees with shell " + String(row.id))
		var furniture := node.get_node_or_null("Furniture")
		_expect(res, furniture != null and furniture.get_child_count() == row.plan.furniture.size(),
			"assembler furniture count differs from plan " + String(row.id))
		var lamps := 0
		for item in row.plan.furniture:
			if PropCatalog.has_tag(item.key, PropCatalog.LIGHT):
				lamps += 1
		expected_lights += lamps
		_expect(res, _lights(node) == lamps, "LAY-011 lights differ from planned lamps in " + String(row.id))
	_expect(res, expected_lights > 0, "canonical fixture has no lamp to test LAY-011 assembly")
	assembled.free()
