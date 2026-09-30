extends SceneTree
## Stable entry point for the test suites. Install the script-error logger
## before loading the implementation and its many suite dependencies.

class ScriptErrorCapture extends Logger:
	var _mutex := Mutex.new()
	var _errors: Array[String] = []

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_SCRIPT:
			return
		_mutex.lock()
		_errors.append("%s:%d %s %s" % [file, line, code, rationale])
		_mutex.unlock()

	func script_errors() -> Array[String]:
		_mutex.lock()
		var copy := _errors.duplicate()
		_mutex.unlock()
		return copy


var _script_errors := ScriptErrorCapture.new()


func _init() -> void:
	OS.add_logger(_script_errors)
	var script := load("res://tests/run_all_impl.gd") as GDScript
	if script == null or not script.can_instantiate() \
			or not _script_errors.script_errors().is_empty():
		_report_bootstrap_failure("suite runner could not compile")
		quit(1)
		return
	var result: Variant = script.new().execute(_script_errors)
	if result is int and (result != 0 or _script_errors.script_errors().is_empty()):
		quit(result)
		return
	_report_bootstrap_failure("suite runner stopped before a complete verdict")
	quit(1)


func _report_bootstrap_failure(reason: String) -> void:
	printerr("RUNNER FAILED: " + reason)
	var errors := _script_errors.script_errors()
	for message in errors.slice(0, 5):
		printerr("  SCRIPT " + message)
	if errors.size() > 5:
		printerr("  ... %d more script errors" % (errors.size() - 5))
