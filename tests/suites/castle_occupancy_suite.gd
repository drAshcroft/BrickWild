extends RefCounted
## The README castle and destructive controls share the production checker.
const Occupancy = preload("res://qa/castle_occupancy_check.gd")


static func run() -> SuiteResult:
	var result := SuiteResult.new("castle occupied structures")
	var spec := CastleSpec.new()
	spec.style = &"norman"
	spec.width = 45.0
	spec.length = 55.0
	spec.height = 6.0
	spec.plan_override = &"motte_bailey"
	CastleGenerator.generate(spec, 8856)
	var builder := CastleBuilder.new()
	var mesh := builder.build(spec)
	check_fixture(result, spec, builder, mesh)
	return result


static func check_fixture(result: SuiteResult, spec: CastleSpec,
		builder: CastleBuilder, mesh: ArrayMesh) -> void:
	_inventory_contract(result)
	var geometry := Occupancy.prepare_mesh(mesh)
	var clean := Occupancy.check(spec, builder, mesh, geometry)
	_expect(result, clean.ok, "README motte: " + str(clean.failures))
	_expect(result, int(clean.stats.required_buildings) >= 9,
		"README inventory omitted the keep, hall, chapel or six defensive towers")
	_expect(result, int(clean.stats.exterior_doors) >= int(clean.stats.required_buildings),
		"README occupied structures do not all have entrances")
	result.note("README seed 8856 occupancy: " + str(clean.stats))
	var hall_index := -1
	for index in builder.interiors.size():
		if String(builder.interiors[index].id) == "hall":
			hall_index = index
	_expect(result, hall_index >= 0, "README fixture has no hall to mutate")
	if hall_index < 0:
		return
	var hall: Dictionary = builder.interiors[hall_index]
	var plan: HousePlan = hall.plan
	# Removing the entire record used to remove its checks too.
	builder.interiors.remove_at(hall_index)
	var missing := Occupancy.check(spec, builder, mesh, geometry)
	_expect(result, _contains(missing.failures, "occupied_shells[hall]: required occupied building"),
		"whole-building removal escaped required occupancy inventory")
	builder.interiors.insert(hall_index, hall)
	var doors := plan.doors.duplicate(true)
	plan.doors.clear()
	var doorless := Occupancy.check(spec, builder, mesh, geometry)
	_expect(result, _contains(doorless.failures, "occupied_shells[hall]: occupied building has no exterior entrance"),
		"doorless hall escaped occupancy QA")
	plan.doors.assign(doors)
	var rooms := plan.rooms.duplicate(true)
	plan.rooms.clear()
	var roomless := Occupancy.check(spec, builder, mesh, geometry)
	_expect(result, _contains(roomless.failures, "occupied_shells[hall]: occupied building has no rooms"),
		"rooms removed beneath retained windows escaped occupancy QA")
	plan.rooms.assign(rooms)
	var entrance := plan.entrance()
	if entrance >= 0:
		var door: Dictionary = plan.doors[entrance]
		var pose := Occupancy._pose(plan, hall.transform, door, int(door.a), true)
		var kit := MeshKit.new(1)
		var normal: Vector3 = pose.facing
		kit.oriented_box(Vector3(float(pose.width), float(pose.height), 0.15),
			Transform3D(Basis(Vector3.UP, atan2(normal.x, normal.z)), pose.pos), 0)
		var panel := kit.commit()
		var sealed := mesh.duplicate() as ArrayMesh
		sealed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, panel.surface_get_arrays(0))
		var blocked := Occupancy.check(spec, builder, sealed)
		_expect(result, _contains(blocked.failures, "occupied_shells[hall]: final mesh blocks exterior door"),
			"sealed emitted doorway escaped while plan and logs stayed intact")
	var window_index := -1
	for index in builder.part_log.size():
		if String(builder.part_log[index].get("tag", "")) == "hall" \
				and String(builder.part_log[index].get("kind", "")) == "window":
			window_index = index
			break
	_expect(result, window_index >= 0, "README hall has no emitted window to mutate")
	if window_index >= 0:
		var original: Dictionary = builder.part_log[window_index].duplicate(true)
		builder.part_log[window_index].facing = -Vector3(original.facing)
		var backwards := Occupancy.check(spec, builder, mesh, geometry)
		_expect(result, _contains(backwards.failures, "faces no matching occupied room"),
			"window facing away from its room escaped occupancy QA")
		builder.part_log[window_index] = original
		var orphan: Dictionary = original.duplicate(true)
		orphan.pos += Vector3.UP * (plan.spec.height * 2.0)
		builder.part_log.append(orphan)
		var no_room := Occupancy.check(spec, builder, mesh, geometry)
		_expect(result, _contains(no_room.failures, "faces no matching occupied room"),
			"extra window above every room escaped occupancy QA")
		builder.part_log.pop_back()
	var floorless := _without_floor(mesh, hall, 0)
	_expect(result, int(floorless.removed) > 0, "floor-removal control removed no emitted triangles")
	var missing_floor := Occupancy.check(spec, builder, floorless.mesh)
	_expect(result, _contains(missing_floor.failures, "occupied_shells[hall]: room 0 has no emitted floor"),
		"missing emitted room floor escaped the room check")
	_expect(result, _contains(missing_floor.failures, "occupied_shells[hall]: window") \
			and _contains(missing_floor.failures, "no emitted floor-backed occupied volume"),
		"missing emitted room floor escaped while plan and window logs stayed intact")
	# A stair landing is a floor patch, not a room. Keep one under the stripped
	# hall, logs untouched: the check must still fail the room.
	var landed := _with_landing(floorless.mesh, hall, 0)
	var landing_check := Occupancy.check(spec, builder, landed)
	_expect(result, _contains(landing_check.failures, "occupied_shells[hall]: room 0 has no emitted floor"),
		"one surviving stair landing passed a room whose floor was removed")
	_expect(result, float(landing_check.stats.get("min_room_floor_fraction", 1.0)) < 0.5,
		"landing mutation reports a majority-supported floor")
	_expect(result, float(clean.stats.get("min_room_floor_fraction", 0.0)) >= Occupancy.ROOM_FLOOR_MIN_FRACTION,
		"clean README motte reports a room below the floor fraction")
	_expect(result, Occupancy.check(spec, builder, mesh, geometry).failures == clean.failures,
		"occupancy controls retained stale failures after restoration")
	_sanctuary_contract(result, spec, builder, mesh)


static func _inventory_contract(result: SuiteResult) -> void:
	var house := CastleSweep.spec_at(&"norman", &"house", 1)
	house.wings = 1
	var manor := CastleSweep.spec_at(&"edwardian", &"manor", 1)
	manor.wings = 2
	manor.courtyard = true
	manor.corner_towers = true
	var enclosed := CastleSweep.spec_at(&"crusader", &"castle", 1)
	enclosed.chapel = true
	enclosed.corner_towers = true
	var ridge := CastleSpec.new()
	ridge.style = &"bavarian"
	ridge.width = 120.0
	ridge.length = 40.0
	ridge.height = 20.0
	ridge.plan_override = &"ridge"
	CastleGenerator.generate(ridge, 8805)
	var tower := CastleSpec.new()
	tower.style = &"norman"
	tower.width = 14.0
	tower.length = 12.0
	tower.height = 34.0
	tower.plan_override = &"tower_house"
	CastleGenerator.generate(tower, 8804)
	var sky := CastleSpec.new()
	sky.style = &"sky"
	sky.width = 80.0
	sky.length = 110.0
	sky.height = 14.0
	sky.tier_override = &"castle"
	CastleGenerator.generate(sky, 12012)
	for case in [
			{"spec": house, "ids": ["hall", "annexe"]},
			{"spec": manor, "ids": ["hall", "wing_left", "wing_right", "range_front", "tower_manor_0"]},
			{"spec": enclosed, "ids": ["keep", "hall", "chapel", "apse", "gate_0", "tower_0_corner_0"]},
			{"spec": ridge, "ids": ["hall", "tower_0_corner_0"]},
			{"spec": tower, "ids": ["tower_house"]},
			{"spec": sky, "ids": ["sky_tower_0"]}]:
		var empty := Occupancy.check(case.spec, CastleBuilder.new(), ArrayMesh.new())
		for id in case.ids:
			_expect(result, _contains(empty.failures,
				"occupied_shells[%s]: required occupied building has no interior record" % id),
				"%s missing %s escaped specification inventory" % [case.spec.plan_kind, id])


static func _sanctuary_contract(result: SuiteResult, spec: CastleSpec,
		builder: CastleBuilder, mesh: ArrayMesh) -> void:
	var row := {}
	for candidate in builder.interiors:
		if String(candidate.id) == "apse":
			row = candidate
	_expect(result, not row.is_empty(), "README chapel has no occupied sanctuary")
	if row.is_empty():
		return
	var plan: HousePlan = row.plan
	_expect(result, plan.kind_of(0) == &"sanctuary", "apse programme must name a sanctuary")
	var clean := HouseQA.new().check(plan, null)
	_expect(result, clean.ok, "sanctuary programme: " + str(clean.failures))
	var furniture := plan.furniture.duplicate(true)
	var tables := plan.furniture.filter(func(item: Dictionary) -> bool:
		return PropCatalog.category(String(item.key)) == "table").size()
	_expect(result, tables == 1, "sanctuary needs exactly one altar table")
	plan.furniture = plan.furniture.filter(func(item: Dictionary) -> bool:
		return PropCatalog.category(String(item.key)) != "table")
	var no_altar := HouseFurnishCheck.new().check(plan)
	_expect(result, _contains(no_altar.failures, "has no table"),
		"sanctuary with its altar removed escaped the furnishing programme")
	plan.furniture.assign(furniture)
	var windows := plan.windows.duplicate(true)
	plan.windows.clear()
	var dark := HousePlanCheck.new().check(plan)
	_expect(result, _contains(dark.failures, "daylight"),
		"sanctuary with all daylight removed escaped the room programme")
	plan.windows.assign(windows)
	var stripped := _without_floor(mesh, row, 0)
	var floorless := Occupancy.check(spec, builder, stripped.mesh)
	_expect(result, int(stripped.removed) > 0 \
			and _contains(floorless.failures, "occupied_shells[apse]: room 0 has no emitted floor"),
		"sanctuary floor removal escaped the emitted-room check")


static func _with_landing(mesh: ArrayMesh, row: Dictionary, room: int) -> ArrayMesh:
	var plan: HousePlan = row.plan
	var polygon := HouseGeometry.room_floor_poly(plan, room)
	var rect := Poly.bounding_rect(polygon)
	var point := rect.get_center()
	for step in 5:
		var probe := rect.position + rect.size * Vector2(0.5, 0.2 + 0.15 * step)
		if Poly.contains_point(polygon, point, 0.5):
			break
		point = probe
	var floor_y := float(plan.storey_of_room(room)) * plan.spec.height
	var kit := MeshKit.new(1)
	var xf: Transform3D = row.transform
	kit.oriented_box(Vector3(1.2, HouseGeometry.FLOOR_T, 1.2),
		Transform3D(xf.basis, xf * Vector3(point.x, floor_y + HouseGeometry.FLOOR_T * 0.5, point.y)), 0)
	var patch := kit.commit()
	var output := mesh.duplicate() as ArrayMesh
	output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, patch.surface_get_arrays(0))
	return output


static func _without_floor(mesh: ArrayMesh, row: Dictionary, room: int) -> Dictionary:
	var plan: HousePlan = row.plan
	var inverse: Transform3D = Transform3D(row.transform).affine_inverse()
	var rect := Poly.bounding_rect(HouseGeometry.room_floor_poly(plan, room)).grow(
		HouseGeometry.wall_thickness(plan.spec) + 0.05)
	var floor_y := float(plan.storey_of_room(room)) * plan.spec.height
	var output := ArrayMesh.new()
	var removed := 0
	for surface in mesh.get_surface_count():
		var source: Array = mesh.surface_get_arrays(surface)
		var source_vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX] if source[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else source_vertices.size()
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		for start in range(0, count, 3):
			var erase := true
			for offset in 3:
				var index: int = indices[start + offset] if not indices.is_empty() else start + offset
				var point: Vector3 = inverse * source_vertices[index]
				if point.y < floor_y - 0.001 or point.y > floor_y + HouseGeometry.FLOOR_T + 0.001 \
						or not rect.has_point(Vector2(point.x, point.z)):
					erase = false
			if erase:
				removed += 1
				continue
			for offset in 3:
				var index: int = indices[start + offset] if not indices.is_empty() else start + offset
				vertices.append(source_vertices[index])
				normals.append(source_normals[index])
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return {"mesh": output, "removed": removed}


static func _contains(failures: Array, text: String) -> bool:
	for failure in failures:
		if String(failure).contains(text):
			return true
	return false


static func _expect(result: SuiteResult, ok: bool, message: String) -> void:
	result.checked += 1
	if not ok:
		result.fail(message)
