extends SceneTree


func _init() -> void:
	var suites: Array[SuiteResult] = [HotelSuite.run(), HotelLandmarkSuite.run()]
	var failed := 0
	for res in suites:
		for note in res.notes:
			print("    " + note)
		for warning in res.warnings:
			print("  WARN " + warning)
		for failure in res.failures:
			print("  FAIL " + failure)
		print(res.summary())
		if not res.ok():
			failed += 1
	quit(1 if failed > 0 else 0)
