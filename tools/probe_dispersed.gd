extends SceneTree
## Probe: site plan only (no buildings) of the dispersed cases; prints hamlet
## spacing and each hamlet's link (VTER-DISPERSED-2).
const S := preload("res://tests/suites/village_dispersed_suite.gd")

func _init() -> void:
	for c in S.CASES:
		var ground := S.terrain(c[0])
		var spec := S.spec_for(ground, c[1])
		var plan := VillageSitePlanner.plan(spec)
		var seats: Array = []
		for h in plan.hamlets:
			seats.append(h["seat"])
		var nn := []
		for i in range(seats.size()):
			var best := INF
			for j in range(seats.size()):
				if i != j:
					best = minf(best, seats[i].distance_to(seats[j]))
			nn.append(snappedf(best, 0.1))
		print("%s site %v hamlets %d nn %s" % [c[0], plan.site.size, seats.size(), nn])
		for i in range(plan.hamlets.size()):
			var h: Dictionary = plan.hamlets[i]
			var r: int = VillageDispersedForm.spine_of(plan, i)
			if r < 0:
				print("  h%d main seat %v" % [i, h["seat"]])
				continue
			var road: Dictionary = plan.roads[r]
			var len := 0.0
			var pts: PackedVector2Array = road["points"]
			for k in range(pts.size() - 1):
				len += pts[k].distance_to(pts[k + 1])
			print("  h%d seat %v link %s len %.0f verts %d grade %.1f%%" % [i, h["seat"], road["class"], len, pts.size(),
				100.0 * VillageRoadRouter.grade_of(plan.ground, pts)])
	quit()
