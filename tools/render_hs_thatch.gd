extends "res://tools/render_shots.gd"
## HS-THATCH review renders (real renderer, NOT headless): per frozen request
## (8 x 10 m, seeds 1, 8102, 21325)
##   _front     roof-on three-quarter from the eyebrow's side, high: thatch, ridge roll, eyebrow, garden
##   _eyebrow   roof-on, closer and lower on the same side: the eave bolster and the eyebrow hood
##   _garden    eye level from the road: path, flower beds, the door
##   _interior  eye level inside the entrance room, looking at the door
## Output: artifacts/hs_thatch/renders/
func _init() -> void:
	_build_stage()
	await process_frame
	_cam.current = true
	var out := "res://artifacts/hs_thatch/renders"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = "res://artifacts/hs_thatch/" + a.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for seed_value in [1, 8102, 21325]:
		var spec := HouseTraitMeasure.make_spec(&"thatch_cottage", 8.0, 10.0, 2.6, 1)
		var plan: HousePlan = HouseGenerator.generate(spec, seed_value, true)
		var building: Node3D = HouseAssembler.build(plan, false)
		_root3d.add_child(building)
		await process_frame
		_family = &"house"
		var e := plan.entrance()
		var door: Dictionary = plan.doors[e]
		var n := Vector2(door["normal"]).normalized()
		var tang := Vector2(n.y, -n.x)
		var dp := Vector2(door["pos"])
		var light := atan2(n.x, n.y)
		# the eyebrow's side of the house, in world terms
		var layout := HouseGeometry.roof_layout(plan)
		var sites := HouseGeometry.eyebrow_sites(plan, layout)
		var xf: Transform3D = layout["transform"]
		var ew := Vector3.ZERO
		if not sites.is_empty():
			ew = xf * Vector3(float(sites[0]["x"]), 0.0, float(sites[0]["z"]))
		var side := signf(Vector2(ew.x, ew.z).dot(tang))
		if side == 0.0:
			side = 1.0

		_cam.fov = 50.0
		var eye := dp + n * 14.0 + tang * side * 9.0
		_cam.position = Vector3(eye.x, 7.0, eye.y)
		_cam.look_at(Vector3(0.0, 3.2, 0.0), Vector3.UP)
		_set_shot_lighting(light, 8.0)
		await _save_review_image(out.path_join("thatch_%d_front.jpg" % seed_value))

		# closer and lower on the eyebrow's side
		var eye2 := Vector2(ew.x, ew.z) + n * 6.0 + tang * side * 6.5
		_cam.fov = 55.0
		_cam.position = Vector3(eye2.x, 3.4, eye2.y)
		_cam.look_at(Vector3(ew.x, 3.6, ew.z), Vector3.UP)
		_set_shot_lighting(light, 8.0)
		await _save_review_image(out.path_join("thatch_%d_eyebrow.jpg" % seed_value))

		# the garden at eye level, from the road edge
		var out_p := dp + n * 7.0 - tang * side * 1.2
		_cam.fov = 70.0
		_cam.position = Vector3(out_p.x, 1.6, out_p.y)
		_cam.look_at(Vector3(dp.x, 1.3, dp.y), Vector3.UP)
		_set_shot_lighting(light, 8.0)
		await _save_review_image(out.path_join("thatch_%d_garden.jpg" % seed_value))

		# inside: from the clearest spot in the entrance room, looking at the door
		var rr := HouseGeometry.room_floor_rect(plan, int(door["a"])).grow(-0.45)
		var cands: Array = []
		var gx := 0.0
		while gx <= 1.0:
			var gy := 0.0
			while gy <= 1.0:
				var c := rr.position + Vector2(rr.size.x * gx, rr.size.y * gy)
				if c.distance_to(dp) >= 2.2:
					cands.append(c)
				gy += 0.125
			gx += 0.125
		var p := _clear_spot(plan, rr.get_center(), cands)
		_cam.fov = 80.0
		_cam.position = Vector3(p.x, 1.6, p.y)
		_cam.look_at(Vector3(dp.x, 1.3, dp.y), Vector3.UP)
		_set_shot_lighting(light, 8.0)
		await _save_review_image(out.path_join("thatch_%d_interior.jpg" % seed_value))
		building.queue_free()
		await process_frame
	quit(0)


## Of the candidate eye points, the one farthest from every furniture piece and
## yard prop (and inside no part of the porch, if any).
func _clear_spot(plan: HousePlan, fallback: Vector2, cands: Array) -> Vector2:
	var best := fallback
	var best_gap := -1.0
	for c in cands:
		var gap := 9.0
		for f in plan.furniture:
			gap = minf(gap, Rect2(f["rect"]).grow(0.0).get_center().distance_to(c)
				- maxf(Rect2(f["rect"]).size.x, Rect2(f["rect"]).size.y) * 0.5)
		for prop in plan.yard:
			gap = minf(gap, Rect2(prop["rect"]).get_center().distance_to(c) - 0.3)
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
