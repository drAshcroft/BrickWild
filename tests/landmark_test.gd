extends SceneTree
## The famous churches this generator must be able to build, at four scales.
## Run: godot --headless --script res://tests/landmark_test.gd
## (or: godot --headless --script res://tests/run_all.gd -- landmark)

func _init() -> void:
	var res: SuiteResult = LandmarkSuite.run()
	for n in res.notes:
		print("    " + n)
	for w in res.warnings:
		print("  WARN " + w)
	for f in res.failures:
		print("  FAIL " + f)
	print(res.summary())
	quit(0 if res.ok() else 1)
