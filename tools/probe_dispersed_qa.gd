extends SceneTree
## Probe: plan + VillageQA of the dispersed cases with a small programme (VTER-DISPERSED-2).
const S := preload("res://tests/suites/village_dispersed_suite.gd")

func _init() -> void:
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(VillageProgrammer.programme(S.spec_for(null)))
	for c in S.CASES:
		if OS.get_cmdline_user_args().size() > 0 and not String(c[0]).contains(OS.get_cmdline_user_args()[0]):
			continue
		var spec := S.spec_for(S.terrain(c[0]), c[1])
		var plan := VillageLotPlanner.plan_measured(spec, jobs)
		var no_pure := func(_p: VillagePlan) -> Array: return []
		var qa: Dictionary = VillageQA.new().check(plan, {&"pure": no_pure}, false)
		print("%s ok=%s %s" % [c[0], qa["ok"], "; ".join(qa["failures"])])
		if not qa["ok"]:
			for r in range(plan.roads.size()):
				var pts: PackedVector2Array = plan.roads[r]["points"]
				print("  road %d %s n=%d %v -> %v" % [r, plan.roads[r]["class"], pts.size(), pts[0], pts[pts.size() - 1]])
			for j in VillageSitePlanner.junctions(plan):
				print("  junction %v" % j["pos"])
	quit()
