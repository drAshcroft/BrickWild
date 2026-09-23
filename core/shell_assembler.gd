class_name ShellAssembler
extends RefCounted
## Turns a built shell and its dressing into a scene.
##
## Every family that emits a MassBuilder shell rather than a HousePlan --
## church, castle, and the temple before them -- ends the same way: one
## MeshInstance3D with a material per surface, an instance of the real model
## for every prop in `prop_log`, and a light at every flame. That ending lives
## here so a lamp that is dark in one family is dark in all of them and fixed
## once, which is the same argument LightKit makes about the houses.
##
## Nothing above this file loads a model. That is what lets the whole massing
## harness run headless in milliseconds per building.

## How rough a wall is. Every family used its own number for no reason any of
## them could have stated -- 0.88, 0.9, 0.95, 1.0 -- so they use this one and
## a family that genuinely wants another passes it.
const DEFAULT_ROUGHNESS := 0.92
## What a surface with no colour of its own gets.
const NO_COLOUR := Color("1a1c20")


## A material per surface, from the family's own colours (API-005).
##
## Every family ends the same way and each had its own copy of this loop: the
## colours in surface order, roughness, and `CULL_DISABLED` because a shell is
## a box seen from inside as often as from out and a wall the camera is behind
## must not vanish. `hide` is the surface a cutaway leaves undrawn, or -1.
##
## Materials and not meshes: nothing here loads an asset, so a headless build
## is unaffected by any of it.
static func surface_materials(node: MeshInstance3D, colors: Array,
		roughness := DEFAULT_ROUGHNESS, hide := -1) -> void:
	if node.mesh == null:
		return
	for i in range(node.mesh.get_surface_count()):
		var slot := i
		if node.mesh is ArrayMesh:
			var surface_name := (node.mesh as ArrayMesh).surface_get_name(i)
			if surface_name.begins_with("material_slot:"):
				slot = int(surface_name.trim_prefix("material_slot:"))
		if slot == hide:
			node.set_surface_override_material(i, invisible())
			continue
		var m := StandardMaterial3D.new()
		var c = colors[slot] if slot >= 0 and slot < colors.size() else NO_COLOUR
		m.albedo_color = c if c is Color else NO_COLOUR
		m.roughness = roughness
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		node.set_surface_override_material(i, m)


## Restrained, metre-scale roof courses. Kept opt-in to ordinary houses;
## four-surface castle/church/hotel shells retain their material contract.
static func house_materials(node: MeshInstance3D, spec: HouseSpec) -> void:
	if DisplayServer.get_name() == "headless":
		return # Dummy renderer has no shader instances; retain base material.
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform vec4 roof_colour : source_color;
uniform float course = 0.28;
uniform float tile_width = 0.36;
uniform bool thatch = false;
void fragment() {
	vec2 p = UV / vec2(tile_width, course);
	float row = floor(p.y);
	p.x += mod(row, 2.0) * 0.5;
	vec2 cell = floor(p);
	float tint = fract(sin(dot(cell, vec2(12.9898,78.233))) * 43758.5453);
	vec2 edge = fract(p);
	float seam = smoothstep(0.015, 0.065, edge.y);
	if (!thatch) { seam *= smoothstep(0.015, 0.05, edge.x); }
	float reed = thatch ? 0.96 + 0.04 * sin(UV.x * 115.0) : 1.0;
	ALBEDO = roof_colour.rgb * mix(0.68, 0.91 + tint * 0.16, seam) * reed;
	ROUGHNESS = 0.94;
	if (COLOR.r < 0.5) {
		ALBEDO = vec3(0.1529, 0.3372, 0.3763);
		ROUGHNESS = 0.22;
		METALLIC = 0.25;
	}
}
"""
	var roof := ShaderMaterial.new()
	roof.shader = shader
	roof.set_shader_parameter("roof_colour", spec.roof_color)
	roof.set_shader_parameter("course", 0.22 if spec.roof_material == &"slate" else 0.30)
	roof.set_shader_parameter("tile_width", 0.30 if spec.roof_material == &"slate" else 0.42)
	roof.set_shader_parameter("thatch", spec.roof_material == &"thatch")
	node.set_surface_override_material(HouseBuilder.SURF_ROOF, roof)
	house_floor_material(node, spec)


## Textiles share the floor material slot, including stone houses. Roofing
## remains a separate opt-in because family shells own their roof palettes.
static func house_floor_material(node: MeshInstance3D, spec: HouseSpec) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var textile := Shader.new()
	textile.code = """shader_type spatial;
render_mode cull_disabled;
uniform vec4 floor_colour : source_color;
uniform vec4 rug_colour : source_color;
void fragment() {
	ALBEDO = floor_colour.rgb;
	ROUGHNESS = 0.94;
	if (COLOR.r < 0.5) {
		vec2 edge = min(UV, vec2(1.0) - UV);
		float border = step(0.055, min(edge.x, edge.y)) * (1.0 - step(0.09, min(edge.x, edge.y)));
		float weave = 0.96 + 0.04 * sin(UV.x * 540.0) * sin(UV.y * 540.0);
		ALBEDO = mix(rug_colour.rgb, vec3(0.72, 0.56, 0.30), border * 0.85) * weave;
	}
}
"""
	var floor_material := ShaderMaterial.new()
	floor_material.shader = textile
	floor_material.set_shader_parameter("floor_colour", spec.floor_color)
	var palette := [Color("703c38"), Color("365b60"), Color("806438")]
	floor_material.set_shader_parameter("rug_colour", palette[absi(spec.seed) % palette.size()])
	node.set_surface_override_material(HouseBuilder.SURF_FLOOR, floor_material)


## Build the scene. `cutaway` leaves the roof surface undrawn, which is the
## only way to photograph an interior lit by things that are on fire.
static func build(node_name: String, mesh: ArrayMesh, colors: Array,
		props: Array, roof_surface: int, cutaway: bool,
		glow: Color = LightKit.FLAME) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	if mesh == null:
		return root

	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	shell.mesh = mesh
	surface_materials(shell, colors, DEFAULT_ROUGHNESS,
		roof_surface if cutaway else -1)
	root.add_child(shell)

	if props.is_empty():
		return root
	var dressing := Node3D.new()
	dressing.name = "Dressing"
	root.add_child(dressing)
	for p in props:
		var node: Node3D = instance(p)
		if node != null:
			dressing.add_child(node)
	_light_the_fires(root, props, glow)
	return root


## One prop, at the place the furnisher put it, or null when the model is
## missing. A missing model is not an error here: the checks measure the
## placements, and a build with an incomplete asset folder should still show
## the architecture.
static func instance(p: Dictionary) -> Node3D:
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
	node.position = world_origin(p)
	return node


## Where a prop's own origin ends up: its recorded position, dropped by however
## far the model's feet sit below that origin. A piece that hangs -- on a wall
## or from the ceiling -- is not dropped: its recorded position IS its mount.
static func world_origin(p: Dictionary) -> Vector3:
	var key: String = p["key"]
	var s: float = float(p.get("scale", 1.0))
	var pos: Vector3 = p["pos"]
	if PropCatalog.has_tag(key, PropCatalog.WALL_MOUNTED) \
			or PropCatalog.has_tag(key, PropCatalog.CEILING):
		return pos
	return Vector3(pos.x, pos.y - PropCatalog.floor_offset(key) * s, pos.z)


## Every flame gets a light (LAY-011).
##
## A placement is a flame when the furnisher said so -- kind &"light" -- or
## when the catalogue tags the prop LIGHT. Both, because a Cauldron standing in
## for a brazier is a fire the catalogue does not know about, and a torch is a
## fire whatever the furnisher called it.
static func _light_the_fires(root: Node3D, props: Array, glow: Color) -> void:
	for p in props:
		var key: String = p["key"]
		if StringName(p.get("kind", &"")) != &"light" \
				and not PropCatalog.has_tag(key, PropCatalog.LIGHT):
			continue
		root.add_child(LightKit.for_prop(key, world_origin(p),
			float(p.get("yaw", 0.0)) + PropCatalog.face_offset(key),
			float(p.get("scale", 1.0)), glow))


## A material that draws nothing: what a cutaway roof gets.
static func invisible() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0, 0, 0, 0)
	return m
