extends SceneTree
## One or more cases of the vcrest suite, printed. godot --headless --path . --script res://tools/crest_probe.gd -- crest spur
func _init() -> void:
	var names: Array = Array(OS.get_cmdline_user_args())
	var res = preload("res://tests/suites/village_crest_suite.gd").run(names)
	print("checked %d, failures %d" % [res.checked, res.failures.size()])
	for f in res.failures:
		print("FAIL ", f)
	for n in res.notes:
		print("NOTE ", n)
	quit(0)
