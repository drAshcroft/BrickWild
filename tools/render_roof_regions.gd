extends "res://tools/render_shots.gd"
## Corrected ziggurats, using the real assembled model and props.
const REGION_OUT := "res://artifacts/p1p2_roof_regions/renders"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REGION_OUT))
	_build_stage()
	await process_frame
	for size in [Vector2(18, 24), Vector2(24, 30)]:
		var spec := TempleSpec.new(4413)
		spec.form = &"ziggurat"
		spec.width = size.x
		spec.length = size.y
		spec.height = 14
		TempleGenerator.generate(spec, spec.seed)
		var model := TempleAssembler.build(spec)
		_root3d.add_child(model)
		for view in ["front", "summit", "chamber"]:
			var focus := Vector3(0, 6, -3)
			var direction := Vector3(1.0, 0.72, -1.4).normalized()
			var distance := 64.0
			if view == "summit":
				focus = TempleGeometry.idol_center(spec) + Vector3.UP * 1.5
				direction = Vector3(1.0, 1.2, 1.4).normalized()
				distance = 33.0
			_cam.position = focus + direction * distance
			if view == "chamber":
				_cam.position = Vector3(0, 1.65, TempleGeometry.hall_rect(spec).position.y + 0.4)
				focus = TempleGeometry.altar_center(spec) + Vector3.UP * 1.0
			_cam.look_at(focus, Vector3.UP)
			for frame in 3:
				await process_frame
				await RenderingServer.frame_post_draw
			var path := "%s/ziggurat_%dx%d_%s.jpg" % [REGION_OUT, size.x, size.y, view]
			_vp.get_texture().get_image().save_jpg(path, 0.94)
			print("ROOF_REGION_RENDER ", path)
		model.queue_free()
		await process_frame
	print("Roof region renders complete")
	quit()
