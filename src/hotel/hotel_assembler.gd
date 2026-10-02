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
	ShellAssembler.surface_materials(shell, BuildingFamilyAdapter.colours(plan.spec))
	shell.set_surface_override_material(HouseBuilder.SURF_WALL,
		MaterialKit.plaster(plan.spec.wall_color))
	ShellAssembler.house_materials(shell, plan.spec)
	root.add_child(shell)
	HouseAssembler.furnish(root, plan)
	return root
