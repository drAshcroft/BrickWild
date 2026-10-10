class_name TempleSuite
extends RefCounted
## 16. Contract: user inputs survive generation, the mesh is well formed, its
##     surfaces face the right way, and the same seed rebuilds the identical
##     temple.

static func run() -> SuiteResult:
	var res := SuiteResult.new("temple")
	for form in TempleSweep.forms():
		for cult in TempleSweep.cults():
			for i in range(TempleSweep.COUNT):
				var spec: TempleSpec = TempleSweep.spec_at(form, cult, i)
				var row: Dictionary = TempleSweep.SIZES[i]
				var where := "form=%s cult=%s seed=%d" % [String(form), String(cult),
					spec.seed]
				res.checked += 1

				if spec.form != form or spec.cult != cult \
						or not is_equal_approx(spec.width, float(row["w"])) \
						or not is_equal_approx(spec.length, float(row["l"])) \
						or not is_equal_approx(spec.height, float(row["h"])):
					res.fail("user inputs mutated, " + where)
					continue

				var builder := TempleBuilder.new()
				var before: Array = _fingerprint(spec)
				var mesh: ArrayMesh = builder.build(spec)
				if _fingerprint(spec) != before:
					res.fail("build() mutated its spec, " + where)
				if mesh == null or mesh.get_surface_count() != 4:
					res.fail("bad mesh, " + where)
					continue
				var verts := 0
				for s in range(mesh.get_surface_count()):
					verts += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
						as PackedVector3Array).size()
				if verts < 200:
					res.fail("too few verts (%d), %s" % [verts, where])
				if builder.mass_log.is_empty():
					res.fail("no structural masses logged, " + where)
				if builder.prop_log.is_empty():
					res.fail("the temple was never dressed, " + where)
				_column_plan(res, spec, builder, where)
				_brazier_clearance(res, builder, where)
				NormalsSuite.check_mesh(res, mesh, where)

	# determinism: same seed, same temple
	res.checked += 1
	var a: TempleSpec = TempleSweep.spec_at(&"basilica", &"blood", 1)
	var b: TempleSpec = TempleSweep.spec_at(&"basilica", &"blood", 1)
	var ma: PackedVector3Array = TempleBuilder.new().build(a).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var mb: PackedVector3Array = TempleBuilder.new().build(b).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if ma != mb:
		res.fail("the same seed produced two different temples")

	# idempotence: building the same spec twice must not drift
	res.checked += 1
	var bb := TempleBuilder.new()
	var m1: PackedVector3Array = bb.build(a).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var props1: int = bb.prop_log.size()
	var m2: PackedVector3Array = bb.build(a).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if m1 != m2 or bb.prop_log.size() != props1:
		res.fail("rebuilding the same spec produced a different temple")
	_column_grid_helper(res)
	_compact_columns(res)
	_rotunda_brazier_wall_negative(res)
	return res


static func _brazier_clearance(res: SuiteResult, builder: TempleBuilder, where: String) -> void:
	var bowls: Array[AABB] = []
	for p in builder.prop_log:
		if p["key"] != "Cauldron":
			continue
		var pos: Vector3 = p["pos"]
		var size := PropCatalog.size("Cauldron") * float(p["scale"])
		var bounds := AABB(pos + Vector3(-size.x * 0.5, 0, -size.z * 0.5), size)
		var brazier_box := {"xf": Transform3D(Basis.IDENTITY,
			pos + Vector3(0, size.y * 0.5, 0)), "size": size}
		var rotunda_walls: Dictionary = TempleQA._rotunda_wall_components(builder) \
			if builder.spec.form == &"rotunda" else {}
		res.checked += 1
		var footprint := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(size.x, size.z))
		for corner in Poly.from_rect(footprint):
			var supported := false
			for floor_rect in TempleGeometry.floor_rects(builder.spec):
				supported = supported or floor_rect.grow(0.001).has_point(corner)
			if not supported:
				res.fail("brazier foot has no floor at %s, %s" % [corner, where])
		for mass in builder.mass_log:
			var name := String(mass["name"])
			if builder.spec.form == &"rotunda" and name.begins_with("wall_rotunda_"):
				var component: Dictionary = rotunda_walls.get(name, {})
				if component.is_empty():
					res.fail("brazier clearance lacks actual oriented wall component %s, %s" % [name, where])
				elif TempleQA._rotunda_box_overlap_depth(component, brazier_box) > MassRules.TOL:
					res.fail("brazier intersects actual Rotunda wall %s at %s, %s" % [name, pos, where])
			elif name.begins_with("wall_") or name.begins_with("pylon_") \
					or name.begins_with("column_") or name == "dais":
				if bounds.intersects(mass["aabb"]):
					res.fail("brazier intersects %s at %s, %s" % [name, pos, where])
		for other in bowls:
			if bounds.intersects(other):
				res.fail("braziers overlap at %s, %s" % [pos, where])
		bowls.append(bounds)


## The rotated wall check must still reject the same Cauldron footprint when a
## person moves it into an actual emitted panel. This control uses the same SAT
## predicate as the live bowl checks; no wall-family exemption is involved.
static func _rotunda_brazier_wall_negative(res: SuiteResult) -> void:
	var spec := TempleSpec.new(54811)
	spec.form = &"rotunda"
	spec.cult = &"blood"
	TempleGenerator.generate(spec, spec.seed)
	var builder := TempleBuilder.new()
	builder.build(spec)
	var walls: Dictionary = TempleQA._rotunda_wall_components(builder)
	if walls.is_empty():
		res.fail("Rotunda brazier wall negative has no emitted panel geometry")
		return
	var names: Array = walls.keys()
	names.sort()
	var wall: Dictionary = walls[names[0]]
	var wall_xf: Transform3D = wall["xf"]
	var size: Vector3 = PropCatalog.size("Cauldron") * 0.75
	var moved_brazier := {"xf": Transform3D(Basis.IDENTITY, wall_xf.origin),
		"size": size}
	res.checked += 1
	if TempleQA._rotunda_box_overlap_depth(wall, moved_brazier) <= MassRules.TOL:
		res.fail("actual Cauldron footprint inside %s escaped the Rotunda wall SAT negative" % names[0])
	_rotunda_recorded_brazier_controls(res)


## Every captured wall-hit remains rejected. A nearby inward station must still
## pass placement and have emitted floor support.
static func _rotunda_recorded_brazier_controls(res: SuiteResult) -> void:
	var cases: Array[Dictionary] = [
		{"cult": &"blood", "seed": 31304, "positions": [Vector2(-6.716875, -8.562364), Vector2(6.716875, -8.562364)]},
		{"cult": &"void", "seed": 31304, "positions": [Vector2(-6.716875, -8.562364), Vector2(6.716875, -8.562364)]},
		{"cult": &"flame", "seed": 31316, "positions": [Vector2(-3.464875, -5.158746), Vector2(3.464875, -5.158746)]},
		{"cult": &"bone", "seed": 31349, "positions": [Vector2(-3.464875, -5.118890), Vector2(3.464875, -5.118890)]},
		{"cult": &"serpent", "seed": 31356, "positions": [Vector2(-3.464875, -5.171854), Vector2(3.464875, -5.171854)]},
	]
	for witness in cases:
		var spec: TempleSpec = null
		for i in range(TempleSweep.COUNT):
			var candidate: TempleSpec = TempleSweep.spec_at(&"rotunda", witness["cult"], i)
			if candidate.seed == int(witness["seed"]):
				spec = candidate
				break
		if spec == null:
			res.fail("recorded Rotunda brazier seed is no longer canonical: %s" % str(witness))
			continue
		var builder := TempleBuilder.new()
		var mesh: ArrayMesh = builder.build(spec)
		builder.prop_log.clear()
		var walls: Dictionary = TempleQA._rotunda_wall_components(builder)
		var stone: Array = MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_STONE)
		var physical_size: Vector3 = PropCatalog.size("Cauldron") * TempleBuilder.BRAZIER_SCALE
		for pos in witness["positions"]:
			res.checked += 1
			var actual_box := {"xf": Transform3D(Basis.IDENTITY,
				Vector3(pos.x, 0.002 + physical_size.y * 0.5, pos.y)),
				"size": physical_size}
			var hit_name := ""
			for name in walls:
				if TempleQA._rotunda_box_overlap_depth(walls[name], actual_box) > MassRules.TOL:
					hit_name = String(name)
					break
			if hit_name.is_empty():
				res.fail("recorded Cauldron witness no longer hits an emitted Rotunda wall: seed=%d pos=%s" % [spec.seed, str(pos)])
			if builder._brazier_clear(pos):
				res.fail("Rotunda placement still accepts its wall-hit witness %s seed=%d pos=%s" % [hit_name, spec.seed, str(pos)])
			var nearby_clear := false
			for step in range(1, 13):
				var inward: Vector2 = pos - pos.normalized() * (0.15 * float(step))
				if not builder._brazier_clear(inward):
					continue
				var half: Vector2 = PropCatalog.footprint("Cauldron") \
					* TempleBuilder.BRAZIER_SCALE * 0.5
				var supported := true
				for point in [inward, inward + Vector2(-half.x, -half.y),
						inward + Vector2(-half.x, half.y), inward + Vector2(half.x, -half.y),
						inward + Vector2(half.x, half.y)]:
					if not MeshProbe.has_upward_support(stone, point, 0.001, 0.03):
						supported = false
						break
				if not supported:
					continue
				var neighbor_box := {"xf": Transform3D(Basis.IDENTITY,
					Vector3(inward.x, 0.002 + physical_size.y * 0.5, inward.y)),
					"size": physical_size}
				var hits_wall := false
				for wall in walls.values():
					if TempleQA._rotunda_box_overlap_depth(wall, neighbor_box) > MassRules.TOL:
						hits_wall = true
						break
				if not hits_wall:
					nearby_clear = true
					break
			if not nearby_clear:
				res.fail("no nearby supported clear brazier station within 1.8m; seed=%d pos=%s" % [spec.seed, str(pos)])


static func _compact_columns(res: SuiteResult) -> void:
	for seed in [731, 42, 4413]:
		for size in [Vector2(18, 24), Vector2(24, 24), Vector2(24, 30), Vector2(36, 42)]:
			var spec := TempleSpec.new(seed)
			spec.form = &"ziggurat"
			spec.width = size.x
			spec.length = size.y
			spec.height = 16
			TempleGenerator.generate(spec, seed)
			var builder := TempleBuilder.new()
			builder.build(spec)
			var columns: Array[Dictionary] = []
			for mass in builder.mass_log:
				if String(mass["name"]).begins_with("column_"):
					columns.append(mass)
			var overlap := MassRules.overlaps(columns, func(_a: String, _b: String) -> float: return 0.0, ["column"])
			res.checked += 1
			if not overlap["failures"].is_empty():
				res.fail("compact column capitals collide seed=%d size=%s: %s" % [seed, size, overlap["failures"]])
			if spec.columns.size() >= 3:
				spec.columns[2]["pos"] = Vector3(spec.columns[0]["pos"]) + Vector3(0.1, 0, 0)
				builder.build(spec)
				columns.clear()
				for mass in builder.mass_log:
					if String(mass["name"]).begins_with("column_"):
						columns.append(mass)
				var bad := MassRules.overlaps(columns, func(_a: String, _b: String) -> float: return 0.0, ["column"])
				res.checked += 1
				if bad["failures"].is_empty():
					res.fail("compact column collision mutation escaped")


static func _column_plan(res: SuiteResult, spec: TempleSpec, builder: TempleBuilder, where: String) -> void:
	var expected: Array[Dictionary] = TempleGeometry.column_records(spec)
	res.checked += 1
	if spec.columns.size() != expected.size():
		res.fail("column plan count drifted from geometry, " + where)
		return
	for i in range(spec.columns.size()):
		var got: Dictionary = spec.columns[i]
		var want: Dictionary = expected[i]
		res.checked += 1
		if got["pos"] != want["pos"] or not is_equal_approx(float(got["radius"]), float(want["radius"])) \
			or not is_equal_approx(float(got["height"]), float(want["height"])):
			res.fail("column plan changed emitted position/radius/height at %d, %s" % [i, where])
		if not got.has("ring"):
			res.fail("column plan row has no ring id, " + where)
		var expected_aabb := AABB(Vector3(got["pos"].x - float(got["radius"]) * 1.2, 0.0,
			got["pos"].z - float(got["radius"]) * 1.2),
			Vector3(float(got["radius"]) * 2.4,
				float(got["height"]) + TempleGeometry.COLUMN_CAP * float(got["radius"]),
				float(got["radius"]) * 2.4))
		var emitted: Dictionary = {}
		for mass in builder.mass_log:
			if String(mass["name"]) == "column_%d" % i:
				emitted = mass
				break
		res.checked += 1
		if emitted.is_empty() or emitted["aabb"] != expected_aabb:
			res.fail("column mass_log drifted from authored plan at %d, %s" % [i, where])


static func _column_grid_helper(res: SuiteResult) -> void:
	var columns := ColumnGrid.grid(Rect2(-10, -10, 20, 20), 4, 4, 1.0)
	res.checked += 1
	if columns.size() != 16:
		res.fail("ColumnGrid did not emit a complete 4x4 grid")
	for column in columns:
		var p: Vector3 = column["pos"]
		var x_twin := false
		var z_twin := false
		for other in columns:
			var q: Vector3 = other["pos"]
			x_twin = x_twin or (absf(q.x + p.x) < 0.001 and absf(q.z - p.z) < 0.001)
			z_twin = z_twin or (absf(q.x - p.x) < 0.001 and absf(q.z + p.z) < 0.001)
		res.checked += 1
		if not x_twin or not z_twin:
			res.fail("ColumnGrid lost mirror symmetry at %s" % p)


## Everything about a spec the builder could plausibly rewrite.
static func _fingerprint(spec: TempleSpec) -> Array:
	return [spec.wall_t, spec.column_rows, spec.column_bays, spec.column_r,
		spec.aisle_width, spec.dais_steps, spec.dais_height, spec.altar_w,
		spec.altar_l, spec.altar_h, spec.idol_kind, spec.idol_height,
		spec.idol_width, spec.pit, spec.pit_radius, spec.bridge_width,
		spec.cells, spec.brazier_bays, spec.spire, spec.terraces, spec.obelisks]
