extends "res://tools/render_church_roofs.gd"
## Exact audit fixtures, backface culling enabled by the shared stage.

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_stage()
	await process_frame
	for style in [&"renaissance", &"russian", &"byzantine"]:
		var spec := ChurchSpec.new()
		spec.style = style
		ChurchGenerator.generate(spec, 4413)
		_set_mesh(ChurchBuilder.new().build(spec), BuildingFamilyAdapter.colours(spec))
		await _look(Vector3(32, 35, -34), Vector3(0, 10, 0), "seams_" + style + "_4413.jpg")
	var temple := TempleSpec.new()
	temple.form = &"rotunda"
	TempleGenerator.generate(temple, 42)
	_set_mesh(TempleBuilder.new().build(temple), BuildingFamilyAdapter.colours(temple))
	await _look(Vector3(32, 32, -38), Vector3(0, 9, 0), "seams_rotunda_42.jpg")
	quit()
