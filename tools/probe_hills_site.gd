extends SceneTree
## HILLS-STAIRS probe: the hillside SITE plan alone (no lots), every riser with its hops and
## their stair goings, as VillageGroundSurface would lay them.
##   godot --headless --path . --script res://tools/probe_hills_site.gd -- manarola masouleh
const VTP := preload("res://tests/suites/village_terrain_plan_suite.gd")


func _init() -> void:
	for name in OS.get_cmdline_user_args():
		var spec := VTP.spec_for(&"hillside", VTP.terrain("real30/" + name))
		var plan := VillageSitePlanner.plan(spec)
		print("== %s site %s" % [name, plan.site])
		for i in plan.roads.size():
			var r: Dictionary = plan.roads[i]
			var pts: PackedVector2Array = r["points"]
			if r["class"] not in [&"steps", &"street"] or r.has("terrace"):
				continue
			var bed: Dictionary = VillageGroundSurface.of(plan).road_bed(i) if plan.ground != null else {}
			var go := INF
			var ts: Array = bed.get("treads", [])
			for k in range(1, ts.size() - 1):
				go = minf(go, float(ts[k]["s1"]) - float(ts[k]["s0"]))
			if OS.get_environment("PROFILE") != "" and bed.has("stations") and i == int(OS.get_environment("PROFILE")):
				var st: PackedVector2Array = bed["stations"]
				var sv: PackedFloat32Array = bed["s"]
				var hv: PackedFloat32Array = bed["h"]
				for q in range(st.size()):
					if float(sv[q]) > 30.0:
						break
					print("     s %.1f at %s raw %.2f bed %.2f" % [sv[q], str(st[q].snapped(Vector2(0.1, 0.1))), plan.ground.height_at(st[q]), hv[q]])
			if OS.get_environment("PROFILE") != "" and i == int(OS.get_environment("PROFILE")):
				var thr: PackedVector2Array = plan.roads[0]["points"]
				print("     model bed at start: smooth %.2f treads %.2f; real through bed %.2f; raw %.2f" % [
					VillageHillsideForm._line_bed(plan.ground, thr, pts[0]), VillageHillsideForm._line_bed(plan.ground, thr, pts[0], true),
					VillageGroundSurface.of(plan).bed_at(0, pts[0]), plan.ground.height_at(pts[0])])
			if OS.get_environment("PROFILE") != "" and i == int(OS.get_environment("PROFILE")):
				for j in range(plan.roads.size()):
					if j == i:
						continue
					var rib := VillageSitePlanner.road_ribbon(plan.roads[j], true)
					var cnt := 0
					for q in range(0, 7):
						var pq: Vector2 = pts[0].lerp(pts[1], float(q) / 12.0)
						if Geometry2D.is_point_in_polygon(pq, rib):
							cnt += 1
					if cnt > 0:
						print("     start stations in ribbon of road%d (%s) x%d, its bed there %.2f" % [j, plan.roads[j]["class"], cnt, VillageGroundSurface.of(plan).bed_at(j, pts[0])])
			var acc := 0.0
			var marks := ""
			for q in range(pts.size() - 1):
				acc += pts[q].distance_to(pts[q + 1])
				marks += " hop_end@%.1f" % acc
			var shorts := ""
			for k in range(1, ts.size() - 1):
				if float(ts[k]["s1"]) - float(ts[k]["s0"]) < 0.3:
					shorts += " [%.1f..%.1f=%.2f]" % [float(ts[k]["s0"]), float(ts[k]["s1"]), float(ts[k]["s1"]) - float(ts[k]["s0"])]
			print("   hops%s short treads%s" % [marks, shorts])
			print("road%d %s pts %d grade %.3f going_min %.2f  %s" % [i, r["class"], pts.size(),
				VillageRoadRouter.grade_of(plan.ground, pts), go, str(pts)])
	quit()
