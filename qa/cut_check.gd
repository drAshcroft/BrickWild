class_name CutCheck
extends RefCounted
## WLD-015 rules for a temple carved down from a per-building ground datum.


func check(plan: HousePlan, builder: CutTempleBuilder) -> Dictionary:
	var failures: Array[String] = []
	_check_identity(plan, failures)
	_check_negative(plan, builder, failures)
	_check_free_standing(plan, builder, failures)
	_check_bridge(plan, builder, failures)
	_check_axis(plan, failures)
	_check_sky(plan, builder, failures)
	_check_gallery(plan, builder, failures)
	return {"ok": failures.is_empty(), "failures": failures, "warnings": [],
		"stats": {"masses": builder.mass_log.size(),
			"gallery_segments": plan.world_meta.get("gallery", []).size()}}


func _check_identity(plan: HousePlan, failures: Array[String]) -> void:
	if plan.world_family != CutTempleGenerator.FAMILY \
			or plan.world_subkind != CutTempleGenerator.SUBKIND:
		failures.append("identity: plan is not the Quarried Temple")
	var pit: Rect2 = plan.world_meta.get("pit", Rect2())
	var site := HouseGeometry.site_rect(plan.spec)
	if pit.position.distance_to(site.position) > 0.02 or pit.size.distance_to(site.size) > 0.02:
		failures.append("negative: the pit rectangle is not the authored site")


func _check_negative(plan: HousePlan, builder: CutTempleBuilder,
		failures: Array[String]) -> void:
	var ground := float(plan.world_meta.get("ground_level", INF))
	if not is_finite(ground):
		failures.append("negative: no per-building ground level was retained")
		return
	var negative_rooms := 0
	for room in plan.rooms:
		if String(room.get("role", "")) == "gateway":
			continue
		if int(room.get("storey", 0)) >= 0 or float(room.get("elevation", 0.0)) >= ground:
			failures.append("negative: occupied temple room is not on a negative storey")
		else:
			negative_rooms += 1
	if negative_rooms < 4:
		failures.append("negative: the temple lacks its negative-storey programme")
	for mass in builder.mass_log:
		var name := String(mass.get("name", ""))
		if name.begins_with("gateway"):
			continue
		var a: AABB = mass.get("aabb", AABB())
		if a.end.y > ground + MassRules.TOL:
			failures.append("negative: %s rises %.2fm above the ground datum" %
				[name, a.end.y - ground])


func _check_free_standing(plan: HousePlan, builder: CutTempleBuilder,
		failures: Array[String]) -> void:
	var walls: Array[AABB] = []
	for mass in builder.mass_log:
		if String(mass.get("name", "")).begins_with("pit_wall"):
			walls.append(mass["aabb"])
	if walls.size() != 4:
		failures.append("free-standing: four emitted pit faces are required")
		return
	var checked := 0
	for mass in builder.mass_log:
		var name := String(mass.get("name", ""))
		if not _is_temple_mass(name):
			continue
		checked += 1
		for wall in walls:
			var clearance := MassRules.separation(mass["aabb"], wall)
			if clearance + 0.02 < CastleGeometry.BAILEY_CLEAR:
				failures.append("free-standing: %s is only %.2fm from the pit wall" %
					[name, clearance])
				break
	if checked == 0:
		failures.append("free-standing: no temple masses were emitted inside the pit")


func _check_bridge(plan: HousePlan, builder: CutTempleBuilder,
		failures: Array[String]) -> void:
	var bridge: Rect2 = plan.world_meta.get("bridge_rect", Rect2())
	var emitted := builder.mass_aabb("bridge")
	if bridge.size.x < 1.2 or emitted.size == Vector3.ZERO \
			or absf(emitted.size.x - bridge.size.x) > 0.02:
		failures.append("bridge: a measured crossing at least 1.2m wide is required")
		return
	var grid := _walk_grid(plan)
	var front := Vector2(bridge.get_center().x, bridge.position.y + 0.35)
	var rear := Vector2(bridge.get_center().x, bridge.end.y - 0.35)
	if not grid.flood_from(front, 0.32) or not is_finite(grid.distance_to(rear, 0.5)):
		failures.append("bridge: the walk does not reach both ends of the rock bridge")


func _check_axis(plan: HousePlan, failures: Array[String]) -> void:
	var axis := float(plan.world_meta.get("axis_x", 0.0))
	var marks: Array = plan.world_meta.get("axis_marks", [])
	if marks.size() != 5:
		failures.append("axis: gate, Nandi, porch, hall and sanctum are required")
		return
	var previous_z := -INF
	var pit: Rect2 = plan.world_meta.get("pit", Rect2())
	for mark in marks:
		var rect: Rect2 = mark.get("rect", Rect2())
		if absf(rect.get_center().x - axis) > plan.spec.width * 0.02:
			failures.append("axis: %s is off the processional line" % String(mark.get("name", "mass")))
		if rect.get_center().y <= previous_z or not pit.has_point(rect.get_center()):
			failures.append("axis: ritual stations are not ordered inside the pit")
		previous_z = rect.get_center().y


func _check_sky(plan: HousePlan, builder: CutTempleBuilder,
		failures: Array[String]) -> void:
	var sky: Rect2 = plan.world_meta.get("sky_rect", Rect2())
	var floor_y := float(plan.world_meta.get("gallery_y", -INF))
	if sky.size.x < 2.0 or sky.size.y < 2.0:
		failures.append("sky: the quarried court has no measurable open patch")
		return
	for mass in builder.mass_log:
		var name := String(mass.get("name", ""))
		if name.begins_with("pit_") or name.begins_with("gallery_"):
			continue
		var a: AABB = mass["aabb"]
		var footprint := Rect2(Vector2(a.position.x, a.position.z),
			Vector2(a.size.x, a.size.z))
		var overlap := footprint.intersection(sky)
		if overlap.get_area() > 0.04 and a.end.y > floor_y + 0.5:
			failures.append("sky: %s roofs the open quarried court" % name)
			return


func _check_gallery(plan: HousePlan, builder: CutTempleBuilder,
		failures: Array[String]) -> void:
	var gallery: Array = plan.world_meta.get("gallery", [])
	if gallery.size() != 4:
		failures.append("gallery: the pit-wall colonnade needs four floor strips")
		return
	for i in range(4):
		if builder.mass_aabb("gallery_floor_%d" % i).size == Vector3.ZERO:
			failures.append("gallery: emitted floor strip %d is missing" % i)
	var grid := _walk_grid(plan)
	var bridge: Rect2 = plan.world_meta.get("bridge_rect", Rect2())
	if not grid.flood_from(Vector2(bridge.get_center().x, bridge.position.y + 0.35), 0.32):
		failures.append("gallery: the bridge does not enter the pit-wall walk")
		return
	for i in range(gallery.size()):
		if not is_finite(grid.distance_to((gallery[i] as Rect2).get_center(), 0.8)):
			failures.append("gallery: walk flood does not reach floor strip %d" % i)


func _walk_grid(plan: HousePlan) -> WalkGrid:
	var pit: Rect2 = plan.world_meta.get("pit", Rect2())
	var grid := WalkGrid.new()
	grid.setup(pit.grow(0.5), 0.2)
	for rect in plan.world_meta.get("gallery", []):
		grid.add_floor(rect)
	for key in ["bridge_rect", "nandi_rect", "porch_rect", "hall_rect", "sanctum_rect"]:
		grid.add_floor(plan.world_meta.get(key, Rect2()))
	grid.build(0.32)
	return grid


static func _is_temple_mass(name: String) -> bool:
	return name.begins_with("temple_") or name.begins_with("nandi_") \
		or name.begins_with("porch_") or name.begins_with("hall_") \
		or name.begins_with("sanctum_") or name.begins_with("shikhara_")
