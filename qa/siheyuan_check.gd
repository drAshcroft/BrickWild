class_name SiheyuanCheck
extends RefCounted
## WLD-007: cultural compound rules layered over the shared CourtCheck.


func check(plan: HousePlan, supplied_builder: HouseBuilder = null) -> Dictionary:
	var failures: Array[String] = []
	var stats := {"courts": 0, "wings": 0, "verandah_rooms": 0}
	if plan == null or plan.spec == null or plan.world_family != &"siheyuan":
		return {"ok": false, "failures": ["siheyuan: missing family plan or spec"], "warnings": [], "stats": stats}
	var builder := supplied_builder
	if builder == null:
		builder = HouseBuilder.new()
		builder.build(plan)
	var overrides := {
		"inward": {"name": "Siheyuan inward rooms", "call": Callable(self, "_not_applicable")},
		"water": {"name": "Siheyuan water feature", "call": Callable(self, "_not_applicable")},
	}
	# CourtCheck's current bearing rule is four bands for a one-court shell.
	# Multi-court shells use separate span roofs and are sky-checked below.
	if plan.courts.size() == 1:
		overrides["builder"] = builder
	var court_report := CourtCheck.new().check(plan, overrides)
	failures.append_array(court_report.get("failures", []))
	stats["courts"] = plan.courts.size()
	_check_corner_gate(plan, failures)
	_check_screen(plan, builder, failures)
	_check_south_hall(plan, builder, failures)
	_check_mirrored_wings(plan, failures, stats)
	_check_verandah(plan, failures, stats)
	_check_courts_in_line(plan, failures)
	_check_emitted_court_sky(plan, builder, failures)
	return {"ok": failures.is_empty(), "failures": failures,
		"warnings": court_report.get("warnings", []), "stats": stats,
		"court_replacements": court_report.get("replaced", {})}


func _not_applicable(_plan: HousePlan) -> Array[String]:
	return []


func _check_corner_gate(plan: HousePlan, failures: Array[String]) -> void:
	var site := HouseGeometry.site_rect(plan.spec)
	var axis_x := float(plan.world_meta.get("axis_x", 0.0))
	var required := 0.3 * site.size.x
	var gates := 0
	for door in plan.doors:
		if String(door.get("role", "")) != "siheyuan_corner_gate":
			continue
		gates += 1
		var pos: Vector2 = door.get("pos", Vector2.ZERO)
		var normal: Vector2 = door.get("normal", Vector2.ZERO)
		var on_front := absf(pos.y - site.position.y) <= 0.3 and normal.y < -0.5
		if not on_front:
			failures.append("corner_gate: gate is not on the south/front wall")
		if absf(pos.x - axis_x) + 0.001 < required:
			failures.append("corner_gate: door centre is less than 0.3 site widths from the axis")
	if gates != 1:
		failures.append("corner_gate: expected exactly one authored corner gate, found %d" % gates)


func _check_screen(plan: HousePlan, builder: HouseBuilder, failures: Array[String]) -> void:
	if not plan.blind_entry:
		failures.append("screen: blind entry is not enabled")
	var screen := Rect2(plan.world_meta.get("blind_screen", Rect2()))
	var fauces := -1
	for i in range(plan.rooms.size()):
		if String(plan.rooms[i].get("role", "")) == "fauces":
			fauces = i
			break
	if fauces < 0 or not HouseGeometry.room_floor_rect(plan, fauces).encloses(screen):
		failures.append("screen: screen is not inside the authored gate passage")
	var emitted := false
	for mass in builder.mass_log:
		if String(mass.get("name", "")) == "blind_screen":
			emitted = true
	if not emitted:
		failures.append("screen: physical screen mass was not emitted")


func _check_south_hall(plan: HousePlan, builder: HouseBuilder, failures: Array[String]) -> void:
	var hall := _role_room(plan, "main_hall")
	if hall < 0:
		failures.append("south: main_hall room is missing")
		return
	var rect := HouseGeometry.room_floor_rect(plan, hall)
	var axis_x := float(plan.world_meta.get("axis_x", 0.0))
	var far_y := float(plan.world_meta.get("hall_far_wall_y", -INF))
	if absf(rect.get_center().x - axis_x) > 0.1:
		failures.append("south: main hall centre is not on the compound axis")
	if far_y <= float(plan.world_meta.get("street_door", Vector2.ZERO).y):
		failures.append("south: main hall is not on the far side from the gate")
	var hall_door_faces_south := false
	for door in plan.doors:
		if String(door.get("role", "")) == "hall_verandah" \
				and int(door.get("a", -1)) == hall \
				and Vector2(door.get("normal", Vector2.ZERO)).y < -0.5:
			hall_door_faces_south = true
	if not hall_door_faces_south:
		failures.append("south: main hall entrance does not face the south verandah")
	for i in range(plan.room_count()):
		if i == hall:
			continue
		if HouseGeometry.room_floor_rect(plan, i).get_area() > rect.get_area() + 0.01:
			failures.append("south: main hall is not the largest planned room")
			break
	var ridge_name := "siheyuan_main_hall_ridge"
	var ridge_top := -INF
	var max_top := -INF
	for mass in builder.mass_log:
		var bounds: AABB = mass.get("aabb", AABB())
		max_top = maxf(max_top, bounds.end.y)
		if String(mass.get("name", "")) == ridge_name:
			ridge_top = maxf(ridge_top, bounds.end.y)
	if ridge_top == -INF:
		failures.append("south: emitted main hall ridge is missing from mass_log")
	elif ridge_top < max_top - 0.01:
		failures.append("south: main hall ridge is not the highest emitted mass")


func _check_mirrored_wings(plan: HousePlan, failures: Array[String], stats: Dictionary) -> void:
	var wings: Array[int] = []
	for i in range(plan.room_count()):
		if String(plan.rooms[i].get("role", "")).begins_with("wing"):
			wings.append(i)
	stats["wings"] = wings.size()
	if wings.size() != 2:
		failures.append("wings: expected two authored wings, found %d" % wings.size())
		return
	var a := HouseGeometry.room_floor_rect(plan, wings[0])
	var b := HouseGeometry.room_floor_rect(plan, wings[1])
	if absf(a.get_center().x + b.get_center().x) > 0.1 \
			or absf(a.get_center().y - b.get_center().y) > 0.1 \
			or a.size.distance_to(b.size) > 0.1:
		failures.append("wings: the east and west wings are not mirrored within 0.1m")


func _check_verandah(plan: HousePlan, failures: Array[String], stats: Dictionary) -> void:
	var galleries: Array[int] = []
	for i in range(plan.room_count()):
		if String(plan.rooms[i].get("role", "")).begins_with("verandah"):
			galleries.append(i)
	stats["verandah_rooms"] = galleries.size()
	if galleries.size() < 3:
		failures.append("walk: missing one or more continuous verandah floor strips")
		return
	var seen := {galleries[0]: true}
	var queue: Array[int] = [galleries[0]]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		# Room clear-floor rectangles stop at opposite faces of their shared
		# partition, so use the authored room rectangles for adjacency here;
		# WalkGrid below proves that their emitted door gaps make the route walkable.
		var a := Rect2(plan.rooms[current]["rect"])
		for other in galleries:
			if seen.has(other):
				continue
			var b := Rect2(plan.rooms[other]["rect"])
			if _share_walk_edge(a, b):
				seen[other] = true
				queue.append(other)
	if seen.size() != galleries.size():
		failures.append("walk: verandah floor strips are not one continuous walkable run")
	var grid := WalkGrid.new()
	grid.setup(HouseGeometry.site_rect(plan.spec), 0.12)
	for room in galleries:
		grid.add_floor(HouseGeometry.room_floor_rect(plan, room))
	for door in plan.doors:
		if String(door.get("role", "")).begins_with("verandah_") \
				or String(door.get("role", "")) in ["hall_verandah", "west_verandah_door", "east_verandah_door", "gate_verandah"]:
		var pos: Vector2 = door.get("pos", Vector2.ZERO)
		grid.add_floor(Rect2(pos - Vector2(0.5, 0.5), Vector2.ONE))
	grid.build(HouseGeometry.PERSON_RADIUS)
	var rear_index := _role_room(plan, "verandah_rear")
	if rear_index >= 0 and grid.flood_from(HouseGeometry.room_floor_rect(plan, rear_index).get_center()):
		for target in [plan.world_meta.get("hall_door", Vector2.ZERO)] + plan.world_meta.get("wing_doors", []):
			if grid.distance_to(Vector2(target), 1.0) > 100.0:
				failures.append("walk: verandah floor flood does not reach a hall or wing door")
	else:
		failures.append("walk: verandah floor flood cannot enter at the main hall")
	var required_roles := ["hall_verandah", "west_verandah_door", "east_verandah_door"]
	for role in required_roles:
		var found := false
		for door in plan.doors:
			if String(door.get("role", "")) == role:
				found = true
		if not found:
			failures.append("walk: verandah route lacks %s connection" % role)


func _check_courts_in_line(plan: HousePlan, failures: Array[String]) -> void:
	if plan.courts.size() < 2:
		return
	var rows: Array[Dictionary] = []
	for court in plan.courts:
		var rect := Rect2(court.get("rect", Rect2()))
		if absf(rect.get_center().x - float(plan.world_meta.get("axis_x", 0.0))) > 0.1:
			failures.append("courts_in_line: court centre is not on the compound axis")
		rows.append({"rect": rect, "y": rect.get_center().y})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
	for i in range(rows.size() - 1):
		var a: Rect2 = rows[i]["rect"]
		var b: Rect2 = rows[i + 1]["rect"]
		var hall_between := false
		for room in plan.rooms:
			if String(room.get("role", "")) != "main_hall":
				continue
			var r := Rect2(room.get("rect", Rect2()))
			if r.position.y >= a.end.y - 0.1 and r.end.y <= b.position.y + 0.1:
				hall_between = true
		if not hall_between:
			failures.append("courts_in_line: no main hall stands between consecutive courts")
	for i in range(rows.size() - 1):
		var previous: Rect2 = rows[i]["rect"]
		var next: Rect2 = rows[i + 1]["rect"]
		if next.position.y <= previous.end.y:
			failures.append("courts_in_line: courts overlap or are not ordered from front to back")


func _check_emitted_court_sky(plan: HousePlan, builder: HouseBuilder,
		failures: Array[String]) -> void:
	for mass in builder.mass_log:
		var name := String(mass.get("name", ""))
		if not name.begins_with("roof_court"):
			continue
		var bounds: AABB = mass.get("aabb", AABB())
		var footprint := Rect2(Vector2(bounds.position.x, bounds.position.z),
			Vector2(bounds.size.x, bounds.size.z))
		for ci in range(plan.courts.size()):
			var court := Rect2(plan.courts[ci]["rect"])
			var overlap := footprint.intersection(court)
			if overlap.size.x > 0.02 and overlap.size.y > 0.02:
				failures.append("sky: emitted roof mass %s covers court %d" % [name, ci])


func _role_room(plan: HousePlan, role: String) -> int:
	for i in range(plan.room_count()):
		if String(plan.rooms[i].get("role", "")) == role:
			return i
	return -1


func _share_walk_edge(a: Rect2, b: Rect2) -> bool:
	var overlap_x := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
	var overlap_y := minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y)
	return (absf(a.end.x - b.position.x) < 0.05 or absf(b.end.x - a.position.x) < 0.05) \
		and overlap_y >= 1.0 or ((absf(a.end.y - b.position.y) < 0.05 \
		or absf(b.end.y - a.position.y) < 0.05) and overlap_x >= 1.0)
