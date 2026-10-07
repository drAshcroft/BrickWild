extends SceneTree
## Run against a generated compact shared-cooking hall and use its real
## workbench. The explicitly requested Pot_1 exercises a non-square measured
## cookware footprint through the real preferred-host placer.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var spec := HouseSpec.new()
	spec.style = &"cottage"
	spec.width = 7.0
	spec.length = 9.0
	spec.height = 2.6
	var plan: HousePlan = HouseGenerator.generate(spec, 1, true)
	if plan.room_count() != 2:
		failures.append("fixture did not generate the compact two-room layout")
		_finish(failures)
		return
	var hall := -1
	for room in range(plan.room_count()):
		if plan.kind_of(room) == &"hall":
			hall = room
			break
	if hall < 0 or not plan.rooms[hall].get("domestic_functions", []).has(&"cooking"):
		failures.append("fixture has no generated shared-cooking hall")
		_finish(failures)
		return
	var host_index := -1
	for index in plan.furniture_of(hall):
		if String(plan.furniture[index].get("cat", "")) == "workbench":
			host_index = index
			break
	if host_index < 0:
		failures.append("generated shared hall has no workbench host")
		_finish(failures)
		return
	var retained: Array[Dictionary] = []
	for piece in plan.furniture:
		if int(piece.get("host", -1)) == host_index:
			continue
		retained.append(piece)
	plan.furniture = retained
	var rng := RandomNumberGenerator.new()
	rng.seed = 8271
	HouseFurnishPlacement._place_on_preferred_category(plan, hall, "Pot_1", "workbench", rng)
	var found := false
	for piece in plan.furniture:
		if String(piece.get("key", "")) != "Pot_1" or int(piece.get("host", -1)) != host_index:
			continue
		found = true
		var host: Dictionary = plan.furniture[host_index]
		var physical_yaw: float = float(piece["yaw"]) + PropCatalog.face_offset("Pot_1")
		var expected: Vector2 = PropCatalog.footprint_rotated("Pot_1", physical_yaw) \
			* float(piece.get("scale", 1.0))
		var unrotated: Vector2 = PropCatalog.footprint("Pot_1") * float(piece.get("scale", 1.0))
		if absf(expected.x - unrotated.x) < 0.02 \
				and absf(expected.y - unrotated.y) < 0.02:
			failures.append("fixture yaw did not exercise a meaningful non-square footprint rotation")
		if not Vector2(piece["rect"].size).is_equal_approx(expected):
			failures.append("Pot_1 support rectangle ignores the assembled model yaw/face offset")
		if not Rect2(host["rect"]).grow(-0.06).encloses(Rect2(piece["rect"])):
			failures.append("Pot_1 overhangs the generated workbench top")
		if absf(float(piece["pos"].y) - float(host["pos"].y) \
				- PropCatalog.surface_height(String(host["key"])) * PropCatalog.placement_height_scale(host)) > 0.001:
			failures.append("Pot_1 is not placed at the measured workbench surface height")
	if not found:
		failures.append("real preferred-host placement did not place the requested Pot_1")
	_finish(failures)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("PASS: generated Pot_1 cookware uses its measured rotated footprint on the workbench")
		quit(0)
		return
	for failure in failures:
		printerr(failure)
	quit(1)
