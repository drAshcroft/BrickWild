extends SceneTree
## Normal/winding integrity and opening orientation.
## Run: godot --headless --script res://tests/normals_test.gd
## (or: godot --headless --script res://tests/run_all.gd -- normals)

func _init() -> void:
	var res: SuiteResult = NormalsSuite.run()
	for n in res.notes:
		print("    " + n)
	for w in res.warnings:
		print("  WARN " + w)
	for f in res.failures:
		print("  FAIL " + f)
	print(res.summary())
	quit(0 if res.ok() else 1)
