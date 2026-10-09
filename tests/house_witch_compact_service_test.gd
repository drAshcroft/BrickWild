extends SceneTree
## Root-run compact Witch programme contract, including a measured frontage negative.
const SEEDS := [1, 8102, 21325]
var failures: Array[String] = []

func _init() -> void:
	for seed_value in SEEDS:
		_check_public_compact_case(seed_value)
	_check_impossible_service_frontage()
	for failure in failures:
		printerr("FAIL ", failure)
	print("witch compact service programme: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)

func _make_request(width: float, length: float, seed_value: int) -> BuildingRequest:
	return BuildingRequest.from_dict({
		"schema": "brickwild.request", "schema_version": 1, "kind": "house",
		"style": "witch_hut", "purpose": "none", "seed": str(seed_value),
		"width": width, "length": length, "height": 2.6, "storeys": 1,
		"material": "timber", "enclosure": "none", "water": "none",
		"orientation": 0.0, "period": 1200,
	})

func _check_legacy_shared_kitchen_recipe(plan: HousePlan) -> void:
	var halls := plan.rooms_of(&"hall")
	if halls.is_empty():
		failures.append("legacy shared-kitchen control has no hall fixture")
		return
	var room: int = halls[0]
	var original: Dictionary = plan.rooms[room].duplicate(true)
	var legacy: Dictionary = original.duplicate(true)
	legacy["kind"] = &"kitchen"
	legacy.erase("shared_activity_station")
	plan.rooms[room] = legacy
	var recipe: Array = HouseFurnishingRecipes.recipe_for_room(plan, room, true)
	var cooking_hearth := 0
	var witchwork_hearth := 0
	var aliased_hearth := 0
	for step in recipe:
		if String(step.get("cat", "")) != "hearth":
			continue
		if String(step.get("group", "")) == "cooking":
			cooking_hearth += 1
		if String(step.get("group", "")) == "witchwork":
			witchwork_hearth += 1
		if not Array(step.get("shared_activity_groups", [])).is_empty():
			aliased_hearth += 1
	if cooking_hearth != 1 or witchwork_hearth != 1 or aliased_hearth != 0:
		failures.append("legacy shared Witchwork kitchen must retain two independent heat recipes without compact aliases")
	plan.rooms[room] = original

func _furniture_signature(plan: HousePlan) -> Array[String]:
	var rows: Array[String] = []
	for piece in plan.furniture:
		rows.append("%s|%d|%s|%s|%s|%s|%s|%s" % [
			piece.get("key", ""), int(piece.get("room", -1)), piece.get("pos", Vector3.ZERO),
			piece.get("yaw", 0.0), piece.get("scale", 1.0),
			piece.get("activity_group", ""), piece.get("rect", Rect2()), piece.get("zone", Rect2())])
	return rows

func _check_public_compact_case(seed_value: int) -> void:
	var label := "witch_small_%d" % seed_value
	var request := _make_request(7.0, 9.0, seed_value)
	if not request._decode_errors.is_empty():
		failures.append("%s request decode failed: %s" % [label, str(request._decode_errors)])
		return
	var built: GeneratedBuilding = BrickWild.generate(request)
	if not built.is_ok() or built.plan == null:
		failures.append("%s public generation failed: %s" % [label, str(built.errors)])
		return
	var plan: HousePlan = built.plan
	if seed_value == 8102:
		var repeated: GeneratedBuilding = BrickWild.generate(_make_request(7.0, 9.0, seed_value))
		if not repeated.is_ok() or repeated.plan == null:
			failures.append("%s repeated request failed" % label)
		elif _furniture_signature(plan) != _furniture_signature(repeated.plan):
			failures.append("%s repeated seed changed measured furniture poses or activity groups" % label)
	if seed_value == SEEDS[0]:
		_check_legacy_shared_kitchen_recipe(plan)
	if String(plan.domestic_layout.get("status", "")) != "planned":
		failures.append("%s compact domestic layout is not planned: %s" % [label, str(plan.domestic_layout)])
	if not plan.domestic_layout.get("merged_activities", []).has(&"workshop") or not plan.domestic_layout.get("merged_activities", []).has(&"kitchen") or not plan.domestic_layout.get("ground_activities", []).has(&"workshop"):
		failures.append("%s does not explicitly record kitchen and Witchwork as merged ground activities" % label)
	if not plan.domestic_layout.get("added_activities", []).has(&"store"):
		failures.append("%s does not record the purposeful compact dry pantry room" % label)
	if int(plan.domestic_layout.get("requested_rooms", 0)) != 3 or int(plan.domestic_layout.get("planned_rooms", 0)) != 3 or not plan.domestic_layout.get("omitted_activities", []).is_empty():
		failures.append("%s compact Witch layout omitted a requested activity: %s" % [label, str(plan.domestic_layout)])
	for required_kind in [&"hall", &"bedroom", &"store"]:
		if plan.rooms_of(required_kind).size() != 1:
			failures.append("%s must preserve one %s room" % [label, String(required_kind)])
	var halls := plan.rooms_of(&"hall")
	if halls.is_empty():
		return
	var service_room := halls[0]
	var functions: Array = plan.rooms[service_room].get("domestic_functions", [])
	if not functions.has(&"cooking") or not functions.has(&"witchwork") or not bool(plan.rooms[service_room].get("shared_cooking", false)) or not bool(plan.rooms[service_room].get("shared_witchwork", false)):
		failures.append("%s hall lacks explicit shared cooking and Witchwork contracts" % label)
	var regions: Dictionary = plan.rooms[service_room].get("activity_regions", {})
	var heat_contract: Dictionary = plan.rooms[service_room].get("shared_activity_station", {})
	if String(heat_contract.get("id", "")) != "compact_witch_hearth" or String(heat_contract.get("scope", "")) != "compact_witch_shared_hall" or not Array(heat_contract.get("groups", [])).has(&"cooking") or not Array(heat_contract.get("groups", [])).has(&"witchwork"):
		failures.append("%s shared activity contract is not the explicit compact Witch hall station" % label)
	if not regions.has(&"eating") or not regions.has(&"cooking") or not regions.has(&"witchwork"):
		failures.append("%s hall lacks meal and shared-service reservations" % label)
	else:
		var floor: Rect2 = HouseGeometry.room_floor_rect(plan, service_room)
		var eating: Rect2 = regions[&"eating"]
		var cooking: Rect2 = regions[&"cooking"]
		var witchwork: Rect2 = regions[&"witchwork"]
		var cooking_left := absf(cooking.position.x - floor.position.x) <= 0.002
		var service_width := 4.10
		var meal_width := 2.10
		var buffer_width := 0.10
		var expected_service := Rect2(Vector2(floor.position.x if cooking_left else floor.end.x - service_width, floor.position.y),
			Vector2(service_width, floor.size.y))
		var expected_eating := Rect2(Vector2(floor.end.x - meal_width if cooking_left else floor.position.x, floor.position.y),
			Vector2(meal_width, floor.size.y))
		if not eating.is_equal_approx(expected_eating) or not cooking.is_equal_approx(expected_service) or not witchwork.is_equal_approx(expected_service):
			failures.append("%s service and meal reservations do not match the measured 4.10/0.10/2.10m layout" % label)
		if not floor.encloses(eating) or not floor.encloses(cooking) or not floor.encloses(witchwork) or eating.intersects(cooking) or eating.intersects(witchwork) or not cooking.is_equal_approx(witchwork):
			failures.append("%s shared service/meal reservations leave the measured hall floor or diverge" % label)
	_check_group_count(plan, service_room, "cooking", "workbench", 1, label)
	_check_group_count(plan, service_room, "cooking", "hearth", 1, label)
	_check_group_count(plan, service_room, "cooking", "storage", 1, label)
	_check_group_count(plan, service_room, "cooking", "bucket", 1, label)
	_check_min_count(plan, service_room, "cooking", "cookware", 1, label)
	_check_group_count(plan, service_room, "witchwork", "workbench", 1, label)
	_check_min_count(plan, service_room, "witchwork", "shelf", 1, label)
	_check_group_count(plan, service_room, "witchwork", "sconce", 1, label)
	_check_group_count(plan, service_room, "witchwork", "hearth", 1, label)
	_check_group_count(plan, service_room, "witchwork", "alchemy", 2, label)
	_check_group_count(plan, service_room, "witchwork", "books", 1, label)
	_check_compact_book_support(plan, service_room, label)
	_check_cooking_prep_relation(plan, service_room, label)
	_check_shared_heat_station(plan, service_room, label)
	_fixture_check_activity_geometry(plan, service_room, regions, label)
	var positive_storage: bool = _has_reachable_witch_storage(plan, service_room)
	if seed_value == SEEDS[0]:
		_fixture_activity_geometry_negatives(plan, service_room, regions, label, positive_storage)
	_check_witch_pantry(plan, label)
	_check_group_count(plan, service_room, "eating", "table", 1, label)
	_check_min_count(plan, service_room, "eating", "seat", 2, label)
	_check_meal_host_and_room(plan, service_room, label)
	var bedrooms := plan.rooms_of(&"bedroom")
	if bedrooms.size() != 1:
		return
	var bedroom: int = bedrooms[0]
	if not _has_door_between(plan, service_room, bedroom):
		failures.append("%s private bedroom is not directly reached from the hall" % label)
	_check_group_count(plan, bedroom, "sleep", "bed", 1, label)
	_check_group_count(plan, bedroom, "sleep", "chest", 1, label)
	var nav := HouseNavCheck.new().check(plan)
	if not bool(nav.get("ok", false)):
		failures.append("%s combined household plan is not reachable: %s" % [label, str(nav)])
	if String(plan.domestic_layout.get("activity_status", "")) != "complete":
		failures.append("%s required activity audit is not complete: %s" % [label, str(plan.domestic_layout.get("activity_shortfalls", []))])
	_check_missing_role_negatives(plan, service_room, label)

func _fixture_check_activity_geometry(plan: HousePlan, room: int, regions: Dictionary, label: String) -> void:
	var rows_by_group: Dictionary = {"eating": [], "cooking": [], "witchwork": []}
	for index in plan.furniture_of(room):
		var piece: Dictionary = plan.furniture[index]
		var group: String = String(piece.get("activity_group", ""))
		if not rows_by_group.has(group):
			continue
		var body: Rect2 = Rect2(piece.get("rect", Rect2()))
		var use: Rect2 = Rect2(piece.get("zone", Rect2()))
		if not body.has_area():
			failures.append("%s %s item %s has no measured body" % [label, group, String(piece.get("key", ""))])
			continue
		if not regions.has(StringName(group)):
			failures.append("%s %s item has no matching activity reservation" % [label, group])
			continue
		var activity_body := body
		var mounted: bool = bool(piece.get("mounted", false))
		var on_surface: bool = PropCatalog.has_tag(String(piece.get("key", "")), PropCatalog.ON_SURFACE)
		var ceiling_piece: bool = PropCatalog.has_tag(String(piece.get("key", "")), PropCatalog.CEILING)
		if mounted:
			var key := String(piece.get("key", ""))
			var yaw := float(piece.get("yaw", 0.0))
			var scale := float(piece.get("scale", 1.0))
			var model_yaw := yaw + PropCatalog.face_offset(key)
			var origin := PropCatalog.house_origin(piece)
			var centre := PropCatalog.plan_centre(key, origin, model_yaw, scale)
			var measured := PropCatalog.footprint_rotated(key, model_yaw) * scale
			body = Rect2(centre - measured * 0.5, measured)
			activity_body = body.intersection(HouseGeometry.room_floor_rect(plan, room))
		if mounted or on_surface or ceiling_piece:
			use = Rect2()
		var region: Rect2 = Rect2(regions[StringName(group)])
		if not activity_body.has_area() or not region.grow(0.01).encloses(activity_body) \
				or (use.has_area() and not region.grow(0.01).encloses(use)):
			failures.append("%s %s %s body/use-zone escaped its reserved activity region" % [label, group, String(piece.get("key", ""))])
		var vertical := _vertical_prop_bounds(piece)
		rows_by_group[group].append({"index": index, "body": activity_body,
			"zone": use, "bottom": vertical.x, "top": vertical.y})
	var groups: Array[String] = ["eating", "cooking", "witchwork"]
	for first_group_index in range(groups.size()):
		var first_group: String = groups[first_group_index]
		for second_group_index in range(first_group_index + 1, groups.size()):
			var second_group: String = groups[second_group_index]
			var reported := false
			for first in rows_by_group[first_group]:
				for second in rows_by_group[second_group]:
					var first_body: Rect2 = Rect2(first["body"])
					var first_zone: Rect2 = Rect2(first["zone"])
					var second_body: Rect2 = Rect2(second["body"])
					var second_zone: Rect2 = Rect2(second["zone"])
					var first_body_hits_second_stance: bool = first_body.intersects(second_zone) \
						and float(first["bottom"]) < 1.80 and float(first["top"]) > 0.02
					var second_body_hits_first_stance: bool = second_body.intersects(first_zone) \
						and float(second["bottom"]) < 1.80 and float(second["top"]) > 0.02
					var bodies_overlap_in_height: bool = first_body.intersects(second_body) \
						and minf(float(first["top"]), float(second["top"])) - maxf(float(first["bottom"]), float(second["bottom"])) > 0.002
					if first_body_hits_second_stance or second_body_hits_first_stance \
						or bodies_overlap_in_height:
						if not reported:
							failures.append("%s %s and %s bodies/use-zones physically overlap in the measured vertical span" % [label, first_group, second_group])
							reported = true

	var workbenches: Array[Dictionary] = []
	var shelves: Array[Dictionary] = []
	var sconces: Array[Dictionary] = []
	for index in plan.furniture_of(room):
		var item: Dictionary = plan.furniture[index]
		var category := String(item.get("cat", ""))
		if category == "shelf":
			shelves.append(item)
		if String(item.get("activity_group", "")) != "witchwork":
			continue
		if category == "workbench":
			workbenches.append(item)
		elif category == "sconce":
			sconces.append(item)
	if workbenches.size() == 1:
		if not _has_reachable_witch_storage(plan, room, workbenches[0], shelves):
			failures.append("%s has no mounted Witchwork storage within arm reach of the actual work stance" % label)
		if not _compact_witchwork_opening_clear(plan, room, workbenches[0], shelves):
			failures.append("%s a hall window intersects the actual Witchwork bench or bound rack" % label)
	if workbenches.size() == 1 and sconces.size() == 1:
		var work_zone := Rect2(workbenches[0].get("zone", Rect2()))
		var lamp_body := Rect2(sconces[0].get("rect", Rect2()))
		if HousePlanFeatures._rect_distance(work_zone, lamp_body) > 1.9:
			failures.append("%s Witchwork lamp is not near the measured working stance" % label)


func _compact_witchwork_opening_clear(plan: HousePlan, room: int,
		bench: Dictionary, shelves: Array[Dictionary]) -> bool:
	var bench_rect := _measured_plan_rect(bench)
	for window_index in plan.windows_of(room):
		var window: Dictionary = plan.windows[window_index]
		if not _window_is_on_actual_exterior_wall(plan, room, window):
			return false
		var clear: Rect2 = HouseGeometry.window_clear_rect(window)
		if clear.intersects(bench_rect.grow(0.01)):
			return false
		var anchor_id := String(bench.get("surface_anchor_id", ""))
		for shelf in shelves:
			if String(shelf.get("activity_anchor_id", "")) != anchor_id:
				continue
			if bool(shelf.get("mounted", false)) and clear.intersects(_measured_plan_rect(shelf).grow(0.01)):
				return false
	return true


func _window_is_on_actual_exterior_wall(plan: HousePlan, room: int,
		window: Dictionary) -> bool:
	var outward: Vector2 = Vector2(window.get("normal", Vector2.ZERO)).normalized()
	var pos: Vector2 = Vector2(window.get("pos", Vector2.ZERO))
	var width := float(window.get("width", 0.0))
	for wall in HouseGeometry.room_walls(plan, room):
		var inward: Vector2 = Vector2(wall.get("normal", Vector2.ZERO)).normalized()
		if outward.dot(-inward) < 0.999:
			continue
		var from: Vector2 = Vector2(wall.get("from", Vector2.ZERO))
		var to: Vector2 = Vector2(wall.get("to", Vector2.ZERO))
		var axis := 0 if absf(inward.x) > 0.5 else 1
		var line := from.x if axis == 0 else from.y
		if not HouseGeometry.is_exterior_edge(plan.spec, axis, line):
			continue
		var along := (to - from).normalized()
		var offset := (pos - from).dot(along)
		if absf((pos - from).dot(inward)) <= 0.025 \
				and offset >= width * 0.5 - 0.01 \
				and offset <= from.distance_to(to) - width * 0.5 + 0.01:
			return true
	return false


func _has_reachable_witch_storage(plan: HousePlan, room: int,
		known_bench: Dictionary = {}, known_shelves: Array[Dictionary] = []) -> bool:
	var bench: Dictionary = known_bench
	var shelves: Array[Dictionary] = known_shelves
	if bench.is_empty():
		for index in plan.furniture_of(room):
			var candidate: Dictionary = plan.furniture[index]
			if String(candidate.get("activity_group", "")) == "witchwork" and String(candidate.get("cat", "")) == "workbench":
				if not bench.is_empty():
					return false
				bench = candidate
	if shelves.is_empty():
		for index in plan.furniture_of(room):
			var candidate: Dictionary = plan.furniture[index]
			if String(candidate.get("cat", "")) == "shelf":
				shelves.append(candidate)
	if bench.is_empty() or shelves.is_empty():
		return false
	var work_zone: Rect2 = Rect2(bench.get("zone", Rect2()))
	if not work_zone.has_area():
		return false
	var bench_key := String(bench.get("key", ""))
	var bench_scale: float = PropCatalog.placement_height_scale(bench)
	var bench_origin: Vector3 = PropCatalog.house_origin(bench)
	var bench_surface_y: float = bench_origin.y + PropCatalog.floor_offset(bench_key) * bench_scale + PropCatalog.surface_height(bench_key) * bench_scale
	for shelf in shelves:
		var shelf_rect: Rect2 = _measured_plan_rect(shelf)
		var vertical := _vertical_prop_bounds(shelf)
		var within_reach: bool = HousePlanFeatures._rect_distance(shelf_rect, work_zone) <= 0.75
		var reachable_height: bool = vertical.x >= 0.55 and vertical.x <= 1.90 and vertical.y <= 2.40
		var above_work_surface: bool = vertical.x >= bench_surface_y + 0.01
		if bool(shelf.get("mounted", false)) \
				and String(shelf.get("mount_relation", "")) == "supports_activity" \
				and String(shelf.get("activity_anchor_id", "")) == String(bench.get("surface_anchor_id", "")) \
				and String(shelf.get("content_kind", "")) == "integrated_ingredient_rack" \
				and String(shelf.get("content_asset_key", "")) == String(shelf.get("key", "")) \
				and within_reach and reachable_height and above_work_surface \
				and _shelf_has_actual_wall_host(plan, room, shelf, shelf_rect):
			return true
	return false


func _measured_plan_rect(piece: Dictionary) -> Rect2:
	var key := String(piece.get("key", ""))
	var scale := float(piece.get("scale", 1.0))
	var yaw := float(piece.get("yaw", 0.0))
	var model_yaw := yaw + PropCatalog.face_offset(key)
	var origin: Vector3 = PropCatalog.house_origin(piece)
	var centre: Vector2 = PropCatalog.plan_centre(key, origin, model_yaw, scale)
	var footprint: Vector2 = PropCatalog.footprint_rotated(key, model_yaw) * scale
	return Rect2(centre - footprint * 0.5, footprint)


func _shelf_has_actual_wall_host(plan: HousePlan, room: int,
		shelf: Dictionary, shelf_rect: Rect2) -> bool:
	var wanted_id := String(shelf.get("wall_host_id", ""))
	if wanted_id.is_empty():
		return false
	var walls := HouseGeometry.room_walls(plan, room)
	for host in plan.wall_hosts:
		if String(host.get("id", "")) != wanted_id or int(host.get("room", -1)) != room:
			continue
		if String(host.get("role", "")) != "activity_support" \
				or String(host.get("activity_group", "")) != "witchwork" \
				or String(host.get("target_category", "")) != String(shelf.get("cat", "")) \
				or String(host.get("anchor_id", "")) != String(shelf.get("activity_anchor_id", "")):
			continue
		var wall_index: int = int(host.get("wall", -1))
		if wall_index < 0 or wall_index >= walls.size():
			return false
		var wall: Dictionary = walls[wall_index]
		var normal: Vector2 = Vector2(wall.get("normal", Vector2.ZERO)).normalized()
		var host_normal: Vector2 = Vector2(host.get("normal", Vector2.ZERO)).normalized()
		if normal.dot(host_normal) < 0.999:
			return false
		var wall_from: Vector2 = Vector2(wall.get("from", Vector2.ZERO))
		var wall_to: Vector2 = Vector2(wall.get("to", Vector2.ZERO))
		var host_from: Vector2 = Vector2(host.get("from", Vector2.ZERO))
		var host_to: Vector2 = Vector2(host.get("to", Vector2.ZERO))
		if HousePlanFeatures._rect_distance(Rect2(wall_from.min(wall_to), (wall_to - wall_from).abs()), Rect2(host_from.min(host_to), (host_to - host_from).abs())) > 0.025:
			return false
		var contact: float
		var wall_plane: float
		var body_edge: float
		if absf(normal.y) > 0.5:
			wall_plane = wall_from.y
			body_edge = shelf_rect.position.y if normal.y > 0.0 else shelf_rect.end.y
		else:
			wall_plane = wall_from.x
			body_edge = shelf_rect.position.x if normal.x > 0.0 else shelf_rect.end.x
		contact = absf(body_edge - wall_plane)
		return contact <= 0.025
	return false


func _fixture_activity_geometry_negatives(plan: HousePlan, room: int,
		regions: Dictionary, label: String, positive_storage: bool) -> void:
	var saved_windows: Array[Dictionary] = plan.windows.duplicate(true)
	var witch_bench: Dictionary = {}
	var witch_shelves: Array[Dictionary] = []
	for index in plan.furniture_of(room):
		var item: Dictionary = plan.furniture[index]
		if String(item.get("activity_group", "")) == "witchwork" and String(item.get("cat", "")) == "workbench":
			witch_bench = item
		if String(item.get("cat", "")) == "shelf":
			witch_shelves.append(item)
	if not witch_bench.is_empty() and not plan.windows_of(room).is_empty():
		var window_index: int = plan.windows_of(room)[0]
		var bad_window: Dictionary = plan.windows[window_index].duplicate(true)
		var wall: Dictionary = HouseGeometry.room_walls(plan, room)[0]
		var center: Vector2 = _measured_plan_rect(witch_bench).get_center()
		bad_window["normal"] = -Vector2(wall.get("normal", Vector2.ZERO))
		bad_window["pos"] = Vector2(center.x, Vector2(wall.get("from", Vector2.ZERO)).y)
		plan.windows[window_index] = bad_window
		var detected := not _compact_witchwork_opening_clear(plan, room, witch_bench, witch_shelves)
		plan.windows = saved_windows.duplicate(true)
		if not detected:
			failures.append("%s moved-window negative did not detect a window through the Witchwork station" % label)
	else:
		failures.append("%s moved-window negative lacks a Witchwork bench or hall window" % label)
	var saved_furniture: Array[Dictionary] = plan.furniture.duplicate(true)
	var eating_index := -1
	var cooking_index := -1
	for index in plan.furniture_of(room):
		var piece: Dictionary = plan.furniture[index]
		var group := String(piece.get("activity_group", ""))
		if bool(piece.get("mounted", false)) or int(piece.get("host", -1)) >= 0:
			continue
		if group == "eating" and eating_index < 0 and String(piece.get("cat", "")) == "table":
			eating_index = index
		elif group == "cooking" and cooking_index < 0 and String(piece.get("cat", "")) == "hearth":
			cooking_index = index
	if eating_index < 0 or cooking_index < 0:
		failures.append("%s overlap negative lacks distinct table and cooking-station bodies" % label)
	else:
		for index in [eating_index, cooking_index]:
			var item: Dictionary = plan.furniture[index].duplicate(true)
			item["pos"] = Vector3.ZERO
			item["rect"] = Rect2(Vector2(-0.25, -0.25), Vector2(0.5, 0.5))
			item["zone"] = Rect2()
			item["mounted"] = false
			item["host"] = -1
			plan.furniture[index] = item
		var before_failures: int = failures.size()
		_fixture_check_activity_geometry(plan, room, regions, label + "_overlap_negative")
		var detected := false
		for failure in failures.slice(before_failures):
			if "bodies/use-zones physically overlap" in failure:
				detected = true
				break
		failures.resize(before_failures)
		if not detected:
			failures.append("%s negative distinct-body collision was not detected by fixture geometry checker" % label)
	plan.furniture = saved_furniture.duplicate(true)
	if not positive_storage:
		failures.append("%s moved-shelf negative skipped because the positive storage case did not pass" % label)
		plan.furniture = saved_furniture
		return
	var bench_index := -1
	var shelf_index := -1
	for index in plan.furniture_of(room):
		var piece: Dictionary = plan.furniture[index]
		if String(piece.get("activity_group", "")) == "witchwork" and String(piece.get("cat", "")) == "workbench":
			bench_index = index
	if bench_index >= 0:
		var bench_anchor := String(plan.furniture[bench_index].get("surface_anchor_id", ""))
		for index in plan.furniture_of(room):
			var candidate: Dictionary = plan.furniture[index]
			if String(candidate.get("cat", "")) == "shelf" and String(candidate.get("activity_anchor_id", "")) == bench_anchor:
				shelf_index = index
				break
	if bench_index < 0 or shelf_index < 0:
		failures.append("%s shelf-displacement negative lacks an actual bound shelf and workbench" % label)
		return
	var moved_shelf: Dictionary = plan.furniture[shelf_index].duplicate(true)
	var moved_pos: Vector3 = Vector3(moved_shelf.get("pos", Vector3.ZERO))
	moved_pos.x += 4.0
	moved_shelf["pos"] = moved_pos
	var moved_rect: Rect2 = Rect2(moved_shelf.get("rect", Rect2()))
	moved_rect.position += Vector2(4.0, 0.0)
	moved_shelf["rect"] = moved_rect
	plan.furniture[shelf_index] = moved_shelf
	var saved_count: int = failures.size()
	_fixture_check_activity_geometry(plan, room, regions, label + "_moved_shelf_negative")
	var rejected := false
	for failure in failures.slice(saved_count):
		if "no mounted Witchwork storage within arm reach" in failure:
			rejected = true
			break
	failures.resize(saved_count)
	if not rejected:
		failures.append("%s negative moved shelf remained accepted by fixture support checker" % label)
	plan.furniture = saved_furniture


func _vertical_prop_bounds(piece: Dictionary) -> Vector2:
	var key := String(piece.get("key", ""))
	var height_scale: float = PropCatalog.placement_height_scale(piece)
	var origin: Vector3 = PropCatalog.house_origin(piece)
	var bottom: float = origin.y + PropCatalog.floor_offset(key) * height_scale
	return Vector2(bottom, bottom + PropCatalog.placement_height(piece))


func _check_meal_host_and_room(plan: HousePlan, room: int, label: String) -> void:
	if int(plan.domestic_layout.get("dining_room", -1)) != room:
		failures.append("%s compact hall is not the physically selected meal room" % label)
	var table_index := -1
	for index in plan.furniture_of(room):
		var piece: Dictionary = plan.furniture[index]
		if String(piece.get("activity_group", "")) == "eating" and String(piece.get("cat", "")) == "table":
			table_index = index
			break
	if table_index < 0:
		failures.append("%s selected meal group has no actual table to seat" % label)
		return
	var hosted_seats := 0
	for index in plan.furniture_of(room):
		var piece: Dictionary = plan.furniture[index]
		if String(piece.get("activity_group", "")) == "eating" and String(piece.get("cat", "")) in ["seat", "bench"] \
				and int(piece.get("host", -1)) == table_index:
			hosted_seats += 1
	if hosted_seats < 2:
		failures.append("%s measured central meal aisle lacks two seats attached to its actual table" % label)

func _check_cooking_prep_relation(plan: HousePlan, room: int, label: String) -> void:
	var workbenches: Array[Dictionary] = []
	var stores: Array[Dictionary] = []
	for index in plan.furniture_of(room):
		var piece: Dictionary = plan.furniture[index]
		if String(piece.get("activity_group", "")) != "cooking":
			continue
		if String(piece.get("cat", "")) == "workbench":
			workbenches.append(piece)
		elif String(piece.get("cat", "")) == "storage":
			stores.append(piece)
	if workbenches.size() != 1 or stores.size() != 1:
		return
	if String(workbenches[0].get("activity_host_cat", "")) != "storage":
		failures.append("%s cooking workbench is not bound to the real cooking storage role" % label)
		return
	var prep_zone: Rect2 = Rect2(workbenches[0].get("zone", Rect2()))
	var storage_body: Rect2 = Rect2(stores[0].get("rect", Rect2()))
	if not prep_zone.has_area() or not storage_body.has_area():
		failures.append("%s cooking storage/prep relation lacks real body or person stance" % label)
	elif prep_zone.intersects(storage_body):
		failures.append("%s cooking worker stance is blocked by the storage body" % label)


func _check_shared_heat_station(plan: HousePlan, room: int, label: String) -> void:
	var contract: Dictionary = plan.rooms[room].get("shared_activity_station", {})
	var contract_groups: Array = contract.get("groups", [])
	if String(contract.get("id", "")) != "compact_witch_hearth" \
			or String(contract.get("category", "")) != "hearth" \
			or not contract_groups.has(&"cooking") or not contract_groups.has(&"witchwork") \
			or not is_equal_approx(float(contract.get("max_usezone_distance", 0.0)), 1.9):
		failures.append("%s room has no explicit measured cooking/Witchwork heat-sharing contract" % label)
	var stations: Array[Dictionary] = []
	var cooking_benches: Array[Dictionary] = []
	var witch_benches: Array[Dictionary] = []
	for index in plan.furniture_of(room):
		var piece: Dictionary = plan.furniture[index]
		var category := String(piece.get("cat", ""))
		var group := String(piece.get("activity_group", ""))
		if category == "hearth" and group == "cooking" \
				and Array(piece.get("shared_activity_groups", [])).has("witchwork"):
			stations.append(piece)
		elif category == "workbench" and group == "cooking":
			cooking_benches.append(piece)
		elif category == "workbench" and group == "witchwork":
			witch_benches.append(piece)
	if stations.size() != 1:
		failures.append("%s requires exactly one real cooking hearth explicitly shared with Witchwork" % label)
		return
	var station: Dictionary = stations[0]
	var station_index := -1
	for index in plan.furniture_of(room):
		if plan.furniture[index].get("shared_station_id", "") == "compact_witch_hearth":
			station_index = index
	var shared_nav: Dictionary = HouseNavCheck.new().check(plan)
	for role in ["cooking", "witchwork"]:
		if not HouseFurnisher._shared_activity_station_valid(plan, room, station_index, role, shared_nav):
			failures.append("%s production validator rejected the real shared station for %s" % [label, role])
	if String(station.get("key", "")) != "Cauldron" \
			or String(station.get("shared_station_id", "")) != "compact_witch_hearth" \
			or Array(station.get("shared_activity_groups", [])) != ["witchwork"]:
		failures.append("%s hearth lacks the scoped two-craft station binding" % label)
	var body: Rect2 = Rect2(station.get("rect", Rect2()))
	var use: Rect2 = Rect2(station.get("zone", Rect2()))
	if not body.has_area() or not use.has_area():
		failures.append("%s shared Cauldron lacks its measured body or actual worker stance" % label)
	var regions: Dictionary = plan.rooms[room].get("activity_regions", {})
	for group in ["cooking", "witchwork"]:
		if not regions.has(StringName(group)) or not Rect2(regions[StringName(group)]).grow(0.01).encloses(body) \
				or not Rect2(regions[StringName(group)]).grow(0.01).encloses(use):
			failures.append("%s shared Cauldron body/use stance escaped the %s reservation" % [label, group])
	var breast: Dictionary = HouseGeometry.hearth_breast(plan)
	if plan.hearth_room() != room or int(breast.get("wall", -1)) != plan.hearth_wall() \
			or HousePlanFeatures._rect_distance(Rect2(breast.get("rect", Rect2())), body) > 0.01:
		failures.append("%s shared Cauldron has no actual same-wall chimney breast contact" % label)
	if cooking_benches.size() != 1 or witch_benches.size() != 1:
		failures.append("%s shared hearth needs separate measured cooking and Witchwork prep benches" % label)
		return
	var cook_zone: Rect2 = Rect2(cooking_benches[0].get("zone", Rect2()))
	var witch_zone: Rect2 = Rect2(witch_benches[0].get("zone", Rect2()))
	if not cook_zone.has_area() or not witch_zone.has_area() \
			or HousePlanFeatures._rect_distance(use, cook_zone) > 1.9 \
			or HousePlanFeatures._rect_distance(use, witch_zone) > 1.9:
		failures.append("%s actual shared-heat worker stance is more than 1.9m from one prep bench" % label)
	if PropCatalog.placement_height(witch_benches[0]) < 0.75:
		failures.append("%s Witchwork tabletop is below the 0.75m standing work height" % label)
	var original_furniture: Array = plan.furniture.duplicate(true)
	var original_compromises: Dictionary = plan.compromises.duplicate(true)
	var original_layout: Dictionary = plan.domestic_layout.duplicate(true)
	var remote_furniture: Array[Dictionary] = []
	var moved := false
	for item in original_furniture:
		var copy := Dictionary(item).duplicate(true)
		if not moved and String(copy.get("cat", "")) == "workbench" \
				and String(copy.get("activity_group", "")) == "witchwork":
			var remote_body: Rect2 = Rect2(copy.get("rect", Rect2()))
			var remote_zone: Rect2 = Rect2(copy.get("zone", Rect2()))
			var offset := Vector2(4.5, 0.0)
			copy["rect"] = Rect2(remote_body.position + offset, remote_body.size)
			copy["zone"] = Rect2(remote_zone.position + offset, remote_zone.size)
			moved = true
		remote_furniture.append(copy)
	plan.furniture = remote_furniture
	plan.compromises = original_compromises.duplicate(true)
	plan.compromises.erase(room)
	HouseFurnisher._audit_activity_groups(plan)
	if not moved or not _shortfall_has(plan, "activity:witchwork:hearth") \
			or _shortfall_has(plan, "activity:cooking:hearth"):
		failures.append("%s production audit accepted remote Witchwork prep or rejected unrelated cooking" % label)
	var unbound_furniture: Array[Dictionary] = []
	for item in original_furniture:
		var copy := Dictionary(item).duplicate(true)
		if String(copy.get("shared_station_id", "")) == "compact_witch_hearth":
			copy["shared_activity_groups"] = []
		unbound_furniture.append(copy)
	plan.furniture = unbound_furniture
	plan.compromises = original_compromises.duplicate(true)
	plan.compromises.erase(room)
	HouseFurnisher._audit_activity_groups(plan)
	if not _shortfall_has(plan, "activity:witchwork:hearth") \
			or _shortfall_has(plan, "activity:cooking:hearth"):
		failures.append("%s removing the actual heat-sharing binding did not fail Witchwork alone" % label)
	var without_heat: Array[Dictionary] = []
	for item in original_furniture:
		if String(item.get("shared_station_id", "")) != "compact_witch_hearth":
			without_heat.append(Dictionary(item).duplicate(true))
	plan.furniture = without_heat
	plan.compromises = original_compromises.duplicate(true)
	plan.compromises.erase(room)
	HouseFurnisher._audit_activity_groups(plan)
	for group in ["cooking", "witchwork"]:
		if not _shortfall_has(plan, "activity:%s:hearth" % group):
			failures.append("%s removing the one physical heat station did not fail %s" % [label, group])
	plan.furniture = original_furniture
	plan.compromises = original_compromises
	plan.domestic_layout = original_layout


func _heat_serves_station(heat_zone: Rect2, prep_zone: Rect2, max_distance: float) -> bool:
	return heat_zone.has_area() and prep_zone.has_area() \
		and HousePlanFeatures._rect_distance(heat_zone, prep_zone) <= max_distance


func _shortfall_has(plan: HousePlan, issue: String) -> bool:
	for row in plan.domestic_layout.get("activity_shortfalls", []):
		for value in row.get("issues", []):
			if String(value) == issue:
				return true
	return false


func _check_witch_pantry(plan: HousePlan, label: String) -> void:
	var stores := plan.rooms_of(&"store")
	if stores.size() != 1:
		return
	var halls := plan.rooms_of(&"hall")
	if halls.size() != 1:
		return
	var room: int = stores[0]
	var functions: Array = plan.rooms[room].get("domestic_functions", [])
	if not functions.has(&"storage") or not functions.has(&"dry_herbs"):
		failures.append("%s compact store does not claim storage and dry-herb functions" % label)
	if not _has_door_between(plan, halls[0], room):
		failures.append("%s dry pantry is not directly reached from the hall" % label)
	_check_min_count(plan, room, "witch_pantry", "barrel", 1, label)
	_check_min_count(plan, room, "witch_pantry", "storage", 1, label)
	var floor: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var container_count := 0
	var storage_count := 0
	for index in plan.furniture_of(room):
		var piece: Dictionary = plan.furniture[index]
		if String(piece.get("activity_group", "")) != "witch_pantry":
			continue
		var body: Rect2 = Rect2(piece.get("rect", Rect2()))
		var use: Rect2 = Rect2(piece.get("zone", Rect2()))
		if not body.has_area() or not floor.grow(0.01).encloses(body):
			failures.append("%s pantry %s lacks a measured body on its own floor" % [label, String(piece.get("key", ""))])
		if not use.has_area():
			failures.append("%s pantry %s has no usable access stance" % [label, String(piece.get("key", ""))])
		elif not floor.grow(0.01).encloses(use):
			failures.append("%s pantry %s use stance leaves its room" % [label, String(piece.get("key", ""))])
		if String(piece.get("cat", "")) == "barrel":
			container_count += 1
			if body.size.x * body.size.y < 0.20:
				failures.append("%s pantry barrel is not a full-size usable container" % label)
			if absf(use.size.y - 0.6) > 0.02 and absf(use.size.x - 0.6) > 0.02:
				failures.append("%s pantry barrel has no measured 0.6m access stance" % label)
		if String(piece.get("cat", "")) == "storage":
			storage_count += 1
			if PropCatalog.category(String(piece.get("key", ""))) != "storage":
				failures.append("%s pantry storage role is not a catalogue storage unit" % label)
	if container_count < 1 or storage_count < 1:
		failures.append("%s dry-pantry contract lacks a reachable container and measured storage unit" % label)


func _has_door_between(plan: HousePlan, a: int, b: int) -> bool:
	for door in plan.doors:
		if int(door.get("storey", 0)) != plan.storey_of_room(a):
			continue
		if (int(door.get("a", -1)) == a and int(door.get("b", -1)) == b) or (int(door.get("a", -1)) == b and int(door.get("b", -1)) == a):
			return true
	return false


func _check_missing_role_negatives(plan: HousePlan, room: int, label: String) -> void:
	var original_furniture: Array = plan.furniture.duplicate(true)
	var original_compromises: Dictionary = plan.compromises.duplicate(true)
	var original_layout: Dictionary = plan.domestic_layout.duplicate(true)
	for missing_group in ["cooking", "witchwork", "witch_pantry"]:
		plan.domestic_layout = original_layout.duplicate(true)
		var filtered: Array[Dictionary] = []
		var old_to_new: Dictionary = {}
		for old_index in range(original_furniture.size()):
			var piece: Dictionary = Dictionary(original_furniture[old_index]).duplicate(true)
			if String(piece.get("activity_group", "")) == missing_group:
				continue
			old_to_new[old_index] = filtered.size()
			filtered.append(piece)
		for piece in filtered:
			var old_host: int = int(piece.get("host", -1))
			if old_host >= 0:
				piece["host"] = int(old_to_new.get(old_host, -1))
		plan.furniture = filtered
		plan.compromises = original_compromises.duplicate(true)
		plan.compromises.erase(room)
		HouseFurnisher._audit_activity_groups(plan)
		var expected: String = "activity:" + missing_group
		var found := false
		for row in plan.domestic_layout.get("activity_shortfalls", []):
			for issue in row.get("issues", []):
				if String(issue) == expected or String(issue).begins_with(expected + ":"):
					found = true
		if String(plan.domestic_layout.get("activity_status", "")) != "unsatisfied" or not found:
			failures.append("%s removing every %s item did not produce an honest required-role shortfall: %s" % [label, missing_group, str(plan.domestic_layout.get("activity_shortfalls", []))])
	plan.furniture.clear()
	for piece in original_furniture:
		plan.furniture.append(Dictionary(piece).duplicate(true))
	plan.compromises = original_compromises
	plan.domestic_layout = original_layout


func _check_compact_book_support(plan: HousePlan, room: int, label: String) -> void:
	var books: Array[Dictionary] = []
	for index in plan.furniture_of(room):
		var item: Dictionary = plan.furniture[index]
		if String(item.get("activity_group", "")) == "witchwork" and String(item.get("cat", "")) == "books":
			books.append(item)
	if books.size() != 1:
		failures.append("%s shared-service Witchwork must have exactly one book" % label)
		return
	var book: Dictionary = books[0]
	if String(book.get("key", "")) != "Book_Stack_1":
		failures.append("%s compact shared-service Witchwork did not choose Book_Stack_1" % label)
	var host_index := int(book.get("host", -1))
	if host_index < 0 or host_index >= plan.furniture.size():
		failures.append("%s compact grimoire has no workbench support index" % label)
		return
	var host: Dictionary = plan.furniture[host_index]
	if String(host.get("cat", "")) != "workbench" or String(host.get("activity_group", "")) != "witchwork":
		failures.append("%s compact grimoire is not hosted by the Witchwork workbench" % label)
		return
	if not Rect2(host.get("rect", Rect2())).grow(-0.05).encloses(Rect2(book.get("rect", Rect2()))):
		failures.append("%s compact grimoire leaves the measured workbench top" % label)
	var host_key := String(host.get("key", ""))
	var host_scale := PropCatalog.placement_height_scale(host)
	var expected_top := PropCatalog.house_origin(host).y \
		+ PropCatalog.floor_offset(host_key) * host_scale \
		+ PropCatalog.surface_height(host_key) * host_scale
	var book_key := String(book.get("key", ""))
	var actual_bottom := (PropCatalog.house_origin(book).y
		+ PropCatalog.floor_offset(book_key) * PropCatalog.placement_height_scale(book))
	if absf(actual_bottom - expected_top) > 0.005:
		failures.append("%s compact grimoire does not contact the measured workbench surface" % label)


func _check_group_count(plan: HousePlan, room: int, group: String, category: String, expected: int, label: String) -> void:
	var count := _group_count(plan, room, group, category)
	if count != expected:
		failures.append("%s %s/%s count=%d expected=%d" % [label, group, category, count, expected])

func _check_min_count(plan: HousePlan, room: int, group: String, category: String, minimum: int, label: String) -> void:
	var count := _group_count(plan, room, group, category)
	if count < minimum:
		failures.append("%s %s/%s count=%d expected at least %d" % [label, group, category, count, minimum])

func _group_count(plan: HousePlan, room: int, group: String, category: String) -> int:
	var count := 0
	for index in plan.furniture_of(room):
		var piece: Dictionary = plan.furniture[index]
		var groups: Array = [String(piece.get("activity_group", ""))]
		groups.append_array(piece.get("shared_activity_groups", []))
		if groups.has(group) and String(piece.get("cat", "")) == category:
			count += 1
	return count

func _check_impossible_service_frontage() -> void:
	var spec := HouseSpec.new(1)
	spec.style = &"witch_hut"
	spec.trade = &"none"
	spec.width = 6.2
	spec.length = 9.0
	spec.height = 2.6
	spec.storeys = 1
	spec.cellars = 0
	spec.room_count = 3
	var plan := HousePlan.new()
	plan.spec = spec
	HousePlanRooms.subdivide(plan, spec)
	if String(plan.domestic_layout.get("status", "")) != "fallback" \
			or String(plan.domestic_layout.get("activity_status", "")) != "unsatisfied" \
			or not plan.domestic_layout.get("activity_shortfalls", []).has(&"witchwork"):
		failures.append("undersized measured frontage was accepted or did not expose Witchwork shortfall: %s" % str(plan.domestic_layout))
	if not String(plan.domestic_layout.get("reason", "")).contains("frontage"):
		failures.append("undersized service negative did not name the measured frontage constraint: %s" % str(plan.domestic_layout))
