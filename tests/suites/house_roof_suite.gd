extends RefCounted
## Roof-only regression tests measure the triangles, not projected coverage
## or the AABB the builder hoped to produce. The slow furnishing path is opt-in.

static func run(full := false) -> SuiteResult:
	var res := SuiteResult.new("house roofs")
	_hip_primitive(res)
	_subtraction(res)
	_lowered_gable(res)
	for kind in [&"gable", &"half_hipped", &"hipped"]:
		for size in [Vector2(7, 9), Vector2(14, 7), Vector2(8, 8), Vector2(10, 13)]:
			for pitch in [0.7, 1.6]:
				var s := HouseSpec.new()
				s.width = size.x
				s.length = size.y
				s.height = 2.7
				s.storeys = 2
				s.roof_pitch = pitch
				s.roof_type = kind
				s.room_count = 1
				s.program = [&"hall"]
				s.dormers = true
				s.dormer_count = 3
				s.timber_frame = false
				s.bargeboards = false
				var plan := HousePlanner.plan(s)
				var builder := HouseBuilder.new()
				var mesh := builder.build(plan)
				var who := "%s %s pitch %.1f" % [kind, size, pitch]
				_check_house(res, plan, mesh, who)
				var before: PackedVector3Array = mesh.surface_get_arrays(2)[Mesh.ARRAY_VERTEX]
				var second := builder.build(plan)
				_expect(res, before == second.surface_get_arrays(2)[Mesh.ARRAY_VERTEX], who + " rebuild changed roof")
				builder.build(plan, false)
				_expect(res, builder.roof_components.is_empty(), who + " cutaway retained roof components")
	_rotation(res)
	for row in [[&"farmhouse", 4413, 10.0, 13.0, 2.7, 1],
			[&"townhouse", 4411, 9.0, 12.0, 2.7, 2],
			[&"cottage", 4412, 7.0, 9.0, 2.5, 1],
			[&"longhall", 4414, 12.0, 16.0, 2.7, 1]]:
		var s := HouseSpec.new()
		s.style = row[0]
		s.width = row[2]
		s.length = row[3]
		s.height = row[4]
		s.storeys = row[5]
		var plan := HouseGenerator.generate(s, row[1], full)
		var builder := HouseBuilder.new()
		var mesh := builder.build(plan)
		_check_house(res, plan, mesh, "%s seed=%s" % [row[0], row[1]])
		res.note("%s seed=%d roof=%s fitted_dormers=%d" % [s.style, s.seed, s.roof_type,
			HouseGeometry.roof_layout(plan)["dormers"].size()])
	return res


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)


static func _triangles(mesh: ArrayMesh, surface: int) -> Array:
	return HouseQASuite._triangles(mesh, surface)


static func _hits(tris: Array, a: Vector3, b: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for t in tris:
		var hit = Geometry3D.segment_intersects_triangle(a, b, t[0], t[1], t[2])
		if hit != null:
			out.append(hit)
	return out


static func _hip_error(mesh: ArrayMesh, span: float, along: float, rise: float) -> float:
	var tris := _triangles(mesh, 0)
	var error := 0.0
	var h := span * 0.5
	var f := along * 0.5
	# Independent envelope equation: a hip is the lower of its side and end
	# planes. The old crossed rectangles fail although every X/Z is covered.
	var end_run := minf(h, f)
	for ix in range(1, 12):
		for iz in range(1, 14):
			var x := -h + span * float(ix) / 12.0
			var z := -f + along * float(iz) / 14.0
			var expected := minf(rise * (1.0 - absf(x) / h), rise * (f - absf(z)) / end_run) + 0.12
			var hits := _hits(tris, Vector3(x, rise + 2, z), Vector3(x, -1, z))
			var top := -INF
			for p in hits:
				top = maxf(top, p.y)
			error = maxf(error, absf(top - expected))
	return error


static func _hip_primitive(res: SuiteResult) -> void:
	for size in [Vector2(10.7, 13.5), Vector2(8, 8), Vector2(8, 8.02), Vector2(12, 7)]:
		var kit := MeshKit.new(1)
		kit.hip_roof_at(Transform3D.IDENTITY, size.x, size.y, 3.6, 0)
		_expect(res, _hip_error(kit.commit(), size.x, size.y, 3.6) < 0.002,
			"hip envelope differs from joined face planes: %s" % size)
	# Mutation fixture: retain the previous crossed-slab construction so a
	# future implementation cannot weaken this into a coverage-only test.
	var bad := MeshKit.new(1)
	var h := 5.35
	var f := 6.75
	var rise := 3.6
	for side in [-1.0, 1.0]:
		bad.oriented_box(Vector3(sqrt(h * h + rise * rise), 0.24, 2.8),
			Transform3D(Basis(Vector3.FORWARD, side * atan2(rise, h)), Vector3(side * h * 0.5, rise * 0.5, 0)), 0)
		bad.oriented_box(Vector3(h * 2, 0.24, sqrt(f * f + rise * rise)),
			Transform3D(Basis(Vector3.RIGHT, side * atan2(rise, f)), Vector3(0, rise * 0.5, side * f * 0.5)), 0)
	_expect(res, _hip_error(bad.commit(), h * 2, f * 2, rise) > 0.2,
		"hip regression failed to reject old crossed slabs")


static func _subtraction(res: SuiteResult) -> void:
	var outer := Poly.from_rect(Rect2(-5, -5, 10, 10))
	var hole := PackedVector2Array([Vector2(-2,-1), Vector2(1,-1), Vector2(2,0), Vector2(1,1), Vector2(-2,1)])
	var pieces := RoofShape.subtract(outer, hole)
	var area := 0.0
	for i in range(pieces.size()):
		area += Poly.area(pieces[i])
		_expect(res, Poly.intersection_area(pieces[i], hole) < 0.0001, "roof cut covers its hole")
		for j in range(i):
			_expect(res, Poly.intersection_area(pieces[i], pieces[j]) < 0.0001, "roof cut duplicated a face")
	_expect(res, absf(area + Poly.area(hole) - 100.0) < 0.0001, "roof cut lost area outside opening")


static func _lowered_gable(res: SuiteResult) -> void:
	var s := HouseSpec.new()
	s.width = 7
	s.length = 9
	s.roof_type = &"gable"
	s.dormers = false
	var plan := HousePlanner.plan(s)
	var original := HouseBuilder.new().build(plan)
	var mutant := ArrayMesh.new()
	for surface in original.get_surface_count():
		var arrays := original.surface_get_arrays(surface)
		if surface == 0:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in vertices.size():
				if vertices[i].y > s.height + 0.01:
					vertices[i].y -= 0.3
			arrays[Mesh.ARRAY_VERTEX] = vertices
		mutant.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var result := SuiteResult.new("lowered gable mutation")
	_check_house(result, plan, mutant, "lowered gable")
	_expect(res, result.failures.any(func(f: String) -> bool: return f.contains("lateral wall/roof gaps")),
		"lateral envelope check accepted a lowered gable")


static func _check_house(res: SuiteResult, plan: HousePlan, mesh: ArrayMesh, who: String) -> void:
	var layout := HouseGeometry.roof_layout(plan)
	var faces: Array[PackedVector3Array] = layout["faces"]
	var xf: Transform3D = layout["transform"]
	var h := float(layout["span"]) * 0.5
	var f := float(layout["along"]) * 0.5
	var walls := _triangles(mesh, 0)
	var misses := 0
	for edge in [[Vector2(-h,-f), Vector2(h,-f), Vector2(0,-1)],
			[Vector2(-h,f), Vector2(h,f), Vector2(0,1)],
			[Vector2(-h,-f), Vector2(-h,f), Vector2(-1,0)],
			[Vector2(h,-f), Vector2(h,f), Vector2(1,0)]]:
		for i in range(1, 12):
			var p: Vector2 = edge[0].lerp(edge[1], float(i) / 12.0)
			var y := RoofShape.height_at(faces, p) - 0.12 - 0.025
			if y <= 0.01:
				continue
			var a: Vector2 = p + edge[2] * 0.15
			var b: Vector2 = p - edge[2] * 0.1
			if _hits(walls, xf * Vector3(a.x, y, a.y), xf * Vector3(b.x, y, b.y)).is_empty():
				misses += 1
	_expect(res, misses == 0, "%s: %d lateral wall/roof gaps" % [who, misses])
	var roofs := _triangles(mesh, 2)
	for d in layout["dormers"]:
		var x := lerpf(d["front"], d["peak_x"], 0.32)
		var z: float = d["z"] + 0.03
		var y := RoofShape.height_at(faces, Vector2(x,z))
		_expect(res, _hits(roofs, xf * Vector3(x, y + 0.13, z), xf * Vector3(x, y - 0.13, z)).is_empty(),
			who + ": host roof still crosses dormer opening")
		var cover := _hits(roofs, xf * Vector3(x, y + 3, z), xf * Vector3(x, y + 0.14, z))
		_expect(res, not cover.is_empty(), who + ": missing dormer rooflet")
	# Every emitted triangle has a finite nonzero normal.
	for surface in range(mesh.get_surface_count()):
		var normals: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_NORMAL]
		var valid := true
		for n in normals:
			if not n.is_finite() or n.length_squared() < 0.9:
				valid = false
		_expect(res, valid, who + ": degenerate mesh normal")


static func _rotation(res: SuiteResult) -> void:
	var plans: Array[HousePlan] = []
	for size in [Vector2(7,14), Vector2(14,7)]:
		var s := HouseSpec.new()
		s.width = size.x
		s.length = size.y
		var p := HouseGenerator.generate(s, 4413, false)
		s.chimney = false
		plans.append(p)
	_expect(res, plans[0].spec.dormers == plans[1].spec.dormers and plans[0].spec.dormer_count == plans[1].spec.dormer_count,
		"rotated footprint changed dormer eligibility/count")
	_expect(res, HouseGeometry.roof_layout(plans[0])["dormers"] == HouseGeometry.roof_layout(plans[1])["dormers"],
		"rotated footprint changed roof-local dormer fit")
