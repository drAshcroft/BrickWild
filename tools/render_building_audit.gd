extends "res://tools/render_shots.gd"
## One-family, current-source visual audit capture.
## Run without --headless: godot --path . --script res://tools/render_building_audit.gd -- --family:house
## Each invocation renders one deterministic fixture family and writes the
## request, camera and structured API QA beside the images.

const AUDIT_ROOT := "res://artifacts/renders/building_audit"
const AUDIT_SIZE := Vector2i(1280, 900)

var _audit_family := ""
var _audit_rows: Array[Dictionary] = []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--family:"):
			_audit_family = arg.trim_prefix("--family:").strip_edges().to_lower()
	if _audit_family not in ["house", "shop", "hotel", "church", "temple", "world", "village"]:
		printerr("Usage: godot --path . --script res://tools/render_building_audit.gd -- --family:house|shop|hotel|church|temple|world|village")
		quit(2)
		return
	var out_dir := AUDIT_ROOT + "/" + _audit_family
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_build_stage()
	_vp.size = AUDIT_SIZE
	await process_frame
	_set_atmosphere(&"house")
	match _audit_family:
		"house":
			await _run_house()
		"shop":
			await _run_request(BuildingRequest.shop(353, &"blacksmith", &"longhall", 11.0, 14.0, 2.8, 1), "blacksmith_longhall")
		"hotel":
			await _run_request(BuildingRequest.hotel(373, &"grand_budapest", 30.0, 16.0, 3.0), "grand_budapest_compact")
		"church":
			await _run_request(BuildingRequest.church(5005, &"romanesque", 11.9, 60.0, 22.2), "durham_romanesque")
		"temple":
			await _run_temple()
		"world":
			var request := BrickWild.default_request(&"world", 12003)
			request.style = &"courtyard_house"
			request.purpose = &"palazzo"
			request.width = 20.0
			request.length = 30.0
			request.height = 18.0
			await _run_request(request, "palazzo_courtyard")
		"village":
			var request := BrickWild.default_request(&"village", 44001)
			request.width = 18.0
			request.length = 60.0
			request.style = &"english"
			request.purpose = &"farming"
			request.water = &"none"
			request.enclosure = &"hedge"
			await _run_request(request, "thorpe_english_farming")
	var failures := _audit_failure_reasons()
	var exit_code := 1 if not failures.is_empty() else 0
	var image_count := _captured_image_count()
	if not _write_audit(out_dir, exit_code, image_count, failures):
		failures.append("manifest write failed")
		exit_code = 1
	print("BUILDING_AUDIT family=", _audit_family, " fixtures=", _audit_rows.size(),
		" images=", image_count, " status=", "fail" if exit_code != 0 else "pass",
		" out=", out_dir)
	if not failures.is_empty():
		for failure in failures:
			printerr("BUILDING_AUDIT failure: ", failure)
	quit(exit_code)


func _run_house() -> void:
	var fixtures: Array[Dictionary] = [
		{"key": "family_cottage", "request": BuildingRequest.house(8102, &"cottage", &"none", 8.0, 10.5, 2.6, 1)},
		{"key": "rich_merchant", "request": BuildingRequest.house(8107, &"rich", &"innkeeper", 12.0, 15.0, 3.0, 3)},
	]
	for fixture in fixtures:
		await _run_request(fixture["request"], fixture["key"], fixture["request"].style == &"rich")


func _run_temple() -> void:
	var request := BuildingRequest.temple(7302, &"pylon", &"void", 34.0, 58.0, 15.0)
	var building := BrickWild.generate(request)
	if not building.is_ok():
		_audit_rows.append(_failed_fixture("starless_pylon", request, building.errors))
		return
	var spec: TempleSpec = building.spec
	var needs: Array[String] = ["obelisks"]
	TempleArchetypeSuite._force(spec, needs)
	# Force the same documented feature as the canonical temple fixture before
	# checking and assembling, so the picture and its QA describe one spec.
	var report := BrickWild.check(building)
	var row := _fixture_row("starless_pylon", request, building, report)
	row["canonical_forced_features"] = needs
	row["qa"]["canonical_forced_temple_rite"] = _qa_status(report)
	row["captures"].append(await _capture_fixture(building, false,
		"exterior_3q", "starless_pylon_exterior.jpg"))
	row["captures"].append(await _capture_fixture(building, true,
		"axis_cutaway", "starless_pylon_axis_cutaway.jpg", true))
	_audit_rows.append(row)


func _run_request(request: BuildingRequest, key: String, rich := false) -> void:
	var building := BrickWild.generate(request)
	if not building.is_ok():
		_audit_rows.append(_failed_fixture(key, request, building.errors))
		return
	var report := BrickWild.check(building)
	var row := _fixture_row(key, request, building, report)
	var views: Array[Dictionary] = []
	if request.kind in [&"church", &"temple"]:
		views = [
			{"cutaway": false, "view": "exterior_3q", "file": key + "_exterior_3q.jpg"},
			{"cutaway": true, "view": "axis_cutaway", "file": key + "_axis_cutaway.jpg", "axis": true},
		]
	else:
		views = [
			{"cutaway": false, "view": "exterior_3q", "file": key + "_exterior_3q.jpg"},
			{"cutaway": true, "view": "elevated_cutaway", "file": key + "_elevated_cutaway.jpg"},
			{"cutaway": false, "view": "front_entry", "file": key + "_front_entry.jpg", "entry": true},
		]
	for view in views:
		var capture := await _capture_fixture(building, bool(view["cutaway"]), String(view["view"]), String(view["file"]), bool(view.get("axis", false)), bool(view.get("entry", false)))
		row["captures"].append(capture)
	if rich and building.plan != null:
		var builder := HouseBuilder.new()
		builder.build(building.plan)
		row["qa"]["rich_house"] = _qa_status(RichHouseCheck.new().check(building.plan, builder))
	_audit_rows.append(row)


func _capture_fixture(building: GeneratedBuilding, cutaway: bool, view: String,
		filename: String, axis := false, entry := false) -> Dictionary:
	var row := {"file": filename, "view": view, "cutaway": cutaway,
		"status": "pending", "camera": {}}
	var node := BrickWild.instantiate(building, cutaway)
	if node == null:
		row["status"] = "instantiate_failed"
		return row
	_root3d.add_child(node)
	await process_frame
	var bounds: AABB = SceneBounds.of_node(node)
	if bounds.size.length() <= 0.01:
		node.queue_free()
		row["status"] = "empty_bounds"
		return row
	var centre := bounds.get_center()
	var radius := maxf(bounds.size.length() * 0.5, 1.0)
	var door: Vector3 = BrickWild.placement(building).get("door", centre)
	var yaw := 2.28
	var pitch := -0.28
	if view == "elevated_cutaway":
		pitch = -0.76
	var focus := centre
	var direction := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	var distance := radius / tan(deg_to_rad(_cam.fov) * 0.5) * 1.22
	if axis:
		_set_atmosphere(&"temple_dark" if building.request.kind == &"temple" else &"church")
		if building.request.kind == &"temple" and building.spec is TempleSpec:
			var temple: TempleSpec = building.spec
			var idol: Vector3 = TempleGeometry.idol_center(temple)
			var sight: Vector2 = TempleGeometry.sight_point(temple)
			_cam.position = Vector3(sight.x, 1.7, sight.y)
			focus = Vector3(0.0, idol.y + temple.idol_height * 0.45, idol.z)
		else:
			_set_atmosphere(&"church")
			_cam.position = Vector3(door.x, maxf(1.7, door.y), door.z + 0.35)
			focus = Vector3(0.0, centre.y * 0.35, bounds.position.z + bounds.size.z * 0.78)
	elif entry:
		_set_atmosphere(&"house")
		var approach := clampf(bounds.size.z * 0.22, 4.0, 7.5)
		yaw = PI
		pitch = 0.0
		_cam.position = Vector3(door.x, 1.65, door.z - approach)
		focus = door
		_cam.look_at(focus, Vector3.UP)
	else:
		_set_atmosphere(&"house" if building.request.kind in [&"house", &"shop", &"hotel", &"village"] else &"castle")
		_cam.position = centre + direction * distance
		_cam.look_at(centre, Vector3.UP)
	if axis:
		_cam.look_at(focus, Vector3.UP)
		var fwd := -_cam.global_transform.basis.z
		_set_shot_lighting(atan2(-fwd.x, -fwd.z), _cam.position.distance_to(focus) + radius)
	else:
		_set_shot_lighting(yaw, distance + radius)
	row["camera"] = {"position": _vec3(_cam.position), "target": _vec3(focus),
		"fov_degrees": _cam.fov, "yaw_radians": yaw, "pitch_radians": pitch,
		"framing_radius_m": radius}
	row["bounds"] = {"position": _vec3(bounds.position), "size": _vec3(bounds.size)}
	var out_path := AUDIT_ROOT + "/" + _audit_family + "/" + filename
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _vp.get_texture().get_image()
	var save_error := image.save_jpg(ProjectSettings.globalize_path(out_path), 0.94)
	if save_error != OK:
		row["status"] = "save_failed"
		row["error"] = error_string(save_error)
	else:
		row["status"] = "captured"
	node.queue_free()
	await process_frame
	return row


func _fixture_row(key: String, request: BuildingRequest, building: GeneratedBuilding,
		report: Dictionary) -> Dictionary:
	return {"fixture": key, "generated": true, "request": request.to_dict(),
		"building_name": building.name(), "qa": {"brickwild": _qa_status(report)},
		"captures": []}


func _failed_fixture(key: String, request: BuildingRequest, errors: Array) -> Dictionary:
	return {"fixture": key, "generated": false, "request": request.to_dict(),
		"qa": {"brickwild": {"status": "unavailable", "reason": "generation failed"}},
		"generation_errors": errors, "captures": []}


func _qa_status(report: Dictionary) -> Dictionary:
	var status := "unavailable"
	if report.has("ok"):
		status = "pass" if bool(report["ok"]) else "fail"
	return {"status": status, "report": report}


func _write_audit(out_dir: String, exit_code: int, image_count: int,
		failures: Array[String]) -> bool:
	var document := {"schema": "brickwild.visual_audit", "schema_version": 1,
		"family": _audit_family, "captured_at": Time.get_datetime_string_from_system(true),
		"renderer": "Godot SubViewport via tools/render_shots.gd stage",
		"headless": false, "fixture_count": _audit_rows.size(),
		"image_count": image_count, "status": "fail" if exit_code != 0 else "pass",
		"failures": failures, "fixtures": _audit_rows}
	var file := FileAccess.open(out_dir + "/audit.json", FileAccess.WRITE)
	if file == null:
		printerr("BUILDING_AUDIT failed to open manifest: ", out_dir + "/audit.json")
		return false
	file.store_string(JSON.stringify(document, "\t") + "\n")
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		printerr("BUILDING_AUDIT failed writing manifest: ", error_string(write_error))
		return false
	return true


func _captured_image_count() -> int:
	var count := 0
	for fixture in _audit_rows:
		for capture in fixture.get("captures", []):
			if capture.get("status", "") == "captured":
				count += 1
	return count


func _audit_failure_reasons() -> Array[String]:
	var failures: Array[String] = []
	for fixture in _audit_rows:
		var key := String(fixture.get("fixture", "unknown"))
		if not bool(fixture.get("generated", false)):
			failures.append(key + ": generation failed")
		var captures: Array = fixture.get("captures", [])
		if captures.is_empty():
			failures.append(key + ": no captures produced")
		for capture in captures:
			if capture.get("status", "") != "captured":
				failures.append(key + ": capture " + String(capture.get("file", "unknown"))
					+ " status=" + String(capture.get("status", "missing")))
		_append_qa_failures(fixture.get("qa", {}), key, failures)
	return failures


func _append_qa_failures(value: Variant, path: String, failures: Array[String]) -> void:
	if value is Dictionary:
		if value.get("status", "") == "fail":
			failures.append(path + ": QA failed")
		for key in value:
			_append_qa_failures(value[key], path + "/" + String(key), failures)
	elif value is Array:
		for index in range(value.size()):
			_append_qa_failures(value[index], path + "[" + str(index) + "]", failures)


func _vec3(v: Vector3) -> Array[float]:
	return [v.x, v.y, v.z]
