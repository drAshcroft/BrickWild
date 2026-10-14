extends "res://tools/render_witch_personality.gd"
## Separate roof-on preparation and cupboard views for three frozen kitchens.
## The full matrix's cooking portraits focus on the firebox, not these benches.

func _init() -> void:
	_build_stage()
	await process_frame
	var output := "res://artifacts/todo_completion_20261013/witch_cooking_prep_v1"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			output = arg.trim_prefix("out=")
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output)) != OK:
		quit(1)
		return
	var start := _source_snapshot()
	var renderer_start := FileAccess.get_sha256(get_script().resource_path)
	var rows: Array[Dictionary] = []
	var cases: Array[Dictionary] = []
	for seed_value in [1, 8102, 21325]:
		var request := BuildingRequest.house(seed_value, &"witch_hut", &"none", 9, 12, 2.6, 1)
		var case_id := "witch_default_%d" % seed_value
		var plan: HousePlan = BrickWild.generate(request).plan
		var room := plan.hearth_room()
		var pieces: Array[Dictionary] = []
		var bench: Dictionary = {}
		for item in plan.furniture:
			if int(item["room"]) == room and String(item.get("activity_group", "")) == "cooking" \
					and String(item.get("cat", "")) in ["workbench", "storage"]:
				pieces.append(item)
				if item["cat"] == "workbench":
					bench = item
		if pieces.size() != 2 or bench.is_empty():
			_errors.append(case_id + ": missing complete prep/cupboard pair")
			continue
		var assembled := HouseAssembler.build(plan, false)
		_root3d.add_child(assembled)
		await process_frame
		var floor_y := HouseFurnishGeometry.storey_base(plan, room) + HouseGeometry.FLOOR_T
		for piece in pieces:
			var focus: Array[Dictionary] = [piece]
			var anchor := Rect2(piece["rect"]).get_center()
			var facing := HouseFurnishScore._facing_of(float(piece["yaw"]))
			var front := anchor + facing * (PropCatalog.footprint(String(piece["key"])).y \
				* float(piece.get("scale", 1.0)) * 0.5 + 0.01)
			# Aim at the working front. A legitimate mug on the cupboard top
			# must not be mistaken for an obstruction hiding the cupboard itself.
			var height_fraction := 0.94 if String(piece["cat"]) == "workbench" else 0.55
			var sight_targets: Array[Vector3] = [Vector3(front.x,
				floor_y + PropCatalog.placement_height(piece) * height_fraction, front.y)]
			var camera := _find_eye_camera(plan, room, focus, anchor, floor_y,
				HouseGeometry.room_floor_rect(plan, room), piece, 1.65, true, 0.75, sight_targets)
			var view := "cooking_%s_eye_level" % String(piece["cat"])
			if not bool(camera["body_clear"]) or not bool(camera["reachable"]) \
					or not bool(camera["focus_in_frame"]) or not bool(camera["line_of_sight_clear"]):
				_errors.append(case_id + ": " + view + " lacks clear reachable framing")
			_cam.fov = 72.0
			var eye: Vector3 = camera["eye"]
			var target: Vector3 = camera["target"]
			_set_camera(eye, target, atan2(target.x - eye.x, target.z - eye.z), 24.0)
			var path := output.path_join(case_id + "_" + view + ".jpg")
			var saved := await _save_image(path)
			rows.append(_view_row(case_id, request, view, path, saved,
				{"roof_on": true, "cutaway": false, "room_index": room, "room_kind": "kitchen",
				"activity_group": "cooking", "members": _piece_summary(focus),
				"camera": _camera_data(eye, target, "reachable view of the fitted " + String(piece["cat"])),
				"camera_body_clear": camera["body_clear"], "camera_reachable": camera["reachable"],
				"focus_in_frame": camera["focus_in_frame"], "line_of_sight_clear": camera["line_of_sight_clear"]}))
		cases.append({"id": case_id, "request": request.to_dict()})
		assembled.queue_free()
		await process_frame
	var finish := _source_snapshot()
	var renderer_finish := FileAccess.get_sha256(get_script().resource_path)
	var changed: bool = start["aggregate_sha256"] != finish["aggregate_sha256"] or renderer_start != renderer_finish
	if changed or rows.size() != 6:
		_errors.append("source changed or incomplete default-kitchen cohort")
	var manifest := {"purpose": "fitted cooking prep and cupboard in the three frozen default Witch kitchens",
		"source_start": start, "source_end": finish, "source_changed": changed,
		"renderer": get_script().resource_path, "renderer_sha256_start": renderer_start,
		"renderer_sha256_end": renderer_finish, "expected_cases": 3, "expected_image_count": 6,
		"requests": cases, "renders": rows, "errors": _errors, "visual_review_state": "not_assessed"}
	var file := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	print("WITCH_COOKING_PREP views=", rows.size(), " errors=", _errors)
	quit(0 if _errors.is_empty() else 1)
