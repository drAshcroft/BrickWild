extends SceneTree

const ChurchRoofSuite = preload("res://tests/suites/church_roof_suite.gd")

func _init() -> void:
	var result := SuiteResult.new("VIS-008 dome support and shell fixtures")
	ChurchRoofSuite._hero_dome_segments(result)
	ChurchRoofSuite._pendentive_transition(result)
	for failure in result.failures:
		print("FAIL: " + failure)
	print(result.summary())
	quit(0 if result.ok() else 1)
