class_name LegacyBuildingSuite
extends RefCounted
## 4. The superseded house-generator stack (src/building/). Kept passing so the
##    decision to finish or delete it stays a decision, not an accident.

const COUNT := 200

static func run() -> SuiteResult:
	var res := SuiteResult.new("legacy building")
	var total_verts := 0
	for i in range(COUNT):
		var spec: BuildingSpec = SpecGenerator.generate(1000 + i)
		res.checked += 1
		if not (spec.style in [&"european", &"east_asian"]):
			res.fail("seed=%d unknown style %s" % [1000 + i, String(spec.style)])
			continue
		var mesh: ArrayMesh = BuildingBuilder.new().build(spec)
		if mesh == null or mesh.get_surface_count() != 4:
			res.fail("seed=%d surfaces=%d" % [1000 + i,
				mesh.get_surface_count() if mesh else -1])
			continue
		for s in range(mesh.get_surface_count()):
			total_verts += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	# building the same spec twice must produce the same mesh: the builder used
	# to draw its randomness from spec.rng, advancing it on every build.
	var spec: BuildingSpec = SpecGenerator.generate(4242)
	var b := BuildingBuilder.new()
	res.checked += 1
	var v1: PackedVector3Array = b.build(spec).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var v2: PackedVector3Array = b.build(spec).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if v1 != v2:
		res.fail("rebuilding the same BuildingSpec produced different geometry")

	res.note("%d houses, %d total vertices" % [COUNT, total_verts])
	return res
