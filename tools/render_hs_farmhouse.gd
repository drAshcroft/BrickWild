extends "res://tools/render_shots.gd"
## HS-FARMHOUSE review renders (real renderer, NOT headless): per frozen request,
## a front three-quarter, a REAR three-quarter (back door, byre, yard) and an
## interior eye-level view of the kitchen toward its yard door.
## Output: artifacts/goal/HS-FARMHOUSE/renders/
func _init() -> void:
	_build_stage()
	await process_frame
	_cam.current = true
	var out := "res://artifacts/goal/HS-FARMHOUSE/renders2"
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
		# Rear three-quarter framing the yard door and the props beside it.
		for i in plan.doors.size():
			var bd: Dictionary = plan.doors[i]
			if i == plan.entrance() or not bd["exterior"]:
				continue
			var bn := Vector2(bd["normal"]).normalized()
			var bp := Vector2(bd["pos"])
			var bt := Vector2(bn.y, -bn.x)
			var pts: Array[Vector2] = [bp]
			for pc in plan.yard_pieces:
				if str(pc["kind"]) in ["byre", "cart", "trough"]:
					pts.append((pc["rect"] as Rect2).get_center())
			var cen := Vector2.ZERO
			for q in pts:
				cen += q / float(pts.size())
			var spread := 0.0
			for q in pts:
				spread = maxf(spread, q.distance_to(cen))
			var house_c := Vector2(0.0, 0.0)
			var outward := (cen - house_c).normalized()
			var dir := (outward + bn * 0.9).normalized()
			var cam2 := cen + dir * (3.5 + spread * 1.5)
			_cam.fov = 58.0
			_cam.position = Vector3(cam2.x, 2.8, cam2.y)
			_cam.look_at(Vector3(cen.x, 0.8, cen.y), Vector3.UP)
			var toward := dir
			_set_shot_lighting(atan2(toward.x, toward.y), 8.0)
			await _save_review_image(out.path_join("farmhouse_%d_rear.jpg" % seed_value))
			# Interior: stand in the kitchen on the side away from the hearth.
			var room: Rect2 = plan.rooms[int(bd["a"])]["rect"]
			var depth := absf(bn.x) * room.size.x + absf(bn.y) * room.size.y
			var width := absf(bt.x) * room.size.x + absf(bt.y) * room.size.y
			var hearth_dir := 0.0
			if plan.hearth_room() == int(bd["a"]):
				var hv: Vector2 = [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)][plan.hearth_wall()]
				hearth_dir = hv.dot(bt)
			var lat := -signf(hearth_dir) if absf(hearth_dir) > 0.5 else 1.0
			var e := bp - bn * (depth - 0.4) + bt * lat * (width * 0.3)
			_cam.fov = 72.0
			_cam.position = Vector3(e.x, 1.58, e.y)
			_cam.look_at(Vector3(bp.x, 1.2, bp.y), Vector3.UP)
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
