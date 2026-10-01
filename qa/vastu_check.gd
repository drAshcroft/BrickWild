class_name VastuCheck
extends RefCounted
## WLD-019 measurable vastu rules over the haveli plan and its emitted details.


func check(plan: HousePlan, supplied_builder: HouseBuilder = null) -> Dictionary:
	var failures: Array[String] = []
	if plan == null or plan.spec == null:
		return {"ok": false, "failures": ["plan: missing haveli plan"], "warnings": []}
	var builder := supplied_builder
	if builder == null:
		builder = HouseBuilder.new()
		builder.build(plan)
	_check_brahmasthana(plan, failures)
	_check_agni(plan, failures)
	_check_jal(plan, builder, failures)
	_check_door(plan, failures)
	_check_light_well(plan, failures)
	_check_jharokha(plan, builder, failures)
	return {"ok": failures.is_empty(), "failures": failures, "warnings": [],
		"stats": {"rooms": plan.room_count(), "masses": builder.mass_log.size()}}


func _check_brahmasthana(plan: HousePlan, failures: Array[String]) -> void:
	var site: Rect2 = plan.world_meta.get("site", Rect2())
	var court: Rect2 = plan.world_meta.get("court_rect", Rect2())
	var cell := Vector2(site.size.x / 9.0, site.size.y / 9.0)
	var central := Rect2(site.position + cell * 4.0, cell)
	if not court.encloses(central):
		failures.append("brahmasthana: the open court does not contain the central 9x9 cell")
		return
	for room in plan.rooms:
		if int(room.get("storey", 0)) == 0 \
				and Rect2(room.get("rect", Rect2())).intersects(central, true):
			failures.append("brahmasthana: a ground-floor room occupies the central cell")
			return


func _check_agni(plan: HousePlan, failures: Array[String]) -> void:
	var site: Rect2 = plan.world_meta.get("site", Rect2())
	var room := int(plan.world_meta.get("kitchen_room", -1))
	if room < 0 or room >= plan.room_count() or plan.kind_of(room) != &"kitchen":
		failures.append("agni: the haveli has no authored kitchen")
		return
	var center: Vector2 = Rect2(plan.rooms[room]["rect"]).get_center()
	if center.x <= site.get_center().x or center.y >= site.get_center().y:
		failures.append("agni: the kitchen is not in the south-east quadrant")


func _check_jal(plan: HousePlan, builder: HouseBuilder,
		failures: Array[String]) -> void:
	var site: Rect2 = plan.world_meta.get("site", Rect2())
	var well: Rect2 = plan.world_meta.get("well_rect", Rect2())
	if not well.has_area() or not site.encloses(well) \
			or well.get_center().x <= site.get_center().x \
			or well.get_center().y <= site.get_center().y:
		failures.append("jal: the well is not in the north-east quadrant")
		return
	if builder.mass_aabb("vastu_well").size == Vector3.ZERO:
		failures.append("jal: the north-east well has no emitted mass")


func _check_door(plan: HousePlan, failures: Array[String]) -> void:
	var entrance := plan.entrance()
	if entrance < 0:
		failures.append("door: the haveli has no front door")
		return
	var normal: Vector2 = plan.doors[entrance].get("normal", Vector2.ZERO)
	if normal.x < 0.9 and normal.y > -0.9:
		failures.append("door: the entrance does not face east or north in the site frame")
	if not is_finite(float(plan.spec.orientation)):
		failures.append("door: the site orientation is not finite")


func _check_light_well(plan: HousePlan, failures: Array[String]) -> void:
	var court: Rect2 = plan.world_meta.get("court_rect", Rect2())
	var eave := float(plan.world_meta.get("eave_height", 0.0))
	if not court.has_area() or court.size.x > eave + 0.01:
		failures.append("light_well: court width exceeds one eave height")


func _check_jharokha(plan: HousePlan, builder: HouseBuilder,
		failures: Array[String]) -> void:
	var site: Rect2 = plan.world_meta.get("site", Rect2())
	var found := 0
	for mass in builder.mass_log:
		if not String(mass.get("name", "")).begins_with("jharokha"):
			continue
		var aabb: AABB = mass.get("aabb", AABB())
		var foot := Rect2(Vector2(aabb.position.x, aabb.position.z),
			Vector2(aabb.size.x, aabb.size.z))
		if aabb.position.y + 0.01 >= plan.spec.height and not site.encloses(foot):
			found += 1
	if found < 1:
		failures.append("jharokha: no upper-storey projection extends outside the street facade")
