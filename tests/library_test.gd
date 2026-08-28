extends SceneTree
## Public library facade contract.
## Run: godot --headless --path . --script res://tests/library_test.gd


func _init() -> void:
	var res: SuiteResult = LibrarySuite.run()
	for n in res.notes:
		print("    " + n)
	for w in res.warnings:
		print("  WARN " + w)
	for f in res.failures:
		print("  FAIL " + f)
	print(res.summary())
	quit(0 if res.ok() else 1)
