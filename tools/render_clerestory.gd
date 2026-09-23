extends "res://tools/render_church_roofs.gd"
## Reuses the fixed church reference lighting for the new upper window course.

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_stage()
	await process_frame
	for landmark in ["notre_dame", "cologne"]:
		var spec := ChurchSpec.new()
		spec.style = &"gothic"
		spec.width = 12 if landmark == "notre_dame" else 14
		spec.length = 127 if landmark == "notre_dame" else 144
		spec.height = 33 if landmark == "notre_dame" else 43
		ChurchGenerator.generate(spec, 42)
		LandmarkSuite._force_features(landmark, spec)
		var builder := ChurchBuilder.new()
		var mesh := builder.build(spec)
		_set_mesh(mesh, [spec.stone_color, spec.trim_color, spec.roof_color, Color("161a20")])
		await _look(Vector3(90, 68, -100), Vector3(0, 19, 0), "clerestory_" + landmark + "_west.jpg")
		await _look(Vector3(-70, 42, 12), Vector3(0, spec.height * 0.76, 0), "clerestory_" + landmark + "_course.jpg")
	quit()
