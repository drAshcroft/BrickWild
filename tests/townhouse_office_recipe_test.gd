extends SceneTree
## LIVE-TOWNHOUSE-OFFICE: exact public seed 8102 office furnishing contract.
## Run: godot --headless --path . --script res://tests/townhouse_office_recipe_test.gd

const CASES: Array[Dictionary] = [
	{"name": "small", "width": 7.0, "length": 9.0, "height": 2.4, "office": false},
	{"name": "default", "width": 9.0, "length": 12.0, "height": 2.6, "office": true},
	{"name": "large", "width": 14.5, "length": 19.0, "height": 3.1, "storeys": 2, "office": true},
]

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_controls()
	for row in CASES:
		_check_case(row)
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: townhouse seed 8102 office recipe, measured desk group, supported writing props, records and navigation")
	quit(1 if not failures.is_empty() else 0)


func _check_case(row: Dictionary) -> void:
	var spec := HouseSpec.new()
	spec.style = &"townhouse"
	spec.width = float(row["width"])
	spec.length = float(row["length"])
	spec.height = float(row["height"])
	spec.storeys = int(row.get("storeys", 1))
	var plan: HousePlan = HouseGenerator.generate(spec, 8102, true)
	var who := "townhouse_%s_8102" % row["name"]
	var office := -1
	for room in range(plan.room_count()):
		if plan.kind_of(room) == &"office":
			office = room
	if not bool(row["office"]):
		if office >= 0:
			failures.append("%s invented an office" % who)
		return
	if office < 0:
		failures.append("%s is missing its office" % who)
		return
	var by_key: Dictionary = {}
	for index in plan.furniture_of(office):
		var piece: Dictionary = plan.furniture[index]
		by_key[String(piece.get("key", ""))] = index
	for key in ["Workbench", "Chair_1", "Book_5", "Scroll_1", "Bookcase_2"]:
		if not by_key.has(key):
			failures.append("%s missing measured office item %s" % [who, key])
	if not by_key.has("Workbench") or not by_key.has("Chair_1") \
			or not by_key.has("Book_5") or not by_key.has("Scroll_1") or not by_key.has("Bookcase_2"):
		return
	var table: Dictionary = plan.furniture[int(by_key["Workbench"])]
	var chair: Dictionary = plan.furniture[int(by_key["Chair_1"])]
	var book: Dictionary = plan.furniture[int(by_key["Book_5"])]
	var scroll: Dictionary = plan.furniture[int(by_key["Scroll_1"])]
	var bookcase: Dictionary = plan.furniture[int(by_key["Bookcase_2"])]
	var book_groups: Array[Dictionary] = []
	for index in plan.furniture_of(office):
		var piece: Dictionary = plan.furniture[index]
		if String(piece.get("key", "")) == "BookGroup_Small_1":
			book_groups.append(piece)
	if book_groups.size() != 3:
		failures.append("%s has %d plan-owned shelf groups; expected three" % [who, book_groups.size()])
	else:
		_check_bookcase_groups(plan, office, int(by_key["Bookcase_2"]), book_groups, who)
	if not _missing_office_activity(plan, office).is_empty():
		failures.append("%s has incomplete mandatory writing activity: %s" % [who,
			str(_missing_office_activity(plan, office))])
	var table_surface := PropCatalog.placement_height(table)
	if table_surface < 0.72 or table_surface > 0.79:
		failures.append("%s writing surface is %.3fm; expected seated writing height" % [who, table_surface])
	var table_pos: Vector3 = table.get("pos", Vector3.ZERO)
	var chair_pos: Vector3 = chair.get("pos", Vector3.ZERO)
	var chair_to_table := Vector2(table_pos.x - chair_pos.x, table_pos.z - chair_pos.z)
	var table_rect: Rect2 = table.get("rect", Rect2())
	var chair_rect: Rect2 = chair.get("rect", Rect2())
	var edge_gap := _rect_gap(table_rect, chair_rect)
	if edge_gap > 0.10:
		failures.append("%s Chair_1 is %.3fm from the writing surface edge" % [who, edge_gap])
	if chair_to_table.length() > 0.001:
		var chair_facing := HouseFurnishScore._facing_of(float(chair.get("yaw", 0.0)))
		if chair_facing.normalized().dot(chair_to_table.normalized()) < 0.5:
			failures.append("%s Chair_1 does not face the writing edge" % who)
		var long_axis_is_x := table_rect.size.x >= table_rect.size.y
		var across_desk: float = absf(chair_to_table.y) if long_axis_is_x else absf(chair_to_table.x)
		var along_desk: float = absf(chair_to_table.x) if long_axis_is_x else absf(chair_to_table.y)
		if across_desk <= along_desk:
			failures.append("%s Chair_1 is at the desk end: table_rect=%s chair_rect=%s centers=%s/%s" % [
				who, str(table_rect), str(chair_rect), str(table_pos), str(chair_pos)])
	var bookcase_pos: Vector3 = bookcase.get("pos", Vector3.ZERO)
	var room_direction := Vector2(table_pos.x - bookcase_pos.x,
		table_pos.z - bookcase_pos.z).normalized()
	var semantic_bookcase_yaw := float(bookcase.get("yaw", 0.0))
	var face_offset := PropCatalog.face_offset("Bookcase_2")
	# GLTF's shelving front is local +Z, opposite the catalogue's default
	# semantic front convention (-Z), so negate the semantic vector to measure
	# the visible shelf opening itself.
	var shelf_facing := -HouseFurnishScore._facing_of(semantic_bookcase_yaw + face_offset)
	var previous_facing := -HouseFurnishScore._facing_of(semantic_bookcase_yaw)
	if not is_equal_approx(absf(face_offset), PI) \
			or shelf_facing.dot(room_direction) < 0.5:
		failures.append("%s Bookcase_2 measured shelves do not face the writing station: offset=%.3f facing=%s room=%s" % [
			who, face_offset, str(shelf_facing), str(room_direction)])
	if previous_facing.dot(room_direction) > -0.5:
		failures.append("%s Bookcase_2 previous zero-offset pose is not a valid backward-facing negative control" % who)
	for item in [book, scroll]:
		var item_key := String(item.get("key", ""))
		if int(item.get("host", -1)) != int(by_key["Workbench"]):
			failures.append("%s %s is not supported by its writing surface" % [who, item_key])
		var item_rect: Rect2 = item.get("rect", Rect2())
		var table_top: float = float(table.get("pos", Vector3.ZERO).y) \
			+ PropCatalog.surface_height("Workbench") * PropCatalog.placement_height_scale(table)
		if absf(float(item.get("pos", Vector3.ZERO).y) - table_top) > 0.002:
			failures.append("%s %s sits %.3fm off the measured Workbench top" % [who, item_key,
				float(item.get("pos", Vector3.ZERO).y) - table_top])
		var item_scale := float(item.get("scale", 1.0))
		var measured_footprint: Vector2 = PropCatalog.footprint(item_key) * item_scale
		if not item_rect.size.is_equal_approx(measured_footprint):
			failures.append("%s %s footprint differs from its measured model: stored=%s measured=%s" % [
				who, item_key, str(item_rect.size), str(measured_footprint)])
		var item_pos: Vector3 = item.get("pos", Vector3.ZERO)
		if not item_rect.get_center().is_equal_approx(Vector2(item_pos.x, item_pos.z)):
			failures.append("%s %s footprint is not centered on its measured position" % [who, item_key])
		var rotated_footprint: Vector2 = PropCatalog.footprint_rotated(item_key,
			float(item.get("yaw", 0.0)) + PropCatalog.face_offset(item_key)) * item_scale
		var physical_rect := Rect2(item_rect.get_center() - rotated_footprint * 0.5,
			rotated_footprint)
		if not table_rect.grow(-0.06).encloses(physical_rect):
			failures.append("%s %s measured footprint does not fit on Workbench: item=%s table=%s" % [
				who, item_key, str(physical_rect), str(table_rect)])
		if String(item.get("activity_group", "")) != "writing":
			failures.append("%s %s is absent from the writing activity" % [who, item_key])
	if String(chair.get("activity_group", "")) != "writing" \
			or String(book.get("activity_group", "")) != "writing" \
			or String(scroll.get("activity_group", "")) != "writing" \
			or book_groups.size() != 3:
		failures.append("%s chair or writing prop is absent from the writing activity" % who)
	var table_zone: Rect2 = table.get("zone", Rect2())
	var chair_zone: Rect2 = chair.get("zone", Rect2())
	if not table_zone.has_area() or not chair_zone.has_area():
		failures.append("%s Workbench/Chair_1 lacks a measured use zone: desk=%s chair=%s" % [
			who, str(table_zone), str(chair_zone)])
	var nav_check := HouseNavCheck.new()
	var nav: Dictionary = nav_check.check(plan)
	var nav_stats: Dictionary = nav.get("stats", {})
	var expected_use_zones := 0
	for index in plan.furniture.size():
		var piece: Dictionary = plan.furniture[index]
		if PropCatalog.blocks_floor(String(piece.get("key", ""))) \
				and Rect2(piece.get("zone", Rect2())).has_area():
			expected_use_zones += 1
	if int(nav_stats.get("use_zones", -1)) != expected_use_zones:
		failures.append("%s NavCheck counted %d use zones; expected all %d floor props" % [
			who, int(nav_stats.get("use_zones", -1)), expected_use_zones])
	if int(nav_stats.get("use_zones_reached", -1)) != expected_use_zones:
		failures.append("%s NavCheck reached %d/%d use zones (Workbench=%s Chair_1=%s); failures=%s" % [
			who, int(nav_stats.get("use_zones_reached", -1)), expected_use_zones,
			str(table_zone), str(chair_zone), str(nav.get("failures", []))])
	if int(by_key["Workbench"]) in nav_check.unreachable_items \
			or int(by_key["Chair_1"]) in nav_check.unreachable_items:
		failures.append("%s Workbench or Chair_1 use zone is unreachable: %s" % [
			who, str(nav_check.unreachable_items)])
	if not bool(nav.get("ok", false)):
		failures.append("%s navigation: %s" % [who, str(nav.get("failures", []))])
	_check_measured_chair_blocker(plan, int(by_key["Chair_1"]),
		int(by_key["Bookcase_2"]), who)
	# Prove that omitting the drawn-up seat is visible to the activity audit.
	var retained: Array[Dictionary] = []
	for piece in plan.furniture:
		if int(piece.get("room", -1)) == office and String(piece.get("key", "")) == "Chair_1":
			continue
		retained.append(piece)
	plan.furniture = retained
	if not _missing_office_activity(plan, office).has("writing/seat"):
		failures.append("%s missing-seat negative escaped the writing activity audit" % who)


func _check_controls() -> void:
	_check_legacy_around_control()
	var trade := HouseSpec.new()
	trade.style = &"townhouse"
	trade.trade = &"merchant"
	_check_no_writing_overlay(trade, &"", "trade")
	var world := HouseSpec.new()
	world.style = &"townhouse"
	_check_no_writing_overlay(world, &"town_village", "world")
	var custom_family := ShopSpec.new()
	custom_family.style = &"townhouse"
	_check_no_writing_overlay(custom_family, &"", "custom family")
	var cottage := HouseSpec.new()
	cottage.style = &"cottage"
	_check_no_writing_overlay(cottage, &"", "Cottage")


func _check_bookcase_groups(plan: HousePlan, room: int, host_index: int,
		groups: Array[Dictionary], who: String) -> void:
	var host: Dictionary = plan.furniture[host_index]
	var board_triangles := _bookcase_triangles()
	if board_triangles.is_empty():
		failures.append("%s could not inspect Bookcase_2's real mesh shelf boards" % who)
	var host_origin := PropCatalog.house_origin(host)
	var host_scale := float(host.get("scale", 1.0))
	var model_yaw := float(host.get("yaw", 0.0)) + PropCatalog.face_offset("Bookcase_2")
	var expected_levels: Array[float] = [1.151, 1.535, 1.919]
	var seen: Array[float] = []
	for group in groups:
		var level := float(group.get("support_level_local_y", -1.0))
		if not expected_levels.has(level) or seen.has(level):
			failures.append("%s shelf group has duplicate or unmeasured board level %.3f" % [who, level])
		seen.append(level)
		if int(group.get("host", -1)) != host_index \
				or HousePlan.record_storey(group) != HousePlan.record_storey(host) \
				or String(group.get("activity_group", "")) != "writing" \
				or String(group.get("support_board", "")) != "Bookcase_2:shelf_%d" % (seen.size()) :
			failures.append("%s shelf group is not plan-owned by its measured Bookcase_2 board" % who)
		var piece_key := String(group.get("key", ""))
		var piece_scale := float(group.get("scale", 1.0))
		var foot := PropCatalog.footprint_rotated(piece_key,
			float(group.get("yaw", 0.0)) + PropCatalog.face_offset(piece_key)) * piece_scale
		var rect: Rect2 = group.get("rect", Rect2())
		if not rect.size.is_equal_approx(foot):
			failures.append("%s shelf group footprint is not its measured yawed body" % who)
		var foot_local := PropCatalog.footprint_rotated(piece_key,
			float(group.get("yaw", 0.0)) + PropCatalog.face_offset(piece_key) - model_yaw) * piece_scale
		var local_center_world := PropCatalog.plan_centre(piece_key,
			Vector3(group.get("pos", Vector3.ZERO)),
			float(group.get("yaw", 0.0)) + PropCatalog.face_offset(piece_key), piece_scale)
		var local_center_3d := Basis(Vector3.UP, model_yaw).inverse() * Vector3(
			local_center_world.x - host_origin.x, 0.0, local_center_world.y - host_origin.z)
		if foot_local.x > 1.186 * host_scale - 0.025 or foot_local.y > 0.247 * host_scale - 0.012 \
				or absf(local_center_3d.x) + foot_local.x * 0.5 > 0.593 * host_scale \
				or absf(local_center_3d.z - 0.0295 * host_scale) + foot_local.y * 0.5 > 0.1235 * host_scale:
			failures.append("%s measured BookGroup_Small_1 does not fit measured shelf board %.3f" % [who, level])
		var origin := PropCatalog.house_origin(group)
		var bottom := origin.y + PropCatalog.floor_offset(piece_key) * PropCatalog.placement_height_scale(group)
		var expected_top := host_origin.y + level * host_scale
		if absf(bottom - expected_top) > 0.002:
			failures.append("%s BookGroup_Small_1 bottom %.3f misses board %.3f by %.3fm" % [
				who, bottom, expected_top, bottom - expected_top])
		var model_support_point := Vector2(0.0, 0.0)
		if not MeshProbe.has_upward_support(board_triangles, model_support_point, level, 0.01):
			failures.append("%s Bookcase_2 mesh has no upward support beneath shelf level %.3f" % [who, level])
		if absf(float(group.get("pos", Vector3.ZERO).y) - expected_top) > 0.002:
			failures.append("%s book group placement is not derived from measured bottom support" % who)
		var expected_center := PropCatalog.plan_centre(piece_key,
			Vector3(group.get("pos", Vector3.ZERO)),
			float(group.get("yaw", 0.0)) + PropCatalog.face_offset(piece_key), piece_scale)
		if not rect.get_center().is_equal_approx(expected_center):
			failures.append("%s shelf group's measured rectangle misses its position" % who)
	var removed_level := seen[0] if not seen.is_empty() else -1.0
	var without_board: Array = []
	var removed_triangles := 0
	for triangle in board_triangles:
		var a: Vector3 = triangle[0]
		var b: Vector3 = triangle[1]
		var c: Vector3 = triangle[2]
		var board_face := absf(a.y - removed_level) < 0.002 \
			and absf(b.y - removed_level) < 0.002 and absf(c.y - removed_level) < 0.002
		if board_face and MeshProbe.upward_triangle_contains_point(triangle,
			Vector2.ZERO, removed_level, 0.01):
			removed_triangles += 1
		else:
			without_board.append(triangle)
	if removed_triangles == 0 or MeshProbe.has_upward_support(without_board,
			Vector2.ZERO, removed_level, 0.01):
		failures.append("%s removed-board negative did not remove actual Bookcase_2 support triangles at %.3f (removed=%d)" % [
			who, removed_level, removed_triangles])


func _bookcase_triangles() -> Array:
	var packed := load(PropCatalog.scene_path("Bookcase_2")) as PackedScene
	if packed == null:
		return []
	var root := packed.instantiate()
	var out: Array = []
	_collect_mesh_triangles(root, Transform3D.IDENTITY, out)
	root.free()
	return out


func _collect_mesh_triangles(node: Node, parent_transform: Transform3D,
		out: Array) -> void:
	var transform := parent_transform
	if node is Node3D:
		transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is ArrayMesh:
		var mesh := (node as MeshInstance3D).mesh as ArrayMesh
		for surface in range(mesh.get_surface_count()):
			for triangle in MeshProbe.surface_triangles(null, mesh, surface):
				out.append([transform * triangle[0], transform * triangle[1], transform * triangle[2]])
	for child in node.get_children():
		_collect_mesh_triangles(child, transform, out)


func _check_legacy_around_control() -> void:
	var implicit_default := _legacy_around_pose(false)
	var explicit_empty := _legacy_around_pose(true)
	if implicit_default.is_empty() or explicit_empty.is_empty():
		failures.append("legacy around-side control did not place Chair_1")
		return
	if Rect2(implicit_default["rect"]) != Rect2(explicit_empty["rect"]) \
			or not is_equal_approx(float(implicit_default["yaw"]), float(explicit_empty["yaw"])):
		failures.append("empty preferred_sides changed the legacy Chair_1 placement")


func _legacy_around_pose(pass_empty_option: bool) -> Dictionary:
	var spec := HouseSpec.new()
	spec.width = 6.0
	spec.length = 6.0
	var plan := HousePlan.new()
	plan.spec = spec
	plan.rooms.append({"kind": &"office", "rect": Rect2(0.0, 0.0, 5.0, 5.0)})
	var host := HouseFurnishGeometry.candidate("Workbench", Vector2(2.5, 2.5), 0.0)
	host["room"] = 0
	plan.furniture.append(host)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8102
	var blocked: Array[Rect2] = []
	var zones: Array[Rect2] = []
	if pass_empty_option:
		HouseFurnishPlacement.place_around(plan, 0, "Chair_1", blocked, zones, rng, false, [])
	else:
		HouseFurnishPlacement.place_around(plan, 0, "Chair_1", blocked, zones, rng)
	for piece in plan.furniture:
		if String(piece.get("key", "")) == "Chair_1":
			return {"rect": piece["rect"], "yaw": float(piece["yaw"])}
	return {}


func _check_no_writing_overlay(spec: HouseSpec, world_family: StringName, label: String) -> void:
	var plan := HousePlan.new()
	plan.spec = spec
	plan.world_family = world_family
	plan.rooms.append({"kind": &"office", "rect": Rect2(0.0, 0.0, 3.0, 3.0)})
	for step_variant in HouseFurnishingRecipes.recipe_for_room(plan, 0):
		var step: Dictionary = step_variant
		if String(step.get("group", "")) == "writing" \
				or String(step.get("key", "")) in ["Workbench", "Chair_1", "Book_5", "Scroll_1", "Bookcase_2"]:
			failures.append("%s office received the ordinary Townhouse writing overlay" % label)
			return


func _check_measured_chair_blocker(plan: HousePlan, chair_index: int,
		bookcase_index: int, who: String) -> void:
	var chair: Dictionary = plan.furniture[chair_index]
	var chair_use: Rect2 = chair.get("zone", Rect2())
	if chair_use.size.x <= 0.0 or chair_use.size.y <= 0.0:
		failures.append("%s Chair_1 has no measured use zone" % who)
		return
	var original_bookcase: Dictionary = plan.furniture[bookcase_index].duplicate(true)
	var bookcase := original_bookcase.duplicate(true)
	var chair_rect: Rect2 = chair.get("rect", Rect2())
	var pullback: Vector2 = chair_use.get_center() - chair_rect.get_center()
	if pullback.length() <= 0.001:
		failures.append("%s Chair_1 use zone has no pull-back direction" % who)
		return
	pullback = pullback.normalized()
	var blocker_yaw := PI * 0.5 if absf(pullback.x) > absf(pullback.y) else 0.0
	var blocker_scale := float(bookcase.get("scale", 1.0))
	var bookcase_size: Vector2 = PropCatalog.footprint_rotated("Bookcase_2", blocker_yaw) * blocker_scale
	if bookcase_size.x <= 0.0 or bookcase_size.y <= 0.0:
		failures.append("%s Bookcase_2 has no measured obstruction footprint" % who)
		return
	var blocker_rect := Rect2(chair_use.get_center() - bookcase_size * 0.5, bookcase_size)
	var chair_room := int(chair.get("room", -1))
	if chair_room < 0 or not HouseGeometry.room_floor_rect(plan, chair_room).grow(0.01).encloses(blocker_rect):
		failures.append("%s measured Bookcase_2 blocker does not sit on the office floor: %s" % [who, str(blocker_rect)])
		return
	var covered: float = chair_use.intersection(blocker_rect).get_area() / chair_use.get_area()
	if covered < 0.75:
		failures.append("%s measured Bookcase_2 covers only %.0f%% of Chair_1's use zone" % [who, covered * 100.0])
		return
	var use_depth: float = chair_use.size.x if absf(pullback.x) > absf(pullback.y) else chair_use.size.y
	var blocker_depth: float = bookcase_size.x if absf(pullback.x) > absf(pullback.y) else bookcase_size.y
	var residual_clearance := maxf(0.0, (use_depth - blocker_depth) * 0.5)
	if residual_clearance > HouseGeometry.PERSON_RADIUS * 0.5:
		failures.append("%s Bookcase_2 leaves %.3fm of chair-use clearance" % [who, residual_clearance])
		return
	for index in range(plan.furniture.size()):
		if index == bookcase_index:
			continue
		var standing: Dictionary = plan.furniture[index]
		if HousePlan.record_storey(standing) != HousePlan.record_storey(chair):
			continue
		if not PropCatalog.blocks_floor(String(standing.get("key", ""))):
			continue
		if blocker_rect.intersects(Rect2(standing.get("rect", Rect2()))):
			failures.append("%s blocker overlaps standing %s" % [who, String(standing.get("key", ""))])
			return
	var blocker_pos: Vector3 = bookcase.get("pos", Vector3.ZERO)
	blocker_pos.x = blocker_rect.get_center().x
	blocker_pos.z = blocker_rect.get_center().y
	bookcase["rect"] = blocker_rect
	bookcase["pos"] = blocker_pos
	bookcase["yaw"] = blocker_yaw
	plan.furniture[bookcase_index] = bookcase
	var blocked_nav := HouseNavCheck.new().check(plan)
	var chair_rejected := false
	for failure_variant in blocked_nav.get("failures", []):
		if String(failure_variant).contains("Chair_1"):
			chair_rejected = true
			break
	if not chair_rejected:
		failures.append("%s measured Bookcase_2 blocker did not invalidate Chair_1's use zone" % who)
	plan.furniture[bookcase_index] = original_bookcase


func _missing_office_activity(plan: HousePlan, room: int) -> Array[String]:
	var required: Dictionary = {}
	for step_variant in HouseFurnishingRecipes.recipe_for_room(plan, room):
		var step: Dictionary = step_variant
		var group := String(step.get("group", ""))
		if group.is_empty() or float(step.get("opt", 0.0)) < 1.0:
			continue
		var category := String(step.get("cat", ""))
		required[category] = int(required.get(category, 0)) \
			+ int(step.get("min_n", step.get("n", [1, 1])[0]))
	var missing: Array[String] = []
	for category_variant in required:
		var category := String(category_variant)
		var count := 0
		for index in plan.furniture_of(room):
			var piece: Dictionary = plan.furniture[index]
			if String(piece.get("activity_group", "")) == "writing" \
					and String(piece.get("cat", "")) == category:
				count += 1
		if count < int(required[category]):
			missing.append("writing/%s" % category)
	if plan.was_dropped(room, "activity:writing"):
		missing.append("writing/dropped")
	return missing


func _rect_gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), 0.0)
	var dy := maxf(maxf(a.position.y - b.end.y, b.position.y - a.end.y), 0.0)
	return Vector2(dx, dy).length()
