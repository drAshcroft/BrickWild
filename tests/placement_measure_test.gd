extends SceneTree
## Placement-only generation must preserve actual shells and public placement.
var checks := 0
var failures: Array[String] = []
var timings: Array[Dictionary] = []

func _init() -> void:
	var fixtures: Array[BuildingRequest] = []
	var styles: Array = HouseSpec.STYLES.keys()
	for i in styles.size():
		for material in [&"timber", &"stone"]:
			var request := BuildingRequest.house(4411 + i, styles[i],
				HouseSpec.TRADES.keys()[i], 9, 12, 2.7)
			request.material = material
			request.storeys = 2 if i % 2 == 0 or styles[i] == &"townhouse" else 1
			fixtures.append(request)
	var businesses: Array = ShopSpec.BUSINESSES.keys()
	for i in businesses.size():
		var request := BuildingRequest.shop(7200 + i, businesses[i], styles[i % styles.size()], 9, 12, 2.8)
		request.material = &"stone" if i % 2 else &"timber"
		request.storeys = 2 if i % 3 == 0 else 1
		fixtures.append(request)
	for request in fixtures:
		_check(request)
	# Other adapters retain full generation and their measured native entrance.
	var manor := BuildingRequest.castle(4232296064, &"norman", 40, 50, 18.8)
	var castle := BigGlade.generate(manor)
	var expected := BigGlade.placement(castle)
	_expect(BigGlade.measure(manor) == expected, "castle fallback placement")
	_expect(expected.has("approach"), "recessed manor retains its certified approach")
	_expect(not VillageLotPlanner.measure(manor).is_empty(), "village accepts native measured manor")
	_expect(BigGlade.measure(null).is_empty(), "null request refused")
	var invalid := BuildingRequest.house(42)
	invalid.width = -1
	_expect(BigGlade.measure(invalid).is_empty(), "invalid request refused")
	# Measuring uses independent specs/RNGs and must not alter a later interior.
	var request := BuildingRequest.house(303, &"townhouse", &"smith", 9, 12, 2.7)
	request.storeys = 2
	var before := BigGlade.generate(request)
	var expected_state: Variant = BuildingCodec.encode(before.plan)
	var expected_rng: int = before.spec.rng.state
	seed(8133)
	var global_expected := randi()
	seed(8133)
	BigGlade.measure(request)
	_expect(randi() == global_expected, "measurement preserves global RNG stream")
	var after := BigGlade.generate(request)
	_expect(BuildingCodec.encode(after.plan) == expected_state, "measurement preserves subsequent complete interior")
	_expect(after.spec.rng.state == expected_rng, "full generation retains exact post-furnishing RNG state")
	_expect(not after.plan.furniture.is_empty(), "public generate still furnishes")
	var report := {"checks": checks, "failures": failures, "timings": timings}
	DirAccess.make_dir_recursive_absolute("res://artifacts/p1p2_api")
	FileAccess.open("res://artifacts/p1p2_api/placement_measure.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	for failure in failures: print("FAIL ", failure)
	print("placement_measure: %d checks, %d failures, %d house/shop fixtures" % [checks, failures.size(), fixtures.size()])
	quit(0 if failures.is_empty() else 1)

func _check(request: BuildingRequest) -> void:
	var who := "%s/%s/%s/%s/%d" % [request.kind, request.style, request.purpose, request.material, request.seed]
	print("MEASURE ", who)
	var unchanged := request.to_json()
	var started := Time.get_ticks_usec()
	var full := BigGlade.generate(request)
	_expect(full.is_ok(), who + " full generation")
	if not full.is_ok(): return
	var placement := BigGlade.placement(full)
	var full_us := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var measured := BigGlade.measure(request)
	var measure_us := Time.get_ticks_usec() - started
	_expect(measured == placement, who + " exact placement (bounds, footprint, door, metadata)")
	_expect(request.to_json() == unchanged, who + " request remains unchanged")
	var shell := GeneratedBuilding.new()
	shell.request = request.copy()
	_expect(BuildingFamilyAdapter.of(request.kind).generate_for_placement(shell.request, shell), who + " shell prepared")
	_expect(shell.plan.furniture.is_empty(), who + " measurement retains no incomplete interior")
	_expect(full.plan.exterior == shell.plan.exterior, who + " exact exterior prop placements")
	_expect(full.plan.exterior_omissions == shell.plan.exterior_omissions, who + " exact exterior omissions")
	var a := HouseBuilder.new()
	var b := HouseBuilder.new()
	var a_mesh := a.build(full.plan)
	var b_mesh := b.build(shell.plan)
	_expect(_same_mesh(a_mesh, b_mesh), who + " exact shell surface arrays")
	_expect(a.part_log == b.part_log and a.mass_log == b.mass_log and a.component_log == b.component_log,
		who + " exact emitted geometry logs")
	for field in ["rooms", "doors", "windows", "stairs", "hearth", "rugs"]:
		_expect(full.plan.get(field) == shell.plan.get(field), who + " structural plan " + field)
	timings.append({"fixture": who, "full_generate_and_placement_ms": full_us / 1000.0,
		"measure_ms": measure_us / 1000.0})

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _same_mesh(a: ArrayMesh, b: ArrayMesh) -> bool:
	if a.get_surface_count() != b.get_surface_count(): return false
	for surface in a.get_surface_count():
		if var_to_bytes(a.surface_get_arrays(surface)) != var_to_bytes(b.surface_get_arrays(surface)):
			return false
	return true
