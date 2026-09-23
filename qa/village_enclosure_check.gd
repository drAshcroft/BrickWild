class_name VillageEnclosureCheck
extends RefCounted
## Contract checks for the pure VIL-018 enclosure/water derivation.

static func check(plan: VillagePlan, derived: Dictionary) -> Dictionary:
	var failures: Array[String] = []
	var edge: PackedVector2Array = derived["edge"]
	if edge.size() < 3:
		failures.append("enclosure: missing offset hull")
	failures.append_array(gate_faults(plan, edge, derived["gates"]))
	for c in derived["crossings"]:
		if c["water_kind"] == &"river" and c["kind"] != &"bridge":
			failures.append("crossings: river crossing is not a bridge")
		if c["water_kind"] == &"stream" and c["kind"] != &"ford":
			failures.append("crossings: stream crossing is not a ford")
	for f in derived["fields"]:
		if VillageEnclosurePlan._overlap_area(f["poly"], edge) > 0.01:
			failures.append("fields: field lies inside enclosure")
	return {"ok": failures.is_empty(), "failures": failures,
		"stats": {"gates": derived["gates"].size(), "crossings": derived["crossings"].size(),
			"edge_vertices": edge.size()}}

## Independent geometry: deliberately does not call the planner's crossing
## finder, so an omitted second hit or a projected near-miss cannot self-pass.
static func gate_faults(plan: VillagePlan, edge: PackedVector2Array, gates: Array) -> Array[String]:
	var faults: Array[String] = []
	for r in plan.roads.size():
		var pts: PackedVector2Array = plan.roads[r]["points"]
		for i in range(pts.size() - 1):
			for k in edge.size():
				var hit = Geometry2D.segment_intersects_segment(pts[i], pts[i + 1], edge[k], edge[(k + 1) % edge.size()])
				if hit == null:
					continue
				if not gates.any(func(g): return int(g["road"]) == r and Vector2(g["pos"]).distance_to(hit) <= 0.05):
					faults.append("gates: road %d crosses enclosure at %v without an entrance" % [r, hit])
	for g in gates:
		var pos: Vector2 = g["pos"]
		var road := int(g["road"])
		if VillageMeasure.point_to_poly(pos, edge) > 0.05:
			faults.append("gates: entrance at %v is not on enclosure boundary" % pos)
		if road < 0 or road >= plan.roads.size():
			faults.append("gates: entrance has stale road index %d" % road)
			continue
		var row := plan.roads[road]
		if VillageMeasure.point_to_polyline(pos, row["points"]) > 0.05:
			faults.append("gates: entrance at %v is not on its road" % pos)
		if float(g.get("width", 0.0)) < float(row["width"]):
			faults.append("gates: entrance at %v is narrower than its road" % pos)
		var wanted: StringName = &"gate" if row["class"] == &"through" else &"postern"
		if g.get("kind", &"") != wanted:
			faults.append("gates: entrance at %v should be a %s" % [pos, wanted])
	return faults
