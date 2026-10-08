extends SceneTree
## Fixed Feng Shui composition regressions for two confirmed ordinary-home cases.

func _init() -> void:
	var result := SuiteResult.new("Feng Shui composition regressions")
	var style_rows := HouseSweep.styles()
	var trade_rows := HouseSweep.trades()
	for n in [2, 6]:
		var spec := HouseSpec.new()
		spec.style = style_rows[n % style_rows.size()]
		spec.trade = trade_rows[n % trade_rows.size()]
		spec.width = 6.0 + float(n % 5) * 2.0
		spec.length = 7.0 + float(n % 7) * 1.8
		spec.storeys = 1 + (n % 2)
		var plan := HouseGenerator.generate(spec, 60000 + n)
		var rules: Dictionary = HouseFurnishCheck.new().check(plan)
		result.checked += 1
		var bedroom := -1
		for room_index in plan.rooms.size():
			if plan.kind_of(room_index) == &"bedroom":
				bedroom = room_index
				break
		var bed_found := false
		var nightstand_found := false
		var clothes_storage_found := false
		var bedside_anchor_id := ""
		var reading_support_index := -1
		if bedroom >= 0:
			for item_index in plan.furniture_of(bedroom):
				var role_item: Dictionary = plan.furniture[item_index]
				var role_key := String(role_item.get("key", ""))
				if PropCatalog.category(role_key) == "bed":
					bed_found = true
				if role_key == "Nightstand_Shelf":
					nightstand_found = true
					bedside_anchor_id = String(role_item.get("surface_anchor_id", ""))
				if role_key == "Chest_Wood" and String(role_item.get("activity_host_anchor", "")) != "head_end":
					clothes_storage_found = true
		if not bed_found or not nightstand_found or not clothes_storage_found:
			result.fail("seed %d missing bed/nightstand/independent clothes storage in bedroom" % (60000 + n))
		if n == 6 and bedside_anchor_id == "":
			result.fail("seed %d nightstand has no stable sleep-activity anchor" % (60000 + n))
		elif n == 6:
			for item_index in plan.furniture_of(bedroom):
				var support_item: Dictionary = plan.furniture[item_index]
				if String(support_item.get("activity_anchor_id", "")) == bedside_anchor_id \
						and String(support_item.get("mount_relation", "")) == "supports_activity" \
						and String(support_item.get("key", "")) == "Shelf_Simple" \
						and bool(support_item.get("mounted", false)):
					reading_support_index = item_index
					break
			result.checked += 1
			if reading_support_index < 0:
				result.fail("seed %d has no mounted reading shelf bound to the bedside nightstand" % (60000 + n))
			else:
				var shelf_id := String(plan.furniture[reading_support_index].get("surface_anchor_id", ""))
				var supported_book := false
				for child_index in plan.furniture_of(bedroom):
					var child: Dictionary = plan.furniture[child_index]
					if String(child.get("key", "")).begins_with("Book_") \
							and int(child.get("host", -1)) == reading_support_index \
							and String(child.get("surface_parent_id", "")) == shelf_id:
						supported_book = true
						break
				if not supported_book:
					result.fail("seed %d bedside reading shelf has no physically hosted book" % (60000 + n))
		var bedroom_items: Array[int] = []
		if bedroom >= 0:
			for item_index in plan.furniture_of(bedroom):
				var nav_item: Dictionary = plan.furniture[item_index]
				var nav_category := PropCatalog.category(String(nav_item.get("key", "")))
				if nav_category == "bed" or String(nav_item.get("key", "")) == "Nightstand_Shelf":
					bedroom_items.append(item_index)
		var nav_report: Dictionary = HouseNavCheck.new().check(plan)
		result.checked += 1
		if bedroom in nav_report.get("unreached_rooms", []):
			result.fail("seed %d bedroom is unreachable in HouseNavCheck" % (60000 + n))
		var unreachable: Array = nav_report.get("unreachable_items", [])
		for item_index in bedroom_items:
			result.checked += 1
			if item_index in unreachable:
				result.fail("seed %d bed/nightstand index %d is unreachable in HouseNavCheck" % [60000 + n, item_index])
		if not bedroom_items.is_empty() and bedroom >= 0:
			_check_generated_bedside_nav_negative(result, plan, bedroom)
		if bedroom >= 0:
			for role in ["bed", "nightstand", "chest", "activity:sleep", "activity:sleep:chest"]:
				if plan.was_dropped(bedroom, role):
					result.fail("seed %d compromised bedroom role %s" % [60000 + n, role])
		if n == 2:
			if bedroom >= 0:
				for item_index in plan.furniture_of(bedroom):
					var item: Dictionary = plan.furniture[item_index]
					if PropCatalog.category(String(item.get("key", ""))) != "bed":
						continue
					var head_wall := HouseFurnishScore._bed_head_wall(plan, bedroom, item)
					if head_wall < 0:
						result.fail("seed 60002 bed has no measured headwall")
					elif HouseFurnishSpatialCheck.fs_wall_lit(plan, bedroom, head_wall):
						result.fail("seed 60002 bed is still on a lit headwall")
			for failure in rules.get("failures", []):
				if String(failure).begins_with("bed_window:"):
					result.fail("seed 60002: " + String(failure))
		else:
			var sconces: Array[Dictionary] = []
			if bedroom >= 0:
				for item_index in plan.furniture_of(bedroom):
					var item: Dictionary = plan.furniture[item_index]
					if bool(item.get("mounted", false)) and PropCatalog.category(String(item.get("key", ""))) == "sconce":
						sconces.append(item)
			if sconces.size() < 1 or sconces.size() > 2:
				result.fail("seed 60006 expected one reused or two paired sconces, got %d" % sconces.size())
			var task_light_found := false
			for sconce in sconces:
				if String(sconce.get("activity_anchor_id", "")) != "" \
						and String(sconce.get("mount_relation", "")) == "lights_activity":
					task_light_found = true
			if not task_light_found:
				result.fail("seed 60006 has no task-bound sconce serving the activity")
			if sconces.size() == 2:
				var first_wall := HouseFurnishScore._back_wall_index(plan, bedroom,
					Rect2(sconces[0].get("rect", Rect2())), sconces[0])
				var second_wall := HouseFurnishScore._back_wall_index(plan, bedroom,
					Rect2(sconces[1].get("rect", Rect2())), sconces[1])
				if first_wall < 0 or first_wall != second_wall:
					result.fail("seed 60006 added sconce is not on the authored sconce wall")
			for failure in rules.get("failures", []):
				if String(failure).begins_with("sconce_pair:"):
					result.fail("seed 60006: " + String(failure))
	_check_bedside_aisle_cardinals(result)
	# Independent fault controls ensure the Feng Shui rules remain active.
	var controls := SuiteResult.new("Feng Shui negative controls")
	HouseQASuite._fs_bed_window(controls)
	HouseQASuite._fs_sconce_pair(controls)
	result.checked += controls.checked
	for failure in controls.failures:
		result.fail(String(failure))
	print(result.summary())
	for failure in result.failures:
		print("FAIL: " + failure)
	quit(0 if result.ok() else 1)


func _check_bedside_aisle_cardinals(result: SuiteResult) -> void:
	var clearance := maxf(HouseGeometry.PATH_MIN,
		HouseGeometry.PERSON_RADIUS * 2.0 + 0.06)
	for yaw in [0.0, PI * 0.5, PI, PI * 1.5]:
		for side in [-1.0, 1.0]:
			var bed := HouseFurnishGeometry.candidate("Bed_Twin1", Vector2.ZERO, yaw, side, 1.0)
			var bed_rect := Rect2(bed["rect"])
			var access := Rect2(bed["zone"])
			var outward := (access.get_center() - bed_rect.get_center()).normalized()
			var lane := HouseFurnishGeometry.ordinary_bedside_aisle(access, bed_rect, yaw)
			result.checked += 1
			if not lane.grow(0.01).encloses(access):
				result.fail("bedside lane does not contain its use zone yaw=%s side=%s" % [yaw, side])
			if absf(outward.x) > 0.5:
				if absf(lane.size.y - access.size.y) > 0.01:
					result.fail("bedside lane grew across bed yaw=%s side=%s" % [yaw, side])
				var target_width := maxf(access.size.x, clearance)
				var expected_edge := access.position.x + target_width if outward.x > 0.0 else access.end.x - target_width
				var actual_edge := lane.end.x if outward.x > 0.0 else lane.position.x
				if absf(actual_edge - expected_edge) > 0.01:
					result.fail("bedside lane extended the wrong way yaw=%s side=%s" % [yaw, side])
			else:
				if absf(lane.size.x - access.size.x) > 0.01:
					result.fail("bedside lane grew across bed yaw=%s side=%s" % [yaw, side])
				var target_width_y := maxf(access.size.y, clearance)
				var expected_edge_y := access.position.y + target_width_y if outward.y > 0.0 else access.end.y - target_width_y
				var actual_edge_y := lane.end.y if outward.y > 0.0 else lane.position.y
				if absf(actual_edge_y - expected_edge_y) > 0.01:
					result.fail("bedside lane extended the wrong way yaw=%s side=%s" % [yaw, side])


func _check_generated_bedside_nav_negative(result: SuiteResult, source: HousePlan, room: int) -> void:
	var bed_index := -1
	for item_index in source.furniture_of(room):
		if PropCatalog.category(String(source.furniture[item_index].get("key", ""))) == "bed":
			bed_index = item_index
			break
	if bed_index < 0:
		return
	var access := Rect2(source.furniture[bed_index].get("zone", Rect2()))
	if not access.has_area():
		result.fail("generated bedroom bed has no measurable side-approach zone")
		return
	var plan := HousePlan.new()
	plan.spec = source.spec
	plan.rooms = source.rooms
	plan.doors = source.doors
	plan.windows = source.windows
	plan.stairs = source.stairs
	plan.columns = source.columns
	plan.courts = source.courts
	plan.zones = source.zones
	plan.hearth = source.hearth
	plan.dais = source.dais
	plan.furniture = source.furniture.duplicate(true)
	var size_a := PropCatalog.footprint_rotated("Table_Large", 0.0)
	var size_b := PropCatalog.footprint_rotated("Table_Large", PI * 0.5)
	var scale_a := maxf(access.size.x / maxf(size_a.x, 0.01), access.size.y / maxf(size_a.y, 0.01))
	var scale_b := maxf(access.size.x / maxf(size_b.x, 0.01), access.size.y / maxf(size_b.y, 0.01))
	var yaw := 0.0 if scale_a <= scale_b else PI * 0.5
	var scale := maxf(PropCatalog.min_scale("Table_Large"), minf(scale_a, scale_b)) * 1.01
	var centre := access.get_center()
	var blocker := HouseFurnishGeometry.candidate("Table_Large", centre, yaw, 1.0, scale)
	var blocker_rect: Rect2 = Rect2(blocker["rect"])
	if not blocker_rect.grow(0.01).encloses(access):
		result.fail("generated nav negative cannot physically cover the measured bedside approach")
		return
	var blocked: Array[Rect2] = []
	var zones: Array[Rect2] = []
	HouseFurnishGeometry.commit(plan, room, blocker, blocked, zones)
	var nav: Dictionary = HouseNavCheck.new().check(plan)
	result.checked += 1
	var unreachable: Array = nav.get("unreachable_items", [])
	if bed_index not in unreachable:
		result.fail("generated bed remained reachable after measured furniture blocked its access strip")
