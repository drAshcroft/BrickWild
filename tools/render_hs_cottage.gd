extends "res://tools/render_shots.gd"
## HS-COTTAGE review renders (real renderer, NOT headless): per frozen request,
## one roof-on three-quarter exterior and one interior eye-level view toward the
## hearth. Output: artifacts/goal/HS-COTTAGE/renders/
func _init() -> void:
	_build_stage()
	await process_frame
	_cam.current = true
	var out := "res://artifacts/goal/HS-COTTAGE/renders"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for seed_value in [1, 8102, 21325]:
		var spec := HouseSpec.new(seed_value)
		spec.style = &"cottage"
		spec.width = 8.0
		spec.length = 10.0
		spec.height = 2.6
		var plan: HousePlan = HouseGenerator.generate(spec, seed_value, true)
		var building: Node3D = HouseAssembler.build(plan, false)
		_root3d.add_child(building)
		await process_frame
		_family = &"house"
		var door: Dictionary = plan.doors[plan.entrance()]
		var n := Vector2(door["normal"]).normalized()
		var tang := Vector2(n.y, -n.x)
		var dp := Vector2(door["pos"])
		var eye2 := dp + n * 9.0 + tang * 6.0
		_cam.fov = 50.0
		_cam.position = Vector3(eye2.x, 5.0, eye2.y)
		_cam.look_at(Vector3(dp.x, 2.0, dp.y), Vector3.UP)
		_set_shot_lighting(atan2(n.x, n.y), 8.0)
		await _save_review_image(out.path_join("cottage_%d_exterior.jpg" % seed_value))
		var breast: Dictionary = HouseGeometry.hearth_breast(plan)
		if not breast.is_empty():
			var bn: Vector2 = breast.normal
			var face: Vector2 = Vector2(breast.centre) + bn * float(breast.depth) * 0.5
			var bt := Vector2(bn.y, -bn.x)
			var e := face + bn * 2.2 + bt * 0.45
			_cam.fov = 66.0
			_cam.position = Vector3(e.x, 1.58, e.y)
			_cam.look_at(Vector3(face.x, 0.95, face.y), Vector3.UP)
			_set_shot_lighting(atan2(bn.x, bn.y), 8.0)
			await _save_review_image(out.path_join("cottage_%d_interior.jpg" % seed_value))
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
