extends SceneTree

func _init() -> void:
	var res := SuiteResult.new("persistent village gateways")
	for kind in [&"hedge", &"palisade", &"wall"]:
		for angle in [0.0, 0.17, PI / 8.0, PI / 4.0]:
			var plan := _plan(kind, angle)
			var label := "%s/%.2f" % [kind, angle]
			_expect(res, plan.gate_crossings.size() == 4, label + " must preserve both hits of both road segments")
			_expect(res, _faults(plan).is_empty(), label + " " + str(_faults(plan)))
			var builder := VillageBuilder.new()
			var mesh := builder.build(plan)
			_expect(res, ComponentCheck.check(builder, mesh)["ok"], label + " portal component differs from triangles")
			_expect(res, _blocked(plan, mesh) == 0, label + " actual wall or gate blocks a road")
			var grid := VillageNavCheck.build_grid(plan)
			var direction := Vector2.RIGHT.rotated(angle)
			_expect(res, grid.flood_from(-direction * 30.0) and grid.reached(Rect2(direction * 30.0 - Vector2.ONE, Vector2.ONE * 2.0)), label + " open gate is not walkable")
			var codec := BuildingCodec.new()
			var copy: VillagePlan = codec.decode(BuildingCodec.encode(plan))
			_expect(res, codec.errors.is_empty() and plan.equals(copy), label + " loses boundary/gates on serialization")
			copy.gate_crossings.pop_back()
			_expect(res, not plan.equals(copy) and not _faults(copy).is_empty(), label + " omitted second crossing escaped")
	var base := _plan(&"wall", 0.0)
	base.lots[0]["poly"] = Poly.from_rect(Rect2(-43, -43, 86, 86))
	base.roads[0]["points"] = PackedVector2Array([Vector2(-45,0), Vector2(45,0)])
	base.roads[1]["points"] = PackedVector2Array([Vector2(2,-45), Vector2(2,45)])
	VillageEnclosurePlan.author(base)
	_expect(res, base.gate_crossings.size() == 4, "lots near parcel edge put wall beyond approach roads")
	_expect(res, Array(base.enclosure).all(func(p): return base.site.has_point(p)), "offset wall escaped available ground")
	base = _plan(&"wall", 0.0)
	base.gate_crossings[0]["width"] = 1.0
	_expect(res, not _faults(base).is_empty(), "narrow gate accepted")
	base = _plan(&"wall", 0.0)
	base.gate_crossings.clear()
	var grid := VillageNavCheck.build_grid(base)
	grid.flood_from(Vector2(-30, 0))
	_expect(res, not grid.reached(Rect2(29, -1, 2, 2)), "navigation walks through ungated enclosure")
	base = _plan(&"wall", 0.0)
	base.gate_crossings[0]["road"] = 99
	_expect(res, not _faults(base).is_empty(), "stale road index accepted")
	base = _plan(&"wall", 0.0)
	base.gate_crossings[0]["pos"] = Vector2.ZERO
	_expect(res, not _faults(base).is_empty(), "entrance on road but off boundary accepted")
	base = _plan(&"wall", 0.0)
	base.enclosure.clear()
	_expect(res, not _faults(base).is_empty(), "empty persistent boundary accepted")
	base = _plan(&"wall", 0.0)
	base.roads = [{"points": PackedVector2Array([Vector2(-15, 17), Vector2(15, 17)]),
		"class": &"through", "width": 6.0, "verge": 1.0}]
	VillageEnclosurePlan.author(base)
	_expect(res, base.gate_crossings.is_empty(), "nearby road invented a projected gateway")
	base = _plan(&"wall", 0.0)
	var blocked_builder := VillageBuilder.new()
	blocked_builder.build(base)
	# Independently emitted closed leaf, not a forged mass/component record.
	var gate: Dictionary = base.gate_crossings[0]
	blocked_builder.box(Vector3(0.5, 2.4, 7.0), Vector3(gate["pos"].x, 1.2, gate["pos"].y), VillageBuilder.SURF_WOOD)
	_expect(res, _blocked(base, blocked_builder.commit()) > 0, "closed gate negative control escaped physical rays")
	for failure in res.failures:
		print("FAIL: ", failure)
	print("gateways: %d checks, %d failures" % [res.checked, res.failures.size()])
	quit(0 if res.failures.is_empty() else 1)


func _plan(kind: StringName, angle: float) -> VillagePlan:
	var spec := VillageSpec.new(19800)
	spec.enclosure = kind
	var plan := VillagePlan.new(spec)
	plan.site = Rect2(-45, -45, 90, 90)
	plan.lots.append({"poly": Poly.from_rect(Rect2(-14,-14,28,28))})
	var direction := Vector2.RIGHT.rotated(angle)
	plan.roads.append({"points": PackedVector2Array([-direction * 40.0, direction * 40.0]),
		"class": &"through", "width": 6.0, "verge": 1.0})
	plan.roads.append({"points": PackedVector2Array([Vector2(2,-40), Vector2(2,40)]),
		"class": &"track", "width": 3.0, "verge": 0.0})
	VillageEnclosurePlan.author(plan)
	return plan


func _faults(plan: VillagePlan) -> Array[String]:
	var check := VillageRoadCheck.new()
	check._check_gates(plan)
	return check.failures


func _blocked(plan: VillagePlan, mesh: ArrayMesh) -> int:
	var triangles: Array = []
	for surface in mesh.get_surface_count():
		triangles.append_array(HouseQA._mesh_triangles(mesh, surface))
	var blocked := 0
	for gate in plan.gate_crossings:
		var point: Vector2 = gate["pos"]
		var direction: Vector2 = gate["direction"]
		var right := Vector2(-direction.y, direction.x)
		var width := float(plan.roads[gate["road"]]["width"])
		for side in [-0.46, 0.0, 0.46]:
			for height in [0.5, 1.7, 2.4]:
				var at: Vector2 = point + right * side * width
				var start := Vector3(at.x - direction.x * 3.0, height, at.y - direction.y * 3.0)
				var end := Vector3(at.x + direction.x * 3.0, height, at.y + direction.y * 3.0)
				for tri in triangles:
					if Geometry3D.segment_intersects_triangle(start, end, tri[0], tri[1], tri[2]) != null:
						blocked += 1
						break
	return blocked


func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)
