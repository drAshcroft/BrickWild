extends SceneTree
## BG-015 scratch: the clearance rule on every terrain-lane fixture, the walk
## as baked now against the walk baked off `footprint` (as before), plus the
## doors the 3D walk reaches each way. Evidence for the report, not a gate.
const LANE := preload("res://tests/suites/village_terrain_lane_suite.gd")
const CLEARANCE := preload("res://qa/village_walk_clearance.gd")

func _init() -> void:
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(
		VillageProgrammer.programme(LANE.spec_for(&"street", null)))
	var clear := VillageWalk3D.gap_clear()
	var approach := VillageWalk3D.agent_radius() + VillageWalk3D.CELL
	for c in LANE.CASES:
		var plan := VillageLotPlanner.plan_measured(LANE.spec_for(c[1], LANE.terrain(c[0])), jobs)
		if plan.ground == null or plan.buildings.is_empty():
			print("%s: no plan" % c[0])
			continue
		var built: Array = CLEARANCE.built(plan, jobs)
		var line := "%-18s %2d buildings" % [c[0], plan.buildings.size()]
		for mode in [{}, {"footprints": true}]:
			var m3: Dictionary = VillageWalk3D.bake(plan, mode)
			var r: Dictionary = CLEARANCE.measure(m3, built, clear, approach)
			line += " | %s: nearest %.3f m, %d edges + %d gap links within %.3f m, %d gap links, %d polygons" % [
				"footprints" if not mode.is_empty() else "built", float(r["worst_m"]), int(r["edges"]), int(r["links"]),
				clear, int(m3["stats"]["gap_links"]), int(m3["stats"]["polygons"])]
		print(line)
		# the doors on the walk as now baked
		var projection: Dictionary = VillageWalk.projection(plan, "x")
		var reached := 0
		for d in projection["doors"]:
			reached += 1 if bool(d.get("reachable_3d", false)) else 0
		print("%-18s doors reachable_3d %d/%d" % [c[0], reached, projection["doors"].size()])
	quit()
