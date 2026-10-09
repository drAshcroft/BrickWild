extends SceneTree
## Exact Witch workshop/hall finish and task-light checks. Visual acceptance stays pending.
const CUSTOM_SPEC := preload("res://tests/fixtures/witch_custom_house_spec.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for dims in [Vector2(7.0, 9.0), Vector2(9.0, 12.0), Vector2(17.0, 18.0)]:
		for seed in [1, 8102, 21325]:
			_check_witch(seed, dims)
	_check_scope_controls()
	if failures.is_empty():
		print("PASS: Witch selective finish and work-light contracts")
		quit(0)
		return
	for failure in failures:
		printerr(failure)
	quit(1)

func _plan(trade: StringName, seed: int, dims := Vector2(9.0, 12.0)) -> HousePlan:
	var spec := HouseSpec.new()
	spec.style = &"witch_hut"
	spec.trade = trade
	spec.width = dims.x
	spec.length = dims.y
	spec.height = 2.8 if dims.x >= 17.0 else 2.6
	spec.storeys = 1
	return HouseGenerator.generate(spec, seed, true)

func _activity_signature(plan: HousePlan) -> Array[String]:
	var result: Array[String] = []
	for item in plan.furniture:
		if String(item.get("activity_group", "")) not in ["cooking", "witchwork"] and not PropCatalog.has_tag(String(item.get("key", "")), PropCatalog.LIGHT):
			continue
		result.append("%s|%d|%s|%s|%s|%s|%s|%s" % [item.get("key", ""), int(item.get("room", -1)), item.get("pos", Vector3.ZERO), item.get("activity_anchor_id", ""), item.get("wall_host_id", ""), item.get("mount_relation", ""), item.get("surface_parent_id", ""), item.get("house_light_profile", {})])
	return result

func _check_witch(seed: int, dims: Vector2) -> void:
	var plan := _plan(&"none", seed, dims)
	if plan == null or plan.spec == null:
		failures.append("Witch seed %d did not generate" % seed)
		return
	var target_rooms: Array[int] = []
	for room_index in plan.room_count():
		if StringName(plan.kind_of(room_index)) in [&"workshop", &"hall"]:
			target_rooms.append(room_index)
	if target_rooms.is_empty():
		failures.append("Witch seed %d lacks workshop or shared hall" % seed)
		return
	if dims.x <= 7.01 and dims.y <= 9.01:
		_check_compact_shared_hall_host_groups(plan, seed)
	var signature := _activity_signature(plan)
	HousePlanFeatures.compose_wall_hosts(plan, plan.spec)
	if signature != _activity_signature(plan):
		failures.append("Witch seed %d recomposition changed fitting identity or work-light profile" % seed)
	var supported_work_lights := 0
	var anchored_supports := 0
	for item_variant in plan.furniture:
		var item: Dictionary = item_variant
		if not PropCatalog.has_tag(String(item.get("key", "")), PropCatalog.LIGHT):
			continue
		var room := int(item.get("room", -1))
		var is_work_activity := String(item.get("activity_group", "")) in ["cooking", "witchwork"] \
				and room in target_rooms
		var activity_profile: Dictionary = item.get("house_light_profile", {})
		if is_work_activity:
			supported_work_lights += 1
			if String(activity_profile.get("name", "")) != "witchwork" \
					or absf(float(activity_profile.get("energy_scale", 1.0)) - 0.76) > 0.001 \
					or absf(float(activity_profile.get("range_scale", 1.0)) - 0.84) > 0.001:
				failures.append("Witch seed %d activity light lacks intended profile" % seed)
		elif String(activity_profile.get("name", "")) == "witchwork":
			failures.append("Witch seed %d work-light profile escaped its activity room" % seed)
	for support_variant in plan.furniture:
		var support_item: Dictionary = support_variant
		if String(support_item.get("activity_group", "")) not in ["cooking", "witchwork"] or String(support_item.get("mount_relation", "")) != "supports_activity":
			continue
		anchored_supports += 1
		var support_room := int(support_item.get("room", -1))
		var support_host_id := String(support_item.get("wall_host_id", ""))
		var support_host_found := false
		for host_variant in plan.wall_hosts:
			var support_host: Dictionary = host_variant
			if String(support_host.get("id", "")) == support_host_id and int(support_host.get("room", -1)) == support_room and String(support_host.get("role", "")) == "activity_support":
				support_host_found = true
		if not support_host_found:
			failures.append("Witch seed %d activity shelf is detached from its wall host" % seed)

	if supported_work_lights == 0:
		failures.append("Witch seed %d has no activity light in workshop/shared hall" % seed)
	if anchored_supports == 0:
		failures.append("Witch seed %d %s has no measured activity-support fitting retained after recomposition" % [seed, dims])
	if dims.x >= 17.0 and seed == 21325:
		_check_large_workshop_rack(plan)

	var finish_host_ids: Dictionary = {}
	for host_variant in plan.wall_hosts:
		var finish_host: Dictionary = host_variant
		if String(finish_host.get("role", "")) != "room_finish":
			continue
		var finish_id := String(finish_host.get("id", ""))
		if finish_id == "" or finish_host_ids.has(finish_id):
			failures.append("Witch seed %d has a missing or reused room-finish host ID" % seed)
		finish_host_ids[finish_id] = true
	var builder := HouseBuilder.new()
	var mesh := builder.build(plan, false)
	var component_check := ComponentCheck.check(builder, mesh)
	if not bool(component_check.get("ok", false)):
		failures.append("Witch seed %d component rows differ from emitted mesh: %s" % [seed, component_check.get("failures", [])])
	var panels := 0
	for row in builder.component_log:
		if String(row.get("role", "")) != "witch_service_wainscot":
			continue
		panels += 1
		var host_id := String(row.get("host", ""))
		if not host_id.begins_with("witch_finish_"):
			failures.append("Witch seed %d wainscot lacks actual room-wall host" % seed)
		var parts := host_id.split("_")
		if parts.size() < 4:
			failures.append("Witch seed %d malformed finish host %s" % [seed, host_id])
			continue
		var finish_room := int(parts[2])
		var wi := int(parts[3])
		if finish_room < 0 or finish_room >= plan.room_count() or wi < 0 or wi >= HouseGeometry.room_walls(plan, finish_room).size():
			failures.append("Witch seed %d finish references missing wall %s" % [seed, host_id])
			continue
		var kind := StringName(plan.kind_of(finish_room))
		if kind not in [&"workshop", &"hall"]:
			failures.append("Witch seed %d finish landed outside workshop/shared hall" % seed)
		var wall: Dictionary = HouseGeometry.room_walls(plan, finish_room)[wi]
		var normal: Vector2 = wall["normal"]
		var transform: Transform3D = row["xf"]
		var centre2 := Vector2(transform.origin.x, transform.origin.z)
		if absf((centre2 - Vector2(wall["from"])).dot(normal) - 0.0185) > 0.01:
			failures.append("Witch seed %d finish panel misses actual wall face" % seed)
		var size: Vector3 = row["size"]
		if int(row.get("surface", -1)) != HouseBuilder.SURF_TRIM or absf(size.y - 0.90) > 0.002:
			failures.append("Witch seed %d finish has wrong trim surface or height" % seed)
		var axis := Vector2.RIGHT if absf(normal.y) > 0.5 else Vector2(0, 1)
		var centre_along := centre2.dot(axis)
		var half_run := size.x * 0.5
		var valid_span := false
		for clear_span in HousePlanFeatures.clear_wall_spans(plan, finish_room, wi, 0.07):
			if centre_along - half_run >= clear_span.x - 0.001 and centre_along + half_run <= clear_span.y + 0.001:
				valid_span = true
		if not valid_span:
			failures.append("Witch seed %d finish crosses an opening or leaves its clear wall span" % seed)
		var finish_host_found := false
		for host_variant in plan.wall_hosts:
			var finish_host: Dictionary = host_variant
			if String(finish_host.get("id", "")) == host_id and int(finish_host.get("room", -1)) == finish_room \
					and int(finish_host.get("wall", -1)) == wi \
					and String(finish_host.get("role", "")) == "room_finish" \
					and String(finish_host.get("finish_intent", "")) == "cleanable_working_room" \
					and String(finish_host.get("room_kind", "")) == String(kind):
				var host_span: Vector2 = finish_host.get("span", Vector2.ZERO)
				var host_from: Vector2 = finish_host.get("from", Vector2.ZERO)
				var host_to: Vector2 = finish_host.get("to", Vector2.ZERO)
				var expected_from := Vector2(host_span.x, wall["from"].y) if absf(normal.y) > 0.5 else Vector2(wall["from"].x, host_span.x)
				var expected_to := Vector2(host_span.y, wall["from"].y) if absf(normal.y) > 0.5 else Vector2(wall["from"].x, host_span.y)
				var host_matches_wall := host_from.is_equal_approx(expected_from) and host_to.is_equal_approx(expected_to) \
						and Vector2(finish_host.get("normal", Vector2.ZERO)).is_equal_approx(normal) \
						and int(finish_host.get("storey", -1)) == plan.storey_of_room(finish_room)
				if host_matches_wall and centre_along - half_run >= host_span.x - 0.001 \
						and centre_along + half_run <= host_span.y + 0.001:
					finish_host_found = true
		if not finish_host_found:
			failures.append("Witch seed %d finish lacks matching semantic room-wall intent" % seed)
		if kind == &"hall":
			var room_row: Dictionary = plan.rooms[finish_room]
			var functions: Array = room_row.get("domestic_functions", [])
			if not bool(room_row.get("shared_witchwork", false)) or not bool(room_row.get("shared_cooking", false)) \
					 or not functions.has(&"cooking") or not functions.has(&"witchwork"):
				failures.append("Witch seed %d shared-hall finish lacks shared working-room intent" % seed)
		var bounds: AABB = MassBuilder.component_aabb(row)
		var body_rect := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
		var room_rect: Rect2 = plan.rooms[finish_room]["rect"]
		if not room_rect.grow(0.01).encloses(body_rect):
			failures.append("Witch seed %d %s finish body leaves its physical room bounds" % [seed, dims])
		for zone_variant in plan.zones:
			var use_zone: Dictionary = zone_variant
			if int(use_zone.get("room", -1)) == finish_room and Rect2(use_zone.get("rect", Rect2())).intersects(body_rect.grow(0.01)):
				failures.append("Witch seed %d finish intrudes an actual floor/use clearance zone" % seed)
				break
		for furniture_variant in plan.furniture:
			var furniture: Dictionary = furniture_variant
			if int(furniture.get("room", -1)) != finish_room:
				continue
			var furniture_zone: Rect2 = furniture.get("zone", Rect2())
			var furniture_key := String(furniture.get("key", ""))
			var furniture_origin := PropCatalog.house_origin(furniture)
			var furniture_yaw := float(furniture.get("yaw", 0.0)) + PropCatalog.face_offset(furniture_key)
			var furniture_scale := float(furniture.get("scale", 1.0))
			var furniture_centre := PropCatalog.plan_centre(furniture_key, furniture_origin, furniture_yaw, furniture_scale)
			var furniture_size := PropCatalog.footprint_rotated(furniture_key, furniture_yaw) * furniture_scale
			var furniture_body := Rect2(furniture_centre - furniture_size * 0.5, furniture_size)
			var furniture_bottom := furniture_origin.y + PropCatalog.floor_offset(furniture_key) * PropCatalog.placement_height_scale(furniture)
			var furniture_top := furniture_bottom + PropCatalog.placement_height(furniture)
			var vertical_collision := furniture_bottom < bounds.end.y and furniture_top > bounds.position.y
			if (furniture_zone.has_area() and furniture_zone.grow(0.025).intersects(body_rect)) \
					or (vertical_collision and furniture_body.intersects(body_rect)):
				failures.append("Witch seed %d finish intrudes measured furniture/use footprint" % seed)
				break
		var floor_y := float(plan.storey_of_room(finish_room)) * plan.spec.height + HouseGeometry.FLOOR_T
		if bounds.position.y < floor_y - 0.002 or bounds.end.y > float(plan.storey_of_room(finish_room) + 1) * plan.spec.height + 0.002:
			failures.append("Witch seed %d finish violates room floor/head clearance" % seed)
	if panels == 0:
		failures.append("Witch seed %d %s generated no safely placed Witch finish panels" % [seed, dims])

	var root := Node3D.new()
	root.name = "WitchProfileFixture"
	get_root().add_child(root)
	HouseAssembler.furnish(root, plan)
	var lights: Node3D = root.get_node("Lights")
	var light_index := 0
	for item_variant in plan.furniture:
		var item: Dictionary = item_variant
		var key := String(item.get("key", ""))
		if not PropCatalog.has_tag(key, PropCatalog.LIGHT):
			continue
		var lamp_profile: Dictionary = item.get("house_light_profile", {})
		if String(lamp_profile.get("name", "")) == "witchwork":
			var lamp := lights.get_child(light_index) as OmniLight3D
			var category: Dictionary = LightKit.TABLE.get(PropCatalog.category(key), LightKit.DEFAULT)
			if lamp == null or absf(lamp.light_energy - float(category["energy"]) * 0.76) > 0.002 \
					or absf(lamp.omni_range - float(category["reach"]) * 0.84) > 0.002 \
					or String(lamp.get_meta("house_light_profile", "")) != "witchwork":
				failures.append("Witch seed %d profile did not affect its actual OmniLight" % seed)
		light_index += 1
	if light_index != lights.get_child_count():
		failures.append("Witch seed %d LightKit mapping is not one-to-one" % seed)
	root.queue_free()
	mesh.clear_surfaces()



func _check_compact_shared_hall_host_groups(plan: HousePlan, seed: int) -> void:
	var halls := plan.rooms_of(&"hall")
	if halls.is_empty():
		failures.append("Witch seed %d 7x9 has no shared hall for ownership regression" % seed)
		return
	_check_shared_hall_host_groups(plan, halls[0], "Witch seed %d 7x9" % seed)


func _check_shared_hall_host_groups(plan: HousePlan, hall: int, who: String) -> void:
	var cooking_pots: Array[int] = []
	var surface_items: Array[int] = []
	var witch_bench_index := -1
	for index in plan.furniture_of(hall):
		var item: Dictionary = plan.furniture[index]
		if String(item.get("key", "")) == "Pot_1" and String(item.get("activity_group", "")) == "cooking":
			cooking_pots.append(index)
		if String(item.get("activity_group", "")) == "witchwork" and String(item.get("cat", "")) in ["alchemy", "books"]:
			surface_items.append(index)
		if String(item.get("cat", "")) == "shelf" and not surface_items.has(index):
			surface_items.append(index)
		if String(item.get("activity_group", "")) == "witchwork" and String(item.get("cat", "")) == "workbench":
			witch_bench_index = index
	if cooking_pots.is_empty():
		failures.append("%s shared hall has no cooking Pot_1 for host ownership check" % who)
		return
	for pot_index in cooking_pots:
		var pot: Dictionary = plan.furniture[pot_index]
		var host_index := int(pot.get("host", -1))
		if host_index < 0 or host_index >= plan.furniture.size():
			failures.append("%s cooking pot has no valid surface host" % who)
			continue
		var host: Dictionary = plan.furniture[host_index]
		if String(host.get("cat", "")) != "workbench" or String(host.get("activity_group", "")) != "cooking":
			failures.append("%s cooking pot is hosted by a non-cooking workbench" % who)
		# The pre-fix failure was a real 3D intersection between this pot and a
		# Witchwork wall shelf. Check their measured body rectangles and heights.
		for witch_index in surface_items:
			var witch_item: Dictionary = plan.furniture[witch_index]
			if String(witch_item.get("cat", "")) in ["alchemy", "books"]:
				var witch_host_index := int(witch_item.get("host", -1))
				if witch_host_index < 0 or witch_host_index >= plan.furniture.size():
					failures.append("%s Witchwork surface item has no valid host" % who)
				else:
					var witch_host: Dictionary = plan.furniture[witch_host_index]
					if String(witch_host.get("cat", "")) != "workbench" or String(witch_host.get("activity_group", "")) != "witchwork":
						failures.append("%s Witchwork surface item is hosted by a non-Witchwork bench" % who)
			var pot_body: Rect2 = Rect2(pot.get("rect", Rect2()))
			var witch_body: Rect2 = Rect2(witch_item.get("rect", Rect2()))
			if not pot_body.intersects(witch_body):
				continue
			var pot_bottom := PropCatalog.house_origin(pot).y + PropCatalog.floor_offset(String(pot.get("key", ""))) * PropCatalog.placement_height_scale(pot)
			var witch_bottom := PropCatalog.house_origin(witch_item).y + PropCatalog.floor_offset(String(witch_item.get("key", ""))) * PropCatalog.placement_height_scale(witch_item)
			var pot_top := pot_bottom + PropCatalog.placement_height(pot)
			var witch_top := witch_bottom + PropCatalog.placement_height(witch_item)
			if minf(pot_top, witch_top) - maxf(pot_bottom, witch_bottom) > 0.015:
				failures.append("%s cooking pot overlaps Witchwork surface furniture in measured 3D bounds" % who)
	if witch_bench_index < 0:
		failures.append("%s shared hall has no Witchwork bench for the rack clearance check" % who)
	else:
		for shelf_index in surface_items:
			var shelf: Dictionary = plan.furniture[shelf_index]
			if String(shelf.get("cat", "")) != "shelf":
				continue
			var shelf_body: Rect2 = Rect2(shelf.get("rect", Rect2()))
			var shelf_bottom := PropCatalog.house_origin(shelf).y + PropCatalog.floor_offset(String(shelf.get("key", ""))) * PropCatalog.placement_height_scale(shelf)
			var shelf_top := shelf_bottom + PropCatalog.placement_height(shelf)
			for other_index in plan.furniture_of(hall):
				if other_index == shelf_index:
					continue
				var other: Dictionary = plan.furniture[other_index]
				if other_index != witch_bench_index and int(other.get("host", -1)) != witch_bench_index:
					continue
				if not shelf_body.intersects(Rect2(other.get("rect", Rect2()))):
					continue
				var other_bottom := PropCatalog.house_origin(other).y + PropCatalog.floor_offset(String(other.get("key", ""))) * PropCatalog.placement_height_scale(other)
				var other_top := other_bottom + PropCatalog.placement_height(other)
				if minf(shelf_top, other_top) - maxf(shelf_bottom, other_bottom) > 0.015:
					failures.append("%s Witchwork rack intersects its bench or hosted potion in measured 3D bounds" % who)

func _check_large_workshop_rack(plan: HousePlan) -> void:
	var workshop := -1
	for room in plan.room_count():
		if plan.kind_of(room) == &"workshop":
			workshop = room
			break
	if workshop < 0:
		failures.append("large seed 21325 has no workshop for the ingredient-rack contract")
		return
	var bench: Dictionary = {}
	var bench_index := -1
	var rack: Dictionary = {}
	var rack_index := -1
	for index in plan.furniture_of(workshop):
		var item: Dictionary = plan.furniture[index]
		if String(item.get("cat", "")) == "workbench" and String(item.get("activity_group", "")) == "witchwork":
			bench = item
			bench_index = index
		if String(item.get("key", "")) == "Shelf_Small_Bottles" and String(item.get("activity_group", "")) == "witchwork":
			if String(item.get("mount_relation", "")) == "supports_activity":
				rack = item
				rack_index = index
	if bench.is_empty() or rack.is_empty():
		failures.append("large seed 21325 lacks a bound ingredient rack at its actual Witchwork bench")
		return
	if String(rack.get("activity_anchor_id", "")) == "" or String(rack.get("wall_host_id", "")) == "":
		failures.append("large seed 21325 rack has no derived activity and wall-host binding")
	if not bool(rack.get("mounted", false)):
		failures.append("large seed 21325 Witchwork rack is not mounted")
	var bench_zone := Rect2(bench.get("zone", Rect2()))
	var rack_body := Rect2(rack.get("rect", Rect2()))
	var dx := maxf(maxf(rack_body.position.x - bench_zone.end.x, bench_zone.position.x - rack_body.end.x), 0.0)
	var dz := maxf(maxf(rack_body.position.y - bench_zone.end.y, bench_zone.position.y - rack_body.end.y), 0.0)
	if Vector2(dx, dz).length() > 1.9:
		failures.append("large seed 21325 ingredient rack is not within measured workbench reach")
	var rack_vertical := _measured_body_vertical_span(rack)
	for index in plan.furniture_of(workshop):
		if index == rack_index:
			continue
		var item: Dictionary = plan.furniture[index]
		if index != bench_index and int(item.get("host", -1)) != bench_index:
			continue
		if not rack_body.intersects(Rect2(item.get("rect", Rect2()))):
			continue
		var other_vertical := _measured_body_vertical_span(item)
		if minf(rack_vertical.y, other_vertical.y) - maxf(rack_vertical.x, other_vertical.x) > 0.015:
			failures.append("large seed 21325 ingredient rack intersects its bench or a potion in measured 3D bounds")

func _measured_body_vertical_span(item: Dictionary) -> Vector2:
	var key := String(item.get("key", ""))
	var origin := PropCatalog.house_origin(item)
	var bottom := origin.y + PropCatalog.floor_offset(key) * PropCatalog.placement_height_scale(item)
	return Vector2(bottom, bottom + PropCatalog.placement_height(item))

func _check_scope_controls() -> void:
	var trade_plan := _plan(&"alchemist", 8102)
	if trade_plan != null:
		HousePlanFeatures.compose_wall_hosts(trade_plan, trade_plan.spec)
		for item in trade_plan.furniture:
			var trade_profile: Dictionary = item.get("house_light_profile", {})
			if String(trade_profile.get("name", "")) == "witchwork":
				failures.append("Witch/alchemist trade entered no-trade work-light profile")
		_assert_no_wainscot(trade_plan, "Witch/alchemist")
	var custom_plan := _plan(&"none", 8102)
	if custom_plan != null:
		var custom := CUSTOM_SPEC.new() as HouseSpec
		custom.style = &"witch_hut"
		custom.trade = &"none"
		custom.width = 9.0
		custom.length = 12.0
		custom.height = 2.6
		custom.storeys = 1
		_clear_derived_witch_finish_hosts(custom_plan)
		custom_plan.spec = custom
		for item in custom_plan.furniture:
			item.erase("house_light_profile")
		HousePlanFeatures.compose_wall_hosts(custom_plan, custom)
		for item in custom_plan.furniture:
			var custom_profile: Dictionary = item.get("house_light_profile", {})
			if String(custom_profile.get("name", "")) == "witchwork":
				failures.append("custom HouseSpec entered built-in Witch work-light profile")
		_assert_no_wainscot(custom_plan, "custom WitchSpec")
	var family_plan := _plan(&"none", 8102)
	if family_plan != null:
		_clear_derived_witch_finish_hosts(family_plan)
		family_plan.world_family = &"vastu"
		for item in family_plan.furniture:
			item.erase("house_light_profile")
		HousePlanFeatures.compose_wall_hosts(family_plan, family_plan.spec)
		for item in family_plan.furniture:
			var family_profile: Dictionary = item.get("house_light_profile", {})
			if String(family_profile.get("name", "")) == "witchwork":
				failures.append("world-family plan entered built-in Witch work-light profile")
		_assert_no_wainscot(family_plan, "world-family Witch")


	_check_plain_hall_control()


func _check_plain_hall_control() -> void:
	var plan := _plan(&"none", 8102, Vector2(7.0, 9.0))
	if plan == null:
		return
	var hall := -1
	for room in plan.room_count():
		if plan.kind_of(room) == &"hall":
			hall = room
			break
	if hall < 0:
		return
	# Remove only this fixture's already-composed finish rows. This models a
	# plain hall and leaves the production scope guard free to preserve caller rows.
	_clear_derived_witch_finish_hosts(plan)
	var room_row: Dictionary = plan.rooms[hall]
	room_row["shared_witchwork"] = false
	room_row["shared_cooking"] = false
	var functions: Array = room_row.get("domestic_functions", []).duplicate()
	functions.erase(&"cooking")
	functions.erase(&"witchwork")
	room_row["domestic_functions"] = functions
	plan.rooms[hall] = room_row
	HousePlanFeatures.compose_wall_hosts(plan, plan.spec)
	for host_variant in plan.wall_hosts:
		var host: Dictionary = host_variant
		if int(host.get("room", -1)) == hall and String(host.get("role", "")) == "room_finish":
			failures.append("plain hall acquired Witch cleanable-room finish intent")
	var builder := HouseBuilder.new()
	var mesh := builder.build(plan, false)
	for row_variant in builder.component_log:
		var row: Dictionary = row_variant
		if String(row.get("role", "")) == "witch_service_wainscot" \
				and String(row.get("host", "")).begins_with("witch_finish_%d_" % hall):
			failures.append("plain hall emitted Witch cleanable-room finish")
	mesh.clear_surfaces()


func _clear_derived_witch_finish_hosts(plan: HousePlan) -> void:
	for index in range(plan.wall_hosts.size() - 1, -1, -1):
		var host: Dictionary = plan.wall_hosts[index]
		if String(host.get("role", "")) == "room_finish" \
				and String(host.get("finish_intent", "")) == "cleanable_working_room":
			plan.wall_hosts.remove_at(index)


func _assert_no_wainscot(plan: HousePlan, label: String) -> void:
	for host_variant in plan.wall_hosts:
		var finish_host: Dictionary = host_variant
		if String(finish_host.get("role", "")) == "room_finish" \
				and String(finish_host.get("finish_intent", "")) == "cleanable_working_room":
			failures.append("%s control composed Witch room-finish host" % label)
	var builder := HouseBuilder.new()
	var mesh := builder.build(plan, false)
	for row in builder.component_log:
		if String(row.get("role", "")) == "witch_service_wainscot":
			failures.append("%s control emitted Witch wainscot" % label)
	mesh.clear_surfaces()
