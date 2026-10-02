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
		roughness := DEFAULT_ROUGHNESS, hide := -1, vertex_colour_slots: Array = []) -> void:
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
		if slot in vertex_colour_slots:
			# the surface carries its own colours (a castle's ground skin and
			# yard dressing); the slot's colour tints them and white leaves them
			m.vertex_color_use_as_albedo = true
			m.vertex_color_is_srgb = true
		node.set_surface_override_material(i, m)


## Finish the two architectural surfaces from their metre-scale UVs. Stone,
## trim, roof and opening remain the original four slots; only stone and roof
## receive procedural variation. The renderer uses this same method for live
## scenes and reference portraits.
static func architectural_materials(node: MeshInstance3D, colors: Array,
		stone_slot := 0, roof_slot := 2) -> void:
	if DisplayServer.get_name() == "headless" or node.mesh == null:
		return
	var stone_colour: Color = colors[stone_slot] if stone_slot < colors.size() else NO_COLOUR
	node.set_surface_override_material(stone_slot, MaterialKit.church_stone(stone_colour))
	var roof_colour: Color = colors[roof_slot] if roof_slot < colors.size() else NO_COLOUR
	node.set_surface_override_material(roof_slot, MaterialKit.church_roof(roof_colour))


## Restrained, metre-scale roof courses. Kept opt-in to ordinary houses;
## four-surface castle/church/hotel shells retain their material contract.
static func house_materials(node: MeshInstance3D, spec: HouseSpec) -> void:
	if DisplayServer.get_name() == "headless":
		return # Dummy renderer has no shader instances; retain base material.
	var slate: bool = spec.roof_material == &"slate"
	node.set_surface_override_material(HouseBuilder.SURF_ROOF, MaterialKit.house_roof(
		spec.roof_color, 0.22 if slate else 0.30, 0.30 if slate else 0.42,
		spec.roof_material == &"thatch"))
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
uniform bool stone_floor = false;
varying vec3 floor_pos;
varying vec3 floor_normal;
void vertex() {
	floor_pos = VERTEX;
	floor_normal = NORMAL;
}
void fragment() {
	ALBEDO = floor_colour.rgb;
	ROUGHNESS = 0.94;
	// Metres, not the per-face 0..1 UV: a large hall must not have one
	// enormous plank. Vertical faces in this shared slot use masonry courses.
	if (floor_normal.y > 0.85) {
		vec2 p = floor_pos.xz / ((stone_floor || COLOR.g < 0.5) ? vec2(0.55) : vec2(0.20, 2.4));
		p.y += mod(floor(p.x), 2.0) * 0.5;
		vec2 cell = floor(p);
		vec2 edge = min(fract(p), vec2(1.0) - fract(p));
		vec2 aa = fwidth(p);
		vec2 seam = smoothstep(vec2(0.015), vec2(0.025) + aa, edge);
		float fade = 1.0 - clamp(max(aa.x, aa.y), 0.0, 1.0);
		float tone = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
		ALBEDO *= mix(1.0, (0.94 + tone * 0.12) * mix(0.68, 1.0, seam.x * seam.y), fade);
	} else if (abs(floor_normal.y) < 0.5) {
		// Chimneys and stone bases share this slot, but are masonry, not
		// vertical floorboards. Keep their courses at an architectural scale.
		float along = abs(floor_normal.x) > 0.5 ? floor_pos.z : floor_pos.x;
		vec2 p = vec2(along / 0.65, floor_pos.y / 0.24);
		p.x += mod(floor(p.y), 2.0) * 0.5;
		vec2 edge = min(fract(p), vec2(1.0) - fract(p));
		vec2 aa = fwidth(p);
		vec2 seam = smoothstep(vec2(0.025), vec2(0.045) + aa, edge);
		float fade = 1.0 - clamp(max(aa.x, aa.y), 0.0, 1.0);
		ALBEDO *= mix(1.0, mix(0.72, 1.0, seam.x * seam.y), fade);
	}
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
	floor_material.set_shader_parameter("stone_floor", spec.material == &"stone" or spec is HotelSpec)
	var palette := [Color("703c38"), Color("365b60"), Color("806438")]
	floor_material.set_shader_parameter("rug_colour", palette[absi(spec.seed) % palette.size()])
	node.set_surface_override_material(HouseBuilder.SURF_FLOOR, floor_material)


## Build the scene. `cutaway` leaves the roof surface undrawn, which is the
## only way to photograph an interior lit by things that are on fire.
static func build(node_name: String, mesh: ArrayMesh, colors: Array,
		props: Array, roof_surface: int, cutaway: bool,
		glow: Color = LightKit.FLAME, architectural_finish := false,
		vertex_colour_slots: Array = []) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	if mesh == null:
		return root

	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	shell.mesh = mesh
	surface_materials(shell, colors, DEFAULT_ROUGHNESS,
		-1, vertex_colour_slots)
	if architectural_finish:
		architectural_materials(shell, colors)
	if cutaway:
		shell.set_surface_override_material(roof_surface, invisible())
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
