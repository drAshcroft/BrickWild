extends SceneTree
## HILLS-GENERAL probe: the hillside form on one or more grounds, planned as the
## vhillside suite plans it, with its measures and VillageQA's faults.
##   godot --headless --path . --script res://tools/hills_probe.gd -- plan manarola masouleh ...
## `plane` is the synthetic 30 % plane; any other name is a tests/fixtures/terrain/real30 file.
const H := preload("res://tests/suites/village_hillside_suite.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var jobs: Array[Dictionary] = []
	for name in args.slice(1):
		var ground: VillageTerrain
		if name == "plane":
			ground = preload("res://tests/fixtures/terrain/synthetic_terrain.gd").make("plane_30")
		else:
			ground = VillageTerrain.from_file("res://tests/fixtures/terrain/real30/%s.json" % name)
		var spec: VillageSpec = H._spec(ground)
		if jobs.is_empty():
			jobs = VillageLotPlanner.measure_all(VillageProgrammer.programme(H._spec(null)))
		var t0 := Time.get_ticks_msec()
		var plan := VillageLotPlanner.plan_measured(spec, jobs)
		var m := VillageShape.measure(plan)
		print("%s: contour %s span %s elong %s steps %s houses %d/%d bld %d site %s (%.0f s)" % [name,
			str(m.get("street_contour_share")), str(m.get("elev_span_m")), str(m.get("elongation")),
			str(m.get("steps_ways")), plan.buildings_of_kind(&"house").size(), spec.households,
			plan.buildings.size(), str(plan.site), (Time.get_ticks_msec() - t0) / 1000.0])
		print("  roads: ", VillageRoadCheck.new().check(plan)["failures"])
		var qa := VillageQA.new().check(plan, {&"pure": func(_p): return []}, false)
		print("  qa: ", qa["failures"])
		print("  through stepped: ", plan.roads[0].get("stepped", false), " shallow: ", plan.roads[0].get("shallow", false))
	quit()
