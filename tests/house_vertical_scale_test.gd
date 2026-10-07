extends SceneTree
## Focused regression for opt-in vertical scaling in HousePlan placements.

var failures: Array[String] = []

func _init() -> void:
	_check_table_model_pose()
	_check_hosted_surface_height()
	_check_light_height_scale()
	for failure in failures:
		push_error(failure)
	print("house vertical placement scale: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _check_table_model_pose() -> void:
	var placement := {
		"key": "Table_Large", "pos": Vector3(0.0, 0.0, 0.0),
		"yaw": 0.0, "scale": 0.62, "height_scale": 1.0,
	}
	var node := HouseAssembler._instance(placement)
	if node == null:
		failures.append("could not load measured Table_Large scene")
		return
	if not is_equal_approx(node.scale.x, 0.62) or not is_equal_approx(node.scale.z, 0.62):
		failures.append("table footprint did not retain scale 0.62")
	if not is_equal_approx(node.scale.y, 1.0):
		failures.append("table vertical scale did not retain measured height")
	if not is_equal_approx(PropCatalog.placement_height(placement), 0.813):
		failures.append("Table_Large placement height should remain measured 0.813 m")
	var bottom := node.position.y + PropCatalog.floor_offset("Table_Large") * node.scale.y
	if not is_equal_approx(bottom, float(placement["pos"].y)):
		failures.append("adult-height table does not meet the floor")
	var mesh_bounds := _actual_mesh_heights(node)
	if not is_finite(mesh_bounds.x) or absf(mesh_bounds.x - float(placement["pos"].y)) > 0.02:
		failures.append("assembled Table_Large mesh bottom is not on the floor")
	if absf(mesh_bounds.y - mesh_bounds.x - 0.813) > 0.02:
		failures.append("assembled table mesh lost its adult height")
	node.free()

	var legacy := {"key": "Table_Large", "pos": Vector3.ZERO,
		"yaw": 0.0, "scale": 0.62}
	var legacy_node := HouseAssembler._instance(legacy)
	if legacy_node == null:
		failures.append("could not load legacy Table_Large scene")
		return
	if not is_equal_approx(PropCatalog.placement_height_scale(legacy), 0.62) \
			or not is_equal_approx(legacy_node.scale.y, 0.62):
		failures.append("legacy uniform placement behavior changed")
	legacy_node.free()


func _check_light_height_scale() -> void:
	var placement := {"key": "Candle_1", "pos": Vector3(0.0, 0.0, 0.0),
		"yaw": 0.0, "scale": 0.62, "height_scale": 1.0}
	var plan := HousePlan.new()
	var spec := HouseSpec.new()
	spec.height = 3.0
	plan.spec = spec
	plan.furniture.append(placement)
	var lights := LightKit.light_the_plan(plan)
	if lights.get_child_count() != 1:
		failures.append("opt-in candle did not emit exactly one light")
		lights.free()
		return
	var lamp := lights.get_child(0) as OmniLight3D
	var origin := PropCatalog.house_origin(placement)
	var expected_y := origin.y + PropCatalog.light_offset("Candle_1").y
	if not is_equal_approx(lamp.position.y, expected_y):
		failures.append("candle flame height did not use placement height_scale")
	lights.free()


func _check_hosted_surface_height() -> void:
	var plan := HousePlan.new()
	plan.spec = HouseSpec.new()
	plan.rooms = [{"kind": &"hall", "rect": Rect2(-3, -3, 6, 6), "storey": 0}]
	var foot := PropCatalog.footprint("Table_Large") * 0.62
	var host_rect := Rect2(-foot * 0.5, foot)
	plan.furniture.append({
		"key": "Table_Large", "room": 0, "storey": 0,
		"pos": Vector3(0.0, 0.0, 0.0), "yaw": 0.0,
		"rect": host_rect, "zone": Rect2(), "host": -1,
		"cat": "table", "scale": 0.62, "height_scale": 1.0,
	})
	var rng := RandomNumberGenerator.new()
	rng.seed = 441
	HouseFurnishSurface.place_on_surface(plan, 0, "Mug", rng)
	var found := false
	for piece in plan.furniture:
		if String(piece.get("key", "")) != "Mug":
			continue
		found = true
		var expected_top := float(plan.furniture[0]["pos"].y) \
			+ PropCatalog.surface_height("Table_Large")
		if not is_equal_approx(float(piece["pos"].y), expected_top):
			failures.append("hosted Mug was not placed at the adult-height table surface")
		var node := HouseAssembler._instance(piece)
		if node == null:
			failures.append("could not load actual hosted Mug scene")
		else:
			var bottom: float = _actual_mesh_heights(node).x
			if absf(bottom - expected_top) > 0.02:
				failures.append("assembled Mug does not meet the scaled host surface")
			node.free()
		break
	if not found:
		failures.append("no Mug could be placed on the measured table surface")

	var legacy_plan := HousePlan.new()
	legacy_plan.spec = plan.spec
	legacy_plan.rooms = plan.rooms.duplicate(true)
	legacy_plan.furniture.append({
		"key": "Table_Large", "room": 0, "storey": 0,
		"pos": Vector3.ZERO, "yaw": 0.0, "rect": host_rect,
		"zone": Rect2(), "host": -1, "cat": "table", "scale": 0.62,
	})
	HouseFurnishSurface.place_on_surface(legacy_plan, 0, "Mug", rng)
	var legacy_child_found := false
	for piece in legacy_plan.furniture:
		if String(piece.get("key", "")) == "Mug":
			legacy_child_found = true
			var legacy_top := PropCatalog.surface_height("Table_Large") * 0.62
			if not is_equal_approx(float(piece["pos"].y), legacy_top):
				failures.append("legacy hosted Mug surface height changed")
			break
	if not legacy_child_found:
		failures.append("legacy uniform table did not support its hosted Mug")


func _actual_mesh_heights(root: Node3D) -> Vector2:
	var todo: Array[Node] = [root]
	var lowest: float = INF
	var highest: float = -INF
	var found: bool = false
	while not todo.is_empty():
		var current: Node = todo.pop_back()
		if current is GeometryInstance3D:
			var instance := current as GeometryInstance3D
			var bounds: AABB = instance.get_aabb()
			var transform: Transform3D = instance.transform
			var parent: Node = instance.get_parent()
			while parent is Node3D:
				transform = (parent as Node3D).transform * transform
				parent = parent.get_parent()
			for x in range(2):
				for y in range(2):
					for z in range(2):
						var point := bounds.position + Vector3(
							bounds.size.x * float(x), bounds.size.y * float(y),
							bounds.size.z * float(z))
						lowest = minf(lowest, (transform * point).y)
						highest = maxf(highest, (transform * point).y)
						found = true
		for child in current.get_children():
			todo.append(child)
	return Vector2(lowest, highest) if found else Vector2(INF, -INF)
