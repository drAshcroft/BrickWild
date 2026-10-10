extends SceneTree

const EXTERIOR_SUITE := preload("res://tests/suites/house_exterior_suite.gd")

func _init() -> void:
	var result := SuiteResult.new("Witch facade and cauldron lights")
	for rotated in [false, true]:
		for trade in [&"none", &"farmer", &"alchemist", &"innkeeper"]:
			var spec := HouseSpec.new(4413)
			spec.style = &"witch_hut"
			spec.trade = trade
			spec.width = 13.0 if rotated else 9.0
			spec.length = 9.0 if rotated else 13.0
			var plan := HouseGenerator.generate(spec, 4413, false)
			EXTERIOR_SUITE._check_assembly(result, plan,
				"witch_hut/%s rotated=%s" % [trade, str(rotated)])
	for failure in result.failures:
		printerr("FAIL " + failure)
	print("Witch facade and cauldron lights: %d checks, %d failures" % [result.checked, result.failures.size()])
	quit(1 if not result.failures.is_empty() else 0)
