extends SceneTree
## VIS-003 visual swatch. Emits one physically scaled coursed-stone shader over
## the coordinate fixtures named in the todo, then saves one review image.

const OUT := "res://artifacts/vis003/metric_coordinates.png"
const SIZE := Vector2i(1800, 1000)

var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _shader_material: ShaderMaterial


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vis003"))
	_stage()
	await process_frame
	_add_box("2 m box", Vector3(2, 2, 2), Vector3(-26, 1, 0))
	_add_box("20 m wall", Vector3(20, 10, 0.8), Vector3(-13, 5, 0))
	_add_roof()
	_add_half_cylinder()
	_add_drum("12 sided drum", 12, Vector3(25, 0, 0))
	_add_drum("16 sided drum", 16, Vector3(36, 0, 0))
	_camera.position = Vector3(7, 29, 67)
	_camera.look_at(Vector3(7, 5, 0), Vector3.UP)
	for _frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	var error := image.save_png(OUT)
	if error != OK:
		printerr("Could not save metric coordinate swatch: ", error)
	else:
		print("Saved metric coordinate swatch: ", OUT)
	quit(0 if error == OK else 1)


func _stage() -> void:
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("506785")
	sky_material.sky_horizon_color = Color("bdc8ce")
	sky_material.ground_bottom_color = Color("30342f")
	sky_material.ground_horizon_color = Color("73776d")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-42), 0, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	_world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-24), deg_to_rad(52), 0)
	fill.light_energy = 0.42
	_world.add_child(fill)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 100)
	ground.mesh = plane
	ground.position.y = -0.12
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("57594f")
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	_world.add_child(ground)
	_camera = Camera3D.new()
	_camera.fov = 55.0
	_camera.far = 1000.0
	_viewport.add_child(_camera)
	_shader_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform vec4 stone_color : source_color = vec4(0.57, 0.53, 0.45, 1.0);
uniform float tile_width = 1.35;
uniform float course_height = 0.58;
void fragment() {
    vec2 p = UV / vec2(tile_width, course_height);
    float row = floor(p.y);
    p.x += mod(row, 2.0) * 0.5;
    vec2 edge = fract(p);
    float seams = smoothstep(0.015, 0.065, edge.y) * smoothstep(0.015, 0.055, edge.x);
    vec2 cell = floor(p);
    float tint = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
    vec3 block = stone_color.rgb * mix(0.79, 1.10, tint);
    ALBEDO = mix(vec3(0.16, 0.16, 0.15), block, seams);
    ROUGHNESS = 0.94;
}
"""
	_shader_material.shader = shader


func _add_box(label: String, size: Vector3, position: Vector3) -> void:
	var kit := MeshKit.new(1, true)
	kit.box(size, position, 0)
	_add_mesh(label, kit.commit(), position.x, 0)


func _add_roof() -> void:
	var center := Vector3(4, 0, 0)
	var points := PackedVector3Array([
		center + Vector3(-6, 6, -5), center + Vector3(6, 6, -5),
		center + Vector3(6, 0, 5), center + Vector3(-6, 0, 5)])
	var kit := MeshKit.new(1, true)
	kit.slab_poly(points, 0.25, 0)
	_add_mesh("sloped roof", kit.commit(), center.x, 0)


func _add_half_cylinder() -> void:
	var kit := MeshKit.new(1, true)
	kit.half_cylinder(4.0, 6.0, Vector2(15, 0), 0, 16)
	_add_mesh("half cylinder", kit.commit(), 15, 0)


func _add_drum(label: String, sides: int, center: Vector3) -> void:
	var kit := MeshKit.new(1, true)
	kit.drum(center, 4.3, 3.5, 10.0, 0, sides)
	_add_mesh(label, kit.commit(), center.x, 0)


func _add_mesh(label: String, mesh: ArrayMesh, x: float, _y: float) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.set_surface_override_material(0, _shader_material)
	_world.add_child(instance)
	var caption := Label3D.new()
	caption.text = label
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.font_size = 56
	caption.pixel_size = 0.018
	caption.modulate = Color("f4eee2")
	caption.outline_size = 12
	caption.position = Vector3(x, 0.8, 6.0)
	_world.add_child(caption)
