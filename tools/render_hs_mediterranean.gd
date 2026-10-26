extends "res://tools/render_shots.gd"
## HS-MEDITERRANEAN review renders (real renderer, NOT headless): per frozen
## request (8 x 10 m, seeds 1, 8102, 21325)
##   _front     roof-on three-quarter of the entrance side: render, low tile roof, loggia
##   _rear      roof-on three-quarter of the back: the walled court and its gateway
##   _loggia    eye level on the loggia deck, looking along it at the door
##   _court     eye level inside the court, looking back at the house
##   _interior  eye level inside, looking through the rear door onto the court
## Output: artifacts/hs_mediterranean/renders/
func _init() -> void:
	_build_stage()
	await process_frame
	_cam.current = true
	var out := "res://artifacts/hs_mediterranean/renders"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = "res://artifacts/hs_mediterranean/" + a.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for seed_value in [1, 8102, 21325]:
		var spec := HouseTraitMeasure.make_spec(&"mediterranean", 8.0, 10.0, 2.6, 1)
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

		_cam.fov = 50.0
		var eye := dp + n * 15.0 + tang * 9.0
		_cam.position = Vector3(eye.x, 6.0, eye.y)
		_cam.look_at(Vector3(0.0, 1.8, 0.0), Vector3.UP)
		_set_shot_lighting(light, 8.0)
		await _save_review_image(out.path_join("mediterranean_%d_front.jpg" % seed_value))

		var rear := -n
		var eye_r := rear * 15.0 - tang * 9.0
		_cam.position = Vector3(eye_r.x, 6.0, eye_r.y)
		_cam.look_at(Vector3(0.0, 1.4, 0.0) + Vector3(rear.x, 0, rear.y) * 2.0, Vector3.UP)
		_set_shot_lighting(atan2(rear.x, rear.y), 8.0)
		await _save_review_image(out.path_join("mediterranean_%d_rear.jpg" % seed_value))

		# The loggia seen from the ground at eye level, three metres out, a little
		# to one side: its posts, beam, roof and the door it shades.
		var out_p := dp + n * (spec.veranda_depth + 2.6) + tang * 0.9
		_cam.fov = 70.0
		_cam.position = Vector3(out_p.x, 1.6, out_p.y)
		_cam.look_at(Vector3(dp.x, 1.5, dp.y), Vector3.UP)
		_set_shot_lighting(light, 8.0)
		await _save_review_image(out.path_join("mediterranean_%d_loggia.jpg" % seed_value))

		# In the court, near the rear wall, looking back at the house.
		var site := HouseGeometry.site_rect(plan.spec)
		var half_depth: float = (absf(n.x) * site.size.x + absf(n.y) * site.size.y) * 0.5
		var cc := rear * (half_depth + 2.4) + tang * 2.6
		_cam.fov = 92.0
		_cam.position = Vector3(cc.x, 1.6, cc.y)
		var back := rear * (half_depth - 0.2) - tang * 0.8
		_cam.look_at(Vector3(back.x, 1.2, back.y), Vector3.UP)
		_set_shot_lighting(atan2(n.x, n.y), 8.0)
		await _save_review_image(out.path_join("mediterranean_%d_court.jpg" % seed_value))

		# Inside, looking out through the rear door at the court.
		for i in range(plan.doors.size()):
			var d: Dictionary = plan.doors[i]
			if i == e or not d.get("exterior", false) or Vector2(d["normal"]).dot(n) > -0.5:
				continue
			var dn := Vector2(d["normal"]).normalized()
			var dpos := Vector2(d["pos"])
			var rr := HouseGeometry.room_floor_rect(plan, int(d["a"])).grow(-0.45)
			var cands: Array = []
			var gx := 0.0
			while gx <= 1.0:
				var gy := 0.0
				while gy <= 1.0:
					var c := rr.position + Vector2(rr.size.x * gx, rr.size.y * gy)
					if c.distance_to(dpos) >= 1.8:
						cands.append(c)
					gy += 0.125
				gx += 0.125
			var p := _clear_spot(plan, rr.get_center(), cands)
			_cam.fov = 80.0
			_cam.position = Vector3(p.x, 1.6, p.y)
			var aim := dpos + dn * 2.0
			_cam.look_at(Vector3(aim.x, 1.2, aim.y), Vector3.UP)
			_set_shot_lighting(atan2(dn.x, dn.y), 8.0)
			await _save_review_image(out.path_join("mediterranean_%d_interior.jpg" % seed_value))
			break
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
