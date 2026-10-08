extends SceneTree
## Independently checks emitted porch-roof triangles against the true shell
## exterior face, cardinal door normals and the planned site envelope.

const CASES := [
	{"label": "farmhouse 8102 front", "style": &"farmhouse", "seed": 8102,
		"normal": Vector2(0, -1)},
	{"label": "west-facing entrance", "style": &"farmhouse", "seed": 8102,
		"normal": Vector2(-1, 0)},
	{"label": "east-facing entrance", "style": &"farmhouse", "seed": 8102,
		"normal": Vector2(1, 0)},
	{"label": "rear-facing entrance", "style": &"farmhouse", "seed": 8102,
		"normal": Vector2(0, 1)},
]

var failures: Array[String] = []


func _init() -> void:
	for fixture in CASES:
		_check_case(fixture)
	for failure in failures:
		push_error(failure)
	print("porch roof room clearance: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _check_case(fixture: Dictionary) -> void:
	var spec := HouseSpec.new()
	spec.style = StringName(fixture["style"])
	spec.width = 9.0
	spec.length = 12.0
	spec.height = 2.6
	spec.porch = true
	var plan: HousePlan = HouseGenerator.generate(spec, int(fixture["seed"]), false)
	var door_index: int = plan.entrance()
	if door_index < 0:
		failures.append("%s has no entrance door" % fixture["label"])
		return
	var door: Dictionary = plan.doors[door_index].duplicate(true)
	var normal: Vector2 = Vector2(fixture["normal"]).normalized()
	var inner := HouseGeometry.interior_rect(spec)
	var door_pos := Vector2(door["pos"])
	if absf(normal.x) > 0.5:
		door_pos.x = inner.position.x if normal.x < 0.0 else inner.end.x
	else:
		door_pos.y = inner.position.y if normal.y < 0.0 else inner.end.y
	door["pos"] = door_pos
	door["normal"] = normal
	plan.doors[door_index] = door

	var builder := HouseBuilder.new()
	var mesh: ArrayMesh = builder.build(plan, true)
	var roof: Dictionary = {}
	for row in builder.component_log:
		if String(row.get("role", "")) == "porch_roof":
			roof = row
			break
	if roof.is_empty():
		failures.append("%s emitted no porch_roof component" % fixture["label"])
		return
	if String(roof.get("host", "")) != "porch":
		failures.append("%s porch_roof lost its component host" % fixture["label"])
		return

	var actual_vertices := _emitted_roof_vertices(roof)
	if actual_vertices.is_empty():
		failures.append("%s porch roof produced no triangles" % fixture["label"])
		return
	var recorded_bounds: AABB = MassBuilder.component_aabb(roof).grow(0.001)
	for point in actual_vertices:
		if not recorded_bounds.has_point(point):
			failures.append("%s porch_roof AABB omits emitted slab thickness" % fixture["label"])
			break
	var roof_surface: PackedVector3Array = mesh.surface_get_arrays(
		HouseBuilder.SURF_ROOF)[Mesh.ARRAY_VERTEX]
	if not ComponentCheck.contains_triangles(roof_surface, actual_vertices):
		failures.append("%s porch_roof component does not match emitted mesh triangles" % fixture["label"])
	var wall_t: float = HouseGeometry.wall_thickness(spec)
	var exterior_face: Vector2 = door_pos + normal * wall_t
	var outer_end: Vector2 = door_pos + normal * (HouseGeometry.porch_depth(spec) + 0.1)
	if not _vertices_clear_of_shell(actual_vertices, normal, exterior_face,
			outer_end, HouseGeometry.exterior_bounds(plan)):
		failures.append("%s porch_roof penetrates the room or leaves its planned site bounds" % fixture["label"])

	# A deliberate 20 cm inward translation must be caught by the same actual-
	# triangle predicate. This proves the test can reject a penetrating canopy.
	var corrupted: Dictionary = roof.duplicate(true)
	var corrupted_xf: Transform3D = corrupted["xf"]
	corrupted_xf.origin -= Vector3(normal.x, 0.0, normal.y) * 0.2
	corrupted["xf"] = corrupted_xf
	var bad_vertices := _emitted_roof_vertices(corrupted)
	if _vertices_clear_of_shell(bad_vertices, normal, exterior_face, outer_end,
			HouseGeometry.exterior_bounds(plan)):
		failures.append("%s injected inward canopy was not rejected" % fixture["label"])


func _emitted_roof_vertices(row: Dictionary) -> PackedVector3Array:
	var kit := MeshKit.new(1)
	kit.ridge_roof(row["xf"], float(row["span"]), float(row["along"]),
		float(row["rise"]), 0)
	var isolated: ArrayMesh = kit.commit()
	if isolated.get_surface_count() == 0:
		return PackedVector3Array()
	return isolated.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]


func _vertices_clear_of_shell(vertices: PackedVector3Array, normal: Vector2,
		exterior_face: Vector2, outer_end: Vector2, bounds: AABB) -> bool:
	var min_out: float = INF
	var max_out: float = -INF
	for point in vertices:
		var out: float = Vector2(point.x, point.z).dot(normal)
		min_out = minf(min_out, out)
		max_out = maxf(max_out, out)
		if point.x < bounds.position.x - 0.01 or point.x > bounds.end.x + 0.01 \
				or point.y < bounds.position.y - 0.01 or point.y > bounds.end.y + 0.01 \
				or point.z < bounds.position.z - 0.01 or point.z > bounds.end.z + 0.01:
			return false
	var wall_plane: float = exterior_face.dot(normal)
	var porch_end: float = outer_end.dot(normal)
	return min_out >= wall_plane - 0.005 and max_out <= porch_end + 0.005
