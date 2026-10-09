extends SceneTree

const CAULDRON_LOG_ROLES := ["witch_cauldron_heat_log_lower", "witch_cauldron_heat_log_upper"]
var failures: Array[String] = []
var saw_indoor_cauldron := false
var saw_outdoor_cauldron := false

func _init() -> void:
	_check_case(&"none", "yard Witch")
	_check_case(&"alchemist", "indoor Witch trade")
	if not saw_indoor_cauldron:
		failures.append("fixed Witch requests produced no indoor Cauldron")
	if not saw_outdoor_cauldron:
		failures.append("fixed Witch requests produced no yard/exterior Cauldron")
	for failure in failures:
		printerr("FAIL " + failure)
	print("Witch Cauldron heat fixture: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _check_case(trade: StringName, label: String) -> void:
	var spec := HouseSpec.new()
	spec.style = &"witch_hut"
	spec.trade = trade
	var plan := HouseGenerator.generate(spec, 8102, true)
	var planned_counts := [plan.furniture.size(), plan.exterior.size(), plan.yard.size()]
	var nav_before: Dictionary = HouseNavCheck.new().check(plan)
	var cauldrons: Array[Dictionary] = []
	for furniture_index in range(plan.furniture.size()):
		var furniture_placement: Dictionary = plan.furniture[furniture_index]
		if String(furniture_placement.get("key", "")) == "Cauldron":
			saw_indoor_cauldron = true
			cauldrons.append({"placement": furniture_placement, "centred": true, "host_id": "furniture_%d" % furniture_index})
	for exterior_index in range(plan.exterior.size()):
		var exterior_placement: Dictionary = plan.exterior[exterior_index]
		if String(exterior_placement.get("key", "")) == "Cauldron":
			saw_outdoor_cauldron = true
			cauldrons.append({"placement": exterior_placement, "centred": false, "host_id": "exterior_%d" % exterior_index})
	for yard_index in range(plan.yard.size()):
		var yard_placement: Dictionary = plan.yard[yard_index]
		if String(yard_placement.get("key", "")) == "Cauldron":
			saw_outdoor_cauldron = true
			cauldrons.append({"placement": yard_placement, "centred": false, "host_id": "yard_%d" % yard_index})
	if cauldrons.is_empty():
		failures.append("%s generated no Cauldron to receive the heat cue" % label)
		return
	var builder := HouseBuilder.new()
	var shell: ArrayMesh = builder.build(plan, true)
	var component_report: Dictionary = ComponentCheck.check(builder, shell)
	if not bool(component_report.get("ok", false)):
		failures.append("%s emitted component triangles do not match the shell: %s" % [label, str(component_report.get("failures", []))])
	var structural_count := 0
	for entry in cauldrons:
		var placement: Dictionary = entry["placement"]
		var centred: bool = bool(entry["centred"])
		var id_part := String(entry["host_id"])
		var expected_host := "witch_cauldron_%s" % id_part
		var logs: Array[Dictionary] = []
		for row in builder.component_log:
			if String(row.get("host", "")) == expected_host \
						and String(row.get("role", "")) in CAULDRON_LOG_ROLES:
				logs.append(row)
		if logs.size() != 3:
			failures.append("%s %s emitted %d native heat logs; expected three" % [label, id_part, logs.size()])
			continue
		structural_count += logs.size()
		_check_log_support_and_mesh(placement, centred, logs, label)
	if shell.get_surface_count() <= 0:
		failures.append("%s shell did not commit its heat geometry" % label)
	if planned_counts != [plan.furniture.size(), plan.exterior.size(), plan.yard.size()]:
		failures.append("%s builder changed the authored placement lists" % label)
	var assembled := HouseAssembler.build(plan, true)
	var nav_after: Dictionary = HouseNavCheck.new().check(plan)
	if nav_before.get("ok") != nav_after.get("ok") \
			or nav_before.get("unreachable_items", []) != nav_after.get("unreachable_items", []):
		failures.append("%s heat cue changed the plan navigation result" % label)
	var cues := _find_heat_cues(assembled)
	if cues.size() != cauldrons.size():
		failures.append("%s assembled %d heat cues for %d Cauldrons" % [label, cues.size(), cauldrons.size()])
	for cue in cues:
		var names := {}
		for child in cue.get_children():
			names[String(child.name)] = child
		if not names.has("EmberBed") or not names.has("CauldronWarmth") \
				or not names.has("LowFlame_0") or not names.has("LowFlame_1"):
			failures.append("%s Cauldron cue lacks embers, low flame or warmth" % label)
			continue
		var ember: MeshInstance3D = names["EmberBed"]
		var flame: MeshInstance3D = names["LowFlame_0"]
		var light: OmniLight3D = names["CauldronWarmth"]
		var ember_mat := ember.material_override as StandardMaterial3D
		var flame_mat := flame.material_override as StandardMaterial3D
		if ember_mat == null or not ember_mat.emission_enabled \
				or flame_mat == null or not flame_mat.emission_enabled:
			failures.append("%s Cauldron cue is not visibly emissive" % label)
		if light.light_energy <= 0.0 or light.omni_range < 1.0:
			failures.append("%s Cauldron warmth does not reach its immediate work area" % label)
		_check_assembled_heat_geometry(cue, label)
	if structural_count == 0:
		failures.append("%s emitted no structural heat components" % label)
	assembled.free()
	shell.clear_surfaces()


func _check_log_support_and_mesh(placement: Dictionary, centred: bool,
		logs: Array[Dictionary], label: String) -> void:
	var key := "Cauldron"
	var cauldron_instance: Node3D = HouseAssembler._instance(placement, centred)
	if cauldron_instance == null:
		failures.append("%s could not load the actual Cauldron placement" % label)
		return
	var origin: Vector3 = cauldron_instance.position
	var model_yaw: float = cauldron_instance.rotation.y
	cauldron_instance.free()
	var scale_factor := float(placement.get("scale", 1.0))
	var height_scale := PropCatalog.placement_height_scale(placement)
	var expected_floor := origin.y + PropCatalog.floor_offset(key) * height_scale
	var lower_tops: Array[float] = []
	var upper_bottom := INF
	var model_triangles := _cauldron_triangles()
	if model_triangles.is_empty():
		failures.append("%s could not inspect imported Cauldron triangles" % label)
		return
	for row in logs:
		var role := String(row["role"])
		var xf: Transform3D = row["xf"]
		var size: Vector3 = row["size"]
		var actual_bottom := xf.origin.y - size.y * 0.5
		if role == "witch_cauldron_heat_log_lower":
			if absf(actual_bottom - expected_floor) > 0.002:
				failures.append("%s lower heat log does not touch Cauldron floor datum" % label)
			lower_tops.append(xf.origin.y + size.y * 0.5)
		else:
			upper_bottom = actual_bottom
		if _box_intersects_cauldron_mesh(xf, size, model_yaw, origin,
				scale_factor, height_scale, model_triangles):
			failures.append("%s emitted log intersects the actual imported Cauldron mesh" % label)
	if lower_tops.size() == 2:
		for top in lower_tops:
			if absf(upper_bottom - top) > 0.002:
				failures.append("%s upper cross-log does not bear on both lower logs" % label)

	# Negative control: an intentionally lifted box crosses the bowl underside.
	var model_basis := Basis(Vector3.UP, model_yaw)
	var probe_origin := origin + model_basis * Vector3(0.0, 0.22 * height_scale, 0.0)
	var probe_size := Vector3(0.05 * scale_factor, 0.04 * height_scale,
		0.05 * scale_factor)
	if not _box_intersects_cauldron_mesh(Transform3D(model_basis, probe_origin),
		probe_size, model_yaw, origin, scale_factor, height_scale, model_triangles):
		failures.append("%s imported-mesh collision negative did not detect a box at the bowl underside" % label)

func _check_assembled_heat_geometry(cue: Node3D, label: String) -> void:
	var prop_root := cue.get_parent() as Node3D
	if prop_root == null:
		failures.append("%s heat cue is detached from its Cauldron instance" % label)
		return
	var rows: Array[Dictionary] = []
	_collect_heat_mesh_rows(cue, Transform3D.IDENTITY, rows)
	var cauldron_xf: Transform3D = prop_root.transform
	var triangles := _cauldron_triangles()
	var floor_point := cauldron_xf * Vector3(0.0, PropCatalog.floor_offset("Cauldron"), 0.0)
	var coal_bottom := INF
	var coal_top := -INF
	var flame_bottoms: Array[float] = []
	for row in rows:
		var node: MeshInstance3D = row["node"]
		var relative_xf: Transform3D = row["xf"]
		var mesh_xf := cauldron_xf * relative_xf
		var local_bounds: AABB = node.mesh.get_aabb()
		var world_bounds := _transform_aabb(local_bounds, mesh_xf)
		if String(node.name) == "EmberBed":
			coal_bottom = world_bounds.position.y
			coal_top = world_bounds.end.y
			if not _floor_contact_matches(coal_bottom, floor_point.y):
				failures.append("%s assembled ember bed is not supported by the Cauldron floor datum" % label)
			if _floor_contact_matches(coal_bottom + 0.02, floor_point.y):
				failures.append("%s floor-gap negative was accepted as a supported ember bed" % label)
		elif String(node.name).begins_with("LowFlame_"):
			flame_bottoms.append(world_bounds.position.y)
		if _mesh_aabb_intersects_cauldron(node.mesh.get_aabb(), mesh_xf,
				cauldron_xf, triangles):
			failures.append("%s actual assembled heat mesh intersects imported Cauldron triangles" % label)
	if not is_finite(coal_bottom) or not is_finite(coal_top) or flame_bottoms.size() != 2:
		failures.append("%s assembled heat mesh bounds are incomplete" % label)
		return
	for bottom in flame_bottoms:
		if absf(bottom - coal_top) > 0.002:
			failures.append("%s low flame does not sit on the assembled ember bed" % label)


func _collect_heat_mesh_rows(node: Node, parent_xf: Transform3D,
		out: Array[Dictionary]) -> void:
	var xf := parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append({"node": node as MeshInstance3D, "xf": xf})
	for child in node.get_children():
		_collect_heat_mesh_rows(child, xf, out)


func _floor_contact_matches(actual_bottom: float, floor_y: float) -> bool:
	return absf(actual_bottom - floor_y) <= 0.002


func _transform_aabb(bounds: AABB, xf: Transform3D) -> AABB:
	var first := true
	var result := AABB()
	for sx in [0.0, 1.0]:
		for sy in [0.0, 1.0]:
			for sz in [0.0, 1.0]:
				var point := xf * (bounds.position + Vector3(
					bounds.size.x * sx, bounds.size.y * sy, bounds.size.z * sz))
				if first:
					result = AABB(point, Vector3.ZERO)
					first = false
				else:
					result = result.expand(point)
	return result


func _mesh_aabb_intersects_cauldron(mesh_bounds: AABB, mesh_xf: Transform3D,
		cauldron_xf: Transform3D, triangles: Array) -> bool:
	var inverse_mesh := mesh_xf.affine_inverse()
	var local_center := mesh_bounds.get_center()
	var half := mesh_bounds.size * 0.5
	for triangle in triangles:
		var a: Vector3 = inverse_mesh * (cauldron_xf * triangle[0]) - local_center
		var b: Vector3 = inverse_mesh * (cauldron_xf * triangle[1]) - local_center
		var c: Vector3 = inverse_mesh * (cauldron_xf * triangle[2]) - local_center
		if _triangle_overlaps_aabb(a, b, c, half):
			return true
	return false


func _cauldron_triangles() -> Array:
	var packed: PackedScene = load(PropCatalog.scene_path("Cauldron"))
	if packed == null:
		return []
	var instance: Node3D = packed.instantiate()
	var out: Array = []
	_collect_mesh_triangles(instance, Transform3D.IDENTITY, out)
	instance.free()
	return out


func _collect_mesh_triangles(node: Node, parent_xf: Transform3D, out: Array) -> void:
	var xf := parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh := (node as MeshInstance3D).mesh
		for surface_index in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for i in range(0, vertices.size() - 2, 3):
					out.append([xf * vertices[i], xf * vertices[i + 1], xf * vertices[i + 2]])
			else:
				for i in range(0, indices.size() - 2, 3):
					out.append([xf * vertices[indices[i]], xf * vertices[indices[i + 1]], xf * vertices[indices[i + 2]]])
	for child in node.get_children():
		_collect_mesh_triangles(child, xf, out)


func _box_intersects_cauldron_mesh(log_xf: Transform3D, size: Vector3,
		model_yaw: float, origin: Vector3, scale_factor: float,
		height_scale: float, triangles: Array) -> bool:
	var model_basis := Basis(Vector3.UP, model_yaw)
	var inverse_box := log_xf.basis.inverse()
	var half := size * 0.5
	for triangle in triangles:
		var points: Array[Vector3] = []
		for vertex in triangle:
			var scaled := Vector3(vertex.x * scale_factor, vertex.y * height_scale,
				vertex.z * scale_factor)
			var world := origin + model_basis * scaled
			points.append(inverse_box * (world - log_xf.origin))
		if _triangle_overlaps_aabb(points[0], points[1], points[2], half):
			return true
	return false


func _triangle_overlaps_aabb(a: Vector3, b: Vector3, c: Vector3, half: Vector3) -> bool:
	var edges := [b - a, c - b, a - c]
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK,
		edges[0].cross(edges[1])]
	for edge in edges:
		axes.append(edge.cross(Vector3.RIGHT))
		axes.append(edge.cross(Vector3.UP))
		axes.append(edge.cross(Vector3.BACK))
	for axis in axes:
		if axis.length_squared() < 1e-12:
			continue
		var p0 := a.dot(axis)
		var p1 := b.dot(axis)
		var p2 := c.dot(axis)
		var low := minf(p0, minf(p1, p2))
		var high := maxf(p0, maxf(p1, p2))
		var radius := half.x * absf(axis.x) + half.y * absf(axis.y) + half.z * absf(axis.z)
		if low > radius or high < -radius:
			return false
	return true


func _find_heat_cues(root: Node) -> Array[Node3D]:
	var found: Array[Node3D] = []
	if root is Node3D and String((root as Node3D).name) == "NativeCauldronHeat":
		found.append(root as Node3D)
	for child in root.get_children():
		found.append_array(_find_heat_cues(child))
	return found
