extends SceneTree
## The temple generator end to end: contract, the rite, and the archetypes.
## Run: godot --headless --script res://tests/temple_test.gd

func _init() -> void:
	var suites: Array[SuiteResult] = [TempleSuite.run(), TempleQASuite.run(),
		TempleArchetypeSuite.run()]
	var failed := 0
	for res in suites:
		for n in res.notes:
			print("    " + n)
		for w in res.warnings:
			print("  WARN " + w)
		for f in res.failures:
			print("  FAIL " + f)
		print(res.summary())
		if not res.ok():
			failed += 1
	quit(1 if failed > 0 else 0)
