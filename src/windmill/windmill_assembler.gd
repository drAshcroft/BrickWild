class_name WindmillAssembler
extends RefCounted
## Turns a built windmill into a scene: the stone, the boards, the thatch, the
## iron and the cloth, and nothing else.
##
## The same split as every other family. Everything above this file works in
## metres and never loads a model, which is what lets the whole harness run
## headless in milliseconds; here at the end the mesh is handed its materials.
##
## `cutaway` is accepted and does nothing, on purpose. A house or a temple has
## an inside worth photographing with the roof off; a windmill's is a round
## empty drum with a windshaft through it. Hiding the cap would show the miller
## a hole, not a room.

static func build(spec: WindmillSpec) -> Node3D:
	var root := Node3D.new()
	root.name = spec.variant_name if not spec.variant_name.is_empty() else "Windmill"
	var builder := WindmillBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	if mesh == null:
		return root
	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	shell.mesh = mesh
	ShellAssembler.surface_materials(shell, BuildingFamilyAdapter.colours(spec),
		ShellAssembler.DEFAULT_ROUGHNESS)
	root.add_child(shell)
	return root