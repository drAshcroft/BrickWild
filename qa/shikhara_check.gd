class_name ShikharaCheck
extends RefCounted
## WLD-013 acceptance. Uses TempleRiteCheck's shared axis and sightline geometry.

static func check(plan: HousePlan, builder: NagaraBuilder) -> Dictionary:
	var failures: Array[String] = []
	var urushringa_count := 0
	for mass in builder.mass_log:
		if String(mass.get("name", "")).begins_with("urushringa_"):
			urushringa_count += 1
	_check_ascent(plan, builder, failures)
	_check_axis(plan, failures)
	_check_sanctum(plan, builder, failures)
	_check_plinth(plan, builder, failures)
	_check_cluster(builder, failures)
	_check_pradakshina(plan, failures)
	_check_sightline(plan, builder, failures)
	return {"ok": failures.is_empty(), "failures": failures, "warnings": [],
		"stats": {"halls": plan.world_meta["hall_rects"].size(),
			"urushringas": urushringa_count,
			"ring_segments": plan.world_meta["pradakshina"].size()}}


static func _check_ascent(plan: HousePlan, builder: NagaraBuilder, failures: Array[String]) -> void:
	var heights: Array = plan.world_meta.get("hall_heights", [])
	if heights.size() != 4:
		failures.append("ascent: expected four rising halls")
		return
	var previous := -INF
	for i in range(heights.size()):
		var emitted := builder.mass_aabb("hall_%d" % i)
		var measured_top := emitted.end.y
		if float(heights[i]) <= previous or measured_top <= float(plan.world_meta["plinth_height"]) + previous:
			failures.append("ascent: hall %d does not rise above its predecessor" % i)
		previous = float(heights[i])
	var shikhara := builder.mass_aabb("shikhara")
	if shikhara.size == Vector3.ZERO or shikhara.end.y <= builder.mass_aabb("hall_3").end.y:
		failures.append("ascent: emitted shikhara is not the tallest mass")


static func _check_axis(plan: HousePlan, failures: Array[String]) -> void:
	var marks: Array = []
	for i in range(plan.world_meta["hall_rects"].size()):
		var rect: Rect2 = plan.world_meta["hall_rects"][i]
		marks.append(["hall %d" % i, rect.get_center().x])
	var sanctum: Rect2 = plan.world_meta["sanctum_rect"]
	marks.append(["sanctum", sanctum.get_center().x])
	var tol := float(plan.spec.width) * 0.02
	failures.append_array(TempleRiteCheck.axis_faults(0.0, marks, tol))
	for door in plan.doors:
		var p: Vector2 = door["pos"]
		if absf(p.x) > tol:
			failures.append("axis: a door is %.2fm off the processional line" % p.x)
			break


static func _check_sanctum(plan: HousePlan, builder: NagaraBuilder,
		failures: Array[String]) -> void:
	var sanctum: Rect2 = plan.world_meta["sanctum_rect"]
	var largest := 0.0
	for hall in plan.world_meta["hall_rects"]:
		var rect: Rect2 = hall
		largest = maxf(largest, rect.get_area())
	if sanctum.get_area() > largest / 6.0 + 0.02:
		failures.append("sanctum: garbhagriha exceeds one sixth of the largest hall")
	var aspect := maxf(sanctum.size.x, sanctum.size.y) / maxf(minf(sanctum.size.x, sanctum.size.y), 0.001)
	if aspect > 1.1:
		failures.append("sanctum: garbhagriha is not square")
	if not plan.windows.is_empty():
		failures.append("sanctum: a window admits daylight to the dark chamber")
	var sanctum_id := plan.rooms.size() - 1
	var doors := 0
	for door in plan.doors:
		if int(door.get("a", -1)) == sanctum_id or int(door.get("b", -1)) == sanctum_id:
			doors += 1
	if doors != 1:
		failures.append("sanctum: expected one axial door, found %d" % doors)
	if not builder.has_mass("sanctum_roof"):
		failures.append("sanctum: emitted dark roof is missing")


static func _check_plinth(plan: HousePlan, builder: NagaraBuilder,
		failures: Array[String]) -> void:
	var plinth := builder.mass_aabb("plinth")
	var spire := builder.mass_aabb("shikhara")
	if plinth.size.y < float(plan.world_meta["shikhara_height"]) * 0.1:
		failures.append("plinth: emitted platform is less than a tenth of the shikhara height")
	var stair := false
	for mass in builder.mass_log:
		if String(mass.get("name", "")).begins_with("plinth_stair_"):
			var aabb: AABB = mass["aabb"]
			if aabb.position.x <= 0.02 and aabb.end.x >= -0.02 and aabb.position.z < plinth.position.z:
				stair = true
	if not stair or spire.size == Vector3.ZERO:
		failures.append("plinth: no front-axis stair climbs to the raised platform")


static func _check_cluster(builder: NagaraBuilder, failures: Array[String]) -> void:
	var main := builder.mass_aabb("shikhara")
	if main.size == Vector3.ZERO:
		failures.append("cluster: main shikhara is absent")
		return
	var count := 0
	for mass in builder.mass_log:
		if not String(mass.get("name", "")).begins_with("urushringa_"):
			continue
		count += 1
		var small: AABB = mass["aabb"]
		var separation := MassRules.separation(main, small)
		if separation > 0.02:
			failures.append("cluster: %s is %.2fm from the main spire" % [mass["name"], separation])
		if main.end.y - small.end.y < small.size.y * 0.15:
			failures.append("cluster: %s reaches too near the main apex" % mass["name"])
	if count < 8:
		failures.append("cluster: expected at least eight subsidiary spires")


static func _check_pradakshina(plan: HousePlan, failures: Array[String]) -> void:
	var ring: Array = plan.world_meta.get("pradakshina", [])
	if ring.size() != 4:
		failures.append("pradakshina: passage does not have four connected sides")
		return
	for i in range(ring.size()):
		var a: Rect2 = ring[i]
		var b: Rect2 = ring[(i + 1) % ring.size()]
		if a.size.x <= 0.2 or a.size.y <= 0.2 or not a.intersects(b, true):
			failures.append("pradakshina: passage segment %d does not overlap its neighbour" % i)
			return
	var bounds: Rect2 = plan.world_meta["ring_outer"]
	var grid := WalkGrid.new()
	grid.setup(bounds.grow(0.4), 0.2)
	for rect in ring:
		grid.add_floor(rect)
	grid.build(0.0)
	if not grid.flood_from((ring[0] as Rect2).get_center(), 0.0):
		failures.append("pradakshina: walk flood cannot enter the passage")
		return
	for i in range(1, ring.size()):
		var centre := (ring[i] as Rect2).get_center()
		if not grid.reached(Rect2(centre - Vector2.ONE * 0.1, Vector2.ONE * 0.2), 0.0):
			failures.append("pradakshina: walk flood does not circle segment %d" % i)
			return


static func _check_sightline(plan: HousePlan, builder: NagaraBuilder,
		failures: Array[String]) -> void:
	if plan.doors.size() < 3:
		failures.append("sightline: mandapa door is missing")
		return
	var door: Vector2 = plan.doors[2]["pos"]
	var image: Vector3 = plan.world_meta["image"]
	var from := Vector3(door.x, float(plan.world_meta["plinth_height"]) + 1.6, door.y)
	var to := Vector3(image.x, image.y + 2.0, image.z)
	var blockers: Array = []
	for mass in builder.mass_log:
		var name := String(mass.get("name", ""))
		if name in ["plinth", "image", "garbhagriha", "sanctum_roof", "shikhara"] \
				or name.begins_with("hall_roof_") or name.begins_with("hall_") \
				or name.begins_with("pradakshina_") or name.begins_with("urushringa_"):
			continue
		blockers.append({"name": name, "aabb": mass["aabb"]})
	var hits := TempleRiteCheck.sightline_blockers(from, to, blockers)
	if not hits.is_empty():
		failures.append("sightline: %s hides the image from the mandapa door" % ", ".join(hits.slice(0, 3)))
