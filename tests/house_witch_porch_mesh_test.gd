extends SceneTree
## Staged four-cardinal Witch canopy contract. Run after builder_delta.diff is
## applied to the project source. It checks named parts against the actual mesh.

const CASES := [
	{"label": "front", "normal": Vector2(0, -1)},
	{"label": "rear", "normal": Vector2(0, 1)},
	{"label": "west", "normal": Vector2(-1, 0)},
	{"label": "east", "normal": Vector2(1, 0)},
]
const ROOF_ROLE := "witch_entry_lean_to"
const LEDGER_ROLE := "witch_entry_wall_ledger"
const POST_PREFIX := "witch_entry_support_"
const STEP_ROLE := "witch_entry_step"

var failures: Array[String] = []

func _init() -> void:
	for fixture in CASES:
		_check_case(fixture)
	for failure in failures:
		printerr("FAIL ", failure)
	print("Witch porch mesh contract: ", failures.size(), " failures")
	quit(1 if not failures.is_empty() else 0)

func _check_case(fixture: Dictionary) -> void:
	var spec := HouseSpec.new()
	spec.style = &"witch_hut"
	spec.width = 9.0
	spec.length = 12.0
	spec.height = 2.6
	spec.storeys = 1
	spec.exterior_props = false
	var plan: HousePlan = HouseGenerator.generate(spec, 8102, false)
	if plan == null:
		failures.append("%s: Witch plan did not generate" % fixture["label"])
		return
	spec.porch = true
	var door_index := plan.entrance()
	if door_index < 0:
		failures.append("%s: no entrance door" % fixture["label"])
		return
	var normal: Vector2 = Vector2(fixture["normal"]).normalized()
	var placement := _cardinal_door(plan, door_index, normal)
	if placement.is_empty():
		failures.append("%s: no margin-safe door station on a real exterior wall" % fixture["label"])
		return
	var door: Dictionary = placement["door"]
	var door_pos: Vector2 = Vector2(door["pos"])
	plan.doors[door_index] = door
	if plan.entrance() != door_index or int(door.get("a", -1)) != int(placement["room"]) \
			 or int(door.get("b", -2)) != -1 or not bool(door.get("exterior", false)):
		failures.append("%s: cardinal entrance lost its true exterior room owner" % fixture["label"])
	var owner_floor: Rect2 = placement["owner_floor"]
	var inside_threshold := HouseGeometry.door_threshold(door, -1.0)
	var outside_threshold := HouseGeometry.door_threshold(door, 1.0)
	if not owner_floor.grow(0.02).has_point(inside_threshold) or (inside_threshold - door_pos).dot(normal) >= 0.0:
		failures.append("%s: entrance has no inward threshold in its owning room" % fixture["label"])
	if (outside_threshold - door_pos).dot(normal) <= 0.0 or HouseGeometry.interior_rect(spec).has_point(outside_threshold):
		failures.append("%s: exterior approach threshold is not outside the house" % fixture["label"])
	var tangent: Vector2 = Vector2(normal.y, -normal.x)
	var owner_tangent_min := INF
	for corner in [owner_floor.position, Vector2(owner_floor.end.x, owner_floor.position.y), owner_floor.end, Vector2(owner_floor.position.x, owner_floor.end.y)]:
		var projection: float = corner.dot(tangent)
		owner_tangent_min = minf(owner_tangent_min, projection)
	var porch_half_width_check := (float(door["width"]) + 1.1) * 0.5
	if not _porch_fits_owner_margin(door, owner_floor):
		failures.append("%s: porch footprint lacks its stated 30 mm margin inside the real wall-host room" % fixture["label"])
	var near_corner_door: Dictionary = door.duplicate(true)
	var corner_station: float = owner_tangent_min + porch_half_width_check + 0.01 - 0.24
	var corner_pos: Vector2 = door_pos + tangent * (corner_station - door_pos.dot(tangent))
	near_corner_door["pos"] = corner_pos
	if _porch_fits_owner_margin(near_corner_door, owner_floor):
		failures.append("%s: porch crossing the 30 mm near-corner margin passed the independent footprint control" % fixture["label"])

	var builder := HouseBuilder.new()
	var mesh: ArrayMesh = builder.build(plan, true)
	var roof := _component(builder, ROOF_ROLE)
	var step := _component(builder, STEP_ROLE)
	var ledger := _component(builder, LEDGER_ROLE)
	var posts: Array[Dictionary] = []
	for row in builder.component_log:
		if String(row.get("role", "")).begins_with(POST_PREFIX):
			posts.append(row)
	if roof.is_empty() or ledger.is_empty() or step.is_empty() or posts.size() != 2:
		failures.append("%s: expected named roof, wall ledger, step, and two supports; got roof=%s ledger=%s step=%s posts=%d" % [
			fixture["label"], not roof.is_empty(), not ledger.is_empty(), not step.is_empty(), posts.size()])
		return
	if String(roof.get("host", "")) != "porch" or String(step.get("host", "")) != "porch":
		failures.append("%s: porch components lost their named host" % fixture["label"])
	var roof_triangles := _component_vertices(roof)
	var actual_highest := -INF
	for point in roof_triangles:
		actual_highest = maxf(actual_highest, point.y)
	if actual_highest > spec.height - 0.015:
		failures.append("%s: full canopy slab rises above the wall-eave profile" % fixture["label"])
	var roof_surface: PackedVector3Array = mesh.surface_get_arrays(HouseBuilder.SURF_ROOF)[Mesh.ARRAY_VERTEX]
	if roof_triangles.is_empty() or not ComponentCheck.contains_triangles(roof_surface, roof_triangles):
		failures.append("%s: named canopy triangles are absent from the emitted roof mesh" % fixture["label"])
	var recorded: AABB = MassBuilder.component_aabb(roof).grow(0.001)
	for point in roof_triangles:
		if not recorded.has_point(point):
			failures.append("%s: roof component bound omits actual slab thickness" % fixture["label"])
			break
	var wall_t := HouseGeometry.wall_thickness(spec)
	var porch_centre := HouseGeometry.porch_center(plan)
	var across_width := Vector2(normal.y, -normal.x)
	var porch_half_width := (float(door["width"]) + 1.1) * 0.5
	var face := door_pos + normal * wall_t
	var outer_end := door_pos + normal * (HouseGeometry.porch_depth(spec) + 0.1)
	if not _clear_of_shell(roof_triangles, normal, face, outer_end, HouseGeometry.exterior_bounds(plan)):
		failures.append("%s: actual canopy triangles cross the exterior face or porch bound" % fixture["label"])
	var roof_within_tangent := _within_porch_tangent(roof_triangles, porch_centre, across_width, porch_half_width)
	var step_vertices := _component_vertices(step)
	var step_within_tangent := _within_porch_tangent(step_vertices, porch_centre, across_width, porch_half_width)
	if not roof_within_tangent or not step_within_tangent:
		failures.append("%s: roof or step exceeds shifted porch_center tangent envelope" % fixture["label"])
	var wall_vertices: PackedVector3Array = mesh.surface_get_arrays(HouseBuilder.SURF_WALL)[Mesh.ARRAY_VERTEX]
	var trim_surface: PackedVector3Array = mesh.surface_get_arrays(HouseBuilder.SURF_TRIM)[Mesh.ARRAY_VERTEX]
	var ledger_triangles := _component_vertices(ledger)
	if ledger_triangles.is_empty() or not ComponentCheck.contains_triangles(trim_surface, ledger_triangles):
		failures.append("%s: named wall ledger is absent from emitted trim mesh" % fixture["label"])
	if not _ledger_wall_contact(ledger, wall_vertices, 0.005):
		failures.append("%s: ledger inner face is detached from actual exterior wall mesh" % fixture["label"])
	if not _ledger_roof_contact(ledger, roof, normal, 0.005):
		failures.append("%s: ledger top does not bear on the actual canopy slab" % fixture["label"])
	var lifted_roof: Dictionary = roof.duplicate(true)
	var lifted_points: PackedVector3Array = lifted_roof["points"]
	for point_index in range(lifted_points.size()):
		lifted_points[point_index] += Vector3.UP * 0.02
	lifted_roof["points"] = lifted_points
	if _ledger_roof_contact(ledger, lifted_roof, normal, 0.005):
		failures.append("%s: 20 mm vertically lifted canopy negative still passes ledger bearing" % fixture["label"])
	var detached_ledger: Dictionary = ledger.duplicate(true)
	var detached_xf: Transform3D = detached_ledger["xf"]
	detached_xf.origin += Vector3(normal.x, 0.0, normal.y) * 0.02
	detached_ledger["xf"] = detached_xf
	if _ledger_wall_contact(detached_ledger, wall_vertices, 0.005):
		failures.append("%s: 20 mm outward-shifted ledger still passes wall bearing" % fixture["label"])
	var face_sample := door_pos + normal * (wall_t + 0.03)
	var face_heights := _heights_at(roof_surface, face_sample)
	if face_heights.is_empty() or face_heights.min() < HouseGeometry.DOOR_H + 0.25:
		failures.append("%s: actual roof underside leaves less than 25 cm above the door head" % fixture["label"])

	var step_bounds: AABB = MassBuilder.component_aabb(step)
	for post in posts:
		var post_vertices := _component_vertices(post)
		if not _within_porch_tangent(post_vertices, porch_centre, across_width, porch_half_width):
			failures.append("%s: %s exceeds shifted porch_center tangent envelope" % [fixture["label"], post.get("role", "support")])
		var post_surface: PackedVector3Array = mesh.surface_get_arrays(HouseBuilder.SURF_TRIM)[Mesh.ARRAY_VERTEX]
		if post_vertices.is_empty() or not ComponentCheck.contains_triangles(post_surface, post_vertices):
			failures.append("%s: named support is absent from emitted trim mesh" % fixture["label"])
			continue
		var post_bounds: AABB = MassBuilder.component_aabb(post)
		if absf(post_bounds.position.y) > 0.002 or post_bounds.end.y <= HouseGeometry.FLOOR_T:
			failures.append("%s: support does not reach the ground through the porch floor slab" % fixture["label"])
		if not post_bounds.intersects(step_bounds):
			failures.append("%s: support does not intersect the emitted porch step" % fixture["label"])
		var post_xf: Transform3D = post["xf"]
		var post_size: Vector3 = post["size"]
		var post_centre: Vector3 = post_xf * Vector3.ZERO
		var post_top: float = post_centre.y + post_size.y * 0.5
		var contact_heights := _heights_at(roof_surface, Vector2(post_centre.x, post_centre.z))
		if contact_heights.is_empty() or absf(post_top - contact_heights.min()) > 0.005:
			failures.append("%s: %s does not meet the actual roof slab underside within 5 mm" % [fixture["label"], post["role"]])
		var lowered: Dictionary = post.duplicate(true)
		var lowered_size: Vector3 = lowered["size"]
		var lowered_top: float = lowered_size.y - 0.10
		if lowered_top <= 0.0:
			failures.append("%s: support is too short for the lowered-post negative" % fixture["label"])
			continue
		lowered_size.y = lowered_top
		lowered["size"] = lowered_size
		var lowered_xf: Transform3D = lowered["xf"]
		lowered_xf.origin.y = lowered_top * 0.5
		lowered["xf"] = lowered_xf
		var lowered_vertices := _component_vertices(lowered)
		var lowered_mesh_top := -INF
		for point in lowered_vertices:
			lowered_mesh_top = maxf(lowered_mesh_top, point.y)
		var lowered_centre: Vector3 = lowered_xf * Vector3.ZERO
		var lower_heights := _heights_at(roof_surface, Vector2(lowered_centre.x, lowered_centre.z))
		if not lower_heights.is_empty() and lowered_mesh_top >= lower_heights.min() - 0.005:
			failures.append("%s: lowered-support mesh negative still touches the roof" % fixture["label"])

	# Recreate the old canopy datum exactly: door position plus d/2, length d+0.2.
	# Its near edge is -0.1 m, inside the door datum and 0.45 m inside the wall face.
	var old_along := HouseGeometry.porch_depth(spec) + 0.2
	var old_head := HouseGeometry.DOOR_H + 0.35
	var across: Vector2 = Vector2(normal.y, -normal.x)
	var frame := Basis(Vector3(across.x, 0.0, across.y), Vector3.UP, Vector3(normal.x, 0.0, normal.y))
	var old_centre2 := door_pos + normal * (HouseGeometry.porch_depth(spec) * 0.5)
	var old_xf := Transform3D(frame, Vector3(old_centre2.x, old_head, old_centre2.y))
	var old_roof: Dictionary = roof.duplicate(true)
	old_roof["points"] = PackedVector3Array([
		old_xf * Vector3(-float(door["width"]) * 0.5 - 1.1 * 0.5, 0.42, -old_along * 0.5),
		old_xf * Vector3(float(door["width"]) * 0.5 + 1.1 * 0.5, 0.42, -old_along * 0.5),
		old_xf * Vector3(float(door["width"]) * 0.5 + 1.1 * 0.5, 0.0, old_along * 0.5),
		old_xf * Vector3(-float(door["width"]) * 0.5 - 1.1 * 0.5, 0.0, old_along * 0.5)])
	var old_vertices := _component_vertices(old_roof)
	if _clear_of_shell(old_vertices, normal, face, outer_end, HouseGeometry.exterior_bounds(plan)):
		failures.append("%s: the exact prior inward-canopy geometry passed the clearance predicate" % fixture["label"])
	print("WITCH_PORCH_CARDINAL ", fixture["label"], " door=", door_pos,
		" room=", placement["room"], " room_floor=", owner_floor,
		" margin=0.03m roof_vertices=", roof_triangles.size(),
		" roof_host=", roof["host"], " supports=", posts.size(), " checks_complete")

func _cardinal_door(plan: HousePlan, door_index: int, normal: Vector2) -> Dictionary:
	var spec: HouseSpec = plan.spec
	var shell_run: Dictionary = {}
	for run in HouseGeometry.exterior_runs(spec):
		if Vector2(run["normal"]).dot(normal) > 0.999:
			shell_run = run
			break
	if shell_run.is_empty():
		return {}
	var run_from: Vector2 = shell_run["from"]
	var run_to: Vector2 = shell_run["to"]
	var run_dir: Vector2 = (run_to - run_from).normalized()
	var run_length: float = run_from.distance_to(run_to)
	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	var door: Dictionary = plan.doors[door_index].duplicate(true)
	var door_width: float = float(door["width"])
	var porch_half: float = (door_width + 1.1) * 0.5
	var margin: float = 0.05
	var window_clear: float = porch_half + margin
	var blockers: Array[Vector2] = []
	for window in plan.windows:
		if int(window.get("storey", 0)) != 0 or Vector2(window.get("normal", Vector2.ZERO)).dot(normal) < 0.999:
			continue
		var window_pos: Vector2 = window["pos"]
		if absf((window_pos - run_from).dot(normal)) > HouseGeometry.wall_thickness(spec) + 0.10:
			continue
		var window_station: float = (window_pos - run_from).dot(run_dir)
		var window_half: float = window_clear + float(window.get("width", 0.0)) * 0.5
		blockers.append(Vector2(window_station - window_half, window_station + window_half))
	for other_index in range(plan.doors.size()):
		if other_index == door_index:
			continue
		var other: Dictionary = plan.doors[other_index]
		if not bool(other.get("exterior", false)) or Vector2(other.get("normal", Vector2.ZERO)).dot(normal) < 0.999:
			continue
		var other_pos: Vector2 = other["pos"]
		if absf((other_pos - run_from).dot(normal)) > HouseGeometry.wall_thickness(spec) + 0.10:
			continue
		var other_station: float = (other_pos - run_from).dot(run_dir)
		var other_half: float = window_clear + float(other.get("width", 0.0)) * 0.5
		blockers.append(Vector2(other_station - other_half, other_station + other_half))
	var best_room := -1
	var best_station := 0.0
	var best_distance := INF
	var best_floor := Rect2()
	for room_index in range(plan.room_count()):
		if HousePlan.record_storey(plan.rooms[room_index]) != 0:
			continue
		var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room_index)
		var actual_edge: float
		var expected_edge: float
		if absf(normal.x) > 0.5:
			actual_edge = floor_rect.position.x if normal.x < 0.0 else floor_rect.end.x
			expected_edge = inner.position.x if normal.x < 0.0 else inner.end.x
		else:
			actual_edge = floor_rect.position.y if normal.y < 0.0 else floor_rect.end.y
			expected_edge = inner.position.y if normal.y < 0.0 else inner.end.y
		if absf(actual_edge - expected_edge) > 0.02:
			continue
		var owner_lo := INF
		var owner_hi := -INF
		for corner in [floor_rect.position, Vector2(floor_rect.end.x, floor_rect.position.y), floor_rect.end, Vector2(floor_rect.position.x, floor_rect.end.y)]:
			var projected: float = (corner - run_from).dot(run_dir)
			owner_lo = minf(owner_lo, projected)
			owner_hi = maxf(owner_hi, projected)
		var lo: float = maxf(owner_lo, 0.0) + porch_half + 0.24 + margin
		var hi: float = minf(owner_hi, run_length) - porch_half - 0.24 - margin
		if hi < lo:
			continue
		var steps := int(floor((hi - lo) / 0.05)) + 1
		var midpoint: float = (lo + hi) * 0.5
		for step_index in range(steps):
			var candidate: float = lo + float(step_index) * 0.05
			var blocked := false
			for span in blockers:
				if candidate >= span.x and candidate <= span.y:
					blocked = true
					break
			if blocked:
				continue
			var score: float = absf(candidate - midpoint)
			if score < best_distance:
				best_distance = score
				best_room = room_index
				best_station = candidate
				best_floor = floor_rect
	if best_room < 0:
		return {}
	# Exterior runs are wall centre-lines; plan doors are on the inner face.
	door["pos"] = run_from + run_dir * best_station - normal * HouseGeometry.wall_thickness(spec) * 0.5
	door["normal"] = normal
	door["a"] = best_room
	door["b"] = -1
	door["exterior"] = true
	door["front"] = true
	door["storey"] = 0
	return {"door": door, "room": best_room, "owner_floor": best_floor, "run": shell_run, "station": best_station}

func _porch_fits_owner_margin(door: Dictionary, owner_floor: Rect2) -> bool:
	var normal: Vector2 = Vector2(door["normal"]).normalized()
	var tangent := Vector2(normal.y, -normal.x)
	var centre: Vector2 = Vector2(door["pos"]) + tangent * 0.24
	var half_width: float = (float(door["width"]) + 1.1) * 0.5
	var owner_min := INF
	var owner_max := -INF
	for corner in [owner_floor.position, Vector2(owner_floor.end.x, owner_floor.position.y), owner_floor.end, Vector2(owner_floor.position.x, owner_floor.end.y)]:
		var station: float = corner.dot(tangent)
		owner_min = minf(owner_min, station)
		owner_max = maxf(owner_max, station)
	var centre_station: float = centre.dot(tangent)
	return centre_station - half_width >= owner_min + 0.03 \
		and centre_station + half_width <= owner_max - 0.03

func _ledger_wall_contact(ledger: Dictionary, wall: PackedVector3Array, tolerance: float) -> bool:
	if wall.is_empty():
		return false
	var xf: Transform3D = ledger["xf"]
	var size: Vector3 = ledger["size"]
	for fraction in [-0.3, 0.0, 0.3]:
		var point := xf * Vector3(size.x * fraction, 0.0, -size.z * 0.5)
		if _point_mesh_distance(point, wall) > tolerance:
			return false
	return true

func _ledger_roof_contact(ledger: Dictionary, roof: Dictionary, normal: Vector2, tolerance: float) -> bool:
	var roof_vertices := _component_vertices(roof)
	if roof_vertices.is_empty():
		return false
	var xf: Transform3D = ledger["xf"]
	var size: Vector3 = ledger["size"]
	for fraction in [-0.3, 0.0, 0.3]:
		var point := xf * Vector3(size.x * fraction, size.y * 0.5, size.z * 0.5)
		if _point_mesh_distance(point, roof_vertices) > tolerance:
			return false
	return true

func _component(builder: HouseBuilder, role: String) -> Dictionary:
	for row in builder.component_log:
		if String(row.get("role", "")) == role:
			return row
	return {}

func _component_vertices(row: Dictionary) -> PackedVector3Array:
	var kit := MeshKit.new(1)
	if String(row.get("form", "")) == "box":
		kit.oriented_box(row["size"], row["xf"], 0)
	elif String(row.get("form", "")) == "slab":
		kit.slab_poly(row["points"], float(row["depth"]), 0, bool(row["vertical"]))
	var isolated: ArrayMesh = kit.commit()
	if isolated.get_surface_count() == 0:
		return PackedVector3Array()
	return isolated.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]

func _clear_of_shell(vertices: PackedVector3Array, normal: Vector2, face: Vector2,
		outer_end: Vector2, bounds: AABB) -> bool:
	if vertices.is_empty():
		return false
	var min_out := INF
	var max_out := -INF
	for point in vertices:
		var out := Vector2(point.x, point.z).dot(normal)
		min_out = minf(min_out, out)
		max_out = maxf(max_out, out)
		if point.x < bounds.position.x - 0.01 or point.x > bounds.end.x + 0.01 \
				or point.y < bounds.position.y - 0.01 or point.y > bounds.end.y + 0.01 \
				or point.z < bounds.position.z - 0.01 or point.z > bounds.end.z + 0.01:
			return false
	return min_out >= face.dot(normal) - 0.005 and max_out <= outer_end.dot(normal) + 0.005

func _near_edge_vertices(vertices: PackedVector3Array, normal: Vector2) -> Array[Vector3]:
	var minimum := INF
	for point in vertices:
		minimum = minf(minimum, Vector2(point.x, point.z).dot(normal))
	var out: Array[Vector3] = []
	for point in vertices:
		if Vector2(point.x, point.z).dot(normal) <= minimum + 0.006:
			out.append(point)
	return out

func _main_roof_vertices(builder: HouseBuilder) -> PackedVector3Array:
	var out := PackedVector3Array()
	for row in builder.component_log:
		if String(row.get("host", "")) != "roof":
			continue
		if String(row.get("role", "")) == ROOF_ROLE:
			continue
		out.append_array(_component_vertices(row))
	return out

func _edge_attaches_to_shell(edge: Array[Vector3], wall: PackedVector3Array,
		main_roof: PackedVector3Array, tolerance: float) -> bool:
	if wall.is_empty() and main_roof.is_empty():
		return false
	for point in edge:
		if minf(_point_mesh_distance(point, wall), _point_mesh_distance(point, main_roof)) > tolerance:
			return false
	return true

func _point_mesh_distance(point: Vector3, vertices: PackedVector3Array) -> float:
	if vertices.is_empty() or vertices.size() % 3 != 0:
		return INF
	var best := INF
	for index in range(0, vertices.size(), 3):
		var a: Vector3 = vertices[index]
		var b: Vector3 = vertices[index + 1]
		var c: Vector3 = vertices[index + 2]
		var ab := b - a
		var ac := c - a
		var normal := ab.cross(ac)
		if normal.length_squared() < 0.0000001:
			continue
		normal = normal.normalized()
		var projected := point - normal * (point - a).dot(normal)
		var v0 := ac
		var v1 := ab
		var v2 := projected - a
		var d00 := v0.dot(v0)
		var d01 := v0.dot(v1)
		var d11 := v1.dot(v1)
		var d20 := v2.dot(v0)
		var d21 := v2.dot(v1)
		var denom := d00 * d11 - d01 * d01
		if absf(denom) > 0.0000001:
			var u := (d11 * d20 - d01 * d21) / denom
			var v := (d00 * d21 - d01 * d20) / denom
			if u >= -0.0001 and v >= -0.0001 and u + v <= 1.0001:
				best = minf(best, absf((point - a).dot(normal)))
		best = minf(best, _point_segment_distance(point, a, b))
		best = minf(best, _point_segment_distance(point, b, c))
		best = minf(best, _point_segment_distance(point, c, a))
	return best

func _point_segment_distance(point: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	if ab.length_squared() < 0.0000001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return point.distance_to(a + ab * t)

func _within_porch_tangent(vertices: PackedVector3Array, centre: Vector2, across: Vector2, half_width: float) -> bool:
	if vertices.is_empty():
		return false
	for point in vertices:
		if absf((Vector2(point.x, point.z) - centre).dot(across)) > half_width + 0.005:
			return false
	return true

func _heights_at(vertices: PackedVector3Array, point: Vector2) -> Array[float]:
	var heights: Array[float] = []
	if vertices.size() % 3 != 0:
		return heights
	for index in range(0, vertices.size(), 3):
		var a: Vector3 = vertices[index]
		var b: Vector3 = vertices[index + 1]
		var c: Vector3 = vertices[index + 2]
		var u := Vector2(b.x - a.x, b.z - a.z)
		var v := Vector2(c.x - a.x, c.z - a.z)
		var q := point - Vector2(a.x, a.z)
		var determinant := u.cross(v)
		if absf(determinant) < 0.000001:
			continue
		var s := q.cross(v) / determinant
		var t := u.cross(q) / determinant
		if s < -0.0001 or t < -0.0001 or s + t > 1.0001:
			continue
		heights.append(a.y + s * (b.y - a.y) + t * (c.y - a.y))
	return heights
