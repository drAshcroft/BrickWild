extends SceneTree
## VTER-VISUAL-DOOR-ISLAND: where is the stranded door, and what is round it.
##   godot --headless --path . --script res://tools/probe_door_island.gd -- real30/manarola
const S := preload("res://tests/suites/village_steps_walk_suite.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(
		VillageProgrammer.programme(S.VTP.spec_for(&"street", null)))
	var plan := VillageLotPlanner.plan_measured(S.VTP.spec_for(&"green", S.VTP.terrain(args[0])), jobs)
	var walk := VillageWalk.projection(plan, "c")
	var m3 := S._mesh(walk["navmesh_3d"])
	var isl := VillageWalk3D.islands(m3)
	var gate_isl := {}
	for g in walk["gates"]:
		var c := VillageWalk3D.closest(m3, S._v3(g["nav_3d_m"]))
		gate_isl[isl[int(c["polygon"])]] = true
	var count := {}
	for i in isl:
		count[i] = int(count.get(i, 0)) + 1
	print("DIAG islands: ", count.size(), " sizes ", count.values().slice(0, 20), " gate islands ", gate_isl.keys())
	for i in walk["doors"].size():
		var d: Dictionary = walk["doors"][i]
		if d["outside_3d_m"] == null:
			print("DIAG ", d["building_id"], " no 3d point"); continue
		var p := S._v3(d["outside_3d_m"])
		var c := VillageWalk3D.closest(m3, p)
		if gate_isl.has(isl[int(c["polygon"])]) and bool(d["reachable_3d"]):
			continue
		var b: Dictionary = plan.buildings[i]
		var li: int = int(b.get("lot", -1))
		var gf: Dictionary = plan.lots[li].get("ground_fit", {}) if li >= 0 else {}
		print("DIAG stranded ", d["building_id"], " outside_m ", d["outside_m"], " out3d ", d["outside_3d_m"],
			" island ", isl[int(c["polygon"])], " (", count[isl[int(c["polygon"])]], " polys) reach ", d["reachable_3d"])
		print("DIAG   lot ", li, " entry_flights ", (gf.get("entry_flights", []) as Array).size(),
			" access ", gf.has("access"), " keys ", gf.keys())
		for f in gf.get("entry_flights", []):
			print("DIAG   flight route ", f["route"], " door ", f["door"], " landing ", f["treads"][0]["poly"], " top ", f["treads"][0]["top"], " ntreads ", f["treads"].size())
		for link in walk["navmesh_3d"]["links"]:
			if link["building_id"] != d["building_id"]:
				continue
			var lf := S._v3(link["from_m"])
			var lt := S._v3(link["to_m"])
			var ca := VillageWalk3D.closest(m3, lf)
			var cb := VillageWalk3D.closest(m3, lt)
			print("DIAG   link ", link["kind"], " door ", link["door"], " from ", lf, " island ", isl[int(ca["polygon"])],
				" snap ", snappedf((ca["point"] as Vector3).distance_to(lf), 0.01), " to ", lt, " island ",
				isl[int(cb["polygon"])], " snap ", snappedf((cb["point"] as Vector3).distance_to(lt), 0.01))
		if gf.has("access"):
			print("DIAG   access ", str(gf["access"]).left(300))
			if gf["access"].has("treads"):
				var ac: Dictionary = gf["access"]
				print("DIAG   access dir ", ac["dir"], " origin ", ac["origin"], " going ", ac["going_m"], " treads ", ac["treads"].size(), " heights ",
					ac["treads"].map(func(t): return snappedf(t["h"], 0.01)))
				var lt: Dictionary = ac["treads"][ac["treads"].size() - 1]
				var base: Vector2 = ac["origin"] + (ac["dir"] as Vector2) * (float(lt["d"]) - float(lt["len"]) * 0.5)
				for e in range(0, 12):
					var q2 := base + (ac["dir"] as Vector2) * (e * 0.3)
					var cq := VillageWalk3D.closest(m3, Vector3(q2.x, VillageGroundSurface.of(plan).ground_at(q2), q2.y))
					print("DIAG   head +", e * 0.3, " ground ", snappedf(VillageGroundSurface.of(plan).ground_at(q2), 0.01), " kind ", VillageGroundSurface.of(plan).kind_of(VillageGroundSurface.of(plan).region_at(q2)),
						" snap ", snappedf((cq["point"] as Vector3).distance_to(Vector3(q2.x, VillageGroundSurface.of(plan).ground_at(q2), q2.y)), 0.01), " island ", isl[int(cq["polygon"])])
		var o := Vector2(p.x, p.z)
		for ob in VillageWalk3D.wall_footprints(plan):
			var r := Rect2(ob[0], Vector2.ZERO)
			for q in ob:
				r = r.expand(q)
			if r.grow(2.0).has_point(o):
				print("DIAG   wall footprint ", ob)
		for ob in VillageWalk3D.obstacle_outlines(plan):
			var r2 := Rect2(ob[0], Vector2.ZERO)
			for q in ob:
				r2 = r2.expand(q)
			if r2.grow(0.6).has_point(o + Vector2(0, 1.0)) or r2.grow(0.6).has_point(o + Vector2(0, 0.5)):
				print("DIAG   obstacle ", r2)
		var bld := VillageBuilder.new()
		bld.build(plan)
		for row in bld.component_log:
			if String(row["role"]) in VillageWalk3D.WALL_ROLES and row["form"] == "slab":
				var pts: PackedVector3Array = row["points"]
				if Vector2(pts[0].x, pts[0].z).distance_to(o) < 3.0:
					print("DIAG   wallrow ", row["role"], " host ", row["host"], " ", pts[0], pts[1])
		var surf := VillageGroundSurface.of(plan)
		var sid: int = isl[int(c["polygon"])]
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for pi in (m3["polygons"] as Array).size():
			if isl[pi] != sid:
				continue
			for v in m3["polygons"][pi]:
				var vv: Vector3 = m3["vertices"][v]
				lo = Vector2(minf(lo.x, vv.x), minf(lo.y, vv.z))
				hi = Vector2(maxf(hi.x, vv.x), maxf(hi.y, vv.z))
		print("DIAG   island bbox ", lo, " .. ", hi)
		for k in range(0, 33):
			var q := Vector2(p.x, p.z - 1.0 + k * 0.5)
			var near_main := "-"
			for pi in (m3["polygons"] as Array).size():
				if not gate_isl.has(isl[pi]):
					continue
				var poly: PackedInt32Array = m3["polygons"][pi]
				for t in range(1, poly.size() - 1):
					var hh := VillageWalk3D._height_near(m3["vertices"][poly[0]], m3["vertices"][poly[t]], m3["vertices"][poly[t + 1]], q)
					if not is_nan(hh):
						near_main = "%.2f" % hh
			var own := "-"
			for pi in (m3["polygons"] as Array).size():
				if isl[pi] != sid:
					continue
				var poly: PackedInt32Array = m3["polygons"][pi]
				for t in range(1, poly.size() - 1):
					var hh := VillageWalk3D._height_near(m3["vertices"][poly[0]], m3["vertices"][poly[t]], m3["vertices"][poly[t + 1]], q)
					if not is_nan(hh):
						own = "%.2f" % hh
			print("DIAG   z ", q.y, " ground ", snappedf(surf.ground_at(q), 0.01), " kind ", surf.kind_of(surf.region_at(q)), " main ", near_main, " own ", own)
		# polygons within 6 m, by island
		var near := {}
		for pi in (m3["polygons"] as Array).size():
			var poly: PackedInt32Array = m3["polygons"][pi]
			var cc := Vector3.ZERO
			for v in poly:
				cc += m3["vertices"][v]
			cc /= poly.size()
			if Vector2(cc.x, cc.z).distance_to(o) < 6.0:
				near[isl[pi]] = near.get(isl[pi], []) + [snappedf(cc.y, 0.01)]
		for k in near:
			print("DIAG   near island ", k, " polys ", near[k].size(), " heights ", near[k].slice(0, 6))
	quit()
