extends SceneTree
## Finishing one house must not recolour the shared imported scene, its metal,
## its cloth, or a later shop/inn. Inspect real imported material resources.
var failures: Array[String] = []

func _initialize() -> void:
	var placement := {"key": "Bed_Twin1", "pos": Vector3.ZERO, "yaw": 0.0,
		"scale": 1.0, "room": 0, "storey": 0, "rect": Rect2()}
	var untouched := HouseAssembler._instance(placement)
	var originals := _materials(untouched)
	var original_wood: BaseMaterial3D = originals["MI_Trim_Furniture"]
	var original_colour := original_wood.albedo_color
	var original_normal := original_wood.normal_scale
	for style in [&"cottage", &"farmhouse", &"thatch_cottage", &"townhouse", &"witch_hut"]:
		var spec := HouseSpec.new()
		spec.style = style
		var plan := HousePlan.new()
		plan.spec = spec
		plan.furniture.append(placement)
		var root := Node3D.new()
		HouseAssembler.furnish(root, plan)
		var actual := _materials(root)
		var wood: BaseMaterial3D = actual["MI_Trim_Furniture"]
		if wood == original_wood or wood.albedo_color.get_luminance() >= original_colour.get_luminance():
			failures.append("%s did not receive its own quieter wood finish" % style)
		if wood.albedo_texture != original_wood.albedo_texture or wood.normal_texture != original_wood.normal_texture:
			failures.append("%s discarded the model's owned grain maps" % style)
		for name in ["MI_Trim_Metal", "MI_Trim_Cloth"]:
			if actual[name] != originals[name]:
				failures.append("%s changed a non-wood surface" % style)
		root.free()
	if original_wood.albedo_color != original_colour or original_wood.normal_scale != original_normal:
		failures.append("finishing an instance mutated the shared imported material")
	for spec: HouseSpec in [ShopSpec.new(), HotelSpec.new(), InsulaSpec.new(), HouseSpec.new()]:
		var plan := HousePlan.new()
		plan.spec = spec
		plan.spec.style = &"townhouse"
		plan.spec.trade = &"innkeeper"
		plan.furniture.append(placement)
		var root := Node3D.new()
		HouseAssembler.furnish(root, plan)
		if _materials(root)["MI_Trim_Furniture"] != original_wood:
			failures.append("specialist/trade consumer inherited the domestic finish")
		root.free()
	var reloaded := HouseAssembler._instance(placement)
	if _materials(reloaded)["MI_Trim_Furniture"] != original_wood:
		failures.append("a subsequent unstyled instance changed material")
	reloaded.free()
	untouched.free()
	for issue in failures:
		push_error(issue)
	print("Domestic material isolation: five styles, four specialist/trade controls, %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _materials(node: Node) -> Dictionary:
	var out := {}
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(surface)
			out[material.resource_name] = material
	for child in node.get_children():
		out.merge(_materials(child), true)
	return out
