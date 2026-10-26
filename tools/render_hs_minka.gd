extends "res://tools/render_shots.gd"
## HS-MINKA review renders (real renderer, NOT headless): per frozen request
## (8 x 10 m, seeds 1, 8102, 21325)
##   _front     roof-on three-quarter from the engawa side, high: the irimoya
##              roof, the deep eave, the engawa and the garden in front of it
##   _engawa    roof-on, closer and lower on the same side: plinth, engawa deck,
##              sliding lattice screens, the dry garden
##   _interior  eye level inside the main room, looking through its screen
##              onto the engawa and the garden
## Output: artifacts/hs_minka/renders/
func _init() -> void:
	_build_stage()
	await process_frame
	_cam.current = true
	var out := "res://artifacts/hs_minka/renders"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = "res://artifacts/hs_minka/" + a.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for seed_value in [1, 8102, 21325]:
		var spec := HouseTraitMeasure.make_spec(&"asian", 8.0, 10.0, 2.6, 1)
		var plan: HousePlan = HouseGenerator.generate(spec, seed_value, true)
		var building: Node3D = HouseAssembler.build(plan, false)
		_root3d.add_child(building)
		await process_frame
		_family = &"house"
		var raise := HouseGeometry.floor_raise(plan.spec)
		var n: Vector2 = plan.engawa["normal"]
		var tang := Vector2(n.y, -n.x)
		var deck: Rect2 = plan.engawa["rect"]
		var light := atan2(n.x, n.y)
		var centre := deck.get_center()

		# high three-quarter from the engawa side, a little toward the front
		_cam.fov = 50.0
		var eye := centre + n * 15.0 + tang * 9.0
		_cam.position = Vector3(eye.x, 8.0, eye.y)
		_cam.look_at(Vector3(-n.x * 0.5, 2.6 + raise, -n.y * 0.5), Vector3.UP)
		_set_shot_lighting(light, 8.0)
		await _save_review_image(out.path_join("minka_%d_front.jpg" % seed_value))

		# closer and lower: the engawa, its screens and the garden
		var eye2 := centre + n * 9.0 + tang * 3.5
		_cam.fov = 58.0
		_cam.position = Vector3(eye2.x, 2.3, eye2.y)
		_cam.look_at(Vector3(centre.x - n.x * 0.5, 1.2 + raise, centre.y - n.y * 0.5), Vector3.UP)
		_set_shot_lighting(light, 8.0)
		await _save_review_image(out.path_join("minka_%d_engawa.jpg" % seed_value))

		# inside the main room, looking out through its screen at the garden
		var main: int = int(plan.engawa["main_room"])
		var door_pos := Vector2.ZERO
		for d in plan.doors:
			if bool(d.get("screen", false)) and int(d["a"]) == main:
				door_pos = Vector2(d["pos"])
		var rr := HouseGeometry.room_floor_rect(plan, main).grow(-0.4)
		var cands: Array = []
		var gx := 0.0
		while gx <= 1.0:
			var gy := 0.0
			while gy <= 1.0:
				var c := rr.position + Vector2(rr.size.x * gx, rr.size.y * gy)
				if c.distance_to(door_pos) >= 2.5:
					cands.append(c)
				gy += 0.125
			gx += 0.125
		var p := _clear_spot(plan, rr.get_center(), cands, door_pos)
		_cam.fov = 78.0
		_cam.position = Vector3(p.x, raise + HouseGeometry.FLOOR_T + 1.5, p.y)
		_cam.look_at(Vector3(door_pos.x + n.x * 2.0, raise + 0.9, door_pos.y + n.y * 2.0), Vector3.UP)
		_set_shot_lighting(light, 8.0)
		await _save_review_image(out.path_join("minka_%d_interior.jpg" % seed_value))
		building.queue_free()
		await process_frame
	quit(0)


## Of the candidate eye points, the one farthest from every furniture piece and
## yard prop, with a preference for sitting back from the opening.
func _clear_spot(plan: HousePlan, fallback: Vector2, cands: Array, target: Vector2) -> Vector2:
	var wall_n: Vector2 = plan.engawa["normal"]
	var best := fallback
	var best_gap := -1.0
	for c in cands:
		var gap := 9.0
		for f in plan.furniture:
			gap = minf(gap, Rect2(f["rect"]).get_center().distance_to(c)
				- maxf(Rect2(f["rect"]).size.x, Rect2(f["rect"]).size.y) * 0.5)
		for prop in plan.yard:
			gap = minf(gap, Rect2(prop["rect"]).get_center().distance_to(c) - 0.3)
		# the line to the opening must be clear of furniture too
		var line_gap := 9.0
		for f in plan.furniture:
			var fc := Rect2(f["rect"]).get_center()
			var seg := Geometry2D.get_closest_point_to_segment(fc, c, target)
			line_gap = minf(line_gap, fc.distance_to(seg) - maxf(Rect2(f["rect"]).size.x, Rect2(f["rect"]).size.y) * 0.5)
		gap = minf(gap, 1.5) + minf(line_gap, 1.5) + minf(c.distance_to(target), 5.0) * 0.4 - absf((c - target).dot(Vector2(wall_n.y, -wall_n.x))) * 0.9
		if gap > best_gap:
			best_gap = gap
			best = c
	return best


func _save_review_image(path: String) -> Error:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered: Image = _vp.get_texture().get_image()
	return rendered.save_jpg(ProjectSettings.globalize_path(path), 0.94)
