extends RefCounted
## VIS-005: a dark face in front of a solid nave must not pass as an aperture.

static func run() -> SuiteResult:
	var res := SuiteResult.new("church apertures")
	for row in [["notre_dame", &"gothic", 12.0, 127.0, 33.0, 5001],
			["durham", &"romanesque", 11.9, 61.0, 22.2, 5005]]:
		var spec := ChurchSpec.new()
		spec.style = row[1]
		spec.width = row[2]
		spec.length = row[3]
		spec.height = row[4]
		ChurchGenerator.generate(spec, row[5])
		LandmarkSuite._force_features(row[0], spec)
		var builder := ChurchBuilder.new()
		var mesh: ArrayMesh = builder.build(spec)
		_expect(res, mesh.get_surface_count() == 4,
			"%s finish changed the four church surface slots" % row[0])
		var roles := PackedStringArray()
		for component in builder.component_log:
			roles.append(component["role"])
		if row[0] == "notre_dame":
			_expect(res, roles.has("clerestory_pane")
				and roles.has("clerestory_spandrel")
				and roles.has("clerestory_transom"),
				"Notre-Dame finish components are missing")
			var pane_colors: PackedColorArray = mesh.surface_get_arrays(
				ChurchBuilder.SURF_OPEN)[Mesh.ARRAY_COLOR]
			var marked := 0
			for color in pane_colors:
				if color.r < 0.5:
					marked += 1
			_expect(res, marked > 0, "clerestory panes lack glazing markers")
			var windows: Array[Dictionary] = ChurchGeometry.clerestory_windows(spec)
			_expect(res, windows.size() > 0, "Notre-Dame has no clerestory fixture")
			for opening in windows:
				_check_opening(res, mesh, builder, opening.pos, opening.face,
					opening.width, opening.height, "%s clerestory" % row[0])
		for opening in builder._west_door_openings():
			_check_opening(res, mesh, builder, opening.pos, PI,
				opening.width, opening.height,
				"%s west portal x=%.2f" % [row[0], opening.pos.x],
				spec.tower_width + 2.0 if spec.west_towers >= 2 else 0.45)
		_expect(res, roles.has("portal_jamb") and roles.has("portal_lintel"),
			"%s cut portal has no named moulding" % row[0])
	# These wider portals are empty at their logged centres. The coarse voxel
	# sweep used to call that a floating recess; direct rays verify the cut and
	# adjacent masonry at the five fixed seeds which exposed the mismatch.
	for case in [[&"gothic", 11], [&"renaissance", 1],
			[&"renaissance", 6], [&"renaissance", 8], [&"renaissance", 9]]:
		var spec: ChurchSpec = TestSweep.spec_at(case[0], case[1])
		var builder := ChurchBuilder.new()
		var mesh: ArrayMesh = builder.build(spec)
		for opening in builder._west_door_openings():
			_check_opening(res, mesh, builder, opening.pos, PI,
				opening.width, opening.height,
				"%s seed=%d west portal" % [String(case[0]), spec.seed],
				spec.tower_width + 2.0 if spec.west_towers >= 2 else 0.45)
	var solid := MeshKit.new(1, true)
	solid.box(Vector3(12.0, 20.0, 30.0), Vector3(0, 10.0, 0), 0)
	_expect(res, _blocked(solid.commit(), Vector3(6.5, 10, 0),
		Vector3(5.5, 10, 0)), "control solid wall did not block the probe")
	return res


static func _check_opening(res: SuiteResult, mesh: ArrayMesh,
		builder: ChurchBuilder, pos: Vector3, face: float, width: float,
		height: float, label: String, outer_run := 0.45) -> void:
	var matching := 0
	for part in builder.part_log:
		if part["kind"] != "window" or part.get("aperture", "") != "through":
			continue
		if (part["pos"] as Vector3).distance_to(pos) > 0.001:
			continue
		if absf(float(part["size"].x) - width) > 0.001 \
				or absf(float(part["size"].y) - height) > 0.001 \
				or absf(float(part["rot_y"]) - face) > 0.001:
			continue
		matching += 1
	_expect(res, matching == 1, "%s log differs from emitted aperture" % label)
	var basis := Basis(Vector3.UP, face)
	var outward: Vector3 = basis * Vector3.FORWARD * -1.0
	var along: Vector3 = basis * Vector3.RIGHT
	var clear_point: Vector3 = pos + along * (width * 0.22)
	var clear_hit: Dictionary = _first_hit(mesh, clear_point + outward * outer_run,
		clear_point - outward * 0.75)
	_expect(res, clear_hit.is_empty(), "%s is walled in by %s" % [label, clear_hit])
	var pier_point: Vector3 = pos + along * (width * 0.65)
	_expect(res, _blocked(mesh, pier_point + outward * outer_run,
		pier_point - outward * 0.75), "%s has no neighbouring pier" % label)
	var throat: Vector3 = pos - outward * (ChurchGeometry.OPENING_EPS
		+ ChurchBuilder.NAVE_WALL_T * 0.5)
	var jamb: Vector3 = throat + along * (width / 2.0)
	_expect(res, _blocked(mesh, jamb - along * 0.08,
		jamb + along * 0.08), "%s has no stone jamb return" % label)
	var head: Vector3 = throat + Vector3.UP * (height / 2.0)
	_expect(res, _blocked(mesh, head - Vector3.UP * 0.08,
		head + Vector3.UP * 0.08), "%s has no stone head return" % label)
	var sill: Vector3 = throat - Vector3.UP * (height / 2.0)
	_expect(res, _blocked(mesh, sill - Vector3.UP * 0.015,
		sill + Vector3.UP * 0.015), "%s has no stone sill/threshold" % label)


static func _blocked(mesh: ArrayMesh, a: Vector3, b: Vector3) -> bool:
	return not _first_hit(mesh, a, b).is_empty()


static func _first_hit(mesh: ArrayMesh, a: Vector3, b: Vector3) -> Dictionary:
	for surface in range(mesh.get_surface_count()):
		# A seated glass pane may cross the ray. Only masonry proves whether
		# the host was actually cut; a dark panel over solid stone still fails.
		if surface == ChurchBuilder.SURF_OPEN:
			continue
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
			if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count: int = indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0, count, 3):
			var p0: Vector3 = vertices[indices[i] if not indices.is_empty() else i]
			var p1: Vector3 = vertices[indices[i + 1] if not indices.is_empty() else i + 1]
			var p2: Vector3 = vertices[indices[i + 2] if not indices.is_empty() else i + 2]
			var hit = Geometry3D.segment_intersects_triangle(a, b, p0, p1, p2)
			if hit != null:
				return {"surface": surface, "at": hit, "triangle": [p0, p1, p2]}
	return {}


static func _expect(res: SuiteResult, good: bool, complaint: String) -> void:
	res.checked += 1
	if not good:
		res.fail(complaint)
