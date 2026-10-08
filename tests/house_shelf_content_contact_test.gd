extends SceneTree
## Focused SURFACES shelf-content fixture. Run only after applying this staged
## feature delta to the current house_plan_features.gd. It checks exact support
## geometry, real imported shelf-mesh contact, recompose stability, and fault
## injections. It does not certify style visuals.

var failures: Array[String] = []
var positives := 0
var unsatisfied := 0

const CASES := [
	{"id": "farmhouse_small_8102", "style": &"farmhouse", "width": 9.0, "length": 12.0, "seed": 8102, "group": "cooking"},
	{"id": "farmhouse_ample_1", "style": &"farmhouse", "width": 11.0, "length": 14.0, "seed": 1, "group": "cooking"},
	{"id": "witch_hut_small_8102", "style": &"witch_hut", "width": 9.0, "length": 12.0, "seed": 8102, "group": "witchwork"},
	{"id": "witch_hut_ample_1", "style": &"witch_hut", "width": 11.0, "length": 14.0, "seed": 1, "group": "witchwork"},
]


func _init() -> void:
	for row in CASES:
		print("SHELF_CONTENT_CASE_START ", row.id)
		_check_case(row)
		print("SHELF_CONTENT_CASE_END ", row.id)
	print("SHELF_CONTENT_RESULT positive=", positives, " unsatisfied=", unsatisfied,
		" failures=", failures.size())
	for failure in failures:
		printerr("FAIL ", failure)
	quit(1 if not failures.is_empty() else 0)


func _check_case(row: Dictionary) -> void:
	var spec := HouseSpec.new()
	spec.style = row.style
	spec.width = float(row.width)
	spec.length = float(row.length)
	spec.height = 2.6
	spec.storeys = 1
	var plan := HouseGenerator.generate(spec, int(row.seed), true)
	if plan == null:
		failures.append("%s failed to generate a plan" % row.id)
		return
	HousePlanFeatures.compose_wall_hosts(plan, spec)
	var expected_keys: Array[String] = ["Mug"]
	var room := -1
	var anchor_id := ""
	for item in plan.furniture:
		if String(item.get("activity_group", "")) == String(row.group) \
				and String(item.get("cat", "")) == "workbench":
			room = int(item.get("room", -1))
			anchor_id = String(item.get("surface_anchor_id", ""))
			break
	if room < 0:
		failures.append("%s has no actual %s workbench anchor" % [row.id, row.group])
		return
	var shelf_host: Dictionary = {}
	var shelf_index := -1
	for host in plan.wall_hosts:
		if int(host.get("room", -1)) == room and String(host.get("activity_group", "")) == String(row.group) \
				and String(host.get("role", "")) == "activity_support" \
				and String(host.get("target_category", "")) == "shelf" \
				and String(host.get("anchor_id", "")) == anchor_id:
			for fi in range(plan.furniture.size()):
				if String(plan.furniture[fi].get("wall_host_id", "")) == String(host.get("id", "")):
					shelf_host = host
					shelf_index = fi
					break
			if shelf_index >= 0:
				break
	if shelf_index < 0:
		if plan.was_dropped(room, "surface:%s:no_safe_station" % row.group):
			unsatisfied += 1
			print("SHELF_CONTENT_UNSAT_CONTROL id=", row.id, " reason=no_safe_station; acceptance=FAIL")
			failures.append("%s unresolved no-safe-station shortfall is recorded but cannot count as acceptance" % row.id)
			return
		failures.append("%s has no task shelf and no recorded no-safe-station reason" % row.id)
		return
	var shelf: Dictionary = plan.furniture[shelf_index]
	if row.group == "witchwork":
		if String(shelf.get("key", "")) != "Shelf_Small_Bottles" \
				or String(shelf.get("content_kind", "")) != "integrated_ingredient_rack" \
				or String(shelf.get("content_asset_key", "")) != "Shelf_Small_Bottles" \
				or String(shelf.get("content_layout", "")) != "integrated_two_tier_bottles" \
				or String(shelf_host.get("content_kind", "")) != "integrated_ingredient_rack":
			failures.append("%s did not record the exact integrated two-tier bottle rack asset" % row.id)
			return
		var scene := load(PropCatalog.scene_path("Shelf_Small_Bottles")) as PackedScene
		if scene == null:
			failures.append("%s cannot load the measured integrated ingredient rack scene" % row.id)
			return
		var rack_node := scene.instantiate()
		var mesh_vertices := _mesh_vertex_count(rack_node)
		rack_node.free()
		if mesh_vertices < 3:
			failures.append("%s integrated rack asset has no actual mesh triangles" % row.id)
			return
		for fi in range(plan.furniture.size()):
			var child: Dictionary = plan.furniture[fi]
			if int(child.get("host", -1)) == shelf_index and bool(child.get("surface_generated", false)):
				failures.append("%s added loose generated items to the non-surface integrated rack" % row.id)
		var before_furniture: Array = plan.furniture.duplicate(true)
		var before_hosts: Array = plan.wall_hosts.duplicate(true)
		HousePlanFeatures.compose_wall_hosts(plan, spec)
		if plan.furniture != before_furniture or plan.wall_hosts != before_hosts:
			failures.append("%s integrated ingredient rack metadata was not idempotent" % row.id)
		positives += 1
		print("SHELF_CONTENT_INTEGRATED_RACK id=", row.id, " asset=Shelf_Small_Bottles mesh_vertices=", mesh_vertices)
		return
	var children: Array[int] = []
	for fi in range(plan.furniture.size()):
		var item: Dictionary = plan.furniture[fi]
		if int(item.get("host", -1)) == shelf_index and String(item.get("key", "")) in expected_keys:
			children.append(fi)
	if children.is_empty():
		if plan.was_dropped(room, "surface:%s:no_safe_contents" % row.group):
			unsatisfied += 1
			print("SHELF_CONTENT_UNSAT_CONTROL id=", row.id, " reason=no_safe_contents shelf=", shelf.get("key", ""), "; acceptance=FAIL")
			failures.append("%s unresolved no-safe-contents shortfall is recorded but cannot count as acceptance" % row.id)
			return
		failures.append("%s task shelf is empty and lacks an explicit no-safe-contents reason" % row.id)
		return
	if children.size() != 1:
		failures.append("%s requires exactly one actual supported Mug; found %d" % [row.id, children.size()])
		return
	for child_index in children:
		var child: Dictionary = plan.furniture[child_index]
		if not HousePlanFeatures._is_supported_surface_child(child, shelf, shelf_index):
			failures.append("%s child %s fails exact measured support, footprint, or host-index check" % [row.id, child.get("key", "" )])
			continue
		if String(child.get("surface_parent_id", "")) != String(shelf.get("surface_anchor_id", "")) \
				or String(child.get("activity_anchor_id", "")) != anchor_id \
				or String(child.get("activity_binding_group", "")) != String(row.group):
			failures.append("%s child %s lacks its derived support relation metadata" % [row.id, child.get("key", "")])
		if bool(child.get("surface_generated", false)) and child.has("activity_group"):
			failures.append("%s generated contents falsely count as an authored activity role" % row.id)
		var floating: Dictionary = child.duplicate(true)
		var float_pos: Vector3 = floating["pos"]
		float_pos.y += 0.10
		floating["pos"] = float_pos
		if HousePlanFeatures._is_supported_surface_child(floating, shelf, shelf_index):
			failures.append("%s floating negative was accepted for %s" % [row.id, child.get("key", "")])
		if _actual_mesh_contact(shelf, floating):
			failures.append("%s actual shelf triangles were accepted as supporting a child floating 10 cm above them" % row.id)
		var clipped: Dictionary = child.duplicate(true)
		var clip_pos: Vector3 = clipped["pos"]
		var shelf_rect: Rect2 = Rect2(shelf["rect"])
		var child_rect: Rect2 = Rect2(clipped["rect"])
		var clip_delta := shelf_rect.end.x - child_rect.position.x + 0.15
		clip_pos.x += clip_delta
		clipped["pos"] = clip_pos
		child_rect.position.x += clip_delta
		clipped["rect"] = child_rect
		if HousePlanFeatures._is_supported_surface_child(clipped, shelf, shelf_index):
			failures.append("%s overhanging footprint negative was accepted for %s" % [row.id, child.get("key", "")])
		if _actual_mesh_contact(shelf, clipped):
			failures.append("%s actual shelf triangles were accepted under an overhanging child sample" % row.id)
		if not _actual_mesh_contact(shelf, child):
			failures.append("%s %s footprint rests at catalog height but has no contact with actual imported shelf triangles" % [row.id, child.get("key", "")])
	positives += 1
	_check_recompose_and_authored_child(plan, spec, row, shelf_index, children[0])


func _check_recompose_and_authored_child(plan: HousePlan, spec: HouseSpec,
		row: Dictionary, shelf_index: int, child_index: int) -> void:
	var shelf: Dictionary = plan.furniture[shelf_index]
	var child: Dictionary = plan.furniture[child_index]
	var authored_shelf := shelf.duplicate(true)
	var authored_child := child.duplicate(true)
	# Convert a real supported child and its support into authored objects. The
	# composer must rebind derived links without moving, rescaling, regrouping,
	# or changing the child's stable host index.
	authored_shelf.erase("surface_generated")
	authored_child.erase("surface_generated")
	authored_child["activity_group"] = "authored_household_display"
	plan.furniture[shelf_index] = authored_shelf
	plan.furniture[child_index] = authored_child
	var pose := Vector3(authored_child["pos"])
	var yaw := float(authored_child.get("yaw", 0.0))
	var scale := float(authored_child.get("scale", 1.0))
	var group := String(authored_child.get("activity_group", ""))
	var host := int(authored_child.get("host", -1))
	HousePlanFeatures.compose_wall_hosts(plan, spec)
	var rebound: Dictionary = plan.furniture[child_index]
	if Vector3(rebound.get("pos", Vector3.ZERO)) != pose or float(rebound.get("yaw", 0.0)) != yaw \
				or float(rebound.get("scale", 1.0)) != scale \
				or String(rebound.get("activity_group", "")) != group \
				or int(rebound.get("host", -1)) != host:
		failures.append("%s changed authored child pose, scale, group, or shelf host index" % row.id)
	if not HousePlanFeatures._is_supported_surface_child(rebound, plan.furniture[shelf_index], shelf_index):
		failures.append("%s authored child lost its real support after recomposition" % row.id)
	var before_furniture: Array = plan.furniture.duplicate(true)
	var before_hosts: Array = plan.wall_hosts.duplicate(true)
	HousePlanFeatures.compose_wall_hosts(plan, spec)
	if plan.furniture != before_furniture or plan.wall_hosts != before_hosts:
		failures.append("%s shelf contents or host indices changed on identical recomposition" % row.id)


func _mesh_vertex_count(root: Node) -> int:
	var meshes: Array[Node] = []
	if root is MeshInstance3D:
		meshes.append(root)
	meshes.append_array(root.find_children("*", "MeshInstance3D", true, false))
	var count := 0
	for node in meshes:
		var instance := node as MeshInstance3D
		if instance.mesh == null:
			continue
		for surface in range(instance.mesh.get_surface_count()):
			var arrays := instance.mesh.surface_get_arrays(surface)
			if arrays.size() > Mesh.ARRAY_VERTEX:
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				count += vertices.size()
	return count


func _actual_mesh_contact(shelf: Dictionary, child: Dictionary) -> bool:
	var support_node := HouseAssembler._instance(shelf, true)
	var child_node := HouseAssembler._instance(child, true)
	if support_node == null or child_node == null:
		if support_node != null: support_node.free()
		if child_node != null: child_node.free()
		return false
	var support_triangles := _mesh_triangles(support_node)
	var child_triangles := _mesh_triangles(child_node)
	support_node.free()
	child_node.free()
	if support_triangles.is_empty() or child_triangles.is_empty():
		return false
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for triangle in child_triangles:
		for point in triangle:
			low = low.min(point)
			high = high.max(point)
	var samples := [Vector2((low.x + high.x) * 0.5, (low.z + high.z) * 0.5),
		Vector2(low.x + 0.01, low.z + 0.01), Vector2(high.x - 0.01, low.z + 0.01),
		Vector2(low.x + 0.01, high.z - 0.01), Vector2(high.x - 0.01, high.z - 0.01)]
	for sample in samples:
		var support_y := -INF
		for triangle in support_triangles:
			support_y = maxf(support_y, _triangle_height_at(triangle, sample))
		if not is_finite(support_y) or absf(support_y - low.y) > 0.02:
			return false
	return true


func _mesh_triangles(root: Node3D) -> Array:
	var out: Array = []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current is MeshInstance3D and (current as MeshInstance3D).mesh != null:
			var instance := current as MeshInstance3D
			var transform := instance.transform
			var parent := instance.get_parent()
			while parent is Node3D:
				transform = (parent as Node3D).transform * transform
				parent = parent.get_parent()
			for surface in range(instance.mesh.get_surface_count()):
				var arrays := instance.mesh.surface_get_arrays(surface)
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
					out.append(triangle)
		for child_node in current.get_children():
			pending.append(child_node)
	return out


func _triangle_height_at(triangle: Array, sample: Vector2) -> float:
	var a: Vector3 = triangle[0]
	var b: Vector3 = triangle[1]
	var c: Vector3 = triangle[2]
	var u := Vector2(b.x - a.x, b.z - a.z)
	var v := Vector2(c.x - a.x, c.z - a.z)
	var q := sample - Vector2(a.x, a.z)
	var determinant := u.cross(v)
	if absf(determinant) < 0.000001:
		return -INF
	var s := q.cross(v) / determinant
	var t := u.cross(q) / determinant
	if s < -0.0001 or t < -0.0001 or s + t > 1.0001:
		return -INF
	return a.y + s * (b.y - a.y) + t * (c.y - a.y)
