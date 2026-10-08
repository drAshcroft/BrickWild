extends SceneTree
## Generated ordinary-bedroom role, scale, floor, backing and access regression.

var failures: Array[String] = []

func _init() -> void:
	var spec := HouseSpec.new()
	spec.style = &"farmhouse"
	spec.width = 9.0
	spec.length = 12.0
	spec.height = 2.6
	var plan: HousePlan = HouseGenerator.generate(spec, 8102, true)
	var rooms: Array[int] = plan.rooms_of(&"bedroom")
	if rooms.is_empty():
		failures.append("generated farmhouse has no bedroom")
	else:
		_check_bedroom(plan, rooms[0])
	for failure in failures:
		push_error(failure)
	print("generated bedside roles: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _check_bedroom(plan: HousePlan, room: int) -> void:
	var bed: Dictionary = {}
	var bedside: Dictionary = {}
	var clothes_chests: Array[Dictionary] = []
	for piece in plan.furniture:
		if int(piece.get("room", -1)) != room or String(piece.get("activity_group", "")) != "sleep":
			continue
		match String(piece.get("cat", "")):
			"bed":
				bed = piece
			"nightstand":
				bedside = piece
			"chest":
				if String(piece.get("key", "")) == "Chest_Wood" \
						and String(piece.get("activity_host_cat", "")) != "bed":
					clothes_chests.append(piece)
	if bed.is_empty() or bedside.is_empty():
		failures.append("generated sleep group lacks its bed or nightstand role")
		return
	if clothes_chests.is_empty():
		failures.append("generated sleep group must retain separate clothes storage")
	if String(bedside.get("key", "")) != "Nightstand_Shelf":
		failures.append("bedside category is not backed by Nightstand_Shelf")
	var scale: float = float(bedside.get("scale", 1.0))
	if scale < 0.62 or scale > 1.0:
		failures.append("bedside scale %.3f is outside the scoped 0.62..1.0 policy" % scale)
	if PropCatalog.placement_height(bedside) > 0.8:
		failures.append("measured bedside height exceeds the 0.8 m target")
	var floor_y: float = HouseFurnishGeometry.storey_base(plan, room) + HouseGeometry.FLOOR_T
	if not is_equal_approx(float(bedside["pos"].y), floor_y):
		failures.append("nightstand plan origin is not at the finished floor")
	if Rect2(bedside["rect"]).intersects(Rect2(bed.get("zone", Rect2()))):
		failures.append("nightstand blocks bed access")
	if not HouseFurnishArrangementCheck._backs_bed_head(plan, bedside):
		failures.append("nightstand actual pose does not back the bed head")
	var node: Node3D = HouseAssembler._instance(bedside)
	if node == null:
		failures.append("measured Nightstand_Shelf scene could not be assembled")
		return
	if not is_equal_approx(node.scale.x, scale) or not is_equal_approx(node.scale.z, scale):
		failures.append("nightstand footprint did not use its measured horizontal scale")
	var bounds: Vector2 = _mesh_height_bounds(node)
	if not is_finite(bounds.x) or not is_finite(bounds.y):
		failures.append("assembled nightstand has no measurable mesh bounds")
	elif absf(bounds.x - floor_y) > 0.02 or absf((bounds.y - bounds.x) - PropCatalog.placement_height(bedside)) > 0.02:
		failures.append("assembled nightstand mesh misses measured height or finished floor")
	node.free()


func _mesh_height_bounds(root: Node3D) -> Vector2:
	var pending: Array[Node] = [root]
	var lowest: float = INF
	var highest: float = -INF
	var found := false
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current is GeometryInstance3D:
			var instance := current as GeometryInstance3D
			var box: AABB = instance.get_aabb()
			var transform: Transform3D = instance.transform
			var parent: Node = instance.get_parent()
			while parent is Node3D:
				transform = (parent as Node3D).transform * transform
				parent = parent.get_parent()
			for ix in 2:
				for iy in 2:
					for iz in 2:
						var point := box.position + Vector3(box.size.x * float(ix),
							box.size.y * float(iy), box.size.z * float(iz))
						var y: float = (transform * point).y
						lowest = minf(lowest, y)
						highest = maxf(highest, y)
						found = true
		for child in current.get_children():
			pending.append(child)
	return Vector2(lowest, highest) if found else Vector2(INF, -INF)
