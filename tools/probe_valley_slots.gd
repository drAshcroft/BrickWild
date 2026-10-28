extends SceneTree
## Probe (VTER-USHGULI-ELONGATION, VTER-VALLEY-THIN): for each household of a valley
## plan, the slot the valley form gave it and where its lot was cut.
##   godot --headless --path . --script res://tools/probe_valley_slots.gd -- world90/balan
const S := preload("res://tests/suites/village_valley_suite.gd")


func _init() -> void:
	var name: String = OS.get_cmdline_user_args()[0]
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(VillageProgrammer.programme(S.spec_for(null)))
	var spec := S.spec_for(S.terrain(name))
	if OS.get_environment("NO_NET") != "":
		VillageLotPlanner._StreetNet.enabled = false
	var plan := VillageLotPlanner.plan_measured(spec, jobs)
	print("placed ", plan.buildings.size(), "/", jobs.size(), " site ", plan.site, " form ", plan.spec.form)
	var copy: Array[Dictionary] = []
	for j in jobs:
		copy.append(j.duplicate())
	VillageValleyForm.assign_jobs(plan, copy)
	var taken := {}
	var through: PackedVector2Array = plan.roads[0]["points"]
	for j in copy:
		if not j.has("near_point"):
			continue
		var np: Vector2 = j["near_point"]
		var b: Variant = null
		for k in range(plan.buildings.size()):
			var cand: Dictionary = plan.buildings[k]
			if not taken.has(k) and cand["placement"] == j["placement"]:
				taken[k] = true
				b = cand
				break
		var where := "UNPLACED"
		var off := -1.0
		if b != null:
			var c: Vector2 = VillageMeasure.centre(VillageMeasure.footprint_poly(b))
			off = c.distance_to(np)
			var lot: Dictionary = plan.lots[int(b["lot"])]
			where = "centre (%.0f,%.0f) road %d" % [c.x, c.y, int(lot["road"])]
		print("slot (%.0f,%.0f) %s/%s -> %s  moved %.0f m" % [np.x, np.y, j["request"].kind, j["request"].purpose, where, off])
	var sh := VillageShape.measure(plan)
	print("SHAPE elong ", sh.get("elongation"), " body ", sh.get("body_buildings"), " dead ", sh.get("dead_end_ratio"))
	var a := VillageSiteAnalysis.of(plan.ground, plan.site, 10.0)
	var x := plan.site.position.x + 10.0
	while x < plan.site.end.x:
		var y := VillageLotPlanner._polyline_y_at_x(through, x)
		var row := "x %5.0f road y %5.1f |" % [x, y]
		for dy in [-30.0, -20.0, -11.0, 11.0, 20.0, 30.0]:
			var q := Vector2(x, y + dy)
			row += " %+.0f:%.2f%s" % [dy, a.slope_at(q), "w" if a.wet_at(q) else " "]
		print(row)
		x += 20.0
	quit()
