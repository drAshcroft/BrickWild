extends SceneTree
## Fixed built-in Witch gable has a real upper casement; ordinary Cottage does not.

const ROLES := ["witch_gable_casement_light", "witch_gable_casement_jamb",
	"witch_gable_casement_head", "witch_gable_casement_sill",
	"witch_gable_casement_shutter", "witch_gable_casement_hinge",
	"witch_gable_flower_box_bottom", "witch_gable_flower_box_front",
	"witch_gable_flower_box_back", "witch_gable_flower_box_end",
	"witch_gable_flower_box_bracket", "witch_gable_flower_box_leaf",
	"witch_gable_flower_box_bloom"]
var failures: Array[String] = []

func _init() -> void:
	var witch_spec := _spec(&"witch_hut")
	var witch_plan: HousePlan = HouseGenerator.generate(witch_spec, 8102, false)
	if witch_plan == null:
		_fail("fixed Witch plan did not generate")
		_finish()
		return
	if witch_spec.roof_type != &"gable":
		_fail("built-in Witch gable draw was resolved to %s" % witch_spec.roof_type)
	# The authored seed normally omits optional frame timber. Turn it on after
	# generation so this fixed fixture proves the opening clears real supports.
	witch_plan.spec.timber_frame = true
	if not witch_plan.spec.timber_frame:
		_fail("fixture failed to enable the measured Witch gable frame")
	var witch_builder := HouseBuilder.new()
	var witch_mesh: ArrayMesh = witch_builder.build(witch_plan, true)
	var lights := _components(witch_builder, "witch_gable_casement_light")
	if lights.size() != 1:
		_fail("expected one measured Witch gable casement, found %d; roof=%s; skip=%s; search=%s" % [
			lights.size(), witch_spec.roof_type, witch_builder.witch_gable_casement_skip_reason,
			JSON.stringify(witch_builder.witch_gable_casement_search_diagnostic)])
	else:
		_check_emitted(witch_builder, witch_mesh)
		_check_actual_opening(witch_plan, witch_mesh, lights[0])
		_check_frame_clearance(witch_plan, witch_builder, lights[0])
		_check_flower_box_bearing(witch_plan, witch_builder, witch_mesh, lights[0])
	_check_cottage_control()
	_finish()

func _spec(style: StringName) -> HouseSpec:
	var spec := HouseSpec.new()
	spec.style = style
	spec.width = 7.0
	spec.length = 9.0
	spec.height = 2.6
	spec.storeys = 1
	spec.exterior_props = false
	return spec

func _components(builder: HouseBuilder, role: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for row in builder.component_log:
		if String(row.get("role", "")) == role:
			rows.append(row)
	return rows

func _check_emitted(builder: HouseBuilder, mesh: ArrayMesh) -> void:
	var expected := {
		"witch_gable_casement_light": [1, HouseBuilder.SURF_ROOF],
		"witch_gable_casement_jamb": [2, HouseBuilder.SURF_TRIM],
		"witch_gable_casement_head": [1, HouseBuilder.SURF_TRIM],
		"witch_gable_casement_sill": [1, HouseBuilder.SURF_TRIM],
		"witch_gable_casement_shutter": [2, HouseBuilder.SURF_TRIM],
		"witch_gable_casement_hinge": [4, HouseBuilder.SURF_TRIM],
		"witch_gable_flower_box_bottom": [1, HouseBuilder.SURF_TRIM],
		"witch_gable_flower_box_front": [1, HouseBuilder.SURF_TRIM],
		"witch_gable_flower_box_back": [1, HouseBuilder.SURF_TRIM],
		"witch_gable_flower_box_end": [2, HouseBuilder.SURF_TRIM],
		"witch_gable_flower_box_bracket": [2, HouseBuilder.SURF_TRIM],
		"witch_gable_flower_box_leaf": [3, HouseBuilder.SURF_TRIM],
		"witch_gable_flower_box_bloom": [3, HouseBuilder.SURF_TRIM],
	}
	for role in expected:
		var rows := _components(builder, role)
		var record: Array = expected[role]
		if rows.size() != int(record[0]):
			_fail("%s expected %d components; got %d" % [role, int(record[0]), rows.size()])
			continue
		var surface: PackedVector3Array = mesh.surface_get_arrays(int(record[1]))[Mesh.ARRAY_VERTEX]
		for row in rows:
			var vertices := _component_vertices(row)
			if vertices.is_empty() or not ComponentCheck.contains_triangles(surface, vertices):
				_fail("%s %s is absent from its emitted mesh surface" % [role, row.get("id", "")])

func _check_actual_opening(plan: HousePlan, mesh: ArrayMesh, light: Dictionary) -> void:
	var layout: Dictionary = HouseGeometry.roof_layout(plan)
	var roof_xf: Transform3D = layout["transform"]
	var light_xf: Transform3D = light["xf"]
	var size: Vector3 = light["size"]
	var aperture_width := size.x + 0.12
	var aperture_height := size.y + 0.12
	if size.x < 0.55 or size.y < 0.55:
		_fail("glazed casement is too small to read: %s" % size)
	var world_center: Vector3 = light_xf.origin
	var local_center: Vector3 = roof_xf.affine_inverse() * world_center
	var outward: Vector3 = (roof_xf.basis * Vector3(0.0, 0.0, -signf(local_center.z))).normalized()
	# The centre and two vertically separated rays pass through the whole wall
	# thickness. Side rays immediately outside the aperture still hit wall mesh.
	var wall_surface: PackedVector3Array = mesh.surface_get_arrays(HouseBuilder.SURF_WALL)[Mesh.ARRAY_VERTEX]
	var wall_depth: float = HouseGeometry.wall_thickness(plan.spec)
	for fraction in [-0.28, 0.0, 0.28]:
		var point: Vector3 = light_xf * Vector3(0.0, float(fraction) * size.y, 0.0)
		var ray_start: Vector3 = point - outward * wall_depth * 0.8
		var ray_end: Vector3 = point + outward * wall_depth * 0.8
		if _ray_hits(wall_surface, ray_start, ray_end):
			_fail("wall triangle blocks a full-thickness ray through the casement")
	var across := light_xf.basis.x.normalized()
	for side in [-1.0, 1.0]:
		var point: Vector3 = world_center + across * float(side) * (aperture_width * 0.5 + 0.06)
		if not _ray_hits(wall_surface, point - outward * wall_depth * 0.8,
				point + outward * wall_depth * 0.8):
			_fail("adjacent measured wall does not remain outside the casement aperture")
	if aperture_height <= 0.55 or aperture_width <= 0.55:
		_fail("measured wall aperture is too small")

func _check_frame_clearance(plan: HousePlan, builder: HouseBuilder, light: Dictionary) -> void:
	var support_vertices := PackedVector3Array()
	var role_counts: Dictionary = {}
	for row in builder.component_log:
		var role: String = String(row.get("role", ""))
		if role in ["witch_kingpost", "witch_collar", "witch_rafter", "witch_gable_raking_brace"]:
			role_counts[role] = int(role_counts.get(role, 0)) + 1
			support_vertices.append_array(_component_vertices(row))
	var layout: Dictionary = HouseGeometry.roof_layout(plan)
	var bay: Dictionary = layout.get("witch_bay", {})
	var roof_xf: Transform3D = layout["transform"]
	var light_xf: Transform3D = light["xf"]
	var local_center: Vector3 = roof_xf.affine_inverse() * light_xf.origin
	var station: float = signf(local_center.z) * (float(layout["along"]) * 0.5 + HouseGeometry.BEAM_D * 0.5 - 0.01)
	var bay_covers_station := not bay.is_empty() and station >= float(bay.get("along_lo", INF)) \
		and station <= float(bay.get("along_hi", -INF))
	print("Witch casement frame roles=", role_counts,
		" front_station=", station, " bay_along=[", bay.get("along_lo", "none"), ", ",
		bay.get("along_hi", "none"), "] covers=", bay_covers_station)
	if support_vertices.is_empty() and not bay_covers_station:
		_fail("no gable frame exists at the casement station and no measured Workshop bay explains it")
		return
	if support_vertices.is_empty():
		return # the Workshop roof occupies this measured end-frame station
	var size: Vector3 = light["size"]
	for x_fraction in [-0.35, 0.0, 0.35]:
		for y_fraction in [-0.35, 0.0, 0.35]:
			var point: Vector3 = light_xf * Vector3(float(x_fraction) * size.x,
				float(y_fraction) * size.y, 0.0)
			if _point_mesh_distance(point, support_vertices) < 0.04:
				_fail("a measured gable support crosses the glazed casement")

func _check_flower_box_bearing(plan: HousePlan, builder: HouseBuilder, mesh: ArrayMesh, light: Dictionary) -> void:
	var layout: Dictionary = HouseGeometry.roof_layout(plan)
	var roof_xf: Transform3D = layout["transform"]
	var light_xf: Transform3D = light["xf"]
	var light_local: Vector3 = roof_xf.affine_inverse() * light_xf.origin
	var hole_bottom: float = light_local.y - float(light["size"].y) * 0.5
	var roles := ["witch_gable_flower_box_bottom", "witch_gable_flower_box_front",
		"witch_gable_flower_box_back", "witch_gable_flower_box_end",
		"witch_gable_flower_box_bracket", "witch_gable_flower_box_leaf",
		"witch_gable_flower_box_bloom"]
	for role in roles:
		for row in _components(builder, role):
			if String(row.get("host", "")) != "roof":
				_fail("%s lost its stable roof host" % role)
			var row_xf: Transform3D = row["xf"]
			var local_center: Vector3 = roof_xf.affine_inverse() * row_xf.origin
			if local_center.y >= hole_bottom - 0.04:
				_fail("%s intrudes into the measured casement sill/aperture zone" % role)
	var back := _components(builder, "witch_gable_flower_box_back")
	if back.size() == 1:
		var back_vertices := _component_vertices(back[0])
		var wall: PackedVector3Array = mesh.surface_get_arrays(HouseBuilder.SURF_WALL)[Mesh.ARRAY_VERTEX]
		var closest := INF
		for point in back_vertices:
			for triangle_index in range(0, wall.size(), 3):
				closest = minf(closest, _point_triangle_distance(point,
					wall[triangle_index], wall[triangle_index + 1], wall[triangle_index + 2]))
		if closest > 0.075:
			_fail("flower box back board has no measured bearing against the exterior wall triangles")

func _check_cottage_control() -> void:
	var spec := _spec(&"cottage")
	var plan: HousePlan = HouseGenerator.generate(spec, 8102, false)
	if plan == null:
		_fail("Cottage control plan did not generate")
		return
	var builder := HouseBuilder.new()
	builder.build(plan, true)
	for role in ROLES:
		if not _components(builder, role).is_empty():
			_fail("non-Witch Cottage emitted Witch casement component %s" % role)

func _component_vertices(row: Dictionary) -> PackedVector3Array:
	var kit := MeshKit.new(1)
	if String(row.get("form", "")) == "box":
		kit.oriented_box(row["size"], row["xf"], 0)
	elif String(row.get("form", "")) == "slab":
		kit.slab_poly(row["points"], float(row["depth"]), 0,
			bool(row["vertical"]), row.get("open_edges", PackedInt32Array()))
	var mesh: ArrayMesh = kit.commit()
	if mesh.get_surface_count() == 0:
		return PackedVector3Array()
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]

func _ray_hits(vertices: PackedVector3Array, start: Vector3, finish: Vector3) -> bool:
	for index in range(0, vertices.size(), 3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(start, finish,
			vertices[index], vertices[index + 1], vertices[index + 2])
		if hit is Vector3:
			return true
	return false

func _point_triangle_distance(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var ab := b - a
	var ac := c - a
	var normal := ab.cross(ac)
	if normal.length_squared() < 0.0000001:
		return minf(point.distance_to(a), minf(point.distance_to(b), point.distance_to(c)))
	normal = normal.normalized()
	var projected := point - normal * (point - a).dot(normal)
	var v2 := projected - a
	var d00 := ac.dot(ac)
	var d01 := ac.dot(ab)
	var d11 := ab.dot(ab)
	var d20 := v2.dot(ac)
	var d21 := v2.dot(ab)
	var denom := d00 * d11 - d01 * d01
	if absf(denom) > 0.0000001:
		var u := (d11 * d20 - d01 * d21) / denom
		var v := (d00 * d21 - d01 * d20) / denom
		if u >= -0.0001 and v >= -0.0001 and u + v <= 1.0001:
			return absf((point - a).dot(normal))
	return minf(_point_segment_distance(point, a, b), minf(
		_point_segment_distance(point, b, c), _point_segment_distance(point, c, a)))

func _point_mesh_distance(point: Vector3, vertices: PackedVector3Array) -> float:
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

func _fail(message: String) -> void:
	failures.append(message)

func _finish() -> void:
	for failure in failures:
		printerr("FAIL ", failure)
	print("Witch gable casement contract: ", failures.size(), " failures")
	quit(1 if not failures.is_empty() else 0)
