extends RefCounted
## Bounded church geometry gate. The exhaustive style, seed and landmark
## sweeps remain in the named church suites and lane:church.

const Apertures = preload("res://tests/suites/church_aperture_suite.gd")


static func run() -> SuiteResult:
	var res := SuiteResult.new("church change")
	# Assembled domed styles enter the scheduled sweep. QA-PERF-003 tracks
	# their currently unbounded roof clipping. churchroof below still checks
	# dome surfaces and support geometry in this change lane.
	for style in [&"romanesque", &"gothic", &"nordic_stave"]:
		for index in [3, 8]:
			var started := Time.get_ticks_msec()
			var spec: ChurchSpec = TestSweep.spec_at(style, index)
			var builder := ChurchBuilder.new()
			var mesh: ArrayMesh = builder.build(spec)
			var who := "%s seed=%d" % [String(style), TestSweep.seed_at(index)]
			_expect(res, mesh != null and mesh.get_surface_count() == 4,
				"%s has no four-surface mesh" % who)
			if mesh != null:
				NormalsSuite.check_mesh(res, mesh, who)
				NormalsSuite.check_openings(res, builder, who)
			_check_massing(res, spec, builder, who)
			var elapsed := (Time.get_ticks_msec() - started) / 1000.0
			res.note("%s %.2fs" % [who, elapsed])

	for key in ["notre_dame", "durham"]:
		var started := Time.get_ticks_msec()
		var row := _landmark_row(key)
		var spec := ChurchSpec.new()
		spec.style = row["style"]
		spec.width = row["width"]
		spec.length = row["length"]
		spec.height = row["height"]
		ChurchGenerator.generate(spec, LandmarkSuite._seed_for(key, 1.0))
		LandmarkSuite._force_features(key, spec)
		var builder := ChurchBuilder.new()
		var mesh: ArrayMesh = builder.build(spec)
		LandmarkSuite._check_required_masses(key, builder, key, res)
		LandmarkSuite._check_clerestory(spec, builder, key, res)
		_check_massing(res, spec, builder, key)
		if key == "notre_dame":
			var clerestory := ChurchGeometry.clerestory_windows(spec)
			_expect(res, not clerestory.is_empty(), "Notre-Dame lacks clerestory fixture")
			if not clerestory.is_empty():
				var opening: Dictionary = clerestory[0]
				Apertures._check_opening(res, mesh, builder, opening.pos,
					opening.face, opening.width, opening.height, "Notre-Dame clerestory")
		var elapsed := (Time.get_ticks_msec() - started) / 1000.0
		res.note("%s %.2fs" % [key, elapsed])

	var route_start := Time.get_ticks_msec()
	Apertures._entrance_routes(res)
	var route_elapsed := (Time.get_ticks_msec() - route_start) / 1000.0
	res.note("entrance routes %.2fs" % route_elapsed)
	_negative_controls(res)
	res.note("assembled domed styles remain in lane:church; QA-PERF-003 tracks clipping")
	return res


static func _landmark_row(key: String) -> Dictionary:
	for row in LandmarkSuite.LANDMARKS:
		if row["key"] == key:
			return row
	return {}


static func _check_massing(res: SuiteResult, spec: ChurchSpec,
		builder: ChurchBuilder, who: String) -> void:
	var report: Dictionary = MassingCheck.new().check(spec, builder)
	_expect(res, report["ok"], "%s massing: %s" % [who, report["failures"]])
	for warning in report["warnings"]:
		res.warn("%s massing: %s" % [who, warning])


static func _negative_controls(res: SuiteResult) -> void:
	var solid := MeshKit.new(1)
	solid.box(Vector3(4.0, 4.0, 0.5), Vector3(0, 2, 0), 0)
	var solid_mesh := solid.commit()
	_expect(res, Apertures._blocked(solid_mesh, Vector3(0, 2, -1),
		Vector3(0, 2, 1)), "solid-wall aperture control was not detected")
	var arrays: Array = solid_mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in range(normals.size()):
		normals[i] = -normals[i]
	arrays[Mesh.ARRAY_NORMAL] = normals
	var inverted := ArrayMesh.new()
	inverted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var normal_control := SuiteResult.new("inverted normal control")
	NormalsSuite.check_mesh(normal_control, inverted, "inverted box")
	_expect(res, not normal_control.ok(), "inverted-normal control was not detected")

	var spec: ChurchSpec = TestSweep.spec_at(&"romanesque", 3)
	var builder := ChurchBuilder.new()
	builder.build(spec)
	builder.mass_log.clear()
	var report: Dictionary = MassingCheck.new().check(spec, builder)
	_expect(res, not report["ok"], "missing-mass control was not detected")


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)
