class_name HanCheck
extends RefCounted
## WLD-006: checks the gate, cells, stable thresholds, winter hall and kiosk.

const CELL_KINDS := [&"guest_room", &"stable"]


func check(plan: HousePlan, supplied_builder: HouseBuilder = null) -> Dictionary:
	var failures: Array[String] = []
	var stats := {"cells": 0, "stable_cells": 0, "court_doors": 0}
	if plan == null or plan.spec == null:
		return {"ok": false, "failures": ["plan: missing Han plan or spec"], "warnings": [], "stats": stats}
	var builder := supplied_builder
	if builder == null:
		builder = HouseBuilder.new()
		builder.build(plan)

	# A small court-only view lets CourtCheck measure its real sky and ring
	# rules. Han cells replace domestic inwardness and court proportions.
	var court_plan := HousePlan.new()
	court_plan.spec = plan.spec
	court_plan.rooms = plan.rooms
	court_plan.doors = plan.doors
	court_plan.windows = plan.windows
	court_plan.furniture = plan.furniture
	court_plan.courts = plan.courts
	court_plan.stairs = plan.stairs
	var court_report := CourtCheck.new().check(court_plan, {
		"inward": {"name": "Han cell openings", "call": Callable(self, "_not_applicable")},
		"proportion": {"name": "Han court envelope", "call": Callable(self, "_not_applicable")},
	})
	for failure in court_report.get("failures", []):
		failures.append(str(failure))

	_check_gate(plan, failures)
	_check_cells(plan, failures, stats)
	_check_winter_hall(plan, builder, failures)
	_check_kiosk(plan, builder, failures)
	return {"ok": failures.is_empty(), "failures": failures,
		"warnings": court_report.get("warnings", []), "stats": stats,
		"court_replacements": court_report.get("replaced", {})}


func _not_applicable(_plan: HousePlan) -> Array[String]:
	return []


func _check_gate(plan: HousePlan, failures: Array[String]) -> void:
	var exterior_doors: Array[Dictionary] = []
	for door in plan.doors:
		var pos: Vector2 = door.get("pos", Vector2.ZERO)
		var normal: Vector2 = door.get("normal", Vector2.ZERO)
		if bool(door.get("exterior", false)) or _on_outer_wall(plan, pos, normal):
			exterior_doors.append(door)
	if exterior_doors.size() != 1:
		failures.append("gate: expected one exterior gate, found %d" % exterior_doors.size())
	var gates := 0
	for door in exterior_doors:
		if String(door.get("role", "")) != "han_gate":
			continue
		gates += 1
		var clear_height := float(door.get("head", HouseGeometry.DOOR_H)) - float(door.get("sill", 0.0))
		if float(door.get("width", 0.0)) < 2.6 or clear_height < 3.0:
			failures.append("gate: exterior opening is smaller than 2.6 x 3.0m")
	if gates != 1:
		failures.append("gate: no unique Sultan's Han gate is present")

	var site := HouseGeometry.site_rect(plan.spec)
	var wall_t := HouseGeometry.wall_thickness(plan.spec)
	for wi in range(plan.windows.size()):
		var window: Dictionary = plan.windows[wi]
		var pos: Vector2 = window.get("pos", Vector2.ZERO)
		var normal: Vector2 = window.get("normal", Vector2.ZERO)
		var exterior := (absf(pos.y - site.position.y) <= wall_t + 0.1 and normal.y < -0.5) \
			or (absf(pos.y - site.end.y) <= wall_t + 0.1 and normal.y > 0.5) \
			or (absf(pos.x - site.position.x) <= wall_t + 0.1 and normal.x < -0.5) \
			or (absf(pos.x - site.end.x) <= wall_t + 0.1 and normal.x > 0.5)
		if exterior and float(window.get("sill", 0.0)) < 2.2:
			failures.append("outer_opening: low exterior window %d weakens the protected wall" % wi)


func _check_cells(plan: HousePlan, failures: Array[String], stats: Dictionary) -> void:
	var cell_count := 0
	for room in range(plan.room_count()):
		var kind := plan.kind_of(room)
		if not kind in CELL_KINDS:
			continue
		cell_count += 1
		var clear_floor := HouseGeometry.room_floor_rect(plan, room)
		if minf(clear_floor.size.x, clear_floor.size.y) < 3.0:
			failures.append("cell: room %d is smaller than a 3 x 3m clear cell" % room)
		var court_doors := 0
		var widest := 0.0
		for di in plan.doors_of(room):
			var door: Dictionary = plan.doors[di]
			if _onto_court(plan, Vector2(door.get("pos", Vector2.ZERO)),
					Vector2(door.get("normal", Vector2.ZERO))):
				court_doors += 1
				widest = maxf(widest, float(door.get("width", 0.0)))
		if court_doors != 1:
			failures.append("cell_door: room %d has %d court-facing doors; expected one" % [room, court_doors])
		stats["court_doors"] = int(stats["court_doors"]) + court_doors
		if kind == &"stable":
			stats["stable_cells"] = int(stats["stable_cells"]) + 1
			if widest < 1.5:
				failures.append("stable: room %d court door is narrower than 1.5m" % room)
	stats["cells"] = cell_count
	if cell_count == 0:
		failures.append("cell: no guest or stable cells were planned")
	if int(stats["stable_cells"]) == 0:
		failures.append("stable: no stable cell was planned")


func _check_winter_hall(plan: HousePlan, builder: HouseBuilder,
		failures: Array[String]) -> void:
	var hall_index := -1
	for room in range(plan.room_count()):
		if String(plan.rooms[room].get("role", "")) == "winter_hall":
			hall_index = room
			break
	if hall_index < 0:
		failures.append("winter_hall: no winter hall is planned")
		return
	var court: Rect2 = plan.world_meta.get("court_rect", Rect2())
	var hall: Rect2 = plan.rooms[hall_index].get("rect", Rect2())
	var gate_pos := Vector2.ZERO
	for door in plan.doors:
		if String(door.get("role", "")) == "han_gate":
			gate_pos = Vector2(door.get("pos", Vector2.ZERO))
			break
	if absf(hall.get_center().x - court.get_center().x) > 0.5 \
			or hall.position.y < court.end.y - 0.1 \
			or gate_pos.y >= court.get_center().y:
		failures.append("winter_hall: hall is not centered on the far side opposite the gate")
	var dome := _named_mass(builder, "han_winter_dome")
	if dome.is_empty():
		failures.append("winter_dome: emitted winter-hall dome mass is missing")
		return
	var aabb: AABB = dome["aabb"]
	var dome_centre := Vector2(aabb.get_center().x, aabb.get_center().z)
	if dome_centre.distance_to(hall.get_center()) > 0.3 or aabb.size.y < 2.0:
		failures.append("winter_dome: dome mass is not centered over the winter hall")


func _check_kiosk(plan: HousePlan, builder: HouseBuilder,
		failures: Array[String]) -> void:
	var kiosk := _named_mass(builder, "han_kiosk")
	if kiosk.is_empty():
		failures.append("kiosk: raised kiosk mass is missing")
		return
	var court: Rect2 = plan.world_meta.get("court_rect", Rect2())
	var flood: Rect2 = plan.world_meta.get("flood_rect", Rect2())
	var aabb: AABB = kiosk["aabb"]
	var centre := Vector2(aabb.get_center().x, aabb.get_center().z)
	var kiosk_rect := Rect2(Vector2(aabb.position.x, aabb.position.z),
		Vector2(aabb.size.x, aabb.size.z))
	if centre.distance_to(court.get_center()) > 0.2 or aabb.size.y < 2.0:
		failures.append("kiosk: kiosk is not a raised mass at the court centre")
	var water_parts: Array[AABB] = []
	for part in builder.component_log:
		if String(part.get("role", "")) == "han_court_flood":
			water_parts.append(MassBuilder.component_aabb(part))
	var reaches := {"left": false, "right": false, "front": false, "rear": false}
	for water_aabb in water_parts:
		var water_centre := Vector2(water_aabb.get_center().x, water_aabb.get_center().z)
		if water_centre.x < centre.x:
			reaches["left"] = true
		if water_centre.x > centre.x:
			reaches["right"] = true
		if water_centre.y < centre.y:
			reaches["front"] = true
		if water_centre.y > centre.y:
			reaches["rear"] = true
	var all_sides := true
	for side in reaches:
		all_sides = all_sides and bool(reaches[side])
	if water_parts.size() != 4 or not all_sides \
			or not court.encloses(flood) or not flood.encloses(kiosk_rect.grow(0.2)) \
			or plan.water_plane <= 0.0:
		failures.append("flood: water does not reach every side of the raised kiosk")


func _named_mass(builder: HouseBuilder, name: String) -> Dictionary:
	for mass in builder.mass_log:
		if String(mass.get("name", "")) == name:
			return mass
	return {}


func _onto_court(plan: HousePlan, pos: Vector2, normal: Vector2) -> bool:
	var outside := pos + normal * (HouseGeometry.wall_thickness(plan.spec) + 0.05)
	for court in plan.courts:
		if int(court.get("storey", 0)) > 0:
			continue
		if Rect2(court["rect"]).has_point(outside):
			return true
	return false


func _on_outer_wall(plan: HousePlan, pos: Vector2, normal: Vector2) -> bool:
	var site := HouseGeometry.site_rect(plan.spec)
	var tol := HouseGeometry.wall_thickness(plan.spec) + 0.1
	return (absf(pos.y - site.position.y) <= tol and normal.y < -0.5) \
		or (absf(pos.y - site.end.y) <= tol and normal.y > 0.5) \
		or (absf(pos.x - site.position.x) <= tol and normal.x < -0.5) \
		or (absf(pos.x - site.end.x) <= tol and normal.x > 0.5)
