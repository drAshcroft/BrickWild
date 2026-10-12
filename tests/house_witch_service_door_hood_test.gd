extends SceneTree
## Measured shell contract for the Witch service-yard door hood.

const HOOD_ROLE := "witch_service_door_hood"
const CORBEL_ROLE := "witch_service_door_corbel"
var failures: Array[String] = []

func _init() -> void:
	var spec := HouseSpec.new()
	spec.style = &"witch_hut"
	spec.width = 9.0
	spec.length = 12.0
	spec.height = 2.6
	spec.storeys = 1
	spec.exterior_props = false
	var plan: HousePlan = HouseGenerator.generate(spec, 8102, false)
	if plan == null:
		failures.append("frozen Witch service plan did not generate")
		_finish()
		return
	var service_door: Dictionary = {}
	for door in plan.doors:
		if bool(door.get("witch_workshop_yard", false)) and bool(door.get("exterior", false)):
			service_door = door
			break
	if service_door.is_empty():
		failures.append("frozen plan has no real exterior Workshop-to-yard door")
		_finish()
		return
	var builder := HouseBuilder.new()
	var mesh: ArrayMesh = builder.build(plan, true)
	var hood := _component(builder, HOOD_ROLE)
	var corbels: Array[Dictionary] = []
	for row in builder.component_log:
		if String(row.get("role", "")) == CORBEL_ROLE:
			corbels.append(row)
	if hood.is_empty() or corbels.size() != 2:
		failures.append("expected one service hood and two corbels; found hood=%s corbels=%d" % [
			not hood.is_empty(), corbels.size()])
		_finish()
		return
	var trim: PackedVector3Array = mesh.surface_get_arrays(HouseBuilder.SURF_TRIM)[Mesh.ARRAY_VERTEX]
	var wall: PackedVector3Array = mesh.surface_get_arrays(HouseBuilder.SURF_WALL)[Mesh.ARRAY_VERTEX]
	var door_pos: Vector2 = service_door["pos"]
	var normal: Vector2 = Vector2(service_door["normal"]).normalized()
	var tangent := Vector2(normal.y, -normal.x)
	var wall_face := door_pos + normal * HouseGeometry.wall_thickness(spec)
	var aperture_half := float(service_door["width"]) * 0.5
	var head := float(service_door.get("head", HouseGeometry.DOOR_H))
	var door_probe := Vector3(door_pos.x + normal.x * HouseGeometry.wall_thickness(spec) * 0.5,
		HouseGeometry.DOOR_H * 0.5,
		door_pos.y + normal.y * HouseGeometry.wall_thickness(spec) * 0.5)
	if _point_mesh_distance(door_probe, wall) < 0.20:
		failures.append("service door aperture was filled by hood geometry")
	if String(hood.get("host", "")) == "" or not _emitted(hood, trim):
		failures.append("hood is not emitted in the named trim host")
	var hood_bounds: AABB = MassBuilder.component_aabb(hood)
	for corbel in corbels:
		if corbel.get("host", "") != hood.get("host", "") or not _emitted(corbel, trim):
			failures.append("corbel lost its door host or emitted trim triangles")
		if not MassBuilder.component_aabb(corbel).intersects(hood_bounds):
			failures.append("corbel does not bear on the hood")
		var points := _vertices(corbel)
		var face_contact := false
		var tangent_side := 0.0
		for point in points:
			var p2 := Vector2(point.x, point.z)
			if absf((p2 - wall_face).dot(normal)) <= 0.025 and point.y < head + 0.03:
				face_contact = true
			if absf((p2 - door_pos).dot(tangent)) > aperture_half + 0.02:
				tangent_side = signf((p2 - door_pos).dot(tangent))
		if not face_contact or tangent_side == 0.0:
			failures.append("corbel misses its real wall bearing or intrudes into the doorway")
		var across3 := Vector3(tangent.x, 0.0, tangent.y)
		var anchor := Vector3(wall_face.x, head - 0.12, wall_face.y) \
			+ across3 * tangent_side * (aperture_half + 0.15)
		if _point_mesh_distance(anchor, wall) > 0.015:
			failures.append("corbel wall end has no contact with the emitted exterior wall")
	if corbels.size() == 2:
		var side_a := _corbel_side(corbels[0], door_pos, tangent)
		var side_b := _corbel_side(corbels[1], door_pos, tangent)
		if side_a == 0.0 or side_b == 0.0 or side_a == side_b:
			failures.append("corbels do not flank opposite sides of the opening")
	var hood_bottom := hood_bounds.position.y
	if hood_bottom < head + 0.08:
		failures.append("hood underside leaves insufficient head clearance")
	print("WITCH_SERVICE_DOOR_HOOD host=", hood.get("host", ""), " wall_face=", wall_face,
		" aperture_half=", aperture_half, " hood_bottom=", hood_bottom,
		" corbels=", corbels.size(), " checks_complete")
	_finish()

func _component(builder: HouseBuilder, role: String) -> Dictionary:
	for row in builder.component_log:
		if String(row.get("role", "")) == role:
			return row
	return {}

func _emitted(row: Dictionary, surface: PackedVector3Array) -> bool:
	var vertices := _vertices(row)
	return not vertices.is_empty() and ComponentCheck.contains_triangles(surface, vertices)

func _vertices(row: Dictionary) -> PackedVector3Array:
	var kit := MeshKit.new(1)
	if String(row.get("form", "")) == "box":
		kit.oriented_box(row["size"], row["xf"], 0)
	var mesh: ArrayMesh = kit.commit()
	if mesh.get_surface_count() == 0:
		return PackedVector3Array()
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]

func _corbel_side(row: Dictionary, door_pos: Vector2, tangent: Vector2) -> float:
	var side := 0.0
	for point in _vertices(row):
		var projection := (Vector2(point.x, point.z) - door_pos).dot(tangent)
		if absf(projection) > float(row["size"].x):
			side = signf(projection)
	return side

func _point_mesh_distance(point: Vector3, vertices: PackedVector3Array) -> float:
	if vertices.is_empty() or vertices.size() % 3 != 0:
		return INF
	var closest := INF
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
				closest = minf(closest, absf((point - a).dot(normal)))
		closest = minf(closest, _point_segment_distance(point, a, b))
		closest = minf(closest, _point_segment_distance(point, b, c))
		closest = minf(closest, _point_segment_distance(point, c, a))
	return closest

func _point_segment_distance(point: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	if ab.length_squared() < 0.0000001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return point.distance_to(a + ab * t)

func _finish() -> void:
	for failure in failures:
		printerr("FAIL ", failure)
	print("Witch service door hood contract: ", failures.size(), " failures")
	quit(1 if not failures.is_empty() else 0)
