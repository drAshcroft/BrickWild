extends SceneTree
## A long but narrow household must keep a real domestic plan and usable stair.
var failures: Array[String] = []
var checked := 0

func _init() -> void:
	for style in [&"farmhouse", &"cottage", &"townhouse"]:
		for seed_value in [4413, 4414]:
			_check_case(style, seed_value)
	for failure in failures:
		printerr("FAIL ", failure)
	print("Large front-hall fallback: %d checks, %d failures" % [checked, failures.size()])
	quit(1 if not failures.is_empty() else 0)

func _check_case(style: StringName, seed_value: int) -> void:
	var spec := HouseSpec.new(seed_value)
	spec.style = style
	spec.width = 12.0
	spec.length = 16.0
	spec.storeys = 2
	var furnished := style == &"farmhouse" and seed_value == 4413
	var plan := HouseGenerator.generate(spec, seed_value, furnished)
	var label := "%s/%d" % [style, seed_value]
	_expect(plan.domestic_layout.get("status") == &"planned", label + ": lost household grammar")
	var kinds: Array[StringName] = []
	for room in plan.rooms_on_storey(0):
		kinds.append(plan.kind_of(room))
	_expect(kinds.has(&"kitchen") and kinds.has(&"bedroom") and kinds.has(&"hall"),
		label + ": fallback removed a required household activity")
	var builder := HouseBuilder.new()
	var mesh := builder.build(plan)
	var stairs := HouseStairCheck.check(plan, builder)
	_expect(stairs.is_empty(), label + ": " + str(stairs))
	var layout_check := HousePlanCheck.new().check(plan)
	_expect(layout_check["ok"], label + ": " + str(layout_check["failures"]))
	_expect(ComponentCheck.check(builder, mesh)["ok"], label + ": component geometry drift")
	_expect(plan.stairs.size() == 1 and bool(plan.stairs[0].get("domestic_profile", false)),
		label + ": legacy stair silently replaced the domestic flight")
	if not plan.stairs.is_empty():
		var saved: Dictionary = plan.stairs[0].duplicate(true)
		plan.stairs[0]["steps"] = 10
		var negative := HouseStairCheck.check(plan, builder)
		_expect(negative.any(func(error: String): return error.begins_with("stair_pitch:")),
			label + ": steep legacy risers escaped the same stair check")
		plan.stairs[0] = saved
	var replay := HouseGenerator.generate(spec, seed_value, false)
	_expect(replay.rooms == plan.rooms and replay.stairs == plan.stairs and replay.doors == plan.doors,
		label + ": household plan is not deterministic")

func _expect(condition: bool, message: String) -> void:
	checked += 1
	if not condition:
		failures.append(message)
