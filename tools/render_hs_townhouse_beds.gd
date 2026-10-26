extends "res://tools/render_shots.gd"
## HS-TOWNHOUSE bedroom review renders (real renderer, NOT headless): per frozen request,
## per frozen request, an upper bedroom at eye level with its bed in view.
## Output: artifacts/goal/HS-TOWNHOUSE/renders2/
func _init() -> void:
	_build_stage()
	await process_frame
	_cam.current = true
	var out := "res://artifacts/goal/HS-TOWNHOUSE/renders2"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for seed_value in [1, 8102, 21325]:
		var spec := HouseSpec.new(seed_value)
		spec.style = &"townhouse"
		spec.width = 8.0
		spec.length = 10.0
		spec.height = 2.6
		var plan: HousePlan = HouseGenerator.generate(spec, seed_value, true)
		var building: Node3D = HouseAssembler.build(plan, false)
		_root3d.add_child(building)
		await process_frame
		_family = &"house"
		var bed := -1
		var best := -1.0
		for i in plan.furniture.size():
			var f: Dictionary = plan.furniture[i]
			if str(f.get("cat", "")) == "bed" and plan.storey_of_room(int(f["room"])) > 0:
				var a := HouseGeometry.room_area(plan, int(f["room"]))
				if a > best:
					best = a
					bed = i
		var shot := 0
		if bed >= 0:
			var f: Dictionary = plan.furniture[bed]
			var rr: Rect2 = HouseGeometry.room_floor_rect(plan, int(f["room"]))
			var bc := Rect2(f["rect"]).get_center()
			# stand at the corner of the room farthest from the bed
			var corners: Array[Vector2] = [rr.position + Vector2(0.4, 0.4), Vector2(rr.end.x - 0.4, rr.position.y + 0.4),
				Vector2(rr.position.x + 0.4, rr.end.y - 0.4), rr.end - Vector2(0.4, 0.4)]
			var eye := corners[0]
			for c in corners:
				if c.distance_to(bc) > eye.distance_to(bc):
					eye = c
			var base := float(plan.storey_of_room(int(f["room"]))) * plan.spec.height
			_cam.fov = 80.0
			_cam.position = Vector3(eye.x, base + 1.58, eye.y)
			_cam.look_at(Vector3(bc.x, base + 0.5, bc.y), Vector3.UP)
			_set_shot_lighting(atan2(bc.x - eye.x, bc.y - eye.y), 8.0)
			await _save_review_image(out.path_join("townhouse_%d_bedroom.jpg" % seed_value))
			shot = 1
		print("seed ", seed_value, " bed shot ", shot)
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
