extends RefCounted
## Exercise the real access emitter without re-running interior furnishing.

static func run(filters := PackedStringArray()) -> SuiteResult:
	var res := SuiteResult.new("castle physical access")
	for style in CastleSweep.styles():
		for tier in [&"castle", &"fortress"]:
			for index in range(3):
				var who := "%s/%s/%d" % [style, tier, index]
				if not filters.is_empty() and not Array(filters).any(func(f): return who.contains(f)):
					continue
				var spec := CastleSweep.spec_at(style, tier, index)
				if not CastleGeometry.is_enclosed(spec):
					continue
				var builder := CastleBuilder.new()
				builder.spec = spec
				builder.begin(4)
				for ring in CastleGeometry.rings(spec):
					builder._build_ring(ring)
				builder._build_wall_stairs()
				var mesh := builder.commit()
				var check := CastleMassingCheck.new()
				check._check_wall_stairs(spec, builder)
				_expect(res, check.failures.is_empty(), who + " " + str(check.failures))
				_expect(res, ComponentCheck.check(builder, mesh)["ok"], who + " stair components differ from real triangles")
				var triangles: Array = []
				for surface in mesh.get_surface_count():
					triangles.append_array(HouseQA._mesh_triangles(mesh, surface))
				var missing := 0
				var blocked := 0
				for row in builder.component_log:
					if row.role not in ["wall_stair_tread", "wall_stair_landing"]:
						continue
					var centre: Vector3 = row.xf.origin + Vector3.UP * row.size.y * 0.5
					if not _hit(triangles, centre + Vector3.UP * 0.04, centre - Vector3.UP * 0.04):
						missing += 1
					if _hit(triangles, centre + Vector3.UP * 0.05, centre + Vector3.UP * 1.95):
						blocked += 1
						print("BLOCKED ", who, " ", row.host, " ", row.role, " ", centre)
						for tri in triangles:
							var hit = Geometry3D.segment_intersects_triangle(centre + Vector3.UP * 0.05, centre + Vector3.UP * 1.95, tri[0], tri[1], tri[2])
							if hit != null:
								print("HIT ", hit, " triangle ", tri)
								break
				_expect(res, missing == 0, who + " %d treads/landings have no emitted floor" % missing)
				_expect(res, blocked == 0, who + " %d treads/landings have obstructed headroom" % blocked)
				if index == 0:
					builder.mass_log = builder.mass_log.filter(func(m): return not String(m.name).begins_with("wall_stair_"))
					check = CastleMassingCheck.new()
					check._check_wall_stairs(spec, builder)
					_expect(res, not check.failures.is_empty(), who + " missing stairs escaped QA")
				print("ACCESS ", who, " failures=", res.failures.size())
	_check_compact_octagon_stairs(res)
	_check_mont_forebuilding_clearance(res)
	return res


static func _check_compact_octagon_stairs(res: SuiteResult) -> void:
	var spec := CastleSpec.new()
	spec.style = &"crusader"
	spec.tier_override = &"castle"
	spec.width = 56.0 * 0.4
	spec.length = 56.0 * 0.4
	spec.height = 24.0 * 0.4
	CastleGenerator.generate(spec, CastleLandmarkSuite._seed_for("castel_del_monte", 0.4))
	spec.corner_towers = true
	spec.gate_towers = false
	spec.great_tower = -1
	spec.great_tower_scale = 1.0
	CastleLandmarkSuite._force_plan(spec, &"polygon", 8)
	var plans := CastleGeometry.wall_stairs(spec)
	var transverse := 0
	var edge: PackedVector2Array = CastleGeometry.enceinte_polygon(spec, 0)
	for stair in plans:
		var e: int = int(stair["edge"])
		var tangent := (edge[(e + 1) % edge.size()] - edge[e]).normalized()
		if absf(Vector2(stair["along"]).dot(tangent)) < 0.1:
			transverse += 1
	res.checked += 1
	if plans.size() != 2:
		res.fail("Castel del Monte 0.40: %d stairs, wants two" % plans.size())
	if plans.size() == 2:
		res.checked += 1
		var first: Dictionary = plans[0]
		var second: Dictionary = plans[1]
		if int(first.edge) == int(second.edge):
			res.fail("Castel del Monte 0.40: both stairs use edge %d" % int(first.edge))
		if first.footprint.intersects(second.footprint):
			res.fail("Castel del Monte 0.40: selected stair footprints overlap")
	if transverse == 0:
		res.fail("Castel del Monte 0.40: no short-facet transverse stair was selected")
	var builder := CastleBuilder.new()
	builder.spec = spec
	builder.begin(4)
	for ring in CastleGeometry.rings(spec):
		builder._build_ring(ring)
	builder._build_wall_stairs()
	var check := CastleMassingCheck.new()
	check._check_wall_stairs(spec, builder)
	for failure in check.failures:
		res.fail("Castel del Monte 0.40: " + String(failure))
	if plans.size() > 0:
		var removed: String = "wall_stair_%d" % 0
		builder.mass_log = builder.mass_log.filter(func(mass): return String(mass.name) != removed)
		builder.component_log = builder.component_log.filter(func(row): return String(row.host) != removed)
		check = CastleMassingCheck.new()
		check._check_wall_stairs(spec, builder)
		res.checked += 1
		if check.failures.is_empty():
			res.fail("Castel del Monte 0.40: one-stair negative control escaped wall-stair QA")


static func _check_mont_forebuilding_clearance(res: SuiteResult) -> void:
	for scale in [0.7, 1.0]:
		var spec := CastleSpec.new()
		spec.style = &"french_chateau"
		spec.tier_override = &"fortress"
		spec.width = 120.0 * scale
		spec.length = 80.0 * scale
		spec.height = 40.0 * scale
		CastleGenerator.generate(spec, CastleLandmarkSuite._seed_for("mont_saint_michel", scale))
		CastleLandmarkSuite._force_features("mont_saint_michel", spec)
		var fore: Dictionary = CastleGeometry.forebuilding(spec)
		if not spec.inner_ward or fore.is_empty():
			res.checked += 1
			res.fail("Mont-Saint-Michel %.2f: fixture lacks inner gate or raised forebuilding" % scale)
			continue
		var gate: AABB = CastleGeometry.gatehouse_aabb(spec, 1)
		var gate_rect := Rect2(gate.position.x, gate.position.z, gate.size.x, gate.size.z)
		var fore_footprint: Rect2 = fore["footprint"]
		res.checked += 1
		if fore_footprint.grow(0.22).intersects(gate_rect):
			res.fail("Mont-Saint-Michel %.2f: forebuilding lost its inner-gate clearance" % scale)
		var plans: Array[Dictionary] = CastleGeometry.wall_stairs(spec)
		for ring in CastleGeometry.rings(spec):
			var ring_stairs: Array[Dictionary] = plans.filter(func(stair): return int(stair["ring"]) == ring)
			res.checked += 1
			if ring_stairs.size() != 2:
				res.fail("Mont-Saint-Michel %.2f ring %d: %d clear wall stairs, expected two" % [scale, ring, ring_stairs.size()])
				continue
			var first: Rect2 = ring_stairs[0]["footprint"]
			var second: Rect2 = ring_stairs[1]["footprint"]
			res.checked += 1
			if first.intersects(second):
				res.fail("Mont-Saint-Michel %.2f ring %d: independent wall stairs overlap" % [scale, ring])
			for stair in ring_stairs:
				var footprint: Rect2 = stair["footprint"]
				res.checked += 1
				if footprint.intersects(fore_footprint.grow(0.22)):
					res.fail("Mont-Saint-Michel %.2f ring %d: %s overlaps forebuilding allowance" % [scale, ring, stair.get("name", "wall stair")])
		var builder := CastleBuilder.new()
		builder.build(spec)
		for mass in builder.mass_log:
			if not String(mass["name"]).begins_with("wall_stair_"):
				continue
			var box: AABB = mass["aabb"]
			var emitted_footprint := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
			res.checked += 1
			if emitted_footprint.intersects(fore_footprint.grow(0.22)):
				res.fail("Mont-Saint-Michel %.2f: emitted %s mass overlaps forebuilding allowance" % [scale, mass["name"]])


static func _hit(triangles: Array, a: Vector3, b: Vector3) -> bool:
	for tri in triangles:
		if Geometry3D.segment_intersects_triangle(a, b, tri[0], tri[1], tri[2]) != null:
			return true
	return false


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)
		print("FAIL: ", message)
