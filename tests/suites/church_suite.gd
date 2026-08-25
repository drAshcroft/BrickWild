class_name ChurchSuite
extends RefCounted
## 1. Contract: user inputs survive generation, meshes are well formed, and the
##    same seed rebuilds the identical building.

static func run() -> SuiteResult:
	var res := SuiteResult.new("church")
	for style in TestSweep.styles():
		for i in range(TestSweep.COUNT):
			var want_len: float = 18.0 + i * 2.0
			var spec: ChurchSpec = TestSweep.spec_at(style, i)
			res.checked += 1
			var sd: int = TestSweep.seed_at(i)

			if spec.style != style or not is_equal_approx(spec.length, want_len):
				res.fail("user inputs mutated, style=%s seed=%d" % [String(style), sd])
				continue

			var builder := ChurchBuilder.new()
			var before_aisles: int = spec.aisles
			var mesh: ArrayMesh = builder.build(spec)
			# build() must be a pure function of its spec
			if spec.aisles != before_aisles:
				res.fail("build() mutated spec.aisles (%d -> %d) style=%s seed=%d"
					% [before_aisles, spec.aisles, String(style), sd])
			if mesh == null or mesh.get_surface_count() != 4:
				res.fail("bad mesh style=%s seed=%d" % [String(style), sd])
				continue
			var verts := 0
			for s in range(mesh.get_surface_count()):
				verts += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			if verts < 100:
				res.fail("too few verts (%d) style=%s seed=%d" % [verts, String(style), sd])

	# determinism: same seed, same geometry
	var a := ChurchSpec.new(); a.style = &"gothic"
	var b := ChurchSpec.new(); b.style = &"gothic"
	ChurchGenerator.generate(a, 42)
	ChurchGenerator.generate(b, 42)
	res.checked += 1
	var ma: PackedVector3Array = ChurchBuilder.new().build(a).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var mb: PackedVector3Array = ChurchBuilder.new().build(b).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if ma != mb:
		res.fail("same seed produced different geometry")

	# idempotence: building the same spec twice must not drift
	var c: ChurchSpec = TestSweep.spec_at(&"romanesque", 3)
	res.checked += 1
	var bb := ChurchBuilder.new()
	var m1: PackedVector3Array = bb.build(c).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var m2: PackedVector3Array = bb.build(c).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if m1 != m2:
		res.fail("rebuilding the same spec produced different geometry")
	return res
