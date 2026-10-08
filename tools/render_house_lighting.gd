extends "res://tools/render_activity_groups.gd"
## Roof-on views of the actual large-room lighting regression.
func _init() -> void:
	_build_stage()
	await process_frame
	var output := "res://artifacts/personality/resumed/lighting_renders"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var source_start := _source_snapshot()
	var request := BuildingRequest.house(32103, &"longhall", &"smith", 11.0, 14.0, 2.7, 3)
	var building := BrickWild.generate(request)
	if not building.is_ok() or building.plan == null:
		quit(1)
		return
	var plan: HousePlan = building.plan
	var node := HouseAssembler.build(plan, false)
	_root3d.add_child(node)
	await process_frame
	var rows: Array[Dictionary] = []
	var failed := false
	for room in [0, 4]:
		var floor := HouseFurnishGeometry.storey_base(plan, room) + HouseGeometry.FLOOR_T
		var rect := HouseGeometry.room_floor_rect(plan, room)
		var members: Array[Dictionary] = []
		for index in plan.furniture_of(room):
			members.append(plan.furniture[index])
		var anchor := rect.get_center()
		var camera := _find_activity_camera(plan, room, "lighting", members, anchor, floor, rect)
		var eye: Vector3 = camera["eye"]
		var target := Vector3(anchor.x, floor + 2.0, anchor.y)
		_cam.fov = 76.0
		_cam.near = 0.05
		_cam.position = eye
		_cam.look_at(target, Vector3.UP)
		_family = &"house"
		_set_shot_lighting(0.0, 24.0)
		var path := output.path_join("longhall_32103_room_%d_roof_on.jpg" % room)
		var err := await _save_image(path)
		failed = failed or err != OK or not bool(camera.get("body_clear", false))
		rows.append({"room": room, "image": path, "request": request.to_dict(), "eye": _xyz(eye), "target": _xyz(target), "fov": _cam.fov, "roof_on": true, "body_clear": camera.get("body_clear", false), "save_error": err})
	var source_end := _source_snapshot()
	var manifest := {"request": request.to_dict(), "renders": rows, "source_start": source_start, "source_end": source_end, "source_changed": source_start != source_end, "renderer_sha256": FileAccess.get_sha256("res://tools/render_house_lighting.gd"), "failed": failed}
	var file := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(manifest, "	"))
	file.close()
	print("LIGHT_RENDER views=", rows.size(), " failed=", failed, " source_changed=", source_start != source_end)
	quit(1 if failed or source_start != source_end else 0)
