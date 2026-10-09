extends SceneTree

const CHECKS = preload("res://tests/suites/library_suite.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("usage: --script res://tools/library_partition_driver.gd -- <partition>")
		quit(2)
		return
	var partition: String = args[0]
	var result := SuiteResult.new("libraryquick:" + partition)
	CHECKS._quick = true
	CHECKS._cache.clear()
	CHECKS._tm.clear()
	var started := Time.get_ticks_msec()
	match partition:
		"church_101", "castle_202", "house_303", "shop_353", "hotel_373", "temple_404", "windmill_505", "windmill_515":
			var request := _request_for(partition)
			if request == null:
				push_error("partition has no request: " + partition)
				quit(2)
				return
			print("[library-partition] request=%s:%d" % [String(request.kind), request.seed])
			var requests: Array[BuildingRequest] = [request]
			CHECKS._check_family(result, request)
			CHECKS._check_contract(result, requests)
			CHECKS._check_documents(result, requests)
		"village":
			print("[library-partition] request=village:9101")
			CHECKS._check_village_kind(result)
		"world":
			print("[library-partition] request=world:828")
			CHECKS._check_world_kind(result)
			CHECKS._check_world_generic_envelope(result)
		"globals":
			print("[library-partition] controls=globals")
			_run_invalid_controls(result)
			var full_requests := _all_quick_requests()
			CHECKS._check_every_kind_covered(result, full_requests)
			_run_descriptor_and_stacked_house_controls(result)
		_:
			push_error("unknown partition: " + partition)
			quit(2)
			return
	CHECKS._notes(result)
	print("[library-partition] %s elapsed_ms=%d" % [partition, Time.get_ticks_msec() - started])
	for note in result.notes:
		print("[library-partition] note: " + note)
	for warning in result.warnings:
		push_warning(warning)
	for failure in result.failures:
		push_error(failure)
	print(result.summary())
	quit(0 if result.ok() else 1)


func _all_quick_requests() -> Array[BuildingRequest]:
	return [
		BuildingRequest.church(101, &"gothic", 10.0, 22.0, 12.0),
		BuildingRequest.castle(202, &"norman", 48.0, 42.0, 18.0),
		BuildingRequest.house(303, &"cottage", &"none", 9.0, 12.0, 2.6),
		BuildingRequest.shop(353, &"blacksmith", &"longhall", 11.0, 14.0, 2.8),
		BuildingRequest.hotel(373, &"grand_budapest", 30.0, 16.0, 3.0),
		BuildingRequest.temple(404, &"basilica", &"blood", 26.0, 44.0, 12.0),
		BuildingRequest.windmill(505, &"tower", 13.0, 6.5, 14.0),
		BuildingRequest.windmill(515, &"paddle", 10.0, 6.5, 12.0),
	]


func _request_for(partition: String) -> BuildingRequest:
	for request in _all_quick_requests():
		if "%s_%d" % [String(request.kind), request.seed] == partition:
			return request
	return null


func _run_invalid_controls(result: SuiteResult) -> void:
	var unknown := BuildingRequest.church(1)
	unknown.kind = &"shed"
	CHECKS._check_invalid(result, unknown, &"unknown_kind")
	var bad_style := BuildingRequest.church(1)
	bad_style.style = &"cardboard"
	CHECKS._check_invalid(result, bad_style, &"unknown_style")
	var bad_trade := BuildingRequest.house(1)
	bad_trade.purpose = &"dragon_tamer"
	CHECKS._check_invalid(result, bad_trade, &"unknown_trade")
	var bad_storeys := BuildingRequest.house(1)
	bad_storeys.storeys = 4
	CHECKS._check_invalid(result, bad_storeys, &"storeys_out_of_range")
	var bad_business := BuildingRequest.shop(1)
	bad_business.purpose = &"dragon_tamer"
	CHECKS._check_invalid(result, bad_business, &"unknown_business")
	var bad_size := BuildingRequest.temple(1)
	bad_size.width = 0.0
	CHECKS._check_invalid(result, bad_size, &"invalid_dimension")
	var non_finite := BuildingRequest.castle(1)
	non_finite.height = INF
	CHECKS._check_invalid(result, non_finite, &"invalid_dimension")
	var outside := BuildingRequest.church(1)
	outside.width = 5.9
	CHECKS._check_invalid(result, outside, &"dimension_out_of_range")
	CHECKS._check_invalid(result, null, &"request_required")


func _run_descriptor_and_stacked_house_controls(result: SuiteResult) -> void:
	var descriptor: Dictionary = BrickWild.describe_kind(&"house")
	result.checked += 1
	if descriptor.get("api_version") != BrickWild.API_VERSION \
			or (descriptor.get("styles", []) as Array).is_empty() \
			or (descriptor.get("purposes", []) as Array).is_empty() \
			or not descriptor.has("storeys"):
		result.fail("house descriptor is incomplete")
	descriptor["width"]["min"] = -1.0
	if BrickWild.describe_kind(&"house")["width"]["min"] < 0.0:
		result.fail("describe_kind returned mutable library state")
	var stacked_request := BuildingRequest.house(505, &"cottage", &"none", 9.0, 12.0, 2.6, 2)
	var stacked_copy := stacked_request.copy()
	result.checked += 1
	if stacked_request.storeys != 2 or stacked_copy.storeys != 2:
		result.fail("house storeys did not survive request copy")
	var stacked: GeneratedBuilding = BrickWild.generate(stacked_request)
	result.checked += 1
	var stacked_spec: HouseSpec = stacked.spec as HouseSpec
	if not stacked.is_ok() or stacked_spec == null or stacked_spec.storeys != 2 \
			or stacked.plan == null:
		result.fail("two-storey house did not transfer storeys into its model")
	else:
		var plan: HousePlan = stacked.plan
		var floors := {}
		for room in plan.rooms:
			floors[int(room.get("storey", 0))] = true
		var exterior_upper := false
		for door in plan.doors:
			if door.get("storey", 0) > 0 and door["exterior"]:
				exterior_upper = true
		if floors.size() != 2 or plan.stairs.size() != 1 or exterior_upper \
				or plan.reachable_rooms(plan.entrance_room()).size() != plan.room_count():
			result.fail("two-storey plan lacks complete upper-floor circulation")
