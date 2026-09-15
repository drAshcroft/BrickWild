extends "res://tools/render_church_roofs.gd"
## CAS-012 reference renders. Run without --headless.

const DEST := "res://artifacts/renders"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	_stage()
	await process_frame
	for row in [
			{"style": &"wizard", "w": 9.0, "l": 9.0, "h": 42.0,
				"tier": &"house", "seed": 12012, "eye": Vector3(50, 38, -55),
				"at": Vector3(0, 22, 0)},
			{"style": &"dark", "w": 40.0, "l": 55.0, "h": 14.0,
				"tier": &"castle", "seed": 9249, "eye": Vector3(72, 48, -78),
				"at": Vector3(0, 18, 0)},
			{"style": &"sky", "w": 80.0, "l": 110.0, "h": 14.0,
				"tier": &"castle", "seed": 12012, "eye": Vector3(165, 125, -175),
				"at": Vector3(0, 62, 0)},
	]:
		var spec := CastleSpec.new()
		spec.style = row.style
		spec.width = row.w
		spec.length = row.l
		spec.height = row.h
		spec.tier_override = row.tier
		CastleGenerator.generate(spec, row.seed)
		_set_mesh(CastleBuilder.new().build(spec), [spec.stone_color, spec.trim_color,
			spec.roof_color, Color("11131c")])
		await _capture(row.eye, row.at, "castle_%s.jpg" % String(row.style))
		if row.style == &"dark":
			await _capture(Vector3(-42, 62, -18), Vector3(0, 13, 0),
				"castle_dark_joins.jpg")
	print("Fantasy castle renders complete")
	quit()


func _capture(eye: Vector3, at: Vector3, file: String) -> void:
	_cam.position = eye
	_cam.look_at(at, Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_jpg(DEST + "/" + file, 0.94)
	print(file)
