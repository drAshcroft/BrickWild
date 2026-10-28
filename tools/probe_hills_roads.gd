extends SceneTree
## HILLS-STAIRS probe: every road of the hillside plan with its class, grade and shallowest tread.
##   godot --headless --path . --script res://tools/probe_hills_roads.gd -- manarola
class HillsideProbe:
	static func dist(p: Vector2, line: PackedVector2Array) -> float:
		return VillageHillsideForm._dist_to_line(p, line)

const VTP := preload("res://tests/suites/village_terrain_plan_suite.gd")
const VALLEY := preload("res://tests/suites/village_valley_suite.gd")


func _init() -> void:
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(VillageProgrammer.programme(VTP.spec_for(&"street", null)))
	for name in OS.get_cmdline_user_args():
		var plan := VillageLotPlanner.plan_measured(VTP.spec_for(&"hillside", VALLEY.terrain(("world90/" if name == "rocamadour" else "real30/") + name)), jobs)
		print("== %s" % name)
		for i in plan.roads.size():
			var r: Dictionary = plan.roads[i]
			var bed: Dictionary = VillageGroundSurface.of(plan).road_bed(i)
			var go := INF
			var ts: Array = bed.get("treads", [])
			for k in range(1, ts.size() - 1):
				go = minf(go, float(ts[k]["s1"]) - float(ts[k]["s0"]))
			var pts: PackedVector2Array = r["points"]
			if OS.get_environment("SHORT") != "" and i in [5, 6]:
				var sv: PackedFloat32Array = bed["s"]
				for k in range(1, ts.size() - 1):
					if float(ts[k]["s1"]) - float(ts[k]["s0"]) < 0.3:
						print("   short road%d tread %d s %.1f..%.1f going %.2f" % [i, k, float(ts[k]["s0"]), float(ts[k]["s1"]), float(ts[k]["s1"]) - float(ts[k]["s0"])])
				var acc := 0.0
				for q in range(pts.size() - 1):
					acc += pts[q].distance_to(pts[q + 1])
					if q % 3 == 0 or q == pts.size() - 2:
						print("   pt %d s %.1f %s" % [q + 1, acc, str(pts[q + 1].snapped(Vector2(0.1, 0.1)))])
			print("road%d %s%s%s len %.0f grade %.3f from %s to %s treads %d going_min %.2f" % [i, String(r["class"]),
				" terrace" if r.has("terrace") else "", " stepped" if r.get("stepped", false) else "",
				float(bed["s"][bed["s"].size() - 1]) if bed.has("s") else 0.0, VillageRoadRouter.grade_of(plan.ground, pts),
				str(pts[0].snapped(Vector2(0.1, 0.1))), str(pts[pts.size() - 1].snapped(Vector2(0.1, 0.1))), ts.size(), go])
	quit()
