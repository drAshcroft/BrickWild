extends "res://tools/render_shots.gd"
## WITCH-ROOF review renders (real renderer, NOT headless): the frozen huts
## (7 x 9 at three seeds, 5.5 x 7 at seed 1), a front and a side three-quarter.
## Output: artifacts/goal/WITCH-ROOF/renders/
func _init() -> void:
	_build_stage()
	await process_frame
	_cam.current = true
	var out := "res://artifacts/goal/WITCH-ROOF/renders2"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var cases := [[7.0, 9.0, 1], [7.0, 9.0, 8102], [7.0, 9.0, 21325], [5.5, 7.0, 1]]
	for c in cases:
		var spec := HouseSpec.new(int(c[2]))
		spec.style = &"witch_hut"
		spec.width = c[0]
		spec.length = c[1]
		spec.height = 2.6
		var plan: HousePlan = HouseGenerator.generate(spec, int(c[2]), true)
		var building: Node3D = HouseAssembler.build(plan, false)
		_root3d.add_child(building)
		await process_frame
		_family = &"house"
		var door: Dictionary = plan.doors[plan.entrance()]
		var n := Vector2(door["normal"]).normalized()
		var tang := Vector2(n.y, -n.x)
		var dp := Vector2(door["pos"])
		var tag := "%dx%d_s%d" % [int(c[0] * 10), int(c[1] * 10), int(c[2])]
		var views := {"front": dp + n * 10.0 + tang * 6.0, "side": dp - n * 4.0 + tang * 11.0}
		for k in views:
			var eye: Vector2 = views[k]
			_cam.fov = 50.0
			_cam.position = Vector3(eye.x, 3.2, eye.y)
			_cam.look_at(Vector3(0.0, 2.6, 0.0), Vector3.UP)
			_set_shot_lighting(atan2(n.x, n.y), 8.0)
			await _save_review_image(out.path_join("witch_%s_%s.jpg" % [tag, k]))
		building.queue_free()
		await process_frame
	quit(0)


func _save_review_image(path: String) -> Error:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered: Image = _vp.get_texture().get_image()
	return rendered.save_jpg(ProjectSettings.globalize_path(path), 0.94)
