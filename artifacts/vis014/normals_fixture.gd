extends SceneTree

func _init() -> void:
	var result := SuiteResult.new("VIS-014 entrance normals")
	for mode in ["narthex", "tower", "both"]:
		var spec := ChurchSpec.new()
		spec.style = &"romanesque"
		spec.width = 12.0
		spec.length = 62.0
		spec.height = 22.0
		ChurchGenerator.generate(spec, 8120 if mode == "narthex" else 8111)
		spec.narthex = mode != "tower"
		spec.tower = mode != "narthex"
		spec.west_towers = 0 if mode == "narthex" else 1
		if spec.tower:
			spec.tower_width = 10.0
			spec.tower_height = 32.0
		var builder := ChurchBuilder.new()
		var mesh := builder.build(spec)
		result.checked += 1
		NormalsSuite.check_mesh(result, mesh, mode)
		NormalsSuite.check_openings(result, builder, mode)
	for failure in result.failures:
		print("FAIL: ", failure)
	print(result.summary())
	quit(0 if result.ok() else 1)
