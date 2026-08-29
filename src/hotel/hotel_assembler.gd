class_name HotelAssembler
extends RefCounted

const SURFACES := ["wall", "trim", "roof", "floor"]


static func build(plan: HousePlan, cutaway := false) -> Node3D:
	var root := Node3D.new()
	root.name = "GrandHotel"
	var builder := HotelBuilder.new()
	var mesh := builder.build(plan, not cutaway)
	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	shell.mesh = mesh
	var spec := plan.spec as HotelSpec
	var colors := [spec.wall_color, spec.trim_color, spec.roof_color, spec.floor_color]
	for i in range(mesh.get_surface_count()):
		var material := StandardMaterial3D.new()
		material.albedo_color = colors[i]
		material.roughness = 0.88
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		shell.set_surface_override_material(i, material)
	root.add_child(shell)
	var props := Node3D.new()
	props.name = "Furniture"
	root.add_child(props)
	for placement in plan.furniture:
		var node: Node3D = HouseAssembler._instance(placement)
		if node != null:
			props.add_child(node)
	return root
