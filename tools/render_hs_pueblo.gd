extends "res://tools/render_shots.gd"
## HS-PUEBLO review renders (real renderer, NOT headless): per frozen request
## (8 x 10 m, three storeys, seeds 1, 8102, 21325)
##   _front     roof-on three-quarter of the entrance side: the three set-back
##              storeys, the parapets, the vigas, the ladders
##   _side      roof-on three-quarter of the drawn-in side and the back
##   _ladder    eye level on the ground, four metres out: the ladder up the front
##              wall, the vigas, the small door and windows
##   _terrace   eye level on the first terrace: the next storey's door, the ladder
##              to the terrace above, the parapet
##   _roof      eye level on the top roof, at the head of the last ladder
##   _interior  eye level inside the first upper room, looking at its door onto the
##              terrace
## The house is built UNFURNISHED (generate(..., false)): the furnisher has no
## pueblo prop vocabulary yet (task CULTURE-FURNISH-VOCAB), and a trestle table,
## torches and goblets would contradict the culture shown. The rooms are shown bare.
## Output: artifacts/hs_pueblo/renders/
func _init() -> void:
	_build_stage()
	await process_frame
	_cam.current = true
	var out := "res://artifacts/hs_pueblo/renders"
	var only := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = "res://artifacts/hs_pueblo/" + a.substr(6)
		elif a.begins_with("--seed="):
			only = int(a.substr(7))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for seed_value in [1, 8102, 21325]:
		if only >= 0 and seed_value != only:
			continue
		var spec := HouseTraitMeasure.make_spec(&"pueblo", 8.0, 10.0, 2.6, 3)
		var plan: HousePlan = HouseGenerator.generate(spec, seed_value, false)
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
		var h := plan.spec.height

		_cam.fov = 48.0
		var eye := dp + n * 19.0 + tang * 11.0
		_cam.position = Vector3(eye.x, 8.5, eye.y)
		_cam.look_at(Vector3(0.0, 3.4, 0.5), Vector3.UP)
		_set_shot_lighting(light, 8.0)
		await _save_review_image(out.path_join("pueblo_%d_front.jpg" % seed_value))

		var eye_s := dp + n * 7.0 - tang * 17.0
		_cam.position = Vector3(eye_s.x, 8.5, eye_s.y)
		_cam.look_at(Vector3(0.0, 3.4, 1.5), Vector3.UP)
		_set_shot_lighting(atan2(-tang.x, -tang.y), 8.0)
		await _save_review_image(out.path_join("pueblo_%d_side.jpg" % seed_value))

		# the ground floor's ladder, from the ground, a little to one side
		var l1: Dictionary = plan.ladders[0]
		var lp := Vector2(float(l1["x"]), float(l1["wall_y"]))
		var out_p := lp + n * 5.2 + tang * 1.0
		_cam.fov = 62.0
		_cam.position = Vector3(out_p.x, 1.6, out_p.y)
		_cam.look_at(Vector3(lp.x, 2.6, lp.y), Vector3.UP)
		_set_shot_lighting(light, 8.0)
		await _save_review_image(out.path_join("pueblo_%d_ladder.jpg" % seed_value))

		# on the first terrace, from its far end, looking along the next storey's
		# front wall: its door, its window and the ladder to the terrace above
		var l2: Dictionary = plan.ladders[1]
		var t1: Rect2 = plan.terraces[0]["rect"]
		var deck := float(h) + HouseGeometry.FLOOR_T
		var wall2 := float(l2["wall_y"])
		var lx2 := float(l2["x"])
		var from_right := lx2 < t1.get_center().x
		var stand := Vector2(t1.end.x - 0.4 if from_right else t1.position.x + 0.4, t1.position.y + 0.6)
		var aim_x := lerpf(stand.x, lx2, 0.55)
		_cam.fov = 80.0
		_cam.position = Vector3(stand.x, deck + 1.6, stand.y)
		_cam.look_at(Vector3(aim_x, deck + 1.7, wall2), Vector3.UP)
		_set_shot_lighting(light, 8.0)
		await _save_review_image(out.path_join("pueblo_%d_terrace.jpg" % seed_value))

		# on the top roof, from the back, looking at the head of the last ladder
		var top_t: Dictionary = {}
		for t in plan.terraces:
			if bool(t["roof"]):
				top_t = t
		var roof: Rect2 = top_t["rect"]
		var lt: Dictionary = plan.ladders[plan.ladders.size() - 1]
		var roof_y := deck + h * float(plan.spec.storeys - 1)
		_cam.fov = 75.0
		_cam.position = Vector3(float(lt["x"]) - 0.6, roof_y + 1.6, roof.end.y - 0.4)
		_cam.look_at(Vector3(float(lt["x"]), roof_y + 0.7, roof.position.y), Vector3.UP)
		_set_shot_lighting(light, 8.0)
		await _save_review_image(out.path_join("pueblo_%d_roof.jpg" % seed_value))

		# inside the first upper room, looking at its door onto the terrace
		for i in range(plan.doors.size()):
			var d: Dictionary = plan.doors[i]
			if not bool(d.get("terrace", false)):
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
					if c.distance_to(dpos) >= 3.4:
						cands.append(c)
					gy += 0.125
				gx += 0.125
			var p := _clear_spot(plan, rr.get_center(), cands)
			_cam.fov = 80.0
			var fy := float(HousePlan.record_storey(d)) * h + HouseGeometry.FLOOR_T
			_cam.position = Vector3(p.x, fy + 1.6, p.y)
			var aim := dpos + dn * 0.5
			_cam.look_at(Vector3(aim.x, fy + 1.1, aim.y), Vector3.UP)
			_set_shot_lighting(atan2(dn.x, dn.y), 8.0)
			await _save_review_image(out.path_join("pueblo_%d_interior.jpg" % seed_value))
			break
		building.queue_free()
		await process_frame
	quit(0)


## Of the candidate eye points, the one farthest from every furniture piece.
func _clear_spot(plan: HousePlan, fallback: Vector2, cands: Array) -> Vector2:
	var best := fallback
	var best_gap := -1.0
	for c in cands:
		var gap := 9.0
		for f in plan.furniture:
			gap = minf(gap, Rect2(f["rect"]).get_center().distance_to(c)
				- maxf(Rect2(f["rect"]).size.x, Rect2(f["rect"]).size.y) * 0.5)
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
