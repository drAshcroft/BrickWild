extends SceneTree
## The blueprint must be a drawing of the mesh.
## Run: godot --headless --script res://tests/blueprint_match_test.gd
## (or: godot --headless --script res://tests/run_all.gd -- blueprint)

func _init() -> void:
	var res: SuiteResult = BlueprintMatchSuite.run()
	for n in res.notes:
		print("    " + n)
	for w in res.warnings:
		print("  WARN " + w)
	for f in res.failures:
		print("  FAIL " + f)
	print(res.summary())
	quit(0 if res.ok() else 1)
