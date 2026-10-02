extends SceneTree
## Prototype the exact native RNG prefix that establishes a house's chimney.
var failures: Array[String] = []
var checks := 0
var times: Array[Dictionary] = []

func _init() -> void:
	for style in HouseSpec.STYLES:
		for material in [&"timber", &"stone"]:
			for variant in range(2):
				var request := BuildingRequest.house(4411 + variant, style,
					&"smith" if variant else &"none", 9 + variant, 12 + variant, 2.7)
				request.material = material
				request.storeys = 1 + (int(style.hash()) + variant) % 3
				_check(request)
	for failure in failures: print("FAIL ", failure)
	FileAccess.open("res://artifacts/p1p2_api/hearth_prefix.json", FileAccess.WRITE).store_string(
		JSON.stringify({"checks": checks, "failures": failures, "timings": times}, "  "))
	print("hearth_prefix: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check(request: BuildingRequest) -> void:
	var who := "%s/%s/%d/%d" % [request.style, request.material, request.storeys, request.seed]
	print("PREFIX ", who)
	var started := Time.get_ticks_usec()
	var full := BrickWild.generate(request)
	var full_us := Time.get_ticks_usec() - started
	if not full.is_ok():
		failures.append(who + " invalid full request")
		return
	var prefix := GeneratedBuilding.new()
	prefix.request = request.copy()
	started = Time.get_ticks_usec()
	BuildingFamilyAdapter.of(&"house")._generate_plan(prefix.request, prefix, false)
	var plan := prefix.plan
	HouseFurnisher.prepare_shell_focus(plan, plan.spec)
	HouseExterior.dress(plan)
	var prefix_us := Time.get_ticks_usec() - started
	if plan.spec.chimney:
		_expect(full.plan.focus == plan.focus, who + " final focus parity")
	var a := HouseBuilder.new()
	var b := HouseBuilder.new()
	var ma := a.build(full.plan)
	var mb := b.build(plan)
	var same := ma.get_surface_count() == mb.get_surface_count()
	for surface in ma.get_surface_count():
		if var_to_bytes(ma.surface_get_arrays(surface)) != var_to_bytes(mb.surface_get_arrays(surface)): same = false
	_expect(same, who + " complete mesh parity")
	_expect(a.part_log == b.part_log and a.mass_log == b.mass_log and a.component_log == b.component_log,
		who + " complete emitted log parity")
	_expect(BrickWild.placement(full) == BrickWild.placement(prefix), who + " complete placement parity")
	_expect(full.plan.exterior == plan.exterior, who + " exterior parity")
	times.append({"fixture": who, "full_ms": full_us / 1000.0, "prefix_ms": prefix_us / 1000.0})

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
