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
		for host in ["aisle", "transept", "tower", "crossing_tower", "narthex", "apse"]:
			_check_host_sample(res, mesh, builder, host, row[0])
		_expect(res, roles.has("portal_jamb") and roles.has("portal_lintel"),
			"%s cut portal has no named moulding" % row[0])
	var chapel_spec := ChurchSpec.new()
	chapel_spec.style = &"gothic"
	chapel_spec.width = 16.4
	chapel_spec.length = 130.0
	chapel_spec.height = 37.5
	ChurchGenerator.generate(chapel_spec, 5003)
	LandmarkSuite._force_features("chartres", chapel_spec)
	var chapel_builder := ChurchBuilder.new()
	var chapel_mesh: ArrayMesh = chapel_builder.build(chapel_spec)
	_expect(res, _check_host_sample(res, chapel_mesh, chapel_builder,
		"chapel", "chartres"), "Chartres has no through chapel window")
	for dome_case in [["hagia_sophia", &"byzantine", 31.0, 76.0, 40.0, 5006],
			["florence_duomo", &"renaissance", 17.0, 153.0, 45.0, 5007]]:
		var dome_spec := ChurchSpec.new()
		dome_spec.style = dome_case[1]
		dome_spec.width = dome_case[2]
		dome_spec.length = dome_case[3]
		dome_spec.height = dome_case[4]
		ChurchGenerator.generate(dome_spec, dome_case[5])
		LandmarkSuite._force_features(dome_case[0], dome_spec)
		var dome_builder := ChurchBuilder.new()
		var dome_mesh: ArrayMesh = dome_builder.build(dome_spec)
		_expect(res, _check_host_sample(res, dome_mesh, dome_builder,
			"dome", dome_case[0]), "%s has no through drum window" % dome_case[0])
	for towers in [0, 1]:
		var rose_spec := ChurchSpec.new()
		rose_spec.style = &"romanesque"
		rose_spec.width = 12.0
		rose_spec.length = 62.0
		rose_spec.height = 22.0
		ChurchGenerator.generate(rose_spec, 8110 + towers)
		rose_spec.rose_window = true
		rose_spec.aisles = 0
		rose_spec.tower = towers == 1
		rose_spec.west_towers = towers
		rose_spec.narthex = false
		if towers == 1:
			rose_spec.tower_width = 10.0
			rose_spec.tower_height = 32.0
		var rose_builder := ChurchBuilder.new()
		var rose_mesh: ArrayMesh = rose_builder.build(rose_spec)
		_check_rose(res, rose_mesh, rose_builder, "single tower" if towers == 1 else "nave")
		_expect(res, _check_host_sample(res, rose_mesh, rose_builder,
			"window", "aisle-free nave"), "aisle-free nave has no cut side window")
	var vestibule := ChurchSpec.new()
	vestibule.style = &"romanesque"
	vestibule.width = 12.0
	vestibule.length = 62.0
	vestibule.height = 22.0
	ChurchGenerator.generate(vestibule, 8120)
	vestibule.narthex = true
	vestibule.tower = false
	vestibule.west_towers = 0
	var vestibule_builder := ChurchBuilder.new()
	var vestibule_mesh: ArrayMesh = vestibule_builder.build(vestibule)
	_expect(res, _check_host_sample(res, vestibule_mesh, vestibule_builder,
		"narthex", "narthex"), "narthex has no cut exterior door")
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
	_entrance_routes(res)
	_floor_under_entrance(res)
	_windows_between_buttresses(res)
	return res


## Walk-QA, Abbey Ivo pin 1: a nave buttress standing across a side window,
## glass showing either side of it. Every style at three sizes, and a control
## that moves one window onto a buttress.
static func _windows_between_buttresses(res: SuiteResult) -> void:
	var swept := 0
	for style in TestSweep.styles():
		for i in [0, 7, 14]:
			var spec: ChurchSpec = TestSweep.spec_at(style, i)
			var builder := ChurchBuilder.new()
			builder.build(spec)
			var clashes := _bay_clashes(builder)
			_expect(res, clashes.is_empty(), "%s/%d: %s" % [String(style), i, ", ".join(clashes)])
			if clashes.is_empty() and builder.components("shaft_0").size() > 0:
				swept += 1
				if swept == 1:
					# the control: one window moved onto the first nave buttress
					var shaft: Dictionary = {}
					for row in builder.component_log:
						if String(row.role) == "shaft_0" and String(row.host).begins_with("nave_"):
							shaft = row
							break
					for part in builder.part_log:
						if part.get("kind") == "window" and part.get("tag") == "window" \
								and signf(Vector3(part.pos).x) == signf(MassBuilder.component_aabb(shaft).get_center().x):
							part.pos = Vector3(part.pos.x, part.pos.y, MassBuilder.component_aabb(shaft).get_center().z)
							break
					_expect(res, not _bay_clashes(builder).is_empty(),
						"control: a window moved onto a buttress was not caught")
	_expect(res, swept > 0, "no buttressed church in the sweep to test")


static func _bay_clashes(builder: ChurchBuilder) -> PackedStringArray:
	var out := PackedStringArray()
	for row in builder.component_log:
		if String(row.role) != "shaft_0" or not String(row.host).begins_with("nave_"):
			continue
		var b: AABB = MassBuilder.component_aabb(row)
		for part in builder.part_log:
			if part.get("kind") != "window" or part.get("tag") != "window":
				continue
			var pos: Vector3 = part.pos
			if signf(pos.x) != signf(b.get_center().x):
				continue
			var half: float = Vector3(part.size).x * 0.5
			if pos.z + half > b.position.z + 0.01 and pos.z - half < b.end.z - 0.01:
				out.append("%s stands across the window at z=%.2f" % [row.host, pos.z])
	return out


## A cut on the outer door is not an entrance if a tower, narthex back wall or
## nave front still spans the same passage. Trace the entire route.
static func _entrance_routes(res: SuiteResult) -> void:
	for mode in ["narthex", "tower", "both"]:
		var spec := ChurchSpec.new()
		spec.style = &"romanesque"
		spec.width = 12.0
		spec.length = 62.0
		spec.height = 22.0
		ChurchGenerator.generate(spec, 8120 if mode == "narthex" else 8111)
		spec.narthex = mode != "tower"
		spec.tower = mode != "narthex"
		spec.west_towers = 0 if mode == "narthex" else 1
		if spec.tower:
			spec.tower_width = 10.0
			spec.tower_height = 32.0
		var builder := ChurchBuilder.new()
		var mesh: ArrayMesh = builder.build(spec)
		var front: float = ChurchGeometry.narthex_aabb(spec).position.z \
			if mode == "narthex" else ChurchGeometry.tower_aabb(spec).position.z
		var end_z := -spec.length * 0.5 + 2.0
		var pier_x := 0.0
		var outer_logs := 0
		for opening in builder._west_door_openings():
			var x: float = opening.pos.x
			var y: float = opening.pos.y - opening.height * 0.10
			var start := Vector3(x, y, front - 1.0)
			var end := Vector3(x, y, end_z)
			_expect(res, _first_hit(mesh, start, end, true).is_empty(),
				"%s entrance route still hits stone at x=%.2f" % [mode, x])
			_expect(res, _first_hit(mesh, start, end).is_empty(),
				"%s entrance route is blocked by trim or another surface" % mode)
			# At the feet, too: a sill left across a doorway is a step up from
			# bare ground on both sides (walk-QA, Abbey Ivo pin 2).
			# Measured from the floor the church stands on, not from the hole,
			# or a hole cut short of the floor would pass its own test.
			var feet: float = ChurchGeometry.podium_height(spec) + 0.03
			_expect(res, _first_hit(mesh, Vector3(x, feet, front - 1.0), Vector3(x, feet, end_z)).is_empty(),
				"%s entrance route has a sill across it at x=%.2f" % [mode, x])
			var logged := false
			for part in builder.part_log:
				if part.get("kind") == "window" and part.get("tag") == "door" \
						and Vector3(part.pos).distance_to(opening.pos) < 0.001 \
						and part.get("aperture", "") == "through":
					logged = true
			_expect(res, logged, "%s inner/axial entrance has a false recess log" % mode)
			pier_x = maxf(pier_x, absf(x) + opening.width * 0.5 + 0.6)
		var pier_start := Vector3(pier_x, 1.4, front - 1.0)
		_expect(res, _blocked(mesh, pier_start,
			Vector3(pier_x, 1.4, end_z)),
			"%s entrance route removed its neighbouring pier" % mode)
		if spec.narthex:
			for part in builder.part_log:
				if part.get("kind") == "window" and part.get("tag") == "narthex":
					outer_logs += 1
					_expect(res, part.get("aperture", "") == "through" \
						and part.pos.y - part.size.y * 0.5 < 0.2,
						"%s narthex front door is raised or logged as a recess" % mode)
			_expect(res, outer_logs == builder._west_door_openings().size(),
				"%s narthex exterior and inner doors do not correspond" % mode)


## Something to STAND on, all the way in. The rays above are horizontal, so a
## church with no floor at all passed them: every room was a closed shell
## whose bottom faced DOWN at y=0, the walker stood on the ground 2 cm lower,
## and its capsule jammed on those undersides' edge in the doorway (WALK-QA,
## 6 Oct, Abbey Ivo pin 2). Straight down along each west leaf's route, from
## the west front to the nave, the nearest face must face UP at the floor
## datum. A floorless builder is the negative control.
static func _floor_under_entrance(res: SuiteResult) -> void:
	var floorless: GDScript = load("res://tests/fixtures/floorless_church_builder.gd")
	for row in [[&"romanesque", 1], [&"gothic", 2], [&"nordic_stave", 3], [&"byzantine", 1],
			[&"renaissance", 1], [&"russian", 3]]:
		var spec := ChurchSpec.new()
		spec.style = row[0]
		ChurchGenerator.generate(spec, row[1])
		var label := "%s %d" % [row[0], row[1]]
		var gaps: PackedStringArray = _floor_gaps(spec, ChurchBuilder.new())
		_expect(res, gaps.is_empty(), "%s has no floor to stand on under its entrance at %s"
			% [label, ", ".join(gaps.slice(0, 4))])
		if row[0] == &"romanesque":
			_expect(res, not _floor_gaps(spec, floorless.new()).is_empty(),
				"%s floor probe passed a floorless church: the probe is a tautology" % label)


## Route points with no upward face at the floor datum directly below them.
static func _floor_gaps(spec: ChurchSpec, builder: ChurchBuilder) -> PackedStringArray:
	var mesh: ArrayMesh = builder.build(spec)
	var datum: float = ChurchGeometry.podium_height(spec)
	# from the face the outer door is cut in: the narthex front, a single
	# tower's west face, or the nave's west wall (twin towers stand either side
	# of open air, which needs no floor)
	var west := -spec.length / 2.0
	if spec.narthex:
		west = ChurchGeometry.narthex_aabb(spec).position.z
	elif spec.tower and spec.west_towers == 1:
		west = ChurchGeometry.tower_aabb(spec).position.z
	var gaps := PackedStringArray()
	for leaf in ChurchGeometry.west_door_layout(spec):
		var x: float = leaf["x"]
		var z := west + 0.05
		while z < -spec.length / 2.0 + 2.0:
			var hit := _nearest_hit(mesh, Vector3(x, datum + 0.5, z), Vector3(x, datum - 0.1, z))
			if hit.is_empty() or hit["normal"].y < 0.7 or absf(hit["at"].y - datum) > 0.06:
				gaps.append("(%.2f, %.2f)" % [x, z])
			z += 0.25
	return gaps


## The hit nearest `a` on segment a-b, with its face's outward normal (Godot
## winds front faces clockwise: (c - a) x (b - a)).
static func _nearest_hit(mesh: ArrayMesh, a: Vector3, b: Vector3) -> Dictionary:
	var best := {}
	var best_d := INF
	for surface in range(mesh.get_surface_count()):
		if surface == ChurchBuilder.SURF_OPEN:
			continue
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] 			if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count: int = indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0, count, 3):
			var p0: Vector3 = vertices[indices[i] if not indices.is_empty() else i]
			var p1: Vector3 = vertices[indices[i + 1] if not indices.is_empty() else i + 1]
			var p2: Vector3 = vertices[indices[i + 2] if not indices.is_empty() else i + 2]
			var hit = Geometry3D.segment_intersects_triangle(a, b, p0, p1, p2)
			if hit == null or a.distance_to(hit) >= best_d:
				continue
			var n := (p2 - p0).cross(p1 - p0)
			if n.length() < 1e-9:
				continue
			best_d = a.distance_to(hit)
			best = {"at": hit, "normal": n.normalized()}
	return best


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


static func _check_host_sample(res: SuiteResult, mesh: ArrayMesh,
		builder: ChurchBuilder, host: String, label: String) -> bool:
	for part in builder.part_log:
		if part.get("kind") != "window" or part.get("tag", "") != host \
				or part.get("aperture", "") != "through":
			continue
		_check_opening(res, mesh, builder, part.pos, part.rot_y,
			part.size.x, part.size.y, "%s %s" % [label, host])
		return true
	return false


static func _check_rose(res: SuiteResult, mesh: ArrayMesh,
		builder: ChurchBuilder, label: String) -> void:
	var ring_count := 0
	for component in builder.component_log:
		if component.get("host", "") == "west_rose" \
				and component.get("role", "") == "rose_ring":
			ring_count += 1
	_expect(res, ring_count == 12,
		"%s rose lacks its emitted stone surround" % label)
	for part in builder.part_log:
		if part.get("kind") != "window" or part.get("tag", "") != "facade":
			continue
		var pos: Vector3 = part.pos
		var outward: Vector3 = part.facing.normalized()
		var along := Vector3(outward.z, 0, -outward.x)
		var radius: float = part.size.x * 0.5
		var clear: Vector3 = pos + along * radius * 0.18 + Vector3.UP * radius * 0.10
		_expect(res, part.get("aperture", "") == "through",
			"%s rose is not logged as through" % label)
		_expect(res, _first_hit(mesh, clear + outward * 0.5,
			clear - outward * 0.8, true).is_empty(),
			"%s rose still has masonry behind the tracery" % label)
		var pier: Vector3 = pos + along * radius * 1.18
		_expect(res, not _first_hit(mesh, pier + outward * 0.5,
			pier - outward * 0.8, true).is_empty(),
			"%s rose lost adjacent masonry" % label)
		return
	_expect(res, false, "%s rose has no facade log" % label)


static func _blocked(mesh: ArrayMesh, a: Vector3, b: Vector3) -> bool:
	return not _first_hit(mesh, a, b).is_empty()


static func _first_hit(mesh: ArrayMesh, a: Vector3, b: Vector3,
		wall_only := false) -> Dictionary:
	for surface in range(mesh.get_surface_count()):
		var slot := surface
		var surface_name := mesh.surface_get_name(surface)
		if surface_name.begins_with("material_slot:"):
			slot = int(surface_name.trim_prefix("material_slot:"))
		# Glass does not prove a wall cut. For wall-only probes, both masonry
		# and the Nordic stave surface are structural wall material.
		if slot == ChurchBuilder.SURF_OPEN \
				or (wall_only and slot not in [ChurchBuilder.SURF_STONE,
					ChurchBuilder.SURF_WOOD]):
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
