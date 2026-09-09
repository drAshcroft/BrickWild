extends SceneTree
## Fast roof geometry regressions. --full also furnishes the four seed fixtures.
func _init() -> void:
	var result: SuiteResult = preload("res://tests/suites/house_roof_suite.gd").run(OS.get_cmdline_user_args().has("--full"))
	for note in result.notes:
		print(note)
	for failure in result.failures:
		printerr("FAIL " + failure)
	print(result.summary())
	quit(0 if result.ok() else 1)
