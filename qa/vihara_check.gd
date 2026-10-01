class_name ViharaCheck
extends RefCounted
## WLD-018: monastic cells, cloister walk, axial shrine and court well.

const CELL_SIDE := 3.0
const VERANDAH := 2.0
const CELL_KINDS := [&"cell"]


func check(plan: HousePlan, supplied_builder: HouseBuilder = null) -> Dictionary:
	var failures: Array[String] = []
	var stats := {"cells": 0, "verandah_rooms": 0}
	if plan == null or plan.spec == null:
		return {"ok": false, "failures": ["plan: missing vihara plan or spec"],
			"warnings": [], "stats": stats}
	var builder := supplied_builder
	if builder == null:
		builder = HouseBuilder.new()
		builder.build(plan)

	# Keep the inherited sky, ring and proportion rules. Ordinary window-facing
	# inwardness has no meaning here because the cells are deliberately blind.
	var court_plan := HousePlan.new()
	court_plan.spec = plan.spec
	court_plan.rooms = plan.rooms
	court_plan.doors = plan.doors
	court_plan.windows = plan.windows
	court_plan.furniture = plan.furniture
	court_plan.courts = plan.courts
	court_plan.stairs = plan.stairs
	var court_report := CourtCheck.new().check(court_plan, {
		"inward": {"name": "blind monastic cells", "call": Callable(self, "_not_applicable")},
		"builder": builder,
	})
	for failure in court_report.get("failures", []):
		failures.append(str(failure))

	_check_cells(plan, failures, stats)
	_check_verandah(plan, failures, stats)
	_check_shrine(plan, builder, failures)
	_check_well(plan, builder, failures)
	return {"ok": failures.is_empty(), "failures": failures,
		"warnings": court_report.get("warnings", []), "stats": stats,
		"court_replacements": court_report.get("replaced", {})}


func _not_applicable(_plan: HousePlan) -> Array[String]:
	return []


func _check_cells(plan: HousePlan, failures: Array[String], stats: Dictionary) -> void:
	var edges: Array[float] = []
	var cells := 0
	for room in range(plan.room_count()):
		if not plan.kind_of(room) in CELL_KINDS:
			continue
		cells += 1
		var rect: Rect2 = plan.rooms[room].get("rect", Rect2())
		var square_error := absf(rect.size.x - rect.size.y)
		if rect.size.x < 2.5 or rect.size.x > 3.5 or rect.size.y < 2.5 \
				or rect.size.y > 3.5 or square_error > 0.05:
			failures.append("cell_size: cell %d is not a 2.5-3.5m square" % room)
		edges.append((rect.size.x + rect.size.y) * 0.5)
		var veranda_doors := 0
		for di in plan.doors_of(room):
			var door: Dictionary = plan.doors[di]
			if _onto_verandah(plan, door):
				veranda_doors += 1
		if veranda_doors != 1:
			failures.append("cell_door: cell %d has %d doors onto the verandah; expected one" %
				[room, veranda_doors])
		if not plan.windows_of(room).is_empty():
			failures.append("cell_window: cell %d has a window" % room)
	stats["cells"] = cells
	if cells == 0:
		failures.append("cell_size: no monastic cells were planned")
	if not edges.is_empty():
		var mean_edge := 0.0
		for edge in edges:
			mean_edge += edge
		mean_edge /= float(edges.size())
		for i in range(edges.size()):
			if absf(edges[i] - mean_edge) > mean_edge * 0.05 + 0.001:
				failures.append("cell_width: cell %d differs over 5%% from the common module" % i)
				break


func _onto_verandah(plan: HousePlan, door: Dictionary) -> bool:
	var pos: Vector2 = door.get("pos", Vector2.ZERO)
	var normal: Vector2 = door.get("normal", Vector2.ZERO)
	var beyond := pos + normal * (HouseGeometry.wall_thickness(plan.spec) + 0.05)
	for raw_index in plan.world_meta.get("verandah_rooms", []):
		var index := int(raw_index)
		if index < 0 or index >= plan.room_count():
			continue
		if Rect2(plan.rooms[index].get("rect", Rect2())).has_point(beyond):
			return true
	return false


func _check_verandah(plan: HousePlan, failures: Array[String], stats: Dictionary) -> void:
	var court := Rect2(plan.world_meta.get("court_rect", Rect2()))
	var expected := {
		"verandah_west": Rect2(Vector2(court.position.x - VERANDAH, court.position.y),
			Vector2(VERANDAH, court.size.y)),
		"verandah_east": Rect2(Vector2(court.end.x, court.position.y),
			Vector2(VERANDAH, court.size.y)),
		"verandah_front": Rect2(Vector2(court.position.x, court.position.y - VERANDAH),
			Vector2(court.size.x, VERANDAH)),
		"verandah_rear": Rect2(Vector2(court.position.x, court.end.y),
			Vector2(court.size.x, VERANDAH)),
		"verandah_corner_front_west": Rect2(court.position - Vector2.ONE * VERANDAH,
			Vector2.ONE * VERANDAH),
		"verandah_corner_front_east": Rect2(Vector2(court.end.x,
			court.position.y - VERANDAH), Vector2.ONE * VERANDAH),
		"verandah_corner_rear_west": Rect2(Vector2(court.position.x - VERANDAH,
			court.end.y), Vector2.ONE * VERANDAH),
		"verandah_corner_rear_east": Rect2(court.end, Vector2.ONE * VERANDAH),
	}
	var found := {}
	for i in range(plan.room_count()):
		var role := String(plan.rooms[i].get("role", ""))
		if not role.begins_with("verandah_"):
			continue
		found[role] = i
		if expected.has(role) and not _same_rect(Rect2(plan.rooms[i]["rect"]), expected[role]):
			failures.append("verandah_floor: %s no longer fills its continuous strip" % role)
	for role in expected:
		if not found.has(role):
			failures.append("verandah_floor: missing %s" % role)
	stats["verandah_rooms"] = found.size()
	if found.size() == expected.size() and not _verandah_connected(plan, found):
		failures.append("verandah_floor: the four side strips do not join around all corners")


func _verandah_connected(plan: HousePlan, rooms: Dictionary) -> bool:
	var start := int(rooms["verandah_front"])
	var queue: Array[int] = [start]
	var visited := {start: true}
	var graph := plan.door_graph()
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for raw_next in graph.get(current, []):
			var next := int(raw_next)
			if not rooms.values().has(next) or visited.has(next):
				continue
			visited[next] = true
			queue.append(next)
	return visited.size() == rooms.size()


func _same_rect(a: Rect2, b: Rect2) -> bool:
	return a.position.distance_to(b.position) <= 0.01 \
		and a.size.distance_to(b.size) <= 0.01


func _check_shrine(plan: HousePlan, builder: HouseBuilder,
		failures: Array[String]) -> void:
	var shrine := -1
	for i in range(plan.room_count()):
		if String(plan.rooms[i].get("role", "")) == "vihara_shrine":
			if shrine >= 0:
				failures.append("shrine_axis: more than one shrine was planned")
			shrine = i
	if shrine < 0:
		failures.append("shrine_axis: the shrine is missing")
		return
	var court: Rect2 = plan.world_meta.get("court_rect", Rect2())
	var shrine_rect: Rect2 = plan.rooms[shrine].get("rect", Rect2())
	if absf(shrine_rect.get_center().x - court.get_center().x) > 0.05 \
			or shrine_rect.position.y < court.end.y + VERANDAH - 0.05:
		failures.append("shrine_axis: shrine is not centered on the rear wall opposite the entrance")
	var shrine_doors: Array[Dictionary] = []
	for di in plan.doors_of(shrine):
		var door: Dictionary = plan.doors[di]
		if String(door.get("role", "")) == "shrine_axis_door":
			shrine_doors.append(door)
	if shrine_doors.size() != 1:
		failures.append("shrine_door: expected one shrine door onto the rear verandah")
		return
	var axis_door := shrine_doors[0]
	var entry_pos := Vector2.ZERO
	for door in plan.doors:
		if String(door.get("role", "")) == "vihara_entry":
			entry_pos = Vector2(door.get("pos", Vector2.ZERO))
			break
	var shrine_pos: Vector2 = axis_door.get("pos", Vector2.ZERO)
	var facing: Vector2 = axis_door.get("normal", Vector2.ZERO)
	if facing.dot(entry_pos - shrine_pos) < 0.99 \
			or absf(shrine_pos.x - entry_pos.x) > 0.05:
		failures.append("shrine_door: door does not face the entrance on the central axis")
	var start := Vector3(shrine_pos.x, 1.2, shrine_pos.y - VERANDAH * 0.5)
	var finish := Vector3(entry_pos.x, 1.2, court.position.y - VERANDAH * 0.5)
	var blockers: Array[AABB] = []
	for placement in plan.furniture:
		var rect: Rect2 = placement.get("rect", Rect2())
		if rect.has_area():
			blockers.append(AABB(Vector3(rect.position.x, 0.0, rect.position.y),
				Vector3(rect.size.x, plan.spec.height, rect.size.y)))
	for mass in builder.mass_log:
		var name := String(mass.get("name", ""))
		if name != "vihara_well":
			continue
		blockers.append(mass.get("aabb", AABB()))
	if not Sightline.clear(start, finish, blockers):
		failures.append("shrine_sightline: the entrance-to-shrine axis is blocked")


func _check_well(plan: HousePlan, builder: HouseBuilder,
		failures: Array[String]) -> void:
	var court: Rect2 = plan.world_meta.get("court_rect", Rect2())
	var well: Rect2 = plan.world_meta.get("well_rect", Rect2())
	var water_pos: Vector2 = plan.world_meta.get("water_pos", Vector2(INF, INF))
	if not well.has_area() or not court.encloses(well) \
			or water_pos.distance_to(court.get_center()) > 0.1 \
			or well.get_center().distance_to(court.get_center()) > 0.1:
		failures.append("well_center: court well or tank is missing or off-center")
	var found := false
	for mass in builder.mass_log:
		if String(mass.get("name", "")) != "vihara_well":
			continue
		var aabb: AABB = mass.get("aabb", AABB())
		if Vector2(aabb.get_center().x, aabb.get_center().z).distance_to(court.get_center()) <= 0.1:
			found = true
	if not found:
		failures.append("well_emission: centered well geometry was not emitted")
