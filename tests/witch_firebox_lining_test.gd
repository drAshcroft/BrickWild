extends SceneTree
## The Witch cooking recess reuses the measured lining, without a second fire.

class BlockedChimneyBuilder extends HouseBuilder:
	func _chimney_box(size: Vector3, centre: Vector3) -> void:
		box(size, centre, SURF_FLOOR)

class RaisedSeatBuilder extends HouseBuilder:
	func _hearth_breast_box(role: String, size: Vector3, centre: Vector2, y0: float,
			y_local: float, x_local: float, z_local: float, yaw: float, surface: int) -> void:
		if role == "hearth_breast_foot":
			size.y += 0.08
			y_local += 0.04
		super(role, size, centre, y0, y_local, x_local, z_local, yaw, surface)

class NarrowMouthBuilder extends HouseBuilder:
	func _hearth_breast_box(role: String, size: Vector3, centre: Vector2, y0: float,
			y_local: float, x_local: float, z_local: float, yaw: float, surface: int) -> void:
		if role == "hearth_jamb":
			x_local -= signf(x_local) * 0.12
		super(role, size, centre, y0, y_local, x_local, z_local, yaw, surface)

var failures: Array[String] = []
var checks := 0

func _init() -> void:
	var seeds: Array[int] = [1, 8102, 21325]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			var selected := int(argument.trim_prefix("--seed="))
			if selected not in seeds:
				printerr("Unknown frozen Witch seed: ", selected)
				quit(2)
				return
			seeds = [selected]
	for seed_value in seeds:
		for size in [Vector2(7, 9)]:
			_check_case(size, seed_value)
	for failure in failures:
		printerr("FAIL ", failure)
	print("Witch firebox lining: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)

func _check_case(size: Vector2, seed_value: int) -> void:
	var label := "%s seed=%d" % [size, seed_value]
	var request := BuildingRequest.house(seed_value, &"witch_hut", &"none", size.x, size.y,
		2.6 if size.x < 10 else 2.8, 1)
	var plan: HousePlan = BrickWild.generate(request).plan
	var layout := HousePlanCheck.new().check(plan)
	_expect(bool(layout["ok"]), "%s room plan: %s" % [label, layout["failures"]])
	var builder := HouseBuilder.new()
	builder.build(plan)
	var breast := HouseGeometry.hearth_breast(plan)
	var mouth := HouseQA._hearth_mouth_metrics(builder, breast)
	var assembled := HouseAssembler.build(plan)
	var details := HouseQA.check_interior_details(plan, builder)
	_expect(details.is_empty(), "%s interior details: %s" % [label, details])
	var floor_errors := HouseQA.check_furniture_floor(plan, builder)
	_expect(floor_errors.is_empty(), "%s furniture support: %s" % [label, floor_errors])
	var navigation := HouseNavCheck.new().check(plan)
	_expect(bool(navigation["ok"]), "%s route failures: %s" % [label, navigation["failures"]])
	var furnished := HouseFurnishCheck.new().check(plan)
	_expect(bool(furnished["ok"]), "%s furnishing: %s" % [label, furnished["failures"]])
	_expect(String(plan.domestic_layout.get("activity_status", "")) == "complete",
		"%s lost an activity: %s" % [label, plan.domestic_layout.get("activity_shortfalls", [])])
	var preparation_vessels := 0
	for item in plan.furniture:
		if String(item.get("activity_group", "")) != "cooking" or String(item.get("key", "")) != "Pot_1":
			continue
		var host := int(item.get("host", -1))
		if host >= 0 and host < plan.furniture.size() \
				and String(plan.furniture[host].get("cat", "")) == "workbench" \
				and String(plan.furniture[host].get("activity_group", "")) == "cooking":
			preparation_vessels += 1
	_expect(preparation_vessels == 1, "%s needs one supported pot at the cooking prep bench" % label)
	var linings := assembled.find_children("FireboxSoot", "Node3D", true, false)
	_expect(linings.size() == 1, "%s must have one cooking firebox lining" % size)
	_expect(assembled.find_children("DomesticHearthHeat", "Node3D", true, false).is_empty(),
		"%s lining must not invent a second cooking fire" % size)
	if linings.size() == 1:
		var lining: Node3D = linings[0]
		var brick := lining.get_node("FirebrickRecessBack") as MeshInstance3D
		var bounds: AABB = (lining.transform * brick.transform) * brick.mesh.get_aabb()
		_expect(absf(bounds.position.y - float(mouth["bottom"])) < 0.002
			and absf(bounds.end.y - float(mouth["top"])) < 0.002,
			"%s firebrick must meet the actual sill and lintel" % size)
		var clear_width: float = maxf(bounds.size.x, bounds.size.z)
		_expect(absf(clear_width - float(mouth["width"])) < 0.002,
			"%s firebrick must fill the actual jamb opening" % size)
		var normal2: Vector2 = breast["normal"]
		var normal := Vector3(normal2.x, 0, normal2.y)
		var hit := HouseAssembler._hearth_backing_hit(builder.emitted_mesh, breast,
			normal, lining.position.y, plan.spec)
		_expect(not hit.is_empty(), "%s lining needs an actual shell backing" % size)
		if not hit.is_empty():
			var roomward: float = (bounds.get_center() - Vector3(hit["point"])).dot(normal)
			_expect(roomward > 0.06 and roomward < 0.09,
				"%s lining floats away from its actual wall face" % size)
	var cooking: Dictionary = {}
	for item in plan.furniture:
		if item["key"] == "Cauldron" and int(item["room"]) == plan.hearth_room():
			cooking = item
			break
	_expect(not cooking.is_empty(), "%s must retain its real cooking Cauldron" % size)
	if not cooking.is_empty():
		var prop := HouseAssembler._instance(cooking, true)
		_check_vessel(plan, builder, cooking, prop, label)
		var blocked := BlockedChimneyBuilder.new()
		blocked.build(plan)
		# Seed 1's old stack physically sealed this mouth. Keep the real fault,
		# rather than manufacturing a false result by changing a metadata flag.
		if not builder.components("chimney_recess_surround").is_empty():
			var invalid := HouseAssembler._domestic_hearth_assembly(prop, cooking, plan, blocked, true)
			_expect(invalid.is_empty(), "%s solid chimney must reject the lining" % size)
			if invalid.has("soot"):
				invalid["soot"].free()
		plan.spec.trade = &"alchemist"
		var specialist := HouseAssembler._domestic_hearth_assembly(prop, cooking, plan, builder, true)
		_expect(specialist.is_empty(), "%s ordinary lining leaked into a trade override" % size)
		if specialist.has("soot"):
			specialist["soot"].free()
		prop.free()
	_check_stove_and_brooms(plan, builder, assembled, label)
	assembled.free()
	print("WITCH_RECESS_CASE ", label, " checks=", checks, " failures=", failures.size())

## WITCH-PROPS: one stove piped into the breast, a Cauldron beside it, two brooms
## standing on the floor with the handle touching a wall.
func _check_stove_and_brooms(plan: HousePlan, builder: HouseBuilder, assembled: Node3D,
		label: String) -> void:
	var breast := HouseGeometry.hearth_breast(plan)
	_expect(not Dictionary(breast.get("stove", {})).is_empty(), label + " breast lost its stove record")
	var stoves := assembled.find_children("WitchWoodStove", "Node3D", true, false)
	_expect(stoves.size() == 1, label + " needs exactly one wood stove, found %d" % stoves.size())
	if stoves.size() == 1:
		var stove: Node3D = stoves[0]
		var mouth := HouseGeometry.hearth_mouth(plan)
		_expect(float(stove.get_meta("flue_top_y")) >= float(mouth["top"]) + 0.05,
			label + " stove pipe stops short of the breast header")
		_expect(stove.find_child("StoveFluePipe", true, false) != null, label + " stove has no flue pipe")
		var rec: Dictionary = breast["stove"]
		var floor_y: float = float(breast["storey"]) * plan.spec.height + float(rec["slab_y"])
		_expect(absf(stove.position.y - floor_y) < 0.001, label + " stove does not rest on the slab")
	var cauldrons := 0
	for item in plan.furniture:
		if item["key"] == "Cauldron":
			cauldrons += 1
	_expect(cauldrons >= 1, label + " lost its Cauldron")
	var brooms := assembled.find_children("WitchBroom_*", "Node3D", true, false)
	_expect(brooms.size() >= 2, label + " needs two brooms, found %d" % brooms.size())
	var whys := {}
	for broom in brooms:
		whys[String(broom.get_meta("why"))] = true
		var foot: Vector3 = broom.get_meta("foot")
		var tip: Vector3 = broom.get_meta("tip")
		var floor_y2 := float(plan.witch_props[0]["floor_y"])
		_expect(absf(foot.y - floor_y2) < 0.03, label + " broom foot is off the floor")
		_expect(tip.y > foot.y + 1.0, label + " broom is not standing")
	_expect(whys.has("door") and whys.has("stove"), label + " broom set lacks door/stove: %s" % [whys.keys()])
	var tria := HouseQA.check_furniture_floor(plan, builder)
	_expect(tria.is_empty(), label + " furniture floor after props: %s" % [tria])

func _check_vessel(plan: HousePlan, builder: HouseBuilder, cooking: Dictionary,
		prop: Node3D, label: String) -> void:
	_expect(HouseQA._hearth_recess_vessel_fits(plan, builder, cooking),
		label + " measured vessel must fit the actual mouth")
	var vertices := PackedVector3Array()
	_collect_vertices(prop, Transform3D.IDENTITY, vertices)
	_expect(_vertices_inside_mouth(vertices, builder, plan),
		label + " actual imported vessel crosses its masonry opening")
	# The stove bay widens the mouth on one side; "sideways" means away from it.
	var stove_rec: Dictionary = HouseGeometry.hearth_breast(plan).get("stove", {})
	var yaw_b: float = float(HouseGeometry.hearth_breast(plan)["yaw"])
	var away := -Vector2(cos(yaw_b), -sin(yaw_b)) * float(stove_rec.get("side", -1.0))
	var sideways := vertices.duplicate()
	for index in sideways.size():
		sideways[index] += Vector3(away.x, 0.0, away.y) * 0.25
	_expect(not _vertices_inside_mouth(sideways, builder, plan),
		label + " moved assembled mesh escaped opening clearance")
	var lowest := INF
	for vertex in vertices:
		lowest = minf(lowest, vertex.y)
	var supports: Array[Vector2] = []
	var triangles := MeshProbe.surface_triangles(builder, builder.emitted_mesh, HouseBuilder.SURF_WALL)
	for vertex in vertices:
		if vertex.y > lowest + 0.002:
			continue
		var point := Vector2(vertex.x, vertex.z)
		if supports.any(func(existing: Vector2): return existing.distance_to(point) < 0.1):
			continue
		supports.append(point)
		_expect(MeshProbe.has_upward_support(triangles, point, vertex.y, 0.003),
			label + " an actual Cauldron foot floats or penetrates its masonry seat")
	_expect(supports.size() >= 3, label + " actual model must expose all three feet")
	var displaced := cooking.duplicate(true)
	displaced["pos"].y += 0.08
	_expect(not HouseQA._hearth_recess_vessel_fits(plan, builder, displaced),
		label + " lifted vessel escaped the recess predicate")
	displaced = cooking.duplicate(true)
	var normal: Vector2 = HouseGeometry.hearth_breast(plan)["normal"]
	var tangent := away
	displaced["pos"] += Vector3(tangent.x, 0, tangent.y) * 0.25
	displaced["rect"].position += tangent * 0.25
	_expect(not HouseQA._hearth_recess_vessel_fits(plan, builder, displaced),
		label + " sideways vessel escaped the actual jamb clearance")
	var raised := RaisedSeatBuilder.new()
	raised.build(plan)
	_expect(not HouseQA._hearth_recess_vessel_fits(plan, raised, cooking),
		label + " raised actual seat escaped contact check")
	var narrow := NarrowMouthBuilder.new()
	narrow.build(plan)
	_expect(not HouseQA._hearth_recess_vessel_fits(plan, narrow, cooking),
		label + " narrowed actual jambs escaped body clearance")

func _collect_vertices(node: Node, parent_xf: Transform3D, vertices: PackedVector3Array) -> void:
	var xf := parent_xf
	if node is Node3D:
		xf = parent_xf * node.transform
	if node is MeshInstance3D and node.mesh != null:
		for surface in node.mesh.get_surface_count():
			for vertex in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				vertices.append(xf * vertex)
	for child in node.get_children():
		_collect_vertices(child, xf, vertices)

func _vertices_inside_mouth(vertices: PackedVector3Array, builder: HouseBuilder,
		plan: HousePlan) -> bool:
	if vertices.is_empty():
		return false
	var breast := HouseGeometry.hearth_breast(plan)
	var mouth := HouseQA._hearth_mouth_metrics(builder, breast)
	var centre: Vector2 = breast["centre"]
	var normal: Vector2 = breast["normal"]
	var tangent := Vector2(normal.y, -normal.x)
	var half_depth: float = float(breast["depth"]) * 0.5
	for vertex in vertices:
		var offset := Vector2(vertex.x, vertex.z) - centre
		if absf(offset.dot(tangent)) > float(mouth["width"]) * 0.5 - 0.025 \
				or offset.dot(normal) < -half_depth + 0.09 \
				or offset.dot(normal) > half_depth - 0.025 \
				or vertex.y < float(mouth["bottom"]) - 0.003 \
				or vertex.y > float(mouth["top"]) - 0.06:
			return false
	return true

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
