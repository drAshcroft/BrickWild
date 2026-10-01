class_name VavCheck
extends RefCounted
## WLD-016 plan and emitted-geometry rules for descending stepwells.

func check(plan: HousePlan, builder: VavBuilder) -> Dictionary:
	var failures: Array[String] = []
	var meta: Dictionary = plan.world_meta
	_check_identity(plan, failures)
	_check_descent(plan, builder, failures)
	_check_narrowing(plan, failures)
	_check_pavilions(plan, builder, failures)
	_check_tank(plan, builder, failures)
	_check_shaft(plan, builder, failures)
	_check_water(plan, builder, failures)
	_check_walk(plan, failures)
	_check_sky(plan, builder, failures)
	_check_grounding(builder, failures)
	return {"ok": failures.is_empty(), "failures": failures, "warnings": [],
		"stats": {"negative_storeys": plan.rooms.size() - 1,
			"flights": plan.stairs.size(), "pavilions": meta.get("pavilions", []).size(),
			"masses": builder.mass_log.size()}}


func _check_identity(plan: HousePlan, failures: Array[String]) -> void:
	if plan.world_family != VavGenerator.FAMILY or plan.world_subkind != VavGenerator.SUBKIND:
		failures.append("identity: plan is not the Queen's Well stepwell")
	if plan.spec == null or plan.spec.storeys != 1:
		failures.append("identity: the stepwell shell must not be represented as raised floors")


func _check_descent(plan: HousePlan, builder: VavBuilder, failures: Array[String]) -> void:
	var landings: Array = plan.world_meta.get("landings", [])
	var expected_drop := float(plan.world_meta.get("total_drop", 0.0))
	if landings.size() != VavGenerator.LEVELS + 1 or plan.stairs.size() != VavGenerator.LEVELS:
		failures.append("descent: requires seven negative storeys and seven connecting flights")
		return
	for i in range(landings.size()):
		var level := int(landings[i].get("storey", 1))
		var elevation := float(landings[i].get("y", INF))
		if level != -i or absf(elevation + float(i) * expected_drop / float(VavGenerator.LEVELS)) > 0.02:
			failures.append("descent: landing %d has no matching negative storey/elevation" % i)
		var room: Dictionary = plan.rooms[i]
		var room_rect: Rect2 = room.get("rect", Rect2())
		var planned_rect: Rect2 = landings[i].get("rect", Rect2())
		if int(room.get("storey", 1)) != level \
				or absf(float(room.get("elevation", INF)) - elevation) > 0.02 \
				or room_rect.position.distance_to(planned_rect.position) > 0.02 \
				or room_rect.size.distance_to(planned_rect.size) > 0.02:
			failures.append("descent: landing %d differs between HousePlan and descent graph" % i)
		var rect: Rect2 = landings[i].get("rect", Rect2())
		if rect.size.x < 2.0 or rect.size.y < 2.0:
			failures.append("descent: landing %d is not standable" % i)
		if i < plan.stairs.size():
			var flight: Dictionary = plan.stairs[i]
			if int(flight.get("storey", 1)) != -i or int(flight.get("to_storey", 1)) != -(i + 1) \
					or int(flight.get("a", -1)) != int(landings[i].get("id", -1)) \
					or int(flight.get("b", -1)) != int(landings[i + 1].get("id", -1)):
				failures.append("descent: flight %d does not join adjacent negative storeys" % i)
			if float(flight.get("rise", 0.0)) <= 0.0 or float(flight.get("run", 0.0)) < 2.0 \
					or int(flight.get("steps", 0)) < 6:
				failures.append("descent: flight %d has no usable descending treads" % i)
			var slope := rad_to_deg(atan(float(flight.get("rise", INF)) /
				maxf(float(flight.get("run", 0.0)), 0.001)))
			if slope > 40.0:
				failures.append("descent: flight %d slope %.1f degrees exceeds 40" % [i, slope])
			var emitted_treads := 0
			for mass in builder.mass_log:
				if String(mass.get("name", "")).begins_with("stair_%d_tread_" % i):
					emitted_treads += 1
			if emitted_treads < int(flight.get("steps", 0)):
				failures.append("descent: flight %d emitted %d of %d planned treads" %
					[i, emitted_treads, int(flight.get("steps", 0))])
	var wall_found := false
	for mass in builder.mass_log:
		if String(mass.get("name", "")).begins_with("retaining_wall"):
			var a: AABB = mass["aabb"]
			wall_found = wall_found or (absf(a.position.y + expected_drop) < 0.02 \
				and absf(a.end.y) < 0.02 and MassRules.is_negative(mass))
	if not wall_found:
		failures.append("descent: emitted retaining walls do not span the excavation")


func _check_narrowing(plan: HousePlan, failures: Array[String]) -> void:
	for i in range(1, plan.rooms.size()):
		var previous: Rect2 = plan.rooms[i - 1]["rect"]
		var current: Rect2 = plan.rooms[i]["rect"]
		var ratio := current.size.x / maxf(previous.size.x, 0.001)
		if ratio < 0.88 or ratio >= 1.0:
			failures.append("narrowing: level %d width ratio %.3f is not a straight inward step" % [i, ratio])
		if i - 1 >= plan.stairs.size():
			failures.append("narrowing: level %d has no flight between terrace profiles" % i)
			continue
		var flight: Rect2 = plan.stairs[i - 1].get("rect", Rect2())
		if flight.position.x < current.end.x - 0.02 or flight.end.x > previous.position.x + 0.02:
			failures.append("narrowing: flight %d leaves its consecutive terrace envelope" % (i - 1))


func _check_pavilions(plan: HousePlan, builder: VavBuilder, failures: Array[String]) -> void:
	var pavilions: Array = plan.world_meta.get("pavilions", [])
	if pavilions.size() != plan.rooms.size():
		failures.append("pavilions: every one of the eight landings needs its own pavilion")
	for pavilion in pavilions:
		if builder.mass_aabb(String(pavilion.get("id", "missing"))).size == Vector3.ZERO:
			failures.append("pavilions: %s has no emitted roof mass" % String(pavilion.get("id", "missing")))
			continue
		var column_count := 0
		for mass in builder.mass_log:
			if String(mass.get("name", "")) == String(pavilion["id"]) + "_column":
				column_count += 1
		if column_count < 4:
			failures.append("pavilions: %s has fewer than four emitted supports" % String(pavilion["id"]))
		var stair_width := float(plan.world_meta.get("stair_width", INF))
		var pavilion_size: Vector2 = pavilion.get("size", Vector2.ZERO)
		if pavilion_size.x < stair_width * 1.5:
			failures.append("pavilions: %s is not 1.5 times wider than the stair" % String(pavilion["id"]))


func _check_tank(plan: HousePlan, builder: VavBuilder, failures: Array[String]) -> void:
	var tank: Rect2 = plan.world_meta.get("tank", Rect2())
	var bottom := float(plan.world_meta.get("tank_floor_y", 0.0))
	var floor := builder.mass_aabb("tank_floor")
	if tank.size.x < 2.0 or tank.size.y < 2.0 or floor.size == Vector3.ZERO \
			or absf(floor.position.y - bottom) > 0.02 \
			or absf(floor.position.x - tank.position.x) > 0.02 \
			or absf(floor.position.z - tank.position.y) > 0.02 \
			or absf(floor.size.x - tank.size.x) > 0.02 \
			or absf(floor.size.z - tank.size.y) > 0.02:
		failures.append("tank: no emitted basin floor matches the bottom plan")
	var walls := 0
	for mass in builder.mass_log:
		if String(mass.get("name", "")) != "tank_wall":
			continue
		walls += 1
		if absf((mass["aabb"] as AABB).position.y - bottom) > 0.02:
			failures.append("tank: tank wall is not founded on the basin floor")
	if walls < 3:
		failures.append("tank: three retaining basin walls were not emitted")


func _check_shaft(plan: HousePlan, builder: VavBuilder, failures: Array[String]) -> void:
	var shaft: Rect2 = plan.world_meta.get("shaft", Rect2())
	var bottom := float(plan.world_meta.get("shaft_bottom_y", 0.0))
	var tank_floor := float(plan.world_meta.get("tank_floor_y", 0.0))
	var found := 0
	var components := builder.components_of("draw_shaft")
	var expected_radius := minf(shaft.size.x, shaft.size.y) * 0.5 - 0.12
	for mass in builder.mass_log:
		if not String(mass.get("name", "")).begins_with("shaft_wall"):
			continue
		found += 1
		var a: AABB = mass["aabb"]
		if absf(a.position.y - bottom) > 0.02 or absf(a.end.y) > 0.02:
			failures.append("shaft: emitted shaft wall does not run below the tank from grade")
	var round_shaft_valid := components.size() == 12
	for component in components:
		if String(component.get("form", "")) != "box":
			round_shaft_valid = false
			continue
		var xf: Transform3D = component["xf"]
		var radial := Vector2(xf.origin.x, xf.origin.z).distance_to(shaft.get_center())
		if absf(radial - expected_radius) > 0.03:
			round_shaft_valid = false
	if shaft.size.x < 1.0 or shaft.size.y < 1.0 or found != 12 \
			or bottom >= tank_floor or not round_shaft_valid:
		failures.append("shaft: twelve sides of a deep draw shaft are required")


func _check_water(plan: HousePlan, builder: VavBuilder, failures: Array[String]) -> void:
	var water := builder.mass_aabb("water")
	var tank: Rect2 = plan.world_meta.get("tank", Rect2())
	var expected_y := float(plan.world_meta.get("water_y", INF))
	if water.size == Vector3.ZERO or absf(water.get_center().y - expected_y) > 0.02 \
			or water.position.x < tank.position.x or water.end.x > tank.end.x \
			or water.position.z < tank.position.y or water.end.z > tank.end.y:
		failures.append("water: emitted water is missing, misplaced or outside its tank")
	if float(plan.world_meta.get("water_y", INF)) <= float(plan.world_meta.get("tank_floor_y", 0.0)):
		failures.append("water: water surface is not above the tank floor")


func _check_walk(plan: HousePlan, failures: Array[String]) -> void:
	for i in range(plan.rooms.size()):
		var rect: Rect2 = plan.rooms[i].get("rect", Rect2())
		var grid := WalkGrid.new()
		grid.setup(rect.grow(0.6), 0.2)
		grid.add_floor(rect)
		grid.build(0.32)
		if not grid.flood_from(rect.get_center()):
			failures.append("walk: negative-storey landing %d has no body-clear standing route" % i)
	var apron: Rect2 = plan.world_meta.get("entry_apron", Rect2())
	var first: Rect2 = plan.rooms[0].get("rect", Rect2()) if not plan.rooms.is_empty() else Rect2()
	if apron.size.x <= 0.0 or apron.size.y <= 0.0:
		failures.append("walk: the grade entrance has no emitted approach floor")
		return
	var route := WalkGrid.new()
	route.setup(apron.merge(first).grow(0.6), 0.2)
	route.add_floor(apron)
	route.add_floor(first)
	route.build(0.32)
	var entry: Vector2 = plan.world_meta.get("entry", Vector2.ZERO)
	if not route.flood_from(entry):
		failures.append("walk: grade entrance does not reach the first landing")
	_check_tank_walk(plan, failures)


func _check_tank_walk(plan: HousePlan, failures: Array[String]) -> void:
	var last: Rect2 = plan.rooms.back().get("rect", Rect2())
	var tank: Rect2 = plan.world_meta.get("tank", Rect2())
	var access: Rect2 = plan.world_meta.get("tank_access", Rect2())
	var bounds := last.merge(access).grow(0.6)
	var grid := WalkGrid.new()
	grid.setup(bounds, 0.2)
	grid.add_floor(last)
	for strip in plan.world_meta.get("tank_walk", []):
		grid.add_floor(strip)
	grid.add_obstacle(tank)
	var shaft: Rect2 = plan.world_meta.get("shaft", Rect2())
	grid.add_obstacle(shaft)
	grid.build(0.32)
	if not grid.flood_from(last.get_center()):
		failures.append("water: the final landing has no route to the tank edge")
		return
	var points := [Vector2(tank.get_center().x, access.position.y + 0.55),
		Vector2(tank.get_center().x, access.end.y - 0.55),
		Vector2(access.position.x + 0.55, tank.get_center().y),
		Vector2(access.end.x - 0.55, tank.get_center().y)]
	var reached_sides := 0
	for p in points:
		if is_finite(grid.distance_to(p, 0.8)):
			reached_sides += 1
	if reached_sides < 3:
		failures.append("water: the flood reaches only %d sides of the tank, needs three" % reached_sides)


func _check_sky(plan: HousePlan, builder: VavBuilder, failures: Array[String]) -> void:
	var corridor: Rect2 = plan.world_meta.get("corridor", Rect2())
	for mass in builder.mass_log:
		var name := String(mass.get("name", ""))
		if name.begins_with("pavilion") or name.begins_with("shaft_wall"):
			continue
		var a: AABB = mass["aabb"]
		var horizontal := Rect2(Vector2(a.position.x, a.position.z),
			Vector2(a.size.x, a.size.z))
		if a.position.y >= 0.02 and horizontal.intersects(corridor, true):
			failures.append("sky: mass %s covers the open stair corridor" % name)
			return


func _check_grounding(builder: VavBuilder, failures: Array[String]) -> void:
	if builder.mass_log.is_empty():
		failures.append("masses: the stepwell emitted no structural log")
		return
	for issue in MassRules.grounded(builder.mass_log, []):
		failures.append("grounded: %s" % String(issue))
