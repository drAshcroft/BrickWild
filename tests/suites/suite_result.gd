class_name SuiteResult
extends RefCounted
## Uniform result object so the ordered runner can report every suite alike.

var suite_name: String
var checked := 0
var failures: Array[String] = []
var warnings: Array[String] = []
var notes: Array[String] = []

func _init(p_name: String) -> void:
	suite_name = p_name

func fail(msg: String) -> void:
	failures.append(msg)
	if OS.get_environment("BRICK_WILD_TEST_TRACE") == "1":
		print("failure: %s: %s" % [suite_name, msg])

func warn(msg: String) -> void:
	warnings.append(msg)

func note(msg: String) -> void:
	notes.append(msg)

func ok() -> bool:
	return failures.is_empty()

func summary() -> String:
	return "%-18s %s  (%d checked, %d failures, %d warnings)" % [
		suite_name, "PASS" if ok() else "FAIL", checked, failures.size(), warnings.size()]
