extends RefCounted
## Working mining-camp entrances: real PropKit geometry, dry siting, a
## connected working apron and independent negative semantic controls.

static func run() -> SuiteResult:
	var res := SuiteResult.new("village adit")
	for seed in 50:
		if seed % 10 == 0: print("VMINE site seed=", seed)
		var spec := VillageSpec.new(seed)
		spec.population = 70
		spec.culture = &"norse"
		spec.purpose = &"mining"
		spec.enclosure = &"palisade"
		spec.generate(seed)
		var plan := VillageSitePlanner.plan(spec)
		VillageEnclosurePlan.author(plan)
		VillageDressContext.mine_adit(plan, VillageDressContext.make_context(plan))
		_expect(res, plan.props.size() == 1, "seed%d: no mine mouth" % seed)
		if plan.props.is_empty(): continue
		_expect(res, VillageArchetypeSuite._adit_at_through_end(plan), "seed%d: inaccessible or misplaced adit" % seed)
		var dress := VillageDressCheck.new()
		dress._check_road(plan)
		_expect(res, dress.failures.is_empty(), "seed%d: adit/apron obstructs a road" % seed)
		var prop: Dictionary = plan.props[0]
		var native_kit := MeshKit.new(4)
		var native := PropKit.new(native_kit, 0, 1, 2, 3)
		var at: Vector2 = prop["pos"]
		var native_box := native.adit(Vector3(at.x, 0.0, at.y), prop["yaw"])
		var native_mesh := native_kit.commit()
		var mesh_box: AABB = native_mesh.get_aabb()
		_expect(res, mesh_box.position.distance_to(native_box.position) < 0.001 \
			and mesh_box.size.distance_to(native_box.size) < 0.001, "seed%d: emitted spoil heaps differ from footprint" % seed)
		var builder := VillageBuilder.new()
		var mesh := builder.build(plan)
		var rows: Array = builder.mass_log.filter(func(row: Dictionary) -> bool: return String(row["name"]).begins_with("adit"))
		_expect(res, mesh != null and rows.size() == 1, "seed%d: planned mine not emitted" % seed)
		if seed == 0:
			_expect(res, _clear_native_passage(native_mesh, at, prop["yaw"]), "mine passage metadata pierces emitted rock, spoil or timber")
			_negatives(res, plan)
	return res


static func _negatives(res: SuiteResult, plan: VillagePlan) -> void:
	var prop: Dictionary = plan.props[0]
	var rect: Rect2 = prop["rect"]
	prop["rect"] = rect.grow(-0.2)
	_expect(res, not VillageArchetypeSuite._adit_at_through_end(plan), "undersized spoil footprint escaped")
	prop["rect"] = rect
	var yaw: float = prop["yaw"]
	prop["yaw"] = yaw + PI
	_expect(res, not VillageArchetypeSuite._adit_at_through_end(plan), "mouth facing away from road escaped")
	prop["yaw"] = yaw
	plan.water.append({"kind": &"pond", "poly": Poly.from_rect(rect.grow(0.2))})
	_expect(res, not VillageArchetypeSuite._adit_at_through_end(plan), "flooded adit escaped")
	plan.water.clear()
	var apron: PackedVector2Array = prop["approach"]
	prop.erase("approach")
	_expect(res, not VillageArchetypeSuite._adit_at_through_end(plan), "missing working apron escaped")
	prop["approach"] = apron
	var across: Vector2 = (apron[1] - apron[0]).normalized() * 0.2
	var towards: Vector2 = (apron[3] - apron[0]).normalized()
	var centre_start := (apron[0] + apron[1]) * 0.5
	var entry: Vector2 = prop["pos"]
	var corners := Poly.from_rect(rect)
	for edge in corners.size():
		var hit = Geometry2D.segment_intersects_segment(centre_start, prop["pos"], corners[edge], corners[(edge+1)%corners.size()])
		if hit != null and Vector2(hit).distance_to(centre_start) < entry.distance_to(centre_start): entry = hit
	var side := (apron[1]-apron[0]) * 0.5 + across
	plan.water.append({"kind": &"pond", "poly": PackedVector2Array([entry - side - towards * 0.8,
		entry + side - towards * 0.8, entry + side - towards * 0.2, entry - side - towards * 0.2])})
	_expect(res, not VillageArchetypeSuite._adit_at_through_end(plan), "blocked working apron escaped")
	plan.water.clear()
	prop["approach"] = PackedVector2Array([apron[0],apron[1],entry + side,entry - side])
	_expect(res, not VillageArchetypeSuite._adit_at_through_end(plan), "apron stopping before timber mouth escaped")
	prop["approach"] = apron
	prop["built"] = false
	_expect(res, not VillageArchetypeSuite._adit_at_through_end(plan), "unemitted decorative adit label escaped")
	prop["built"] = true
	var saved_boundary: PackedVector2Array = plan.enclosure
	var centre: Vector2 = rect.get_center()
	plan.enclosure = PackedVector2Array([centre - Vector2(0, 4), centre + Vector2(0, 4), centre + Vector2(8, 0)])
	_expect(res, not VillageArchetypeSuite._adit_at_through_end(plan), "boundary through mine mouth escaped")
	plan.enclosure = saved_boundary


static func _clear_native_passage(mesh: ArrayMesh, at: Vector2, yaw: float) -> bool:
	var turn := Basis(Vector3.UP, yaw)
	for x in [-0.6, 0.0, 0.6]:
		for y in [0.1, 0.8, 1.7]:
			var origin := Vector3(at.x, 0, at.y)
			var start := origin + turn * Vector3(x,y,-5)
			var end := origin + turn * Vector3(x,y,0.4)
			for surface in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for i in range(0,vertices.size(),3):
					if Geometry3D.segment_intersects_triangle(start,end,vertices[i],vertices[i+1],vertices[i+2]) != null:
						return false
	return true


static func _expect(res: SuiteResult, passed: bool, why: String) -> void:
	res.checked += 1
	if not passed: res.fail(why)
