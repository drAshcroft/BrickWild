class_name VillageEnclosureCheck
extends RefCounted
## Contract checks for the pure VIL-018 enclosure/water derivation.

static func check(plan: VillagePlan, derived: Dictionary) -> Dictionary:
	var failures: Array[String] = []
	var edge: PackedVector2Array = derived["edge"]
	if edge.size() < 3:
		failures.append("enclosure: missing offset hull")
	if derived["gates"].size() < _through_boundary_count(plan, edge):
		failures.append("gates: a through-road boundary crossing has no gate")
	for g in derived["gates"]:
		if VillageMeasure.point_to_poly(g["pos"], edge) > 0.5:
			failures.append("gates: gate is not on enclosure boundary")
	for c in derived["crossings"]:
		if c["water"] == &"river" and c["kind"] != &"bridge":
			failures.append("crossings: river crossing is not a bridge")
		if c["water"] == &"stream" and c["kind"] != &"ford":
			failures.append("crossings: stream crossing is not a ford")
	for f in derived["fields"]:
		if VillageEnclosurePlan._overlap_area(f["poly"], edge) > 0.01:
			failures.append("fields: field lies inside enclosure")
	return {"ok": failures.is_empty(), "failures": failures,
		"stats": {"gates": derived["gates"].size(), "crossings": derived["crossings"].size(),
			"edge_vertices": edge.size()}}

static func _through_boundary_count(plan: VillagePlan, edge: PackedVector2Array) -> int:
	var hits: Array[Vector2] = []
	for road in plan.roads:
		if road["class"] != &"through":
			continue
		var pts: PackedVector2Array = road["points"]
		for i in range(pts.size() - 1):
			var hit: Variant = VillageEnclosurePlan._boundary_hit(pts[i], pts[i + 1], edge)
			if hit != null:
				var p: Vector2 = hit
				var duplicate := false
				for prior in hits:
					if prior.distance_to(p) < VillageEnclosurePlan.GATE_HALF * 2.0:
						duplicate = true
						break
				if not duplicate:
					hits.append(p)
	return hits.size()
