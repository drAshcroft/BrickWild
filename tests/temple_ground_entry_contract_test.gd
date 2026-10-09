extends SceneTree
## Ground approach and first-chamber headroom. This does not certify ascent.

var failures: Array[String] = []

func _initialize() -> void:
	var cases := 0
	for dimensions in [Vector3(18, 24, 8), Vector3(26, 44, 12), Vector3(48, 80, 20)]:
		for cult in TempleSweep.cults():
			for seed_value in [1, 8102, 21325]:
				var spec := TempleSpec.new(seed_value)
				spec.form = &"ziggurat"
				spec.cult = cult
				spec.width = dimensions.x
				spec.length = dimensions.y
				spec.height = dimensions.z
				TempleGenerator.generate(spec, seed_value)
				var builder := TempleBuilder.new()
				var mesh: ArrayMesh = builder.build(spec)
				var label := "%s/%s/%d" % [cult, str(dimensions), seed_value]
				_check_case(spec, mesh, label, cases == 0)
				cases += 1
	for failure in failures:
		push_error(failure)
	print("ziggurat ground-entry contract: %d cases, %d failures" % [cases, failures.size()])
	quit(1 if not failures.is_empty() else 0)

func _check_case(spec: TempleSpec, mesh: ArrayMesh, label: String, negative: bool) -> void:
	var stones := MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_STONE)
	var interior := TempleGeometry.interior_rect(spec)
	var site := TempleGeometry.site_rect(spec)
	var old_end := site.position.y + 0.4
	var bridge_end := interior.position.y + 0.2
	var floor_y := 0.001
	for fraction in [0.15, 0.5, 0.85]:
		for x in [-TempleGeometry.PERSON_RADIUS, 0.0, TempleGeometry.PERSON_RADIUS]:
			var point := Vector2(x, lerpf(old_end, bridge_end, fraction))
			if not MeshProbe.has_upward_support(stones, point, floor_y):
				failures.append("%s missing emitted ground paving at %s" % [label, str(point)])
	var entry := TempleGeometry.entry_point(spec)
	var feet := Vector3(entry.x, floor_y + 0.02, entry.y)
	var head := feet + Vector3.UP * 1.97
	if MeshProbe.ray_blocked(stones, feet, head):
		failures.append("%s first chamber blocks a two-metre ground-level body" % label)
	if TempleGeometry.terrace_height(spec) < 2.0:
		failures.append("%s generated an occupied terrace below two metres" % label)
	if not negative:
		return
	var sample := Vector2(0.0, lerpf(old_end, bridge_end, 0.5))
	var from := Vector3(sample.x, floor_y + 0.05, sample.y)
	var to := Vector3(sample.x, floor_y - 0.05, sample.y)
	var removed := MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_STONE,
		func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			return (c - a).cross(b - a).normalized().dot(Vector3.UP) > 0.95 \
				and Geometry3D.segment_intersects_triangle(from, to, a, b, c) != null)
	var without_paving: ArrayMesh = removed.get("mesh")
	if int(removed.get("removed_triangles", 0)) == 0 or without_paving == null \
			or MeshProbe.has_upward_support(MeshProbe.surface_triangles(null,
				without_paving, TempleBuilder.SURF_STONE), sample, floor_y):
		failures.append("%s removed ground-paving negative was not rejected" % label)
	var sealed := MeshProbe.add_box(mesh, TempleBuilder.SURF_STONE,
		AABB(feet + Vector3(-0.4, 1.1, -0.4), Vector3(0.8, 0.3, 0.8)))
	var blocked: ArrayMesh = sealed.get("mesh")
	if blocked == null or not MeshProbe.ray_blocked(MeshProbe.surface_triangles(null,
			blocked, TempleBuilder.SURF_STONE), feet, head):
		failures.append("%s injected low-ceiling negative was not rejected" % label)
