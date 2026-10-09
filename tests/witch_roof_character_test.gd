extends SceneTree
## Artifact-only selector and geometry fixture for the Witch roof proposal.

const SIZES := [
	{"name": "small", "width": 7.0, "length": 9.0, "height": 2.6},
	{"name": "default", "width": 9.0, "length": 12.0, "height": 2.6},
	{"name": "large", "width": 17.0, "length": 18.0, "height": 2.8},
]
const SEEDS := [1, 8102, 21325]
const CUSTOM_SPEC := preload("res://tests/fixtures/witch_custom_house_spec.gd")

var failures: Array[String] = []


func _init() -> void:
	for size in SIZES:
		for seed in SEEDS:
			_check_witch_geometry(size, seed)
	_check_generation_scope()
	_check_material_mode(&"witch_hut", &"none", &"", true)
	_check_material_mode(&"witch_hut", &"alchemist", &"", false)
	_check_material_mode(&"witch_hut", &"none", &"vastu", false)
	_check_material_mode(&"cottage", &"none", &"", false)
	_check_custom_material_mode()
	for failure in failures:
		printerr("FAIL ", failure)
	print("witch roof character: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _check_witch_geometry(size: Dictionary, seed: int) -> void:
	var spec := HouseSpec.new()
	spec.style = &"witch_hut"
	spec.width = float(size.width)
	spec.length = float(size.length)
	spec.height = float(size.height)
	var plan := HouseGenerator.generate(spec, seed, false)
	if plan == null:
		_fail("%s/%d plan did not generate" % [size.name, seed])
		return
	var who := "%s/%d" % [size.name, seed]
	if not HouseGeometry.has_witch_roofcraft(plan.spec, plan.world_family):
		_fail("%s lost exact built-in Witch scope" % who)
	var layout := HouseGeometry.roof_layout(plan)
	var full_span := float(layout["span"]) + HouseGeometry.roof_span_out(plan.spec) * 2.0
	var expected_offset := full_span * 0.18
	if absf(absf(float(layout["ridge_x"])) - expected_offset) > 0.002:
		_fail("%s ridge shift is not 18%% of its measured roof span" % who)
	var pitch_scale := HouseGeometry.art_pitch_scale(plan.spec)
	var pitch := float(plan.spec.roof_pitch)
	if pitch < 1.05 * pitch_scale - 0.0001 or pitch > 1.4 * pitch_scale + 0.0001:
		_fail("%s generated pitch escaped the revised Witch range" % who)
	var expected_rise := minf(minf(plan.spec.width, plan.spec.length) * pitch * 0.5,
		clampf(minf(plan.spec.width, plan.spec.length) * 0.52, 3.6, 5.6))
	if absf(float(layout["rise"]) - expected_rise) > 0.002:
		_fail("%s rise no longer follows the capped roof-height contract" % who)
	if not is_equal_approx(float(plan.spec.height), float(size.height)):
		_fail("%s interior wall/headroom datum changed with roof styling" % who)
	if plan.world_family != &"":
		_fail("%s ordinary Witch generation unexpectedly gained a world-family tag" % who)


func _check_generation_scope() -> void:
	var legacy_row: Array = HouseSpec.STYLES[&"witch_hut"]["roof_pitch"]
	if legacy_row != [1.2, 1.7]:
		_fail("shared Witch style-row pitch changed; trades and other contexts would inherit it")
	var trade_spec := HouseSpec.new()
	trade_spec.style = &"witch_hut"
	trade_spec.trade = &"alchemist"
	_check_generated_pitch(trade_spec, 8102, &"", 1.2, 1.7, "Witch trade")
	var world_spec := HouseSpec.new()
	world_spec.style = &"witch_hut"
	var world_plan := HouseGenerator.generate(world_spec, 8102, false, &"vastu")
	if world_plan == null or world_plan.world_family != &"vastu":
		_fail("world-scoped Witch generation did not retain its family context")
	else:
		_check_pitch_range(world_plan, 1.2, 1.7, "world Witch")
		if HouseGeometry.has_witch_roofcraft(world_plan.spec, world_plan.world_family):
			_fail("world-scoped Witch generation entered the built-in Witch roof path")
	var custom := CUSTOM_SPEC.new() as HouseSpec
	custom.style = &"witch_hut"
	custom.trade = &"none"
	_check_generated_pitch(custom, 8102, &"", 1.2, 1.7, "custom Witch HouseSpec")
	var cottage := HouseSpec.new()
	cottage.style = &"cottage"
	_check_generated_pitch(cottage, 8102, &"", 0.85, 1.2, "Cottage")


func _check_generated_pitch(spec: HouseSpec, seed: int, world_family: StringName,
		low: float, high: float, who: String) -> void:
	var plan := HouseGenerator.generate(spec, seed, false, world_family)
	if plan == null:
		_fail("%s pitch-scope plan did not generate" % who)
		return
	_check_pitch_range(plan, low, high, who)


func _check_pitch_range(plan: HousePlan, low: float, high: float, who: String) -> void:
	var scale := HouseGeometry.art_pitch_scale(plan.spec)
	var pitch := float(plan.spec.roof_pitch)
	if pitch < low * scale - 0.0001 or pitch > high * scale + 0.0001:
		_fail("%s generated pitch escaped its expected source range" % who)


func _check_material_mode(style: StringName, trade: StringName, world: StringName,
		expected_witch: bool) -> void:
	var spec := HouseSpec.new()
	spec.style = style
	spec.trade = trade
	spec.roof_material = &"thatch"
	var selected := HouseGeometry.has_witch_roofcraft(spec, world)
	if selected != expected_witch:
		_fail("material selector scope mismatch for %s/%s/%s" % [style, trade, world])
	var material := MaterialKit.house_roof(spec.roof_color, 0.30, 0.42, true, selected)
	if bool(material.get_shader_parameter("witch_thatch")) != expected_witch:
		_fail("shader material mode mismatch for %s/%s/%s" % [style, trade, world])
	var shader_code := String(material.shader.code)
	if not shader_code.contains("witch_thatch") or not shader_code.contains("lap_wave") \
			or not shader_code.contains("fiber_body") \
			or shader_code.contains("bundle_cell") or shader_code.contains("u_edge"):
		_fail("house roof shader lost down-slope reeds or retained rectangular bundle-grid seams")
	var legacy := MaterialKit.house_roof(spec.roof_color, 0.30, 0.42, true, false)
	if bool(legacy.get_shader_parameter("witch_thatch")):
		_fail("legacy thatch shader unexpectedly entered Witch mode")
	var no_thatch := MaterialKit.house_roof(spec.roof_color, 0.30, 0.42, false, true)
	if bool(no_thatch.get_shader_parameter("witch_thatch")):
		_fail("non-thatch roof accepted Witch bundle shader mode")


func _check_custom_material_mode() -> void:
	var custom := CUSTOM_SPEC.new() as HouseSpec
	custom.style = &"witch_hut"
	custom.trade = &"none"
	custom.roof_type = &"gable"
	custom.roof_material = &"thatch"
	_check_custom_selector(custom)


func _check_custom_selector(spec: HouseSpec) -> void:
	if HouseGeometry.has_witch_roofcraft(spec):
		_fail("custom Witch HouseSpec subclass entered Witch roof material scope")
	var material := MaterialKit.house_roof(spec.roof_color, 0.30, 0.42, true,
		HouseGeometry.has_witch_roofcraft(spec))
	if bool(material.get_shader_parameter("witch_thatch")):
		_fail("custom Witch HouseSpec subclass selected Witch shader mode")


func _fail(message: String) -> void:
	failures.append(message)
