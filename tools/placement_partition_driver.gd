extends SceneTree

const CHECKS = preload("res://tests/suites/placement_suite.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("usage: --script res://tools/placement_partition_driver.gd -- <partition>")
		quit(2)
		return
	var partition: String = args[0]
	var result := SuiteResult.new("placementquick:" + partition)
	CHECKS._tm.clear()
	var started := Time.get_ticks_msec()
	if not _run_partition(partition, result):
		push_error("unknown placement partition: " + partition)
		quit(2)
		return
	CHECKS._notes(result)
	print("[placement-partition] %s elapsed_ms=%d" % [partition, Time.get_ticks_msec() - started])
	for note in result.notes:
		print("[placement-partition] note: " + note)
	for warning in result.warnings:
		push_warning(warning)
	for failure in result.failures:
		push_error(failure)
	print(result.summary())
	quit(0 if result.ok() else 1)


func _run_partition(partition: String, result: SuiteResult) -> bool:
	match partition:
		"house_shop":
			_run_canonical(result, "house")
			_run_canonical(result, "shop")
			_run_orientation(result, [821, 822])
		"church":
			_run_canonical(result, "church")
			_run_orientation(result, [824])
		"castle":
			_run_canonical(result, "castle")
		"castle_orientation":
			_run_orientation(result, [825])
		"temple":
			_run_canonical(result, "temple")
		"temple_orientation":
			_run_orientation(result, [826])
		"hotel_orientation":
			_run_orientation(result, [823])
		"village":
			_run_canonical(result, "village")
			_run_orientation(result, [827])
		"world_insula":
			_run_canonical(result, "world")
		"world_insula_orientation":
			_run_orientation(result, [828])
		"world_hall_orientation":
			_run_orientation(result, [829])
		"world_stupa_orientation":
			_run_orientation(result, [830])
		"world_rect":
			print("[placement-partition] control=world_rect:house:42")
			CHECKS._check_world_rect(result)
		_:
			return false
	return true


func _run_canonical(result: SuiteResult, kind: String) -> void:
	print("[placement-partition] request=%s:1000" % kind)
	match kind:
		"house":
			CHECKS._check_family(result, kind, func(s: int): return BuildingRequest.house(s, &"cottage", &"none", 9.0, 12.0, 2.6), 1)
		"shop":
			CHECKS._check_family(result, kind, func(s: int): return BuildingRequest.shop(s, &"blacksmith", &"longhall", 11.0, 14.0, 2.8), 1)
		"church":
			CHECKS._check_family(result, kind, func(s: int): return BuildingRequest.church(s, &"gothic", 10.0, 22.0, 12.0), 1)
		"castle":
			CHECKS._check_family(result, kind, func(s: int): return BuildingRequest.castle(s, &"norman", 55.0, 50.0, 18.0), 1)
		"temple":
			CHECKS._check_family(result, kind, func(s: int): return BuildingRequest.temple(s, &"basilica", &"blood", 26.0, 44.0, 12.0), 1)
		"world":
			print("[placement-partition] fixture=world:1000 style=insula purpose=port_tenement size=30x24x15")
			CHECKS._check_family(result, "world", CHECKS._world_request, 1, 0.6)
		"village":
			CHECKS._check_family(result, "village", CHECKS._village_request, 1, 0.6)


func _run_orientation(result: SuiteResult, seeds: Array) -> void:
	var all_requests: Array[BuildingRequest] = CHECKS._orientation_requests(true)
	for seed in seeds:
		var found: BuildingRequest
		var matches := 0
		for request in all_requests:
			if int(request.seed) == int(seed):
				found = request
				matches += 1
		if matches != 1:
			result.fail("orientation seed %d matched %d canonical requests" % [seed, matches])
			continue
		print("[placement-partition] orientation=%s:%d" % [found.kind, seed])
		var subset: Array[BuildingRequest] = [found]
		CHECKS._check_orientation_requests(result, subset, true)
