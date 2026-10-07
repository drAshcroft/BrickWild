extends SceneTree
## Generated-plan LIVE-GROUPS fixture, including compact household activities.

var failures: Array[String] = []

func _init() -> void:
	var spec := HouseSpec.new()
	spec.style = &"farmhouse"
	spec.width = 9.0
	spec.length = 12.0
	spec.height = 2.6
	var plan := HouseGenerator.generate(spec, 8102, true)
	var kitchen := _first_room(plan, &"kitchen")
	var bedroom := _first_room(plan, &"bedroom")
	if kitchen < 0:
		failures.append("fixture house did not plan a kitchen")
	else:
		_check_group(plan, kitchen, "cooking", ["hearth", "workbench", "storage", "bucket", "cookware"])
	if bedroom >= 0:
		_check_group(plan, bedroom, "sleep", ["bed", "chest", "sconce"])
		_check_bedside_support(plan, bedroom)
		_check_bedside_backing(plan, bedroom)
		_check_chest_floor(plan, bedroom)
	else:
		failures.append("fixture farmhouse did not plan a bedroom")
	_check_eating_capacity(plan)
	_check_shared_cooking_hall()
	_check_small_brief_reporting()
	_check_bed_head_axis_orientations()
	_check_nav_repair_loss(plan, kitchen)
	for failure in failures:
		push_error(failure)
	print("generated activity groups: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _first_room(plan: HousePlan, kind: StringName) -> int:
	var rooms: Array[int] = plan.rooms_of(kind)
	return rooms[0] if not rooms.is_empty() else -1


func _check_bedside_backing(plan: HousePlan, room: int) -> void:
	for piece in plan.furniture:
		if int(piece["room"]) != room or String(piece.get("activity_host_anchor", "")) != "head_end":
			continue
		if not HouseFurnishArrangementCheck._backs_bed_head(plan, piece):
			failures.append("actual bedside chest does not prove its bed backing")
		var wrong_facing: Dictionary = piece.duplicate(true)
		wrong_facing["yaw"] = float(piece["yaw"]) + PI
		if HouseFurnishArrangementCheck._backs_bed_head(plan, wrong_facing):
			failures.append("reversed bedside chest bypassed backing check")
		var detached: Dictionary = piece.duplicate(true)
		detached["rect"] = Rect2(Vector2(100.0, 100.0), Rect2(piece["rect"]).size)
		if HouseFurnishArrangementCheck._backs_bed_head(plan, detached):
			failures.append("detached annotated chest bypassed backing check")
		return
	failures.append("bedside backing fixture has no head support")


func _check_chest_floor(plan: HousePlan, room: int) -> void:
	var floor_y := HouseFurnishGeometry.storey_base(plan, room) + HouseGeometry.FLOOR_T
	for piece in plan.furniture:
		if int(piece.get("room", -1)) == room and String(piece.get("cat", "")) == "chest":
			if not is_equal_approx(float(piece["pos"].y), floor_y):
				failures.append("room %d clothes/bedside chest is not on the finished floor" % room)


func _check_group(plan: HousePlan, room: int, group_name: String, categories: Array[String]) -> void:
	for category in categories:
		var count := 0
		for piece in plan.furniture:
			if int(piece["room"]) == room and String(piece.get("activity_group", "")) == group_name \
					and String(piece["cat"]) == category:
				count += 1
		if count == 0:
			failures.append("room %d group %s missing %s" % [room, group_name, category])
		if group_name == "sleep" and category == "chest" and count < 2:
			failures.append("room %d sleep group lacks separate bedside support and clothes storage" % room)
		if group_name == "cooking" and category == "workbench":
			_check_group_piece_height(plan, room, group_name, category, 0.75)
	if plan.was_dropped(room, "activity:" + group_name):
		failures.append("room %d group %s was compromised" % [room, group_name])


func _check_bedside_support(plan: HousePlan, room: int) -> void:
	var child: Dictionary = {}
	for piece in plan.furniture:
		if int(piece["room"]) == room and String(piece["cat"]) == "chest" \
				and String(piece.get("activity_host_cat", "")) == "bed":
			child = piece
			break
	var host := _piece(plan, room, "bed")
	if child.is_empty() or host.is_empty():
		failures.append("room %d lacks bedside chest support and bed endpoints" % room)
		return
	if _edge_distance(Rect2(child["rect"]), Rect2(host["rect"])) > 0.2:
		failures.append("room %d bedside chest is not beside bed" % room)
	if Rect2(child["rect"]).intersects(Rect2(host.get("zone", Rect2()))):
		failures.append("room %d bedside chest overlaps the bed access zone" % room)
	if PropCatalog.height(String(child["key"])) > 0.8:
		failures.append("room %d bedside support is too tall to use as a low chest" % room)
	var head_world: Vector3 = Basis(Vector3.UP, float(host.get("yaw", 0.0))) * Vector3.BACK
	var head_dir := Vector2(head_world.x, head_world.z).normalized()
	var head_offset: float = (Rect2(child["rect"]).get_center() - Rect2(host["rect"]).get_center()).dot(head_dir)
	var head_extent: float = absf(head_dir.x) * Rect2(host["rect"]).size.x * 0.5 \
		+ absf(head_dir.y) * Rect2(host["rect"]).size.y * 0.5
	var support_extent: float = absf(head_dir.x) * Rect2(child["rect"]).size.x * 0.5 \
		+ absf(head_dir.y) * Rect2(child["rect"]).size.y * 0.5
	if head_offset + support_extent < head_extent / 3.0:
		failures.append("room %d bedside support is at mid-bed, not the head end" % room)


func _check_bed_head_axis_orientations() -> void:
	# Exercise the real group audit at each cardinal yaw. Bed_Twin has a PI
	# catalog face offset, while placement/audit use the plan yaw frame.
	var spec := HouseSpec.new()
	spec.style = &"cottage"
	spec.width = 9.0
	spec.length = 12.0
	spec.height = 2.6
	var plan := HouseGenerator.generate(spec, 8102, true)
	var room := _first_room(plan, &"bedroom")
	if room < 0:
		failures.append("orientation fixture has no bedroom")
		return
	var bed_index := -1
	var support_index := -1
	for i in plan.furniture.size():
		var piece: Dictionary = plan.furniture[i]
		if int(piece["room"]) != room:
			continue
		if String(piece["cat"]) == "bed":
			bed_index = i
		elif String(piece["cat"]) == "chest" \
				and String(piece.get("activity_host_cat", "")) == "bed":
			support_index = i
	if bed_index < 0 or support_index < 0:
		failures.append("orientation fixture lacks generated bed/head support")
		return
	var yaws: Array[float] = [0.0, PI * 0.5, PI, PI * 1.5]
	var expected: Array[Vector2] = [Vector2(0, 1), Vector2(1, 0),
		Vector2(0, -1), Vector2(-1, 0)]
	for i in yaws.size():
		var world_head: Vector3 = Basis(Vector3.UP, yaws[i]) * Vector3.BACK
		var head_dir := Vector2(world_head.x, world_head.z).normalized()
		if not head_dir.is_equal_approx(expected[i]):
			failures.append("bed yaw %.2f head axis %s should be %s" % [yaws[i], head_dir, expected[i]])
		var bed: Dictionary = plan.furniture[bed_index]
		var support: Dictionary = plan.furniture[support_index]
		var bed_rect := Rect2(bed["rect"])
		var support_rect := Rect2(support["rect"])
		bed["yaw"] = yaws[i]
		support_rect.size = Vector2(0.5, 0.5)
		support_rect.position = bed_rect.get_center() + head_dir * 1.35 - support_rect.size * 0.5
		support["rect"] = support_rect
		bed["activity_group"] = "sleep"
		support["activity_group"] = "sleep"
		plan.furniture[bed_index] = bed
		plan.furniture[support_index] = support
		plan.compromises[room] = []
		HouseFurnisher._audit_activity_groups(plan)
		if plan.was_dropped(room, "activity:sleep:relation:head_end"):
			failures.append("real activity audit rejects head support at yaw %.2f" % yaws[i])
		# A foot-end support is the negative control. The actual audit must reject it.
		support_rect.position = bed_rect.get_center() - head_dir * 1.35 - support_rect.size * 0.5
		support["rect"] = support_rect
		plan.furniture[support_index] = support
		plan.compromises[room] = []
		HouseFurnisher._audit_activity_groups(plan)
		if not plan.was_dropped(room, "activity:sleep:relation:head_end"):
			failures.append("real activity audit accepts foot-end support at yaw %.2f" % yaws[i])


func _check_eating_capacity(plan: HousePlan) -> void:
	var room := HouseFurnishingRecipes.dining_room_of(plan)
	if room < 0:
		failures.append("fixture plan has no household dining room")
		return
	var seats := 0
	for piece in plan.furniture:
		if int(piece["room"]) == room and String(piece.get("activity_group", "")) == "eating" \
				and String(piece["cat"]) == "seat":
			seats += 1
	var expected := HouseFurnisher._household_seat_capacity(plan)
	if seats < expected:
		failures.append("dining room %d seats %d of %d household places" % [room, seats, expected])
	_check_group_piece_height(plan, room, "eating", "table", 0.70)


## These are human-scale usability targets from render review, not building
## regulations: the tabletop looked low at 0.504 m and work surface too low
## below 0.75 m.
func _check_group_piece_height(plan: HousePlan, room: int, group_name: String,
		category: String, minimum_height: float) -> void:
	var found := false
	for piece in plan.furniture:
		if int(piece.get("room", -1)) != room \
				or String(piece.get("activity_group", "")) != group_name \
				or String(piece.get("cat", "")) != category:
			continue
		found = true
		var key: String = String(piece.get("key", ""))
		var measured_height: float = PropCatalog.placement_height(piece)
		if measured_height < minimum_height:
			failures.append("room %d %s %s %s is %.3f m high, below %.2f m human-scale target" % [
				room, group_name, category, key, measured_height, minimum_height])
	if not found:
		failures.append("room %d required %s %s has no placed item to measure" % [
			room, group_name, category])


func _check_shared_cooking_hall() -> void:
	var compact := HouseSpec.new()
	compact.style = &"cottage"
	compact.width = 7.0
	compact.length = 9.0
	compact.height = 2.6
	var plan: HousePlan = HouseGenerator.generate(compact, 1, true)
	if plan.room_count() != 2:
		failures.append("compact shared-cooking request did not generate a true two-room plan")
		return
	var hall := _first_room(plan, &"hall")
	if hall < 0 or not plan.rooms[hall].get("domestic_functions", []).has(&"cooking"):
		failures.append("compact two-room plan did not mark its shared cooking hall")
		return
	_check_group(plan, hall, "cooking", ["hearth", "workbench", "storage", "bucket", "cookware"])
	_check_eating_capacity(plan)
	_check_compact_meal_pair(plan, hall)
	var bedroom := _first_room(plan, &"bedroom")
	if bedroom >= 0:
		_check_group(plan, bedroom, "sleep", ["bed", "chest", "sconce"])
		_check_bedside_support(plan, bedroom)
		_check_chest_floor(plan, bedroom)
	var nav: Dictionary = HouseNavCheck.new().check(plan)
	if not bool(nav.get("ok", false)):
		failures.append("compact household activities are unreachable: %s" % nav.get("failures", []))
	if String(plan.domestic_layout.get("activity_status", "")) != "complete":
		failures.append("7x9 household did not report a complete activity brief")


func _check_small_brief_reporting() -> void:
	# Additional stress request, outside the accepted 7x9/default/ample matrix.
	# A bounded search may fail here; that result must remain explicit rather
	# than making a navigable but partly furnished shell look complete.
	var spec := HouseSpec.new()
	spec.width = 7.0
	spec.length = 7.0
	spec.height = 2.6
	var plan := HouseGenerator.generate(spec, 1, true)
	var missing: Array[String] = []
	for contract in [
		{"kind": &"hall", "group": "cooking", "counts": {"hearth": 1, "storage": 1, "workbench": 1, "bucket": 1, "cookware": 1}},
		{"kind": &"hall", "group": "eating", "counts": {"table": 1, "seat": 2}},
		{"kind": &"bedroom", "group": "sleep", "counts": {"bed": 1, "chest": 2, "sconce": 1}},
	]:
		var room := _first_room(plan, contract["kind"])
		for category in contract["counts"]:
			var count := 0
			for piece in plan.furniture:
				if int(piece.get("room", -1)) == room \
						and String(piece.get("activity_group", "")) == String(contract["group"]) \
						and String(piece.get("cat", "")) == String(category):
					count += 1
			if count < int(contract["counts"][category]):
				missing.append("%s/%s" % [contract["group"], category])
				if not plan.was_dropped(room, "activity:%s" % contract["group"]):
					failures.append("7x7 stress request silently lost %s/%s" % [contract["group"], category])
	if not missing.is_empty():
		if String(plan.domestic_layout.get("activity_status", "")) != "unsatisfied" \
				or plan.domestic_layout.get("activity_shortfalls", []).is_empty():
			failures.append("7x7 stress request hides its unsatisfied activity brief")
	print("7x7 stress request activity_status=", plan.domestic_layout.get("activity_status", ""),
		" missing=", missing, " (not visual acceptance)")


func _check_compact_meal_pair(plan: HousePlan, room: int) -> void:
	if HouseFurnishingRecipes.dining_room_of(plan) != room:
		failures.append("compact two-room hall is not the household dining room")
		return
	var tables: Array[int] = []
	var seats: Array[int] = []
	for index in range(plan.furniture.size()):
		var piece: Dictionary = plan.furniture[index]
		if int(piece.get("room", -1)) != room \
				or String(piece.get("activity_group", "")) != "eating":
			continue
		if String(piece.get("cat", "")) == "table":
			tables.append(index)
		elif String(piece.get("cat", "")) == "seat":
			seats.append(index)
	var expected := HouseFurnisher._household_seat_capacity(plan)
	if tables.size() != 1:
		failures.append("compact hall needs one real eating table, found %d" % tables.size())
		return
	if seats.size() != expected:
		failures.append("compact hall retains %d of %d required eating seats" % [seats.size(), expected])
		return
	var table: Dictionary = plan.furniture[tables[0]]
	var table_rect := Rect2(table.get("rect", Rect2()))
	var floor_rect := HouseGeometry.room_floor_rect(plan, room)
	for seat_index in seats:
		var seat: Dictionary = plan.furniture[seat_index]
		var host_index := int(seat.get("host", -1))
		if host_index < 0 or host_index >= plan.furniture.size():
			failures.append("compact eating seat has no live table-host index after repair")
			continue
		var host: Dictionary = plan.furniture[host_index]
		if host_index != tables[0] or int(host.get("room", -1)) != room \
				or String(host.get("cat", "")) != "table" \
				or String(host.get("activity_group", "")) != "eating":
			failures.append("compact eating seat host does not resolve to its actual eating table")
		var seat_rect := Rect2(seat.get("rect", Rect2()))
		var access := Rect2(seat.get("zone", Rect2()))
		if not access.has_area() or not floor_rect.grow(0.02).encloses(access):
			failures.append("compact eating seat has no usable in-room access zone after repair")
		# The access rectangle shares an exact edge with its own seat. Ignore
		# sub-millimetre floating-point overlap at that common boundary.
		elif access.grow(-0.001).intersects(table_rect) or access.grow(-0.001).intersects(seat_rect):
			failures.append("compact eating-seat access zone is blocked by its table or seat")

	var damaged := _copy_plan(plan)
	damaged.compromises[room] = []
	var removed_seat: int = seats.back()
	damaged.furniture.remove_at(removed_seat)
	HouseFurnishRepair.reindex_hosts(damaged, removed_seat)
	HouseFurnisher._audit_activity_groups(damaged)
	if not damaged.was_dropped(room, "activity:eating") \
			or not damaged.was_dropped(room, "activity:eating:seat_capacity"):
		failures.append("removing one compact-house seat did not record the eating-capacity compromise")
	_check_all_host_indices(damaged, "after compact seat removal")
	var remaining_seat_has_table_host := false
	for piece in damaged.furniture:
		if int(piece.get("room", -1)) != room \
				or String(piece.get("cat", "")) != "seat" \
				or String(piece.get("activity_group", "")) != "eating":
			continue
		var host_index := int(piece.get("host", -1))
		if host_index >= 0 and host_index < damaged.furniture.size():
			var host: Dictionary = damaged.furniture[host_index]
			remaining_seat_has_table_host = int(host.get("room", -1)) == room \
				and String(host.get("cat", "")) == "table" \
				and String(host.get("activity_group", "")) == "eating"
			if not remaining_seat_has_table_host:
				break
	if not remaining_seat_has_table_host:
		failures.append("remaining compact eating seat lost its reindexed table host")


func _check_all_host_indices(plan: HousePlan, label: String) -> void:
	for index in range(plan.furniture.size()):
		var piece: Dictionary = plan.furniture[index]
		var host_index: int = int(piece.get("host", -1))
		if host_index < -1 or host_index >= plan.furniture.size() or host_index == index:
			failures.append("%s left furniture %d with invalid host index %d" % [
				label, index, host_index])


func _check_nav_repair_loss(plan: HousePlan, room: int) -> void:
	if room < 0:
		return
	var baseline := _copy_plan(plan)
	var frozen_baseline_furniture: Array = baseline.furniture.duplicate(true)
	var baseline_nav: Dictionary = HouseNavCheck.new().check(baseline)
	if not bool(baseline_nav["ok"]):
		failures.append("repair control baseline was not walkable: %s" % baseline_nav["failures"])
		return
	var damaged := _copy_plan(plan)
	var bench_index := -1
	for i in damaged.furniture.size():
		if int(damaged.furniture[i].get("room", -1)) == room \
				and String(damaged.furniture[i].get("cat", "")) == "workbench" \
				and String(damaged.furniture[i].get("activity_group", "")) == "cooking":
			bench_index = i
			break
	if bench_index < 0:
		failures.append("repair fixture has no cooking workbench to challenge")
		return
	if not _move_workbench_into_real_door_choke(damaged, bench_index, room):
		failures.append("repair fixture could not place the measured workbench in a real kitchen doorway")
		return
	var blocked_nav: Dictionary = HouseNavCheck.new().check(damaged)
	if bool(blocked_nav["ok"]):
		failures.append("doorway-choke mutation did not block the otherwise walkable generated plan")
		return
	var removed: int = HouseFurnishRepair.relax(damaged)
	HouseFurnisher._audit_activity_groups(damaged)
	var bench_remains := false
	for piece in damaged.furniture:
		if int(piece.get("room", -1)) == room and String(piece.get("cat", "")) == "workbench" \
				and String(piece.get("activity_group", "")) == "cooking":
			bench_remains = true
	if removed <= 0 or bench_remains:
		failures.append("nav repair did not remove the blocking required cooking workbench")
	if not bool(HouseNavCheck.new().check(damaged)["ok"]):
		failures.append("nav repair did not restore routes after removing the blocking workbench")
	if not damaged.was_dropped(room, "activity:cooking"):
		failures.append("nav repair loss did not leave an explicit cooking shortfall")
	if baseline.furniture != frozen_baseline_furniture or not bool(HouseNavCheck.new().check(baseline)["ok"]):
		failures.append("repair mutated the frozen generated-plan baseline")


func _move_workbench_into_real_door_choke(plan: HousePlan, piece_index: int, room: int) -> bool:
	var floor := HouseGeometry.room_floor_rect(plan, room)
	var bench: Dictionary = plan.furniture[piece_index]
	var chosen_door: Dictionary = {}
	var chosen_other := -1
	for door in plan.doors:
		if bool(door.get("exterior", false)):
			continue
		if int(door.get("a", -1)) == room:
			chosen_door = door
			chosen_other = int(door.get("b", -1))
		elif int(door.get("b", -1)) == room:
			chosen_door = door
			chosen_other = int(door.get("a", -1))
		if not chosen_door.is_empty() and plan.kind_of(chosen_other) == &"hall":
			break
	if chosen_door.is_empty() or chosen_other < 0:
		return false
	var normal: Vector2 = Vector2(chosen_door.get("normal", Vector2.UP))
	var inward := normal * signf((floor.get_center() - Vector2(chosen_door["pos"])).dot(normal))
	if inward.length_squared() < 0.5:
		return false
	var side := 1.0 if inward.dot(normal) >= 0.0 else -1.0
	var opening: Rect2 = HouseGeometry.door_clear_rect(chosen_door, side)
	var best := {}
	var best_overlap := 0.0
	for depth in [0.35, 0.5, 0.65, 0.8, 1.05, 1.2, 1.4]:
		var centre: Vector2 = Vector2(chosen_door["pos"]) + inward * float(depth)
		for yaw in [0.0, PI * 0.5, PI, PI * 1.5]:
			var candidate := HouseFurnishGeometry.candidate(String(bench["key"]), centre,
				float(yaw), 1.0, float(bench.get("scale", 1.0)))
			var rect: Rect2 = Rect2(candidate["rect"])
			if not _fits_through_shared_doorway(plan, rect, chosen_door, room, chosen_other):
				continue
			var overlap: Rect2 = rect.intersection(opening)
			if overlap.get_area() > best_overlap:
				best_overlap = overlap.get_area()
				best = candidate
	if best.is_empty() or best_overlap < 0.12:
		return false
	var moved: Dictionary = bench.duplicate(true)
	var position: Vector3 = Vector3(best["pos"])
	position.y = float(bench.get("pos", Vector3.ZERO).y)
	moved["pos"] = position
	moved["rect"] = Rect2(best["rect"])
	moved["zone"] = Rect2(best["zone"])
	moved["yaw"] = float(best["yaw"])
	plan.furniture[piece_index] = moved
	return true


func _fits_through_shared_doorway(plan: HousePlan, footprint: Rect2, door: Dictionary,
		room_a: int, room_b: int) -> bool:
	if room_b < 0 or room_b >= plan.room_count():
		return false
	var a := HouseGeometry.room_floor_rect(plan, room_a)
	var b := HouseGeometry.room_floor_rect(plan, room_b)
	# A blocker may stand wholly inside one room across its door approach.
	# Only a footprint straddling the partition needs the aperture test.
	if a.encloses(footprint) or b.encloses(footprint):
		return true
	var union := a.merge(b)
	if not union.encloses(footprint):
		return false
	var pos: Vector2 = Vector2(door["pos"])
	var normal: Vector2 = Vector2(door["normal"]).normalized()
	var half_door := float(door["width"]) * 0.5 - 0.02
	if half_door <= 0.0:
		return false
	if absf(normal.x) >= absf(normal.y):
		if footprint.position.x >= pos.x or footprint.end.x <= pos.x:
			return false
		return footprint.position.y >= pos.y - half_door \
			and footprint.end.y <= pos.y + half_door
	if footprint.position.y >= pos.y or footprint.end.y <= pos.y:
		return false
	return footprint.position.x >= pos.x - half_door \
		and footprint.end.x <= pos.x + half_door


func _copy_plan(source: HousePlan) -> HousePlan:
	var copy := HousePlan.new()
	copy.spec = source.spec
	copy.rooms = source.rooms.duplicate(true)
	copy.doors = source.doors.duplicate(true)
	copy.windows = source.windows.duplicate(true)
	copy.furniture = source.furniture.duplicate(true)
	copy.rugs = source.rugs.duplicate(true)
	copy.zones = source.zones.duplicate(true)
	copy.columns = source.columns.duplicate(true)
	copy.stairs = source.stairs.duplicate(true)
	copy.trapdoors = source.trapdoors.duplicate(true)
	copy.courts = source.courts.duplicate(true)
	copy.hearth = source.hearth.duplicate(true)
	copy.focus = source.focus.duplicate(true)
	copy.dais = source.dais.duplicate(true)
	copy.compromises = source.compromises.duplicate(true)
	return copy


func _piece(plan: HousePlan, room: int, category: String) -> Dictionary:
	for piece in plan.furniture:
		if int(piece["room"]) == room and String(piece["cat"]) == category:
			return piece
	return {}


func _edge_distance(a: Rect2, b: Rect2) -> float:
	var gap_x := maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), 0.0)
	var gap_y := maxf(maxf(a.position.y - b.end.y, b.position.y - a.end.y), 0.0)
	return Vector2(gap_x, gap_y).length()
