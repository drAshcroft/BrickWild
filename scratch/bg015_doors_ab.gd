extends SceneTree
## BG-015 scratch: the doors the 3D walk reaches (VillageWalk._add_3d's own
## rule) baked off the built outlines and off `footprint`, per fixture.
## args: fixture:form ... (default: plane_30:street real30/masouleh:street)
const LANE := preload("res://tests/suites/village_terrain_lane_suite.gd")

func _init() -> void:
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(
		VillageProgrammer.programme(LANE.spec_for(&"street", null)))
	var cases: Array = OS.get_cmdline_user_args()
	if cases.is_empty():
		cases = ["plane_30:street", "real30/masouleh:street"]
	for c in cases:
		var parts := String(c).split(":")
		var plan := VillageLotPlanner.plan_measured(LANE.spec_for(StringName(parts[1]), LANE.terrain(parts[0])), jobs)
		var proj: Dictionary = VillageWalk.projection(plan, "x")
		var surface := VillageGroundSurface.of(plan)
		for mode in [{}, {"footprints": true}]:
			var m3: Dictionary = VillageWalk3D.bake(plan, mode)
			var isl: PackedInt32Array = VillageWalk3D.islands(m3)
			var gates := {}
			for g in proj["gates"]:
				var at := Vector2(float(g["nav_m"][0]), float(g["nav_m"][1]))
				var gc := VillageWalk3D.closest(m3, Vector3(at.x, surface.ground_at(at), at.y))
				if int(gc["polygon"]) >= 0:
					gates[isl[int(gc["polygon"])]] = true
			var lost: Array[String] = []
			for i in proj["doors"].size():
				var d: Dictionary = proj["doors"][i]
				var target := Vector3.INF
				var flight: Dictionary = VillageWalk._entry_flight(plan, plan.buildings[i])
				if not flight.is_empty():
					target = flight["route"][0]
				elif d["outside_m"] != null:
					var o := Vector2(float(d["outside_m"][0]), float(d["outside_m"][1]))
					target = Vector3(o.x, surface.ground_at(o), o.y)
				var ok := false
				var why := "no target"
				if target.is_finite():
					var cl := VillageWalk3D.closest(m3, target)
					var off: float = (cl["point"] as Vector3).distance_to(target) if int(cl["polygon"]) >= 0 else INF
					ok = int(cl["polygon"]) >= 0 and gates.has(isl[int(cl["polygon"])]) and off <= VillageWalk.DOOR_SNAP_3D
					why = "%.2f m off, island %s" % [off, "gate" if int(cl["polygon"]) >= 0 and gates.has(isl[int(cl["polygon"])]) else "other"]
				if not ok:
					var b: Dictionary = plan.buildings[i]
					var gf: Dictionary = plan.lots[int(b["lot"])].get("ground_fit", {})
					lost.append("b-%03d %s (%s; flights %d, access %s)" % [i, String((b["request"] as BuildingRequest).kind), why,
						(gf.get("entry_flights", []) as Array).size(), gf.get("access", {}).get("layout", "-")])
			print("%-18s %-10s doors reached %d/%d; gap links %d; lost: %s" % [parts[0], "footprints" if not mode.is_empty() else "built",
				proj["doors"].size() - lost.size(), proj["doors"].size(), int(m3["stats"]["gap_links"]), ", ".join(lost)])
	quit()
