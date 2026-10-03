class_name ShikharaCheck
extends RefCounted
## WLD-013 acceptance. Uses TempleRiteCheck's shared axis and sightline geometry.

static func check(plan: HousePlan, builder: NagaraBuilder = null,
		emitted_mesh: ArrayMesh = null) -> Dictionary:
	var failures: Array[String] = []
	var urushringa_count := 0
	if builder == null:
		# Plan-only consumers can still verify the axis and walkable circuit.
		_check_axis(plan, failures)
		_check_pradakshina(plan, failures)
		return {"ok": failures.is_empty(), "failures": failures, "warnings": [],
			"stats": {"halls": plan.world_meta.get("hall_rects", []).size(),
				"urushringas": 0,
				"ring_segments": plan.world_meta.get("pradakshina", []).size()}}
	for mass in builder.mass_log:
		if String(mass.get("name", "")).begins_with("urushringa_"):
			urushringa_count += 1
	_check_ascent(plan, builder, failures)
	_check_axis(plan, failures)
	_check_sanctum(plan, builder, failures)
	_check_plinth(plan, builder, emitted_mesh, failures)
	_check_cluster(builder, failures)
	_check_pradakshina(plan, failures)
	_check_pradakshina_mesh(plan, builder, emitted_mesh, failures)
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
		emitted_mesh: ArrayMesh, failures: Array[String]) -> void:
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
	_check_plinth_tread_mesh(plan, builder, emitted_mesh, failures)


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


## Require actual support under every side of the pradakshina ring. The four
## rectangles and walk flood above only prove the plan is connected.
static func _check_pradakshina_mesh(plan: HousePlan, builder: NagaraBuilder,
		emitted_mesh: ArrayMesh, failures: Array[String]) -> void:
	var ring: Array = plan.world_meta.get("pradakshina", [])
	if ring.size() != 4:
		return # The plan-side rule already reports the malformed circuit.
	var triangles := _surface_triangles(builder, emitted_mesh, NagaraBuilder.TRIM)
	if triangles.is_empty():
		failures.append("pradakshina_mesh_support: emitted trim surface has no triangles")
		return
	var y := float(plan.world_meta.get("plinth_height", 0.0)) + 0.18
	for i in range(ring.size()):
		var rect: Rect2 = ring[i]
		var samples := _strip_samples(rect)
		var supported := 0
		for sample in samples:
			if _has_upward_support(triangles, sample, y):
				supported += 1
		if supported != samples.size():
			failures.append("pradakshina_mesh_support: segment %d has floor triangles at %d/%d probes" %
				[i, supported, samples.size()])


## Derive each tread from the declared stair run, width and step count, then
## look for its upward face in the finished stone emission.
static func _check_plinth_tread_mesh(plan: HousePlan, builder: NagaraBuilder,
		emitted_mesh: ArrayMesh, failures: Array[String]) -> void:
	if plan.stairs.is_empty():
		return # The plan/log rule reports the absent stair.
	var stair: Dictionary = plan.stairs[0]
	var count := int(stair.get("steps", 0))
	var width := float(stair.get("width", 0.0))
	var run := float(stair.get("run", 0.0))
	var plinth: Rect2 = plan.world_meta.get("plinth_rect", Rect2())
	var plinth_h := float(plan.world_meta.get("plinth_height", 0.0))
	if count < 1 or width <= 0.0 or run <= 0.0:
		return # Invalid planned dimensions are covered by the plan-side checks.
	var triangles := _surface_triangles(builder, emitted_mesh, NagaraBuilder.STONE)
	if triangles.is_empty():
		failures.append("plinth_mesh_support: emitted stone surface has no triangles")
		return
	var depth := run / float(count)
	for i in range(count):
		var top_y := plinth_h * float(i + 1) / float(count)
		var z := plinth.position.y - run + depth * (float(i) + 0.5)
		var supported := 0
		for offset in [-0.25, 0.0, 0.25]:
			if _has_upward_support(triangles, Vector2(width * float(offset), z), top_y):
				supported += 1
		if supported != 3:
			failures.append("plinth_mesh_support: tread %d has top triangles at %d/3 probes" %
				[i, supported])


static func _strip_samples(rect: Rect2) -> Array[Vector2]:
	var samples: Array[Vector2] = []
	for fraction in [0.25, 0.5, 0.75]:
		if rect.size.x >= rect.size.y:
			samples.append(Vector2(lerpf(rect.position.x, rect.end.x, fraction), rect.get_center().y))
		else:
			samples.append(Vector2(rect.get_center().x, lerpf(rect.position.y, rect.end.y, fraction)))
	return samples


static func _surface_triangles(builder: NagaraBuilder, mesh: ArrayMesh,
		surface: int) -> Array:
	var arrays: Array
	if mesh != null:
		if surface >= mesh.get_surface_count():
			return []
		arrays = mesh.surface_get_arrays(surface)
	else:
		if builder._kit == null or surface >= builder._kit._sts.size():
			return []
		arrays = builder._kit.surface(surface).commit_to_arrays()
	if arrays.size() <= Mesh.ARRAY_INDEX:
		return []
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return []
	var index_value: Variant = arrays[Mesh.ARRAY_INDEX]
	var order: PackedInt32Array = index_value if index_value != null else PackedInt32Array()
	if order.is_empty():
		order = PackedInt32Array()
		for i in range(vertices.size()):
			order.append(i)
	var triangles: Array = []
	for i in range(0, order.size() - 2, 3):
		var ia := order[i]
		var ib := order[i + 1]
		var ic := order[i + 2]
		if ia >= 0 and ib >= 0 and ic >= 0 and ia < vertices.size() \
				and ib < vertices.size() and ic < vertices.size():
			triangles.append([vertices[ia], vertices[ib], vertices[ic]])
	return triangles


static func _has_upward_support(triangles: Array, point: Vector2, y: float) -> bool:
	var from := Vector3(point.x, y + 0.025, point.y)
	var to := Vector3(point.x, y - 0.025, point.y)
	for triangle in triangles:
		var a: Vector3 = triangle[0]
		var b: Vector3 = triangle[1]
		var c: Vector3 = triangle[2]
		var face := (c - a).cross(b - a)
		if face.length_squared() < 1e-12 or face.normalized().dot(Vector3.UP) < 0.95:
			continue
		var hit: Variant = Geometry3D.segment_intersects_triangle(from, to, a, b, c)
		if hit != null and absf((hit as Vector3).y - y) <= 0.02:
			return true
	return false


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
