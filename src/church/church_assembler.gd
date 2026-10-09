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
	var root := ShellAssembler.build("Church", mesh, [spec.stone_color, spec.trim_color,
		spec.roof_color, Color("1a1c20"), Color.WHITE,
		Color.WHITE], builder.prop_log,
		ChurchBuilder.SURF_ROOF, cutaway, LightKit.FLAME, true)
	_finish_nordic_timber(root, spec)
	_finish_glazing(root)
	_finish_painted_domes(root)
	return root


## ShellAssembler's palette is colour-only. Install procedural materials after
## its colour pass by the builder's logical slot, which survives empty streams.
static func _finish_nordic_timber(root: Node3D, spec: ChurchSpec) -> void:
	if spec.style != &"nordic_stave":
		return
	var shell := root.get_node_or_null("Shell") as MeshInstance3D
	if shell == null or shell.mesh == null:
		return
	for surface in range(shell.mesh.get_surface_count()):
		var slot := surface
		var surface_name: String = shell.mesh.surface_get_name(surface)
		if surface_name.begins_with("material_slot:"):
			slot = int(surface_name.trim_prefix("material_slot:"))
		if slot == ChurchBuilder.SURF_WOOD:
			shell.set_surface_override_material(surface,
				MaterialKit.timber(spec.stone_color, true, true))


## The onions of a hero St Basil's carry their own colours in the mesh's
## vertex colours, so their surface takes them as albedo.
static func _finish_painted_domes(root: Node3D) -> void:
	var shell := root.get_node_or_null("Shell") as MeshInstance3D
	if shell == null or shell.mesh == null:
		return
	var accent_present := false
	for surface in range(shell.mesh.get_surface_count()):
		var slot := surface
		if shell.mesh is ArrayMesh:
			var surface_name := (shell.mesh as ArrayMesh).surface_get_name(surface)
			if surface_name.begins_with("material_slot:"):
				slot = int(surface_name.trim_prefix("material_slot:"))
		if slot == ChurchBuilder.SURF_ACCENT:
			accent_present = true
			break
	if not accent_present:
		return
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.roughness = 0.42
	paint.metallic = 0.18
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	var materials: Array = []
	materials.resize(ChurchBuilder.SURF_ACCENT + 1)
	materials[ChurchBuilder.SURF_ACCENT] = paint
	MaterialKit.apply(shell, materials)


## The black vertex marker belongs to panes seated in cut masonry throats.
## A recessed window keeps the original dark material in the same slot.
static func _finish_glazing(root: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var shell := root.get_node_or_null("Shell") as MeshInstance3D
	if shell == null:
		return
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled;
void fragment() {
	if (COLOR.r < 0.5) {
		vec2 grid = UV * vec2(0.95, 0.85);
		vec2 edge = min(fract(grid), vec2(1.0) - fract(grid));
		float lead = 1.0 - smoothstep(0.010, 0.035, min(edge.x, edge.y));
		vec2 cell = floor(grid);
		float tint = fract(sin(dot(cell, vec2(17.13, 41.71))) * 43758.5453);
		vec3 blue = vec3(0.025, 0.055, 0.085);
		vec3 jewel = tint > 0.84 ? vec3(0.11, 0.035, 0.045) : vec3(0.035, 0.09, 0.10);
		vec3 glass = mix(blue, jewel, 0.45 + 0.35 * tint);
		ALBEDO = mix(glass, vec3(0.018, 0.024, 0.031), lead);
		EMISSION = glass * (1.0 - lead) * 0.025;
		ROUGHNESS = 0.24;
	} else {
		ALBEDO = vec3(0.020, 0.025, 0.031);
		ROUGHNESS = 0.82;
	}
}
"""
	var glass := ShaderMaterial.new()
	glass.shader = shader
	shell.set_surface_override_material(ChurchBuilder.SURF_OPEN, glass)
