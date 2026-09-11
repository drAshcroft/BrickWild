class_name CastleAssembler
extends RefCounted
## A built castle as a scene: the stone, and an instance of the real model for
## every trestle, banner, barrel and brazier in it.
##
## The same split as the houses, the temple and the churches. Everything above
## this file works in metres and never loads a model; here at the end the
## fortification is handed its dressing.
static func build(spec: CastleSpec, cutaway := false) -> Node3D:
	var builder := CastleBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	var root := ShellAssembler.build("Castle", mesh, [spec.stone_color, spec.trim_color,
		spec.roof_color, Color("1a1c20")], builder.prop_log,
		CastleBuilder.SURF_ROOF, cutaway)
	for row in builder.interiors:
		var rooms := Node3D.new()
		rooms.name = row.id
		rooms.transform = row.transform
		root.add_child(rooms)
		HouseAssembler.furnish(rooms, row.plan)
	return root
