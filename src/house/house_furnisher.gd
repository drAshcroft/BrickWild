class_name HouseFurnisher
extends RefCounted

const BASE_HOUSE_SPEC := preload("res://src/house/house_spec.gd")
## Fills the rooms.
##
## Every piece is placed by a rule rather than a coordinate, and each rule
## encodes something a person would say out loud about furniture:
##
##   wall      a bed, a cabinet, a bookcase wants its back to a wall
##   free      a table wants room all round it
##   around    seats belong at a table, facing it, with room to push back
##   corner    barrels and crates go where nobody walks
##   mounted   shelves, racks and sconces hang on the wall at head height
##   ceiling   the chandelier hangs over the middle of the room
##   on        a mug belongs on a table, never on the floor
##
## Each placement records the floor it occupies AND the floor a person needs to
## USE it -- the pull-back space behind a chair, the side of a bed you get into
## it from. Declaring that zone here is what lets HouseNavCheck ask the only
## question that really matters: can somebody walk in the front door and reach
## every one of them.
##
## Nothing here trusts itself. Everything it places is judged afterwards by
## HouseFurnishCheck and HouseNavCheck, which re-derive the overlaps, the
## clearances and the walkable floor from the placements alone.

static func furnish(plan: HousePlan, spec: HouseSpec) -> void:
	plan.furniture.clear()
	plan.rugs.clear()
	plan.hearth.erase("breast")
	plan.hearth.erase("host_kind")
	plan.hearth.erase("cooking_vessel")
	if _uses_native_domestic_fireplace(plan):
		var room := plan.hearth_room()
		var wall := plan.hearth_wall()
		if room >= 0 and wall >= 0:
			var breast := HouseGeometry.breast_for_domestic_fireplace(plan, room, wall)
			if not breast.is_empty():
				plan.hearth["breast"] = breast
				plan.hearth["host_kind"] = "ordinary_fireplace"
	HousePlanFeatures.reserve_domestic_hearth_tending(plan, spec)
	if HouseFurnishingRecipes.is_ordinary_house(plan):
		_select_household_dining_room(plan)
	# This whole-plan report is also the pre-room baseline for the first room.
	# Each room returns the final report after any bounded local repair, so the
	# next room does not recompute an unchanged before-room walk of the house.
	var nav_report: Dictionary = HouseNavCheck.new().check(plan)
	for i in range(plan.room_count()):
		nav_report = _furnish_room(plan, spec, i, nav_report)
	HouseFurnishRepair.relax(plan)
	_audit_activity_groups(plan)
	# The existing Workbench Pot remains the prep vessel. A second, explicit
	# structural record authorizes the actual model instance suspended over the
	# native fireplace; the assembler must not invent one from a row count.
	var has_domestic_tending := false
	for zone: Dictionary in plan.zones:
		if String(zone.get("why", "")) == "hearth tending":
			has_domestic_tending = true
			break
	if has_domestic_tending and String(plan.hearth.get("host_kind", "")) == "ordinary_fireplace":
		for row: Dictionary in plan.furniture:
			var host := int(row.get("host", -1))
			if String(row.get("key", "")) == "Pot_1" and host >= 0 \
					and host < plan.furniture.size() \
					and String(plan.furniture[host].get("cat", "")) == "workbench" \
					and int(plan.furniture[host].get("room", -1)) == int(row.get("room", -2)):
				plan.hearth["cooking_vessel"] = {
					"key": "Pot_1", "purpose": "hearth_cooking",
					"host": "ordinary_fireplace", "support": "iron_tripod"}
				break


## Choose one room for the household's meal before room recipes run. This is a
## bounded physical trial of the real measured table and complete seat set,
## using door, window, zone and stair reservations. Upper rooms are considered
## only when the unfurnished plan already proves a usable stair route.
static func _select_household_dining_room(plan: HousePlan) -> void:
	plan.domestic_layout.erase("dining_room")
	plan.domestic_layout.erase("dining_key")
	plan.domestic_layout.erase("dining_group")
	plan.domestic_layout.erase("dining_selection")
	plan.domestic_layout.erase("dining_selection_reason")
	plan.domestic_layout["dining_probe_count"] = 0
	var capacity: int = _household_seat_capacity(plan)
	var candidates: Array[int] = []
	# Preserve authored dining rooms. For ordinary rooms, the ground hall gets
	# first choice when it is not also doing the work of a kitchen or bedroom.
	_append_dining_candidates(plan, candidates, [&"dining_room", &"dining"], 0)
	_append_dining_candidates(plan, candidates, [&"hall"], 0, false)
	_append_dining_candidates(plan, candidates, [&"parlour"], 0)
	var upper_kinds: Array[StringName] = [&"dining_room", &"dining", &"parlour"]
	var has_upper_candidate := false
	for kind in upper_kinds:
		for room in plan.rooms_of(kind):
			if plan.storey_of_room(room) > 0:
				has_upper_candidate = true
	var route_failure_declared: bool = bool(plan.domestic_layout.get("stair_unsatisfied", false))
	if has_upper_candidate and not plan.stairs.is_empty() and not route_failure_declared:
		var nav: Dictionary = HouseNavCheck.new().check(plan)
		for kind in upper_kinds:
			for room in plan.rooms_of(kind):
				if plan.storey_of_room(room) <= 0 or candidates.has(room) \
						or _meal_room_competes_with_sleep_or_cooking(plan, room):
					continue
				if not nav["unreached_rooms"].has(room):
					candidates.append(room)
	# Keep a shared cooking/sleeping hall as a last-resort candidate. If it is
	# the only possible room, retain the existing bed-first/cooking arrangement;
	# when another room exists, a separate dining room is tested first.
	_append_dining_candidates(plan, candidates, [&"hall"], 0, true)
	if candidates.size() == 1:
		# Preserve the established random stream and avoid a second full room
		# search when there is only one eligible dining room. Final group audit
		# still proves whether the generated arrangement actually worked.
		plan.domestic_layout["dining_room"] = candidates[0]
		plan.domestic_layout["dining_selection"] = "pending_final_audit"
		return
	var deferred_room := -1
	for room in candidates:
		var has_cooking_function: bool = plan.rooms[room].get("domestic_functions", []).has(&"cooking") \
			or bool(plan.rooms[room].get("shared_cooking", false))
		var is_sleeping_hall: bool = plan.kind_of(room) == &"hall" and not _anybody_sleeps(plan)
		var is_focus_host: bool = (plan.focus_room() == room and plan.focus_cat() != "") \
			or plan.hearth_room() == room
		if is_sleeping_hall or has_cooking_function or is_focus_host:
			# The bare probe cannot reserve the bed, cooking core or focused hearth
			# which the normal recipe will place first. Defer this hall, but keep
			# searching later distinct dining rooms before accepting the fallback.
			if deferred_room < 0:
				deferred_room = room
			continue
		plan.domestic_layout["dining_probe_count"] = \
			int(plan.domestic_layout.get("dining_probe_count", 0)) + 1
		var group: Dictionary = _probe_complete_meal_group(plan, room, capacity)
		if not group.is_empty():
			plan.domestic_layout["dining_room"] = room
			plan.domestic_layout["dining_group"] = group["pieces"]
			plan.domestic_layout["dining_selection"] = "preflight_complete"
			return
	if deferred_room >= 0:
		plan.domestic_layout["dining_room"] = deferred_room
		plan.domestic_layout["dining_selection"] = "pending_final_audit"
		plan.domestic_layout["dining_selection_reason"] = \
			"shared cooking, sleeping or focused hearth order is reserved for normal room placement"
		return
	if not candidates.is_empty():
		# No complete set passed the preflight. Let the largest ground dining or
		# parlour room make one honest partial attempt; final audit keeps the room
		# id and reports any missing capacity instead of erasing usable furniture.
		var fallback_room: int = candidates[0]
		var fallback_area: float = -1.0
		for room in candidates:
			if plan.storey_of_room(room) != 0 \
					or plan.kind_of(room) not in [&"dining_room", &"dining", &"parlour"]:
				continue
			var area: float = HouseGeometry.room_area(plan, room)
			if area > fallback_area:
				fallback_area = area
				fallback_room = room
		plan.domestic_layout["dining_room"] = fallback_room
		plan.domestic_layout["dining_selection"] = "pending_final_audit"
		plan.domestic_layout["dining_selection_reason"] = \
			"no measured complete group fit; retained one best available room for an explicit final attempt"
		return
	plan.domestic_layout["dining_room"] = -1
	plan.domestic_layout["dining_selection"] = "unsatisfied"
	plan.domestic_layout["dining_selection_reason"] = \
		"no reachable hall, dining room or parlour is available for a meal group"


## A ground hall that must also cook or sleep is not a free dining candidate.
## The probe is deliberately not allowed to spend the same square metres twice.
static func _meal_room_competes_with_sleep_or_cooking(plan: HousePlan, room: int) -> bool:
	if plan.kind_of(room) != &"hall":
		return false
	var functions: Array = plan.rooms[room].get("domestic_functions", [])
	if functions.has(&"cooking") or bool(plan.rooms[room].get("shared_cooking", false)):
		return true
	return not _anybody_sleeps(plan)


static func _append_dining_candidates(plan: HousePlan, out: Array[int],
		kinds: Array[StringName], storey: int, only_competing_halls := false) -> void:
	for kind in kinds:
		for room in plan.rooms_of(kind):
			if plan.storey_of_room(room) != storey or out.has(room):
				continue
			var competing := _meal_room_competes_with_sleep_or_cooking(plan, room)
			if only_competing_halls and not competing:
				continue
			if not only_competing_halls and competing:
				continue
			out.append(room)


## Return the actual table key that passed, so the final recipe does not roll a
## larger model than the one whose complete household group was measured.
static func _probe_complete_meal_group(plan: HousePlan, room: int, seats: int) -> Dictionary:
	var keys: Array[String] = PropCatalog.of_category_for_room("table", plan.kind_of(room))
	for key in keys:
		var probe := _meal_probe_plan(plan)
		probe.domestic_layout["dining_room"] = room
		var blocked: Array[Rect2] = HouseFurnishPlacement.initial_blocked(probe, room)
		var original_blocked_count: int = blocked.size()
		var borrowed: int = HouseFurnishPlacement._borrow_activity_band(
			probe, room, "eating", blocked)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(plan.spec.seed) * 7919 + room * 104729
		HouseFurnishPlacement.place_free(probe, room, key, blocked, [], rng,
			true, "seat", seats, true, 1.0)
		HouseFurnishPlacement._restore_borrowed_blocks(blocked, original_blocked_count, borrowed)
		var tables: int = 0
		var placed_seats: int = 0
		for piece in probe.furniture:
			if int(piece.get("room", -1)) != room:
				continue
			if String(piece.get("cat", "")) == "table":
				tables += 1
			elif String(piece.get("cat", "")) == "seat":
				placed_seats += 1
		if tables != 1 or placed_seats != seats:
			continue
		var nav: Dictionary = HouseNavCheck.new().check(probe)
		if nav["unreached_rooms"].has(room):
			continue
		var unreachable_meal_piece := false
		for item_index in nav["unreachable_items"]:
			if int(probe.furniture[item_index].get("room", -1)) == room:
				unreachable_meal_piece = true
				break
		if unreachable_meal_piece:
			continue
		var meal_pieces: Array[Dictionary] = []
		for piece in probe.furniture:
			if int(piece.get("room", -1)) == room:
				meal_pieces.append(piece.duplicate(true))
		return {"key": key, "pieces": meal_pieces}
	return {}


static func _meal_probe_plan(plan: HousePlan) -> HousePlan:
	var probe := HousePlan.new()
	probe.spec = plan.spec
	probe.rooms = plan.rooms
	probe.doors = plan.doors
	probe.windows = plan.windows
	probe.stairs = plan.stairs
	probe.zones = plan.zones
	probe.hearth = plan.hearth.duplicate(true)
	probe.focus = plan.focus.duplicate(true)
	probe.dais = plan.dais.duplicate(true)
	probe.columns = plan.columns.duplicate(true)
	probe.courts = plan.courts.duplicate(true)
	probe.trapdoors = plan.trapdoors.duplicate(true)
	probe.domestic_layout = plan.domestic_layout.duplicate(true)
	probe.world_family = plan.world_family
	probe.world_subkind = plan.world_subkind
	return probe


## The group travels with the placed item, including a seat created as a pair
## with its table. Repair can then report that it broke an activity.
static func _set_activity_group(piece: Dictionary, step: Dictionary) -> void:
	var group_name: String = String(step.get("group", ""))
	if not group_name.is_empty():
		piece["activity_group"] = group_name
	var shared_groups: Array = step.get("shared_activity_groups", [])
	if not shared_groups.is_empty():
		piece["shared_activity_groups"] = shared_groups.duplicate()
		piece["shared_station_id"] = String(step.get("shared_station_id", ""))
	var near_category: String = String(step.get("near_cat", ""))
	if not near_category.is_empty():
		piece["activity_host_cat"] = near_category
	var near_anchor: String = String(step.get("near_anchor", ""))
	if not near_anchor.is_empty():
		piece["activity_host_anchor"] = near_anchor


## Repair may remove a required item, and a placement rule may fail before an
## item exists to tag. Re-derive the required group from the room recipe after
## repair, then record every category or seat count that did not survive.
static func _audit_activity_groups(plan: HousePlan) -> void:
	for room in range(plan.room_count()):
		var kind: StringName = plan.kind_of(room)
		var station_contract: Dictionary = plan.rooms[room].get("shared_activity_station", {})
		var station_nav: Dictionary = {}
		if not station_contract.is_empty():
			station_nav = HouseNavCheck.new().check(plan)
		var recipe: Array = HouseFurnishingRecipes.recipe_for_room(plan, room,
			not _dining_table_lost(plan, room))
		if HouseFurnishingRecipes.is_ordinary_house(plan) and kind == &"hall" \
				and not _anybody_sleeps(plan):
			recipe = recipe.duplicate()
			recipe.append_array([
				{"cat": "bed", "n": [1, 1], "opt": 1.0, "group": "sleep"},
				{"cat": "nightstand", "key": "Nightstand_Shelf", "rule": &"beside", "near_cat": "bed", "near_anchor": "head_end", "n": [1, 1], "opt": 1.0, "group": "sleep"},
				{"cat": "chest", "rule": &"wall", "n": [1, 1], "opt": 1.0, "group": "sleep"},
				{"cat": "sconce", "n": [1, 1], "opt": 1.0, "group": "sleep"},
			])
		var ample: Dictionary = HouseFurnishingRecipes.AMPLE.get(kind, {})
		if not ample.is_empty() and HouseGeometry.room_area(plan, room) >= float(ample["area"]):
			recipe = recipe + HouseFurnishingRecipes.ample_steps_for_room(plan, room)
		var required: Dictionary = {}
		for step in recipe:
			var recipe_group: String = String(step.get("group", ""))
			if recipe_group.is_empty() or float(step.get("opt", 0.0)) < 1.0:
				continue
			var recipe_category: String = String(step["cat"])
			var declared_groups: Array[String] = [recipe_group]
			for shared_group_variant in step.get("shared_activity_groups", []):
				var shared_group := String(shared_group_variant)
				if not shared_group.is_empty() and not declared_groups.has(shared_group):
					declared_groups.append(shared_group)
			for required_group in declared_groups:
				if not required.has(required_group):
					required[required_group] = {}
				var groups_by_category: Dictionary = required[required_group]
				groups_by_category[recipe_category] = int(groups_by_category.get(recipe_category, 0)) \
					+ int(step.get("min_n", step["n"][0]))
		for group_variant in required:
			var audit_group: String = String(group_variant)
			var category_counts: Dictionary = required[group_variant]
			for category_variant in category_counts:
				var audit_category: String = String(category_variant)
				var actual: int = 1 if audit_category == "hearth" \
						and _uses_native_domestic_fireplace(plan) \
						and room == plan.hearth_room() \
						and not HouseGeometry.hearth_breast(plan).is_empty() else 0
				var contract_groups: Array = station_contract.get("groups", [])
				var contract_role: bool = not station_contract.is_empty() \
					and audit_category == String(station_contract.get("category", "")) \
					and contract_groups.has(StringName(audit_group))
				for piece_index in range(plan.furniture.size()):
					var piece: Dictionary = plan.furniture[piece_index]
					if int(piece.get("room", -1)) != room \
							or String(piece.get("cat", "")) != audit_category:
						continue
					var primary_group := String(piece.get("activity_group", ""))
					var shared_groups: Array = piece.get("shared_activity_groups", [])
					if contract_role:
						if _shared_activity_station_valid(plan, room, piece_index,
								audit_group, station_nav):
							actual += 1
					elif primary_group == audit_group:
						actual += 1
					elif shared_groups.has(audit_group) \
							and _shared_activity_station_valid(plan, room, piece_index,
								audit_group, station_nav):
						actual += 1
				if actual < int(category_counts[category_variant]):
					plan.note_compromise(room, "activity:" + audit_group)
					plan.note_compromise(room, "activity:%s:%s" % [audit_group, audit_category])
			if audit_group == "eating" and HouseFurnishingRecipes.is_ordinary_house(plan) \
					and room == HouseFurnishingRecipes.dining_room_of(plan):
				var seats: int = 0
				for piece in plan.furniture:
					if int(piece["room"]) == room and String(piece.get("activity_group", "")) == "eating" \
							and String(piece["cat"]) == "seat":
						seats += 1
				if seats < _household_seat_capacity(plan):
					plan.note_compromise(room, "activity:eating")
					plan.note_compromise(room, "activity:eating:seat_capacity")
		for piece in plan.furniture:
			if HouseFurnishingRecipes.is_ordinary_house(plan) and int(piece["room"]) == room:
				var activity_group: String = String(piece.get("activity_group", ""))
				var activity_category: String = String(piece.get("cat", ""))
				if activity_group == "eating" and activity_category == "table" \
						and PropCatalog.placement_height(piece) \
						< HouseFurnishingRecipes.DOMESTIC_TABLE_MIN_HEIGHT:
					plan.note_compromise(room, "activity:eating:height:table")
				if activity_group == "cooking" and activity_category == "workbench" \
						and PropCatalog.placement_height(piece) \
						< HouseFurnishingRecipes.DOMESTIC_PREP_MIN_HEIGHT:
					plan.note_compromise(room, "activity:cooking:height:workbench")
			if int(piece["room"]) != room or not piece.has("activity_host_cat"):
				continue
			var relation_ok := false
			for host in plan.furniture:
				if int(host["room"]) != room or String(host["cat"]) != String(piece["activity_host_cat"]):
					continue
				var edge_distance: float = _rect_edge_distance(Rect2(piece["rect"]), Rect2(host["rect"]))
				if String(piece.get("activity_relation", "")) == "beside_work_zone":
					relation_ok = String(piece.get("cat", "")) == "bucket" \
						and edge_distance > 0.0 and edge_distance <= 1.0 \
						and not Rect2(host.get("zone", Rect2())).intersects(Rect2(piece["rect"]))
				elif String(piece.get("activity_relation", "")) == "opposed_work_aisle":
					var host_facing := HouseFurnishScore._facing_of(float(host.get("yaw", 0.0))).normalized()
					var piece_facing := HouseFurnishScore._facing_of(float(piece.get("yaw", 0.0))).normalized()
					var toward_piece: Vector2 = (Rect2(piece["rect"]).get_center()
						- Rect2(host["rect"]).get_center()).normalized()
					var host_zone: Rect2 = Rect2(host.get("zone", Rect2()))
					var piece_zone: Rect2 = Rect2(piece.get("zone", Rect2()))
					relation_ok = edge_distance > 0.0 and edge_distance <= 2.5 \
						and host_facing.dot(toward_piece) > 0.0 \
						and piece_facing.dot(-host_facing) >= 0.99 \
						and host_zone.has_area() and piece_zone.has_area() \
						and not host_zone.intersects(Rect2(piece["rect"])) \
						and not piece_zone.intersects(Rect2(host["rect"]))
				elif edge_distance <= 0.2:
					relation_ok = true
					if String(piece.get("activity_host_anchor", "")) == "head_end":
						var head_world: Vector3 = Basis(Vector3.UP,
							float(host.get("yaw", 0.0))) * Vector3.BACK
						var head_dir := Vector2(head_world.x, head_world.z).normalized()
						var host_rect: Rect2 = Rect2(host["rect"])
						var piece_rect: Rect2 = Rect2(piece["rect"])
						var host_extent: float = absf(head_dir.x) * host_rect.size.x * 0.5 \
							+ absf(head_dir.y) * host_rect.size.y * 0.5
						var piece_extent: float = absf(head_dir.x) * piece_rect.size.x * 0.5 \
							+ absf(head_dir.y) * piece_rect.size.y * 0.5
						var head_offset: float = (piece_rect.get_center() - host_rect.get_center()).dot(head_dir)
						# A useful bedside chest can sit beside the head third; it need
						# not project past the mattress end into an exterior wall.
						relation_ok = head_offset + piece_extent >= host_extent / 3.0 \
							and PropCatalog.placement_height(piece) <= 0.8
				if relation_ok:
					break
			if not relation_ok:
				var related_group: String = String(piece.get("activity_group", ""))
				if not related_group.is_empty():
					plan.note_compromise(room, "activity:" + related_group)
					plan.note_compromise(room, "activity:%s:relation:%s" % [
						related_group, String(piece["activity_host_cat"])])
					var anchor: String = String(piece.get("activity_host_anchor", ""))
					if anchor == "head_end":
						plan.note_compromise(room, "activity:%s:relation:%s" % [related_group, anchor])
	_finalize_household_dining(plan)
	_report_activity_brief(plan)


## A shared role is valid only when this exact piece is the contracted physical
## station, bears on the real flue breast, and serves a reachable work stance.
static func _shared_activity_station_valid(plan: HousePlan, room: int,
		station_index: int, role: String, nav: Dictionary) -> bool:
	if room < 0 or room >= plan.rooms.size() or station_index < 0 \
			or station_index >= plan.furniture.size():
		return false
	var room_data: Dictionary = plan.rooms[room]
	var contract: Dictionary = room_data.get("shared_activity_station", {})
	var groups: Array = contract.get("groups", [])
	var station: Dictionary = plan.furniture[station_index]
	var station_id := String(contract.get("id", ""))
	var station_category := String(contract.get("category", ""))
	if station_id != "compact_witch_hearth" or station_category != "hearth" \
			or String(contract.get("scope", "")) != "compact_witch_shared_hall" \
			or not HouseFurnishingRecipes.is_ordinary_house(plan) \
			or plan.spec.style != &"witch_hut" or plan.spec.trade != &"none" \
			or plan.kind_of(room) != &"hall" \
			or not groups.has(&"cooking") or not groups.has(&"witchwork") \
			or not groups.has(StringName(role)) \
			or String(station.get("shared_station_id", "")) != station_id \
			or String(station.get("cat", "")) != station_category \
			or PropCatalog.category(String(station.get("key", ""))) != station_category:
		return false
	var declared_roles: Array = station.get("shared_activity_groups", [])
	if String(station.get("activity_group", "")) != role and not declared_roles.has(role):
		return false
	var body: Rect2 = Rect2(station.get("rect", Rect2()))
	var use: Rect2 = Rect2(station.get("zone", Rect2()))
	var floor: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	if not body.has_area() or not use.has_area() \
			or not floor.grow(0.01).encloses(body) or not floor.grow(0.01).encloses(use):
		return false
	var breast: Dictionary = HouseGeometry.hearth_breast(plan)
	var host_wall := int(contract.get("host_wall", -1))
	if plan.hearth_room() != room or plan.hearth_wall() != host_wall \
			or int(breast.get("wall", -1)) != host_wall \
			or _rect_edge_distance(Rect2(breast.get("rect", Rect2())), body) > 0.01:
		return false
	var activity_regions: Dictionary = room_data.get("activity_regions", {})
	var cooking_region: Rect2 = Rect2(activity_regions.get(&"cooking", Rect2()))
	var witchwork_region: Rect2 = Rect2(activity_regions.get(&"witchwork", Rect2()))
	if not activity_regions.has(&"cooking") or not activity_regions.has(&"witchwork") \
			or not cooking_region.position.is_equal_approx(witchwork_region.position) \
			or not cooking_region.size.is_equal_approx(witchwork_region.size) \
			or not HouseGeometry.room_floor_rect(plan, room).encloses(cooking_region) \
			or not cooking_region.grow(0.01).encloses(body) \
			or not cooking_region.grow(0.01).encloses(use):
		return false
	var max_distance := float(contract.get("max_usezone_distance", 0.0))
	if max_distance <= 0.0:
		return false
	var bench_index := -1
	var bench_count := 0
	for candidate_index in plan.furniture_of(room):
		var candidate: Dictionary = plan.furniture[candidate_index]
		if String(candidate.get("cat", "")) == "workbench" \
				and PropCatalog.category(String(candidate.get("key", ""))) == "workbench" \
				and String(candidate.get("activity_group", "")) == role:
			bench_index = candidate_index
			bench_count += 1
	if bench_count != 1 or bench_index < 0 or bench_index == station_index:
		return false
	var bench: Dictionary = plan.furniture[bench_index]
	var bench_body: Rect2 = Rect2(bench.get("rect", Rect2()))
	var bench_use: Rect2 = Rect2(bench.get("zone", Rect2()))
	if not bench_body.has_area() or not bench_use.has_area() \
			or not floor.grow(0.01).encloses(bench_body) \
			or not floor.grow(0.01).encloses(bench_use) \
			or _rect_edge_distance(use, bench_use) > max_distance \
			or use.intersects(bench_body) or bench_use.intersects(body):
		return false
	if nav.get("unreached_rooms", []).has(room) \
			or nav.get("unreachable_items", []).has(station_index) \
			or nav.get("unreachable_items", []).has(bench_index):
		return false
	return true


## Replay the exact measured pose from selection. Re-searching with a different
## RNG stream could turn a proved full household group into a partial table set.
static func _commit_preflight_dining_group(plan: HousePlan, room: int,
		blocked: Array[Rect2], zones: Array[Rect2]) -> void:
	if room != int(plan.domestic_layout.get("dining_room", -1)):
		return
	var group: Array = plan.domestic_layout.get("dining_group", [])
	if group.is_empty():
		return
	var original_blocked_count: int = blocked.size()
	var borrowed: int = HouseFurnishPlacement._borrow_activity_band(
		plan, room, "eating", blocked)
	var table_index: int = -1
	for source in group:
		var piece: Dictionary = Dictionary(source).duplicate(true)
		var planar_pos: Vector3 = piece.get("pos", Vector3.ZERO)
		planar_pos.y = 0.0
		piece["pos"] = planar_pos
		piece["activity_group"] = "eating"
		piece["must"] = true
		if String(piece.get("cat", "")) == "table":
			piece["host"] = -1
		else:
			piece["host"] = table_index
		HouseFurnishGeometry.commit(plan, room, piece, blocked, zones)
		plan.furniture[-1]["must"] = true
		plan.furniture[-1]["activity_group"] = "eating"
		if String(plan.furniture[-1].get("cat", "")) == "table":
			table_index = plan.furniture.size() - 1
	HouseFurnishPlacement._restore_borrowed_blocks(blocked,
		original_blocked_count, borrowed)


## The preflight is a room-selection aid. Only post-repair furniture and routes
## can claim that the household actually has a complete meal arrangement.
static func _finalize_household_dining(plan: HousePlan) -> void:
	if not HouseFurnishingRecipes.is_ordinary_house(plan) \
			or not plan.domestic_layout.has("dining_room"):
		return
	var room: int = int(plan.domestic_layout.get("dining_room", -1))
	if room < 0:
		plan.domestic_layout["dining_selection"] = "unsatisfied"
		return
	var capacity: int = _household_seat_capacity(plan)
	var tables: Array[int] = []
	var seats: Array[int] = []
	for index in plan.furniture.size():
		var piece: Dictionary = plan.furniture[index]
		if int(piece.get("room", -1)) != room \
				or String(piece.get("activity_group", "")) != "eating":
			continue
		if String(piece.get("cat", "")) == "table":
			tables.append(index)
		elif String(piece.get("cat", "")) == "seat":
			seats.append(index)
	var reason: String = ""
	if tables.size() != 1:
		reason = "selected room did not retain exactly one meal table"
	elif seats.size() != capacity:
		reason = "selected room retained %d of %d household seats" % [seats.size(), capacity]
	else:
		for seat_index in seats:
			if int(plan.furniture[seat_index].get("host", -1)) != tables[0]:
				reason = "an eating seat lost its table host"
				break
	if reason.is_empty():
		var nav: Dictionary = HouseNavCheck.new().check(plan)
		if nav["unreached_rooms"].has(room):
			reason = "the selected dining room is unreachable in the completed house"
		else:
			for item_index in nav["unreachable_items"]:
				if tables.has(int(item_index)) or seats.has(int(item_index)):
					reason = "the completed dining group is not reachable from the entrance"
					break
	if reason.is_empty():
		plan.domestic_layout["dining_selection"] = "complete"
		plan.domestic_layout.erase("dining_selection_reason")
	else:
		plan.domestic_layout["dining_selection"] = "unsatisfied"
		plan.domestic_layout["dining_selection_reason"] = reason
		plan.note_compromise(room, "activity:eating")


## Keep the result of bounded furnishing visible beside the architectural
## programme. A geometrically planned shell is not proof of a complete home.
static func _report_activity_brief(plan: HousePlan) -> void:
	if not HouseFurnishingRecipes.is_ordinary_house(plan):
		return
	var shortfalls: Array[Dictionary] = []
	for room in range(plan.room_count()):
		var issues: Array[String] = []
		for value in plan.compromises.get(room, []):
			var issue := String(value)
			if issue.begins_with("activity:") and not issues.has(issue):
				issues.append(issue)
		if not issues.is_empty():
			shortfalls.append({"room": room, "kind": plan.kind_of(room), "issues": issues})
	if String(plan.domestic_layout.get("dining_selection", "")) == "unsatisfied":
		shortfalls.append({"room": -1, "kind": &"dining", "issues": ["activity:eating:no_verified_room"]})
	plan.domestic_layout["activity_status"] = "complete" if shortfalls.is_empty() else "unsatisfied"
	plan.domestic_layout["activity_shortfalls"] = shortfalls


static func _rect_edge_distance(a: Rect2, b: Rect2) -> float:
	var gap_x := maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), 0.0)
	var gap_y := maxf(maxf(a.position.y - b.end.y, b.position.y - a.end.y), 0.0)
	return Vector2(gap_x, gap_y).length()


## Whether native furnishing can author any part of this plan's emitted shell.
static func shell_needs_furnishing(plan: HousePlan) -> bool:
	# Keep this beside the features that derive emitted shell geometry from
	# furniture. A planner may have selected a hearth wall before a shop's
	# temporary hall was renamed to a room whose recipe contains no hearth.
	if plan.focus_cat() == "hearth":
		return true
	var hearth_room := plan.hearth_room()
	if hearth_room >= 0:
		for step in HouseFurnishingRecipes.recipe_for_room(plan, hearth_room):
			if step["cat"] == "hearth":
				return true
	for room in plan.rooms:
		if room["kind"] in HouseFurnishingRecipes.RUG_ROOM_KINDS:
			return true
	return false


## Placement-only shell preparation. Chimney masonry follows the final hearth
## placement, and floor textiles follow tables that survive navigation repair.
## Both are emitted shell geometry, so the complete native furnishing pass is
## required before discarding temporary furniture. Keep all authored shell data.
static func prepare_shell_focus(plan: HousePlan, spec: HouseSpec) -> void:
	furnish(plan, spec)
	plan.furniture.clear()


## Does anybody sleep anywhere in this plan?
##
## A hall doubles as a bedroom only when nothing else in the building is one,
## which is what a one-room cottage does. But &"bedroom" is not the only room
## people sleep in: a keep lord sleeps in his chamber at the top, and asking
## for that one name put a bed in his hall as well.
static func _anybody_sleeps(plan: HousePlan) -> bool:
	for kind in HouseGeometry.SLEEPING:
		if plan.has_kind(kind):
			return true
	return false


## One sleeping room represents one household room, with two ordinary places
## at the meal table. The measured table and chair footprints decide what can
## physically fit; a shortfall is reported by the group audit.
static func _household_seat_capacity(plan: HousePlan) -> int:
	var sleeping_rooms := 0
	for kind in HouseGeometry.SLEEPING:
		sleeping_rooms += plan.rooms_of(kind).size()
	if sleeping_rooms == 0:
		sleeping_rooms = 1
	return clampi(sleeping_rooms * 2, 2, 8)


static func _uses_native_domestic_fireplace(plan: HousePlan) -> bool:
	return HouseFurnishingRecipes.uses_native_domestic_fireplace(plan)


static func _furnish_room(plan: HousePlan, spec: HouseSpec, room: int,
		before_room_nav: Dictionary) -> Dictionary:
	var kind: StringName = plan.kind_of(room)
	var steps: Array = []
	# A house with no room big enough to be a bedroom sleeps in its hall, which
	# is what a one-room cottage has always done. The bed goes in first, before
	# the table has taken the good wall.
	var sleeps_here: bool = not spec is ShopSpec and kind == &"hall" \
		and not _anybody_sleeps(plan)
	if sleeps_here:
		steps.append({"cat": "bed", "rule": &"wall", "n": [1, 1], "opt": 1.0,
			"group": "sleep" if HouseFurnishingRecipes.is_ordinary_house(plan) else ""})
		if HouseFurnishingRecipes.is_ordinary_house(plan):
			steps.append({"cat": "nightstand", "key": "Nightstand_Shelf", "rule": &"beside", "near_cat": "bed",
				"near_anchor": "head_end", "n": [1, 1], "opt": 1.0, "group": "sleep"})
			steps.append({"cat": "chest", "rule": &"wall", "n": [1, 1], "opt": 1.0, "group": "sleep"})
			steps.append({"cat": "sconce", "rule": &"mounted", "n": [1, 1], "opt": 1.0, "group": "sleep"})
		else:
			# Preserve the pre-overlay hall-sleep fallback for custom families.
			steps.append({"cat": "chest", "rule": &"wall", "n": [1, 1], "opt": 0.9})
	var recipe: Array = HouseFurnishingRecipes.recipe_for_room(plan, room,
		not _dining_table_lost(plan, room))
	var ample: Dictionary = HouseFurnishingRecipes.AMPLE.get(kind, {})
	if not ample.is_empty() and HouseGeometry.room_area(plan, room) >= float(ample["area"]):
		recipe = recipe + HouseFurnishingRecipes.ample_steps_for_room(plan, room)
	for s in recipe:
		# The ordinary masonry host is the required heat source. Do not invent a
		# model row or collision footprint for a vessel that is not in the room.
		if _uses_native_domestic_fireplace(plan) and String(s["cat"]) == "hearth":
			if room == plan.hearth_room() and HouseGeometry.hearth_breast(plan).is_empty():
				plan.note_compromise(room, "activity:cooking:hearth_host")
			continue
		# A family without a supported flue omits the hearth prop, while its
		# table/bed programme remains the same.
		if String(s["cat"]) == "hearth" and not spec.allows_hearth_furniture():
			var unsupported_group: String = String(s.get("group", ""))
			if not unsupported_group.is_empty():
				plan.note_compromise(room, "activity:" + unsupported_group)
				plan.note_compromise(room, "activity:%s:hearth" % unsupported_group)
			continue
		# With a bed in it the hall has no middle left to stand a table in, so
		# the table goes against a wall -- which is what a one-room cottage
		# does anyway.
		if sleeps_here and String(s["cat"]) == "table":
			var wall_table: Dictionary = s.duplicate()
			wall_table["rule"] = &"wall"
			steps.append(wall_table)
			continue
		steps.append(s)
	if spec is ShopSpec and (spec as ShopSpec).business == &"barracks":
		var room_area := HouseGeometry.room_area(plan, room)
		if kind == &"dormitory" and room_area >= 150.0:
			steps.append({"cat": "bed", "rule": &"row", "n": [4, 6], "min_n": 4,
				"pitch": 0.0, "aisle": 1.0, "along": "wall",
				"avoid_window_walls": true, "avoid_door_lines": true, "opt": 1.0})
		if kind == &"armoury" and room_area >= 150.0:
			steps.append({"cat": "stand", "key": "WeaponStand", "rule": &"row",
				"n": [2, 4], "min_n": 2, "pitch": 0.0, "aisle": 0.9,
				"along": "wall", "opt": 1.0})
		if kind == &"mess":
			var extra_tables := 1 if room_area >= 50.0 else 0
			for _table in range(extra_tables):
				steps.append({"cat": "table", "rule": &"free", "n": [1, 1], "opt": 1.0})
				steps.append({"cat": "bench", "rule": &"around", "n": [2, 2], "opt": 1.0})

	# the trade fits out whichever room it works in, after that room's own
	# recipe has had its say
	var trade_room: StringName = HouseSpec.TRADES[spec.trade]["room"] \
		if not spec is ShopSpec else (spec as ShopSpec).front_room()
	var fittings: Array = HouseFurnishingRecipes.TRADE_FITTINGS.get(spec.trade, []) if not spec is ShopSpec \
		else HouseFurnishingRecipes.SHOP_FITTINGS.get((spec as ShopSpec).business, [])
	if trade_room == kind:
		for s2 in fittings:
			if StringName(s2.get("room", trade_room)) == kind:
				if plan.focus_room() == room and String(s2["cat"]) == plan.focus_cat():
					steps.insert(0, s2)
				else:
					steps.append(s2)
	else:
		for s3 in fittings:
			if s3.has("room") and StringName(s3["room"]) == kind:
				steps.append(s3)

	# The focus is the one piece the room is arranged around, so it goes in
	# whether or not the recipe happened to list it: a tavern's bar is not in
	# the dining-room recipe, a great hall's high table is not in any.
	if plan.focus_room() == room and plan.focus_cat() != "" \
			and not (_uses_native_domestic_fireplace(plan) and plan.focus_cat() == "hearth"):

		var listed := false
		for s3 in steps:
			if String(s3["cat"]) == plan.focus_cat():
				listed = true
		if not listed:
			var choices: Array[String] = PropCatalog.of_category(plan.focus_cat())
			if not choices.is_empty():
				var wants_wall: bool = PropCatalog.has_tag(choices[0], PropCatalog.WALL)
				# and it goes in FIRST: the bar takes the wall across from the
				# door before the row of tables can take it
				steps.insert(0, {"cat": plan.focus_cat(),
					"rule": &"wall" if wants_wall else &"free", "n": [1, 1], "opt": 1.0})

	# The things a room cannot do without go in first, whether they came from
	# the room recipe or from the trade. Otherwise a smithy spends its one good
	# wall on a weapon rack and has nowhere left for the workbench.
	#
	# Among equals the room's own recipe wins: a workshop is a workshop because
	# of its bench, and the trade's anvil can take what is left. Ordering them
	# the other way round left one house with a forge and nothing to work at.
	for i in range(steps.size()):
		steps[i] = steps[i].duplicate()
		steps[i]["order"] = i
	# A free table that the recipe goes on to seat knows what it will be
	# seated with, so it can be stood where that seat fits.
	for i2 in range(steps.size()):
		if String(steps[i2]["cat"]) != "table" or steps[i2]["rule"] != &"free":
			continue
		if plan.focus_room() == room and plan.focus_cat() == "table":
			continue # a high table or an altar has its own seating contract
		for j2 in range(i2 + 1, steps.size()):
			if steps[j2]["rule"] == &"around" and String(steps[j2].get("host", "")) != "row":
				steps[i2]["seat_cat"] = String(steps[j2]["cat"])
				# room for the least the step asks, up to a pair facing
				steps[i2]["seat_n"] = clampi(int(steps[j2]["n"][0]), 1, 2)
				break
	if HouseFurnishingRecipes.is_ordinary_house(plan):
		var seated_room: int = HouseFurnishingRecipes.dining_room_of(plan)
		if seated_room == room:
			var household_seats := _household_seat_capacity(plan)
			for step in steps:
				if String(step["cat"]) == "seat" and String(step.get("group", "")) == "eating":
					step["n"] = [household_seats, household_seats]
					step["min_n"] = household_seats
			for step in steps:
				if String(step["cat"]) == "table" and String(step.get("group", "")) == "eating" \
						and step["rule"] == &"free":
					step["seat_n"] = household_seats
					step["seat_n_required"] = true
	steps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["opt"]), float(b["opt"])):
			return float(a["opt"]) > float(b["opt"])
		return int(a["order"]) < int(b["order"]))

	var blocked: Array[Rect2] = HouseFurnishPlacement.initial_blocked(plan, room)
	# Use zones are tracked apart from footprints. Two people may share a
	# gangway, so zones may overlap each other -- but nothing solid may stand
	# in one, or the piece it belongs to becomes unusable. Leaving zones out of
	# the occupancy entirely is what let a chest be set down in the only gap
	# beside a bed.
	var zones: Array[Rect2] = []
	var r: RandomNumberGenerator = spec.rng
	_commit_preflight_dining_group(plan, room, blocked, zones)
	# The dais belongs to the piece the room is arranged around and to whoever
	# sits behind it. Those two steps come first and stand ON it; everything
	# after them treats it as occupied ground, because a barrel on the dais is
	# a barrel on the lord's table and a row of trestles that runs up onto the
	# step is a row that has walked over the high table.
	var close_dais: int = _dais_closes_after(plan, room, steps)
	var dais_open: bool = close_dais >= 0
	for si in range(steps.size()):
		var step: Dictionary = steps[si]
		if dais_open and si > close_dais:
			blocked.append(plan.dais_rect())
			dais_open = false
		# opt 1.0 means the room is not that room without it. Anything less is a
		# dressing roll, nudged by how cluttered the household is. Rolling for
		# the mandatory pieces too is how a bedroom came out with no bed in it
		# five per cent of the time.
		var must: bool = float(step["opt"]) >= 1.0 \
			and not bool(step.get("repair_optional", false))
		if not must and not bool(step.get("always_attempt", false)) \
				and r.randf() > float(step["opt"]) * lerpf(0.75, 1.15, spec.clutter):
			continue
		var placed_from := plan.furniture.size()
		if step["rule"] == &"row":
			var row_count_before: int = plan.furniture.size()
			HouseFurnishPlacement.place_row(plan, room, step, blocked, zones, r)
			for placed in range(placed_from, plan.furniture.size()):
				plan.furniture[placed]["must"] = must
				_set_activity_group(plan.furniture[placed], step)
			var row_group: String = String(step.get("group", ""))
			var row_minimum: int = int(step.get("min_n", step["n"][0]))
			if must and not row_group.is_empty() \
					and plan.furniture.size() - row_count_before < row_minimum:
				plan.note_compromise(room, "activity:" + row_group)
				plan.note_compromise(room, "activity:%s:%s" % [row_group, String(step["cat"])])
			continue
		var lo: int = int(step["n"][0])
		var hi: int = int(step["n"][1])
		var want: int = lo if hi <= lo else r.randi_range(lo, hi)
		if HouseFurnishingRecipes.is_ordinary_house(plan) \
				and String(step.get("group", "")) == "eating" \
				and String(step.get("cat", "")) == "seat" \
				and HouseFurnishingRecipes.dining_room_of(plan) == room:
			var already_tagged_seats := 0
			for existing_piece in plan.furniture:
				if int(existing_piece["room"]) == room \
						and String(existing_piece.get("activity_group", "")) == "eating" \
						and String(existing_piece["cat"]) == "seat":
					already_tagged_seats += 1
			want = maxi(0, want - already_tagged_seats)
		if step["rule"] == &"around" and String(step.get("host", "")) == "row":
			# Seats for a row are seats for every table in it. Two benches
			# for a hall of eight trestles is six tables nobody sits at
			# (walk QA, 6 Oct); each bench goes to the emptiest trestle, so
			# one per table is the least a full row is owed.
			want = maxi(want, _count_row_tables(plan, room))
		var seats_before: int = _count_cat(plan, room, ["seat", "bench"])
		for k in range(want):
			var piece_from := plan.furniture.size()
			HouseFurnishPlacement.place_one(plan, spec, room, String(step["cat"]), step["rule"],
				blocked, zones, r, step)
			for placed in range(piece_from, plan.furniture.size()):
				plan.furniture[placed]["must"] = must
				_set_activity_group(plan.furniture[placed], step)
				if HouseFurnishingRecipes.is_ordinary_house(plan) \
						and String(step.get("cat", "")) == "bed":
					_reserve_sleep_access_clearance(plan, room, zones)
				if bool(step.get("settle", false)):
					# a settle is a seat against a wall, sat on for itself; it
					# is not drawn up to anything and nothing is missing
					plan.furniture[placed]["settle"] = true
			if bool(step.get("settle", false)) and plan.furniture.size() > piece_from \
					and bool(plan.furniture[-1].get("free_standing", false)):
				# no wall would take it, and a settle out in the middle of the
				# floor is the bench-without-a-table this programme replaces
				var stray: Dictionary = plan.furniture.pop_back()
				blocked.erase(stray["rect"])
				zones.erase(stray["zone"])
		var placed_count: int = plan.furniture.size() - placed_from
		var group_name: String = String(step.get("group", ""))
		if must and not group_name.is_empty() and placed_count < want:
			plan.note_compromise(room, "activity:" + group_name)
			plan.note_compromise(room, "activity:%s:%s" % [group_name, String(step["cat"])])
		# A table nobody can sit at is worse than no table: it takes the middle
		# of the room and gives nothing back. If not one seat would go round it,
		# the table goes instead, and the plan records why.
		#
		# A row is the exception: it is placed and judged as a row (straight,
		# pitched, its own shared aisle), and "around" finding nowhere to draw
		# a chair up to ONE end of a long trestle is not the same failure as a
		# free-standing table nobody can reach at all.
		if want > 0 and step["rule"] == &"around" and _count_cat(plan, room, ["seat", "bench"]) \
				== seats_before and _count_freestanding_tables(plan, room) > 0:
			_drop_the_table(plan, room, blocked, zones)
	if dais_open:
		blocked.append(plan.dais_rect())
	_ensure_seating(plan, room, blocked, zones, r)
	_ensure_light(plan, room, r)
	return _keep_the_room_passable(plan, room, blocked, zones, before_room_nav)


## Keep a walker's shoulder width clear around the bedside access strip before
## later storage is placed. A clothes chest can fit outside the bed's exact
## use rectangle yet leave only a 21 cm gap that nobody can walk through.
static func _reserve_sleep_access_clearance(plan: HousePlan, room: int,
		zones: Array[Rect2]) -> void:
	for index in plan.furniture_of(room):
		var piece: Dictionary = plan.furniture[index]
		if String(piece.get("cat", "")) != "bed" or String(piece.get("activity_group", "")) != "sleep":
			continue
		var access := Rect2(piece.get("zone", Rect2()))
		if not access.has_area():
			return
		for zone_index in zones.size():
			if zones[zone_index].is_equal_approx(access):
				zones[zone_index] = HouseFurnishGeometry.ordinary_bedside_aisle(
					access, Rect2(piece.get("rect", Rect2())), float(piece.get("yaw", 0.0)))
				return


## The last step allowed to put something on the dais: the seat behind the
## focus if the recipe has one, else the focus itself. -1 when the room has no
## dais, in which case nothing is closed off at all.
static func _dais_closes_after(plan: HousePlan, room: int, steps: Array) -> int:
	if plan.dais_room() != room or plan.dais_rect().size.x <= 0.0:
		return -1
	for i in range(steps.size() - 1, -1, -1):
		if steps[i]["rule"] == &"behind":
			return i
	for i2 in range(steps.size()):
		if String(steps[i2]["cat"]) == plan.focus_cat():
			return i2
	return -1


## Check the walking as each room is finished, not only at the end.
##
## Compare the current report with the report taken before this room. If the
## same failures were already present, do not strip this room to answer for an
## earlier room. A clean-to-blocked transition still gets the bounded local
## repair below; a genuinely worsened report remains eligible too.
static func _keep_the_room_passable(plan: HousePlan, room: int,
		blocked: Array[Rect2], zones: Array[Rect2], before_room_nav: Dictionary = {}) -> Dictionary:
	for attempt in range(3):
		var rep: Dictionary = HouseNavCheck.new().check(plan)
		if rep["ok"]:
			return rep
		if not bool(before_room_nav.get("ok", true)) \
				and _same_nav_failure_identity(before_room_nav, rep):
			return rep
		var victim := -1
		var best_area := 0.0
		for f in plan.furniture_of(room):
			var p: Dictionary = plan.furniture[f]
			if p.get("must", false) or p.get("mounted", false) or p["host"] >= 0:
				continue
			if not PropCatalog.blocks_floor(p["key"]):
				continue
			var rect: Rect2 = p["rect"]
			var area: float = rect.size.x * rect.size.y
			if area > best_area:
				best_area = area
				victim = f
		if victim < 0:
			return rep
		var repair_indices := HouseFurnishRepair._repair_target_indices(plan, victim)
		for ri in range(repair_indices.size() - 1, -1, -1):
			var index: int = repair_indices[ri]
			if index >= plan.furniture.size():
				continue
			blocked.erase(plan.furniture[index]["rect"])
			zones.erase(plan.furniture[index]["zone"])
			plan.furniture.remove_at(index)
			HouseFurnishRepair.reindex_hosts(plan, index)
	# The third attempt may have removed furniture. Return a report of that
	# final plan state, never the report taken before its last mutation.
	return HouseNavCheck.new().check(plan)


## Failure identity includes the actual messages and affected room/item indices.
## Counts alone can hide one old failure being replaced by a different one.
static func _same_nav_failure_identity(a: Dictionary, b: Dictionary) -> bool:
	return _sorted_nav_values(a.get("failures", [])) == _sorted_nav_values(b.get("failures", [])) \
		and _sorted_nav_values(a.get("unreached_rooms", [])) == _sorted_nav_values(b.get("unreached_rooms", [])) \
		and _sorted_nav_values(a.get("unreachable_items", [])) == _sorted_nav_values(b.get("unreachable_items", []))


static func _sorted_nav_values(values: Array) -> Array:
	var out: Array = values.duplicate()
	out.sort()
	return out


## A table with nothing to sit at it is a table nobody uses.
##
## The seating steps are rolls like any other, and a room can lose all of them
## to chance or to a tight corner. So the room is checked once at the end: if
## there is a table and no seat, one more seat is attempted, and if even that
## will not go in, the table comes out and the plan says so.
static func _ensure_seating(plan: HousePlan, room: int, blocked: Array[Rect2],
		zones: Array[Rect2], r: RandomNumberGenerator) -> void:
	if plan.kind_of(room) == &"sanctuary":
		return # An altar is approached standing; its nave owns the seats.
	if _count_cat(plan, room, ["table"]) == 0:
		if plan.was_dropped(room, "table"):
			_recover_dining_pair(plan, room, blocked, zones)
		return
	if _count_cat(plan, room, ["seat", "bench"]) > 0:
		return
	for cat in ["seat", "bench"]:
		for key in PropCatalog.of_category(cat):
			HouseFurnishPlacement.place_around(plan, room, key, blocked, zones, r)
			if _count_cat(plan, room, ["seat", "bench"]) > 0:
				return
	_drop_the_table(plan, room, blocked, zones)
	_recover_dining_pair(plan, room, blocked, zones)


## A table that fits alone may leave no room for a chair. Before accepting
## that compromise, try the measured table sizes with a seat as one unit.
## This bounded fallback runs only after the ordinary recipe lost its table.
static func _recover_dining_pair(plan: HousePlan, room: int, blocked: Array[Rect2],
		zones: Array[Rect2]) -> void:
	if _count_cat(plan, room, ["table"]) > 0:
		return
	if plan.focus_room() == room and plan.focus_cat() == "table":
		return # an altar or high table has its own authored seating contract
	var required := false
	for step in HouseFurnishingRecipes.recipe_for_room(plan, room):
		if step["cat"] == "table" and float(step["opt"]) >= 1.0 and step["rule"] == &"free":
			required = true
	if not required:
		return
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = hash("dining|%d|%d" % [plan.spec.seed, room])
	var original_blocked_count: int = blocked.size()
	var borrowed_band_count := 0
	if HouseFurnishingRecipes.is_ordinary_house(plan) \
			and HouseFurnishingRecipes.dining_room_of(plan) == room:
		borrowed_band_count = HouseFurnishPlacement._borrow_activity_band(
			plan, room, "eating", blocked)
	var required_seats: int = 1
	if HouseFurnishingRecipes.is_ordinary_house(plan) \
			and HouseFurnishingRecipes.dining_room_of(plan) == room:
		required_seats = _household_seat_capacity(plan)
	for key in PropCatalog.of_category("table"):
		var placed_from := plan.furniture.size()
		var placement_height_scale := -1.0
		if HouseFurnishingRecipes.is_ordinary_house(plan) \
				and HouseFurnishingRecipes.dining_room_of(plan) == room:
			placement_height_scale = 1.0
		HouseFurnishPlacement.place_free(plan, room, key, blocked, zones, local_rng,
			true, "seat", required_seats, required_seats > 1, placement_height_scale)
		if _count_cat(plan, room, ["table"]) > 0:
			for placed in range(placed_from, plan.furniture.size()):
				plan.furniture[placed]["must"] = true
				if HouseFurnishingRecipes.is_ordinary_house(plan) \
						and HouseFurnishingRecipes.dining_room_of(plan) == room:
					_set_activity_group(plan.furniture[placed], {"group": "eating"})
			var seated_count := 0
			for piece in plan.furniture:
				if int(piece["room"]) == room and String(piece.get("activity_group", "")) == "eating" \
						and String(piece["cat"]) == "seat":
					seated_count += 1
			if seated_count < required_seats:
				continue
			# These two requirements have now been physically restored.
			var dropped: Array = plan.compromises.get(room, [])
			dropped.erase("table")
			dropped.erase("seat")
			dropped.erase("activity:eating")
			dropped.erase("activity:eating:table")
			dropped.erase("activity:eating:seat")
			dropped.erase("activity:eating:seat_capacity")
			break
	HouseFurnishPlacement._restore_borrowed_blocks(blocked, original_blocked_count,
		borrowed_band_count)


static func _count_cat(plan: HousePlan, room: int, cats: Array) -> int:
	var n := 0
	for f in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[f]["key"]) in cats:
			n += 1
	return n


## Was the household's dining room already furnished, and did it end up with
## no table? Then this parlour is where they eat after all: one table, not none.
static func _dining_table_lost(plan: HousePlan, room: int) -> bool:
	var dining := HouseFurnishingRecipes.dining_room_of(plan)
	if dining < 0 or dining > room:
		return false
	return _count_cat(plan, dining, ["table"]) == 0


static func _count_row_tables(plan: HousePlan, room: int) -> int:
	var n := 0
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(p["key"]) == "table" and String(p.get("row", "")) != "":
			n += 1
	return n


## Tables that stand on their own, as opposed to ones placed as part of a row.
static func _count_freestanding_tables(plan: HousePlan, room: int) -> int:
	var n := 0
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(p["key"]) == "table" and String(p.get("row", "")) == "":
			n += 1
	return n


## Take the table back out, and free the floor it was holding.
static func _drop_the_table(plan: HousePlan, room: int, blocked: Array[Rect2],
		zones: Array[Rect2]) -> void:
	for f in range(plan.furniture.size() - 1, -1, -1):
		var p: Dictionary = plan.furniture[f]
		if int(p["room"]) != room or PropCatalog.category(p["key"]) != "table":
			continue
		# a row is placed and judged as a row; taking one trestle out of the
		# middle of it would break the very thing the row rule measures
		if String(p.get("row", "")) != "":
			continue
		# nor the piece the PLAN put there. A table nobody sits at is usually a
		# table in the way -- but a chapel altar is a table nobody sits at on
		# purpose, and dropping it is the furnisher overruling the plan that
		# asked for it (INT-002).
		if plan.focus_room() == room and plan.focus_cat() == "table" \
				and Rect2(p["rect"]).get_center().distance_to(plan.focus_pos()) \
				< HouseFurnishScore.FOCUS_TOL:
			continue
		# and never a table somebody is already sitting at: a step that found
		# no room for ONE more chair is not a table nobody can use
		var seated := false
		for g in plan.furniture_of(room):
			if int(plan.furniture[g]["host"]) == f \
					and PropCatalog.category(plan.furniture[g]["key"]) in ["seat", "bench"]:
				seated = true
				break
		if seated:
			continue
		blocked.erase(p["rect"])
		plan.note_compromise(room, "table")
		plan.furniture.remove_at(f)
		HouseFurnishRepair.reindex_hosts(plan, f)
		return


## A room nobody can see in is not furnished. Ordinary houses need one light
## for each 35 m2 above the existing 30 m2 audit threshold. Large rooms prefer
## a ceiling fixture or real hosted candles when an optional mirrored sconce
## pair has no safe station; custom families keep the historic one-light fallback.
const REQUIRED_LIGHT_ROOM_AREA := 30.0
const REQUIRED_LIGHT_AREA := 35.0

static func _ensure_light(plan: HousePlan, room: int, r: RandomNumberGenerator) -> void:
	if not HouseGeometry.is_habitable(plan.kind_of(room)):
		return
	if HouseFurnishingRecipes.is_ordinary_house(plan):
		_ensure_ordinary_light_coverage(plan, room, r)
		return
	if _room_light_count(plan, room) > 0:
		return
	for cat in ["candle", "sconce"]:
		var before: int = plan.furniture.size()
		var rule: StringName = &"on" if cat == "candle" else &"mounted"
		var choices: Array[String] = PropCatalog.of_category_for_room(cat, plan.kind_of(room))
		if choices.is_empty():
			continue
		var key: String = choices[r.randi_range(0, choices.size() - 1)]
		if rule == &"on":
			HouseFurnishSurface.place_on_surface(plan, room, key, r)
		else:
			HouseFurnishSurface.place_mounted(plan, room, key, r)
		if plan.furniture.size() > before:
			return


static func _ensure_ordinary_light_coverage(plan: HousePlan, room: int,
		r: RandomNumberGenerator) -> void:
	var area := HouseGeometry.room_area(plan, room)
	var required := _required_light_count(plan, room)
	if area < REQUIRED_LIGHT_ROOM_AREA:
		if _room_light_count(plan, room) == 0:
			for cat in ["candle", "sconce"]:
				var choices: Array[String] = PropCatalog.of_category_for_room(cat, plan.kind_of(room))
				if choices.is_empty():
					continue
				var before: int = plan.furniture.size()
				var key: String = choices[r.randi_range(0, choices.size() - 1)]
				if cat == "candle":
					HouseFurnishSurface.place_on_surface(plan, room, key, r)
				else:
					HouseFurnishSurface.place_mounted(plan, room, key, r)
				if plan.furniture.size() > before:
					break
		return
	while _room_light_count(plan, room) < required:
		var before := _room_light_count(plan, room)
		# A chandelier is a legitimate large-room source and does not depend on
		# an available mirrored wall pair. Add at most one; subsequent sources
		# must sit on actual supporting furniture.
		var has_chandelier := false
		for index in plan.furniture_of(room):
			if PropCatalog.category(String(plan.furniture[index]["key"])) == "chandelier":
				has_chandelier = true
				break
		if not has_chandelier:
			var chandeliers: Array[String] = PropCatalog.of_category_for_room(
				"chandelier", plan.kind_of(room))
			if not chandeliers.is_empty():
				HouseFurnishSurface.place_ceiling(plan, room,
					chandeliers[r.randi_range(0, chandeliers.size() - 1)])
		if _room_light_count(plan, room) == before:
			# Candles are hosted by measured tables and work surfaces. Bounded
			# retries let a room with several hosts avoid a full first surface.
			var candles: Array[String] = PropCatalog.of_category_for_room(
				"candle", plan.kind_of(room))
			for attempt in range(6):
				if candles.is_empty() or _room_light_count(plan, room) >= required:
					break
				var before_candle := _room_light_count(plan, room)
				HouseFurnishSurface.place_on_surface(plan, room,
					candles[r.randi_range(0, candles.size() - 1)], r)
				if _room_light_count(plan, room) == before_candle:
					continue
		if _room_light_count(plan, room) == before:
			break
	if _room_light_count(plan, room) < required:
		plan.note_compromise(room, "lighting:minimum")


static func _required_light_count(plan: HousePlan, room: int) -> int:
	var area := HouseGeometry.room_area(plan, room)
	return int(ceil(area / REQUIRED_LIGHT_AREA)) if area >= REQUIRED_LIGHT_ROOM_AREA else 1


static func _room_light_count(plan: HousePlan, room: int) -> int:
	var count := 0
	for index in plan.furniture_of(room):
		if PropCatalog.has_tag(String(plan.furniture[index]["key"]), PropCatalog.LIGHT):
			count += 1
	return count

