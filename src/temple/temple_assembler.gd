class_name TempleAssembler
extends RefCounted
## Turns a built temple into a scene: the stone, and an instance of the real
## model for every brazier, cage, chain and candle in it.
##
## The same split as the houses. Everything above this file works in metres and
## never loads a model, which is what lets the rite harness run headless in
## milliseconds; here at the end the architecture is handed its dressing.

## `cutaway` leaves the roof off, which is the only way to photograph an
## interior lit by things that are on fire.
static func build(spec: TempleSpec, cutaway := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Temple"

	var builder := TempleBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	var shell := MeshInstance3D.new()
	shell.name = "Stone"
	shell.mesh = mesh
	# The roof surface is simply not drawn for a cutaway: everything else
	# stays, so the columns still stand and the sightline is still the
	# sightline. ShellAssembler does the whole of it (API-005).
	ShellAssembler.surface_materials(shell, BuildingFamilyAdapter.colours(spec),
		ShellAssembler.DEFAULT_ROUGHNESS,
		TempleBuilder.SURF_ROOF if cutaway else -1)
	shell.set_surface_override_material(TempleBuilder.SURF_STONE,
		MaterialKit.ashlar(spec.stone_color, false, Vector2(1.2, 0.5)))
	root.add_child(shell)

	var props := Node3D.new()
	props.name = "Dressing"
	root.add_child(props)
	for p in builder.prop_log:
		var node: Node3D = _instance(p)
		if node != null:
			props.add_child(node)
	_light_the_fires(root, builder, spec)
	return root


static func _instance(p: Dictionary) -> Node3D:
	var key: String = p["key"]
	var path: String = PropCatalog.scene_path(key)
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var node: Node3D = packed.instantiate()
	node.name = key
	var s: float = float(p.get("scale", 1.0))
	node.scale = Vector3.ONE * s
	node.rotation.y = float(p["yaw"]) + PropCatalog.face_offset(key)
	var pos: Vector3 = p["pos"]
	var drop: float = PropCatalog.floor_offset(key) * s
	if PropCatalog.has_tag(key, PropCatalog.WALL_MOUNTED) \
			or PropCatalog.has_tag(key, PropCatalog.CEILING):
		drop = 0.0
	node.position = Vector3(pos.x, pos.y - drop, pos.z)
	return node


## Every flame gets a light, in the cult's own colour.
##
## The houses do without this and are the poorer for it. Here it is not
## decoration: the rite check spends a whole rule on whether the way to the
## altar is lit, and a temple that passes that rule in the report while being
## pitch black in the render would be a harness lying to itself.
static func _light_the_fires(root: Node3D, builder: TempleBuilder,
		spec: TempleSpec) -> void:
	# the same lamp the houses get (LightKit, LAY-011), at the measured flame
	# of each brazier, in the cult's colour and with a brazier's reach
	var reach: float = TempleGeometry.LIGHT_REACH * 1.5 / float(LightKit.TABLE["brazier"]["reach"])
	for p in builder.prop_log:
		if p["kind"] != &"light":
			continue
		var key: String = p["key"]
		var s: float = float(p.get("scale", 1.0))
		var pos: Vector3 = p["pos"]
		var drop: float = PropCatalog.floor_offset(key) * s
		var yaw: float = float(p.get("yaw", 0.0)) + PropCatalog.face_offset(key)
		var lamp: OmniLight3D = LightKit.for_prop(key, Vector3(pos.x, pos.y - drop, pos.z),
			yaw, s, spec.glow_color, reach)
		lamp.light_energy = 1.25
		root.add_child(lamp)
	# and the god himself: a low flame in the cult's colour before the idol, so
	# the end of the axis is never a silhouette against nothing
	var idol: Vector3 = TempleGeometry.idol_center(spec)
	var rim: OmniLight3D = LightKit.make(
		Vector3(idol.x, idol.y + spec.idol_height * 0.55,
			idol.z - spec.idol_width * 0.75),
		spec.glow_color.lerp(Color("fff0da"), 0.35), 2.6, maxf(spec.idol_height * 2.6, 6.0))
	rim.name = "IdolLight"
	root.add_child(rim)
