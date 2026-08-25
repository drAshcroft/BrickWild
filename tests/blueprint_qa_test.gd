extends SceneTree
## Full voxel QA sweep (slow).
## Run: godot --headless --script res://tests/blueprint_qa_test.gd
## (or: godot --headless --script res://tests/run_all.gd -- voxelqa)

func _init() -> void:
	var res: SuiteResult = BlueprintQASuite.run()
	for n in res.notes:
		print("    " + n)
	for w in res.warnings:
		print("  WARN " + w)
	for f in res.failures:
		print("  FAIL " + f)
	print(res.summary())
	quit(0 if res.ok() else 1)
