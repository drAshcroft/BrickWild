class_name HammamCheck
extends RefCounted
## Plan, walking, roof, and service rules for WLD-005 steam baths.

const RULES: Array[StringName] = [&"identity", &"path", &"walk_distance",
	&"hot_leaf", &"oculi", &"domes", &"dome_mesh_support", &"furnace"]
const STATIONS: Array[StringName] = HammamGenerator.STATIONS
const METHODS := {
	&"identity": "_check_identity", &"path": "_check_path",
	&"walk_distance": "_check_walk_distance", &"hot_leaf": "_check_hot_leaf",
	&"oculi": "_check_oculi", &"domes": "_check_domes",
	&"dome_mesh_support": "_check_dome_mesh_support",
	&"furnace": "_check_furnace",
}

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}
var replaced: Dictionary = {}
var _station_ids: Dictionary = {}
var _nav: HouseNavCheck


func check(plan: HousePlan, builder: HammamBuilder = null) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	replaced.clear()
	_station_ids = _room_ids(plan)
	_nav = HouseNavCheck.new()
	var nav_report: Dictionary = _nav.check(plan)

	# Daylight is replaced explicitly. Any window, even one otherwise valid,
	# violates the family; roof oculi are checked independently below.
	var daylight_override := {&"daylight": {
		"name": "hammam.blind", "call": Callable(self, "_replace_daylight")}}
	var plan_report: Dictionary = HousePlanCheck.new().check(plan, daylight_override)
	for failure in plan_report.get("failures", []):
		failures.append(str(failure))
	for warning in plan_report.get("warnings", []):
		warnings.append(str(warning))
	replaced.merge(plan_report.get("replaced", {}), true)
	for failure2 in nav_report.get("failures", []):
		failures.append(str(failure2))
	for warning2 in nav_report.get("warnings", []):
		warnings.append(str(warning2))

	RuleSet.run(self, RULES, METHODS, {}, [plan, builder, nav_report], [plan],
		failures, warnings)
	stats["walk_distances"] = _room_walk_distances(plan)
	stats["oculi"] = _oculus_counts(builder)
	return {"ok": failures.is_empty(), "failures": failures,
		"warnings": warnings, "stats": stats, "replaced": replaced}


func _replace_daylight(plan: HousePlan) -> Array[String]:
	if plan.windows.is_empty():
		return []
	return ["hammam.blind: expects zero windows, found %d" % plan.windows.size()]


func _check_identity(plan: HousePlan, builder: HammamBuilder,
		_nav_report: Dictionary) -> void:
	if plan.world_family != HammamGenerator.FAMILY \
			or plan.world_subkind != HammamGenerator.SUBKIND:
		failures.append("identity: plan is not a Steam Baths hammam")
	if plan.spec.storeys != 1:
		failures.append("identity: steam baths must be a single-storey shell")
	var station_ids_valid := _station_ids.size() == STATIONS.size()
	for station in STATIONS:
		station_ids_valid = station_ids_valid and int(_station_ids.get(station, -1)) >= 0
	if plan.room_count() != STATIONS.size() or not station_ids_valid:
		failures.append("identity: expected exactly one room for each of four stations")
	if builder == null:
		failures.append("identity: no emitted hammam builder was supplied")


func _check_path(plan: HousePlan, _builder: HammamBuilder,
		_nav_report: Dictionary) -> void:
	for station in STATIONS:
		if not _station_ids.has(station) or int(_station_ids[station]) < 0:
			failures.append("path: missing station %s" % String(station))
	if _station_ids.size() != STATIONS.size() or _has_invalid_station():
		return
	var expected_pairs := [
		_pair(int(_station_ids[&"changing"]), int(_station_ids[&"cold"])),
		_pair(int(_station_ids[&"cold"]), int(_station_ids[&"warm"])),
		_pair(int(_station_ids[&"warm"]), int(_station_ids[&"hot"])),
	]
	var actual_pairs: Array[String] = []
	var entry_count := 0
	for door in plan.doors:
		if bool(door.get("exterior", false)) or int(door.get("b", -1)) < 0:
			entry_count += 1
			if int(door.get("a", -1)) != int(_station_ids[&"changing"]) \
					or not bool(door.get("front", false)):
				failures.append("path: only the changing room may have the front entry")
			continue
		actual_pairs.append(_pair(int(door.get("a", -1)), int(door.get("b", -1))))
	actual_pairs.sort()
	expected_pairs.sort()
	if entry_count != 1 or plan.doors.size() != STATIONS.size():
		failures.append("path: expected one entry and exactly three internal doors")
	if actual_pairs != expected_pairs:
		failures.append("path: doors must form changing -> cold -> warm -> hot exactly")
	stats["station_order"] = STATIONS.duplicate()


func _check_walk_distance(plan: HousePlan, _builder: HammamBuilder,
		_nav_report: Dictionary) -> void:
	if _station_ids.size() != STATIONS.size() or _has_invalid_station():
		return
	var distances := _room_walk_distances(plan)
	var previous := -INF
	for station in STATIONS:
		var distance := float(distances.get(String(station), INF))
		if not is_finite(distance) or distance <= previous + 0.25:
			failures.append("walk_distance: %s is not farther along the walk than the preceding station" % String(station))
			return
		previous = distance


func _check_hot_leaf(plan: HousePlan, _builder: HammamBuilder,
		_nav_report: Dictionary) -> void:
	if not _station_ids.has(&"hot"):
		failures.append("hot_leaf: missing hot chamber")
		return
	var hot := int(_station_ids[&"hot"])
	var neighbours := 0
	for door in plan.doors:
		if bool(door.get("exterior", false)):
			if int(door.get("a", -1)) == hot:
				failures.append("hot_leaf: hot chamber has an exterior door")
			continue
		if int(door.get("a", -1)) == hot or int(door.get("b", -1)) == hot:
			neighbours += 1
	if neighbours != 1:
		failures.append("hot_leaf: hot chamber has %d internal exits, expected one" % neighbours)


func _check_oculi(_plan: HousePlan, builder: HammamBuilder,
		_nav_report: Dictionary) -> void:
	var counts := _oculus_counts(builder)
	stats["oculi"] = counts
	if int(counts.get("warm", 0)) < 3:
		failures.append("oculi: warm chamber has fewer than three emitted roof oculi")
	if int(counts.get("hot", 0)) < 1:
		failures.append("oculi: hot bathing chamber has no emitted roof oculus")


func _check_domes(plan: HousePlan, builder: HammamBuilder,
		_nav_report: Dictionary) -> void:
	if builder == null:
		failures.append("domes: no builder records")
		return
	var component_by_host := {}
	var dome_masses := 0
	for mass in builder.mass_log:
		if String(mass.get("name", "")).begins_with("dome_"):
			dome_masses += 1
	for row in builder.component_log:
		if row.get("role", "") == "dome_revolved":
			component_by_host[String(row.get("host", ""))] = row
	if dome_masses != 3 or component_by_host.size() != 3:
		failures.append("domes: expected three emitted dome masses and revolved shells")
	for role in [&"warm", &"hot"]:
		if not _station_ids.has(role):
			continue
		var room: Rect2 = HouseGeometry.room_floor_rect(plan, int(_station_ids[role]))
		var host := "dome_%s" % String(role)
		var dome_mass := AABB()
		for mass in builder.mass_log:
			if String(mass.get("name", "")) == host:
				dome_mass = mass["aabb"]
				break
		if dome_mass.size.x <= 0.0 or dome_mass.size.z <= 0.0:
			failures.append("domes: %s has no emitted structural mass" % String(role))
			continue
		var ellipse := PackedVector2Array()
		var centre := Vector2(dome_mass.position.x + dome_mass.size.x * 0.5,
			dome_mass.position.z + dome_mass.size.z * 0.5)
		for segment in range(96):
			var angle := TAU * float(segment) / 96.0
			ellipse.append(centre + Vector2(cos(angle) * dome_mass.size.x * 0.5,
				sin(angle) * dome_mass.size.z * 0.5))
		var ratio := Poly.intersection_area(ellipse, Poly.from_rect(room)) \
			/ maxf(room.get_area(), 0.01)
		if ratio < 0.8:
			failures.append("domes: %s mass covers only %.0f%% of its room" % [String(role), ratio * 100.0])
		var row: Dictionary = component_by_host.get(host, {})
		if row.is_empty() or String(row.get("form", "")) != "revolved" \
				or int(row.get("triangles", 0)) < 1:
			failures.append("domes: %s has no real revolved geometry" % String(role))
		else:
			var emitted_bounds: AABB = MassBuilder.component_aabb(row)
			if emitted_bounds.position.distance_to(dome_mass.position) > 0.001 \
					or emitted_bounds.size.distance_to(dome_mass.size) > 0.001:
				failures.append("domes: %s emitted envelope does not match its mass" % String(role))
			var profile: PackedVector2Array = row.get("profile", PackedVector2Array())
			var rows := profile.size() - 1
			var expected := int(row.get("segments", 0)) * rows * 2
			if rows < 1 or int(row.get("triangles", 0)) < expected:
				failures.append("domes: %s revolved shell emitted too few profile triangles" % String(role))
			stats["dome_%s_coverage" % String(role)] = snappedf(ratio, 0.001)


## Verify the dome shell itself. Its mass AABB and component row can both stay
## intact when triangles are lost, so sample elevated points on the actual
## roof surface above the flat panel plane. The sample ring avoids the small
## crown oculi by staying well outside their radii.
func _check_dome_mesh_support(plan: HousePlan, builder: HammamBuilder,
		_nav_report: Dictionary) -> void:
	# This rule extends the emitted-geometry contract only when a builder was
	# supplied. Plan-only callers retain their existing behavior.
	if builder == null:
		return
	if builder.emitted_mesh == null:
		failures.append("dome_mesh_support: no emitted mesh is available")
		return
	var mesh: ArrayMesh = builder.emitted_mesh
	if HouseBuilder.SURF_ROOF >= mesh.get_surface_count():
		failures.append("dome_mesh_support: roof surface is missing")
		return
	var triangles := _surface_triangles(mesh, HouseBuilder.SURF_ROOF)
	if triangles.is_empty():
		failures.append("dome_mesh_support: roof surface has no triangles")
		return
	var rise := minf(plan.spec.height * 0.30, 2.4)
	var base_y := plan.spec.height
	var roles: Array[StringName] = [&"cold", &"warm", &"hot"]
	var samples := 8
	var ring_radius := 0.72
	for role in roles:
		if not _station_ids.has(role) or int(_station_ids[role]) < 0:
			continue
		var room := HouseGeometry.room_floor_rect(plan, int(_station_ids[role]))
		var rx := room.size.x * 0.51
		var rz := room.size.y * 0.51
		var centre := room.get_center()
		var supported := 0
		for sample in range(samples):
			var angle := TAU * float(sample) / float(samples)
			var point := centre + Vector2(cos(angle) * rx * ring_radius,
				sin(angle) * rz * ring_radius)
			var start := Vector3(point.x, base_y + rise + 0.3, point.y)
			var end := Vector3(point.x, base_y + rise * 0.2, point.y)
			if _ray_hits_roof(triangles, start, end):
				supported += 1
		stats["dome_%s_mesh_support" % String(role)] = "%d/%d" % [supported, samples]
		if supported != samples:
			failures.append("dome_mesh_support: %s dome supports %d/%d elevated roof probes" %
				[String(role), supported, samples])


static func _surface_triangles(mesh: ArrayMesh, surface: int) -> Array:
	var out: Array = []
	var arrays: Array = mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index_value: Variant = arrays[Mesh.ARRAY_INDEX]
	var indices: PackedInt32Array = index_value if index_value != null else PackedInt32Array()
	if indices.is_empty():
		for i in range(0, vertices.size() - 2, 3):
			out.append([vertices[i], vertices[i + 1], vertices[i + 2]])
	else:
		for i in range(0, indices.size() - 2, 3):
			if indices[i] < vertices.size() and indices[i + 1] < vertices.size() \
					and indices[i + 2] < vertices.size():
				out.append([vertices[indices[i]], vertices[indices[i + 1]],
					vertices[indices[i + 2]]])
	return out


static func _ray_hits_roof(triangles: Array, start: Vector3, end: Vector3) -> bool:
	for triangle in triangles:
		if Geometry3D.segment_intersects_triangle(start, end,
				triangle[0], triangle[1], triangle[2]) != null:
			return true
	return false


func _check_furnace(plan: HousePlan, builder: HammamBuilder,
		_nav_report: Dictionary) -> void:
	if builder == null or builder.furnace_aabb.size == Vector3.ZERO:
		failures.append("furnace: no emitted furnace mass")
		return
	var site := HouseGeometry.site_rect(plan.spec)
	var furnace_mass := AABB()
	for mass in builder.mass_log:
		if String(mass.get("name", "")) == "furnace":
			furnace_mass = mass["aabb"]
			break
	if furnace_mass.size == Vector3.ZERO:
		failures.append("furnace: furnace is absent from the structural mass log")
		return
	if furnace_mass.position.distance_to(builder.furnace_aabb.position) > 0.001 \
			or furnace_mass.size.distance_to(builder.furnace_aabb.size) > 0.001:
		failures.append("furnace: emitted body and structural mass disagree")
	var furnace_component := {}
	for component in builder.component_log:
		if String(component.get("role", "")) == "furnace_body":
			furnace_component = component
			break
	if furnace_component.is_empty():
		failures.append("furnace: emitted body component is missing")
	else:
		var component_box: AABB = MassBuilder.component_aabb(furnace_component)
		if component_box.position.distance_to(builder.furnace_aabb.position) > 0.001 \
				or component_box.size.distance_to(builder.furnace_aabb.size) > 0.001:
			failures.append("furnace: emitted body component does not match its logged mass")
	if builder.furnace_aabb.position.z < site.end.y - 0.01:
		failures.append("furnace: furnace is not beyond the hot far wall")
	var touches_wall := false
	for mass in builder.mass_log:
		if not String(mass.get("name", "")).begins_with("wall_"):
			continue
		var wall: AABB = mass["aabb"]
		var x_overlap := minf(wall.position.x + wall.size.x,
			builder.furnace_aabb.position.x + builder.furnace_aabb.size.x) \
			- maxf(wall.position.x, builder.furnace_aabb.position.x)
		var y_overlap := minf(wall.position.y + wall.size.y,
			builder.furnace_aabb.position.y + builder.furnace_aabb.size.y) \
			- maxf(wall.position.y, builder.furnace_aabb.position.y)
		var furnace_end_z := builder.furnace_aabb.position.z + builder.furnace_aabb.size.z
		var wall_end_z := wall.position.z + wall.size.z
		var z_gap := maxf(maxf(wall.position.z - furnace_end_z,
			builder.furnace_aabb.position.z - wall_end_z), 0.0)
		if x_overlap > 0.1 and y_overlap > 0.1 and z_gap <= 0.03:
			touches_wall = true
			break
	if not touches_wall:
		failures.append("furnace: service furnace does not touch the hot far wall")
	for door in plan.doors:
		if bool(door.get("exterior", false)) and Vector2(door["pos"]).y > site.get_center().y:
			failures.append("furnace: furnace side has a walkable exterior door")
			break


func _room_walk_distances(plan: HousePlan) -> Dictionary:
	var out := {}
	if _nav == null or _nav._grid == null:
		return out
	for station in STATIONS:
		if not _station_ids.has(station) or int(_station_ids[station]) < 0:
			continue
		var room := int(_station_ids[station])
		var centre := HouseGeometry.room_floor_rect(plan, room).get_center()
		out[String(station)] = _nav._grid.distance_to(centre)
	return out


func _oculus_counts(builder: HammamBuilder) -> Dictionary:
	var counts := {"warm": 0, "hot": 0}
	if builder == null:
		return counts
	for opening in builder.roof_opening_log:
		if StringName(opening.get("kind", &"")) != &"oculus":
			continue
		var role := StringName()
		for station in [&"warm", &"hot"]:
			if int(opening.get("room", -1)) == int(_station_ids.get(station, -2)):
				role = station
				break
		if role != &"":
			counts[String(role)] = int(counts[String(role)]) + 1
	return counts


func _room_ids(plan: HousePlan) -> Dictionary:
	var out := {}
	for i in range(plan.rooms.size()):
		var role := StringName(plan.rooms[i].get("role", &""))
		if role not in STATIONS:
			continue
		if out.has(role):
			out[role] = -1 # duplicates cannot masquerade as one station
			continue
		out[role] = i
	return out


func _has_invalid_station() -> bool:
	for station in STATIONS:
		if int(_station_ids.get(station, -1)) < 0:
			return true
	return false


static func _pair(a: int, b: int) -> String:
	return "%d|%d" % [mini(a, b), maxi(a, b)]
