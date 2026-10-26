extends SceneTree
## Probe: plan one valley-deriving real fixture and print the common's fronting (VTER-VALLEY-REAL).
##   godot --headless --path . --script res://tools/probe_valley_real.gd -- real30/ushguli
const S := preload("res://tests/suites/village_valley_suite.gd")

func _init() -> void:
	var name: String = OS.get_cmdline_user_args()[0]
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(VillageProgrammer.programme(S.spec_for(null)))
	var spec := S.spec_for(S.terrain(name))
	var t0 := Time.get_ticks_msec()
	var plan := VillageLotPlanner.plan_measured(spec, jobs)
	print("plan ", (Time.get_ticks_msec() - t0) / 1000.0, " s, ", plan.buildings.size(), "/", jobs.size(), " placed, site ", plan.site)
	var pc := VillagePlaceCheck.new().check(plan)
	print("place ok=%s fail=%s stats.common_fronted=%s" % [pc["ok"], pc["failures"], pc["stats"].get("common_fronted")])
	var common := VillageMeasure.common_poly(plan)
	print("common ", common)
	for b in plan.buildings:
		var li := int(b["lot"])
		var f: PackedVector2Array = plan.lots[li]["front"] if li >= 0 else PackedVector2Array()
		var c: Vector2 = VillageMeasure.centre(VillageMeasure.bounds_poly(b))
		print("  ", b.get("kind", "?"), " lot ", li, " centre ", c, " front ", f)
	var sh := VillageShape.measure(plan)
	print("elong ", sh.get("elongation"), " body ", sh.get("body_buildings"), " nn ", sh.get("nn_median_m"))
	if OS.get_cmdline_user_args().size() > 1:
		var a := VillageSiteAnalysis.of(plan.ground, plan.site, 10.0)
		var th: PackedVector2Array = plan.roads[0]["points"]
		var x := plan.site.position.x + 10.0
		while x < plan.site.end.x:
			var y := VillageLotPlanner._polyline_y_at_x(th, x)
			var row := "x %6.0f road y %6.1f |" % [x, y]
			for dy in [-30.0, -20.0, -12.0, 12.0, 20.0, 30.0, 40.0]:
				var q := Vector2(x, y + dy)
				row += " %+.0f:%s%s" % [dy, "%.2f" % a.slope_at(q), "w" if a.wet_at(q) else " "]
			print(row)
			x += 10.0
	for r in plan.roads:
		var pp: PackedVector2Array = r["points"]
		print(r["class"], " ", pp[0], " -> ", pp[pp.size() - 1], " mid ", pp[pp.size() / 2])
	quit()
