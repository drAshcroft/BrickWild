extends SceneTree
## Fast production-path checks for Gothic chevet placements only.

const DressingSuiteImpl = preload("res://tests/suites/dressing_suite.gd")

var result := SuiteResult.new("chapel furnishing")


func _initialize() -> void:
	DressingSuiteImpl._gothic_chevet(result)
	print("chapel furnishing: %s (%d checks, %d failures)" % [
		"PASS" if result.ok() else "FAIL", result.checked, result.failures.size()])
	for failure in result.failures:
		push_error(failure)
	quit(0 if result.ok() else 1)
