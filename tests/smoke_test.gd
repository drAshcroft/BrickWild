extends SceneTree
## Superseded house-generator stack.
## Run: godot --headless --script res://tests/smoke_test.gd
## (or: godot --headless --script res://tests/run_all.gd -- legacy)

func _init() -> void:
	var res: SuiteResult = LegacyBuildingSuite.run()
	for n in res.notes:
		print("    " + n)
	for w in res.warnings:
		print("  WARN " + w)
	for f in res.failures:
		print("  FAIL " + f)
	print(res.summary())
	quit(0 if res.ok() else 1)
