extends RefCounted
## Inner-loop roof regression. Keep this limited to direct geometry callers;
## programme, furnishing and circulation belong to their family suites.


static func run() -> SuiteResult:
	var result := SuiteResult.new("roof quick")
	var suites: Array[SuiteResult] = [
		preload("res://tests/suites/house_roof_suite.gd").run(),
		preload("res://tests/suites/castle_temple_roof_suite.gd").run(),
		PropKitSuite.run(),
		preload("res://tests/suites/hotel_roof_smoke_suite.gd").run(),
	]
	for suite in suites:
		result.checked += suite.checked
		for failure in suite.failures:
			result.fail("%s: %s" % [suite.suite_name, failure])
		for warning in suite.warnings:
			result.warn("%s: %s" % [suite.suite_name, warning])
		for note in suite.notes:
			result.note("%s: %s" % [suite.suite_name, note])
	return result
