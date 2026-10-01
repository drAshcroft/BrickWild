class_name InsulaCheck
extends RefCounted
## Plan-level rules for WLD-002 Roman apartment blocks.

const HEIGHT_CAP := 20.7
func check(plan: HousePlan) -> Dictionary:
	var failures: Array[String] = []
	var stats := {"storeys": int(plan.spec.storeys), "flats": 0, "street_shops": 0,
		"stairs": plan.stairs.size(), "courts": plan.courts.size()}
	_check_cap(plan, failures)
	_check_pavement(plan, failures, stats)
	_check_stair(plan, failures)
	_check_flats(plan, failures, stats)
	_check_daylight(plan, failures)
	return {"ok": failures.is_empty(), "failures": failures,
		"warnings": [], "stats": stats}


func _check_cap(plan: HousePlan, failures: Array[String]) -> void:
	var storeys := int(plan.spec.storeys)
	var roof := HouseGeometry.roof_rise(plan.spec)
	var total := float(plan.spec.height) * float(storeys) + roof
	if storeys < 3 or storeys > 6:
		failures.append("cap: storeys %d are outside 3..6" % storeys)
	if total > HEIGHT_CAP + 0.001:
		failures.append("cap: total height %.2fm exceeds %.1fm" % [total, HEIGHT_CAP])


func _check_pavement(plan: HousePlan, failures: Array[String], stats: Dictionary) -> void:
	var shops := 0
	var interior := HouseGeometry.interior_rect(plan.spec)
	for i in range(plan.room_count()):
		if plan.storey_of_room(i) != 0:
			continue
		var room: Dictionary = plan.rooms[i]
		var role := String(room.get("role", ""))
		# The stair lobby is a circulation exception; the commercial frontage
		# around it belongs to the tabernae.
		if role == "stair" or role == "ground_store":
			continue
		var rect: Rect2 = room["rect"]
		var street_frontage := absf(rect.position.y - interior.position.y) < 0.03
		if not street_frontage:
			continue
		if StringName(room.get("kind", &"")) != &"shop":
			failures.append("pavement: street room %d is not a shop" % i)
			continue
		shops += 1
		var opening := false
		for door in plan.doors:
			if int(door.get("a", -1)) == i and bool(door.get("exterior", false)) \
					and int(door.get("storey", -1)) == 0 \
					and float(door.get("width", 0.0)) >= 2.0:
				opening = true
		if not opening:
			failures.append("pavement: shop %d has no street opening at least 2m wide" % i)
		for window in plan.windows:
			if int(window.get("room", -1)) != i:
				continue
			if Vector2(window.get("pos", Vector2.ZERO)).y > interior.position.y + 0.05:
				continue
			if float(window.get("sill", 0.0)) < 2.2:
				failures.append("pavement: taberna street window is below privacy height")
	for i2 in range(plan.room_count()):
		if plan.storey_of_room(i2) != 0 or not HouseGeometry.is_habitable(plan.kind_of(i2)):
			continue
		for window2 in plan.windows:
			if int(window2.get("room", -1)) == i2 \
					and Vector2(window2.get("pos", Vector2.ZERO)).y <= interior.position.y + 0.05:
				failures.append("pavement: dwelling room %d has a street window" % i2)
	stats["street_shops"] = shops
	if shops < 2:
		failures.append("pavement: expected at least two street tabernae, found %d" % shops)


func _check_stair(plan: HousePlan, failures: Array[String]) -> void:
	var stair_rooms: Dictionary = {}
	for i in range(plan.room_count()):
		if String(plan.rooms[i].get("role", "")) == "stair":
			stair_rooms[plan.storey_of_room(i)] = i
	if stair_rooms.size() != int(plan.spec.storeys):
		failures.append("stair: one stair landing is required on every floor")
	var street_entries := 0
	for door in plan.doors:
		if String(door.get("role", "")) != "stair_entry":
			continue
		street_entries += 1
		if not bool(door.get("exterior", false)) or not stair_rooms.has(0) \
				or int(door.get("a", -1)) != int(stair_rooms.get(0, -1)):
			failures.append("stair: street entrance does not enter the ground stair")
	if street_entries != 1:
		failures.append("stair: expected one street stair entrance, found %d" % street_entries)
	var joins := {}
	for stair in plan.stairs:
		var lo := int(stair.get("storey", -1))
		var hi := int(stair.get("to_storey", -1))
		if hi != lo + 1 or not stair_rooms.has(lo) or not stair_rooms.has(hi) \
				or int(stair.get("a", -1)) != int(stair_rooms[lo]) \
				or int(stair.get("b", -1)) != int(stair_rooms[hi]):
			continue
		joins[lo] = true
	if joins.size() != maxi(0, int(plan.spec.storeys) - 1):
		failures.append("stair: stair does not join every adjacent floor")
	# Every flat's threshold is reached directly from the stair, sometimes by way
	# of its private landing so circulation does not pass through a bedroom.
	for door in plan.doors:
		if String(door.get("role", "")) != "flat_entry":
			continue
		var level := int(door.get("storey", -1))
		var stair_room := int(stair_rooms.get(level, -1))
		var landing_room := int(door.get("b", -1))
		if int(door.get("a", -1)) != stair_room or stair_room < 0 \
				or landing_room < 0 or landing_room >= plan.room_count() \
				or String(plan.rooms[landing_room].get("role", "")) != "flat_landing" \
				or plan.storey_of_room(landing_room) != level:
			failures.append("stair: a flat entry is not served by that floor's stair")
	for door2 in plan.doors:
		if bool(door2.get("exterior", false)) and String(door2.get("role", "")) != "stair_entry" \
				and String(door2.get("role", "")) != "taberna":
			failures.append("stair: an unapproved exterior route bypasses the stair")


func _check_flats(plan: HousePlan, failures: Array[String], stats: Dictionary) -> void:
	var units: Dictionary = {}
	for i in range(plan.room_count()):
		var unit := String(plan.rooms[i].get("unit", ""))
		if unit.is_empty():
			continue
		if not units.has(unit):
			units[unit] = []
		units[unit].append(i)
	for unit_id in units:
		var rooms: Array = units[unit_id]
		var room_set := {}
		for room_id0 in rooms:
			room_set[int(room_id0)] = true
		var medianum := -1
		var medianum_count := 0
		for room_id in rooms:
			if String(plan.rooms[room_id].get("role", "")) == "medianum":
				medianum = int(room_id)
				medianum_count += 1
		if medianum_count != 1:
			failures.append("flat: %s has %d medianum rooms" % [String(unit_id), medianum_count])
			continue
		var windows := 0
		for wi in plan.windows_of(medianum):
			if String(plan.windows[wi].get("role", "")) == "court_daylight" \
					and _onto_court(plan, plan.windows[wi]):
				windows += 1
			elif String(plan.windows[wi].get("role", "")) == "court_daylight":
				failures.append("flat: %s medianum window does not face the court" % String(unit_id))
		if windows < 2:
			failures.append("flat: %s medianum has fewer than two court windows" % String(unit_id))
		var entry_count := 0
		for door0 in plan.doors:
			var a := int(door0.get("a", -1))
			var b := int(door0.get("b", -1))
			if not room_set.has(a) and not room_set.has(b):
				continue
			var other := b if room_set.has(a) else a
			if room_set.has(other):
				continue
			if other < 0 or other >= plan.room_count():
				failures.append("flat: %s has an exterior room door" % String(unit_id))
				continue
			if String(door0.get("role", "")) == "flat_entry" \
					and StringName(plan.rooms[other].get("role", &"")) in [&"stair", &"flat_landing"]:
				entry_count += 1
			else:
				failures.append("flat: %s has a route outside its stair entry" % String(unit_id))
		if entry_count != 1:
			failures.append("flat: %s has %d stair entries, expected one" % [String(unit_id), entry_count])
		for room_id2 in rooms:
			if int(room_id2) == medianum:
				continue
			var opens_to_medianum := false
			for door in plan.doors:
				if (int(door.get("a", -1)) == int(room_id2) and int(door.get("b", -1)) == medianum) \
						or (int(door.get("b", -1)) == int(room_id2) and int(door.get("a", -1)) == medianum):
					opens_to_medianum = true
			if not opens_to_medianum:
				failures.append("flat: %s room %d has no door onto its medianum" % [String(unit_id), int(room_id2)])
	stats["flats"] = units.size()
	if units.size() != 6:
		failures.append("flat: port tenement requires six flats, found %d" % units.size())
	if plan.courts.is_empty():
		failures.append("flat: no light court is present")


func _check_daylight(plan: HousePlan, failures: Array[String]) -> void:
	var report := HousePlanCheck.new().check(plan)
	for failure in report.get("failures", []):
		var message := String(failure)
		if message.begins_with("daylight:"):
			failures.append("daylight: " + message.trim_prefix("daylight: "))


func _onto_court(plan: HousePlan, window: Dictionary) -> bool:
	var pos := Vector2(window.get("pos", Vector2.ZERO))
	var normal := Vector2(window.get("normal", Vector2.ZERO))
	var outside := pos + normal * (HouseGeometry.wall_thickness(plan.spec) + 0.05)
	for court_index in range(plan.courts.size()):
		var court_storey := HousePlan.record_storey(plan.courts[court_index])
		if court_storey > int(window.get("storey", 0)):
			continue
		if Poly.contains_point(plan.court_outline(court_index), outside, 0.01):
			return true
	return false
