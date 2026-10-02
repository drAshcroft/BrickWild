extends SceneTree
## One fast visual-reference render for the grand hotel landmark.
## Must run without --headless:
## godot --path . --script res://tools/render_hotel.gd

const OUT := "res://artifacts/renders/hotel_grand_budapest.jpg"
const SHOT := Vector2i(1400, 900)

var viewport: SubViewport
var stage: Node3D
var camera: Camera3D


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	_build_stage()
	var spec := HotelSpec.new()
	spec.style = &"grand_budapest"
	var plan := HotelGenerator.generate(spec, 43101, not OS.get_cmdline_user_args().has("--shell"))
	var node := HotelAssembler.build(plan, false)
	stage.add_child(node)
	await process_frame
	var bounds := SceneBounds.of_node(node)
	var centre := bounds.get_center()
	var vertical_fov := deg_to_rad(camera.fov)
	var aspect := float(SHOT.x) / float(SHOT.y)
	var horizontal_fov := 2.0 * atan(tan(vertical_fov * 0.5) * aspect)
	var distance := maxf(bounds.size.x * 0.5 / tan(horizontal_fov * 0.5),
		bounds.size.y * 0.5 / tan(vertical_fov * 0.5)) * 1.18 + bounds.size.z * 0.5
	var direction := Vector3(0.0, 0.10, -1.0).normalized()
	camera.position = centre + direction * distance
	camera.look_at(centre + Vector3(0, bounds.size.y * 0.03, 0), Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var result := image.save_jpg(OUT, 0.93)
	print("wrote %s (%s)" % [OUT, error_string(result)])
	quit(0 if result == OK else 1)


func _build_stage() -> void:
	viewport = SubViewport.new()
	viewport.size = SHOT
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("b8c4d1")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff4e8")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(-145.0), 0.0)
	sun.light_color = Color("fff0dd")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-18.0), deg_to_rad(35.0), 0.0)
	fill.light_color = Color("b9d4ff")
	fill.light_energy = 0.26
	stage.add_child(fill)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(300, 300)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("92978d")
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	stage.add_child(ground)

	camera = Camera3D.new()
	camera.fov = 44.0
	camera.far = 1000.0
	viewport.add_child(camera)
