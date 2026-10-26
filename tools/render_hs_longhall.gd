extends "res://tools/render_shots.gd"
## HS-LONGHALL review renders (real renderer, NOT headless): per frozen request
##   _exterior  roof-on three-quarter (length, the roof and the louvre in one frame)
##   _louvre    the smoke louvre on the ridge, from a little above
##   _interior  eye level, from one end of the hall down its length (benches,
##              trusses and the fire)
##   _roof      looking up from beside the fire into the open roof
##   _plan      roof off, from above: ends, hall, fire, benches
## Output: artifacts/goal/HS-LONGHALL/renders/ (or renders<N>/ via --out=)
func _init() -> void:
	_build_stage()
	await process_frame
	_cam.current = true
	var out := "res://artifacts/goal/HS-LONGHALL/renders"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = "res://artifacts/goal/HS-LONGHALL/" + a.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for seed_value in [1, 8102, 21325]:
		var spec := HouseTraitMeasure.make_spec(&"longhall", 8.0, 10.0, 2.6, 1)
		var plan: HousePlan = HouseGenerator.generate(spec, seed_value, true)
		var building: Node3D = HouseAssembler.build(plan, false)
		_root3d.add_child(building)
		await process_frame
		_family = &"house"
		var door: Dictionary = plan.doors[plan.entrance()]
		var n := Vector2(door["normal"]).normalized()
		var tang := Vector2(n.y, -n.x)
		var dp := Vector2(door["pos"])
		_cam.fov = 52.0
		var eye := dp + n * 17.0 + tang * 12.0
		_cam.position = Vector3(eye.x, 6.5, eye.y)
		_cam.look_at(Vector3(0.0, 2.6, 0.0), Vector3.UP)
		_set_shot_lighting(atan2(n.x, n.y), 8.0)
		await _save_review_image(out.path_join("longhall_%d_exterior.jpg" % seed_value))

		var hall: Rect2 = plan.rooms[int(plan.longhall["room"])]["rect"]
		var hc: Vector2 = plan.longhall["smoke"]
		var rise := HouseGeometry.roof_rise(plan.spec)
		var top_y: float = plan.spec.height + rise
		var le := hc + n * 7.5 + tang * 4.5
		_cam.fov = 48.0
		_cam.position = Vector3(le.x, top_y + 2.4, le.y)
		_cam.look_at(Vector3(hc.x, top_y + 0.3, hc.y), Vector3.UP)
		_set_shot_lighting(atan2(n.x, n.y), 8.0)
		await _save_review_image(out.path_join("longhall_%d_louvre.jpg" % seed_value))

		# Interior from the end of the hall with the clearest line of sight to the fire.
		var spot := _clear_spot(plan, hall, hc)
		var from_p: Vector2 = spot["from"]
		var aim := Vector2(hc.x + (hc.x - from_p.x) * 0.9, hall.get_center().y)
		_cam.fov = 78.0
		_cam.position = Vector3(from_p.x, 1.6, from_p.y)
		_cam.look_at(Vector3(aim.x, 2.3, aim.y), Vector3.UP)
		_set_shot_lighting(atan2(n.x, n.y), 8.0)
		await _save_review_image(out.path_join("longhall_%d_interior.jpg" % seed_value))

		var ue := Vector2(hc.x - 2.8, hall.get_center().y + 1.6)
		_cam.fov = 84.0
		_cam.position = Vector3(ue.x, 1.6, ue.y)
		_cam.look_at(Vector3(hc.x + 2.5, 5.0, hc.y - 0.6), Vector3.UP)
		_set_shot_lighting(atan2(n.x, n.y), 8.0)
		await _save_review_image(out.path_join("longhall_%d_roof.jpg" % seed_value))
		building.queue_free()
		await process_frame

		var cut: Node3D = HouseAssembler.build(plan, true)
		_root3d.add_child(cut)
		await process_frame
		_cam.fov = 40.0
		_cam.position = Vector3(0.0, 24.0, 7.0)
		_cam.look_at(Vector3(0.0, 0.0, 0.2), Vector3.UP)
		_set_shot_lighting(atan2(n.x, n.y), 8.0)
		await _save_review_image(out.path_join("longhall_%d_plan.jpg" % seed_value))
		cut.queue_free()
		await process_frame
	quit(0)


## The standing point near an end of the hall, off the furniture, from which the
## walk to the fire crosses the fewest pieces.
func _clear_spot(plan: HousePlan, hall: Rect2, fire: Vector2) -> Dictionary:
	var best := {"from": Vector2(hall.position.x + 0.6, hall.get_center().y), "score": 1000.0}
	for end_x in [hall.position.x + 0.55, hall.end.x - 0.55]:
		for dy in [-0.9, -0.45, 0.0, 0.45, 0.9]:
			var from_p := Vector2(end_x, hall.get_center().y + dy)
			var score := 0.0
			for f in plan.furniture:
				var r: Rect2 = f["rect"]
				if r.grow(0.5).has_point(from_p):
					score += 50.0
				for k in range(13):
					if r.grow(0.25).has_point(from_p.lerp(fire, float(k) / 12.0)):
						score += 1.0
			score += absf(dy) * 0.3
			if score < float(best["score"]):
				best = {"from": from_p, "score": score}
	return best


func _save_review_image(path: String) -> Error:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered: Image = _vp.get_texture().get_image()
	return rendered.save_jpg(ProjectSettings.globalize_path(path), 0.94)
