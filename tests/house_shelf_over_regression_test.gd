extends SceneTree
## Reproduces the two current shelf-over regressions through the real generator.
## This test measures the placed model footprint; it does not relax the QA rule.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var longhall := HouseSpec.new()
	longhall.style = &"longhall"
	longhall.trade = &"alchemist"
	longhall.width = 12.0
	longhall.length = 16.0
	longhall.storeys = 1
	_check_case("longhall/alchemist seed 60068", HouseGenerator.generate(longhall, 60068))

	# Match affinity-sweep index 7: asian, the same sweep trade and dimensions,
	# and two storeys. Seed 60007 is the reported failing instance.
	var asian := HouseSpec.new()
	asian.style = &"asian"
	var trades := HouseSweep.trades()
	asian.trade = trades[7 % trades.size()]
	asian.width = 10.0
	asian.length = 7.0
	asian.storeys = 2
	_check_case("asian seed 60007", HouseGenerator.generate(asian, 60007))
	_check_availability_controls()
	_finish()


func _check_case(label: String, plan: HousePlan) -> void:
	var kitchen_count := 0
	var unavailable_count := 0
	var report := HouseFurnishCheck.new().check(plan)
	for room in range(plan.room_count()):
		if plan.kind_of(room) != &"kitchen":
			continue
		kitchen_count += 1
		var cover := _physical_shelf_cover(plan, room)
		var available := _has_checker_station(plan, room)
		if available and cover < HouseFurnishAffinityCheck.FS_SHELF_COVER:
			failures.append("%s kitchen %d has a clear station but its placed shelf covers only %.0f%%"
				% [label, room, cover * 100.0])
		elif not available and cover < HouseFurnishAffinityCheck.FS_SHELF_COVER:
			unavailable_count += 1
			if _has_shelf_host(plan, room) and _has_shelf_prop(plan, room) \
					and not _has_shelf_warning(report, room):
				failures.append("%s kitchen %d lacks a shelf station but QA did not retain the unavailable warning"
					% [label, room])
	if kitchen_count == 0:
		failures.append("%s generated no kitchen to exercise shelf-over" % label)
	print("shelf-over case=", label, " kitchens=", kitchen_count,
		" geometrically_unavailable=", unavailable_count)
	for room in range(plan.room_count()):
		if plan.kind_of(room) != &"kitchen" or not _has_checker_station(plan, room):
			continue
		if _has_shelf_message(report, "failures", room) or _has_shelf_message(report, "warnings", room):
			failures.append("%s kitchen %d has a legal station but checker still reports shelf-over" % [label, room])


func _has_checker_station(plan: HousePlan, room: int) -> bool:
	var widest_placed := 0.05
	for index in plan.furniture_of(room):
		var piece: Dictionary = plan.furniture[index]
		if PropCatalog.category(String(piece["key"])) == "shelf":
			widest_placed = maxf(widest_placed, PropCatalog.size(String(piece["key"])).x)
	for index in plan.furniture_of(room):
		var host: Dictionary = plan.furniture[index]
		if PropCatalog.category(String(host["key"])) in ["workbench", "counter"] \
				and HouseFurnishAffinityCheck._fs_could_hang_over(plan, room, host, widest_placed):
			return true
	return false


func _has_shelf_warning(report: Dictionary, room: int) -> bool:
	return _has_shelf_message(report, "warnings", room) \
		and not _has_shelf_message(report, "failures", room)


func _has_shelf_host(plan: HousePlan, room: int) -> bool:
	for index in plan.furniture_of(room):
		var piece: Dictionary = plan.furniture[index]
		if PropCatalog.category(String(piece["key"])) in ["workbench", "counter"]:
			return true
	return false


func _has_shelf_prop(plan: HousePlan, room: int) -> bool:
	for index in plan.furniture_of(room):
		if PropCatalog.category(String(plan.furniture[index]["key"])) == "shelf":
			return true
	return false


func _has_shelf_message(report: Dictionary, field: String, room: int) -> bool:
	for message in report[field]:
		if String(message).begins_with("shelf_over:") \
				and String(message).contains("room %d " % room):
			return true
	return false


func _physical_shelf_cover(plan: HousePlan, room: int) -> float:
	var best := 0.0
	for shelf_index in plan.furniture_of(room):
		var shelf: Dictionary = plan.furniture[shelf_index]
		if PropCatalog.category(String(shelf["key"])) != "shelf":
			continue
		var shelf_rect := Rect2(shelf["rect"])
		var shelf_wall := HouseFurnishSpatialCheck.fs_back_wall(plan, room, shelf_rect, shelf)
		if shelf_wall < 0:
			continue
		var normal: Vector2 = HouseFurnishSpatialCheck.fs_wall_normal(plan, room, shelf_wall)
		var along := Vector2(normal.y, -normal.x)
		var shelf_span := HouseFurnishSpatialCheck.fs_projection(shelf_rect, along, shelf)
		var shelf_width := maxf(shelf_span.y - shelf_span.x, 0.05)
		for host_index in plan.furniture_of(room):
			var host: Dictionary = plan.furniture[host_index]
			if PropCatalog.category(String(host["key"])) not in ["workbench", "counter"] \
					or bool(host.get("mounted", false)) or int(host.get("host", -1)) >= 0:
				continue
			if HouseFurnishSpatialCheck.fs_back_wall(plan, room,
					Rect2(host["rect"]), host) != shelf_wall:
				continue
			var host_span := HouseFurnishSpatialCheck.fs_projection(
				Rect2(host["rect"]), along, host)
			var host_width := maxf(host_span.y - host_span.x, 0.05)
			var overlap := minf(shelf_span.y, host_span.y) - maxf(shelf_span.x, host_span.x)
			best = maxf(best, clampf(overlap / minf(shelf_width, host_width), 0.0, 1.0))
	return best


## Positive control: a real measured bench and shelf on a clear wall must remain
## available. Negative control: a full-height breast injected across that wall
## must make the checker say unavailable rather than demand a shelf in masonry.
func _check_availability_controls() -> void:
	var clear_plan := _controlled_wall_plan()
	var host := clear_plan.furniture[0]
	var widest := HouseFurnishScore._widest_of("shelf")
	if not HouseFurnishAffinityCheck._fs_could_hang_over(clear_plan, 0, host, widest):
		failures.append("clear-wall positive control was incorrectly unavailable")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9917
	HouseFurnishSurface.place_mounted(clear_plan, 0, "Shelf_Simple", rng)
	if _physical_shelf_cover(clear_plan, 0) < HouseFurnishAffinityCheck.FS_SHELF_COVER:
		failures.append("clear-wall positive control did not place a shelf over its measured workbench")
	_check_narrow_window_gap()

	var blocked_plan := _controlled_wall_plan()
	var blocked_host: Dictionary = blocked_plan.furniture[0]
	var wall: Dictionary = HouseGeometry.room_walls(blocked_plan, 0)[0]
	blocked_plan.hearth = {"breast": {"room": 0, "normal": wall["normal"],
		"centre": (Vector2(wall["from"]) + Vector2(wall["to"])) * 0.5,
		"width": 8.0, "depth": HouseGeometry.BREAST_DEPTH}}
	if HouseFurnishAffinityCheck._fs_could_hang_over(blocked_plan, 0, blocked_host, widest):
		failures.append("breast-block negative control treated masonry as a free shelf station")


func _check_narrow_window_gap() -> void:
	var key := "Shelf_Simple"
	var width := PropCatalog.size(key).x
	var lo := width / 2.0 + 0.2
	var target_x := lo + 30.0 * HouseFurnishScore.MOUNT_STEP
	var plan := _controlled_wall_plan(target_x)
	var wall: Dictionary = HouseGeometry.room_walls(plan, 0)[0]
	var clearance := (HouseGeometry.WINDOW_W + width) / 2.0 + 0.15
	var gap_half := 0.02
	for side in [-1.0, 1.0]:
		var window_x := target_x + float(side) * (clearance + gap_half)
		plan.windows.append({"room": 0, "pos": Vector2(window_x, Vector2(wall["from"]).y),
			"normal": Vector2(0.0, -1.0), "width": HouseGeometry.WINDOW_W,
			"sill": 2.0, "head": 2.4, "storey": 0})
	var host: Dictionary = plan.furniture[0]
	if not HouseFurnishAffinityCheck._fs_could_hang_over(plan, 0, host, width):
		failures.append("narrow-window positive control did not retain its 4cm legal station")
	var rng := RandomNumberGenerator.new()
	rng.seed = 60068
	HouseFurnishSurface.place_mounted(plan, 0, key, rng)
	var shelf_found := false
	for index in plan.furniture_of(0):
		var piece: Dictionary = plan.furniture[index]
		if PropCatalog.category(String(piece["key"])) != "shelf":
			continue
		shelf_found = true
		if _physical_shelf_cover(plan, 0) < HouseFurnishAffinityCheck.FS_SHELF_COVER:
			failures.append("narrow-window station placed a shelf without enough measured workbench overlap")
		if absf(float(piece["pos"].x) - target_x) > HouseFurnishScore.MOUNT_STEP * 0.51:
			failures.append("narrow-window shelf missed its single feasible fixed-phase station")
		break
	if not shelf_found:
		failures.append("narrow-window positive control placed no shelf")


func _controlled_wall_plan(target_x := 4.0) -> HousePlan:
	var plan := HousePlan.new()
	var spec := HouseSpec.new()
	spec.width = 9.0
	spec.length = 8.0
	spec.height = 2.7
	plan.spec = spec
	plan.rooms = [{"kind": &"kitchen", "rect": Rect2(Vector2.ZERO, Vector2(8.0, 7.0)), "storey": 0}]
	var wall: Dictionary = HouseGeometry.room_walls(plan, 0)[0]
	var normal: Vector2 = wall["normal"]
	var yaw := HouseFurnishGeometry.yaw_facing(normal)
	var centre := Vector2(target_x,
		(Vector2(wall["from"]) + Vector2(wall["to"])).y * 0.5)
	var footprint := PropCatalog.footprint_yawed("Workbench", yaw)
	centre += normal * (footprint.y * 0.5)
	var host := HouseFurnishGeometry.candidate("Workbench", centre, yaw)
	host["room"] = 0
	host["storey"] = 0
	host["must"] = true
	plan.furniture.append(host)
	return plan


func _finish() -> void:
	if failures.is_empty():
		print("PASS: generated shelf availability is classified honestly; clear-wall, narrow-gap, and breast controls hold")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
