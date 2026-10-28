extends SceneTree
## VTER-ISLAND-DENSE probe: the islet planned as vislandfill plans it, its
## survey measures beside the real Isola's (cu_isola_dei_pescatori).
##   godot --headless --path . --script res://tools/probe_island_shape.gd
const S := preload("res://tests/suites/village_island_suite.gd")
const SYNTH := preload("res://tests/fixtures/terrain/synthetic_terrain.gd")


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(VillageProgrammer.programme(S.spec_for(null)))
	print("measured %d in %.0f s" % [jobs.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	t0 = Time.get_ticks_msec()
	var plan := VillageLotPlanner.plan_measured(S.spec_for(SYNTH.make("islet")), jobs)
	print("planned in %.0f s, %d/%d placed" % [(Time.get_ticks_msec() - t0) / 1000.0, plan.buildings.size(), jobs.size()])
	var m := VillageShape.measure(plan)
	for k in ["setback_median_m", "compactness", "elongation", "coverage", "water_within_30m", "body_hull_ha", "nn_median_m"]:
		print("  %s %s" % [k, str(m.get(k))])
	var ir: Dictionary = VillageIslandCheck.new().check(plan)
	print("  island check ", ir["ok"], " ", ir["failures"], " ", ir["stats"])
	var rc := VillageRoadCheck.new()
	print("  roads ", rc.check(plan)["failures"])
	var qa := VillageQA.new().check(plan, {&"pure": func(_p): return []}, false)
	print("  qa ", qa["failures"])
	if OS.get_environment("ROADS") != "":
		for i in plan.roads.size():
			var r: Dictionary = plan.roads[i]
			var pts: PackedVector2Array = r["points"]
			print("  road%d %s pts %d w %.1f from %s to %s" % [i, String(r["class"]), pts.size(), float(r["width"]), str(pts[0].snapped(Vector2(1, 1))), str(pts[pts.size() - 1].snapped(Vector2(1, 1)))])
	if OS.get_environment("PER") != "":
		for bi in plan.buildings.size():
			var b: Dictionary = plan.buildings[bi]
			var lot: Dictionary = plan.lots[int(b["lot"])]
			var r: Dictionary = plan.roads[int(lot["road"])]
			print("  b%d %s road%d %s lot setback %.2f depth %.1f frontw %.1f at %s" % [bi, String(b["kind"]), int(lot["road"]), String(r["class"]),
				float(lot["setback"]), float(lot.get("depth", 0.0)), (lot["front"][0] as Vector2).distance_to(lot["front"][1]), str((b["transform"] as Transform3D).origin.snapped(Vector3(1, 1, 1)))])
	if OS.get_environment("DUMP") != "":
		print(rc.ascii_map(3.0))
	quit()
