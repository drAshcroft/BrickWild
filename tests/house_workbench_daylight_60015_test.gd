extends SceneTree
## Exact short diagnostic for the Longhall daylight failure in the quick
## furnishing sweep. A legal candidate proves a placement defect; no witness
## means the affinity oracle must classify the room as unavailable.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var n := 15
	var styles: Array = HouseSweep.styles()
	var trades: Array = HouseSweep.trades()
	var spec := HouseSpec.new()
	spec.style = styles[n % styles.size()]
	spec.trade = trades[n % trades.size()]
	spec.width = 6.0 + float(n % 5) * 2.0
	spec.length = 7.0 + float(n % 7) * 1.8
	spec.storeys = 1 + (n % 2)
	var plan: HousePlan = HouseGenerator.generate(spec, 60000 + n)
	var bench_index := -1
	for i in plan.furniture_of(0):
		if PropCatalog.category(plan.furniture[i]["key"]) == "workbench":
			bench_index = i
			break
	if bench_index < 0:
		push_error("seed 60015 has no room-zero workbench")
		quit(1)
		return
	var bench: Dictionary = plan.furniture[bench_index]
	var centre := Rect2(bench["rect"]).get_center()
	var nearest := INF
	for wi in plan.windows_of(0):
		nearest = minf(nearest, centre.distance_to(Vector2(plan.windows[wi]["pos"])))
	var back_wall := HouseFurnishSpatialCheck.fs_back_wall(plan, 0,
		Rect2(bench["rect"]), bench)
	var candidate := HouseFurnishAffinityCheck._lit_workbench_candidate(
		plan, 0, bench, bench_index)
	var affinity := HouseFurnishAffinityCheck.new()
	affinity.check_workbench_daylight(plan)
	print("seed=60015 style=", spec.style, " trade=", spec.trade,
		" footprint=", spec.width, "x", spec.length, "x", spec.height,
		" storeys=", spec.storeys)
	print("actual key=", bench["key"], " centre=", centre, " yaw=", bench["yaw"],
		" scale=", bench["scale"], " back_wall=", back_wall,
		" nearest_window=", snappedf(nearest, 0.01), " zone=", bench["zone"])
	if candidate.is_empty():
		print("NO FEASIBLE DAYLIGHT CANDIDATE after initial_blocked, existing furniture/zones, and window clearance")
		var has_failure := false
		var has_warning := false
		for message in affinity.failures:
			has_failure = has_failure or String(message).begins_with("workbench_daylight:")
		for message in affinity.warnings:
			has_warning = has_warning or String(message).begins_with("workbench_daylight:")
		if has_failure or not has_warning:
			push_error("seed 60015 daylight oracle did not classify the unavailable pose as a warning")
			quit(1)
			return
		print("ORACLE CLASSIFICATION: warning; no feasible window-wall pose exists")
		quit(0)
		return
	var candidate_centre := Vector2(candidate["pos"].x, candidate["pos"].z)
	var candidate_wall := HouseFurnishSpatialCheck.fs_back_wall(plan, 0,
		Rect2(candidate["rect"]), candidate)
	print("candidate key=", candidate["key"], " centre=", candidate_centre,
		" yaw=", candidate["yaw"], " scale=", candidate["scale"],
		" lit_wall=", candidate_wall, " zone=", candidate["zone"])
	print("oracle_failures=", str(affinity.failures))
	print("PLACEMENT DEFECT: a feasible daylight candidate exists while the current placement fails")
	quit(1)
