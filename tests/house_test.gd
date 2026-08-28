extends SceneTree
## The house generator end to end: contract, assets, plan/furnishing/walking,
## and the archetypes.
## Run: godot --headless --script res://tests/house_test.gd

func _init() -> void:
	var suites: Array[SuiteResult] = [HouseSuite.run(), HouseAssetsSuite.run(),
		HouseQASuite.run(), HouseMultistorySuite.run(), HouseArchetypeSuite.run()]
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
