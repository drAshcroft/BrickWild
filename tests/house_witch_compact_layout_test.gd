extends SceneTree
## Staged plan-only contract for the 7x9 Witch Hut compact fallback.

var failures: Array[String] = []

func _init() -> void:
	var spec := HouseSpec.new()
	spec.style = &"witch_hut"
	spec.width = 7.0
	spec.length = 9.0
	spec.height = 2.6
	var plan := HouseGenerator.generate(spec, 1, false)
	for seed in [1, 8102]:
		_check_real_plan(HouseGenerator.generate(spec, int(seed), false), int(seed))
	_check_role_loss_fallback(plan)
	var second := HouseGenerator.generate(spec, 1, false)
	_check_store_loss_fallback(second)
	_check_existing_kitchen_witchwork_refresh()
	for failure in failures:
		printerr("FAIL " + failure)
	print("witch compact layout: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _check_real_plan(plan: HousePlan, seed: int) -> void:
	var who := "witch_hut 7x9 seed=%d" % seed
	if plan.domestic_layout.get("status", &"") != &"planned":
		failures.append("%s did not produce a planned layout: %s" % [who, plan.domestic_layout.get("reason", "")])
		return
	if plan.rooms.size() != 3 or plan.domestic_layout.get("planned_rooms", 0) != 3:
		failures.append("%s should use three physical rooms with merged activity contracts and dry storage" % who)
		return
	var halls := plan.rooms_of(&"hall")
	var beds := plan.rooms_of(&"bedroom")
	var stores := plan.rooms_of(&"store")
	if halls.size() != 1 or beds.size() != 1 or stores.size() != 1:
		failures.append("%s needs one lived hall, private bedroom, and dry store" % who)
		return
	var hall := halls[0]
	var bed := beds[0]
	var store := stores[0]
	var inner := HouseGeometry.interior_rect(plan.spec)
	var hall_rect: Rect2 = plan.rooms[hall]["rect"]
	var bed_rect: Rect2 = plan.rooms[bed]["rect"]
	var hall_floor := HouseGeometry.room_floor_rect(plan, hall)
	var bed_floor := HouseGeometry.room_floor_rect(plan, bed)
	var store_floor := HouseGeometry.room_floor_rect(plan, store)
	if absf(hall_rect.position.y - inner.position.y) > 0.02 \
			or absf(hall_rect.size.x - inner.size.x) > 0.02:
		failures.append("%s hall does not span the front entry wall" % who)
	if absf(hall_floor.size.x - 6.3) > 0.03 or absf(hall_floor.size.y - 4.62) > 0.03:
		failures.append("%s shared hall clear floor is %.2fx%.2f, expected 6.30x4.62" % [who, hall_floor.size.x, hall_floor.size.y])
	if minf(bed_floor.size.x, bed_floor.size.y) < 3.3:
		failures.append("%s private bedroom clear floor is below the 3.3m minimum" % who)
	if absf(bed_floor.size.y - 3.52) > 0.03:
		failures.append("%s rear bedroom depth is %.2fm, expected 3.52m" % [who, bed_floor.size.y])
	if HouseGeometry.room_aspect(plan, hall) > HouseGeometry.aspect_max(&"hall") \
			or HouseGeometry.room_aspect(plan, bed) > HouseGeometry.aspect_max(&"bedroom") \
			or HouseGeometry.room_aspect(plan, store) > HouseGeometry.aspect_max(&"store"):
		failures.append("%s violates the existing room aspect limits" % who)
	if plan.entrance_room() != hall:
		failures.append("%s front entrance does not lead to the lived hall" % who)
	if not _rooms_share_door(plan, hall, bed):
		failures.append("%s bedroom is not directly served from the hall" % who)
	if not _rooms_share_door(plan, hall, store):
		failures.append("%s dry store is not directly served from the hall" % who)
	if minf(store_floor.size.x, store_floor.size.y) < 1.6:
		failures.append("%s dry store is below its existing minimum floor size" % who)
	var store_functions: Array = plan.rooms[store].get("domestic_functions", [])
	if plan.rooms[store].get("domestic_role", &"") != &"store" \
			or not store_functions.has(&"dry_herbs"):
		failures.append("%s dry store lacks its public storage/dry-herbs room contract" % who)
	if absf(store_floor.size.x - 2.84) > 0.03 or absf(store_floor.size.y - 3.52) > 0.03:
		failures.append("%s dry store clear floor is %.2fx%.2f, expected 2.84x3.52" % [who, store_floor.size.x, store_floor.size.y])
	var all_reachable := plan.reachable_rooms(hall)
	if not all_reachable.has(bed) or not all_reachable.has(store):
		failures.append("%s bedroom or dry store is disconnected from household circulation" % who)
	var public_reachable := plan.reachable_rooms(hall, HouseGeometry.SLEEPING)
	var graph: Dictionary = plan.door_graph()
	var bed_neighbors: Array = graph.get(bed, [])
	if bed_neighbors.size() != 1 or not bed_neighbors.has(hall):
		failures.append("%s private bedroom is not a leaf served only by the hall" % who)
	if not public_reachable.has(store):
		failures.append("%s dry store is not reachable without crossing the private bedroom" % who)
	var functions: Array = plan.rooms[hall].get("domestic_functions", [])
	for required in [&"entry", &"circulation", &"dining", &"common_living", &"cooking", &"witchwork"]:
		if not functions.has(required):
			failures.append("%s hall lacks explicit function %s" % [who, required])
	if not bool(plan.rooms[hall].get("meal_room", false)) \
			or not bool(plan.rooms[hall].get("shared_cooking", false)) \
			or not bool(plan.rooms[hall].get("shared_witchwork", false)):
		failures.append("%s shared hall activity metadata is incomplete" % who)
	var provenance: Dictionary = plan.domestic_layout
	if provenance.get("requested_rooms", 0) != 3 or provenance.get("planned_rooms", 0) != 3 \
			or provenance.get("omitted_rooms", -1) != 0:
		failures.append("%s does not report its three physical rooms" % who)
	if provenance.get("added_activities", []) != [&"store"]:
		failures.append("%s does not report added dry storage as a separate activity" % who)
	if provenance.get("merged_activities", []) != [&"kitchen", &"workshop"] \
			or provenance.get("omitted_activities", [&"missing"]) != []:
		failures.append("%s provenance hides a required cooking or Witchwork activity" % who)
	var report := HousePlanCheck.new().check(plan)
	if not report.get("failures", []).is_empty():
		failures.append("%s fails HousePlanCheck: %s" % [who, report["failures"]])


func _check_role_loss_fallback(plan: HousePlan) -> void:
	var halls := plan.rooms_of(&"hall")
	if halls.is_empty():
		return
	plan.domestic_layout["shared_witchwork"] = false
	HousePlanRooms.refresh_domestic_metadata(plan)
	if plan.domestic_layout.get("status", &"") != &"fallback":
		failures.append("removing the Witchwork activity from the merged hall did not mark the plan fallback")


func _check_store_loss_fallback(plan: HousePlan) -> void:
	var stores := plan.rooms_of(&"store")
	if stores.is_empty():
		failures.append("negative fixture has no dry store to remove")
		return
	plan.rooms.remove_at(stores[0])
	HousePlanRooms.refresh_domestic_metadata(plan)
	if plan.domestic_layout.get("status", &"") != &"fallback":
		failures.append("removing the added dry store did not mark the compact plan fallback")


func _check_existing_kitchen_witchwork_refresh() -> void:
	var spec := HouseSpec.new()
	spec.style = &"witch_hut"
	spec.width = 9.0
	spec.length = 12.0
	spec.height = 2.6
	var positive := HouseGenerator.generate(spec, 8102, false)
	var kitchen := _configure_existing_shared_kitchen(positive)
	if kitchen < 0:
		failures.append("legacy merged-kitchen fixture has no generated kitchen")
		return
	HousePlanRooms.refresh_domestic_metadata(positive)
	var kitchen_functions: Array = positive.rooms[kitchen].get("domestic_functions", [])
	var hall := positive.rooms_of(&"hall")[0]
	var hall_functions: Array = positive.rooms[hall].get("domestic_functions", [])
	if not kitchen_functions.has(&"witchwork") or hall_functions.has(&"witchwork"):
		failures.append("refresh did not preserve Witchwork on the existing kitchen host")
	if positive.domestic_layout.get("status", &"") != &"planned":
		failures.append("valid existing kitchen-hosted Witchwork was marked fallback")
	var negative := HouseGenerator.generate(spec, 8102, false)
	var negative_kitchen := _configure_existing_shared_kitchen(negative)
	if negative_kitchen < 0:
		return
	var row: Dictionary = negative.rooms[negative_kitchen]
	row["shared_witchwork"] = false
	negative.rooms[negative_kitchen] = row
	HousePlanRooms.refresh_domestic_metadata(negative)
	if negative.domestic_layout.get("status", &"") != &"fallback":
		failures.append("removing the existing kitchen-hosted Witchwork role escaped merged-activity validation")


func _configure_existing_shared_kitchen(plan: HousePlan) -> int:
	var kitchens := plan.rooms_of(&"kitchen")
	if kitchens.is_empty():
		return -1
	var kitchen := kitchens[0]
	var row: Dictionary = plan.rooms[kitchen]
	row["shared_witchwork"] = true
	plan.rooms[kitchen] = row
	plan.domestic_layout = {
		"status": &"planned", "style": &"witch_hut", "hall_role": &"living_hall",
		"ground_activities": [&"hall", &"kitchen", &"bedroom", &"workshop"],
		"merged_activities": [&"workshop"], "shared_witchwork": true
	}
	return kitchen


func _rooms_share_door(plan: HousePlan, a: int, b: int) -> bool:
	for door in plan.doors:
		if door.get("exterior", false):
			continue
		if (int(door["a"]) == a and int(door["b"]) == b) \
				or (int(door["a"]) == b and int(door["b"]) == a):
			return true
	return false
