extends SceneTree
## INT-007 reference: run WITHOUT --headless to capture stone shells and props.
## godot --path . --script res://tools/render_castle_interiors.gd
const OUT := "res://artifacts/renders"
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	viewport = SubViewport.new()
	viewport.size = Vector2i(1400, 1000)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("263449")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c5d7ee")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 180)
	ground.mesh = plane
	ground.position.y = -0.03
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("65705a")
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	stage.add_child(ground)
	camera = Camera3D.new()
	camera.fov = 48
	camera.far = 1000
	viewport.add_child(camera)
	await process_frame
	var shapes: Array[StringName] = [&"square", &"round", &"tiered"]
	if not OS.get_cmdline_user_args().is_empty():
		shapes.clear()
		for arg in OS.get_cmdline_user_args():
			if arg not in ["square", "round", "tiered"]:
				push_error("Unknown keep shape: " + arg)
				quit(2)
				return
			shapes.append(StringName(arg))
	for shape in shapes:
		var spec := CastleSpec.new()
		spec.style = &"norman"
		spec.width = 40
		spec.length = 55
		spec.height = 14
		CastleGenerator.generate(spec, 42)
		spec.keep_shape = shape
		for cutaway in [false, true]:
			var castle := CastleAssembler.build(spec, cutaway)
			stage.add_child(castle)
			var keep := CastleGeometry.keep_aabb(spec)
			camera.position = Vector3(54, 65, -69)
			camera.look_at(Vector3(0, 8, 0))
			await _save("castle_%s_%s.png" % [shape, "roof_off" if cutaway else "roof_on"])
			if cutaway:
				camera.position = keep.get_center() + Vector3(5, 32, -8)
				camera.look_at(Vector3(keep.get_center().x, keep.end.y - 2.5, keep.get_center().z))
				await _save("castle_%s_lords_chamber.png" % shape)
				print("%s: %d interior lights" % [shape, _lights(castle)])
			castle.free()
	print("Castle interior references complete: " + OUT)
	quit()

func _save(filename: String) -> void:
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image().save_png(OUT + "/" + filename)
	if result != OK:
		push_error("Could not save " + filename)
	print(filename)

func _lights(node: Node) -> int:
	var total := 1 if node is OmniLight3D else 0
	for child in node.get_children():
		total += _lights(child)
	return total
