class_name HallCheck
extends RefCounted
## HallCheck acceptance rules for WLD-008 timber halls.

static func check(spec: TimberHallSpec, builder: TimberHallBuilder) -> Dictionary:
	var failures: Array[String] = []
	var h := TimberHallGeometry.hall_rect(spec)
	var p := TimberHallGeometry.platform_rect(spec)
	var positions := {}
	for c0 in spec.columns:
		var p0: Vector3 = c0["pos"]
		positions["%.3f:%.3f" % [p0.x, p0.z]] = true
	var by_ring := {0: [], 1: []}
	for c0 in spec.columns:
		by_ring[int(c0["ring"])].append(c0)
	if spec.columns.size() < 8 or spec.columns.size() % 2 != 0:
		failures.append("bays: front column count must be even and at least four")
	for ring in [0, 1]:
		var ring_cols: Array = by_ring[ring]
		if ring_cols.size() < 8:
			failures.append("rings: ring %d is not a closed rectangle" % ring)
			continue
		var min_x := INF
		var max_x := -INF
		var min_z := INF
		var max_z := -INF
		for c1 in ring_cols:
			var rp: Vector3 = c1["pos"]
			min_x = minf(min_x, rp.x); max_x = maxf(max_x, rp.x)
			min_z = minf(min_z, rp.z); max_z = maxf(max_z, rp.z)
		for corner in [Vector2(min_x, min_z), Vector2(min_x, max_z), Vector2(max_x, min_z), Vector2(max_x, max_z)]:
			var found := false
			for c2 in ring_cols:
				var cp: Vector3 = c2["pos"]
				if Vector2(cp.x, cp.z).distance_to(corner) < 0.05:
					found = true
					break
			if not found:
				failures.append("rings: ring %d is missing a rectangle corner" % ring)
	# The front edge carries four mirrored columns; the central bay is widest.
	var front_x: Array[float] = []
	for c3 in spec.columns:
		var cp3: Vector3 = c3["pos"]
		if absf(cp3.z - h.position.y - 2.0) < 0.1 or absf(cp3.z - (h.end.y - 2.0)) < 0.1:
			if not front_x.has(cp3.x):
				front_x.append(cp3.x)
	front_x.sort()
	if front_x.size() < 4 or front_x.size() % 2 != 0:
		failures.append("bays: front edge needs an even four-column bay sequence")
	else:
		var gaps: Array[float] = []
		for i in range(front_x.size() - 1):
			gaps.append(front_x[i + 1] - front_x[i])
		if gaps[gaps.size() / 2] <= gaps[0] or gaps[gaps.size() / 2] <= gaps[-1]:
			failures.append("bays: central bay is not the widest")
	for c in spec.columns:
		var pos: Vector3 = c["pos"]
		var twin := positions.has("%.3f:%.3f" % [-pos.x, pos.z])
		if not twin:
			failures.append("rings: column at %s has no mirror twin" % pos)
		if absf(pos.x) < TimberHallGeometry.PATH_MIN:
			failures.append("clear: column intrudes on the processional axis")
	if p.size.x < h.size.x or p.size.y < h.size.y or spec.platform_h < 0.6:
		failures.append("plinth: platform is too small or low")
	var stair := TimberHallGeometry.front_stair_rect(spec)
	if absf(stair.get_center().x) > 0.05:
		failures.append("plinth: front stair is not centred")
	if spec.roof_overhang < spec.column_h * 0.25:
		failures.append("eaves: roof overhang is less than 0.25 column height")
	if spec.roof_rise < spec.column_h * 0.5:
		failures.append("roof: rise is less than 0.5 column height")
	var roof := builder.mass_aabb("roof")
	if roof.size.x < p.size.x or roof.size.z < p.size.y:
		failures.append("roof: footprint does not cover platform")
	var ip := TimberHallGeometry.image_center(spec)
	if absf(ip.x) > spec.width * 0.02 or ip.z < h.position.y + h.size.y * 0.55:
		failures.append("axis: image is not centred in the back third")
	var occupied := 0.0
	for c4 in spec.columns:
		occupied += PI * pow(float(c4["radius"]), 2.0)
	var standable := h.size.x * h.size.y - occupied - TimberHallGeometry.dais_rect(spec).size.x * TimberHallGeometry.dais_rect(spec).size.y
	if standable < h.size.x * h.size.y * 0.5:
		failures.append("clear: less than half the hall remains standable")
	var door := Vector2(0.0, h.position.y)
	var target := Vector2(ip.x, ip.z)
	for c5 in spec.columns:
		var cp5: Vector3 = c5["pos"]
		if _point_segment_distance(Vector2(cp5.x, cp5.z), door, target) < TimberHallGeometry.PATH_MIN:
			failures.append("axis: column blocks sightline from door to image")
			break
	var brackets := 0
	for part in builder.part_log:
		if part["kind"] == "bracket":
			brackets += 1
	if brackets < spec.columns.size():
		failures.append("brackets: every column needs a bracket set")
	if spec.wings:
		if spec.water.size.x <= h.size.x:
			failures.append("wings: water is not wider than the central hall")
		var water_platform := TimberHallGeometry.platform_rect(spec)
		var stairs := TimberHallGeometry.front_stair_rect(spec)
		if spec.water.intersects(h) or spec.water.intersects(water_platform) or spec.water.intersects(stairs):
			failures.append("wings: water overlaps hall, platform, or front stair")
		if spec.water.end.y > stairs.position.y:
			failures.append("wings: water does not clear the front stair")
		if builder.mass_aabb("wing_left").size != builder.mass_aabb("wing_right").size:
			failures.append("wings: wing corridors are not mirrored")
		if builder.mass_aabb("wing_roof_left").size == Vector3.ZERO or builder.mass_aabb("wing_roof_right").size == Vector3.ZERO:
			failures.append("wings: both corridors need continuous roofs")
	return {"failures": failures, "stats": {"columns": spec.columns.size(), "platform": p}}

static func _point_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((point - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return point.distance_to(a + ab * t)
