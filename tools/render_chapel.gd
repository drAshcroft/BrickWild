extends SceneTree
## INT-005 reference. Run without --headless.

func _init() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1200, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("273242")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("ccd8e8")
	environment.ambient_light_energy = 0.65
	world.environment = environment
	viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	viewport.add_child(sun)
	var spec := CastleSpec.new()
	spec.style = &"edwardian"
	spec.width = 60
	spec.length = 90
	spec.height = 18
	CastleGenerator.generate(spec, 1)
	spec.chapel = true
	var plan := CastleInteriorPlans.chapel_plan(spec)
	var chapel := HouseAssembler.build(plan, true)
	viewport.add_child(chapel)
	var camera := Camera3D.new()
	camera.fov = 52
	viewport.add_child(camera)
	await process_frame
	var door: Vector2 = plan.doors[plan.entrance()].pos
	var focus: Vector2 = plan.focus_pos()
	var inward := (focus - door).normalized()
	camera.position = Vector3(door.x + inward.x * 0.8, 2.0, door.y + inward.y * 0.8)
	camera.look_at(Vector3(focus.x, 1.1, focus.y))
	await _save(viewport, "chapel_aisle.png")
	camera.position = Vector3(0, 24, -5)
	camera.look_at(Vector3.ZERO)
	await _save(viewport, "chapel_plan.png")
	quit()


func _save(viewport: SubViewport, name: String) -> void:
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/renders"))
	var path := "res://artifacts/renders/" + name
	var result := viewport.get_texture().get_image().save_png(path)
	if result != OK:
		push_error("Cannot save " + path)
	print(path)
