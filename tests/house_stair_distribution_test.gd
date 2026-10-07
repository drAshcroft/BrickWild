extends SceneTree
## The existing multistory programme distribution without furniture search.
## Report actual stair feasibility and wall placement per style before the
## more expensive assembled-body fixture and routine planning lane.

func _init() -> void:
	var started := Time.get_ticks_msec()
	var stats := {}
	var failures := 0
	var styles: Array = HouseSweep.styles()
	for n in range(200):
		var spec := HouseSpec.new(41000 + n)
		spec.style = styles[n % styles.size()]
		spec.width = 9.0 + float(n % 5) * 1.5
		spec.length = 10.0 + float(n % 7) * 1.6
		spec.height = 2.6
		spec.storeys = 2
		var inner := HouseGeometry.interior_rect(spec)
		spec.room_count = HouseSpec.rooms_for(inner.size.x * inner.size.y)
		for kind in HouseSpec.PROGRAM:
			spec.program.append(kind)
		spec.back_door = n % 3 == 0
		spec.chimney = true
		var plan := HousePlanner.plan(spec)
		var key := String(spec.style)
		if not stats.has(key):
			stats[key] = {"cases": 0, "legacy_stairs": 0, "domestic_stairs": 0,
				"layout_fallback": 0, "infeasible": 0, "off_wall": 0, "other_plan_failures": 0}
		stats[key]["cases"] += 1
		if HouseSpec.STYLES[spec.style].has("domestic_program") \
				and plan.domestic_layout.get("status", &"") != &"planned":
			stats[key]["layout_fallback"] += 1
			print("LAYOUT_FALLBACK seed=", spec.seed, " style=", key, " reason=", plan.domestic_layout.get("reason", ""))
		for stair in plan.stairs:
			var profile := "domestic_stairs" if bool(stair.get("domestic_profile", false)) else "legacy_stairs"
			stats[key][profile] += 1
			if not bool(stair.get("satisfied", true)):
				stats[key]["infeasible"] += 1
				failures += 1
				print("INFEASIBLE seed=", spec.seed, " style=", key, " reason=", stair.get("reason", ""))
			elif HousePlanCheck.stair_wall_gap(plan, stair) > HousePlanCheck.STAIR_WALL_TOL:
				stats[key]["off_wall"] += 1
				failures += 1
				print("OFF_WALL seed=", spec.seed, " style=", key)
		var report := HousePlanCheck.new().check(plan)
		for failure in report["failures"]:
			if not String(failure).begins_with("stair_line:"):
				stats[key]["other_plan_failures"] += 1
				failures += 1
		if n % 25 == 24:
			print("DISTRIBUTION ", n + 1, "/200")
	print(JSON.stringify(stats))
	print("stair distribution: ", failures, " failures, ", (Time.get_ticks_msec() - started) / 1000.0, " seconds")
	quit(1 if failures > 0 else 0)
