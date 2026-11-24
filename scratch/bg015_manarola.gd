extends SceneTree
## BG-015 scratch: the terrain lane's Manarola case alone (its walk and the
## new clearance rule), so an iteration is minutes, not the whole lane.
const LANE := preload("res://tests/suites/village_terrain_lane_suite.gd")

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(
		VillageProgrammer.programme(LANE.spec_for(&"street", null)))
	print("measured %d in %.1f s" % [jobs.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	var res := SuiteResult.new("bg015")
	var cases: Array = OS.get_cmdline_user_args() if not OS.get_cmdline_user_args().is_empty() else ["real30/manarola:crossroads"]
	for c in cases:
		var parts: PackedStringArray = String(c).split(":")
		LANE._case(res, jobs, parts[0], StringName(parts[1]), "bg015")
	for n in res.notes:
		print("NOTE ", n)
	for f in res.failures:
		print("FAIL ", f)
	print("checked %d failed %d in %.1f s" % [res.checked, res.failures.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	quit()
