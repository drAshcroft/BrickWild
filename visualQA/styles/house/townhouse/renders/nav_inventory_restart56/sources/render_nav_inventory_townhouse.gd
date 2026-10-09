extends "res://tools/render_house_style_gallery.gd"
## Focused visual inventory of the exact two-storey innkeeper townhouse from
## HouseMultistorySuite. This is evidence capture, not a pass/fail repair.

const NAV_RENDERER_PATH := "res://tools/render_nav_inventory_townhouse.gd"
const SUITE_PATH := "res://tests/suites/house_multistory_suite.gd"
const NAV_OUTPUT_ROOT := "res://visualQA/styles/house/townhouse/renders/nav_inventory_restart56"
const CASE_ID := "townhouse_innkeeper_32102_13x16_h2_9_storeys2"
const ROOM_INDICES: Array[int] = [4, 5, 8, 9, 10, 11, 12, 13, 1]


func _init() -> void:
	_build_stage()
	await process_frame
	var absolute_root := ProjectSettings.globalize_path(NAV_OUTPUT_ROOT)
	if DirAccess.dir_exists_absolute(absolute_root) or FileAccess.file_exists(absolute_root):
		printerr("Refusing to overwrite existing nav inventory render: ", NAV_OUTPUT_ROOT)
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(absolute_root) != OK:
		printerr("Could not create nav inventory render directory: ", NAV_OUTPUT_ROOT)
		quit(1)
		return
	var request_dir := NAV_OUTPUT_ROOT.path_join(CASE_ID)
	var rooms_dir := request_dir.path_join("rooms")
	var views_dir := request_dir.path_join("views")
	for output_path in [request_dir, rooms_dir, views_dir]:
		if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path)) != OK:
			_errors.append("could not create output directory: " + output_path)
	var source_start := _inventory_source_snapshot()
	var spec := HouseSpec.new()
	spec.style = &"townhouse"
	spec.trade = &"innkeeper"
	spec.width = 13.0
	spec.length = 16.0
	spec.height = 2.9
	spec.storeys = 2
	var plan: HousePlan = HouseGenerator.generate(spec, 32102)
	var request := BuildingRequest.house(32102, &"townhouse", &"innkeeper",
		13.0, 16.0, 2.9, 2)
	var builder := HouseBuilder.new()
	var emitted_mesh: ArrayMesh = builder.build(plan)
	var qa_report: Dictionary = HouseQA.new().check(plan, builder)
	var nav_checker := HouseNavCheck.new()
	var nav_report: Dictionary = nav_checker.check(plan)
	var nav_grids: Dictionary = nav_checker._grids
	var assembly := HouseAssembler.build(plan, true)
	if assembly == null:
		printerr("HouseAssembler.build could not assemble the fixed townhouse")
		quit(1)
		return
	_root3d.add_child(assembly)
	await process_frame
	var assembly_bounds: AABB = SceneBounds.of_node(assembly)
	var prop_inventory: Dictionary = _prop_inventory(plan, assembly)
	var request_file := FileAccess.open(request_dir.path_join("request.json"), FileAccess.WRITE)
	if request_file == null:
		_errors.append("could not write exact HouseMultistorySuite request record")
	else:
		request_file.store_string(request.to_json())
		request_file.close()
	var case_row: Dictionary = {
		"id": CASE_ID,
		"case": CASE_ID,
		"style": "townhouse",
		"trade": "innkeeper",
		"source_fixture": "HouseMultistorySuite.CASES townhouse row, reproduced field-for-field",
		"seed": 32102,
		"request": request.to_dict(),
		"plan": _plan_summary(plan),
		"shell_mesh_surface_count": emitted_mesh.get_surface_count(),
		"house_qa_receipt": qa_report,
		"navigation_receipt": nav_report,
		"assembly": {"mode": "HouseAssembler.build(plan, true) roof-off cutaway",
			"scene_bounds": _aabb_data(assembly_bounds),
			"prop_inventory": prop_inventory},
		"renders": [],
		"room_requests": [],
	}
	case_row["renders"].append(await _render_overview(plan, request, assembly,
		views_dir, assembly_bounds, false))
	case_row["renders"].append(await _render_overview(plan, request, assembly,
		views_dir, assembly_bounds, true))
	for room in ROOM_INDICES:
		if room < 0 or room >= plan.room_count():
			var missing := {"room_index": room, "state": "requested_room_missing"}
			case_row["room_requests"].append(missing)
			case_row["renders"].append(_view_error(CASE_ID, request.to_dict(),
				"room_inventory_%d" % room, "requested plan room does not exist"))
			continue
		var room_kind := String(plan.kind_of(room))
		var pieces: Array[Dictionary] = []
		for furniture_index in plan.furniture_of(room):
			if furniture_index < 0 or furniture_index >= plan.furniture.size():
				_errors.append("room %d refers to missing furniture index %d" % [room, furniture_index])
				continue
			pieces.append(plan.furniture[furniture_index])
		var keys: Array[String] = []
		for piece in pieces:
			keys.append(String(piece.get("key", "")))
		var room_request := {"room_index": room, "room_kind": room_kind,
			"storey": plan.storey_of_room(room), "furniture_keys": keys,
			"cabinet_present": "Cabinet" in keys,
			"sconce_present": "Sconce" in keys}
		case_row["room_requests"].append(room_request)
		var room_view := {"room_index": room, "room_kind": room_kind,
			"activity_groups": ["inventory"],
			"represented_candidate_rooms": {"inventory": [room]}}
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		case_row["renders"].append(await _render_room_view(plan, request,
			CASE_ID, room_view, rooms_dir, nav_grids))
	var source_end := _inventory_source_snapshot()
	var changed: bool = source_start.get("aggregate_sha256", "") != source_end.get("aggregate_sha256", "")
	if changed:
		_errors.append("fingerprinted source files changed while the renderer ran")
	var saved := 0
	var image_rows: Array[Dictionary] = []
	for render_variant in case_row["renders"]:
		var render_row: Dictionary = render_variant
		image_rows.append(render_row)
		if not render_row.has("error") and int(render_row.get("save_error", 1)) == 0:
			saved += 1
	case_row["render_state"] = "all_requested_images_saved" if saved == case_row["renders"].size() else "render_incomplete"
	var manifest := {
		"purpose": "visual inventory for the exact multi-storey Innkeeper HouseMultistorySuite case",
		"gallery_state": "rendered_with_diagnostics" if saved == case_row["renders"].size() and not changed else "render_incomplete_or_sources_changed",
		"visual_review_state": "not_assessed",
		"validation_state": "recorded_without_filtering",
		"style": "townhouse",
		"seed": 32102,
		"case": CASE_ID,
		"output_root": NAV_OUTPUT_ROOT,
		"expected_views": 11,
		"expected_request_count": 1,
		"saved_views": saved,
		"requests": [{"id": CASE_ID, "request": request.to_dict(), "request_path": request_dir.path_join("request.json")}],
		"cases": [case_row],
		"renders": image_rows,
		"source_start": source_start,
		"source_end": source_end,
		"source_changed": changed,
		"prior_plan_gate_receipt_artifact": "../restart55_nav_cached_HEAD_plan_fast/result.json",
		"prior_plan_gate_receipt_sha256": "19D5E4CD9E3E3BDA906CD1AE27D9EDECFF15F2B4E66A8EE342BF3A39E505E82C",
		"prior_plan_gate_stdout_sha256": "2B5A3AC89AFCE0A7B2776A1D580EBA2419DC35476AA4AEF6531B2232395401DB",
		"renderer_errors": _errors,
	}
	var manifest_saved := _write_inventory_json(NAV_OUTPUT_ROOT.path_join("manifest.json"), manifest)
	print("NAV_INVENTORY_RENDER saved=", saved, " requested=11 source_changed=", changed,
		" failed=", _failed or not _errors.is_empty() or not manifest_saved,
		" output=", NAV_OUTPUT_ROOT)
	quit(1 if saved != case_row["renders"].size() or changed or _failed \
		or not _errors.is_empty() or not manifest_saved else 0)


func _render_overview(plan: HousePlan, request: BuildingRequest, assembly: Node3D,
		views_dir: String, bounds: AABB, high_angle: bool) -> Dictionary:
	var view := "roof_off_all_levels_high_angle" if high_angle else "roof_off_all_levels_overhead"
	_cam.projection = Camera3D.PROJECTION_PERSPECTIVE if high_angle else Camera3D.PROJECTION_ORTHOGONAL
	var centre := bounds.get_center()
	var target := Vector3(centre.x, bounds.position.y + bounds.size.y * 0.42, centre.z)
	var eye: Vector3
	var camera_note := ""
	if high_angle:
		_cam.fov = 48.0
		var direction := Vector3(0.92, 1.55, -1.0).normalized()
		var radius := maxf(bounds.size.length() * 0.5, 1.0)
		var distance := radius / sin(deg_to_rad(_cam.fov * 0.5)) * 1.08
		eye = target + direction * distance
		var yaw := atan2(direction.x, direction.z)
		_set_camera(eye, target, yaw, distance + radius)
		camera_note = "roof-off stacked-storey high-angle view; both levels remain in the assembled scene"
	else:
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.size = maxf(bounds.size.x, bounds.size.z) * 1.16
		eye = Vector3(centre.x, bounds.end.y + maxf(bounds.size.x, bounds.size.z) * 0.44, centre.z)
		_cam.position = eye
		_cam.look_at(Vector3(centre.x, bounds.position.y, centre.z), Vector3.FORWARD)
		_set_shot_lighting(PI, eye.distance_to(target) + bounds.size.length())
		camera_note = "true roof-off vertical projection of the assembled house; upper floor footprint occludes lower-floor plan geometry"
	var path := views_dir.path_join(view + ".jpg")
	var save_error: Error = await _save_image(path)
	return _view_row(CASE_ID, request, view, path, save_error, {
		"priority": "primary", "roof_on": false, "cutaway": true,
		"room_count": plan.room_count(), "storeys": plan.spec.storeys,
		"camera": _camera_data(_cam.position, target, camera_note),
		"light": _light_metadata(PI), "scene_bounds": _aabb_data(bounds),
		"assembled_node": assembly.name})


func _inventory_source_snapshot() -> Dictionary:
	var base: Dictionary = _gallery_source_snapshot()
	var files: Dictionary = Dictionary(base.get("files", {})).duplicate(true)
	for path in [SUITE_PATH, NAV_RENDERER_PATH]:
		if not FileAccess.file_exists(path):
			_errors.append("required source fingerprint is missing: " + path)
			continue
		files[path] = FileAccess.get_sha256(path)
	var paths: Array[String] = []
	for path_variant in files.keys():
		paths.append(String(path_variant))
	paths.sort()
	var entries := PackedStringArray()
	for path in paths:
		entries.append(path + ":" + String(files[path]))
	return {"file_count": files.size(), "aggregate_sha256": "\n".join(entries).sha256_text(),
		"files": files}


func _write_inventory_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_errors.append("could not write renderer manifest: " + path)
		return false
	file.store_string(JSON.stringify(value, "\t", true, true) + "\n")
	file.close()
	return true
