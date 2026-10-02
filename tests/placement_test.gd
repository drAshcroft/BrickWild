extends SceneTree
## BrickWild.placement()'s door contract, standalone.
## Run: godot --headless --path . --script res://tests/placement_test.gd


func _init() -> void:
	var res: SuiteResult = PlacementSuite.run()
	for n in res.notes:
		print("    " + n)
	for w in res.warnings:
		print("  WARN " + w)
	for f in res.failures:
		print("  FAIL " + f)
	print(res.summary())
	quit(0 if res.ok() else 1)
