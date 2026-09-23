extends "res://tools/render_shots.gd"

func _init() -> void:
	_build_stage()
	await process_frame
	for stone in [false, true]:
		var spec := HouseSpec.new(4413)
		spec.style = &"farmhouse"
		spec.width = 11
		spec.length = 14
		spec.storeys = 1
		spec.material = &"stone" if stone else &"timber"
		var plan := HouseGenerator.generate(spec, spec.seed)
		var model := HouseAssembler.build(plan, true)
		_root3d.add_child(model)
		for view in ["cutaway", "hearth", "rug"]:
			var focus := Vector3(0, 0.4, 0)
			_cam.position = Vector3(12, 17, -18)
			if view == "hearth" and plan.hearth.has("breast"):
				var breast: Dictionary = plan.hearth["breast"]
				var c: Vector2 = breast["centre"]
				var n: Vector2 = breast["normal"]
				focus = Vector3(c.x, 1.15, c.y)
				_cam.position = Vector3(c.x + n.x * 3.5, 1.8, c.y + n.y * 3.5)
			if view == "rug" and not plan.rugs.is_empty():
				var centre: Vector2 = Rect2(plan.rugs[0]["rect"]).get_center()
				focus = Vector3(centre.x, 0.2, centre.y)
				_cam.position = focus + Vector3(2.0, 7.0, -3.0)
			_cam.look_at(focus, Vector3.UP)
			for frame in 3:
				await process_frame
				await RenderingServer.frame_post_draw
			var path := "res://artifacts/renders/house_details_%s_%s.jpg" % ["stone" if stone else "timber", view]
			_vp.get_texture().get_image().save_jpg(path, 0.94)
			print("HOUSE_DETAIL_RENDER ", path)
		model.queue_free()
		await process_frame
	quit()
