extends SceneTree
## Generated regression cases for explicit, capacity-complete household dining.
## Run after the staged furnisher/recipe files have been promoted.

const CASES: Array[int] = [72000, 72009, 72015, 72021, 72023]
var failures: Array[String] = []

func _initialize() -> void:
	for seed_value in CASES:
		_check_case(seed_value)
	_check_compact_shared_cooking()
	_check_dropped_seat_negative()
	_check_blocked_stair_negative()
	_check_hearth_host_defer()
	for failure in failures:
		push_error(failure)
	print("dining selection fixture: %d cases, %d failures" % [CASES.size(), failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _check_case(seed_value: int) -> void:
	var n: int = seed_value - 72000
	var styles: Array = HouseSweep.styles()
	var trades: Array = HouseSweep.trades()
	var spec := HouseSpec.new()
	spec.style = styles[n % styles.size()]
	spec.trade = trades[n % trades.size()]
	spec.width = 6.0 + float(n % 5) * 2.0
	spec.length = 7.0 + float(n % 7) * 1.8
	spec.storeys = 2
	var plan: HousePlan = HouseGenerator.generate(spec, seed_value, true)
	var selected: int = int(plan.domestic_layout.get("dining_room", -999))
	var selection: String = String(plan.domestic_layout.get("dining_selection", ""))
	if selection == "unsatisfied":
		if seed_value in [72009, 72015, 72021]:
			failures.append("positive seed %d was allowed to pass as an unsatisfied dining selection" % seed_value)
		if String(plan.domestic_layout.get("dining_selection_reason", "")).is_empty():
			failures.append("seed %d hid why its dining selection is incomplete" % seed_value)
		if selected < -1 or selected >= plan.room_count():
			failures.append("seed %d unsatisfied selection names invalid room %d" % [seed_value, selected])
		var meal_tables: Array[int] = []
		for i in plan.furniture.size():
			var item: Dictionary = plan.furniture[i]
			if String(item.get("activity_group", "")) == "eating" \
					and String(item.get("cat", "")) == "table":
				meal_tables.append(i)
				if selected >= 0 and int(item.get("room", -1)) != selected:
					failures.append("seed %d kept an eating table outside attempted room %d" % [seed_value, selected])
		if meal_tables.size() > 1:
			failures.append("seed %d kept duplicate household meal tables despite an unsatisfied report" % seed_value)
		if selected < 0 and not meal_tables.is_empty():
			failures.append("seed %d emitted a meal table without any selected dining room" % seed_value)
		if seed_value == 72000 and not bool(plan.domestic_layout.get("stair_unsatisfied", false)):
			failures.append("seed 72000 control no longer records its impossible stair route")
		if seed_value == 72023 and selected < 0 \
				and int(plan.domestic_layout.get("dining_probe_count", 0)) == 0:
			failures.append("seed 72023 reported an unserved household without testing any measured candidate")
		if seed_value == 72000 and selected >= 0 and plan.storey_of_room(selected) > 0:
			failures.append("seed 72000 selected an upper dining room despite its failed stair fixture")
		return
	if selection != "complete" or selected < 0 or selected >= plan.room_count():
		failures.append("seed %d has no valid complete dining selection: %s" % [seed_value, selection])
		return
	if seed_value == 72000 and plan.storey_of_room(selected) > 0:
		failures.append("seed 72000 selected an upper dining room despite its failed stair fixture")
	if HouseFurnishingRecipes.dining_room_of(plan) != selected:
		failures.append("seed %d recipe lookup disagrees with selected room %d" % [seed_value, selected])
	var capacity: int = HouseFurnisher._household_seat_capacity(plan)
	var eating_tables: Array[int] = []
	var eating_seats: Array[int] = []
	for i in plan.furniture.size():
		var piece: Dictionary = plan.furniture[i]
		if String(piece.get("activity_group", "")) != "eating":
			continue
		if String(piece.get("cat", "")) == "table":
			eating_tables.append(i)
		elif String(piece.get("cat", "")) == "seat":
			eating_seats.append(i)
	if eating_tables.size() != 1:
		failures.append("seed %d has %d eating tables across the household" % [seed_value, eating_tables.size()])
	if eating_seats.size() != capacity:
		failures.append("seed %d dining room %d has %d/%d eating seats" % [seed_value, selected, eating_seats.size(), capacity])
	for seat_index in eating_seats:
		var seat: Dictionary = plan.furniture[seat_index]
		if int(seat.get("room", -1)) != selected:
			failures.append("seed %d has an eating seat in room %d outside selection %d" % [seed_value, seat.get("room", -1), selected])
		if eating_tables.size() == 1 and int(seat.get("host", -1)) != eating_tables[0]:
			failures.append("seed %d eating seat lost its table host" % seed_value)
		var expected_floor_y: float = HouseFurnishGeometry.storey_base(plan, selected) + HouseGeometry.FLOOR_T
		if not is_equal_approx(float(seat["pos"].y), expected_floor_y):
			failures.append("seed %d eating seat is not on its selected storey floor" % seed_value)
	for table_index in eating_tables:
		var table: Dictionary = plan.furniture[table_index]
		var expected_floor_y: float = HouseFurnishGeometry.storey_base(plan, selected) + HouseGeometry.FLOOR_T
		if not is_equal_approx(float(table["pos"].y), expected_floor_y):
			failures.append("seed %d meal table is not on its selected storey floor" % seed_value)
	var nav: Dictionary = HouseNavCheck.new().check(plan)
	if nav["unreached_rooms"].has(selected):
		failures.append("seed %d selected dining room is unreachable" % seed_value)
	for item_index in nav["unreachable_items"]:
		if eating_tables.has(int(item_index)) or eating_seats.has(int(item_index)):
			failures.append("seed %d selected dining item is unreachable" % seed_value)
	if plan.storey_of_room(selected) > 0 and plan.stairs.is_empty():
		failures.append("seed %d placed dining upstairs without a connecting stair" % seed_value)
	if seed_value == 72009 and (plan.storey_of_room(selected) != 0 or plan.kind_of(selected) != &"parlour"):
		failures.append("seed 72009 did not choose its suitable ground-floor parlour")
	if seed_value == 72009:
		_check_nonselected_parlour_sitting(plan, selected)
	if seed_value == 72015 and plan.storey_of_room(selected) == 0:
		failures.append("seed 72015 did not fall back upstairs after its shared-cooking hall failed")
	if seed_value in [72015, 72021] and plan.storey_of_room(selected) <= 0:
		failures.append("seed %d should prove a complete reachable upper dining fallback" % seed_value)


func _check_nonselected_parlour_sitting(plan: HousePlan, selected: int) -> void:
	var sitting_room := -1
	for room in plan.rooms_of(&"parlour"):
		if room != selected:
			sitting_room = room
			break
	if sitting_room < 0:
		failures.append("seed 72009 does not exercise a separate household sitting parlour")
		return
	var bench_index := -1
	var bench_count := 0
	var sconce_count := 0
	for index in plan.furniture.size():
		var piece: Dictionary = plan.furniture[index]
		if int(piece.get("room", -1)) != sitting_room \
				or String(piece.get("activity_group", "")) != "sitting":
			continue
		if String(piece.get("cat", "")) == "bench":
			bench_count += 1
			bench_index = index
		elif String(piece.get("cat", "")) == "sconce":
			sconce_count += 1
	if bench_count < 1 or sconce_count < 1:
		failures.append("seed 72009 separate parlour lacks its required sitting bench/light group")
		return
	var negative: HousePlan = HouseFurnisher._meal_probe_plan(plan)
	negative.furniture = plan.furniture.duplicate(true)
	negative.compromises.clear()
	negative.furniture.remove_at(bench_index)
	HouseFurnishRepair.reindex_hosts(negative, bench_index)
	HouseFurnisher._audit_activity_groups(negative)
	if not negative.was_dropped(sitting_room, "activity:sitting"):
		failures.append("removed sitting bench did not create an explicit sitting-group shortfall")


func _plan_for_seed(seed_value: int) -> HousePlan:
	var n: int = seed_value - 72000
	var styles: Array = HouseSweep.styles()
	var trades: Array = HouseSweep.trades()
	var spec := HouseSpec.new()
	spec.style = styles[n % styles.size()]
	spec.trade = trades[n % trades.size()]
	spec.width = 6.0 + float(n % 5) * 2.0
	spec.length = 7.0 + float(n % 7) * 1.8
	spec.storeys = 2
	return HouseGenerator.generate(spec, seed_value, true)


func _check_dropped_seat_negative() -> void:
	var plan: HousePlan = _plan_for_seed(72009)
	var room: int = int(plan.domestic_layout.get("dining_room", -1))
	var seat_index := -1
	for index in range(plan.furniture.size() - 1, -1, -1):
		var piece: Dictionary = plan.furniture[index]
		if int(piece.get("room", -1)) == room \
				and String(piece.get("activity_group", "")) == "eating" \
				and String(piece.get("cat", "")) == "seat":
			seat_index = index
			break
	if seat_index < 0:
		failures.append("dropped-seat control lacks a generated household seat")
		return
	plan.furniture.remove_at(seat_index)
	HouseFurnishRepair.reindex_hosts(plan, seat_index)
	HouseFurnisher._finalize_household_dining(plan)
	if String(plan.domestic_layout.get("dining_selection", "")) != "unsatisfied":
		failures.append("dropped-seat negative was still accepted as a complete meal group")


func _check_blocked_stair_negative() -> void:
	var generated: HousePlan = _plan_for_seed(72015)
	var plan: HousePlan = HouseFurnisher._meal_probe_plan(generated)
	plan.stairs.clear()
	plan.domestic_layout.erase("stair_unsatisfied")
	HouseFurnisher._select_household_dining_room(plan)
	var selected: int = int(plan.domestic_layout.get("dining_room", -1))
	if selected >= 0 and plan.storey_of_room(selected) > 0:
		failures.append("blocked-stair control selected dining upstairs without a connecting stair")


func _check_compact_shared_cooking() -> void:
	var spec := HouseSpec.new()
	spec.style = &"cottage"
	spec.width = 7.0
	spec.length = 9.0
	spec.height = 2.6
	var plan: HousePlan = HouseGenerator.generate(spec, 1, true)
	var dining: int = HouseFurnishingRecipes.dining_room_of(plan)
	if dining < 0 or plan.kind_of(dining) != &"hall" or plan.storey_of_room(dining) != 0:
		failures.append("7x9 shared-cooking cottage did not retain its ground hall dining role")
	if String(plan.domestic_layout.get("dining_selection", "")) != "complete":
		failures.append("7x9 shared-cooking cottage lost its complete meal group")
	if int(plan.domestic_layout.get("dining_probe_count", -1)) != 0:
		failures.append("single-room shared-cooking case paid for an unnecessary dining probe")
	if not bool(HouseNavCheck.new().check(plan).get("ok", false)):
		failures.append("7x9 shared-cooking cottage meal group blocked navigation")


func _hearth_selection_plan() -> HousePlan:
	var spec := HouseSpec.new()
	spec.style = &"townhouse"
	spec.width = 14.0
	spec.length = 18.0
	spec.height = 2.9
	spec.storeys = 2
	var plan: HousePlan = HouseGenerator.generate(spec, 72101, true)
	plan.furniture.clear()
	plan.compromises.clear()
	plan.hearth.erase("breast")
	for key in ["dining_room", "dining_group", "dining_selection",
			"dining_selection_reason", "dining_probe_count"]:
		plan.domestic_layout.erase(key)
	var hall := -1
	for room in plan.rooms_of(&"hall"):
		if plan.storey_of_room(room) == 0:
			hall = room
			break
	if hall < 0:
		return plan
	plan.focus = HousePlanFeatures.focus_on_wall(plan, hall, 0, "hearth", false)
	return plan


func _check_hearth_host_defer() -> void:
	var plan := _hearth_selection_plan()
	var hall := plan.focus_room()
	if hall < 0:
		failures.append("hearth-focus fixture has no generated ground hall")
		return
	var separate_rooms: Array[int] = []
	for kind in [&"dining_room", &"dining", &"parlour"]:
		for room in plan.rooms_of(kind):
			if plan.storey_of_room(room) == 0:
				separate_rooms.append(room)
	if separate_rooms.is_empty():
		failures.append("hearth-focus fixture has no separate generated dining candidate")
		return
	HouseFurnisher._select_household_dining_room(plan)
	var selected := int(plan.domestic_layout.get("dining_room", -1))
	if selected == hall or not separate_rooms.has(selected) \
			or Array(plan.domestic_layout.get("dining_group", [])).is_empty():
		failures.append("viable separate dining room did not outrank the focused hearth hall")
	# Seal every separate dining candidate with a real plan-zone rectangle. The
	# focused hall must then be deferred to its recipe instead of receiving a
	# preplaced table group over the hearth's required floor footprint.
	var blocked_plan := _hearth_selection_plan()
	var blocked_hall := blocked_plan.focus_room()
	for kind in [&"dining_room", &"dining", &"parlour"]:
		for room in blocked_plan.rooms_of(kind):
			var floor: Rect2 = HouseGeometry.room_floor_rect(blocked_plan, room)
			blocked_plan.zones.append({"room": room, "why": "fixture sealed candidate",
				"rect": floor})
	HouseFurnisher._select_household_dining_room(blocked_plan)
	if int(blocked_plan.domestic_layout.get("dining_room", -1)) != blocked_hall \
			or String(blocked_plan.domestic_layout.get("dining_selection", "")) != "pending_final_audit" \
			or not Array(blocked_plan.domestic_layout.get("dining_group", [])).is_empty():
		failures.append("focused hearth hall was precommitted after all separate dining rooms were blocked")
