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
	return res


## Everything about a spec the builder could plausibly rewrite.
static func _fingerprint(spec: TempleSpec) -> Array:
	return [spec.wall_t, spec.column_rows, spec.column_bays, spec.column_r,
		spec.aisle_width, spec.dais_steps, spec.dais_height, spec.altar_w,
		spec.altar_l, spec.altar_h, spec.idol_kind, spec.idol_height,
		spec.idol_width, spec.pit, spec.pit_radius, spec.bridge_width,
		spec.cells, spec.brazier_bays, spec.spire, spec.terraces, spec.obelisks]
