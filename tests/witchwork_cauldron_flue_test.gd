extends SceneTree

func _init() -> void:
	var result: SuiteResult = preload("res://tests/suites/witchwork_cauldron_flue_suite.gd").run()
	print(result.summary())
	for failure in result.failures:
		printerr("FAIL " + failure)
	quit(0 if result.ok() else 1)