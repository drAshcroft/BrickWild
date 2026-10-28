extends "res://tools/render_shots.gd"
## WITCH-THATCH-FORM review renders (real renderer, NOT headless): the thatch of
## the 7 x 9 hut at seed 1 from the walk camera height and close in: the gable
## end (apex and verges) and an eave end. Output: artifacts/witch_followups/thatch/
func _init() -> void:
	_build_stage()
	await process_frame
	_cam.current = true
	var out := "res://artifacts/witch_followups/thatch"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var tag := OS.get_environment("THATCH_TAG")
	for seed_v in [1, 8102]:
		var spec := HouseSpec.new(seed_v)
		spec.style = &"witch_hut"
		spec.width = 7.0
		spec.length = 9.0
		spec.height = 2.6
		var plan: HousePlan = HouseGenerator.generate(spec, seed_v, true)
		var building: Node3D = HouseAssembler.build(plan, false)
		_root3d.add_child(building)
		await process_frame
		_family = &"house"
		var door: Dictionary = plan.doors[plan.entrance()]
		var n := Vector2(door["normal"]).normalized()
		var tang := Vector2(n.y, -n.x)
		var dp := Vector2(door["pos"])
		var views := {"gable": [dp + n * 8.0, 2.4, Vector3(0, 3.0, 0)],
			"gable_side": [dp + n * 5.0 + tang * 5.0, 2.2, Vector3(0, 2.6, 0)],
			"eave": [dp - n * 3.0 + tang * 8.0, 2.0, Vector3(0, 2.3, 0)],
			"apex": [dp + n * 4.0 + tang * 1.5, 4.0, Vector3(0, 4.2, 0)]}
		for k in views:
			var v: Array = views[k]
			var eye: Vector2 = v[0]
			_cam.fov = 50.0
			_cam.position = Vector3(eye.x, float(v[1]), eye.y)
			_cam.look_at(v[2], Vector3.UP)
			_set_shot_lighting(atan2(n.x, n.y), 8.0)
			await _save("%s/%s_s%d_%s.png" % [out, tag, seed_v, k])
		building.queue_free()
		await process_frame
	quit(0)


func _save(path: String) -> Error:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered: Image = _vp.get_texture().get_image()
	return rendered.save_png(ProjectSettings.globalize_path(path))
