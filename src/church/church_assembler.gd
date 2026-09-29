class_name ChurchAssembler
extends RefCounted
## A built church as a scene: the stone, and an instance of the real model for
## every pew, candelabrum, banner and torch in it.
##
## The same split as the houses and the temple. Everything above this file
## works in metres and never loads a model, which is what lets the massing and
## voxel suites sweep hundreds of churches headless; here at the end the
## architecture is handed its dressing.
static func build(spec: ChurchSpec, cutaway := false) -> Node3D:
	var builder := ChurchBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	return ShellAssembler.build("Church", mesh, [spec.stone_color, spec.trim_color,
		spec.roof_color, Color("1a1c20")], builder.prop_log,
		ChurchBuilder.SURF_ROOF, cutaway, LightKit.FLAME, true)
