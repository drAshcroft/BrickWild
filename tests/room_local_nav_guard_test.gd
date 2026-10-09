extends SceneTree
## Causal room-end pruning fixture on a public Cottage shell.
## The shell is public; furnishings are controlled measured plan records so the
## tests do not depend on random recipe outcomes or fragile generated groups.

var failures: Array[String] = []


func _init() -> void:
	_check_inherited_failure_preserves_bedroom_storage()
	_check_new_room_failure_is_repaired()
	_check_two_object_plateau_is_repaired()
	_check_three_removal_report_is_fresh()
	for failure in failures:
		push_error(failure)
	print("Room-local Nav pruning guard: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _public_cottage_shell() -> HousePlan:
	var request: BuildingRequest = BrickWild.default_request(&"house", 8102)
	request.style = &"cottage"
	var building: GeneratedBuilding = BrickWild.generate(request)
	if not building.is_ok():
		failures.append("public Cottage 8102 shell failed: %s" % str(building.errors))
		return null
	var plan: HousePlan = building.plan
	plan.furniture.clear()
	return plan


func _controlled_meal_pair(plan: HousePlan, include_third_seat := false) -> Dictionary:
	var table_key: String = "Table_Large"
	var table_size: Vector2 = PropCatalog.footprint_rotated(table_key, 0.0)
	for room in range(plan.room_count()):
		if _bedroom_after(plan, room) < 0:
			continue
		var floor: Rect2 = HouseGeometry.room_floor_rect(plan, room)
		if floor.size.x < table_size.x or floor.size.y < table_size.y:
			continue
		var table_center: Vector2 = floor.get_center()
		var table: Dictionary = HouseFurnishGeometry.candidate(table_key, table_center, 0.0)
		var table_rect: Rect2 = Rect2(table["rect"])
		var left_yaw: float = -PI * 0.5
		var right_yaw: float = PI * 0.5
		var left_size: Vector2 = PropCatalog.footprint_rotated("Chair_1", left_yaw)
		var right_size: Vector2 = PropCatalog.footprint_rotated("Chair_1", right_yaw)
		var left_center: Vector2 = Vector2(table_rect.position.x - left_size.x * 0.5,
			table_rect.get_center().y)
		var right_center: Vector2 = Vector2(table_rect.end.x + right_size.x * 0.5,
			table_rect.get_center().y)
		var left: Dictionary = HouseFurnishGeometry.candidate("Chair_1", left_center, left_yaw)
		var right: Dictionary = HouseFurnishGeometry.candidate("Chair_1", right_center, right_yaw)
		var end_yaw := 0.0
		var end_size: Vector2 = PropCatalog.footprint_rotated("Chair_1", end_yaw)
		var end_center := Vector2(table_rect.get_center().x,
			table_rect.end.y + end_size.y * 0.5)
		var end_seat: Dictionary = HouseFurnishGeometry.candidate("Chair_1", end_center, end_yaw)
		if include_third_seat:
			# Shift only the three-seat diagnostic arrangement within this real floor.
			# Derive the required offset from the measured third blocker use-zone.
			var initial_end_zone: Rect2 = Rect2(end_seat["zone"])
			var blocker_footprint: Vector2 = PropCatalog.footprint_rotated("Chair_1", end_yaw)
			var blocker_scale: float = maxf(initial_end_zone.size.x / blocker_footprint.x,
				initial_end_zone.size.y / blocker_footprint.y)
			var blocker_body_size: Vector2 = blocker_footprint * blocker_scale
			var blocker_center: Vector2 = initial_end_zone.get_center() \
				+ (blocker_body_size - initial_end_zone.size) * 0.5
			var blocker_probe: Dictionary = HouseFurnishGeometry.candidate("Chair_1",
				blocker_center, end_yaw, 1.0, blocker_scale)
			var blocker_zone: Rect2 = Rect2(blocker_probe.get("zone", Rect2()))
			var shift_y: float = minf(0.0, floor.end.y - blocker_zone.end.y - 0.05)
			if absf(shift_y) > 0.000001:
				for piece in [table, left, right, end_seat]:
					var moved_body: Rect2 = Rect2(piece["rect"])
					moved_body.position.y += shift_y
					piece["rect"] = moved_body
					var moved_zone: Rect2 = Rect2(piece.get("zone", Rect2()))
					moved_zone.position.y += shift_y
					piece["zone"] = moved_zone
					var moved_pos: Vector3 = Vector3(piece.get("pos", Vector3.ZERO))
					moved_pos.z += shift_y
					piece["pos"] = moved_pos
		table_rect = Rect2(table["rect"])
		var left_rect: Rect2 = Rect2(left["rect"])
		var right_rect: Rect2 = Rect2(right["rect"])
		var end_rect: Rect2 = Rect2(end_seat["rect"])
		var left_zone: Rect2 = Rect2(left["zone"])
		var right_zone: Rect2 = Rect2(right["zone"])
		var end_zone: Rect2 = Rect2(end_seat["zone"])
		if not floor.encloses(table_rect) or not floor.encloses(left_rect) \
				or not floor.encloses(right_rect) or not floor.encloses(left_zone) \
				or not floor.encloses(right_zone) \
				or (include_third_seat and (not floor.encloses(end_rect) or not floor.encloses(end_zone))):
			continue
		if _material_overlap(left_rect, table_rect) or _material_overlap(right_rect, table_rect) \
				or _material_overlap(left_rect, right_rect) \
				or _material_overlap(left_zone, table_rect) \
				or _material_overlap(right_zone, table_rect) \
				or _material_overlap(left_zone, right_zone) \
				or (include_third_seat and (_material_overlap(end_rect, table_rect) \
					or _material_overlap(end_rect, left_rect) or _material_overlap(end_rect, right_rect) \
					or _material_overlap(end_zone, table_rect) \
					or _material_overlap(end_zone, left_rect) or _material_overlap(end_zone, right_rect) \
					or _material_overlap(end_zone, left_zone) or _material_overlap(end_zone, right_zone) \
					or _material_overlap(end_rect, left_zone) or _material_overlap(end_rect, right_zone))):
			continue
		var table_index: int = plan.furniture.size()
		table["room"] = room
		table["host"] = -1
		table["must"] = true
		table["fixture_role"] = "fixture_meal_table"
		left["room"] = room
		left["host"] = table_index
		left["must"] = true
		left["fixture_role"] = "fixture_left_hosted_seat"
		right["room"] = room
		right["host"] = table_index
		right["must"] = true
		right["fixture_role"] = "fixture_right_hosted_seat"
		end_seat["room"] = room
		end_seat["host"] = table_index
		end_seat["must"] = true
		end_seat["fixture_role"] = "fixture_end_hosted_seat"
		plan.furniture.append(table)
		var left_index: int = plan.furniture.size()
		plan.furniture.append(left)
		var right_index: int = plan.furniture.size()
		plan.furniture.append(right)
		var end_index := -1
		if include_third_seat:
			end_index = plan.furniture.size()
			plan.furniture.append(end_seat)
		var nav: Dictionary = HouseNavCheck.new().check(plan)
		if not bool(nav.get("ok", false)):
			plan.furniture.clear()
			continue
		return {"room": room, "table": table_index,
			"left": left_index, "right": right_index, "end": end_index}
		
	failures.append("public Cottage shell has no measured room for a navigable Table_Large with opposite hosted chairs")
	return {}


func _bedroom_after(plan: HousePlan, meal_room: int) -> int:
	for room in range(meal_room + 1, plan.room_count()):
		if plan.kind_of(room) == &"bedroom":
			return room
	return -1


func _measured_wall_cabinet(plan: HousePlan, room: int) -> Dictionary:
	var floor: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var blocked: Array[Rect2] = HouseFurnishPlacement.initial_blocked(plan, room)
	for wall: Dictionary in HouseGeometry.room_walls(plan, room):
		var a: Vector2 = wall["from"]
		var b: Vector2 = wall["to"]
		var normal: Vector2 = wall["normal"]
		var along: Vector2 = (b - a).normalized()
		var run: float = a.distance_to(b)
		var yaw: float = HouseFurnishGeometry.yaw_facing(normal)
		var footprint: Vector2 = PropCatalog.footprint_rotated("Cabinet", yaw)
		var span: float = absf(along.x) * footprint.x + absf(along.y) * footprint.y
		var depth: float = absf(normal.x) * footprint.x + absf(normal.y) * footprint.y
		if run < span:
			continue
		var step: float = 0.10
		var distance: float = span * 0.5
		while distance <= run - span * 0.5 + 0.0001:
			var center: Vector2 = a + along * distance + normal * (depth * 0.5 + HouseGeometry.WALL_GAP)
			var cabinet: Dictionary = HouseFurnishGeometry.candidate("Cabinet", center, yaw)
			if HouseFurnishGeometry.fits(plan, room, cabinet, floor, blocked, [], []):
				cabinet["room"] = room
				cabinet["host"] = -1
				cabinet["must"] = false
				cabinet["fixture_role"] = "fixture_later_bedroom_storage"
				return cabinet
			distance += step
	return {}


func _build_case_shell() -> Dictionary:
	var plan: HousePlan = _public_cottage_shell()
	if plan == null:
		return {}
	var pair: Dictionary = _controlled_meal_pair(plan)
	if pair.is_empty():
		return {}
	var bedroom: int = _bedroom_after(plan, int(pair["room"]))
	if bedroom < 0:
		failures.append("public Cottage 8102 has no later bedroom in the selected shell")
		return {}
	var cabinet: Dictionary = _measured_wall_cabinet(plan, bedroom)
	if cabinet.is_empty():
		failures.append("no measured Cabinet fits a real bedroom wall with its door/use zone clear")
		return {}
	plan.furniture.append(cabinet)
	var clean: Dictionary = HouseNavCheck.new().check(plan)
	if not bool(clean.get("ok", false)):
		failures.append("controlled public shell/table/chairs/bedroom Cabinet is not Nav-clean: %s" % str(clean.get("failures", [])))
		return {}
	pair["bedroom"] = bedroom
	pair["cabinet"] = plan.furniture.size() - 1
	pair["clean_report"] = clean
	return {"plan": plan, "case": pair}


func _check_inherited_failure_preserves_bedroom_storage() -> void:
	var fixture: Dictionary = _build_case_shell()
	if fixture.is_empty():
		return
	var plan: HousePlan = fixture["plan"]
	var setup: Dictionary = fixture["case"]
	var target_index: int = int(setup["left"])
	var room: int = int(setup["room"])
	var blocker: Dictionary = _measured_full_zone_blocker(plan, target_index,
		"fixture_prior_room_hosted_use_blocker")
	if blocker.is_empty():
		failures.append("could not place a measured body covering the complete hosted seat zone")
		return
	plan.furniture.append(blocker)
	var before_room: Dictionary = HouseNavCheck.new().check(plan)
	if not _chair_failure_for_item(before_room, target_index, room):
		failures.append("prior-room blocker did not produce the intended hosted Chair_1 failure")
		return
	var cabinet_record: Dictionary = plan.furniture[int(setup["cabinet"])].duplicate(true)
	var bedroom: int = int(setup["bedroom"])
	var returned: Dictionary = HouseFurnisher._keep_the_room_passable(plan, bedroom,
		HouseFurnishPlacement.initial_blocked(plan, bedroom), _room_zones(plan, bedroom), before_room)
	var after_room: Dictionary = HouseNavCheck.new().check(plan)
	if not _same_final_report(returned, after_room):
		failures.append("unchanged-failure helper returned a stale report instead of its final plan report")
	if _nav_identity(before_room) != _nav_identity(after_room):
		failures.append("later-room guard changed the exact pre-existing Nav failure identities")
	if not _has_exact_record(plan, cabinet_record):
		failures.append("later bedroom Cabinet was removed despite no new Nav failure")


func _check_new_room_failure_is_repaired() -> void:
	var fixture: Dictionary = _build_case_shell()
	if fixture.is_empty():
		return
	var plan: HousePlan = fixture["plan"]
	var setup: Dictionary = fixture["case"]
	var before: Dictionary = HouseNavCheck.new().check(plan)
	if not bool(before.get("ok", false)):
		failures.append("positive local-repair control did not start Nav-clean")
		return
	var target_index: int = int(setup["left"])
	var room: int = int(setup["room"])
	var blocker: Dictionary = _measured_full_zone_blocker(plan, target_index,
		"fixture_new_room_causal_blocker")
	if blocker.is_empty():
		failures.append("could not place measured clean-to-blocked control body")
		return
	plan.furniture.append(blocker)
	var blocked: Dictionary = HouseNavCheck.new().check(plan)
	if bool(blocked.get("ok", true)) or not _chair_failure_for_item(blocked, target_index, room):
		failures.append("new-room control did not create its actual hosted-seat failure")
		return
	var returned: Dictionary = HouseFurnisher._keep_the_room_passable(plan, room,
		HouseFurnishPlacement.initial_blocked(plan, room), _room_zones(plan, room), before)
	var repaired: Dictionary = HouseNavCheck.new().check(plan)
	if not _same_final_report(returned, repaired):
		failures.append("clean-to-blocked helper returned a stale report instead of its repaired plan report")
	if _nav_identity(repaired) != _nav_identity(before):
		failures.append("clean-to-blocked room repair did not restore the exact clean Nav identity")
	if _has_role(plan, "fixture_new_room_causal_blocker"):
		failures.append("local room repair left its causal measured blocker")


func _check_two_object_plateau_is_repaired() -> void:
	var fixture: Dictionary = _build_case_shell()
	if fixture.is_empty():
		return
	var plan: HousePlan = fixture["plan"]
	var setup: Dictionary = fixture["case"]
	var before: Dictionary = HouseNavCheck.new().check(plan)
	if not bool(before.get("ok", false)):
		failures.append("two-object plateau control did not start Nav-clean")
		return
	var left_index: int = int(setup["left"])
	var right_index: int = int(setup["right"])
	var room: int = int(setup["room"])
	var left_blocker: Dictionary = _measured_full_zone_blocker(plan, left_index,
		"fixture_plateau_blocker_left")
	if left_blocker.is_empty():
		failures.append("could not place first measured plateau blocker")
		return
	plan.furniture.append(left_blocker)
	var right_blocker: Dictionary = _measured_full_zone_blocker(plan, right_index,
		"fixture_plateau_blocker_right")
	if right_blocker.is_empty():
		failures.append("could not place second measured plateau blocker without colliding with first")
		return
	plan.furniture.append(right_blocker)
	var blocked: Dictionary = HouseNavCheck.new().check(plan)
	if not Array(blocked.get("unreachable_items", [])).has(left_index) \
			or not Array(blocked.get("unreachable_items", [])).has(right_index):
		failures.append("two independent actual chair zones were not both reported unreachable")
		return
	var removed_left: Dictionary = _remove_role(plan, "fixture_plateau_blocker_left")
	var one_removed: Dictionary = HouseNavCheck.new().check(plan)
	var one_removed_items: Array = Array(one_removed.get("unreachable_items", []))
	if bool(one_removed.get("ok", false)) or one_removed_items.has(left_index) \
			or not one_removed_items.has(right_index):
		failures.append("removing only one causal blocker did not leave the other chair failure")
		return
	plan.furniture.append(removed_left)
	var returned: Dictionary = HouseFurnisher._keep_the_room_passable(plan, room,
		HouseFurnishPlacement.initial_blocked(plan, room), _room_zones(plan, room), before)
	var repaired: Dictionary = HouseNavCheck.new().check(plan)
	if not _same_final_report(returned, repaired):
		failures.append("two-object helper returned a stale report instead of its final plan report")
	if _nav_identity(repaired) != _nav_identity(before):
		failures.append("bounded two-object room repair did not restore the exact clean report")
	if _has_role(plan, "fixture_plateau_blocker_left") \
			or _has_role(plan, "fixture_plateau_blocker_right"):
		failures.append("bounded repair did not remove both causal blockers")


func _check_three_removal_report_is_fresh() -> void:
	var plan: HousePlan = _public_cottage_shell()
	if plan == null:
		return
	var triple: Dictionary = _controlled_meal_pair(plan, true)
	if triple.is_empty() or int(triple.get("end", -1)) < 0:
		failures.append("public Cottage shell has no fully measured room for the third hosted seat")
		return
	var before: Dictionary = HouseNavCheck.new().check(plan)
	if not bool(before.get("ok", false)):
		failures.append("three-removal control did not start Nav-clean")
		return
	var targets: Array[int] = [int(triple["left"]), int(triple["right"]), int(triple["end"])]
	var roles: Array[String] = ["fixture_three_blocker_left", "fixture_three_blocker_right", "fixture_three_blocker_end"]
	for index in range(targets.size()):
		var blocker := _measured_full_zone_blocker(plan, targets[index], roles[index])
		if blocker.is_empty():
			failures.append("three-removal control could not place measured blocker %d: %s" % [index, _blocker_failure_details(plan, targets[index])])
			return
		plan.furniture.append(blocker)
	var blocked: Dictionary = HouseNavCheck.new().check(plan)
	for target_index in targets:
		if not Array(blocked.get("unreachable_items", [])).has(target_index):
			failures.append("three-removal control did not block hosted Chair_1 item %d" % target_index)
			return
	var before_count := plan.furniture.size()
	var room := int(triple["room"])
	var returned: Dictionary = HouseFurnisher._keep_the_room_passable(plan, room,
		HouseFurnishPlacement.initial_blocked(plan, room), _room_zones(plan, room), before)
	var final_report: Dictionary = HouseNavCheck.new().check(plan)
	if not _same_final_report(returned, final_report):
		failures.append("third-removal helper returned a stale report instead of the final independent Nav report")
	if not bool(returned.get("ok", false)) or not bool(final_report.get("ok", false)):
		failures.append("three-removal control did not return a fresh clean final Nav report")
	if before_count - plan.furniture.size() != 3:
		failures.append("three-removal control expected exactly three measured blocker removals, got %d" % (before_count - plan.furniture.size()))
	for role in roles:
		if _has_role(plan, role):
			failures.append("third-removal control left a causal blocker: %s" % role)


func _measured_full_zone_blocker(plan: HousePlan, target_index: int, role: String) -> Dictionary:
	var target: Dictionary = plan.furniture[target_index]
	var room: int = int(target["room"])
	var zone: Rect2 = Rect2(target["zone"])
	var floor: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var yaw: float = float(target.get("yaw", 0.0))
	var footprint: Vector2 = PropCatalog.footprint_rotated("Chair_1", yaw)
	var scale: float = maxf(zone.size.x / footprint.x, zone.size.y / footprint.y)
	var body_size: Vector2 = footprint * scale
	var center: Vector2 = zone.get_center() + (body_size - zone.size) * 0.5
	var blocker: Dictionary = HouseFurnishGeometry.candidate("Chair_1", center, yaw, 1.0, scale)
	var body: Rect2 = Rect2(blocker["rect"])
	var blocker_zone: Rect2 = Rect2(blocker.get("zone", Rect2()))
	if not floor.encloses(body) or not body.encloses(zone.grow(-0.00001)) \
			or (blocker_zone.has_area() and not floor.encloses(blocker_zone)) \
			or _material_overlap(body, Rect2(target["rect"])):
		return {}
	for i in range(plan.furniture.size()):
		var other: Dictionary = plan.furniture[i]
		if int(other.get("room", -1)) != room:
			continue
		if _material_overlap(body, Rect2(other["rect"])):
			return {}
		if i != target_index and _material_overlap(body, Rect2(other.get("zone", Rect2()))):
			return {}
	blocker["room"] = room
	blocker["host"] = -1
	blocker["must"] = false
	blocker["fixture_role"] = role
	return blocker



func _blocker_failure_details(plan: HousePlan, target_index: int) -> String:
	var target: Dictionary = plan.furniture[target_index]
	var room: int = int(target["room"])
	var zone: Rect2 = Rect2(target["zone"])
	var floor: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var yaw: float = float(target.get("yaw", 0.0))
	var footprint: Vector2 = PropCatalog.footprint_rotated("Chair_1", yaw)
	var scale: float = maxf(zone.size.x / footprint.x, zone.size.y / footprint.y)
	var body_size: Vector2 = footprint * scale
	var center: Vector2 = zone.get_center() + (body_size - zone.size) * 0.5
	var candidate: Dictionary = HouseFurnishGeometry.candidate("Chair_1", center, yaw, 1.0, scale)
	var body: Rect2 = Rect2(candidate["rect"])
	var own_zone: Rect2 = Rect2(candidate.get("zone", Rect2()))
	var details: Array[String] = [
		"target=%s body=%s zone=%s yaw=%.6f" % [String(target.get("key", "")), str(Rect2(target["rect"])), str(zone), yaw],
		"room_floor=%s candidate_scale=%.6f candidate_body=%s candidate_zone=%s" % [str(floor), scale, str(body), str(own_zone)],
		"floor_body=%s body_covers_target_zone=%s floor_own_zone=%s target_body_overlap=%s" % [str(floor.encloses(body)), str(body.encloses(zone.grow(-0.00001))), str(not own_zone.has_area() or floor.encloses(own_zone)), str(_material_overlap(body, Rect2(target["rect"])))],
	]
	for i in range(plan.furniture.size()):
		var other: Dictionary = plan.furniture[i]
		if i == target_index or int(other.get("room", -1)) != room:
			continue
		var other_body: Rect2 = Rect2(other["rect"])
		var other_zone: Rect2 = Rect2(other.get("zone", Rect2()))
		if _material_overlap(body, other_body) or _material_overlap(body, other_zone):
			details.append("conflict index=%d role=%s key=%s body=%s zone=%s body_overlap=%s zone_overlap=%s" % [i, String(other.get("fixture_role", "")), String(other.get("key", "")), str(other_body), str(other_zone), str(_material_overlap(body, other_body)), str(_material_overlap(body, other_zone))])
	return " | ".join(details)
func _chair_failure_for_item(report: Dictionary, item: int, room: int) -> bool:
	if not Array(report.get("unreachable_items", [])).has(item):
		return false
	for issue: String in report.get("failures", []):
		if issue.begins_with("nav: nobody can reach the Chair_1") \
				and issue.contains("room %d" % room) and issue.contains("to use it"):
			return true
	return false


func _room_zones(plan: HousePlan, room: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for piece: Dictionary in plan.furniture:
		if int(piece.get("room", -1)) == room:
			out.append(Rect2(piece.get("zone", Rect2())))
	return out


func _nav_identity(report: Dictionary) -> Dictionary:
	var issues: Array = Array(report.get("failures", [])).duplicate()
	var rooms: Array = Array(report.get("unreached_rooms", [])).duplicate()
	var items: Array = Array(report.get("unreachable_items", [])).duplicate()
	issues.sort()
	rooms.sort()
	items.sort()
	return {"failures": issues, "unreached_rooms": rooms, "unreachable_items": items}


func _same_final_report(returned: Dictionary, independent: Dictionary) -> bool:
	return bool(returned.get("ok", false)) == bool(independent.get("ok", false)) \
		and _nav_identity(returned) == _nav_identity(independent) \
		and returned.get("stats", {}) == independent.get("stats", {})


func _material_overlap(a: Rect2, b: Rect2) -> bool:
	var overlap: Rect2 = a.intersection(b)
	return overlap.size.x > 0.00001 and overlap.size.y > 0.00001


func _has_exact_record(plan: HousePlan, expected: Dictionary) -> bool:
	for piece: Dictionary in plan.furniture:
		if String(piece.get("fixture_role", "")) == String(expected.get("fixture_role", "")) \
				and int(piece.get("room", -1)) == int(expected.get("room", -2)) \
				and String(piece.get("key", "")) == String(expected.get("key", "")) \
				and Rect2(piece.get("rect", Rect2())).is_equal_approx(Rect2(expected.get("rect", Rect2()))):
			return true
	return false


func _has_role(plan: HousePlan, role: String) -> bool:
	for piece: Dictionary in plan.furniture:
		if String(piece.get("fixture_role", "")) == role:
			return true
	return false


func _remove_role(plan: HousePlan, role: String) -> Dictionary:
	for i in range(plan.furniture.size() - 1, -1, -1):
		if String(plan.furniture[i].get("fixture_role", "")) == role:
			return plan.furniture.pop_at(i)
	return {}



