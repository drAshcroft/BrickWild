extends RefCounted
## Bounded church geometry gate. The exhaustive style, seed and landmark
## sweeps remain in the named church suites and lane:church.

const Apertures = preload("res://tests/suites/church_aperture_suite.gd")
const Roofs = preload("res://src/church/church_roofs.gd")
const RoofSuite = preload("res://tests/suites/church_roof_suite.gd")


static func run() -> SuiteResult:
	var res := SuiteResult.new("church change")
	# The roof clipper is bounded for assembled domes, so the change lane
	# checks them alongside the simpler roof and tower forms.
	for style in [&"romanesque", &"gothic", &"nordic_stave",
			&"byzantine", &"renaissance", &"russian"]:
		for index in [3, 8]:
			var started := Time.get_ticks_msec()
			var spec: ChurchSpec = TestSweep.spec_at(style, index)
			var builder := ChurchBuilder.new()
			var mesh: ArrayMesh = builder.build(spec)
			var who := "%s seed=%d" % [String(style), TestSweep.seed_at(index)]
			_check_material_surfaces(res, mesh, style, who)
			if mesh != null:
				NormalsSuite.check_mesh(res, mesh, who)
				NormalsSuite.check_openings(res, builder, who)
			_check_massing(res, spec, builder, who)
			if style == &"byzantine" and index == 3:
				_expect(res, (mesh.surface_get_arrays(ChurchBuilder.SURF_ROOF)[Mesh.ARRAY_VERTEX]
					as PackedVector3Array).size() < 12000,
					"Byzantine roof clipping fragment count regressed")
				_dome_cut_control(res, spec, builder)
			var elapsed := (Time.get_ticks_msec() - started) / 1000.0
			res.note("%s %.2fs" % [who, elapsed])

	for key in ["notre_dame", "durham", "hagia_sophia", "florence_duomo", "st_basil"]:
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
		if spec.hero != &"":
			# the hero emitters (octagon, tribunes, bearing, arches, tent, onions)
			# face outward and their openings look out of their walls
			NormalsSuite.check_mesh(res, mesh, "%s hero" % key)
			NormalsSuite.check_openings(res, builder, "%s hero" % key)
		_check_massing(res, spec, builder, key)
		if key == "hagia_sophia":
			_expect(res, (mesh.surface_get_arrays(ChurchBuilder.SURF_ROOF)[Mesh.ARRAY_VERTEX]
				as PackedVector3Array).size() < 12000,
				"Hagia Sophia roof clipping fragment count regressed")
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
	return res


static func _check_material_surfaces(res: SuiteResult, mesh: ArrayMesh,
		style: StringName, who: String) -> void:
	_expect(res, mesh != null, "%s emitted no mesh" % who)
	if mesh == null:
		return
	var slots: Dictionary = {}
	for surface in range(mesh.get_surface_count()):
		var slot := surface
		var surface_name: String = mesh.surface_get_name(surface)
		if surface_name.begins_with("material_slot:"):
			slot = int(surface_name.trim_prefix("material_slot:"))
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		_expect(res, not slots.has(slot) and not vertices.is_empty(),
			"%s has a duplicate or empty material slot %d" % [who, slot])
		slots[slot] = true
	for slot in [ChurchBuilder.SURF_STONE, ChurchBuilder.SURF_TRIM,
			ChurchBuilder.SURF_ROOF, ChurchBuilder.SURF_OPEN]:
		_expect(res, slots.has(slot), "%s lacks required material slot %d" % [who, slot])
	if style == &"nordic_stave":
		_expect(res, slots.has(ChurchBuilder.SURF_WOOD), "%s lacks native timber geometry" % who)
	_expect(res, mesh.get_surface_count() <= BuildingLibrary.surface_count(&"church"),
		"%s exceeds the published material surface count" % who)


static func _dome_cut_control(res: SuiteResult, spec: ChurchSpec,
		builder: ChurchBuilder) -> void:
	var cut := MeshKit.new(4)
	var uncut := MeshKit.new(4)
	for surface in range(4):
		# SurfaceTool omits empty surfaces; place these fixtures far from the
		# sample to retain the church surface indexes.
		cut.box(Vector3.ONE, Vector3(-100, -100, -100), surface)
		uncut.box(Vector3.ONE, Vector3(-100, -100, -100), surface)
	Roofs.emit(spec, cut, builder.mass_log, builder._roof_volumes)
	Roofs.emit(spec, uncut, builder.mass_log, [])
	var x := -0.625 * spec.dome_radius * 1.5
	var z := ChurchGeometry.crossing_center_z(spec)
	var cut_roof := RoofSuite._triangles(cut.commit(), ChurchBuilder.SURF_ROOF)
	var uncut_roof := RoofSuite._triangles(uncut.commit(), ChurchBuilder.SURF_ROOF)
	var cut_hits := RoofSuite._heights(cut_roof, x, z, 0, 100)
	var uncut_hits := RoofSuite._heights(uncut_roof, x, z, 0, 100)
	_expect(res, cut_hits.is_empty(), "Byzantine half-dome has roof inside shell")
	_expect(res, uncut_hits.size() == 2,
		"missing-volume negative control did not expose the roof inside half-dome")


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
