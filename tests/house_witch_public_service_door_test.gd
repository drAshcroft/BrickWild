extends SceneTree
## Public-API regression for the furnished Workshop/shared-Hall yard threshold.
## Measures the final plan, yard path, furniture clearance, and emitted wall mesh.

const FIXTURE := "res://tests/fixtures/witch_family_requests.json"
var failures: Array[String] = []

func _init() -> void:
	var file := FileAccess.open(FIXTURE, FileAccess.READ)
	if file == null:
		push_error("frozen Witch family request fixture is missing")
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("frozen Witch family request fixture is invalid")
		quit(1)
		return
	var cases: Array = parsed.get("cases", [])
	for row in cases:
		_check_public_case(row)
	for failure in failures:
		push_error(failure)
	print("Witch public service doors: %d cases, %d failures" % [cases.size(), failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _check_public_case(row: Dictionary) -> void:
	var id := String(row.get("id", "unknown"))
	var witch := String(row.get("role", "")) == "witch"
	var request := BuildingRequest.from_dict(Dictionary(row.get("request", {})))
	if not request._decode_errors.is_empty():
		failures.append("%s: request decode failed: %s" % [id, str(request._decode_errors)])
		return
	var pre_furnish := GeneratedBuilding.new()
	var family := BuildingFamilyAdapter.of(request.kind)
	if family == null or not family.generate_for_placement(request, pre_furnish) \
			or not pre_furnish.plan is HousePlan:
		failures.append("%s: pre-furnishing public-family plan failed: %s" % [id, str(pre_furnish.errors)])
		return
	var pre_markers := _service_marker_indices(pre_furnish.plan)
	var planned_doors := _door_rows(pre_furnish.plan)
	var planned_diagnostic := _threshold_diagnostic(pre_furnish.plan)
	HouseFurnisher.furnish(pre_furnish.plan, pre_furnish.spec)
	var furnished_markers := _service_marker_indices(pre_furnish.plan)
	var furnished_doors := _door_rows(pre_furnish.plan)
	HousePlanFeatures.compose_wall_hosts(pre_furnish.plan, pre_furnish.spec)
	HouseExterior.dress(pre_furnish.plan)
	var dressed_markers := _service_marker_indices(pre_furnish.plan)
	var dressed_doors := _door_rows(pre_furnish.plan)
	var building: GeneratedBuilding = BrickWild.generate(request)
	if not building.is_ok() or not building.plan is HousePlan:
		failures.append("%s: public API generation failed: %s" % [id, str(building.errors)])
		return
	var plan: HousePlan = building.plan
	var markers: Array[int] = []
	markers = _service_marker_indices(plan)
	print(JSON.stringify({"id": id, "planned_marker_count": pre_markers.size(),
		"after_furnish_marker_count": furnished_markers.size(),
		"after_shell_refresh_marker_count": dressed_markers.size(),
		"furnished_public_marker_count": markers.size(),
		"planned_doors": planned_doors, "planned_threshold_diagnostic": planned_diagnostic,
		"after_furnish_doors": furnished_doors, "after_shell_refresh_doors": dressed_doors,
		"furnished_public_doors": _door_rows(plan)}))
	if not witch:
		if not markers.is_empty():
			failures.append("%s: Cottage acquired a Witch service-door marker" % id)
		return
	if markers.size() != 1:
		failures.append("%s: furnished public plan has %d Workshop/shared-Hall yard doors; expected exactly one" % [id, markers.size()])
		return
	var door_index := markers[0]
	var door: Dictionary = plan.doors[door_index]
	var room := int(door.get("a", -1))
	if not bool(door.get("exterior", false)) or int(door.get("b", -1)) != -1 \
			or HousePlan.record_storey(door) != 0 or room < 0 or room >= plan.room_count():
		failures.append("%s: service marker is not a ground-floor exterior opening" % id)
		return
	var compact := bool(door.get("witch_compact_service_threshold", false))
	if compact:
		if plan.kind_of(room) != &"hall" or not bool(plan.rooms[room].get("shared_witchwork", false)):
			failures.append("%s: compact threshold is not hosted by the shared working Hall" % id)
	else:
		if plan.kind_of(room) != &"workshop":
			failures.append("%s: service threshold is not hosted by the real Workshop room" % id)
		if not HouseGeometry.witch_workshop_bay(plan).is_empty() and not bool(plan.rooms[room].get("witch_service_wing", false)):
			failures.append("%s: Workshop door host is outside the marked lower-roof service rooms" % id)
	var reached := HouseExterior.reached_doors(plan, true)
	if not reached.has(door_index):
		failures.append("%s: a human-sized yard route cannot reach the marked service door" % id)
	var nav := HouseNavCheck.new().check(plan)
	if not bool(nav.get("ok", false)):
		failures.append("%s: furnished interior navigation failed: %s" % [id, str(nav.get("failures", []))])
	for error in HouseYardCheck.clear(plan):
		failures.append("%s: %s" % [id, error])
	var builder := HouseBuilder.new()
	var mesh: ArrayMesh = builder.build(plan, true)
	if not _body_path_clear(mesh, door):
		failures.append("%s: body envelope intersects emitted doorway geometry" % id)
	# A real closed-wall mesh is the negative control for the same body predicate.
	var removed_door: Dictionary = plan.doors[door_index]
	plan.doors.remove_at(door_index)
	var plugged_mesh: ArrayMesh = HouseBuilder.new().build(plan, true)
	plan.doors.insert(door_index, removed_door)
	if _body_path_clear(plugged_mesh, door):
		failures.append("%s: body predicate failed to reject a doorway physically plugged by wall geometry" % id)


func _body_path_clear(mesh: ArrayMesh, door: Dictionary) -> bool:
	if mesh == null or mesh.get_surface_count() <= HouseBuilder.SURF_WALL:
		return false
	var triangles: Array = []
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			for i in range(0, vertices.size() - 2, 3):
				triangles.append([vertices[i], vertices[i + 1], vertices[i + 2]])
		else:
			for i in range(0, indices.size() - 2, 3):
				triangles.append([vertices[indices[i]], vertices[indices[i + 1]], vertices[indices[i + 2]]])
	var pos: Vector2 = door["pos"]
	var normal: Vector2 = door["normal"]
	var tangent := Vector2(-normal.y, normal.x)
	for height in [0.35, 0.62, 1.35, 1.70]:
		for lateral in [-0.28, 0.0, 0.28]:
			var centre: Vector2 = pos + tangent * float(lateral)
			var start := Vector3(centre.x + normal.x * 0.8, height, centre.y + normal.y * 0.8)
			var finish := Vector3(centre.x - normal.x * 0.12, height, centre.y - normal.y * 0.12)
			for triangle in triangles:
				if Geometry3D.segment_intersects_triangle(start, finish,
						triangle[0], triangle[1], triangle[2]) != null:
					return false
	return true


func _threshold_diagnostic(plan: HousePlan) -> Dictionary:
	var authored := _service_marker_indices(plan)
	if not authored.is_empty():
		var positions: Array[Vector2] = []
		for index in authored:
			positions.append(plan.doors[index]["pos"])
		return {"eligible_anchor": true, "authored_marker_count": authored.size(),
			"authored_positions": positions}
	var bay := HouseGeometry.witch_workshop_bay(plan)
	if bay.is_empty():
		bay = HouseGeometry.witch_compact_service_threshold(plan)
	if bay.is_empty():
		return {"eligible_anchor": false, "reason": "no supported Workshop/shared-Hall threshold descriptor"}
	var normal: Vector2 = bay.normal
	var lo := float(bay.get("service_lo", bay.get("lo", 0.0)))
	var hi := float(bay.get("service_hi", bay.get("hi", 0.0)))
	var along := float(bay.get("door_line_parameter", (lo + hi) * 0.5))
	var point := Vector2(float(bay.line), along) if absf(normal.x) > 0.5 else Vector2(along, float(bay.line))
	var candidate := {"pos": point, "normal": normal, "width": HouseGeometry.DOOR_W}
	var overlaps: Array[Dictionary] = []
	for door in plan.doors:
		if bool(door.get("witch_workshop_yard", false)) or not bool(door.get("exterior", false)):
			continue
		if HouseGeometry.door_opening_rect(plan.spec, door).grow(0.08).intersects(HouseGeometry.door_opening_rect(plan.spec, candidate)):
			overlaps.append({"a": int(door.get("a", -1)), "pos": door.get("pos", Vector2.ZERO),
			"front": bool(door.get("front", false)), "back": not bool(door.get("front", false))})
	return {"eligible_anchor": true, "room": int(bay.get("room", -1)),
		"compact": bool(bay.get("compact_shared_hall", false)), "normal": normal,
		"line": float(bay.line), "service_lo": lo, "service_hi": hi,
		"candidate_pos": point, "candidate_width": HouseGeometry.DOOR_W,
		"existing_exterior_overlap": overlaps}


func _service_marker_indices(plan: HousePlan) -> Array[int]:
	var out: Array[int] = []
	for index in plan.doors.size():
		if bool(plan.doors[index].get("witch_workshop_yard", false)):
			out.append(index)
	return out


func _door_rows(plan: HousePlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for door in plan.doors:
		out.append({"a": int(door.get("a", -1)), "b": int(door.get("b", -1)),
			"pos": door.get("pos", Vector2.ZERO), "normal": door.get("normal", Vector2.ZERO),
			"exterior": bool(door.get("exterior", false)),
			"workshop_yard": bool(door.get("witch_workshop_yard", false)),
			"compact_threshold": bool(door.get("witch_compact_service_threshold", false))})
	return out
