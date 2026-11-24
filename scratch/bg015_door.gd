extends SceneTree
## BG-015 scratch: why a door on the lane's Manarola is not reached on the 3D
## walk after the built outlines (args: building index, default 5).
const LANE := preload("res://tests/suites/village_terrain_lane_suite.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var bi: int = int(args[0]) if args.size() > 0 else 5
	var fixture: String = args[1] if args.size() > 1 else "real30/manarola"
	var form := StringName(args[2]) if args.size() > 2 else &"crossroads"
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(
		VillageProgrammer.programme(LANE.spec_for(&"street", null)))
	var plan := VillageLotPlanner.plan_measured(LANE.spec_for(form, LANE.terrain(fixture)), jobs)
	var walk := VillageWalk.projection(plan, "lane")
	var m3 := LANE._mesh(walk["navmesh_3d"])
	var isl := VillageWalk3D.islands(m3)
	var count := {}
	for i in isl:
		count[i] = int(count.get(i, 0)) + 1
	var gate := LANE._v3(walk["gates"][0]["nav_3d_m"])
	var gc := VillageWalk3D.closest(m3, gate)
	print("gate island %d (%d polys)" % [isl[int(gc["polygon"])], count[isl[int(gc["polygon"])]]])
	var d: Dictionary = walk["doors"][bi]
	var b: Dictionary = plan.buildings[bi]
	var req: BuildingRequest = b["request"]
	print("door ", JSON.stringify(d))
	var gf: Dictionary = plan.lots[int(b["lot"])]["ground_fit"]
	var acc: Dictionary = gf.get("access", {})
	print("lot keys ", gf.keys(), " access ", acc.get("layout", "-"), " poly ", acc.get("poly", []), " origin ", acc.get("origin", "-"), " dir ", acc.get("dir", "-"), " width ", acc.get("width_m", "-"), " foot ", acc.get("foot_m", "-"))
	if acc.has("treads"):
		print("access treads ", acc["treads"])
	print("built outline ", gf.get("built_outline", []))
	print("request %s %.2fx%.2f fall %.2f xf %s" % [req.kind, req.width, req.length, req.ground_fall_m, b["transform"]])
	for f in gf.get("entry_flights", []):
		print("flight door %d route %s landing %s top %.3f treads %d" % [f["door"], f["route"], f["treads"][0]["poly"], float(f["treads"][0]["top"]), (f["treads"] as Array).size()])
	if d["outside_3d_m"] != null:
		var p := LANE._v3(d["outside_3d_m"])
		var c := VillageWalk3D.closest(m3, p)
		var pi: int = int(c["polygon"])
		print("outside_3d on polygon %d island %d (%d polys) poly %s" % [pi, isl[pi], count[isl[pi]],
			Array(m3["polygons"][pi]).map(func(k: int) -> Vector3: return m3["vertices"][k])])
	for link in walk["navmesh_3d"]["links"]:
		if String(link["building_id"]).ends_with("b-%03d" % bi) or String(link["kind"]) == "gap":
			var a := VillageWalk3D.closest(m3, LANE._v3(link["from_m"]))
			var z := VillageWalk3D.closest(m3, LANE._v3(link["to_m"]))
			print("link %s %s from %s (island %d, %.3f off) to %s (island %d, %.3f off)" % [link["kind"], link["building_id"], link["from_m"],
				isl[int(a["polygon"])], (a["point"] as Vector3).distance_to(LANE._v3(link["from_m"])), link["to_m"],
				isl[int(z["polygon"])], (z["point"] as Vector3).distance_to(LANE._v3(link["to_m"]))])
	# the polygons within 3 m of the door's 3D point, by island
	if d["outside_3d_m"] != null:
		var p := LANE._v3(d["outside_3d_m"])
		var near := {}
		for i in (m3["polygons"] as Array).size():
			var poly: PackedInt32Array = m3["polygons"][i]
			for k in poly:
				if Vector2(m3["vertices"][k].x, m3["vertices"][k].z).distance_to(Vector2(p.x, p.z)) < 3.0:
					near[isl[i]] = int(near.get(isl[i], 0)) + 1
					break
		print("islands within 3 m of the door: ", near)
	quit()
