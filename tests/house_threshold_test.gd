extends SceneTree
## LIVE-THRESHOLDS: domestic stairs are emitted at a human scale or recorded
## as infeasible. Run: godot --headless --script res://tests/house_threshold_test.gd

var failures: Array[String] = []
var selected_seed := 0
var plan_only := false
var last_mesh_hit := Vector3.ZERO
var last_mesh_source := ""


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "plan_only":
			plan_only = true
		if arg.begins_with("seed="):
			selected_seed = int(arg.trim_prefix("seed="))
	_check_walkable_flight_and_emitted_guards()
	_check_generated_house_sizes()
	_check_infeasible_footprint_is_not_shrunk()
	_check_shortened_flight_negative_control()
	_check_measured_headroom_negative_control()
	_check_blocked_foot_landing_with_walker()
	_check_adapter_stairs_keep_their_family_paths()
	_check_door_mesh_negative_control()
	for failure in failures:
		printerr("FAIL " + failure)
	print("house threshold stairs: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _check_walkable_flight_and_emitted_guards() -> void:
	var plan := _two_level_plan(12.0, 14.0, 2.6, false)
	HousePlanLevels.add_stair(plan, 0, 1, 0, 1)
	if plan.stairs.size() != 1:
		failures.append("large fixture did not record one stair")
		return
	var stair: Dictionary = plan.stairs[0]
	if not bool(stair.get("satisfied", false)):
		failures.append("large fixture was marked unsatisfied: %s" % stair.get("reason", "no reason"))
		return
	_check_profile(stair, plan.spec.height, "large fixture")
	for entry in [
		{"room": 0, "rect": stair["foot_landing"]},
		{"room": 1, "rect": stair["head_landing"]},
	]:
		if not _poly_encloses(HouseGeometry.room_floor_poly(plan, int(entry["room"])), Rect2(entry["rect"])):
			failures.append("a recorded end landing is outside its actual room floor")
	var builder := HouseBuilder.new()
	var mesh := builder.build(plan, false)
	var stair_masses: Array = builder.mass_log.filter(func(row):
		return String(row.name).begins_with("stair_0_step_"))
	if stair_masses.size() != int(stair["steps"]):
		failures.append("builder emitted %d steps for a %d-step profile" % [stair_masses.size(), stair["steps"]])
	if not _landing_has_emitted_floor(builder, Rect2(stair["foot_landing"]), 0, plan.spec.height):
		failures.append("foot landing has no emitted lower-storey floor beneath it")
	if not _landing_has_emitted_floor(builder, Rect2(stair["head_landing"]), 1, plan.spec.height):
		failures.append("head landing has no emitted upper-storey floor beneath it")
	var rails := builder.component_log.filter(func(row):
		return String(row.get("host", "")) == "stair_0" and "rail" in String(row.get("role", "")))
	if rails.size() < 4:
		failures.append("builder emitted only %d hosted rail beams" % rails.size())
	var components := ComponentCheck.check(builder, mesh)
	if not bool(components["ok"]):
		failures.append("stair component log differs from emitted mesh: %s" % "; ".join(components["failures"]))
	var violations := HouseStairCheck.check(plan, builder)
	if not violations.is_empty():
		failures.append("walkable fixture has stair violations: %s" % "; ".join(violations))
	for climb in [-1.0, 1.0]:
		plan.stairs[0]["climb"] = climb
		var guarded := HouseBuilder.new()
		guarded.build(plan, false)
		if _duplicate_guard_post(guarded.component_log):
			failures.append("stair head emits coincident guard posts for climb %.0f" % climb)
		var corrupted: Array = guarded.component_log.duplicate(true)
		for row in guarded.component_log:
			if String(row.get("role", "")) == "stair_guard_post":
				corrupted.append(row.duplicate(true))
				break
		if not _duplicate_guard_post(corrupted):
			failures.append("duplicate guard-post negative control was missed")


func _duplicate_guard_post(rows: Array) -> bool:
	var posts: Array = []
	for row in rows:
		if not String(row.get("host", "")).begins_with("stair_") \
				or not String(row.get("role", "")).ends_with("post"):
			continue
		var xf: Transform3D = row["xf"]
		for prior in posts:
			var other: Transform3D = prior["xf"]
			if xf.is_equal_approx(other) and Vector3(row["size"]).is_equal_approx(Vector3(prior["size"])):
				return true
		posts.append(row)
	return false


func _check_infeasible_footprint_is_not_shrunk() -> void:
	var plan := _two_level_plan(9.0, 9.0, 2.6, true)
	HousePlanLevels.add_stair(plan, 0, 1, 0, 1)
	if plan.stairs.size() != 1:
		failures.append("compact fixture did not record its stair status")
		return
	var stair: Dictionary = plan.stairs[0]
	if bool(stair.get("satisfied", true)):
		failures.append("compact hall unexpectedly accepted a shortened flight")
	if float(stair.get("required_run", 0.0)) < plan.spec.height / tan(deg_to_rad(HouseGeometry.STAIR_PITCH_MAX)):
		failures.append("unsatisfied record lost the geometric run requirement")
	if String(stair.get("reason", "")).is_empty():
		failures.append("unsatisfied stair has no reason")
	var builder := HouseBuilder.new()
	builder.build(plan, false)
	if builder.has_mass("stair_0_step_"):
		failures.append("builder emitted a stair after the plan marked it infeasible")
	if not bool(plan.domestic_layout.get("stair_unsatisfied", false)):
		failures.append("domestic layout provenance omitted the infeasible stair")
	if not _has_prefix(HouseStairCheck.check(plan), "stair_infeasible:"):
		failures.append("infeasible stair escaped the final diagnostic")


func _check_generated_house_sizes() -> void:
	var fixtures := [
		{"style": &"cottage", "width": 9.0, "length": 12.0, "storeys": 2, "seed": 8102, "name": "default cottage two-storey"},
		{"style": &"farmhouse", "width": 9.0, "length": 12.0, "storeys": 2, "seed": 8114, "name": "default farmhouse two-storey"},
		{"style": &"farmhouse", "width": 9.0, "length": 12.0, "storeys": 3, "seed": 9127, "name": "default farmhouse three-storey"},
		{"style": &"townhouse", "width": 9.0, "length": 12.0, "storeys": 2, "seed": 9301, "name": "default townhouse two-storey"},
		{"style": &"townhouse", "width": 9.0, "length": 12.0, "storeys": 3, "seed": 9302, "name": "default townhouse three-storey"},
		{"style": &"witch_hut", "width": 9.0, "length": 12.0, "storeys": 2, "seed": 9501, "name": "default witch hut two-storey"},
		{"style": &"longhall", "width": 17.0, "length": 18.0, "storeys": 2, "seed": 17018, "name": "large longhall two-storey"},
		{"style": &"farmhouse", "width": 17.0, "length": 18.0, "storeys": 2, "seed": 17028, "name": "large farmhouse two-storey"},
		{"style": &"farmhouse", "width": 17.0, "length": 18.0, "storeys": 3, "seed": 17019, "name": "large farmhouse three-storey"},
		{"style": &"townhouse", "width": 17.0, "length": 18.0, "storeys": 3, "seed": 17103, "name": "large townhouse three-storey"},
	]
	for fixture in fixtures:
		if selected_seed != 0 and int(fixture["seed"]) != selected_seed:
			continue
		print("THRESHOLD_CASE ", fixture["name"], " seed=", fixture["seed"])
		var spec := HouseSpec.new()
		spec.style = fixture["style"]
		spec.width = float(fixture["width"])
		spec.length = float(fixture["length"])
		spec.storeys = int(fixture["storeys"])
		var seed := int(fixture["seed"])
		var plan := HouseGenerator.generate(spec, seed, false)
		var who := String(fixture["name"]) + " seed=" + str(seed)
		if plan.stairs.size() != spec.storeys - 1:
			failures.append("%s planned %d transitions for %d storeys" % [who, plan.stairs.size(), spec.storeys])
			continue
		var valid := true
		for index in range(plan.stairs.size()):
			var stair: Dictionary = plan.stairs[index]
			if not bool(stair.get("satisfied", false)):
				failures.append("%s stair %d unsatisfied: %s" % [who, index, stair.get("reason", "no reason")])
				valid = false
				continue
			_check_profile(stair, spec.height, "%s stair %d" % [who, index])
			if not _poly_encloses(HouseGeometry.room_floor_poly(plan, int(stair["a"])),
					Rect2(stair["foot_landing"])):
				failures.append("%s stair %d foot landing misses its room floor" % [who, index])
			if not _poly_encloses(HouseGeometry.room_floor_poly(plan, int(stair["b"])),
					Rect2(stair["head_landing"])):
				failures.append("%s stair %d head landing misses its room floor" % [who, index])
		if not valid:
			continue
		HouseFurnisher.furnish(plan, spec)
		var builder := HouseBuilder.new()
		builder.build(plan, false)
		if not plan_only:
			var assembled := HouseAssembler.build(plan, false)
			var collision_triangles: Array = []
			_collect_scene_triangles(assembled, collision_triangles)
			for index in range(plan.stairs.size()):
				_check_stair_body_clearance(collision_triangles, plan.stairs[index], plan,
					"%s stair %d" % [who, index])
			_check_door_clearance(collision_triangles, plan, who)
			assembled.free()
		var diagnostics := HouseStairCheck.check(plan, builder)
		if not diagnostics.is_empty():
			failures.append("%s stair QA: %s" % [who, "; ".join(diagnostics)])
			var debug_nav := HouseNavCheck.new()
			debug_nav._plan = plan
			debug_nav._rasterize()
			var debug_grid: WalkGrid = debug_nav._grids[0]
			debug_grid.add_obstacle(Rect2(plan.stairs[0]["lower_rect"]))
			debug_grid.build(HouseStairCheck.WALKER)
			var entry: Dictionary = plan.doors[plan.entrance()]
			var start := Vector2(entry["pos"]) - Vector2(entry["normal"]) * 0.4
			debug_grid.flood_from(start)
			print("APPROACH_DEBUG ", plan.stairs)
			print(debug_grid.ascii_map({start: "E", Rect2(plan.stairs[0]["foot_landing"]).get_center(): "F"}))
			for fi in plan.furniture_of(int(plan.stairs[0]["a"])):
				print("APPROACH_PROP ", plan.furniture[fi])
		var nav := HouseNavCheck.new()
		var nav_report: Dictionary = nav.check(plan)
		for issue in nav_report["failures"]:
			var msg := String(issue)
			if msg.begins_with("nav: door ") or msg.begins_with("nav: storey ") \
					or msg.contains("stair foot landing") or msg.contains("stair head landing"):
				failures.append("%s collision-clearance route: %s" % [who, msg])
		for index in range(plan.stairs.size()):
			var host := "stair_%d" % index
			_check_well_foot_guard(builder, plan, index, who)
			var upper_guard_count := 0
			for row in builder.component_log:
				if String(row.get("host", "")) == host \
						and String(row.get("role", "")).begins_with("stair_well_rail"):
					upper_guard_count += 1
			if upper_guard_count < 4:
				failures.append("%s has no complete upper-well guard on %s" % [who, host])
			for row in builder.component_log:
				if String(row.get("host", "")) != host:
					continue
				var role := String(row.get("role", ""))
				if not role.begins_with("stair_well_rail"):
					continue
				var xf: Transform3D = row["xf"]
				var upper_level := int(plan.stairs[index]["to_storey"])
				var expected_floor := float(upper_level) * spec.height + HouseGeometry.FLOOR_T
				var expected_rise := 0.9 if role.ends_with("top") else 0.46
				if absf(xf.origin.y - (expected_floor + expected_rise)) > 0.01:
					failures.append("%s %s is detached from its upper-floor edge" % [who, role])


func _check_well_foot_guard(builder: HouseBuilder, plan: HousePlan,
		index: int, who: String) -> void:
	var stair: Dictionary = plan.stairs[index]
	var flight: Rect2 = stair["upper_rect"]
	var along_x := flight.size.x > flight.size.y
	var climb := HouseGeometry.stair_climb(plan, stair)
	var end := flight.position if climb > 0.0 else flight.end
	var centre := Vector2(end.x, flight.get_center().y) if along_x \
		else Vector2(flight.get_center().x, end.y)
	var floor_y := float(stair["to_storey"]) * plan.spec.height + HouseGeometry.FLOOR_T
	var found := [false, false]
	for row in builder.component_log:
		if String(row.get("host", "")) != "stair_%d" % index \
				or String(row.get("role", "")) != "stair_well_foot_rail":
			continue
		var xf: Transform3D = row["xf"]
		for hi in range(2):
			var rise: float = [0.46, 0.9][hi]
			if xf.origin.distance_to(Vector3(centre.x, floor_y + rise, centre.y)) < 0.01:
				found[hi] = true
	if not found[0] or not found[1]:
		failures.append("%s stair %d leaves the short foot edge of its upper well unguarded" % [who, index])


## Inspect the actual shell and instantiated furniture. WalkGrid proves plan
## circulation. These rays prove the assembled models leave a human corridor.
func _collect_scene_triangles(node: Node, out: Array,
		parent_transform := Transform3D.IDENTITY, parent_name := "") -> void:
	var source := parent_name + "/" + String(node.name)
	var xf: Transform3D = parent_transform
	if node is Node3D:
		xf = parent_transform * node.transform
	if node is MeshInstance3D and node.mesh != null:
		var mesh_node := node as MeshInstance3D
		for surface in mesh_node.mesh.get_surface_count():
			var arrays := mesh_node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count := indices.size() if not indices.is_empty() else vertices.size()
			for i in range(0, count - 2, 3):
				var i0: int = indices[i] if not indices.is_empty() else i
				var i1: int = indices[i + 1] if not indices.is_empty() else i + 1
				var i2: int = indices[i + 2] if not indices.is_empty() else i + 2
				var a: Vector3 = xf * vertices[i0]
				var b: Vector3 = xf * vertices[i1]
				var c: Vector3 = xf * vertices[i2]
				out.append({"points": [a, b, c, source],
					"bounds": AABB(a, Vector3.ZERO).expand(b).expand(c).grow(0.001)})
	for child in node.get_children():
		_collect_scene_triangles(child, out, xf, source)


func _check_stair_body_clearance(triangles: Array, stair: Dictionary,
		plan: HousePlan, who: String) -> void:
	var height := float(plan.spec.height)
	var foot := Rect2(stair["foot_landing"])
	var head := Rect2(stair["head_landing"])
	var flight := Rect2(stair["lower_rect"])
	var along_x := flight.size.x > flight.size.y
	var run := flight.size.x if along_x else flight.size.y
	var steps := int(stair["steps"])
	var climb := HouseGeometry.stair_climb(plan, stair)
	var base_y := float(stair["storey"]) * height
	base_y += HouseGeometry.FLOOR_T
	var foot_3 := Vector3(foot.get_center().x, base_y, foot.get_center().y)
	var head_3 := Vector3(head.get_center().x, float(stair["to_storey"]) * height + HouseGeometry.FLOOR_T,
		head.get_center().y)
	var bounds_2d := flight.merge(foot).merge(head).grow(0.05)
	var nearby := _nearby_triangles(triangles, AABB(
		Vector3(bounds_2d.position.x, base_y, bounds_2d.position.y),
		Vector3(bounds_2d.size.x, height + HouseStairCheck.HEADROOM + 0.1, bounds_2d.size.y)))
	var path: Array[Vector3] = [foot_3]
	for index in range(steps):
		var t := run * (float(index) + 0.5) / float(steps)
		if climb < 0.0:
			t = run - t
		var point_2 := Vector2(flight.position.x + t, flight.get_center().y) if along_x \
			else Vector2(flight.get_center().x, flight.position.y + t)
		path.append(Vector3(point_2.x, base_y + height * float(index + 1) / float(steps), point_2.y))
	path.append(head_3)
	# Three across the 0.9 m walker and three high. Probe every riser transition
	# and both approaches in both directions against the assembled triangles.
	var across := Vector3(0.0, 0.0, 1.0) if along_x else Vector3(1.0, 0.0, 0.0)
	for side in [-0.45, 0.0, 0.45]:
		for rise in [0.16, 0.9, 1.98]:
			var offset := across * float(side) + Vector3.UP * float(rise)
			for index in range(path.size() - 1):
				var a := path[index] + offset
				var b := path[index + 1] + offset
				if _segment_hits_mesh(a, b, nearby) or _segment_hits_mesh(b, a, nearby):
					failures.append("%s assembled stair body sweep collides at lateral %.2f, height %.2f, segment %d, point %s on %s" % [who, side, rise, index, last_mesh_hit, last_mesh_source])


func _check_door_clearance(triangles: Array, plan: HousePlan, who: String) -> void:
	for di in range(plan.doors.size()):
		var door: Dictionary = plan.doors[di]
		var level := HousePlan.record_storey(door)
		var normal := Vector2(door["normal"]).normalized()
		var tangent := Vector2(-normal.y, normal.x)
		var centre := Vector2(door["pos"])
		# Sweep the reserved approach on each side of this threshold. Wall
		# thickness is already inside it; adding it again tested furniture
		# beyond the doorway's approach, where the route may legitimately turn.
		var reach := HouseGeometry.DOOR_CLEAR
		var extent := normal.abs() * reach + tangent.abs() * 0.46
		var floor_y := float(level) * plan.spec.height + HouseGeometry.FLOOR_T
		var nearby := _nearby_triangles(triangles, AABB(
			Vector3(centre.x - extent.x, floor_y, centre.y - extent.y),
			Vector3(extent.x * 2.0, 2.1, extent.y * 2.0)))
		for side in [-0.45, 0.0, 0.45]:
			for rise in [0.16, 0.9, 1.98]:
				var mid := Vector3(centre.x + tangent.x * side, floor_y + rise,
					centre.y + tangent.y * side)
				var delta := Vector3(normal.x, 0.0, normal.y) * reach
				if _segment_hits_mesh(mid - delta, mid + delta, nearby) \
						or _segment_hits_mesh(mid + delta, mid - delta, nearby):
					failures.append("%s assembled door %d blocks body at side %.2f height %.2f point %s on %s" % [who, di, side, rise, last_mesh_hit, last_mesh_source])


func _check_door_mesh_negative_control() -> void:
	var plan := _two_level_plan(12.0, 14.0, 2.6, false)
	var door: Dictionary = plan.doors[0]
	var centre := Vector2(door["pos"])
	var obstruction := MeshInstance3D.new()
	obstruction.name = "ThresholdObstruction"
	var box := BoxMesh.new()
	box.size = Vector3(0.95, 1.0, 0.12)
	obstruction.mesh = box
	# At the far end of the reserved approach, not just in the opening.
	obstruction.position = Vector3(centre.x, HouseGeometry.FLOOR_T + 0.5,
		centre.y + HouseGeometry.DOOR_CLEAR - 0.08)
	var triangles: Array = []
	_collect_scene_triangles(obstruction, triangles)
	var before := failures.size()
	_check_door_clearance(triangles, plan, "blocked threshold control")
	var detected := failures.size() > before
	failures.resize(before)
	obstruction.free()
	if not detected:
		failures.append("assembled threshold obstruction escaped the body sweep")


func _nearby_triangles(triangles: Array, bounds: AABB) -> Array:
	var selected: Array = []
	for row in triangles:
		if bounds.intersects(row["bounds"]):
			selected.append(row["points"])
	return selected


func _segment_hits_mesh(a: Vector3, b: Vector3, triangles: Array) -> bool:
	for triangle in triangles:
		var hit = Geometry3D.segment_intersects_triangle(a, b,
			triangle[0], triangle[1], triangle[2])
		if hit != null:
			last_mesh_hit = hit
			last_mesh_source = String(triangle[3])
			return true
	return false


func _check_shortened_flight_negative_control() -> void:
	var plan := _two_level_plan(12.0, 14.0, 2.6, false)
	HousePlanLevels.add_stair(plan, 0, 1, 0, 1)
	if plan.stairs.is_empty() or not bool(plan.stairs[0].get("satisfied", false)):
		failures.append("negative control had no valid stair to damage")
		return
	var stair: Dictionary = plan.stairs[0]
	var flight: Rect2 = stair["lower_rect"]
	var size: Vector2
	if flight.size.x > flight.size.y:
		size = Vector2(2.4, flight.size.y)
	else:
		size = Vector2(flight.size.x, 2.4)
	var bad := Rect2(flight.position, size)
	stair["rect"] = bad
	stair["lower_rect"] = bad
	stair["upper_rect"] = bad
	var why := HouseStairCheck.check(plan)
	if not _has_prefix(why, "stair_pitch:"):
		failures.append("2.4 m negative control escaped the pitch check")


func _check_measured_headroom_negative_control() -> void:
	var plan := _two_level_plan(12.0, 14.0, 2.6, false)
	HousePlanLevels.add_stair(plan, 0, 1, 0, 1)
	if plan.stairs.is_empty() or not bool(plan.stairs[0].get("satisfied", false)):
		failures.append("headroom control has no usable flight")
		return
	var flight := Rect2(plan.stairs[0]["lower_rect"])
	var centre := flight.get_center()
	plan.furniture.append({"key": "Chandelier", "room": 0, "storey": 0,
		"pos": Vector3(centre.x, plan.spec.height, centre.y), "yaw": 0.0,
		"rect": Rect2(centre - Vector2.ONE * 0.05, Vector2.ONE * 0.1),
		"zone": Rect2(), "host": -1, "mounted": true, "scale": 1.0})
	var obstructed: Array[String] = []
	HouseStairCheck._headroom(plan, 0, plan.stairs[0], obstructed)
	if not _has_prefix(obstructed, "stair_headroom:"):
		failures.append("a measured chandelier over the flight escaped headroom QA")
	# Move the complete measured body just beyond the flight's side. Its tiny
	# mount record and an isotropic depth expansion do not describe this pose.
	var size := PropCatalog.footprint_rotated("Chandelier", PropCatalog.face_offset("Chandelier"))
	if flight.size.x > flight.size.y:
		centre.y = flight.end.y + size.y * 0.5 + 0.1
	else:
		centre.x = flight.end.x + size.x * 0.5 + 0.1
	plan.furniture[0]["pos"] = Vector3(centre.x, plan.spec.height, centre.y)
	plan.furniture[0]["rect"] = Rect2(centre - Vector2.ONE * 0.05, Vector2.ONE * 0.1)
	var clear: Array[String] = []
	HouseStairCheck._headroom(plan, 0, plan.stairs[0], clear)
	if not clear.is_empty():
		failures.append("a chandelier wholly beside the flight caused false headroom overlap")


func _check_blocked_foot_landing_with_walker() -> void:
	var spec := HouseSpec.new()
	spec.style = &"farmhouse"
	spec.width = 9.0
	spec.length = 12.0
	spec.storeys = 2
	var plan := HouseGenerator.generate(spec, 8102, true)
	if plan.stairs.is_empty() or not bool(plan.stairs[0].get("satisfied", false)):
		failures.append("walker obstruction fixture has no valid stair")
		return
	var stair: Dictionary = plan.stairs[0]
	var lo := int(stair["storey"])
	var nav := HouseNavCheck.new()
	nav._plan = plan
	nav._rasterize()
	if not nav._grids.has(lo):
		failures.append("walker obstruction fixture has no lower-storey grid")
		return
	var door_index := plan.entrance()
	if door_index < 0:
		failures.append("walker obstruction fixture has no front door")
		return
	var door: Dictionary = plan.doors[door_index]
	var inside: Vector2 = Vector2(door["pos"]) - Vector2(door["normal"]) \
		* (HouseGeometry.wall_thickness(spec) * 0.5 + 0.2)
	var grid: WalkGrid = nav._grids[lo]
	grid.add_obstacle(Rect2(stair["lower_rect"]))
	grid.build(HouseStairCheck.WALKER)
	var foot := Rect2(stair["foot_landing"])
	if not grid.flood_from(inside) or not grid.reached(foot):
		print("APPROACH_DEBUG stair=", stair, " entry=", inside)
		print(grid.ascii_map({inside: "E", foot.get_center(): "F"}))
		for fi in plan.furniture_of(int(stair["a"])):
			print("APPROACH_PROP ", plan.furniture[fi])
		failures.append("unobstructed 0.9 m walker could not reach the foot landing")
		return
	grid.add_obstacle(foot)
	grid.build(HouseStairCheck.WALKER)
	if grid.flood_from(inside) and grid.reached(foot):
		failures.append("0.9 m walker still reaches a landing filled by a real obstacle")


func _check_adapter_stairs_keep_their_family_paths() -> void:
	var family_specs: Array[HouseSpec] = [KeepSpec.new(), ShopSpec.new(), HotelSpec.new(), InsulaSpec.new()]
	var names := ["KeepSpec", "ShopSpec", "HotelSpec", "InsulaSpec"]
	for i in family_specs.size():
		var family: HouseSpec = family_specs[i]
		family.width = 12.0
		family.length = 14.0
		family.height = 2.6
		var plan := _two_level_plan(family.width, family.length, family.height, false, family)
		HousePlanLevels.add_stair(plan, 0, 1, 0, 1)
		if plan.stairs.is_empty():
			failures.append("%s family control lost its stair" % names[i])
			continue
		var stair: Dictionary = plan.stairs[0]
		if bool(stair.get("domestic_profile", false)) \
				or not is_equal_approx(float(stair["run"]), 2.4):
			failures.append("%s was rewritten by the ordinary-house stair profile" % names[i])
	for excluded in ["trade", "world", "legacy_layout"]:
		var plan := _two_level_plan(12.0, 14.0, 2.6, false)
		if excluded == "trade":
			plan.spec.trade = &"innkeeper"
		elif excluded == "world":
			plan.world_family = &"courtyard"
		else:
			plan.domestic_layout.clear()
		HousePlanLevels.add_stair(plan, 0, 1, 0, 1)
		if plan.stairs.is_empty() or bool(plan.stairs[0].get("domestic_profile", false)):
			failures.append("%s control entered the converted domestic stair path" % excluded)


func _two_level_plan(width: float, length: float, height: float,
		compact_hall: bool, passed_spec: HouseSpec = null) -> HousePlan:
	var spec := passed_spec if passed_spec != null else HouseSpec.new()
	spec.width = width
	spec.length = length
	spec.height = height
	spec.storeys = 2
	var plan := HousePlan.new()
	plan.spec = spec
	# This deliberately authored fixture models the converted room grammar.
	# Adapter controls retain this marker to prove the family gate also holds.
	plan.domestic_layout = {"status": &"planned", "style": spec.style}
	var clear := HouseGeometry.interior_rect(spec)
	for level in [0, 1]:
		var rect: Rect2 = clear
		if compact_hall:
			rect = Rect2(clear.position, Vector2(minf(4.8, clear.size.x), minf(2.65, clear.size.y)))
		plan.rooms.append({"kind": &"hall", "rect": rect, "storey": level})
	var front: Rect2 = plan.rooms[0]["rect"]
	plan.doors.append({"a": 0, "b": -1, "storey": 0, "front": true,
		"exterior": true, "width": 0.95, "head": 2.22,
		"pos": Vector2(front.get_center().x, front.position.y), "normal": Vector2(0, -1)})
	return plan


func _check_profile(stair: Dictionary, height: float, who: String) -> void:
	var flight: Rect2 = stair["lower_rect"]
	var run := maxf(flight.size.x, flight.size.y)
	var steps := int(stair["steps"])
	var riser := height / float(steps)
	var going := run / float(steps)
	if run < height / tan(deg_to_rad(HouseGeometry.STAIR_PITCH_MAX)):
		failures.append("%s run %.2f m is steeper than pitch limit" % [who, run])
	if riser > HouseGeometry.STAIR_RISER_MAX + 0.001 \
			or going < HouseGeometry.STAIR_GOING_MIN - 0.001 \
			or 2.0 * riser + going > HouseGeometry.STAIR_STRIDE_MAX + 0.001:
		failures.append("%s step profile violates rise/going/stride: %.3f/%.3f" % [who, riser, going])
	if minf(flight.size.x, flight.size.y) < HouseGeometry.STAIR_WIDTH_MIN - 0.001:
		failures.append("%s stair width is below the domestic minimum" % who)
	var clear_width := minf(flight.size.x, flight.size.y) - 2.0 * (
		HouseGeometry.STAIR_GUARD_EDGE_OFFSET + HouseGeometry.STAIR_GUARD_THICKNESS * 0.5)
	if clear_width < HouseGeometry.STAIR_WIDTH_CLEAR_MIN - 0.001:
		failures.append("%s guarded flight leaves only %.3f m clear" % [who, clear_width])
	if not bool(stair.get("foot_landing", Rect2()).has_area()) \
			or not bool(stair.get("head_landing", Rect2()).has_area()):
		failures.append("%s is missing a real floor landing" % who)


func _poly_encloses(poly: PackedVector2Array, rect: Rect2) -> bool:
	for point in Poly.from_rect(rect):
		if not Poly.contains_point(poly, point, 0.01):
			return false
	return true


func _landing_has_emitted_floor(builder: HouseBuilder, rect: Rect2, level: int,
		height: float) -> bool:
	var samples := [rect.get_center(), rect.position + rect.size * 0.25,
		rect.position + Vector2(rect.size.x * 0.75, rect.size.y * 0.25),
		rect.position + rect.size * 0.75,
		rect.position + Vector2(rect.size.x * 0.25, rect.size.y * 0.75)]
	for sample in samples:
		var covered := false
		for row in builder.mass_log:
			if not String(row.get("name", "")).begins_with("floor"):
				continue
			var box: AABB = row["aabb"]
			if absf(box.position.y - float(level) * height) > 0.02:
				continue
			if sample.x >= box.position.x + 0.02 and sample.x <= box.end.x - 0.02 \
					and sample.y >= box.position.z + 0.02 and sample.y <= box.end.z - 0.02:
				covered = true
				break
		if not covered:
			return false
	return true


func _has_prefix(rows: Array[String], prefix: String) -> bool:
	for row in rows:
		if row.begins_with(prefix):
			return true
	return false
