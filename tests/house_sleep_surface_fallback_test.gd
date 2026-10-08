extends SceneTree
## Cottage reading stations retain required roles and authored lamps.
## Measure actual imported lamp triangles independently of catalogue bounds.
var failures: Array[String] = []

func _init() -> void:
	for row in [
		{"id": "cottage_small_8102", "width": 9.0, "length": 12.0, "seed": 8102},
		{"id": "cottage_ample_1", "width": 11.0, "length": 14.0, "seed": 1},
	]:
		var plan := _generate(row)
		if plan == null:
			failures.append("%s failed to generate" % row["id"])
			continue
		var bedroom_before_compose := _bedroom(plan)
		var authored_lights: Dictionary = {}
		if bedroom_before_compose >= 0:
			for index in plan.furniture_of(bedroom_before_compose):
				var item: Dictionary = plan.furniture[index]
				if bool(item.get("mounted", false)) and not bool(item.get("surface_generated", false)) \
						and PropCatalog.category(String(item.get("key", ""))) == "sconce":
					authored_lights[index] = {"pos": item.get("pos", Vector3.ZERO),
						"yaw": float(item.get("yaw", 0.0)), "scale": float(item.get("scale", 1.0)),
						"rect": item.get("rect", Rect2()), "key": item.get("key", ""),
						"host": int(item.get("host", -1)),
						"activity_group": String(item.get("activity_group", "")),
						"mounted": bool(item.get("mounted", false))}
		HousePlanFeatures.compose_wall_hosts(plan, plan.spec)
		_check_positive(plan, String(row["id"]), authored_lights)
	_check_fully_blocked_wall_control()
	for failure in failures:
		printerr("FAIL ", failure)
	print("Cottage sleep fallback contract: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)

func _generate(row: Dictionary) -> HousePlan:
	var spec := HouseSpec.new()
	spec.style = &"cottage"
	spec.width = float(row["width"])
	spec.length = float(row["length"])
	spec.height = 2.6
	spec.storeys = 1
	return HouseGenerator.generate(spec, int(row["seed"]), true)

func _check_positive(plan: HousePlan, case_id: String, authored_lights: Dictionary) -> void:
	var bedroom := _bedroom(plan)
	if bedroom < 0:
		failures.append(case_id + " has no bedroom")
		return
	var bed := -1
	var nightstand := -1
	var clothes := -1
	var support := -1
	var book := -1
	var light := -1
	var support_anchor := ""
	for index in plan.furniture_of(bedroom):
		var item: Dictionary = plan.furniture[index]
		var key := String(item.get("key", ""))
		var category := PropCatalog.category(key)
		if category == "bed": bed = index
		if key == "Nightstand_Shelf": nightstand = index
		if key == "Chest_Wood" and String(item.get("activity_host_anchor", "")) != "head_end": clothes = index
	if bed < 0 or nightstand < 0 or clothes < 0:
		failures.append(case_id + " missing bed, nightstand, or independent clothes chest")
	var anchor_item_key := ""
	for index in plan.furniture_of(bedroom):
		var item: Dictionary = plan.furniture[index]
		if String(item.get("mount_relation", "")) == "supports_activity" \
				and String(item.get("activity_group", "")) == "sleep":
			support = index
			support_anchor = String(item.get("activity_anchor_id", ""))
			var source_index := _anchor_for_id(plan, bedroom, support_anchor)
			if source_index >= 0: anchor_item_key = String(plan.furniture[source_index].get("key", ""))
			break
	if support < 0:
		failures.append(case_id + " has no physically bound sleep shelf")
	else:
		var support_anchor_index := _anchor_for_id(plan, bedroom, support_anchor)
		var prep_rect := Rect2()
		if support_anchor_index >= 0:
			prep_rect = Rect2(plan.furniture[support_anchor_index].get("zone", Rect2()))
			if not prep_rect.has_area(): prep_rect = Rect2(plan.furniture[support_anchor_index].get("rect", Rect2()))
		var authored_near_support := false
		for authored_index_variant in authored_lights:
			var authored_index := int(authored_index_variant)
			var before: Dictionary = authored_lights[authored_index_variant]
			if authored_index >= plan.furniture.size():
				failures.append(case_id + " authored sconce index disappeared during composition")
				continue
			var after: Dictionary = plan.furniture[authored_index]
			if Vector3(after.get("pos", Vector3.ZERO)).distance_to(Vector3(before["pos"])) > 0.001 \
					or absf(float(after.get("yaw", 0.0)) - float(before["yaw"])) > 0.001 \
					or absf(float(after.get("scale", 1.0)) - float(before["scale"])) > 0.001:
				failures.append(case_id + " composition changed authored lamp pose")
			var old_rect: Rect2 = before["rect"]
			var new_rect: Rect2 = Rect2(after.get("rect", Rect2()))
			if old_rect.position.distance_to(new_rect.position) > 0.001 or old_rect.size.distance_to(new_rect.size) > 0.001 \
					or int(after.get("host", -1)) != int(before["host"]) \
					or String(after.get("activity_group", "")) != String(before["activity_group"]) \
					or bool(after.get("mounted", false)) != bool(before["mounted"]):
				failures.append(case_id + " composition changed authored lamp body/host/activity fields")
			if prep_rect.has_area() and String(before["key"]) == "Torch_Metal":
				var imported_bounds := _actual_imported_triangle_bounds(after)
				if imported_bounds.size == Vector3.ZERO:
					failures.append(case_id + " authored Torch_Metal has no imported triangles")
				else:
					var imported_body := Rect2(Vector2(imported_bounds.position.x, imported_bounds.position.z),
						Vector2(imported_bounds.size.x, imported_bounds.size.z))
					if _rect_gap(imported_body, prep_rect) <= 1.9:
						authored_near_support = true
		if not authored_near_support:
			failures.append(case_id + " has no unchanged authored Torch_Metal body within 1.9 m of its selected sleep anchor")
		var shelf: Dictionary = plan.furniture[support]
		for index in plan.furniture_of(bedroom):
			var item: Dictionary = plan.furniture[index]
			if String(item.get("key", "")).begins_with("Book_") \
					and int(item.get("host", -1)) == support \
					and String(item.get("surface_parent_id", "")) == String(shelf.get("surface_anchor_id", "")):
				book = index
			if String(item.get("mount_relation", "")) == "lights_activity" \
					and String(item.get("activity_anchor_id", "")) == support_anchor:
				light = index
		if book < 0 or light < 0:
			failures.append(case_id + " sleep support lacks a hosted book or bound task light")
		if anchor_item_key != "Nightstand_Shelf" and anchor_item_key != "Chest_Wood" \
				and not anchor_item_key.begins_with("Bed_"):
			failures.append(case_id + " sleep support bound to unexpected anchor " + anchor_item_key)
	var nav := HouseNavCheck.new().check(plan)
	if not bool(nav.get("ok", false)):
		failures.append(case_id + " HouseNavCheck reports a general navigation failure")
	if bedroom in nav.get("unreached_rooms", []):
		failures.append(case_id + " bedroom is unreachable")
	var unreachable: Array = nav.get("unreachable_items", [])
	for index in [bed, nightstand, clothes, support, book]:
		if index >= 0 and index in unreachable:
			failures.append("%s role at furniture[%d] is unreachable" % [case_id, index])
	for role in ["bed", "nightstand", "chest", "activity:sleep", "activity:sleep:chest"]:
		if plan.was_dropped(bedroom, role):
			failures.append("%s compromised required role %s" % [case_id, role])

func _check_fully_blocked_wall_control() -> void:
	var row := {"width": 9.0, "length": 12.0, "seed": 8102}
	var plan := _generate(row)
	if plan == null:
		failures.append("blocked-wall control failed to generate")
		return
	var bedroom := _bedroom(plan)
	if bedroom < 0:
		failures.append("blocked-wall control has no bedroom")
		return
	for wall in HouseGeometry.room_walls(plan, bedroom):
		var from: Vector2 = wall["from"]
		var to: Vector2 = wall["to"]
		var center := (from + to) * 0.5
		var horizontal := absf(Vector2(wall["normal"]).y) > 0.5
		var width := absf(to.x - from.x) if horizontal else absf(to.y - from.y)
		plan.windows.append({"room": bedroom, "pos": center,
			"normal": wall["normal"], "width": width + 0.3,
			"sill": 0.8, "head": 1.9, "storey": plan.storey_of_room(bedroom)})
	HousePlanFeatures.compose_wall_hosts(plan, plan.spec)
	var sleep_support := false
	for item in plan.furniture_of(bedroom):
		var placed: Dictionary = plan.furniture[item]
		if String(placed.get("activity_binding_group", "")) == "sleep" \
				and String(placed.get("mount_relation", "")) == "supports_activity":
			sleep_support = true
	if sleep_support:
		failures.append("blocked-wall control fabricated a sleep support")
	if "surface:sleep:no_safe_station" not in plan.compromises.get(bedroom, []):
		failures.append("blocked-wall control did not record honest sleep station unavailability")

func _bedroom(plan: HousePlan) -> int:
	for index in plan.rooms.size():
		if plan.kind_of(index) == &"bedroom": return index
	return -1

func _rect_gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), 0.0)
	var dz := maxf(maxf(a.position.y - b.end.y, b.position.y - a.end.y), 0.0)
	return Vector2(dx, dz).length()

func _actual_imported_triangle_bounds(item: Dictionary) -> AABB:
	var instance := HouseAssembler._instance(item)
	if instance == null:
		return AABB()
	var triangles := _imported_triangles(instance)
	instance.free()
	if triangles.is_empty():
		return AABB()
	var first: Vector3 = triangles[0][0]
	var bounds := AABB(first, Vector3.ZERO)
	for triangle in triangles:
		for vertex_value in triangle:
			var vertex: Vector3 = vertex_value
			bounds = bounds.expand(vertex)
	return bounds

func _imported_triangles(root: Node3D) -> Array:
	var triangles: Array = []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current is MeshInstance3D and (current as MeshInstance3D).mesh != null:
			var mesh_instance := current as MeshInstance3D
			var transform := mesh_instance.transform
			var parent := mesh_instance.get_parent()
			while parent is Node3D:
				transform = (parent as Node3D).transform * transform
				parent = parent.get_parent()
			for surface in range(mesh_instance.mesh.get_surface_count()):
				var arrays := mesh_instance.mesh.surface_get_arrays(surface)
				if arrays.size() <= Mesh.ARRAY_VERTEX:
					continue
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: Variant = arrays[Mesh.ARRAY_INDEX]
				var indexed: bool = indices is PackedInt32Array and not indices.is_empty()
				var count: int = indices.size() if indexed else vertices.size()
				for offset in range(0, count - 2, 3):
					var triangle: Array[Vector3] = []
					for corner in range(3):
						var vertex_index := int(indices[offset + corner]) if indexed else offset + corner
						triangle.append(transform * vertices[vertex_index])
					triangles.append(triangle)
		for child_node in current.get_children():
			pending.append(child_node)
	return triangles

func _anchor_for_id(plan: HousePlan, room: int, anchor_id: String) -> int:
	for index in plan.furniture_of(room):
		if String(plan.furniture[index].get("surface_anchor_id", "")) == anchor_id:
			return index
	return -1
