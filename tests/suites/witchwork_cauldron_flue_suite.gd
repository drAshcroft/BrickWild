extends RefCounted

var failures: Array[String] = []
var checks := 0

static func run() -> SuiteResult:
	var fixture := load("res://tests/suites/witchwork_cauldron_flue_suite.gd").new()
	fixture._run()
	var result := SuiteResult.new("Witchwork Cauldron flue")
	result.checked = fixture.checks
	for failure in fixture.failures:
		result.fail(failure)
	return result

func _run() -> void:
	_check_size(7.0, 9.0, "small", false)
	_check_size(9.0, 12.0, "default", true)
	_check_size(17.0, 18.0, "large", true)

func _check_size(width: float, length: float, label: String, expects_flue: bool) -> void:
	var spec := HouseSpec.new(1)
	spec.style = &"witch_hut"
	spec.trade = &"none"
	spec.width = width
	spec.length = length
	spec.height = 2.6 if width < 10.0 else 2.8
	var plan := HouseGenerator.generate(spec, 1, true)
	var workshop_station: Dictionary = {}
	var cooking_station: Dictionary = {}
	for row: Dictionary in plan.furniture:
		checks += 1
		if String(row.get("key", "")) != "Cauldron":
			continue
		checks += 1
		if String(row.get("heat_setting_id", "")) == "witchwork_cauldron":
			workshop_station = row
		checks += 1
		if int(row.get("room", -1)) == plan.hearth_room():
			cooking_station = row
	checks += 1
	if expects_flue:
		checks += 1
		if plan.heat_settings.size() != 1 or workshop_station.is_empty():
			failures.append("%s did not bind exactly one separate Workshop Cauldron by semantic id" % label)
			return
		checks += 1
		if int(workshop_station["room"]) == plan.hearth_room() \
				or String(workshop_station.get("activity_group", "")) != "witchwork":
			failures.append("%s conflated Witchwork and domestic cooking stations" % label)
		checks += 1
		if cooking_station.is_empty():
			failures.append("%s lost the independent Hall cooking Cauldron" % label)
	else:
		checks += 1
		if not plan.heat_settings.is_empty() or not workshop_station.is_empty():
			failures.append("small compact Witch gained an independent Workshop heat setting")
		checks += 1
		if cooking_station.is_empty():
			failures.append("small compact Witch lost its shared Hall Cauldron")
	var nav := HouseNavCheck.new().check(plan)
	checks += 1
	if not bool(nav.get("ok", false)):
		failures.append("%s heat-setting plan broke nav: %s" % [label, str(nav)])
	var builder := HouseBuilder.new()
	var shell: ArrayMesh = builder.build(plan, true)
	var audit := ComponentCheck.check(builder, shell)
	checks += 1
	if not bool(audit.get("ok", false)):
		failures.append("%s component audit failed: %s" % [label, str(audit.get("failures", []))])
	var openings: Array[Dictionary] = []
	for row: Dictionary in builder.roof_opening_log:
		checks += 1
		if String(row.get("id", "")) == "witchwork_cauldron_flue":
			openings.append(row)
	var flue_components: Array[Dictionary] = []
	for row: Dictionary in builder.component_log:
		checks += 1
		if String(row.get("host", "")) == "witchwork_cauldron_flue":
			flue_components.append(row)
	checks += 1
	if expects_flue:
		checks += 1
		if openings.size() != 1:
			failures.append("%s has no emitted custom-bay aperture record" % label)
		else:
			_check_emitted_roof_rays(builder, plan, openings[0], label)
		_check_imported_cauldron_clearance(builder, workshop_station, flue_components, label)
		var roles: Array[String] = []
		for component: Dictionary in flue_components:
			roles.append(String(component.get("role", "")))
		for expected_role in ["witchwork_cauldron_hood", "witchwork_cauldron_flue_stack",
				"witchwork_cauldron_hood_hanger", "witchwork_flue_roof_collar",
				"witchwork_flue_throat_liner", "witchwork_cauldron_rain_cap_support",
				"witchwork_cauldron_rain_cap"]:
			checks += 1
			if not roles.has(expected_role):
				failures.append("%s missing named supported flue component %s" % [label, expected_role])
		_check_use_zone_headroom(workshop_station, openings, flue_components, plan, label)
		_check_hidden_heat_negative(workshop_station, cooking_station, plan, label)
		checks += 1
		if label == "default" and not openings.is_empty():
			var hole_center: Vector3 = openings[0]["center"]
			var patch_mesh := _solid_patch_mesh(plan, openings[0])
			checks += 1
			if _roof_ray_count(patch_mesh, Vector2(hole_center.x, hole_center.z),
					hole_center.y - 0.6, false, true) == 0:
				failures.append("default solid roof-patch mutation did not block the aperture ray")
			plan.heat_settings[0]["station_id"] = "hall_cooking_cauldron"
			var mismatched := HouseBuilder.new()
			var mismatched_mesh: ArrayMesh = mismatched.build(plan, true)
			checks += 1
			if not mismatched.roof_opening_log.is_empty() \
					or _roof_ray_count(mismatched_mesh, Vector2(hole_center.x, hole_center.z),
						hole_center.y - 0.6, true) == 0:
				failures.append("default mismatched station-id negative did not leave the bay/ceiling solid")
			plan.heat_settings[0]["station_id"] = "witchwork_cauldron"
			plan.heat_settings.clear()
			var unbound := HouseBuilder.new()
			var solid_roof: ArrayMesh = unbound.build(plan, true)
			checks += 1
			if not unbound.roof_opening_log.is_empty() \
					or _roof_ray_count(solid_roof, Vector2(hole_center.x, hole_center.z),
						hole_center.y - 0.6, true) == 0:
				failures.append("default missing-binding negative did not restore solid bay/ceiling geometry")
	else:
		checks += 1
		if not openings.is_empty() or not flue_components.is_empty():
			failures.append("small compact Witch emitted a separate bay aperture or flue")

func _check_emitted_roof_rays(builder: HouseBuilder, plan: HousePlan,
		opening: Dictionary, label: String) -> void:
	var layout := HouseGeometry.roof_layout(plan)
	var xf: Transform3D = layout["transform"]
	var local_center: Vector2 = Poly.bounding_rect(opening["polygon"]).get_center()
	var world_center: Vector3 = Vector3(opening["center"])
	var hole_ray := _roof_ray_count(builder.emitted_mesh, Vector2(world_center.x, world_center.z), world_center.y - 0.6, true)
	checks += 1
	if hole_ray != 0:
		failures.append("%s emitted roof mesh still blocks the flue center ray (%d hits)" % [label, hole_ray])
	var neighbor_local := local_center + Vector2(0.255, 0.0)
	var bay: Dictionary = layout["witch_bay"]
	var cross := neighbor_local.x if int(bay["axis"]) == 0 else neighbor_local.y
	var t := clampf((cross - float(bay["outer"])) / (float(bay["inner"]) - float(bay["outer"])), 0.0, 1.0)
	var roof_y := lerpf(float(bay["eave_y"]), float(bay["join_y"]), t)
	var neighbor_world := xf * Vector3(neighbor_local.x, roof_y, neighbor_local.y)
	var neighbor_ray := _roof_ray_count(builder.emitted_mesh,
		Vector2(neighbor_world.x, neighbor_world.z), neighbor_world.y - 0.6, false)
	checks += 1
	if neighbor_ray == 0:
		failures.append("%s adjacent custom-bay roof ray found no emitted roof" % label)

func _roof_ray_count(mesh: ArrayMesh, xz: Vector2, from_y: float,
		include_ceiling: bool, all_surfaces := false) -> int:
	var hits := 0
	for surface_index in range(mesh.get_surface_count()):
		checks += 1
		if not all_surfaces and surface_index != 2 \
				and not (include_ceiling and surface_index == 0):
			continue
		var arrays := mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		checks += 1
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			indices = arrays[Mesh.ARRAY_INDEX]
		var indexed: bool = not indices.is_empty()
		var triangle_count: int = indices.size() if indexed else vertices.size()
		for i in range(0, triangle_count, 3):
			var ai: int = indices[i] if indexed else i
			var bi: int = indices[i + 1] if indexed else i + 1
			var ci: int = indices[i + 2] if indexed else i + 2
			var a: Vector3 = vertices[ai]
			var b: Vector3 = vertices[bi]
			var c: Vector3 = vertices[ci]
			var hit := _ray_triangle(Vector3(xz.x, from_y, xz.y), Vector3.UP, a, b, c)
			checks += 1
			if is_finite(hit.y) and float(hit.y) > from_y + 0.1:
				hits += 1
	return hits

func _solid_patch_mesh(plan: HousePlan, opening: Dictionary) -> ArrayMesh:
	var layout := HouseGeometry.roof_layout(plan)
	var xf: Transform3D = layout["transform"]
	var bay: Dictionary = layout["witch_bay"]
	var polygon: PackedVector2Array = opening["polygon"]
	var vertices := PackedVector3Array()
	for p: Vector2 in polygon:
		var cross := p.x if int(bay["axis"]) == 0 else p.y
		var t := clampf((cross - float(bay["outer"])) /
			(float(bay["inner"]) - float(bay["outer"])), 0.0, 1.0)
		var y := lerpf(float(bay["eave_y"]), float(bay["join_y"]), t)
		vertices.append(xf * Vector3(p.x, y, p.y))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _check_use_zone_headroom(station: Dictionary, openings: Array[Dictionary],
		components: Array[Dictionary], plan: HousePlan, label: String) -> void:
	var hood: Dictionary = {}
	for component: Dictionary in components:
		checks += 1
		if String(component.get("role", "")) == "witchwork_cauldron_hood":
			hood = component
	checks += 1
	if hood.is_empty() or openings.is_empty():
		failures.append("%s has no measurable hood/use-zone headroom pair" % label)
		return
	var zone: Rect2 = Rect2(station.get("zone", Rect2()))
	var hood_bounds := MassBuilder.component_aabb(hood)
	for component: Dictionary in components:
		checks += 1
		if String(component.get("role", "")) == "witchwork_cauldron_hood":
			hood_bounds = hood_bounds.merge(MassBuilder.component_aabb(component))
	var hood_floor := hood_bounds.position.y
	var hood_top := hood_bounds.end.y
	var hood_rect := Rect2(Vector2(hood_bounds.position.x, hood_bounds.position.z),
		Vector2(hood_bounds.size.x, hood_bounds.size.z))
	var storey_floor := float(station.get("storey", 0)) * plan.spec.height
	checks += 1
	if zone.intersects(hood_rect) and hood_floor < storey_floor + 2.05 - 0.001:
		failures.append("%s hood overhang lowers into the Workshop standing-zone head clearance" % label)
	for component: Dictionary in components:
		checks += 1
		if String(component.get("form", "")) != "box":
			continue
		var bounds := MassBuilder.component_aabb(component)
		var part_rect := Rect2(Vector2(bounds.position.x, bounds.position.z),
			Vector2(bounds.size.x, bounds.size.z))
		var part_bottom := bounds.position.y
		checks += 1
		if zone.intersects(part_rect) and part_bottom < storey_floor + 2.05 - 0.001:
			failures.append("%s low flue geometry blocks the Workshop use zone below head clearance: %s" %
				[label, String(component.get("role", ""))])
			break
	var opening_center: Vector3 = openings[0]["center"]
	var roof_underside: float = opening_center.y - RoofShape.DEPTH * 0.5
	checks += 1
	if hood_top >= roof_underside - 0.10:
		failures.append("%s hood does not clear the custom bay roof underside" % label)

func _ray_triangle(origin: Vector3, direction: Vector3, a: Vector3,
		b: Vector3, c: Vector3) -> Vector3:
	var edge1 := b - a
	var edge2 := c - a
	var p := direction.cross(edge2)
	var det := edge1.dot(p)
	checks += 1
	if absf(det) < 0.000001:
		return Vector3(INF, INF, INF)
	var inv_det := 1.0 / det
	var tvec := origin - a
	var u := tvec.dot(p) * inv_det
	checks += 1
	if u < 0.0 or u > 1.0:
		return Vector3(INF, INF, INF)
	var q := tvec.cross(edge1)
	var v := direction.dot(q) * inv_det
	checks += 1
	if v < 0.0 or u + v > 1.0:
		return Vector3(INF, INF, INF)
	var distance := edge2.dot(q) * inv_det
	checks += 1
	if distance <= 0.0:
		return Vector3(INF, INF, INF)
	return origin + direction * distance

func _check_imported_cauldron_clearance(builder: HouseBuilder, station: Dictionary,
		components: Array[Dictionary], label: String) -> void:
	var instance := HouseAssembler._instance(station)
	checks += 1
	if instance == null:
		failures.append("%s could not instantiate the imported Workshop Cauldron" % label)
		return
	var model_origin := instance.position
	var model_yaw := instance.rotation.y
	instance.free()
	var triangles: Array = []
	var packed: PackedScene = load(PropCatalog.scene_path("Cauldron"))
	checks += 1
	if packed == null:
		failures.append("%s could not load imported Cauldron mesh" % label)
		return
	var model: Node3D = packed.instantiate()
	_collect_triangles(model, Transform3D.IDENTITY, triangles)
	model.free()
	var model_basis := Basis(Vector3.UP, model_yaw)
	for component: Dictionary in components:
		checks += 1
		if String(component.get("form", "")) not in ["box", "slab"]:
			continue
		var bounds := MassBuilder.component_aabb(component)
		var half := bounds.size * 0.5
		var box_center := bounds.position + half
		var collision := false
		for triangle: Array in triangles:
			var local: Array[Vector3] = []
			for vertex: Vector3 in triangle:
				var scaled := Vector3(vertex.x * float(station.get("scale", 1.0)),
					vertex.y * PropCatalog.placement_height_scale(station),
					vertex.z * float(station.get("scale", 1.0)))
				local.append(model_origin + model_basis * scaled - box_center)
			checks += 1
			if _triangle_box(local[0], local[1], local[2], half):
				collision = true
				break
		checks += 1
		if collision:
			failures.append("%s emitted flue component intersects imported Cauldron triangles at %s" % [label, String(component["role"])])
			break

func _collect_triangles(node: Node, parent_xf: Transform3D, out: Array) -> void:
	var xf := parent_xf
	checks += 1
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	checks += 1
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh := (node as MeshInstance3D).mesh
		for surface_index in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			checks += 1
			if indices.is_empty():
				for i in range(0, vertices.size() - 2, 3):
					out.append([xf * vertices[i], xf * vertices[i + 1], xf * vertices[i + 2]])
			else:
				for i in range(0, indices.size() - 2, 3):
					out.append([xf * vertices[indices[i]], xf * vertices[indices[i + 1]], xf * vertices[indices[i + 2]]])
	for child in node.get_children():
		_collect_triangles(child, xf, out)

func _triangle_box(a: Vector3, b: Vector3, c: Vector3, half: Vector3) -> bool:
	var edges := [b - a, c - b, a - c]
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK, edges[0].cross(edges[1])]
	for edge: Vector3 in edges:
		axes.append(edge.cross(Vector3.RIGHT))
		axes.append(edge.cross(Vector3.UP))
		axes.append(edge.cross(Vector3.BACK))
	for axis: Vector3 in axes:
		checks += 1
		if axis.length_squared() < 0.000000001:
			continue
		var low := minf(a.dot(axis), minf(b.dot(axis), c.dot(axis)))
		var high := maxf(a.dot(axis), maxf(b.dot(axis), c.dot(axis)))
		var radius := half.x * absf(axis.x) + half.y * absf(axis.y) + half.z * absf(axis.z)
		checks += 1
		if low > radius or high < -radius:
			return false
	return true

func _check_hidden_heat_negative(workshop: Dictionary, cooking: Dictionary,
		plan: HousePlan, label: String) -> void:
	var workshop_parent := Node3D.new()
	var cooking_parent := Node3D.new()
	HouseAssembler._add_witch_cauldron_heat(workshop_parent, workshop, plan)
	HouseAssembler._add_witch_cauldron_heat(cooking_parent, cooking, plan)
	var workshop_heat := workshop_parent.get_node_or_null("NativeCauldronHeat") as Node3D
	var cooking_heat := cooking_parent.get_node_or_null("NativeCauldronHeat") as Node3D
	checks += 1
	if workshop_heat == null or String(workshop_heat.get_meta("heat_setting_id", "")) != "witchwork_cauldron":
		failures.append("%s Workshop heat cue is not bound to the semantic station id" % label)
	checks += 1
	if cooking_heat == null or cooking_heat.get_meta("heat_setting_id", "") == "witchwork_cauldron":
		failures.append("%s Hall cooking heat cue was merged into the Workshop setting" % label)
	checks += 1
	if workshop_heat != null:
		workshop_heat.visible = false
	checks += 1
	if cooking_heat != null and not cooking_heat.visible:
		failures.append("%s hiding Workshop heat also hid Hall cooking heat" % label)
	workshop_parent.free()
	cooking_parent.free()
