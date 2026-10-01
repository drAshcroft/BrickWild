extends RefCounted
## CAS-013: sampled curved-wall geometry, surface-local apertures, and style
## selection. Root runs this focused selector after editor class registration.

static func run() -> SuiteResult:
	var res := SuiteResult.new("CAS-013 curved castle curtain")
	var chosen: Dictionary = CastleSpec.plan_for(&"elven", &"castle", 13013)
	_expect(res, chosen.kind == &"polygon", "Elven castle did not choose its polygon plan")
	var spec := CastleSpec.new()
	spec.style = &"elven"
	spec.width = 60.0
	spec.length = 70.0
	spec.height = 20.0
	spec.tier_override = &"castle"
	CastleGenerator.generate(spec, 13013)
	_expect(res, spec.curved_edges, "Elven generator did not enable curved edges")
	_expect(res, spec.plan_kind == &"polygon", "Elven generator lost its forced polygon plan")
	var vertices := CastleGeometry.vertex_tower_centers(spec, 0)
	_expect(res, vertices.size() == spec.sides,
		"curved curtains moved towers away from their polygon vertices")

	var builder := CastleBuilder.new()
	builder.begin_metric(5)
	builder.spec = spec
	builder.tag("curtain")
	var seg := {
		"name": "cas013_fixture", "a": Vector2(-12.0, 0.0),
		"b": Vector2(12.0, 0.0), "length": 24.0,
		"yaw": 0.0, "outward": Vector3(0.0, 0.0, -1.0),
	}
	builder._curved_wall_run(seg, 0)
	var mesh: ArrayMesh = builder.commit()
	var wall: AABB = builder.mass_log[0].aabb
	_expect(res, wall.position.z < -3.0,
		"wall mass bounds ignored the outward curved sagitta")
	var windows := builder.part_log.filter(func(row: Dictionary) -> bool:
		return row.get("kind") == "window" and row.get("tag") == "curtain")
	_expect(res, not windows.is_empty(), "curved wall omitted its through-slits")
	if not windows.is_empty():
		_expect(res, windows[0].pos.z < -0.1,
			"curved slit was placed on the unbowed chord instead of the arc")
	_expect(res, mesh.get_surface_count() >= 2,
		"curved wall did not emit masonry and aperture-return surfaces")
	_check_face_normals(res, mesh)

	# A disabled feature is an explicit control: the established Norman plan is
	# still straight, and malformed paths do not leak degenerate triangles.
	var norman := CastleSpec.new()
	norman.style = &"norman"
	CastleGenerator.generate(norman, 13014)
	_expect(res, not norman.curved_edges, "curved-wall default leaked into Norman style")
	var invalid := MeshKit.new(1, true)
	var empty := invalid.curved_wall(PackedVector3Array([Vector3.ZERO]), 5.0,
		2.0, 1.0, 0)
	_expect(res, empty.size == Vector3.ZERO,
		"curved wall accepted a one-point path as structural mass")
	return res


static func _check_face_normals(res: SuiteResult, mesh: ArrayMesh) -> void:
	var checked := 0
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in range(0, vertices.size(), 3):
			var expected: Vector3 = MeshKit._face_normal(vertices[i], vertices[i + 1], vertices[i + 2])
			for j in range(3):
				_expect(res, normals[i + j].dot(expected) > 0.99,
					"curved wall triangle has a missing or smoothed face normal")
			checked += 1
	_expect(res, checked > 0, "curved wall emitted no inspectable triangles")


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)
