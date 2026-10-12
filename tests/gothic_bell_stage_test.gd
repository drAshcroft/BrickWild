extends SceneTree
## Focused Gothic tower opening geometry and aperture rays.
## Run: godot --headless --path . --script res://tests/gothic_bell_stage_test.gd

const ChurchChangeSuite = preload("res://tests/suites/church_change_suite.gd")

func _init() -> void:
	var res := SuiteResult.new("Gothic bell stage")
	ChurchChangeSuite._gothic_bell_stage(res)
	for failure in res.failures:
		printerr("FAIL " + failure)
	print(res.summary())
	quit(0 if res.ok() else 1)
