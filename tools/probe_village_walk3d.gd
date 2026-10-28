extends SceneTree
## VTER-VISUAL: the vstepswalk case run on any real30 ground, to see what the
## 3D village walk says there. The suite's CASES lists only Manarola and
## Positano; this is a probe, not a gate (Monpazier has no stair street, so its
## "no stair street was built" line is the expected one).
##
##   godot --headless --path . --script res://tools/probe_village_walk3d.gd -- real30/hallstatt green

const S := preload("res://tests/suites/village_steps_walk_suite.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var res := SuiteResult.new("probe_walk3d")
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(
		VillageProgrammer.programme(S.VTP.spec_for(&"street", null)))
	for k in range(0, args.size() - 1, 2):
		S._case(res, jobs, args[k], StringName(args[k + 1]))
	print("PROBE checked=", res.checked, " failures=", res.failures.size())
	for f in res.failures:
		print("PROBE FAIL ", f)
	for w in res.warnings:
		print("PROBE WARN ", w)
	for n in res.notes:
		print("PROBE NOTE ", n)
	quit()
