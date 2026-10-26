extends "res://tools/render_shots.gd"
## HS-ROUNDHOUSE review renders (real renderer, NOT headless): per frozen request
## (8 x 10 m request, seeds 1, 8102, 21325; the hut takes the 8 m circle)
##   _front     roof-on three-quarter from the door side, high: the round wall, the
##              cone of thatch and the vent hat at its apex
##   _door      roof-on, lower and closer: the thick wall at the door reveal, the
##              hanging eave
##   _interior  eye level just inside the door, looking across the central hearth
##              to the bed at the wall
##   _vent      eye level beside the fire, looking up the cone to the vent
## Only the bed is left in the room. The furnisher has no culture vocabulary yet
## (task CULTURE-FURNISH-VOCAB): its trestle table, stools, chests, torches and
## goblets are European and are NOT shown as the roundhouse's. The bed is the one
## piece the trait names, and the model is the generic Bed_Twin1. The fire's
## stones, ash, logs and flames are the roundhouse's own.
## Output: artifacts/hs_roundhouse/renders/
func _init() -> void:
	_build_stage()
	await process_frame
	_cam.current = true
	var out := "res://artifacts/hs_roundhouse/renders"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = "res://artifacts/hs_roundhouse/" + a.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for seed_value in [1, 8102, 21325]:
		var spec := HouseTraitMeasure.make_spec(&"roundhouse", 8.0, 10.0, 2.6, 1)
		var plan: HousePlan = HouseGenerator.generate(spec, seed_value, true)
		# the bed only: nothing the furnisher chose from a European vocabulary
		var kept: Array[Dictionary] = []
		for f in plan.furniture:
			if str(f.get("cat", "")) == "bed":
				kept.append(f)
		plan.furniture = kept
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
		_cam.position = Vector3(eye.x, 7.5, eye.y)
		_cam.look_at(Vector3(0.0, 2.6, 0.0), Vector3.UP)
		_set_shot_lighting(light, 8.0)
		await _save_review_image(out.path_join("roundhouse_%d_front.jpg" % seed_value))

		# closer and lower, a little to one side of the door: the wall's thickness
		# in the reveal and the eave that hangs past it
		var eye2 := dp + n * 6.5 + tang * 3.0
		_cam.fov = 60.0
		_cam.position = Vector3(eye2.x, 1.8, eye2.y)
		_cam.look_at(Vector3(dp.x, 1.7, dp.y), Vector3.UP)
		_set_shot_lighting(light, 8.0)
		await _save_review_image(out.path_join("roundhouse_%d_door.jpg" % seed_value))

		# just inside the door, looking across the fire; the bed is on the wall
		# beyond (or beside) it
		var bed_at := Vector2.ZERO
		for f in plan.furniture:
			bed_at = Rect2(f["rect"]).get_center()
		var inside := dp - n * 1.5
		_cam.fov = 85.0
		_cam.position = Vector3(inside.x, 1.55, inside.y)
		var aim := (Vector2.ZERO * 0.5 + bed_at * 0.5)
		_cam.look_at(Vector3(aim.x, 0.7, aim.y), Vector3.UP)
		_set_shot_lighting(atan2(-n.x, -n.y), 8.0)
		await _save_review_image(out.path_join("roundhouse_%d_interior.jpg" % seed_value))

		# beside the fire, looking up the cone at the vent
		var beside := Vector2(1.9, 0.0) if bed_at.x < 0.5 else Vector2(-1.9, 0.0)
		_cam.fov = 80.0
		_cam.position = Vector3(beside.x, 1.5, beside.y)
		_cam.look_at(Vector3(0.0, 6.5, 0.0), Vector3.UP)
		_set_shot_lighting(atan2(-n.x, -n.y), 8.0)
		await _save_review_image(out.path_join("roundhouse_%d_vent.jpg" % seed_value))
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
