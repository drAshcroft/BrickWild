extends SceneTree
## Render the frozen household planning matrix through the existing blueprint.
## Intentionally unfurnished: these sheets judge rooms, openings and circulation.
## Run without --headless. Optional args: cases=res://... out=res://... select=id,id

func _init() -> void:
	var source_start := _source_snapshot()
	var options: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", false, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	var source := String(options.get("cases", "res://visualqa/personality/frozen_requests.json"))
	var output := String(options.get("out", "res://artifacts/personality/plans"))
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(source)) != OK or not parser.data is Dictionary:
		printerr("Invalid case manifest: ", source)
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output)) != OK:
		printerr("Cannot create plan output: ", output)
		quit(1)
		return
	var chosen := String(options.get("select", "")).split(",", false)
	var evidence: Array[Dictionary] = []
	var failed := false
	for row: Dictionary in parser.data.get("cases", []):
		var id := String(row.get("id", ""))
		var request := BuildingRequest.from_dict(row["request"])
		if request.kind != &"house" or (not chosen.is_empty() and not chosen.has(id)):
			continue
		if not request._decode_errors.is_empty() or id.contains("/") or id.contains("\\"):
			failed = true
			continue
		var building := GeneratedBuilding.new()
		BuildingFamilyAdapter.HouseFamily.new()._generate_plan(request, building, false)
		var plan: HousePlan = building.plan
		if plan == null:
			failed = true
			continue
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1200, 1500)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var blueprint := BlueprintView.new()
		blueprint.size = Vector2(viewport.size)
		viewport.add_child(blueprint)
		blueprint.setup_house(plan)
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		var path := output.path_join(id + ".jpg")
		var saved := viewport.get_texture().get_image().save_jpg(ProjectSettings.globalize_path(path), 0.94)
		if saved != OK:
			failed = true
		var report: Dictionary = HousePlanCheck.new().check(plan)
		evidence.append({"id": id, "request": request.to_dict(), "image": path,
			"furnished": false, "layout": BuildingDocument._plain(plan.domestic_layout),
			"rooms": BuildingDocument._plain(plan.rooms), "doors": BuildingDocument._plain(plan.doors),
			"plan_check": BuildingDocument._plain(report)})
		print("PLAN_SHEET ", id)
		viewport.queue_free()
		await process_frame
	var file := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	if file == null:
		failed = true
	else:
		var source_end := _source_snapshot()
		file.store_string(JSON.stringify({"purpose": "unfurnished planning review, not design acceptance",
			"source_start": source_start, "source_end": source_end,
			"source_changed": source_start != source_end,
			"cases": evidence}, "\t"))
		file.close()
	print("Plan sheets: ", evidence.size())
	quit(1 if failed or evidence.is_empty() else 0)


func _source_snapshot() -> Dictionary:
	var paths: Array[String] = []
	for root_path in ["res://src", "res://core", "res://qa", "res://tools", "res://tests"]:
		_collect_scripts(root_path, paths)
	paths.sort()
	var fingerprints := PackedStringArray()
	for path in paths:
		fingerprints.append(path + ":" + FileAccess.get_sha256(path))
	return {"script_sha256": "\n".join(fingerprints).sha256_text(), "script_count": paths.size()}


func _collect_scripts(path: String, paths: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file in directory.get_files():
		if file.ends_with(".gd"):
			paths.append(path.path_join(file))
	for child in directory.get_directories():
		_collect_scripts(path.path_join(child), paths)
