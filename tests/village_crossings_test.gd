extends SceneTree

func _init() -> void:
	var res := SuiteResult.new("persistent village crossings")
	for kind in [&"stream", &"river", &"coast"]:
		for route in [PackedVector2Array([Vector2(-25, 0), Vector2(25, 0)]),
			PackedVector2Array([Vector2(-25, -4), Vector2(0, 0), Vector2(25, -4)]),
			PackedVector2Array([Vector2(-25, -4), Vector2(0, 0)])]:
			var plan := _plan(route, kind)
			var label := "%s/%d" % [kind, route.size()]
			_expect(res, plan.water_crossings.size() == 1, label + " expected one crossing")
			_expect(res, _faults(plan).is_empty(), label + " " + str(_faults(plan)))
			var walk := VillageNavCheck.build_grid(plan)
			var start: Vector2 = route[0].lerp(route[1], 0.08)
			var finish: Vector2 = route[-1].lerp(route[-2], 0.08)
			_expect(res, walk.flood_from(start) and walk.reached(Rect2(finish - Vector2.ONE * 0.2, Vector2.ONE * 0.4)), label + " emitted crossing is absent from walk grid")
			var builder := VillageBuilder.new()
			var mesh := builder.build(plan)
			var components := ComponentCheck.check(builder, mesh)
			_expect(res, components["ok"], label + " emitted crossing differs from component record")
			_expect(res, builder.has_mass("ford" if kind == &"stream" else "bridge"), label + " no crossing emitted")
			if route.size() == 3:
				_expect(res, plan.water_crossings[0]["points"].size() == 3, label + " crossing flattened a bend")
			# Every wet road grid sample must have an actual upward-facing deck
			# triangle above it, independently of the crossing and mass logs.
			var missing := 0
			var wet := Geometry2D.intersect_polygons(Poly.ribbon(route, 3.0), plan.water[0]["poly"])
			for x in range(-15, 16):
				for z in range(-12, 13):
					var point := Vector2(x * 0.5, z * 0.5)
					if wet.any(func(poly): return Poly.contains_point(poly, point)) and not _deck_at(mesh, point):
						missing += 1
			_expect(res, missing == 0, label + " has %d wet samples without emitted deck" % missing)
			var codec := BuildingCodec.new()
			var restored: VillagePlan = codec.decode(BuildingCodec.encode(plan))
			_expect(res, codec.errors.is_empty() and plan.equals(restored), label + " crossing lost in serialization")
			restored.water_crossings[0]["width"] = 1.0
			_expect(res, not plan.equals(restored) and not _faults(restored).is_empty(), label + " narrow deck accepted")
			plan.water_crossings.clear()
			_expect(res, not _faults(plan).is_empty(), label + " missing crossing accepted")
			walk = VillageNavCheck.build_grid(plan)
			walk.flood_from(start)
			_expect(res, not walk.reached(Rect2(finish - Vector2.ONE * 0.2, Vector2.ONE * 0.4)), label + " deleted crossing still walkable")
	# Re-entering a concave water body must retain two separate wet reaches.
	var separated := _plan(PackedVector2Array([Vector2(-20, 0), Vector2(20, 0)]), &"river")
	separated.water[0]["poly"] = PackedVector2Array([Vector2(-12,-5), Vector2(-6,-5),
		Vector2(-6,8), Vector2(6,8), Vector2(6,-5), Vector2(12,-5), Vector2(12,14), Vector2(-12,14)])
	separated.water_crossings = VillageWaterPlan.crossings(separated.water, separated.roads)
	_expect(res, separated.water_crossings.size() == 2 and _faults(separated).is_empty(), "concave water merged distinct crossings")
	var curved := _plan(PackedVector2Array([Vector2(-25,-8), Vector2(0,0), Vector2(25,-8)]), &"river")
	var points: PackedVector2Array = curved.water_crossings[0]["points"]
	curved.water_crossings[0]["points"] = PackedVector2Array([points[0], points[-1]])
	_expect(res, not _faults(curved).is_empty(), "straight shortcut accepted for curved road")
	var stale := _plan(PackedVector2Array([Vector2(-25,0), Vector2(25,0)]), &"river")
	stale.water_crossings[0]["road"] = 99
	_expect(res, not _faults(stale).is_empty(), "stale road index accepted")
	var far := _plan(PackedVector2Array([Vector2(-25,30), Vector2(25,30)]), &"river")
	_expect(res, far.water_crossings.is_empty(), "dry road invented a bridge")
	for failure in res.failures:
		print("FAIL: ", failure)
	print("crossings: %d checks, %d failures" % [res.checked, res.failures.size()])
	quit(0 if res.failures.is_empty() else 1)


func _plan(points: PackedVector2Array, kind: StringName) -> VillagePlan:
	var spec := VillageSpec.new(19002)
	spec.enclosure = &"none"
	var plan := VillagePlan.new(spec)
	plan.site = Rect2(-40, -40, 80, 80)
	plan.roads.append({"points": points, "class": &"through", "width": 6.0, "verge": 1.0})
	plan.water.append({"kind": kind, "poly": Poly.from_rect(Rect2(-4,-20,8,40))})
	plan.water_crossings = VillageWaterPlan.crossings(plan.water, plan.roads)
	return plan


func _faults(plan: VillagePlan) -> Array[String]:
	var check := VillageRoadCheck.new()
	check._check_crossings(plan)
	return check.failures


func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)


func _deck_at(mesh: ArrayMesh, point: Vector2) -> bool:
	for surface in mesh.get_surface_count():
		if mesh.surface_get_name(surface) not in ["material_slot:4", "material_slot:5"]:
			continue
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in range(0, vertices.size(), 3):
			if normals[i].y < 0.8 or vertices[i].y < 0.10:
				continue
			var triangle := PackedVector2Array()
			for k in 3:
				triangle.append(Vector2(vertices[i + k].x, vertices[i + k].z))
			if Poly.contains_point(triangle, point):
				return true
	return false
