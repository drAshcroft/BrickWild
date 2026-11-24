extends SceneTree
## BG-015 scratch: where the baked 3D walk comes nearest what a building
## built, on the terrain lane's Manarola, and what that geometry is.
const LANE := preload("res://tests/suites/village_terrain_lane_suite.gd")
const CLEARANCE := preload("res://qa/village_walk_clearance.gd")

func _init() -> void:
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(
		VillageProgrammer.programme(LANE.spec_for(&"street", null)))
	var args := OS.get_cmdline_user_args()
	var fixture: String = args[0] if args.size() > 0 else "real30/manarola"
	var form := StringName(args[1]) if args.size() > 1 else &"crossroads"
	var plan := VillageLotPlanner.plan_measured(LANE.spec_for(form, LANE.terrain(fixture)), jobs)
	var t0 := Time.get_ticks_msec()
	var m3: Dictionary = VillageWalk3D.bake(plan)
	print("bake %.1f s stats %s" % [(Time.get_ticks_msec() - t0) / 1000.0, m3["stats"]])
	var built: Array = CLEARANCE.built(plan, jobs)
	for i in built.size():
		var b: Dictionary = plan.buildings[i]
		var req: BuildingRequest = b["request"]
		print("b-%03d %s %s %.2fx%.2f fall %.2f skipped '%s' plinth %.2f flights %d" % [i, req.kind, req.style, req.width, req.length,
			req.ground_fall_m, built[i]["skipped"], float(built[i].get("plinth_m", 0.0)), (built[i]["flights"] as Array).size()])
	var r: Dictionary = CLEARANCE.measure(m3, built, VillageWalk3D.gap_clear(), VillageWalk3D.agent_radius() + VillageWalk3D.CELL)
	print("edges %d links %d worst %.3f" % [r["edges"], r["links"], r["worst_m"]])
	for f in r["near"]:
		var bi: int = f["building"]
		var b: Dictionary = plan.buildings[bi]
		var req: BuildingRequest = b["request"]
		var inv: Transform3D = (b["transform"] as Transform3D).affine_inverse()
		var at: Vector2 = f["at"]
		var la: Vector3 = inv * Vector3(at.x, 0.0, at.y)
		var poly: PackedVector2Array = built[bi]["polys"][int(f["poly"])]
		var local := PackedVector2Array()
		for p in poly:
			var l: Vector3 = inv * Vector3(p.x, 0.0, p.y)
			local.append(Vector2(snappedf(l.x, 0.001), snappedf(l.z, 0.001)))
		var to_outline := INF
		for o in plan.lots[int(b["lot"])]["ground_fit"].get("built_outline", []):
			to_outline = minf(to_outline, VillageMeasure.point_to_poly(at, o))
		print("  %s | at local (%.3f, %.3f), half %.2f x %.2f | to built_outline %.3f | poly local %s" % [
			f["text"], la.x, la.z, req.width * 0.5, req.length * 0.5, to_outline, local])
	quit()
