extends RefCounted
## Imported meshes are the final oracle for centres, floor support, wall
## mounts, bed orientation and flame anchors.
const TOL := 0.012


static func run() -> SuiteResult:
	var res := SuiteResult.new("house assembly")
	for yaw in [0.0, PI / 2.0, PI / 5.0]:
		_floor_prop(res, float(yaw))
	for key in ["Lantern_Wall", "Torch_Metal"]:
		for yaw in [0.0, PI / 5.0]:
			_wall_prop(res, key, float(yaw))
	_light(res, "CandleStick_Stand", 0.47, false)
	for key in ["Bed_Twin1", "Bed_Twin2"]:
		for yaw in [0.0, PI / 2.0]:
			_bed(res, key, float(yaw))
	for key in PropCatalog.PROPS:
		if PropCatalog.category(key) in ["seat", "bench"]:
			for yaw in [0.0, PI / 2.0]:
				_seat(res, key, float(yaw))
	_workbench_semantics(res)
	_legacy_exterior(res)
	for scale in [0.65, 1.0]:
		_ceiling_prop(res, scale)
	_mounted_ceiling_clearance(res)
	return res


static func _mounted_ceiling_clearance(res: SuiteResult) -> void:
	for height in [2.2, 2.6, 4.5]:
		var spec := HouseSpec.new()
		spec.height = height
		var plan := HouseGenerator.generate(spec, 4412, false)
		for key in ["Lantern_Wall", "Torch_Metal"]:
			plan.furniture.clear()
			HouseFurnishSurface.place_mounted(plan, 0, key, spec.rng)
			_expect(res, plan.furniture.size() == 1, "mounted clearance fixture placed no lamp")
			if plan.furniture.is_empty():
				continue
			var placed := HouseAssembler._instance(plan.furniture[0])
			var bounds := SceneBounds.of_node(placed)
			_expect(res, bounds.end.y <= spec.height - HouseGeometry.FLOOR_T + TOL,
				"%s pierces a %.2fm ceiling" % [key, spec.height])
			_expect(res, bounds.position.y >= 1.7 - TOL,
				"%s hangs into head clearance" % key)
			placed.free()


static func _ceiling_prop(res: SuiteResult, scale: float) -> void:
	var p := {"key": "Chandelier", "pos": Vector3(1.2, 7.8, -2.1),
		"yaw": PI / 5.0, "scale": scale, "mounted": true, "host": -1}
	var placed := HouseAssembler._instance(p)
	_expect(res, placed != null, "ceiling model missing")
	if placed == null:
		return
	var bounds := SceneBounds.of_node(placed)
	_expect(res, absf(bounds.end.y - p.pos.y) < TOL,
		"chandelier's measured top misses its ceiling mount")
	_expect(res, bounds.position.y < p.pos.y - 0.1,
		"chandelier does not hang into the room")
	placed.free()


static func _workbench_semantics(res: SuiteResult) -> void:
	var benches := PropCatalog.of_category("workbench")
	_expect(res, "Workbench" in benches,
		"the full-size Workbench no longer satisfies workbench recipes")
	_expect(res, not "Workbench_Drawers" in benches \
			and PropCatalog.category("Workbench_Drawers") == "workbench_insert",
		"the drawer insert is still offered as a standalone workbench")
	for key in ["Potion_2", "SmallBottle"]:
		_expect(res, PropCatalog.has_tag(key, PropCatalog.ON_SURFACE),
			"%s lost its supported-surface placement rule" % key)


static func _floor_prop(res: SuiteResult, yaw: float) -> void:
	var key := "Stall_Cart_Empty"
	var raw: Node3D = load(PropCatalog.scene_path(key)).instantiate()
	var raw_bounds := SceneBounds.of_node(raw)
	_expect(res, Vector2(raw_bounds.get_center().x, raw_bounds.get_center().z).length() > 0.1,
		"stall fixture no longer has an offset model pivot")
	var p := HouseFurnishGeometry.candidate(key, Vector2(2.3,-1.7), yaw, 1.0, 0.76)
	p.pos.y = 6.4
	p.room = 0
	p.storey = 2
	var placed := HouseAssembler._instance(p)
	_expect(res, placed != null, "stall model could not be assembled")
	if placed == null:
		raw.free()
		return
	var bounds := SceneBounds.of_node(placed)
	var actual := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
	_expect(res, Rect2(p.rect).grow(TOL).encloses(actual),
		"turned stall exceeds planned footprint at yaw %.3f: %s vs %s" % [yaw, actual, p.rect])
	var centre := placed.transform * raw_bounds.get_center()
	_expect(res, Vector2(centre.x, centre.z).distance_to(p.rect.get_center()) < TOL,
		"stall's measured centre misses its planned centre")
	if absf(sin(yaw * 2.0)) < 0.001:
		_expect(res, actual.get_center().distance_to(p.rect.get_center()) < TOL \
			and actual.size.distance_to(p.rect.size) < TOL,
			"cardinal assembled stall bounds disagree with its planned rectangle")
	_expect(res, absf(bounds.position.y - 6.4) < TOL,
		"scaled stall does not stand on its upper-storey support")
	placed.free()
	raw.free()


static func _wall_prop(res: SuiteResult, key: String, yaw: float) -> void:
	var p := {"key": key, "pos": Vector3(1.2,7.7,-2.1), "yaw": yaw,
		"scale": 0.88, "room": 0, "storey": 2, "mounted": true, "host": -1}
	var placed := HouseAssembler._instance(p)
	_expect(res, placed != null, key + ": missing mounted model")
	if placed == null:
		return
	# In this frame the wall is Z=0 and the room is Z<0. Transform imported
	# mesh bounds back to it, independently of catalogue mount offsets.
	var wall_frame := Transform3D(Basis(Vector3.UP, yaw), p.pos)
	var relative := SceneBounds.of_node(placed, wall_frame.affine_inverse())
	_expect(res, relative.end.z <= TOL and relative.position.z < -0.02,
		key + ": mounted geometry crosses the wall or faces away from the room")
	_expect(res, absf(relative.end.z) < TOL,
		key + ": measured back floats away from the mounting wall")
	placed.free()
	_light(res, key, yaw, true)


static func _light(res: SuiteResult, key: String, yaw: float, mounted: bool) -> void:
	var plan := HousePlan.new()
	plan.spec = HouseSpec.new()
	plan.spec.height = 3.2
	plan.spec.storeys = 3
	var p := {"key": key, "pos": Vector3(1.2,7.7 if mounted else 6.4,-2.1),
		"yaw": yaw, "scale": 0.88, "room": 0, "storey": 2,
		"mounted": mounted, "host": -1}
	plan.furniture = [p]
	var root := Node3D.new()
	HouseAssembler.furnish(root, plan)
	var model := root.get_node("Furniture").get_child(0) as Node3D
	var lights := root.get_node("Lights")
	_expect(res, lights.get_child_count() == 1, key + ": furniture does not have one light")
	if lights.get_child_count() == 1:
		var raw: Node3D = load(PropCatalog.scene_path(key)).instantiate()
		var bounds := SceneBounds.of_node(raw)
		var flame := Vector3(bounds.get_center().x, bounds.end.y, bounds.get_center().z)
		var actual_flame := model.transform * flame
		var light := lights.get_child(0) as OmniLight3D
		_expect(res, actual_flame.y < 3.0 * plan.spec.height - 0.15,
			key + ": flame fixture is above the ceiling clamp")
		_expect(res, light.position.distance_to(actual_flame) < TOL,
			key + ": light misses the actual model's transformed flame")
		raw.free()
	root.free()


static func _bed(res: SuiteResult, key: String, yaw: float) -> void:
	var p := HouseFurnishGeometry.candidate(key, Vector2(1.1,2.2), yaw)
	p.pos.y = 6.4
	var placed := HouseAssembler._instance(p)
	_expect(res, placed != null, key + ": missing bed model")
	if placed == null:
		return
	_expect(res, _headboard_behind(placed, p.pos, yaw),
		key + ": actual raised headboard is at the foot of the planned bed")
	placed.rotation.y += PI
	_expect(res, not _headboard_behind(placed, p.pos, yaw),
		key + ": orientation check accepted a reversed bed model")
	placed.free()


## A seat with a back must have it BEHIND the way the plan faces it. The
## furnisher and the seating rule share one yaw formula, so they agreed with
## each other while every Chair_1 sat with its back to the table (walk QA,
## 3 and 6 Oct, the same pin twice). Only the model can settle it.
static func _seat(res: SuiteResult, key: String, yaw: float) -> void:
	var p := HouseFurnishGeometry.candidate(key, Vector2(0.4, -1.2), yaw)
	p.pos.y = 3.0
	var placed := HouseAssembler._instance(p)
	_expect(res, placed != null, key + ": missing seat model")
	if placed == null:
		return
	var front := Vector3(-sin(yaw), 0, -cos(yaw))
	var off := _top_offset(placed, p.pos)
	# a stool or a bench has no back: its top is its seat, over its middle
	if Vector2(off.x, off.z).length() > 0.12:
		_expect(res, off.dot(front) < -0.12,
			"%s at yaw %.2f: its back is toward the table it faces (set its face offset)" % [key, yaw])
	placed.free()


static func _headboard_behind(node: Node3D, centre: Vector3, yaw: float) -> bool:
	return _top_offset(node, centre).dot(Vector3(sin(yaw), 0, cos(yaw))) > 0.5


## The centre of the top tenth of a model, relative to `centre`.
static func _top_offset(node: Node3D, centre: Vector3) -> Vector3:
	var bounds := SceneBounds.of_node(node)
	var vertices := PackedVector3Array()
	_vertices(node, Transform3D.IDENTITY, vertices)
	var sum := Vector3.ZERO
	var count := 0
	for point in vertices:
		if point.y >= bounds.end.y - bounds.size.y * 0.1:
			sum += point
			count += 1
	if count == 0:
		return Vector3.ZERO
	return sum / float(count) - centre


static func _vertices(node: Node, parent: Transform3D, out: PackedVector3Array) -> void:
	var here := parent
	if node is Node3D:
		here = parent * (node as Node3D).transform
	for points in SceneBounds._meshes_of(node, here):
		out.append_array(points)
	for child in node.get_children():
		_vertices(child, here, out)


static func _legacy_exterior(res: SuiteResult) -> void:
	var plan := HousePlan.new()
	plan.spec = HouseSpec.new()
	plan.spec.exterior_props = true
	var p := {"key": "Stall_Cart_Empty", "id": "offset_stall", "pos": Vector3(3.0,0.4,-2.0),
		"yaw": PI / 3.0, "scale": 0.76}
	plan.exterior = [p]
	var root := Node3D.new()
	HouseAssembler.dress_exterior(root, plan)
	var model := root.get_node("Exterior/offset_stall") as Node3D
	_expect(res, model != null, "legacy exterior stall was not assembled")
	if model != null:
		_expect(res, Vector2(model.position.x, model.position.z).distance_to(Vector2(3.0,-2.0)) < TOL,
			"legacy exterior model origin was recentered")
		var bounds := SceneBounds.of_node(model)
		_expect(res, absf(bounds.position.y - 0.4) < TOL,
			"legacy exterior floor offset changed")
	root.free()


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)
