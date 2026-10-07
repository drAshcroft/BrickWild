extends SceneTree
## Focused diagnosis for the 7x7, two-room cottage's shared cooking/eating hall.
## Run after the current planner/furnisher sources are ready:
## godot --headless --path . --script res://tools/diagnose_compact_cooking.gd

func _initialize() -> void:
	var spec := HouseSpec.new()
	spec.style = &"cottage"
	spec.width = 7.0
	spec.length = 7.0
	spec.height = 2.6
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("length="):
			spec.length = String(arg).substr(7).to_float()
	var plan: HousePlan = HouseGenerator.generate(spec, 1, false)
	var hall := -1
	for room in range(plan.room_count()):
		if plan.kind_of(room) == &"hall":
			hall = room
			break
	print("SPEC style=cottage seed=1 dimensions=", spec.width, "x", spec.length, " derived_rooms=", spec.room_count,
		" plan_rooms=", plan.room_count(), " hall=", hall)
	if hall < 0:
		printerr("No hall in diagnostic request")
		quit(1)
		return
	print("HALL rect=", HouseGeometry.room_floor_rect(plan, hall),
		" area=", HouseGeometry.room_area(plan, hall),
		" domestic_functions=", plan.rooms[hall].get("domestic_functions", []))
	print("RECIPE ", HouseFurnishingRecipes.recipe_for_room(plan, hall))
	print("REQUIRED_SEATS ", HouseFurnisher._household_seat_capacity(plan))
	for door_index in plan.doors_of(hall):
		print("DOOR ", door_index, " ", plan.doors[door_index])

	for room in range(plan.room_count()):
		HouseFurnisher._furnish_room(plan, spec, room)
	_dump_state(plan, hall, "BEFORE_REPAIR")
	var before_nav: Dictionary = HouseNavCheck.new().check(plan)
	print("NAV_BEFORE_REPAIR ", before_nav)
	var removed := HouseFurnishRepair.relax(plan)
	HouseFurnisher._audit_activity_groups(plan)
	print("REPAIR removed=", removed, " compromises=", plan.compromises)
	_dump_state(plan, hall, "AFTER_REPAIR")
	var after_nav: Dictionary = HouseNavCheck.new().check(plan)
	print("NAV_AFTER_REPAIR ", after_nav)
	quit(0)


func _dump_state(plan: HousePlan, hall: int, phase: String) -> void:
	print(phase, " furniture_count=", plan.furniture.size(),
		" dropped_cooking=", plan.was_dropped(hall, "activity:cooking"),
		" dropped_eating=", plan.was_dropped(hall, "activity:eating"))
	for index in range(plan.furniture.size()):
		var piece: Dictionary = plan.furniture[index]
		var room: int = int(piece.get("room", -1))
		var pos: Vector3 = piece.get("pos", Vector3.ZERO)
		print("  F", index, " room=", room,
			" kind=", String(plan.kind_of(room)) if room >= 0 else "none",
			" category=", piece.get("cat", ""), " key=", piece.get("key", ""),
			" group=", piece.get("activity_group", ""),
			" host=", piece.get("activity_host_cat", ""),
			" pos=", pos, " yaw=", piece.get("yaw", 0.0),
			" rect=", piece.get("rect", Rect2()),
			" zone=", piece.get("zone", Rect2()),
			" dropped_tag=", piece.get("dropped_tag", ""))
