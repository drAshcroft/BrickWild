extends SceneTree
## HILLS-STAIRS probe: the vstepswalk _case on the hillside form.
##   godot --headless --path . --script res://tools/probe_hills_walk.gd -- manarola masouleh rocamadour
const S := preload("res://tests/suites/village_steps_walk_suite.gd")
const VTP := preload("res://tests/suites/village_terrain_plan_suite.gd")


func _init() -> void:
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(VillageProgrammer.programme(VTP.spec_for(&"street", null)))
	for name in OS.get_cmdline_user_args():
		var res := SuiteResult.new("probe")
		var t0 := Time.get_ticks_msec()
		S._case(res, jobs, "real30/" + name, &"hillside")
		print("== %s: %d checks, %d failures (%.0f s)" % [name, res.checked, res.failures.size(), (Time.get_ticks_msec() - t0) / 1000.0])
		for f in res.failures:
			print("  FAIL ", f)
		for n in res.notes:
			print("  note ", n)
	quit()
