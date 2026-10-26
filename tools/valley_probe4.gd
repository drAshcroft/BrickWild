extends SceneTree
## The same 60-person farming village on one fixture, planned as each of the
## given forms: placed counts and shape.
##   godot --headless --path . --script res://tools/valley_probe4.gd -- world90/balan street valley green

const SUITE := preload("res://tests/suites/village_valley_suite.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var name: String = args[0]
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(VillageProgrammer.programme(SUITE.spec_for(null)))
	for i in range(1, args.size()):
		var ground: VillageTerrain = SUITE.terrain(name)
		var spec: VillageSpec = SUITE.spec_for(ground, StringName(args[i]))
		var t0 := Time.get_ticks_msec()
		var plan := VillageLotPlanner.plan_measured(spec, jobs)
		var shape := VillageShape.measure(plan)
		print("%-8s site %.0fx%.0f placed %d/%d elong %s dead %s (%.1f s)" % [args[i], plan.site.size.x, plan.site.size.y,
			plan.buildings.size(), jobs.size(), shape.get("elongation"), shape.get("dead_end_ratio"), (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)
