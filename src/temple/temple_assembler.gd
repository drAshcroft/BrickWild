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
	var cols := [spec.stone_color, spec.trim_color, spec.roof_color, Color("07070a")]
	for i in range(mesh.get_surface_count()):
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[i]
		m.roughness = 0.95
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		shell.set_surface_override_material(i, m)
	if cutaway:
		# the roof surface is simply not drawn: everything else stays, so the
		# columns still stand and the sightline is still the sightline
		shell.set_surface_override_material(TempleBuilder.SURF_ROOF, _invisible())
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


static func _invisible() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0, 0, 0, 0)
	return m


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
	for p in builder.prop_log:
		if p["kind"] != &"light":
			continue
		var lamp := OmniLight3D.new()
		lamp.light_color = spec.glow_color
		lamp.light_energy = 2.4
		lamp.omni_range = TempleGeometry.LIGHT_REACH * 1.5
		lamp.omni_attenuation = 1.4
		var pos: Vector3 = p["pos"]
		lamp.position = Vector3(pos.x, pos.y + 1.0, pos.z)
		root.add_child(lamp)
