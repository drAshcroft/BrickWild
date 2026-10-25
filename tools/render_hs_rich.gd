extends "res://tools/render_shots.gd"
## HS-RICH review renders (real renderer, NOT headless): per frozen request, a
## roof-on front three-quarter (the cornice and string courses on the floor
## lines), the entry hall looking at the stair, the parlour and the dining room
## at eye level. Output: artifacts/hs_rich/renders/
func _init() -> void:
	_build_stage()
	await process_frame
	_cam.current = true
	var out := "res://artifacts/hs_rich/renders"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for seed_value in [1, 8102, 21325]:
		var spec := HouseSpec.new(seed_value)
		spec.style = &"rich"
		spec.width = 9.0
		spec.length = 11.0
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
		var eye2 := dp + n * 19.0 + tang * 10.0
		_cam.position = Vector3(eye2.x, 7.5, eye2.y)
		_cam.look_at(Vector3(dp.x, 3.6, dp.y), Vector3.UP)
		_set_shot_lighting(atan2(n.x, n.y), 8.0)
		await _save_review_image(out.path_join("rich_%d_front.jpg" % seed_value))
		# Entry hall: from the door end towards the stair foot.
		var st: Dictionary = plan.stairs[0]
		var foot := Rect2(st["foot_landing"]).get_center()
		var head := Rect2(st["head_landing"]).get_center()
		var climb := (head - foot).normalized()
		var hall := HouseGeometry.room_floor_rect(plan, int(st["a"]))
		var back := foot - climb * minf(2.6, _room_reach(hall, foot, -climb))
		_cam.fov = 75.0
		_cam.position = Vector3(back.x, 1.58, back.y)
		_cam.look_at(Vector3(foot.x + climb.x * 1.5, 1.4, foot.y + climb.y * 1.5), Vector3.UP)
		_set_shot_lighting(atan2(climb.x, climb.y), 8.0)
		await _save_review_image(out.path_join("rich_%d_hall_stair.jpg" % seed_value))
		for kind in [&"parlour", &"dining_room"]:
			for i in plan.rooms_on_storey(0):
				if plan.kind_of(i) != kind:
					continue
				_look_across(plan, HouseGeometry.room_floor_rect(plan, i), 0.0, "")
				_cam.fov = 100.0
				await _save_review_image(out.path_join("rich_%d_%s.jpg" % [seed_value, kind]))
				break
		building.queue_free()
		await process_frame
	quit(0)


func _room_reach(r: Rect2, p: Vector2, dir: Vector2) -> float:
	var t := 0.0
	while t < 6.0 and r.grow(-0.3).has_point(p + dir * (t + 0.2)):
		t += 0.2
	return t


## Eye-level view across a room from its far corner to its middle.
func _look_across(plan: HousePlan, rr: Rect2, _lift: float, _path: String) -> void:
	var c := rr.get_center()
	var long_x := rr.size.x >= rr.size.y
	var from := Vector2(rr.position.x + 0.5, c.y) if long_x else Vector2(c.x, rr.position.y + 0.5)
	var to := Vector2(rr.end.x - 0.5, c.y) if long_x else Vector2(c.x, rr.end.y - 0.5)
	_cam.fov = 78.0
	_cam.position = Vector3(from.x, 1.58, from.y)
	_cam.look_at(Vector3(to.x, 1.0, to.y), Vector3.UP)
	_set_shot_lighting(atan2(to.x - from.x, to.y - from.y), 8.0)


func _save_review_image(path: String) -> Error:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered: Image = _vp.get_texture().get_image()
	return rendered.save_jpg(ProjectSettings.globalize_path(path), 0.94)
