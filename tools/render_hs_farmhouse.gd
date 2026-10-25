extends "res://tools/render_shots.gd"
## HS-FARMHOUSE review renders (real renderer, NOT headless): per frozen request,
## a front three-quarter, a REAR three-quarter (back door, byre, yard) and an
## interior eye-level view of the kitchen toward its yard door.
## Output: artifacts/goal/HS-FARMHOUSE/renders/
func _init() -> void:
	_build_stage()
	await process_frame
	_cam.current = true
	var out := "res://artifacts/goal/HS-FARMHOUSE/renders"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for seed_value in [1, 8102, 21325]:
		var spec := HouseSpec.new(seed_value)
		spec.style = &"farmhouse"
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
		_cam.fov = 50.0
		var eye2 := dp + n * 11.0 + tang * 7.0
		_cam.position = Vector3(eye2.x, 5.0, eye2.y)
		_cam.look_at(Vector3(dp.x, 2.0, dp.y), Vector3.UP)
		_set_shot_lighting(atan2(n.x, n.y), 8.0)
		await _save_review_image(out.path_join("farmhouse_%d_front.jpg" % seed_value))
		# Rear three-quarter: from the byre's side, behind the house.
		var centre := dp - n * 5.0
		var side := tang
		for pc in plan.yard_pieces:
			if str(pc["kind"]) == "byre":
				var rc: Rect2 = pc["rect"]
				var off := rc.get_center() - centre
				side = tang * signf(off.dot(tang)) if absf(off.dot(tang)) > 0.5 else tang
		var back := centre - n * 10.0 + side * 10.0
		_cam.fov = 52.0
		_cam.position = Vector3(back.x, 5.5, back.y)
		_cam.look_at(Vector3(centre.x + side.x * 2.0, 1.2, centre.y + side.y * 2.0 - n.y * 2.0), Vector3.UP)
		_set_shot_lighting(atan2(-n.x, -n.y), 8.0)
		await _save_review_image(out.path_join("farmhouse_%d_rear.jpg" % seed_value))
		# Interior: stand at the far end of the kitchen, look at the yard door.
		for i in plan.doors.size():
			var bd: Dictionary = plan.doors[i]
			if i == plan.entrance() or not bd["exterior"]:
				continue
			var bn := Vector2(bd["normal"]).normalized()
			var bp := Vector2(bd["pos"])
			var room: Rect2 = plan.rooms[int(bd["a"])]["rect"]
			var depth := absf(bn.x) * room.size.x + absf(bn.y) * room.size.y
			var e := bp - bn * (depth - 0.45) + Vector2(bn.y, -bn.x) * 0.2
			_cam.fov = 70.0
			_cam.position = Vector3(e.x, 1.58, e.y)
			_cam.look_at(Vector3(bp.x, 1.1, bp.y), Vector3.UP)
			_set_shot_lighting(atan2(bn.x, bn.y), 8.0)
			await _save_review_image(out.path_join("farmhouse_%d_interior.jpg" % seed_value))
			break
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
