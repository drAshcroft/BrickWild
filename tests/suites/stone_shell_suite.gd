extends RefCounted
## INT-007: stone is a planning input, not a tint applied after planning.
## These checks shoot rays through emitted triangles. Solid door/floor mutants
## prove that preserving plan records alone cannot satisfy the shell contract.

static func run() -> SuiteResult:
	var res := SuiteResult.new("stone house shells")
	_material_geometry(res)
	_suppressed_timber(res)
	for levels in [1, 2, 3]:
		var plan := _plan(&"stone", levels)
		var mesh := HouseBuilder.new().build(plan)
		_doors(res, plan, mesh)
		_stairs(res, plan, mesh)
		_expect(res, _normal_errors(mesh) == 0,
			"stone %d storeys: emitted triangle normals/winding disagree" % levels)
	_negative_controls(res)
	_public_material(res)
	return res


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)


static func _plan(material: StringName, levels := 1) -> HousePlan:
	var spec := HouseSpec.new(25025)
	if material != &"":
		spec.material = material
	spec.width = 10.0
	spec.length = 12.0
	spec.height = 2.8
	spec.storeys = levels
	spec.room_count = 3
	spec.program = [&"hall", &"bedroom", &"kitchen"]
	spec.roof_pitch = 0.9
	spec.plinth_height = 0.45
	spec.exterior_props = false
	spec.bargeboards = false
	return HousePlanner.plan(spec)


static func _triangles(mesh: ArrayMesh, surface := -1) -> Array:
	var out: Array = []
	for s in mesh.get_surface_count():
		if surface >= 0 and surface != s:
			continue
		var arrays := mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0, count, 3):
			var tri: Array[Vector3] = []
			for j in 3:
				tri.append(vertices[indices[i + j] if not indices.is_empty() else i + j])
			out.append(tri)
	return out


static func _hits(triangles: Array, start: Vector3, end: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for tri in triangles:
		var hit: Variant = Geometry3D.segment_intersects_triangle(start, end,
			tri[0], tri[1], tri[2])
		if hit == null:
			continue
		var duplicate := false
		for previous in out:
			if previous.distance_to(hit) < 0.0001:
				duplicate = true
		if not duplicate:
			out.append(hit)
	return out


static func _material_geometry(res: SuiteResult) -> void:
	_expect(res, HouseSpec.new().material == &"timber", "default shell material changed")
	for material in [&"timber", &"stone"]:
		var plan := _plan(material)
		var builder := HouseBuilder.new()
		var mesh := builder.build(plan, false)
		var expected := 0.6 if material == &"stone" else 0.35
		_expect(res, is_equal_approx(HouseGeometry.wall_thickness(plan.spec), expected),
			"%s planning wall thickness is wrong" % material)
		var interior := HouseGeometry.interior_rect(plan.spec)
		_expect(res, interior.size.is_equal_approx(Vector2(10, 12) - Vector2.ONE * expected * 2),
			"%s clear floor was not reduced by both wall thicknesses" % material)
		# Near the wall head, above every door and window: both skin faces must
		# be present at the requested thickness, independently of mass_log.
		var hits := _hits(_triangles(mesh, HouseBuilder.SURF_WALL),
			Vector3(-5.5, 2.63, 0.317), Vector3(-3.9, 2.63, 0.317))
		_expect(res, hits.size() == 2, "%s wall must have two emitted skins; got %d" % [material, hits.size()])
		if hits.size() == 2:
			_expect(res, absf(hits[0].distance_to(hits[1]) - expected) < 0.001,
				"%s emitted wall thickness differs from clear-floor contract" % material)
		_expect(res, not plan.windows.is_empty() and HouseQA._check_opening_elevations(plan, builder).is_empty(),
			"%s real window trim failed the material-aware half-wall tolerance" % material)
		# A wider masonry tolerance must still reject a displaced emitter.
		for part in builder.part_log:
			if part.kind == "window":
				part.pos += Vector3(10, 0, 10)
		_expect(res, not HouseQA._check_opening_elevations(plan, builder).is_empty(),
			"%s opening check accepted trim displaced from every planned window" % material)


static func _same_geometry(a: ArrayMesh, b: ArrayMesh) -> bool:
	if a.get_surface_count() != b.get_surface_count():
		return false
	for s in a.get_surface_count():
		var aa := a.surface_get_arrays(s)
		var bb := b.surface_get_arrays(s)
		for field in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_INDEX]:
			if aa[field] != bb[field]:
				return false
	return true


static func _suppressed_timber(res: SuiteResult) -> void:
	for material in [&"stone", &"timber"]:
		var plan := _plan(material, 2)
		var builder := HouseBuilder.new()
		plan.spec.timber_frame = true
		plan.spec.frame_braces = true
		plan.spec.frame_rail = true
		plan.spec.stud_pitch = 0.7
		plan.spec.jetty = true
		var flags_on := builder.build(plan, false)
		var timber_parts := 0
		for part in builder.part_log:
			if part.get("tag", "") in ["timber", "jetty"]:
				timber_parts += 1
		plan.spec.timber_frame = false
		plan.spec.jetty = false
		var flags_off := builder.build(plan, false)
		if material == &"stone":
			_expect(res, timber_parts == 0, "stone emitted timber/jetty tagged parts")
			_expect(res, _same_geometry(flags_on, flags_off),
				"stone emitted extra geometry when forbidden timber/jetty flags were set")
		else:
			_expect(res, timber_parts > 0, "timber control no longer emits its frame/jetty")
			_expect(res, not _same_geometry(flags_on, flags_off),
				"frame suppression check cannot distinguish the timber control")
	# Explicit and implicit timber must produce exactly the same seed fixture.
	var implicit := _plan(&"")
	var explicit := _plan(&"timber")
	_expect(res, _same_geometry(HouseBuilder.new().build(implicit), HouseBuilder.new().build(explicit)),
		"default timber rebuild changed geometry")


static func _door_clear(triangles: Array, door: Dictionary, height: float) -> bool:
	var pos: Vector2 = door["pos"]
	var normal: Vector2 = door["normal"]
	var center := Vector3(pos.x, height, pos.y)
	var span := Vector3(normal.x, 0, normal.y) * 0.8
	return _hits(triangles, center - span, center + span).is_empty()


static func _doors(res: SuiteResult, plan: HousePlan, mesh: ArrayMesh) -> void:
	var triangles := _triangles(mesh)
	_expect(res, not plan.doors.is_empty(), "stone fixture contains no door control")
	for index in plan.doors.size():
		var door: Dictionary = plan.doors[index]
		for height in [0.25, 1.05, 1.80]:
			var y: float = height + float(door.get("storey", 0)) * plan.spec.height
			_expect(res, _door_clear(triangles, door, y),
				"stone %d storeys: door %d blocked at Y=%.2f" % [plan.spec.storeys, index, y])


static func _floor_hole_clear(triangles: Array, hole: Rect2, y: float) -> bool:
	for fx in [0.23, 0.51, 0.77]:
		for fz in [0.23, 0.51, 0.77]:
			var p := hole.position + hole.size * Vector2(fx, fz)
			# Stop above the upper stair tread. Only the floor slab occupies
			# this band; testing all the way down would hit the useful stairs.
			if not _hits(triangles, Vector3(p.x, y + HouseGeometry.FLOOR_T + 0.05, p.y),
					Vector3(p.x, y + 0.002, p.y)).is_empty():
				return false
	return true


static func _stairs(res: SuiteResult, plan: HousePlan, mesh: ArrayMesh) -> void:
	_expect(res, plan.stairs.size() == plan.spec.storeys - 1,
		"stone fixture is missing a planned stair transition")
	var triangles := _triangles(mesh, HouseBuilder.SURF_FLOOR)
	for index in plan.stairs.size():
		var stair: Dictionary = plan.stairs[index]
		var y := float(stair["to_storey"]) * plan.spec.height
		var hole: Rect2 = stair["upper_rect"]
		_expect(res, _floor_hole_clear(triangles, hole, y),
			"stone %d storeys: stair %d has an uncut upper floor" % [plan.spec.storeys, index])
		var p := Vector2(-3.8, 4.8)
		if hole.has_point(p):
			p = Vector2(3.8, -4.8)
		_expect(res, not _hits(triangles, Vector3(p.x, y + 0.3, p.y),
			Vector3(p.x, y - 0.03, p.y)).is_empty(),
			"stone stair cut removed the neighbouring floor")


static func _normal_errors(mesh: ArrayMesh) -> int:
	var errors := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0, count, 3):
			var ids: Array[int] = []
			for j in 3:
				ids.append(indices[i + j] if not indices.is_empty() else i + j)
			var n := (vertices[ids[2]] - vertices[ids[0]]).cross(vertices[ids[1]] - vertices[ids[0]])
			if not n.is_finite() or n.length_squared() < 0.0000000001:
				errors += 1
				continue
			n = n.normalized()
			for id in ids:
				if not normals[id].is_finite() or absf(normals[id].length() - 1.0) > 0.001 or n.dot(normals[id]) < 0.999:
					errors += 1
	return errors


static func _negative_controls(res: SuiteResult) -> void:
	var plan := _plan(&"stone", 2)
	var mesh := HouseBuilder.new().build(plan)
	var door: Dictionary = plan.doors[plan.entrance()]
	var pos: Vector2 = door["pos"]
	var bad_door := MeshKit.new(1)
	bad_door.box(Vector3(0.8, 2.0, 0.8), Vector3(pos.x, 1.0, pos.y), 0)
	var plugged := _triangles(mesh)
	plugged.append_array(_triangles(bad_door.commit()))
	_expect(res, not _door_clear(plugged, door, 1.05),
		"door mesh probe accepted a solid plug despite preserved plan opening")
	var hole: Rect2 = plan.stairs[0]["upper_rect"]
	var y := plan.spec.height
	var bad_floor := MeshKit.new(1)
	bad_floor.box(Vector3(hole.size.x, HouseGeometry.FLOOR_T, hole.size.y),
		Vector3(hole.get_center().x, y + HouseGeometry.FLOOR_T / 2, hole.get_center().y), 0)
	var filled := _triangles(mesh, HouseBuilder.SURF_FLOOR)
	filled.append_array(_triangles(bad_floor.commit()))
	_expect(res, not _floor_hole_clear(filled, hole, y),
		"stair mesh probe accepted a solid upper floor despite preserved plan stair")
	var normal_mutant := ArrayMesh.new()
	var arrays := mesh.surface_get_arrays(HouseBuilder.SURF_WALL)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	normals[0] = -normals[0]
	arrays[Mesh.ARRAY_NORMAL] = normals
	normal_mutant.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_expect(res, _normal_errors(normal_mutant) > 0, "normal probe accepted a flipped vertex normal")


static func _public_material(res: SuiteResult) -> void:
	var request := BuildingRequest.house(25025)
	_expect(res, request.material == &"timber", "public request default changed")
	request.material = &"stone"
	var copy := request.copy()
	request.material = &"timber"
	_expect(res, copy.material == &"stone", "request copy lost or aliased material")
	_expect(res, BuildingLibrary.validate(copy).is_empty(), "public API rejected stone")
	copy.material = &"paper"
	var rejected := BrickWild.generate(copy)
	var precise_error := false
	for error in rejected.errors:
		precise_error = precise_error or (error["code"] == &"invalid_material" and error["field"] == &"material")
	_expect(res, precise_error and rejected.spec == null,
		"unsupported material did not fail before generation with invalid_material/material")
	copy.material = &"stone"
	var doc := BrickWild.generate_document(copy)
	_expect(res, doc.is_ok(), "stone public document failed: %s" % str(doc.errors))
	if not doc.is_ok():
		return
	_expect(res, doc.plan.spec.material == &"stone", "public request material did not reach planning")
	var data: Dictionary = JSON.parse_string(JSON.stringify(doc.to_dict()))
	_expect(res, data["request"]["material"] == "stone" and data["spec"]["material"] == "stone",
		"document JSON lost request/spec material")
	copy.material = &"timber"
	_expect(res, doc.request.material == &"stone" and doc.plan.spec.material == &"stone",
		"caller request mutation changed generated material")
