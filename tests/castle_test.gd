extends SceneTree
## Castle spec/build contract, structure, surfaces and landmarks in one run.
## Run: godot --headless --script res://tests/castle_test.gd
## (or: godot --headless --script res://tests/run_all.gd -- castle cmassing)

func _init() -> void:
	var suites: Array[SuiteResult] = [CastleSuite.run(), CastleNormalsSuite.run(),
		CastleMassingSuite.run(), CastleLandmarkSuite.run(),
		CastleQASuite.run()]
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
