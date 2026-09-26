extends SceneTree
## Standalone entry point; the same checks also run in lane:castle.
func _init() -> void:
	var result: SuiteResult = preload("res://tests/suites/castle_gate_access_suite.gd").run()
	for failure in result.failures:
		print("FAIL: ", failure)
	print(result.summary())
	quit(0 if result.ok() else 1)
