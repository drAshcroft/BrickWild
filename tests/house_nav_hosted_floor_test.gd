extends SceneTree
## Pure-HEAD shared NavCheck regression using a controlled, measured furniture group
## inside a real public Cottage plan. No test doubles or authored body rectangles.

var failures: Array[String] = []


func _init() -> void:
	_check_hosted_floor_seat_body_and_zone()
	_check_surface_and_mounted_controls()
	for failure in failures:
		push_error(failure)
	print("HEAD hosted floor furniture NavCheck: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _controlled_public_cottage() -> Dictionary:
	var request: BuildingRequest = BrickWild.default_request(&"house", 8102)
	request.style = &"cottage"
	var building: GeneratedBuilding = BrickWild.generate(request)
	if not building.is_ok():
		failures.append("public Cottage request failed: %s" % str(building.errors))
		return {}
	var plan: HousePlan = building.plan
	var room := -1
	var floor := Rect2()
	var largest := 0.0
	for candidate_room in range(plan.room_count()):
		var candidate_floor := HouseGeometry.room_floor_rect(plan, candidate_room)
		if candidate_floor.size.x < 3.5 or candidate_floor.size.y < 3.0:
			continue
		if candidate_floor.get_area() > largest:
			largest = candidate_floor.get_area()
			room = candidate_room
			floor = candidate_floor
	if room < 0:
		failures.append("public Cottage has no room with the measured table-and-seat group envelope")
		return {}
	# This fixture owns a controlled room pair. Clear the public furnishing
	# inventory too, so host indices in other rooms cannot become stale.
	plan.furniture.clear()

	var table_key := "Table_Large"
	var table_size := PropCatalog.footprint_rotated(table_key, 0.0)
	var chair_size := PropCatalog.footprint_rotated("Chair_1", 0.0)
	var table_centre := floor.get_center() - Vector2(0.0, 0.65)
	var table := HouseFurnishGeometry.candidate(table_key, table_centre, 0.0)
	var table_rect: Rect2 = Rect2(table["rect"])
	var chair_centre := Vector2(table_rect.get_center().x, table_rect.end.y + chair_size.y * 0.5)
	var chair := HouseFurnishGeometry.candidate("Chair_1", chair_centre, 0.0)
	var chair_rect: Rect2 = Rect2(chair["rect"])
	var chair_zone: Rect2 = Rect2(chair["zone"])
	if not floor.encloses(table_rect) or not floor.encloses(chair_rect) \
			or not floor.encloses(chair_zone) or table_rect.intersects(chair_rect):
		failures.append("measured public-room Table_Large/Chair_1 group leaves the room or overlaps")
		return {}
	var table_index := plan.furniture.size()
	table["room"] = room
	table["fixture_role"] = "nav_hosted_floor_regression_table"
	chair["room"] = room
	chair["host"] = table_index
	chair["fixture_role"] = "nav_hosted_floor_regression_target"
	plan.furniture.append(table)
	var chair_index := plan.furniture.size()
	plan.furniture.append(chair)
	var nav: Dictionary = HouseNavCheck.new().check(plan)
	if not bool(nav.get("ok", false)):
		failures.append("controlled clear public Cottage furniture group is not navigable: %s" % str(nav.get("failures", [])))
	if Array(nav.get("unreachable_items", [])).has(chair_index):
		failures.append("controlled clear hosted Chair_1 use-zone is unreachable")
	return {"plan": plan, "room": room, "table": table_index, "chair": chair_index}


func _check_hosted_floor_seat_body_and_zone() -> void:
	var hosted := _controlled_public_cottage()
	var unhosted := _controlled_public_cottage()
	if hosted.is_empty() or unhosted.is_empty():
		return
	var hosted_plan: HousePlan = hosted["plan"]
	var unhosted_plan: HousePlan = unhosted["plan"]
	var hosted_index := int(hosted["chair"])
	var unhosted_index := int(unhosted["chair"])
	var chair: Dictionary = hosted_plan.furniture[hosted_index]
	var chair_unhosted: Dictionary = unhosted_plan.furniture[unhosted_index]
	if int(chair.get("host", -1)) != int(hosted["table"]):
		failures.append("controlled Chair_1 is not associated with its real floor table")
		return
	if Rect2(chair["rect"]) != Rect2(chair_unhosted["rect"]) \
			or Rect2(chair["zone"]) != Rect2(chair_unhosted["zone"]):
		failures.append("same-seed hosted/unhosted group has different chair geometry")
		return
	unhosted_plan.furniture[unhosted_index]["host"] = -1
	var clear_hosted: Dictionary = HouseNavCheck.new().check(hosted_plan)
	var clear_unhosted: Dictionary = HouseNavCheck.new().check(unhosted_plan)
	_assert_nav_equivalent(clear_hosted, clear_unhosted, "clear hosted/unhosted floor Chair_1")
	if Array(clear_hosted.get("unreachable_items", [])).has(hosted_index):
		failures.append("clear hosted Chair_1 use-zone is unreachable")
	if int(clear_hosted.get("stats", {}).get("use_zones", -1)) != _floor_use_zone_count(hosted_plan):
		failures.append("NavCheck did not count each floor furniture use-zone")

	var blocker := _measured_full_zone_blocker(hosted_plan, int(hosted["room"]), hosted_index)
	if blocker.is_empty():
		failures.append("no collision-free measured Chair_1 body covers the complete pull-back zone")
		return
	var blocker_unhosted := blocker.duplicate(true)
	hosted_plan.furniture.append(blocker)
	unhosted_plan.furniture.append(blocker_unhosted)
	var blocked_hosted: Dictionary = HouseNavCheck.new().check(hosted_plan)
	var blocked_unhosted: Dictionary = HouseNavCheck.new().check(unhosted_plan)
	if not _chair_use_failure(blocked_hosted) or not _chair_use_failure(blocked_unhosted):
		failures.append("actual measured body did not block the hosted and unhosted Chair_1 use zones")
	if not Array(blocked_hosted.get("unreachable_items", [])).has(hosted_index) \
			or not Array(blocked_unhosted.get("unreachable_items", [])).has(unhosted_index):
		failures.append("NavCheck did not mark the obstructed target chairs unreachable")
	_assert_nav_equivalent(blocked_hosted, blocked_unhosted, "blocked hosted/unhosted floor Chair_1")
	var walk := HouseFurnishWalkCheck.new()
	walk.check_pull_out(hosted_plan)
	if not walk.failures.any(func(issue: String) -> bool:
		return issue.begins_with("pull_out:") and issue.contains("Chair_1") and issue.contains("is pulled out into")):
		failures.append("hosted Chair_1 PULL_OUT marker did not report its obstructed pull-back")


func _measured_full_zone_blocker(plan: HousePlan, room: int, target_index: int) -> Dictionary:
	var target: Dictionary = plan.furniture[target_index]
	var zone: Rect2 = Rect2(target["zone"])
	var floor: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var key := "Chair_1"
	var yaw := float(target.get("yaw", 0.0))
	var footprint := PropCatalog.footprint_rotated(key, yaw)
	var scale := maxf(zone.size.x / footprint.x, zone.size.y / footprint.y)
	var body_size := footprint * scale
	var x_low := maxf(zone.end.x - body_size.x * 0.5, floor.position.x + body_size.x * 0.5)
	var x_high := minf(zone.position.x + body_size.x * 0.5, floor.end.x - body_size.x * 0.5)
	var z_low := maxf(zone.end.y - body_size.y * 0.5, floor.position.y + body_size.y * 0.5)
	var z_high := minf(zone.position.y + body_size.y * 0.5, floor.end.y - body_size.y * 0.5)
	if x_low > x_high + 0.00001 or z_low > z_high + 0.00001:
		return {}
	var centre := zone.get_center() + (body_size - zone.size) * 0.5
	var blocker := HouseFurnishGeometry.candidate(key, centre, yaw, 1.0, scale)
	var rect: Rect2 = Rect2(blocker["rect"])
	var target_rect := Rect2(target["rect"])
	var target_intersection := rect.intersection(target_rect)
	print("BLOCKER_DIAG target_body=%s target_zone=%s catalog_footprint=%s scale=%.9f blocker_body=%s floor=%s contains_zone=%s target_intersection=%s" % [str(target_rect), str(zone), str(footprint), scale, str(rect), str(floor), str(rect.encloses(zone.grow(-0.00001))), str(target_intersection)])
	if not floor.encloses(rect) or not rect.encloses(zone.grow(-0.00001)) \
			or _has_material_overlap(rect, target_rect):
		print("BLOCKER_DIAG reject floor=%s covers_zone=%s target_overlap=%s" % [str(floor.encloses(rect)), str(rect.encloses(zone.grow(-0.00001))), str(target_intersection.size)])
		return {}
	for index in range(plan.furniture.size()):
		var other: Dictionary = plan.furniture[index]
		var other_rect: Rect2 = Rect2(other["rect"])
		var overlap := rect.intersection(other_rect)
		if int(other.get("room", -1)) == room and _has_material_overlap(rect, other_rect):
			print("BLOCKER_DIAG reject_other index=%d key=%s rect=%s overlap=%s" % [index, str(other.get("key", "?")), str(other_rect), str(overlap.size)])
			return {}
	blocker["room"] = room
	blocker["host"] = -1
	blocker["fixture_role"] = "measured_Chair_1_body_covering_full_target_use_zone"
	return blocker


func _has_material_overlap(a: Rect2, b: Rect2) -> bool:
	var overlap := a.intersection(b)
	return overlap.size.x > 0.00001 and overlap.size.y > 0.00001


func _check_surface_and_mounted_controls() -> void:
	var mug_group := _controlled_public_cottage()
	var torch_group := _controlled_public_cottage()
	if mug_group.is_empty() or torch_group.is_empty():
		return
	var mug_plan: HousePlan = mug_group["plan"]
	var table_index := int(mug_group["table"])
	var table: Dictionary = mug_plan.furniture[table_index]
	var centre: Vector2 = Rect2(table["rect"]).get_center()
	var baseline_mug: Dictionary = HouseNavCheck.new().check(mug_plan)
	var mug := HouseFurnishGeometry.candidate("Mug", centre, 0.0)
	mug["room"] = int(table["room"])
	mug["host"] = table_index
	mug["pos"] = Vector3(centre.x, float(table["pos"].y) + PropCatalog.surface_height(String(table["key"])), centre.y)
	if PropCatalog.blocks_floor("Mug") or absf(float(mug["pos"].y) - (float(table["pos"].y) + PropCatalog.surface_height(String(table["key"])))) > 0.0001:
		failures.append("Mug control is not a measured hosted ON_SURFACE placement")
		return
	mug_plan.furniture.append(mug)
	_assert_nav_equivalent(baseline_mug, HouseNavCheck.new().check(mug_plan), "hosted ON_SURFACE Mug")

	var torch_plan: HousePlan = torch_group["plan"]
	var torch_baseline: Dictionary = HouseNavCheck.new().check(torch_plan)
	var torch := HouseFurnishGeometry.candidate("Torch_Metal", centre, 0.0)
	torch["room"] = int(table["room"])
	torch["mounted"] = true
	if PropCatalog.blocks_floor("Torch_Metal"):
		failures.append("mounted Torch_Metal control unexpectedly blocks floor")
		return
	torch_plan.furniture.append(torch)
	_assert_nav_equivalent(torch_baseline, HouseNavCheck.new().check(torch_plan), "mounted Torch_Metal")


func _assert_nav_equivalent(a: Dictionary, b: Dictionary, label: String) -> void:
	for key in ["failures", "unreachable_items", "unreached_rooms"]:
		if a.get(key, []) != b.get(key, []):
			failures.append("%s changed NavCheck %s" % [label, key])
	for stat in ["walkable_area", "reached_cells", "use_zones", "use_zones_reached"]:
		if a.get("stats", {}).get(stat) != b.get("stats", {}).get(stat):
			failures.append("%s changed NavCheck %s statistic" % [label, stat])


func _chair_use_failure(nav: Dictionary) -> bool:
	return Array(nav.get("failures", [])).any(func(issue: String) -> bool:
		return issue.begins_with("nav: nobody can reach the Chair_1") and issue.contains("to use it"))


func _floor_use_zone_count(plan: HousePlan) -> int:
	var count := 0
	for piece: Dictionary in plan.furniture:
		if piece.get("mounted", false) or not PropCatalog.blocks_floor(String(piece["key"])):
			continue
		var zone: Rect2 = Rect2(piece.get("zone", Rect2()))
		if zone.size.x > 0.0 and zone.size.y > 0.0:
			count += 1
	return count
