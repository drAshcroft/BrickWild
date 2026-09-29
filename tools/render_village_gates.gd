extends SceneTree
## Run without --headless. Actual planned/serialized crossing geometry.

func _init() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1200, 850)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b4c6c5")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d7e1e6")
	env.ambient_light_energy = 0.6
	world.environment = env
	viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -25, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 30
	viewport.add_child(camera)
	for kind in [&"hedge", &"palisade", &"wall"]:
		var spec := VillageSpec.new(19800)
		spec.enclosure = kind
		var plan := VillagePlan.new(spec)
		plan.site = Rect2(-45,-45,90,90)
		plan.lots.append({"poly": Poly.from_rect(Rect2(-14,-14,28,28))})
		plan.roads.append({"points": PackedVector2Array([Vector2(-45, -3), Vector2(45, 3)]),
			"class": &"through", "width": 6.0, "verge": 1.0})
		VillageEnclosurePlan.author(plan)
		VillageDressContext.enclosure_hedge(plan, VillageDressContext.make_context(plan))
		var node := VillageAssembler.build(plan)
		viewport.add_child(node)
		await process_frame
		var point: Vector2 = plan.gate_crossings[0]["pos"]
		var focus := Vector3(point.x, 1.0, point.y)
		camera.size = 24
		camera.position = focus + Vector3(14,12,17)
		camera.look_at(focus)
		for frame in 4:
			await process_frame
			await RenderingServer.frame_post_draw
		var path := "res://artifacts/p1p2_village/gateway_%s.png" % kind
		viewport.get_texture().get_image().save_png(path)
		print(path)
		node.queue_free()
		await process_frame
	quit()
