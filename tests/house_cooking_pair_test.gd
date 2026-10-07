extends SceneTree
## Generated ordinary-house kitchen aisle contract and negative controls.

var failures: Array[String] = []


func _init() -> void:
	# Room proportions are being tuned; search a short, fixed request list for
	# a real generated opposed pair instead of making one layout the only oracle.
	var requests: Array[Dictionary] = [
		{"width": 7.0, "length": 9.0, "seed": 1},
		{"width": 7.0, "length": 9.0, "seed": 8102},
		{"width": 7.0, "length": 9.0, "seed": 21325},
		{"width": 9.0, "length": 12.0, "seed": 1},
		{"width": 9.0, "length": 12.0, "seed": 8102},
	]
	var checked_pair := false
	var selected_fixture := ""
	for request in requests:
		var spec := HouseSpec.new()
		spec.style = &"cottage"
		spec.width = float(request["width"])
		spec.length = float(request["length"])
		spec.height = 2.6
		var plan := HouseGenerator.generate(spec, int(request["seed"]), true)
		var pair := _opposed_pair(plan)
		if pair.is_empty():
			continue
		checked_pair = true
		selected_fixture = "%sx%s seed %s" % [request["width"], request["length"], request["seed"]]
		_check_generated_pair(plan, pair)
		_check_wrong_facing_rejected(plan, pair)
		_check_storage_crossing_use_zone_rejected(plan, pair)
		_check_missing_storage_rejected(plan, pair)
		_check_blocked_aisle_unreachable(plan, pair)
		break
	if not checked_pair:
		failures.append("bounded generated cottage requests produced no opposed cooking pair")
	for failure in failures:
		push_error(failure)
	print("generated opposed cooking pair fixture=%s failures=%d" % [selected_fixture, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _opposed_pair(plan: HousePlan) -> Dictionary:
	for workbench_index in plan.furniture.size():
		var workbench: Dictionary = plan.furniture[workbench_index]
		if String(workbench.get("cat", "")) != "workbench" \
				or String(workbench.get("activity_group", "")) != "cooking" \
				or String(workbench.get("activity_relation", "")) != "opposed_work_aisle":
			continue
		var best_storage := -1
		var best_gap := INF
		for storage_index in plan.furniture.size():
			var storage: Dictionary = plan.furniture[storage_index]
			if int(storage.get("room", -1)) == int(workbench.get("room", -2)) \
					and String(storage.get("cat", "")) == "storage" \
					and int(workbench.get("room", -1)) == int(storage.get("room", -2)):
				var gap: float = _edge_distance(Rect2(workbench["rect"]), Rect2(storage["rect"]))
				if gap < best_gap:
					best_gap = gap
					best_storage = storage_index
		if best_storage >= 0:
			return {"room": int(workbench["room"]), "workbench": workbench_index,
				"storage": best_storage}
	return {}


func _check_generated_pair(plan: HousePlan, pair: Dictionary) -> void:
	var room: int = int(pair["room"])
	var storage: Dictionary = plan.furniture[int(pair["storage"])]
	var workbench: Dictionary = plan.furniture[int(pair["workbench"])]
	var host_facing := HouseFurnishScore._facing_of(float(storage.get("yaw", 0.0))).normalized()
	var prep_facing := HouseFurnishScore._facing_of(float(workbench.get("yaw", 0.0))).normalized()
	var delta: Vector2 = Rect2(workbench["rect"]).get_center() - Rect2(storage["rect"]).get_center()
	if host_facing.dot(delta) <= 0.0 or prep_facing.dot(-host_facing) < 0.99:
		failures.append("generated cooking pair does not face across its measured aisle")
	var host_zone: Rect2 = Rect2(storage.get("zone", Rect2()))
	var prep_zone: Rect2 = Rect2(workbench.get("zone", Rect2()))
	if not host_zone.has_area() or not prep_zone.has_area() \
			or host_zone.intersects(Rect2(workbench["rect"])) \
			or prep_zone.intersects(Rect2(storage["rect"])):
		failures.append("generated cooking aisle use zones collide with the opposite fixture")
	var edge_gap: float = _edge_distance(Rect2(storage["rect"]), Rect2(workbench["rect"]))
	if edge_gap <= 0.0 or edge_gap > 2.5:
		failures.append("generated opposed work surface is outside the audited aisle bound")
	if PropCatalog.placement_height(workbench) < HouseFurnishingRecipes.DOMESTIC_PREP_MIN_HEIGHT:
		failures.append("generated cooking workbench is below adult prep height")
	var floor_y: float = HouseFurnishGeometry.storey_base(plan, room) + HouseGeometry.FLOOR_T
	for index in [int(pair["storage"]), int(pair["workbench"])]:
		if not is_equal_approx(float(plan.furniture[index]["pos"].y), floor_y):
			failures.append("generated cooking pair member is not at finished floor height")
			break
	var nav: Dictionary = HouseNavCheck.new().check(plan)
	if room in nav.get("unreached_rooms", []) \
			or int(pair["storage"]) in nav.get("unreachable_items", []) \
			or int(pair["workbench"]) in nav.get("unreachable_items", []):
		failures.append("generated cooking pair is unreachable on the real walk grid")
	var cookware_hosted := false
	for index in plan.furniture.size():
		var piece: Dictionary = plan.furniture[index]
		if int(piece.get("room", -1)) == room and String(piece.get("cat", "")) == "cookware" \
				and int(piece.get("host", -1)) == int(pair["workbench"]):
			cookware_hosted = true
			var expected_y: float = float(workbench["pos"].y) \
				+ PropCatalog.surface_height(String(workbench["key"])) \
				* PropCatalog.placement_height_scale(workbench)
			if not is_equal_approx(float(piece["pos"].y), expected_y):
				failures.append("cooking pot is not supported by the workbench surface")
			break
	if not cookware_hosted:
		failures.append("generated kitchen cookware is not hosted on its workbench")
	var audited := _copy_plan(plan)
	audited.compromises[room] = []
	HouseFurnisher._audit_activity_groups(audited)
	if audited.was_dropped(room, "activity:cooking:relation:storage"):
		failures.append("activity audit rejects the generated opposed storage/workbench relation")


func _check_wrong_facing_rejected(plan: HousePlan, pair: Dictionary) -> void:
	var damaged := _copy_plan(plan)
	var room: int = int(pair["room"])
	var index: int = int(pair["workbench"])
	var workbench: Dictionary = damaged.furniture[index]
	workbench["yaw"] = float(damaged.furniture[int(pair["storage"])]["yaw"])
	damaged.furniture[index] = workbench
	damaged.compromises[room] = []
	HouseFurnisher._audit_activity_groups(damaged)
	if not damaged.was_dropped(room, "activity:cooking:relation:storage"):
		failures.append("activity audit accepts a workbench facing away from kitchen storage")


func _check_storage_crossing_use_zone_rejected(plan: HousePlan, pair: Dictionary) -> void:
	var damaged := _copy_plan(plan)
	var room: int = int(pair["room"])
	var storage_index: int = int(pair["storage"])
	var workbench: Dictionary = damaged.furniture[int(pair["workbench"])]
	var storage: Dictionary = damaged.furniture[storage_index]
	var rect: Rect2 = Rect2(storage["rect"])
	var target: Vector2 = Rect2(workbench["zone"]).get_center()
	var moved_rect := Rect2(target - rect.size * 0.5, rect.size)
	storage["rect"] = moved_rect
	storage["pos"] = Vector3(target.x, float(storage["pos"].y), target.y)
	damaged.furniture[storage_index] = storage
	damaged.compromises[room] = []
	HouseFurnisher._audit_activity_groups(damaged)
	if not damaged.was_dropped(room, "activity:cooking:relation:storage"):
		failures.append("activity audit accepts storage placed across the prep work zone")


func _check_missing_storage_rejected(plan: HousePlan, pair: Dictionary) -> void:
	var damaged := _copy_plan(plan)
	var room: int = int(pair["room"])
	damaged.furniture.remove_at(int(pair["storage"]))
	damaged.compromises[room] = []
	HouseFurnisher._audit_activity_groups(damaged)
	if not damaged.was_dropped(room, "activity:cooking:storage"):
		failures.append("activity audit accepts an opposed workbench with no storage")
	if not damaged.was_dropped(room, "activity:cooking:relation:storage"):
		failures.append("activity audit accepts a missing host for the prep workbench")


func _check_blocked_aisle_unreachable(plan: HousePlan, pair: Dictionary) -> void:
	var damaged := _copy_plan(plan)
	var room: int = int(pair["room"])
	var workbench: Dictionary = damaged.furniture[int(pair["workbench"])]
	var use_zone: Rect2 = Rect2(workbench["zone"])
	if not PropCatalog.blocks_floor("Cabinet"):
		failures.append("aisle negative-control Cabinet is not a measured floor obstruction")
		return
	var blocked: Array[Rect2] = []
	var zones: Array[Rect2] = []
	var chosen_scale := 1.0
	var cabinet_foot: Vector2 = PropCatalog.footprint_rotated("Cabinet", 0.0)
	var best_overhang := INF
	for scale in HouseFurnishGeometry.scales("Cabinet"):
		var foot: Vector2 = PropCatalog.footprint_rotated("Cabinet", 0.0) * float(scale)
		var nx: int = maxi(1, ceili(use_zone.size.x / foot.x))
		var nz: int = maxi(1, ceili(use_zone.size.y / foot.y))
		var overhang: float = float(nx * nz) * foot.x * foot.y \
			- use_zone.size.x * use_zone.size.y
		if overhang < best_overhang:
			best_overhang = overhang
			chosen_scale = float(scale)
			cabinet_foot = foot
	var count_x: int = maxi(1, ceili(use_zone.size.x / cabinet_foot.x))
	var count_z: int = maxi(1, ceili(use_zone.size.y / cabinet_foot.y))
	var row_size := Vector2(cabinet_foot.x * float(count_x),
		cabinet_foot.y * float(count_z))
	var row_origin: Vector2 = use_zone.get_center() - row_size * 0.5
	for x_index in count_x:
		for z_index in count_z:
			var center := row_origin + Vector2(
				(float(x_index) + 0.5) * cabinet_foot.x,
				(float(z_index) + 0.5) * cabinet_foot.y)
			var obstruction := HouseFurnishGeometry.candidate("Cabinet", center,
				0.0, 1.0, chosen_scale)
			if not Rect2(obstruction["rect"]).intersects(use_zone):
				failures.append("Cabinet row failed to cover the generated work-use zone")
				return
			HouseFurnishGeometry.commit(damaged, room, obstruction, blocked, zones)
	var nav: Dictionary = HouseNavCheck.new().check(damaged)
	if int(pair["workbench"]) not in nav.get("unreachable_items", []) \
			and room not in nav.get("unreached_rooms", []):
		failures.append("nav check still reaches the workbench through a real obstruction in its aisle")


func _copy_plan(source: HousePlan) -> HousePlan:
	var copy := HousePlan.new()
	copy.spec = source.spec
	copy.rooms = source.rooms.duplicate(true)
	copy.doors = source.doors.duplicate(true)
	copy.windows = source.windows.duplicate(true)
	copy.stairs = source.stairs.duplicate(true)
	copy.columns = source.columns.duplicate(true)
	copy.courts = source.courts.duplicate(true)
	copy.zones = source.zones.duplicate(true)
	copy.hearth = source.hearth.duplicate(true)
	copy.dais = source.dais.duplicate(true)
	copy.furniture = source.furniture.duplicate(true)
	copy.compromises = source.compromises.duplicate(true)
	return copy


func _edge_distance(a: Rect2, b: Rect2) -> float:
	var gap_x: float = maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), 0.0)
	var gap_y: float = maxf(maxf(a.position.y - b.end.y, b.position.y - a.end.y), 0.0)
	return Vector2(gap_x, gap_y).length()
