extends "res://tools/render_shots.gd"
## Actual furnished stair approaches and upper wells, at human eye height.
const STAIR_OUT := "res://artifacts/personality/current/stairs"

func _init() -> void:
	_build_stage()
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STAIR_OUT))
	var fingerprint := _stair_source_hash()
	var rows: Array = []
	for fixture in [
		{"style": &"farmhouse", "width": 9.0, "length": 12.0, "storeys": 2, "seed": 8114},
		{"style": &"townhouse", "width": 9.0, "length": 12.0, "storeys": 3, "seed": 9302},
		{"style": &"longhall", "width": 17.0, "length": 18.0, "storeys": 2, "seed": 17018},
	]:
		fixture["height"] = 2.6
		fixture["trade"] = &"none"
		fixture["cellars"] = 0
		var spec := HouseSpec.new()
		for field in ["style", "width", "length", "height", "storeys", "trade", "cellars"]:
			spec.set(field, fixture[field])
		var plan := HouseGenerator.generate(spec, int(fixture.seed), true)
		var node := HouseAssembler.build(plan, false)
		_root3d.add_child(node)
		await process_frame
		for si in range(plan.stairs.size()):
			var stair: Dictionary = plan.stairs[si]
			if not bool(stair.get("satisfied", false)):
				rows.append({"fixture": fixture, "stair": si, "unsatisfied": stair})
				continue
			var foot := Rect2(stair.foot_landing).get_center()
			var head := Rect2(stair.head_landing).get_center()
			var lower_y := float(stair.storey) * spec.height + HouseGeometry.FLOOR_T
			var upper_y := float(stair.to_storey) * spec.height + HouseGeometry.FLOOR_T
			var direction := (head - foot).normalized()
			var views := [
				{"name": "approach", "eye": Vector3(foot.x, lower_y + 1.58, foot.y),
				 "target": Vector3(head.x, upper_y + 0.35, head.y)},
				{"name": "upper_well", "eye": Vector3(head.x, upper_y + 1.58, head.y),
				 "target": Vector3(foot.x, lower_y + 1.2, foot.y)},
			]
			for view in views:
				_cam.position = view.eye
				_cam.fov = 76.0
				_cam.look_at(view.target, Vector3.UP)
				_family = &"house"
				_set_shot_lighting(atan2(direction.x, direction.y), 30.0)
				await process_frame
				await RenderingServer.frame_post_draw
				await process_frame
				await RenderingServer.frame_post_draw
				var file := "%s_%d_stair%d_%s.jpg" % [spec.style, fixture.seed, si, view.name]
				var error := _vp.get_texture().get_image().save_jpg(ProjectSettings.globalize_path(STAIR_OUT.path_join(file)), 0.94)
				rows.append({"fixture": fixture, "stair": si, "view": view, "image": file,
					"save_error": error, "roof_on": true, "furniture": true})
				print("STAIR_RENDER ", file, " save=", error)
		node.queue_free()
		await process_frame
	var f := FileAccess.open(STAIR_OUT.path_join("manifest.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"rows": rows, "source_start": fingerprint,
		"source_end": _stair_source_hash(), "source_changed": fingerprint != _stair_source_hash()}, "\t"))
	quit()

func _stair_source_hash() -> String:
	var paths: Array[String] = []
	_stair_scripts("res://src", paths)
	_stair_scripts("res://core", paths)
	paths.sort()
	var hashes := PackedStringArray()
	for path in paths:
		hashes.append(path + ":" + FileAccess.get_sha256(path))
	return "\n".join(hashes).sha256_text()

func _stair_scripts(path: String, paths: Array[String]) -> void:
	var directory := DirAccess.open(path)
	for file in directory.get_files():
		if file.ends_with(".gd"):
			paths.append(path.path_join(file))
	for child in directory.get_directories():
		_stair_scripts(path.path_join(child), paths)
