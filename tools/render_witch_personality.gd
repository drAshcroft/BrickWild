extends "res://tools/render_shots.gd"
## Actual public-API Witch renders. Run without --headless.
## Args: out=res://... [case=<one frozen request id>] (default: all 12 cases)

const REQUESTS_PATH := "res://tests/fixtures/witch_family_requests.json"
const VIEW_REQUEST_PATH := "res://tests/fixtures/witch_render_view_request.json"
const DEFAULT_OUT := "res://artifacts/personality/witch_ready/renders"
const REQUIRED_CASES: Array[String] = [
	"witch_small_1", "witch_small_8102", "witch_small_21325",
	"witch_default_1", "witch_default_8102", "witch_default_21325",
	"witch_large_1", "witch_large_8102", "witch_large_21325",
	"control_cottage_small", "control_cottage_default", "control_cottage_large"]
const WITCH_VIEWS: Array[String] = ["roof_on_exterior", "service_yard",
	"workshop_eye_level", "cutaway_context"]
const COTTAGE_VIEWS: Array[String] = ["roof_on_exterior", "service_yard",
	"ordinary_interior_eye_level", "cutaway_context"]
const HEAT_VIEWS: Array[String] = ["cauldron_heat_eye_level", "cauldron_heat_hidden_control",
	"hall_cooking_heat_visible", "hall_cooking_heat_hidden_control"]

var _failed := false
var _errors: Array[String] = []
var _heat_supplement_enabled := false
var _shared_heat_cases: Dictionary = {}


func _init() -> void:
	_build_stage()
	await process_frame
	var output := DEFAULT_OUT
	var selected_case := ""
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("out="):
			output = String(arg).substr(4)
		elif String(arg).begins_with("case="):
			selected_case = String(arg).substr(5)
		elif String(arg) == "supplement=cauldron_heat":
			_heat_supplement_enabled = true
	var absolute_out := ProjectSettings.globalize_path(output)
	if DirAccess.make_dir_recursive_absolute(absolute_out) != OK:
		printerr("Cannot create Witch render output directory: ", output)
		quit(1)
		return
	var source_start := _source_snapshot()
	var source_cases: Array[Dictionary] = _load_cases()
	var chosen: Array[Dictionary] = []
	var seen_case_ids: Dictionary = {}
	for entry in source_cases:
		var entry_id := String(entry.get("id", ""))
		if entry_id in REQUIRED_CASES and (selected_case.is_empty() or entry_id == selected_case):
			if seen_case_ids.has(entry_id):
				_failed = true
				_errors.append("duplicate required request id: " + entry_id)
			else:
				seen_case_ids[entry_id] = true
				chosen.append(entry)
	if chosen.is_empty():
		_failed = true
		_errors.append("request source has no selected required case: " + selected_case)
	if selected_case.is_empty():
		for required_id in REQUIRED_CASES:
			var found := false
			for entry in chosen:
				if String(entry.get("id", "")) == required_id:
					found = true
			if not found:
				_failed = true
				_errors.append("required request missing: " + required_id)
	var render_rows: Array[Dictionary] = []
	var request_rows: Array[Dictionary] = []
	var case_states: Array[Dictionary] = []
	for case_entry in chosen:
		var case_id := String(case_entry["id"])
		var request_data: Dictionary = case_entry.get("request", {})
		var request_row := {"id": case_id, "role": case_entry.get("role", ""),
			"size": case_entry.get("size", ""), "request": request_data.duplicate(true)}
		request_rows.append(request_row)
		var request := BuildingRequest.from_dict(request_data)
		if not request._decode_errors.is_empty():
			case_states.append({"id": case_id, "generation_state": "not_attempted",
				"navigation_qa_state": "not_run", "render_state": "not_attempted",
				"visual_review_state": "not_assessed"})
			_failed = true
			_errors.append("invalid public request %s: %s" % [case_id, str(request._decode_errors)])
			for view in _required_views(case_id):
				render_rows.append(_view_error(case_id, request_data, view,
					"invalid request fields"))
			continue
		request_rows.back()["request"] = request.to_dict()
		var generated: GeneratedBuilding = BrickWild.generate(request)
		if not generated.is_ok() or generated.plan == null:
			case_states.append({"id": case_id, "generation_state": "failed",
				"generation_errors": generated.errors, "navigation_qa_state": "not_run",
				"mesh_assembly_state": "not_attempted", "render_state": "not_attempted", "visual_review_state": "not_assessed"})
			_failed = true
			var generation_error := "public BrickWild.generate failed: %s" % str(generated.errors)
			_errors.append(case_id + ": " + generation_error)
			for view in _required_views(case_id):
				render_rows.append(_view_error(case_id, request.to_dict(), view, generation_error))
			continue
		var plan: HousePlan = generated.plan
		_shared_heat_cases[case_id] = _has_shared_cooking_cauldron(plan)
		var nav_checker := HouseNavCheck.new()
		var nav_report: Dictionary = nav_checker.check(plan)
		var nav_state := "passed" if bool(nav_report.get("ok", false)) else "failed"
		if nav_state == "failed":
			_failed = true
			_errors.append(case_id + " HouseNavCheck: " + str(nav_report.get("failures", [])))
		case_states.append({"id": case_id, "generation_state": "passed",
			"navigation_qa_state": nav_state, "navigation_qa": nav_report,
			"mesh_assembly_state": "running", "render_state": "running", "visual_review_state": "not_assessed"})
		var first_render_row := render_rows.size()
		render_rows.append_array(await _render_case(plan, request, case_id, output))
		var image_rows := render_rows.slice(first_render_row)
		var saved_views := 0
		var assembly_failed := false
		for image_row in image_rows:
			if not image_row.has("error") and int(image_row.get("save_error", 1)) == 0:
				saved_views += 1
			if String(image_row.get("error", "")).contains("assembly failed"):
				assembly_failed = true
		case_states.back()["mesh_assembly_state"] = "failed" if assembly_failed else "passed"
		case_states.back()["render_state"] = "passed" if saved_views == _required_views(case_id).size() else "failed"
		case_states.back()["rendered_view_count"] = saved_views
	var source_end := _source_snapshot()
	var required_view_count := 0
	for entry in chosen:
		required_view_count += _required_views(String(entry["id"])).size()
	if render_rows.size() != required_view_count:
		_failed = true
		_errors.append("view count mismatch: expected %d rows, got %d" % [required_view_count, render_rows.size()])
	var view_request_data: Dictionary = _load_json(VIEW_REQUEST_PATH)
	var manifest := {"purpose": "roof-on Witch exterior, service-yard work sequence, eye-level room activity and assembled cutaway review; matched ordinary cottage control",
		"visual_acceptance": "not_assessed",
		"mechanical_composition": "reported as generated placement metadata only",
		"source_start": source_start, "source_end": source_end,
		"source_changed": source_start.get("aggregate_sha256", "") != source_end.get("aggregate_sha256", ""),
		"request_source": REQUESTS_PATH, "view_request_source": VIEW_REQUEST_PATH,
		"view_request": view_request_data,
		"selected_case": selected_case, "expected_cases": chosen.size(),
		"expected_view_rows": required_view_count, "expected_view_rows_per_case": 4, "expected_image_count": required_view_count,
		"generated_case_count": _count_state(case_states, "generation_state", "passed"),
		"generation_state": "passed" if case_states.size() == chosen.size() and _count_state(case_states, "generation_state", "passed") == chosen.size() else "failed",
		"navigation_qa_state": "passed" if _count_state(case_states, "navigation_qa_state", "failed") == 0 and _count_state(case_states, "navigation_qa_state", "passed") == chosen.size() else "failed",
		"render_state": "passed" if render_rows.size() == required_view_count and _count_state(case_states, "render_state", "passed") == chosen.size() else "failed",
		"mesh_assembly_state": "passed" if _count_state(case_states, "mesh_assembly_state", "failed") == 0 and _count_state(case_states, "mesh_assembly_state", "passed") == chosen.size() else "failed",
		"matrix": {"witch_hut": {"expected_cases": 9, "sizes": ["small", "default", "large"], "seeds": ["1", "8102", "21325"]},
			"matched_cottage_controls": {"expected_cases": 3, "sizes": ["small", "default", "large"], "seed": "8102"}},
		"matched_cottage_control_count": 3, "visual_review_state": "not_assessed", "case_states": case_states,
		"requests": request_rows, "renders": render_rows, "errors": _errors}
	var manifest_file := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	if manifest_file == null:
		_failed = true
		_errors.append("could not write manifest")
	else:
		manifest_file.store_string(JSON.stringify(manifest, "\t"))
		manifest_file.close()
	print("WITCH_RENDER cases=", request_rows.size(), " views=", render_rows.size(),
		" source_changed=", manifest["source_changed"], " failed=", _failed)
	quit(1 if _failed else 0)


func _count_state(rows: Array[Dictionary], field: String, expected: String) -> int:
	var count := 0
	for row in rows:
		if String(row.get(field, "")) == expected:
			count += 1
	return count


func _render_case(plan: HousePlan, request: BuildingRequest, case_id: String,
		output: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var roof_on: Node3D = HouseAssembler.build(plan, false)
	if roof_on == null:
		_failed = true
		for view in _required_views(case_id):
			rows.append(_view_error(case_id, request.to_dict(), view, "roof-on assembly failed"))
		return rows
	_root3d.add_child(roof_on)
	await process_frame
	var scene_bounds := SceneBounds.of_node(roof_on)
	rows.append(await _render_exterior(plan, request, case_id, output, scene_bounds))
	rows.append(await _render_service_yard(plan, request, case_id, output))
	rows.append(await _render_interior(plan, request, case_id, output))
	if _heat_supplement_enabled and String(request.style) == "witch_hut":
		rows.append_array(await _render_cauldron_heat(plan, request, case_id, output, roof_on))
	roof_on.queue_free()
	await process_frame
	var cutaway: Node3D = HouseAssembler.build(plan, true)
	if cutaway == null:
		_failed = true
		rows.append(_view_error(case_id, request.to_dict(), "cutaway_context", "cutaway assembly failed"))
	else:
		_root3d.add_child(cutaway)
		await process_frame
		rows.append(await _render_cutaway(plan, request, case_id, output, cutaway))
		cutaway.queue_free()
		await process_frame
	return rows


## Supplemental framing for the actual indoor cauldron and its nearest workbench.
## The paired hidden-control image changes only NativeCauldronHeat visibility.
func _render_cauldron_heat(plan: HousePlan, request: BuildingRequest,
		case_id: String, output: String, assembled: Node3D) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var heat_views: Array[String] = HEAT_VIEWS.slice(0, 2) \
		if bool(_shared_heat_cases.get(case_id, false)) else HEAT_VIEWS
	var room := _workshop_room(plan)
	var cauldron: Dictionary = {}
	var bench: Dictionary = {}
	for piece in plan.furniture:
		if int(piece.get("room", -1)) != room:
			continue
		if String(piece.get("key", "")) == "Cauldron":
			cauldron = piece
	if not cauldron.is_empty():
		var found_cauldron_pos: Vector3 = cauldron.get("pos", Vector3.ZERO)
		var nearest_distance := INF
		for piece in plan.furniture:
			if int(piece.get("room", -1)) != room \
					or String(piece.get("cat", "")) != "workbench" \
					or String(piece.get("activity_group", "")) != "witchwork":
				continue
			var piece_pos: Vector3 = piece.get("pos", Vector3.ZERO)
			var distance := Vector2(piece_pos.x, piece_pos.z).distance_to(Vector2(found_cauldron_pos.x, found_cauldron_pos.z))
			if distance < nearest_distance:
				nearest_distance = distance
				bench = piece
	if room < 0 or cauldron.is_empty() or bench.is_empty():
		for view in heat_views:
			rows.append(_view_error(case_id, request.to_dict(), view,
				"workshop must contain both an actual Cauldron and witchwork Workbench"))
		return rows
	var focus_pieces: Array[Dictionary] = [cauldron]
	var cauldron_rect := Rect2(cauldron.get("rect", Rect2()))
	var cauldron_pos: Vector3 = cauldron.get("pos", Vector3.ZERO)
	var bench_pos: Vector3 = bench.get("pos", Vector3.ZERO)
	var workbench_distance := Vector2(cauldron_pos.x, cauldron_pos.z).distance_to(Vector2(bench_pos.x, bench_pos.z))
	var room_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var floor_y: float = HouseFurnishGeometry.storey_base(plan, room) + HouseGeometry.FLOOR_T
	var cue_match := _match_cauldron_heat_cue(assembled, cauldron)
	var heat_node := cue_match.get("node") as Node3D
	var camera := _find_eye_camera(plan, room, focus_pieces, cauldron_rect.get_center(),
		floor_y, room_rect, {}, 2.8, true, 1.18, _heat_sight_targets(heat_node))
	if not bool(camera.get("body_clear", false)) or not bool(camera.get("reachable", false)):
		for view in heat_views:
			rows.append(_view_error(case_id, request.to_dict(), view,
				"no reachable, body-clear human-height camera for the Cauldron"))
		return rows
	var eye: Vector3 = camera["eye"]
	var target: Vector3 = camera["target"]
	_cam.fov = 72.0
	_set_camera(eye, target, atan2(target.x - eye.x, target.z - eye.z), 24.0)
	if heat_node == null or not bool(cue_match.get("matched", false)):
		for view in heat_views:
			var error_row := _view_error(case_id, request.to_dict(), view,
				"no NativeCauldronHeat cue is within tolerance of the focused interior Cauldron")
			error_row["heat_cue_candidates"] = cue_match.get("candidates", [])
			error_row["heat_cue_match_tolerance_m"] = cue_match.get("tolerance_m", 0.10)
			rows.append(error_row)
		return rows
	var cauldron_root := heat_node.get_parent()
	var cauldron_body_visible := _has_visible_mesh(cauldron_root, heat_node)
	var heat_mesh_visible := _has_visible_mesh(heat_node)
	var cauldron_mesh_bounds := _mesh_bounds_excluding(cauldron_root, heat_node)
	var cauldron_mesh_bounds_in_frame := _aabb_in_frame(cauldron_mesh_bounds)
	var heat_mesh_bounds := _mesh_bounds_excluding(heat_node)
	var heat_mesh_bounds_in_frame := _aabb_in_frame(heat_mesh_bounds)
	var bounds_in_frame := bool(camera.get("focus_in_frame", false)) \
		and _placement_bounds_in_frame(cauldron, floor_y) \
		and cauldron_mesh_bounds_in_frame and heat_mesh_bounds_in_frame
	var workbench_visible_corners := _placement_visible_corner_count(bench, floor_y)
	var workbench_any_part_in_frame := workbench_visible_corners > 0
	if not bounds_in_frame or not bool(camera.get("line_of_sight_clear", false)):
		_failed = true
		_errors.append(case_id + " cauldron supplement: framing or line-of-sight failed; focus_in_frame=" + str(camera["focus_in_frame"]) + " line_of_sight_clear=" + str(camera["line_of_sight_clear"]))
	var base_details := {"roof_on": true, "cutaway": false, "room_index": room,
		"shared_cooking_and_witchwork_station": bool(_shared_heat_cases.get(case_id, false)),
		"room_kind": String(plan.kind_of(room)), "camera": _camera_data(eye, target,
			"reachable 1.58 m eye camera aimed at actual Cauldron; Workbench is secondary context"),
		"focused_placement_ids": [_placement_label(cauldron)],
		"secondary_context_placement_id": _placement_label(bench),
		"selected_heat_cue_path": cue_match["selected_path"],
		"selected_heat_cue_global_position": _xyz(cue_match["cue_global_position"]),
		"selected_heat_cue_global_pose": cue_match["cue_global_pose"],
		"selected_heat_cue_parent_global_position": _xyz(cue_match["parent_global_position"]),
		"expected_interior_cauldron_model_origin": cue_match["expected_model_origin"],
		"focused_cauldron_plan_center": cue_match["expected_plan_center"],
		"selected_heat_cue_parent_to_plan_center_distance_m": cue_match["distance_m"],
		"heat_cue_match_tolerance_m": cue_match["tolerance_m"],
		"heat_cue_candidates": cue_match["candidates"],
		"heat_cue_match_state": "passed",
		"workbench_distance_m": workbench_distance,
		"workbench_any_part_in_frame": workbench_any_part_in_frame,
		"workbench_any_bounds_corner_in_frame": workbench_any_part_in_frame,
		"workbench_visible_bounds_corners": workbench_visible_corners,
		"workbench_whole_bounds_in_frame": workbench_visible_corners == 8,
		"camera_body_clear": camera["body_clear"], "camera_reachable": camera["reachable"],
		"occlusion_blockers": camera["occlusion_blockers"],
		"focus_in_frame": camera["focus_in_frame"],
		"framing_candidate_count": camera["framing_candidate_count"],
		"line_of_sight_clear": camera["line_of_sight_clear"],
		"whole_prop_bounds_in_frustum": bounds_in_frame,
		"whole_cauldron_mesh_bounds_in_frustum": cauldron_mesh_bounds_in_frame,
		"whole_heat_cue_bounds_in_frustum": heat_mesh_bounds_in_frame,
		"cauldron_operating_zone_xz": _rect_data(cauldron_rect), "cauldron_body_mesh_present": cauldron_body_visible}
	var path := output.path_join(case_id + "_cauldron_heat_eye_level.jpg")
	var lit_image := await _capture_view_image()
	var save_error := _save_captured_image(lit_image, path)
	var row := _view_row(case_id, request, "cauldron_heat_eye_level", path, save_error, base_details.duplicate(true))
	if not bounds_in_frame or not cauldron_body_visible or not heat_mesh_visible:
		_failed = true
		_errors.append(case_id + " cauldron supplement: body, heat, or frustum acceptance failed")
	rows.append(row)
	heat_node.visible = false
	var heat_hidden := not _has_visible_mesh(heat_node)
	var control_body_visible := _has_visible_mesh(cauldron_root, heat_node)
	var control_path := output.path_join(case_id + "_cauldron_heat_hidden_control.jpg")
	var control_image := await _capture_view_image()
	var control_error := _save_captured_image(control_image, control_path)
	heat_node.visible = true
	var image_difference := _compare_images(lit_image, control_image)
	if not control_body_visible:
		_failed = true
		_errors.append(case_id + " cauldron supplement: Cauldron body disappeared with heat node hidden")
	if not heat_hidden:
		_failed = true
		_errors.append(case_id + " cauldron supplement: hiding NativeCauldronHeat left a visible heat mesh")
	if bool(image_difference.get("identical", true)):
		_failed = true
		_errors.append(case_id + " cauldron supplement: hidden-heat image is pixel-identical to the lit image")
	var control_details := base_details.duplicate(true)
	control_details["negative_control"] = {"mutation": "NativeCauldronHeat.visible = false",
		"heat_hidden_during_capture": heat_hidden,
		"cauldron_body_mesh_present": control_body_visible,
		"image_difference": image_difference,
		"image_difference_state": "passed" if not bool(image_difference.get("identical", true)) else "failed",
		"expected": "pot remains visible; ember bed and flame cue disappear"}
	rows.append(_view_row(case_id, request, "cauldron_heat_hidden_control", control_path, control_error, control_details))
	if bool(_shared_heat_cases.get(case_id, false)):
		# The compact plan deliberately shares one actual heat station. Its
		# lit/hidden pair tests both roles; inventing a second pot is a defect.
		return rows
	var hall_cauldron: Dictionary = {}
	for piece in plan.furniture:
		if String(piece.get("key", "")) == "Cauldron" \
				and int(piece.get("room", -1)) == plan.hearth_room():
			hall_cauldron = piece
			break
	var hall_match := _match_cauldron_heat_cue(assembled, hall_cauldron) \
		if not hall_cauldron.is_empty() else {}
	var hall_heat := hall_match.get("node") as Node3D
	if hall_cauldron.is_empty() or hall_heat == null or hall_heat == heat_node:
		_failed = true
		_errors.append(case_id + " cauldron supplement: separate Hall cooking heat cue was not found")
		return rows
	var hall_room := int(hall_cauldron["room"])
	var hall_rect: Rect2 = Rect2(hall_cauldron.get("rect", Rect2()))
	var hall_room_rect: Rect2 = HouseGeometry.room_floor_rect(plan, hall_room)
	var hall_floor_y: float = HouseFurnishGeometry.storey_base(plan, hall_room) + HouseGeometry.FLOOR_T
	var hall_camera := _find_eye_camera(plan, hall_room, [hall_cauldron],
		hall_rect.get_center(), hall_floor_y, hall_room_rect, {}, 2.8, true, 1.18,
		_heat_sight_targets(hall_heat))
	if not bool(hall_camera.get("body_clear", false)) or not bool(hall_camera.get("reachable", false)):
		_failed = true
		_errors.append(case_id + " cauldron supplement: no reachable human-height Hall cooking camera")
		return rows
	var hall_eye: Vector3 = hall_camera["eye"]
	var hall_target: Vector3 = hall_camera["target"]
	_set_camera(hall_eye, hall_target, atan2(hall_target.x - hall_eye.x,
		hall_target.z - hall_eye.z), 24.0)
	var hall_body := hall_heat.get_parent()
	var hall_bounds := _mesh_bounds_excluding(hall_body, hall_heat)
	var hall_in_frame := bool(hall_camera.get("focus_in_frame", false)) \
		and _placement_bounds_in_frame(hall_cauldron, hall_floor_y) \
		and _aabb_in_frame(hall_bounds) and _has_visible_mesh(hall_body, hall_heat)
	if not hall_in_frame or not _has_visible_mesh(hall_heat) \
			or not bool(hall_camera.get("line_of_sight_clear", false)):
		_failed = true
		_errors.append(case_id + " cauldron supplement: Hall cooking flame lacks clear framing or sight line")
	var hall_lit := await _capture_view_image()
	var hall_lit_path := output.path_join(case_id + "_hall_cooking_heat_visible.jpg")
	var hall_lit_error := _save_captured_image(hall_lit, hall_lit_path)
	rows.append(_view_row(case_id, request, "hall_cooking_heat_visible", hall_lit_path,
		hall_lit_error, {"room_index": hall_room,
		"focused_placement_ids": [_placement_label(hall_cauldron)],
		"camera": _camera_data(hall_eye, hall_target, "reachable human-height Hall cooking Cauldron"),
		"whole_prop_bounds_in_frustum": hall_in_frame,
		"line_of_sight_clear": bool(hall_camera.get("line_of_sight_clear", false)),
		"camera_body_clear": bool(hall_camera.get("body_clear", false)),
		"camera_reachable": bool(hall_camera.get("reachable", false)),
		"hall_heat_mesh_visible": _has_visible_mesh(hall_heat),
		"separate_from_witchwork_station": true}))
	# Keep the Hall camera fixed. Verify that the Workshop cue is the only node
	# toggled and the separate Hall cooking flame remains visible. Full-frame
	# image diffs are unstable across successive SubViewport captures.
	heat_node.visible = false
	var hall_control_visible := _has_visible_mesh(hall_heat)
	var workshop_hidden_for_hall := not heat_node.visible
	var hall_control := await _capture_view_image()
	var hall_control_path := output.path_join(case_id + "_hall_cooking_heat_hidden_control.jpg")
	var hall_control_error := _save_captured_image(hall_control, hall_control_path)
	var hall_difference := _compare_images(hall_lit, hall_control)
	heat_node.visible = true
	var workshop_restored := heat_node.visible and _has_visible_mesh(heat_node)
	var hall_visual_unchanged := hall_control_visible and workshop_hidden_for_hall and workshop_restored
	if not hall_control_visible or not workshop_hidden_for_hall or not workshop_restored:
		_failed = true
		_errors.append(case_id + " cauldron supplement: hiding Workshop heat changed or hid the Hall cooking flame")
	rows.append(_view_row(case_id, request, "hall_cooking_heat_hidden_control", hall_control_path,
		hall_control_error, {"room_index": hall_room,
		"focused_placement_ids": [_placement_label(hall_cauldron)],
		"camera": _camera_data(hall_eye, hall_target, "same Hall camera with only Workshop heat hidden"),
		"hall_heat_mesh_visible": hall_control_visible,
		"workshop_heat_hidden": workshop_hidden_for_hall,
		"workshop_heat_restored": workshop_restored,
		"image_difference": hall_difference,
		"image_visual_unchanged": hall_visual_unchanged,
		"negative_control_state": "passed" if hall_control_visible and workshop_hidden_for_hall and hall_visual_unchanged else "failed"}))
	return rows


func _heat_sight_targets(heat: Node3D) -> Array[Vector3]:
	var targets: Array[Vector3] = []
	if heat != null:
		for node in heat.find_children("LowFlame_*", "MeshInstance3D", true, false):
			if node.mesh != null:
				targets.append(node.global_transform * node.mesh.get_aabb().get_center())
	return targets


func _images_visually_unchanged(difference: Dictionary) -> bool:
	if not bool(difference.get("valid", false)):
		return false
	var width := int(difference.get("width", 0))
	var height := int(difference.get("height", 0))
	if width <= 0 or height <= 0:
		return false
	var max_channel := int(difference.get("max_channel_difference", 255))
	var average_channel := float(difference.get("absolute_rgb_difference", 1e20)) \
		/ float(width * height * 3)
	# Subviewport captures can differ by a few quantization levels across frames.
	return max_channel <= 5 and average_channel <= 2.0


func _placement_label(piece: Dictionary) -> String:
	var pos: Vector3 = piece.get("pos", Vector3.ZERO)
	return "%s|room=%d|x=%.3f|z=%.3f" % [String(piece.get("key", "")), int(piece.get("room", -1)), pos.x, pos.z]


func _match_cauldron_heat_cue(assembled: Node3D, placement: Dictionary) -> Dictionary:
	const MATCH_TOLERANCE_M := 0.10
	var expected_origin: Vector3 = PropCatalog.house_origin(placement)
	var expected_plan_center: Vector3 = placement.get("pos", Vector3.ZERO)
	var key := String(placement.get("key", "Cauldron"))
	var model_yaw := float(placement.get("yaw", 0.0)) + PropCatalog.face_offset(key)
	var placement_scale := float(placement.get("scale", 1.0))
	var cue_nodes: Array[Node3D] = []
	_collect_heat_cue_nodes(assembled, cue_nodes)
	var candidates: Array[Dictionary] = []
	var selected: Node3D = null
	var selected_parent_position := Vector3.ZERO
	var selected_cue_position := Vector3.ZERO
	var selected_cue_pose := {}
	var selected_distance := INF
	var selected_path := ""
	for cue in cue_nodes:
		var parent := cue.get_parent() as Node3D
		if parent == null:
			continue
		var parent_position := parent.global_position
		var origin_distance := Vector2(parent_position.x - expected_origin.x,
			parent_position.z - expected_origin.z).length()
		var parent_plan_center := PropCatalog.plan_centre(key, parent_position, model_yaw, placement_scale)
		var plan_center_distance := parent_plan_center.distance_to(Vector2(expected_plan_center.x, expected_plan_center.z))
		var under_furniture := _has_ancestor_named(cue, "Furniture")
		var record := {"node_path": str(cue.get_path()),
			"cue_global_position": _xyz(cue.global_position),
			"cue_global_pose": _node_pose(cue),
			"parent_global_position": _xyz(parent_position),
			"parent_to_expected_model_origin_m": origin_distance,
			"parent_derived_plan_center": [parent_plan_center.x, parent_plan_center.y],
			"parent_derived_plan_center_distance_m": plan_center_distance,
			"under_furniture": under_furniture,
			"eligible": under_furniture and origin_distance <= MATCH_TOLERANCE_M
				and plan_center_distance <= MATCH_TOLERANCE_M}
		candidates.append(record)
		if under_furniture and origin_distance <= MATCH_TOLERANCE_M \
				and plan_center_distance < selected_distance:
			selected = cue
			selected_parent_position = parent_position
			selected_cue_position = cue.global_position
			selected_cue_pose = _node_pose(cue)
			selected_distance = plan_center_distance
			selected_path = str(cue.get_path())
	return {"node": selected,
		"matched": selected != null and selected_distance <= MATCH_TOLERANCE_M,
		"selected_path": selected_path,
		"parent_global_position": selected_parent_position,
		"cue_global_position": selected_cue_position,
		"cue_global_pose": selected_cue_pose,
		"distance_m": selected_distance,
		"tolerance_m": MATCH_TOLERANCE_M,
		"expected_model_origin": _xyz(expected_origin),
		"expected_plan_center": [expected_plan_center.x, expected_plan_center.z],
		"candidates": candidates}


func _collect_heat_cue_nodes(node: Node, out: Array[Node3D]) -> void:
	if node is Node3D and String(node.name) == "NativeCauldronHeat":
		out.append(node as Node3D)
	for child in node.get_children():
		_collect_heat_cue_nodes(child, out)


func _has_ancestor_named(node: Node, ancestor_name: String) -> bool:
	var parent := node.get_parent()
	while parent != null:
		if String(parent.name) == ancestor_name:
			return true
		parent = parent.get_parent()
	return false


func _node_pose(node: Node3D) -> Dictionary:
	return {"position": _xyz(node.global_position),
		"rotation_radians": _xyz(node.global_rotation),
		"scale": _xyz(node.global_basis.get_scale())}


func _placement_bounds_in_frame(piece: Dictionary, floor_y: float) -> bool:
	return _placement_visible_corner_count(piece, floor_y) == 8


func _placement_visible_corner_count(piece: Dictionary, floor_y: float) -> int:
	var rect := Rect2(piece.get("rect", Rect2()))
	if not rect.has_area():
		return 0
	var height := maxf(PropCatalog.placement_height(piece), 0.25)
	var y0 := floor_y + PropCatalog.floor_offset(String(piece.get("key", "")))
	var size := _vp.size
	var visible_count := 0
	for x in [rect.position.x, rect.end.x]:
		for z in [rect.position.y, rect.end.y]:
			for y in [y0, y0 + height]:
				var point := _cam.unproject_position(Vector3(x, y, z))
				if not _cam.is_position_behind(Vector3(x, y, z)) and point.x >= 1.0 and point.y >= 1.0 and point.x < size.x - 1.0 and point.y < size.y - 1.0:
					visible_count += 1
	return visible_count


func _aabb_in_frame(bounds: AABB) -> bool:
	if bounds.size == Vector3.ZERO:
		return false
	var size := _vp.size
	for ix in 2:
		for iy in 2:
			for iz in 2:
				var point_3d := bounds.position + Vector3(
					bounds.size.x * float(ix), bounds.size.y * float(iy), bounds.size.z * float(iz))
				var point_2d := _cam.unproject_position(point_3d)
				if _cam.is_position_behind(point_3d) or point_2d.x < 1.0 or point_2d.y < 1.0 \
						or point_2d.x >= size.x - 1.0 or point_2d.y >= size.y - 1.0:
					return false
	return true


func _mesh_bounds_excluding(node: Node, excluded: Node = null) -> AABB:
	if node == null or node == excluded:
		return AABB()
	var result := AABB()
	var found := false
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null and mesh_node.is_visible_in_tree():
			result = mesh_node.global_transform * mesh_node.mesh.get_aabb()
			found = result.size != Vector3.ZERO
	for child in node.get_children():
		var child_bounds := _mesh_bounds_excluding(child, excluded)
		if child_bounds.size == Vector3.ZERO:
			continue
		result = child_bounds if not found else result.merge(child_bounds)
		found = true
	return result if found else AABB()


func _has_visible_mesh(node: Node, excluded: Node = null) -> bool:
	if node == null or node == excluded:
		return false
	if node is MeshInstance3D and (node as MeshInstance3D).is_visible_in_tree():
		return true
	for child in node.get_children():
		if _has_visible_mesh(child, excluded):
			return true
	return false


func _render_exterior(plan: HousePlan, request: BuildingRequest, case_id: String,
		output: String, bounds: AABB) -> Dictionary:
	var target := Vector3(0.0, bounds.position.y + bounds.size.y * 0.46, 0.0)
	var horizontal := Vector3(0.72, 0.0, -1.0).normalized() # front -Z, three-quarter
	var radius := maxf(Vector3(request.width, bounds.size.y, request.length).length() * 0.5, 2.0)
	var service_wing := _witch_service_shelter(plan)
	var framing_bounds := bounds
	if not service_wing.is_empty():
		framing_bounds = HouseGeometry.exterior_bounds(plan)
		radius = maxf(framing_bounds.size.length() * 0.5, 2.0)
		var core := Rect2() # WITCH-SIZE: a hut has no high core beside a service wing
		if core.has_area():
			var roof_layout := HouseGeometry.roof_layout(plan)
			var roof_transform: Transform3D = roof_layout.get("transform", Transform3D.IDENTITY)
			var gable_end := Vector2(roof_transform.basis.z.x, roof_transform.basis.z.z).normalized()
			var service_door := _witch_service_door(plan)
			if not service_door.is_empty() and gable_end.dot(Vector2(service_door.get("normal", Vector2.ZERO))) < 0.0:
				gable_end = -gable_end
			var gable_tangent := Vector2(-gable_end.y, gable_end.x)
			horizontal = Vector3((gable_end + gable_tangent * 0.20).x, 0.0,
				(gable_end + gable_tangent * 0.20).y).normalized()
			var core_center := core.get_center()
			target = Vector3(core_center.x,
				plan.spec.height + float(roof_layout.get("rise", 0.0)) * 0.48,
				core_center.y)
			horizontal = Vector3(0.24, 0.0, -1.0).normalized()
	_cam.fov = 46.0
	var direction := Vector3(horizontal.x, 0.22, horizontal.z).normalized()
	var aspect := float(_vp.size.x) / maxf(float(_vp.size.y), 1.0)
	var distance := _fit_camera_distance(framing_bounds, target, direction, _cam.fov, aspect, 1.06)
	var eye := target + direction * distance
	_set_camera(eye, target, atan2(direction.x, direction.z), distance + radius)
	var view := "roof_on_exterior"
	var path := output.path_join(case_id + "_" + view + ".jpg")
	var save_error := await _save_image(path)
	return _view_row(case_id, request, view, path, save_error, {
		"roof_on": true, "cutaway": false, "camera": _camera_data(eye, target,
			"front gable three-quarter; high core and attached service wing framing" if not service_wing.is_empty() else "front -Z three-quarter; shell envelope framing"),
		"scene_bounds": _aabb_data(bounds), "framing_bounds": _aabb_data(framing_bounds),
		"visible_front": "gable end aligned to roof transform" if not service_wing.is_empty() else "-Z"})


func _render_service_yard(plan: HousePlan, request: BuildingRequest,
		case_id: String, output: String) -> Dictionary:
	if plan.spec.style == &"witch_hut" and plan.spec.trade == &"none" \
			and plan.world_family == &"":
		if _witch_service_door(plan).is_empty():
			return _view_error(case_id, request.to_dict(), "service_yard",
				"furnished public plan is missing its required Workshop/shared-Hall yard threshold")
		if _witch_service_shelter(plan).is_empty():
			return _view_error(case_id, request.to_dict(), "service_yard",
				"furnished public plan is missing its required threshold-aligned Witch work shelter")
	var extent: Rect2 = HouseYard.extent(plan)
	if not extent.has_area():
		return _view_error(case_id, request.to_dict(), "service_yard",
			"generated plan has no yard extent to frame")
	var focus := _service_focus(plan, extent)
	var frame_rect := _service_frame_rect(plan, extent)
	var witch_view_direction := Vector2.ZERO
	if plan.spec.style == &"witch_hut":
		var prep_zone := _witch_prep_zone(plan)
		var brew_zone := _witch_brew_zone(plan)
		if prep_zone.has_area() and brew_zone.has_area():
			focus = (prep_zone.get_center() + brew_zone.get_center()) * 0.5
			frame_rect = frame_rect.merge(prep_zone)
			frame_rect = frame_rect.merge(brew_zone)
			frame_rect = frame_rect.merge(_service_frame_rect(plan, extent).grow(0.28))
		var service_door := _witch_service_door(plan)
		if not service_door.is_empty():
			witch_view_direction = Vector2(service_door.get("normal", Vector2.ZERO)).normalized()
	var house_centre := Vector2.ZERO
	var away := witch_view_direction if witch_view_direction.length_squared() > 0.5 \
		else (focus - house_centre).normalized()
	if away.length_squared() < 0.01:
		away = Vector2.RIGHT
	var radius := maxf(frame_rect.size.length() * 0.5, 1.6)
	var distance := maxf(5.8 if plan.spec.style == &"witch_hut" else 4.4,
		radius / tan(deg_to_rad(36.0)) * (1.32 if plan.spec.style == &"witch_hut" else 1.08))
	var tangent := Vector2(-away.y, away.x)
	var yard_view := (away * 0.92 + tangent * 0.39).normalized() if plan.spec.style == &"witch_hut" else away
	var eye_xz := focus + yard_view * distance
	var eye := Vector3(eye_xz.x, HouseGeometry.FLOOR_T + 1.72, eye_xz.y)
	var target := Vector3(focus.x, HouseGeometry.FLOOR_T + 0.85, focus.y)
	_cam.fov = 72.0
	_set_camera(eye, target, atan2(-yard_view.x, -yard_view.y), distance + radius)
	var path := output.path_join(case_id + "_service_yard.jpg")
	var save_error := await _save_image(path)
	return _view_row(case_id, request, "service_yard", path, save_error, {
		"roof_on": true, "cutaway": false,
		"camera": _camera_data(eye, target, "angled yard approach through service opening; prep, brew and shed front framed"),
		"yard_extent_xz": _rect_data(extent), "yard_prop_count": plan.yard.size(),
		"yard_frame_xz": _rect_data(frame_rect),
		"yard_built_piece_count": plan.yard_pieces.size(),
		"yard_roles": _yard_roles(plan),
		"yard_focus_role": _service_focus_role(plan)})


func _render_interior(plan: HousePlan, request: BuildingRequest,
		case_id: String, output: String) -> Dictionary:
	var witch_case := String(request.style) == "witch_hut"
	var room := _workshop_room(plan) if witch_case else _ordinary_control_room(plan)
	var view := "workshop_eye_level" if witch_case else "ordinary_interior_eye_level"
	if room < 0:
		return _view_error(case_id, request.to_dict(), view,
			"required interior room is absent")
	var pieces := _room_focus_pieces(plan, room, witch_case)
	if pieces.is_empty():
		return _view_error(case_id, request.to_dict(), view,
			"required room has no placed activity or furniture to inspect")
	var anchor := _pieces_anchor(pieces)
	var station: Dictionary = {}
	for piece in pieces:
		if String(piece.get("cat", "")) == "workbench" and (not witch_case or String(piece.get("activity_group", "")) == "witchwork"):
			station = piece
			anchor = Rect2(piece["rect"]).get_center()
			break
	if witch_case:
		var storage_sum := Vector2.ZERO
		var storage_count := 0
		for piece in pieces:
			var category := String(piece.get("cat", ""))
			if category in ["shelf", "storage"] or String(piece.get("key", "")).to_lower().contains("rack"):
				var pos: Vector3 = piece.get("pos", Vector3.ZERO)
				storage_sum += Vector2(pos.x, pos.z)
				storage_count += 1
		if storage_count > 0:
			anchor = anchor.lerp(storage_sum / float(storage_count), 0.62)
	var room_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var floor_y: float = HouseFurnishGeometry.storey_base(plan, room) + HouseGeometry.FLOOR_T
	var camera := _find_eye_camera(plan, room, pieces, anchor, floor_y, room_rect, station)
	if not bool(camera.get("body_clear", false)):
		return _view_error(case_id, request.to_dict(), view,
			"no clear human-height camera location")
	var eye: Vector3 = camera["eye"]
	var target: Vector3 = camera["target"]
	_cam.fov = 84.0 if witch_case else 76.0
	_set_camera(eye, target, atan2(target.x - eye.x, target.z - eye.z), 24.0)
	var path := output.path_join(case_id + "_" + view + ".jpg")
	var save_error := await _save_image(path)
	return _view_row(case_id, request, view, path, save_error, {
		"roof_on": true, "cutaway": false, "room_index": room,
		"room_kind": String(plan.kind_of(room)), "activity_group": "witchwork" if witch_case else "ordinary_control",
		"members": _piece_summary(pieces), "camera": _camera_data(eye, target,
			"reachable diagonal floor view; weighted bench and wall-storage composition"),
		"camera_body_clear": camera["body_clear"],
		"camera_reachable": camera["reachable"],
		"occlusion_blockers": camera["occlusion_blockers"],
		"candidate_count": camera["candidate_count"]})


func _render_cutaway(plan: HousePlan, request: BuildingRequest, case_id: String,
		output: String, node: Node3D) -> Dictionary:
	var bounds := SceneBounds.of_node(node)
	var target := bounds.get_center()
	_cam.fov = 48.0
	var radius := maxf(bounds.size.length() * 0.5, 1.0)
	var distance := radius / sin(deg_to_rad(_cam.fov * 0.5)) * 1.08
	var direction := Vector3(0.78, 0.62, -0.72).normalized()
	var eye := target + direction * distance
	_set_camera(eye, target, atan2(direction.x, direction.z), distance + radius)
	var path := output.path_join(case_id + "_cutaway_context.jpg")
	var save_error := await _save_image(path)
	return _view_row(case_id, request, "cutaway_context", path, save_error, {
		"roof_on": false, "cutaway": true,
		"camera": _camera_data(eye, target, "assembled cutaway bounds; front-right elevated"),
		"scene_bounds": _aabb_data(bounds), "room_count": plan.room_count(),
		"furniture_count": plan.furniture.size()})


func _set_camera(eye: Vector3, target: Vector3, yaw: float, reach: float) -> void:
	_cam.position = eye
	_cam.look_at(target, Vector3.UP)
	_family = &"house"
	_set_shot_lighting(yaw, reach)


func _find_eye_camera(plan: HousePlan, room: int, pieces: Array[Dictionary],
		anchor: Vector2, floor_y: float, room_rect: Rect2, station: Dictionary = {},
		preferred_distance: float = 2.8, require_focus_in_frame: bool = false,
		focus_target_height: float = -1.0, sight_targets: Array[Vector3] = []) -> Dictionary:
	var nav := HouseNavCheck.new()
	nav.check(plan)
	var grid: WalkGrid = nav._grids.get(plan.storey_of_room(room))
	var breast := HouseGeometry.hearth_breast(plan)
	var breast_rect: Rect2 = breast.get("rect", Rect2()) if int(breast.get("room", -1)) == room else Rect2()
	var recess_focus := false
	var recess_triangles: Array = []
	var sight_obstacles: Array[AABB] = []
	if not sight_targets.is_empty():
		for piece in plan.furniture:
			if int(piece.get("room", -1)) != room or _is_focus_piece(piece, pieces):
				continue
			var key := String(piece["key"])
			var yaw := float(piece["yaw"]) + PropCatalog.face_offset(key)
			var scale := float(piece.get("scale", 1.0))
			var origin := PropCatalog.house_origin(piece)
			var centre := PropCatalog.plan_centre(key, origin, yaw, scale)
			var size := PropCatalog.footprint_rotated(key, yaw) * scale
			var bottom := origin.y + PropCatalog.floor_offset(key) * PropCatalog.placement_height_scale(piece)
			sight_obstacles.append(AABB(Vector3(centre.x - size.x * 0.5, bottom, centre.y - size.y * 0.5),
				Vector3(size.x, PropCatalog.placement_height(piece), size.y)))
	if breast_rect.has_area() and String(breast.get("kind", "")) == "witch_cauldron_recess":
		for piece in pieces:
			if HouseGeometry.uses_witch_cooking_recess(plan, room, String(piece.get("key", ""))) \
					and breast_rect.has_point(anchor):
				recess_focus = true
		if recess_focus:
			# The camera looks through the emitted opening. A solid breast AABB
			# cannot distinguish its stone jambs from the empty firebox volume.
			var builder := HouseBuilder.new()
			var mesh := builder.build(plan)
			var bounds := AABB(Vector3(breast_rect.position.x, floor_y, breast_rect.position.y),
				Vector3(breast_rect.size.x, plan.spec.height, breast_rect.size.y)).grow(0.02)
			for triangle in MeshProbe.all_triangles(builder, mesh, mesh.get_surface_count()):
				var triangle_bounds := AABB(triangle[0], Vector3.ZERO)
				triangle_bounds = triangle_bounds.expand(triangle[1]).expand(triangle[2])
				if bounds.intersects(triangle_bounds.grow(0.001)):
					recess_triangles.append(triangle)
			focus_target_height = 0.58
			preferred_distance = 2.0
	var half_body := Vector2(0.26, 0.26)
	var best_score := INF
	var best_eye := Vector3(room_rect.get_center().x, floor_y + 1.58, room_rect.get_center().y)
	var blocker_best := 999
	var candidate_count := 0
	var framing_candidate_count := 0
	var best_focus_in_frame := false
	var best_line_of_sight_clear := false
	var min_x := room_rect.position.x + half_body.x + 0.08
	var max_x := room_rect.end.x - half_body.x - 0.08
	var min_z := room_rect.position.y + half_body.y + 0.08
	var max_z := room_rect.end.y - half_body.y - 0.08
	if grid != null:
		for ix in range(grid.nx):
			for iz in range(grid.nz):
				if grid.at(grid._seen, ix, iz) != 1:
					continue
				var candidate := grid.world_of(ix, iz)
				if candidate.x < min_x or candidate.x > max_x \
						or candidate.y < min_z or candidate.y > max_z:
					continue
				var body := Rect2(candidate - half_body, half_body * 2.0)
				var body_clear := true
				if breast_rect.has_area() and breast_rect.intersects(body):
					body_clear = false
				for piece in plan.furniture:
					if int(piece.get("room", -1)) != room:
						continue
					var obstruction := _camera_obstruction_rect(piece, floor_y)
					if obstruction.has_area() and obstruction.intersects(body):
						body_clear = false
						break
				if body_clear:
					candidate_count += 1
					var distance := candidate.distance_to(anchor)
					var blockers := 0
					for piece in plan.furniture:
						if int(piece.get("room", -1)) != room or _is_focus_piece(piece, pieces):
							continue
						if PropCatalog.placement_height(piece) < 1.0:
							continue
						if _segment_intersects_rect(candidate, anchor, Rect2(piece.get("rect", Rect2()))):
							blockers += 1
					if not recess_focus and breast_rect.has_area() and _segment_intersects_rect(candidate, anchor, breast_rect):
						blockers += 1
					var candidate_eye := Vector3(candidate.x, floor_y + 1.58, candidate.y)
					var target_height := focus_target_height if focus_target_height >= 0.0 else (1.18 if not station.is_empty() else 0.95)
					var candidate_target := Vector3(anchor.x, floor_y + target_height, anchor.y)
					if recess_focus and MeshProbe.ray_blocked(recess_triangles, candidate_eye, candidate_target):
						blockers += 1
					# A bench below eye height can still hide the floor-level fire.
					# Test the actual flame centres against measured 3D prop bodies.
					for sight_target in sight_targets:
						var hidden := recess_focus and MeshProbe.ray_blocked(recess_triangles, candidate_eye, sight_target)
						for obstacle in sight_obstacles:
							if obstacle.intersects_segment(candidate_eye, sight_target) != null:
								hidden = true
								break
						if hidden:
							blockers += 1
					var focus_in_frame := true
					if require_focus_in_frame:
						for focus_piece in pieces:
							if not _placement_visible_from_camera(focus_piece, floor_y,
									candidate_eye, candidate_target, 72.0):
								focus_in_frame = false
								break
						if focus_in_frame:
							framing_candidate_count += 1
					var score := float(blockers) * 100.0 + absf(distance - preferred_distance)
					if recess_focus:
						var front := (candidate - anchor).normalized().dot(Vector2(breast["normal"]))
						score += (1.0 - front) * 5.0
					var line_of_sight_clear := blockers == 0
					if require_focus_in_frame and not focus_in_frame:
						score += 1000000.0
					if require_focus_in_frame and not line_of_sight_clear:
						score += 100000.0
					if not station.is_empty():
						var facing: Vector2 = HouseFurnishScore._facing_of(float(station.get("yaw", 0.0)))
						var front_amount := (candidate - anchor).normalized().dot(facing)
						score += (1.0 - front_amount) * 1.2
						var diagonal_amount := (candidate - anchor).normalized().dot(facing.rotated(0.62))
						score += (1.0 - diagonal_amount) * 2.6
					if score < best_score:
						best_score = score
						best_eye = candidate_eye
						best_focus_in_frame = focus_in_frame
						best_line_of_sight_clear = line_of_sight_clear
						blocker_best = blockers
	var target_height := focus_target_height if focus_target_height >= 0.0 else (1.18 if not station.is_empty() else 0.95)
	var target := Vector3(anchor.x, floor_y + target_height, anchor.y)
	return {"eye": best_eye, "target": target, "body_clear": candidate_count > 0,
		"reachable": candidate_count > 0, "occlusion_blockers": blocker_best,
		"candidate_count": candidate_count, "focus_in_frame": best_focus_in_frame,
		"framing_candidate_count": framing_candidate_count,
		"line_of_sight_clear": best_line_of_sight_clear}


func _placement_visible_from_camera(piece: Dictionary, floor_y: float,
		eye: Vector3, target: Vector3, fov_degrees: float) -> bool:
	var rect := Rect2(piece.get("rect", Rect2()))
	if not rect.has_area():
		return false
	var height := maxf(PropCatalog.placement_height(piece), 0.25)
	var y0 := floor_y + PropCatalog.floor_offset(String(piece.get("key", "")))
	var forward := (target - eye).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()
	var tan_vertical := tan(deg_to_rad(fov_degrees * 0.5))
	var tan_horizontal := tan_vertical * float(_vp.size.x) / maxf(float(_vp.size.y), 1.0)
	for x in [rect.position.x, rect.end.x]:
		for z in [rect.position.y, rect.end.y]:
			for y in [y0, y0 + height]:
				var relative := Vector3(x, y, z) - eye
				var depth := relative.dot(forward)
				if depth <= 0.05 or absf(relative.dot(right)) > depth * tan_horizontal \
						or absf(relative.dot(up)) > depth * tan_vertical:
					return false
	return true


## Floor textiles are walkable. Raised and wall-mounted bodies matter only
## where their measured height intersects a standing person.
func _camera_obstruction_rect(piece: Dictionary, floor_y: float) -> Rect2:
	var key := String(piece.get("key", ""))
	if PropCatalog.has_tag(key, PropCatalog.GROUND):
		return Rect2()
	var origin := PropCatalog.house_origin(piece)
	var hs := PropCatalog.placement_height_scale(piece)
	var bottom := origin.y + PropCatalog.floor_offset(key) * hs
	var top := bottom + PropCatalog.placement_height(piece)
	if top <= floor_y + 0.03 or bottom >= floor_y + 1.80:
		return Rect2()
	var scale := float(piece.get("scale", 1.0))
	var model_yaw := float(piece.get("yaw", 0.0)) + PropCatalog.face_offset(key)
	var centre := PropCatalog.plan_centre(key, origin, model_yaw, scale)
	var footprint := PropCatalog.footprint_rotated(key, model_yaw) * scale
	return Rect2(centre - footprint * 0.5, footprint)


func _is_focus_piece(candidate: Dictionary, pieces: Array[Dictionary]) -> bool:
	for piece in pieces:
		if piece == candidate:
			return true
	return false


func _workshop_room(plan: HousePlan) -> int:
	for room in range(plan.room_count()):
		if plan.kind_of(room) == &"workshop":
			return room
	for room in range(plan.room_count()):
		var functions: Array = plan.rooms[room].get("domestic_functions", [])
		if bool(plan.rooms[room].get("shared_witchwork", false)) and functions.has(&"witchwork"):
			return room
	return -1


func _ordinary_control_room(plan: HousePlan) -> int:
	for kind in [&"kitchen", &"parlour", &"hall"]:
		for room in range(plan.room_count()):
			if plan.kind_of(room) == kind and not plan.furniture_of(room).is_empty():
				return room
	return -1


func _room_focus_pieces(plan: HousePlan, room: int, witch_case: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for piece in plan.furniture:
		if int(piece.get("room", -1)) != room:
			continue
		if not witch_case:
			out.append(piece)
			continue
		var group := String(piece.get("activity_group", ""))
		var category := String(piece.get("cat", ""))
		if group == "witchwork" or category in ["workbench", "hearth", "cauldron",
				"cookware", "bucket", "shelf", "bottle", "alchemy", "storage", "book"]:
			out.append(piece)
	return out


func _pieces_anchor(pieces: Array[Dictionary]) -> Vector2:
	var result := Vector2.ZERO
	for piece in pieces:
		var pos: Vector3 = piece.get("pos", Vector3.ZERO)
		result += Vector2(pos.x, pos.z)
	return result / float(maxi(pieces.size(), 1))


func _service_focus(plan: HousePlan, extent: Rect2) -> Vector2:
	for piece in plan.yard_pieces:
		if String(piece.get("role", "")) == "witch_work_shelter":
			return Rect2(piece.get("rect", extent)).get_center()
	var door := _witch_service_door(plan)
	if not door.is_empty():
		var pos: Vector2 = door["pos"]
		var normal: Vector2 = door["normal"]
		return pos + normal * (HouseGeometry.wall_thickness(plan.spec) + 1.0)
	var focus := Vector2.ZERO
	var count := 0
	for prop in plan.yard:
		var role := String(prop.get("role", ""))
		if role.begins_with("witch_") or role in ["herb_bed", "drying_line"]:
			var pos: Vector3 = prop.get("pos", Vector3.ZERO)
			focus += Vector2(pos.x, pos.z)
			count += 1
	if count > 0:
		return focus / float(count)
	return extent.get_center()


func _witch_service_shelter(plan: HousePlan) -> Dictionary:
	for piece in plan.yard_pieces:
		if String(piece.get("role", "")) == "witch_work_shelter":
			return piece
	return {}

func _service_focus_role(plan: HousePlan) -> String:
	for piece in plan.yard_pieces:
		if String(piece.get("role", "")) == "witch_work_shelter":
			return "witch_work_shelter"
	if not _witch_service_door(plan).is_empty():
		return "workshop_threshold"
	return "yard_cluster"


func _witch_service_door(plan: HousePlan) -> Dictionary:
	for door in plan.doors:
		if bool(door.get("witch_workshop_yard", false)):
			return door
	return {}


func _service_frame_rect(plan: HousePlan, fallback: Rect2) -> Rect2:
	for piece in plan.yard_pieces:
		if String(piece.get("role", "")) == "witch_work_shelter":
			return Rect2(piece.get("rect", fallback))
	return fallback


func _witch_prep_zone(plan: HousePlan) -> Rect2:
	for prop in plan.yard:
		if String(prop.get("role", "")) == "witch_prep_bench":
			return Rect2(prop.get("operation_zone", Rect2()))
	return Rect2()


func _witch_brew_zone(plan: HousePlan) -> Rect2:
	for prop in plan.yard:
		if String(prop.get("role", "")) == "witch_brewing_heat":
			return Rect2(prop.get("operation_zone", Rect2()))
	return Rect2()


func _yard_roles(plan: HousePlan) -> Array[String]:
	var roles: Array[String] = []
	for prop in plan.yard:
		var role := String(prop.get("role", ""))
		if not role.is_empty() and role not in roles:
			roles.append(role)
	for piece in plan.yard_pieces:
		var role := String(piece.get("role", ""))
		if not role.is_empty() and role not in roles:
			roles.append(role)
	return roles


func _segment_intersects_rect(start: Vector2, finish: Vector2, rect: Rect2) -> bool:
	var length := start.distance_to(finish)
	var samples := maxi(int(ceil(length / 0.12)), 1)
	for index in range(1, samples):
		if rect.has_point(start.lerp(finish, float(index) / float(samples))):
			return true
	return false


func _has_shared_cooking_cauldron(plan: HousePlan) -> bool:
	var cauldrons: Array[Dictionary] = []
	for piece in plan.furniture:
		if String(piece.get("key", "")) == "Cauldron":
			cauldrons.append(piece)
	if cauldrons.size() != 1 or int(cauldrons[0].get("room", -1)) != plan.hearth_room():
		return false
	var groups: Array = Array(cauldrons[0].get("shared_activity_groups", []))
	groups.append(String(cauldrons[0].get("activity_group", "")))
	return "cooking" in groups and "witchwork" in groups


func _required_views(case_id: String) -> Array[String]:
	var source: Array[String] = COTTAGE_VIEWS if case_id.begins_with("control_cottage") else WITCH_VIEWS
	var out: Array[String] = []
	for view in source:
		out.append(view)
	if _heat_supplement_enabled and not case_id.begins_with("control_cottage"):
		out.append_array(HEAT_VIEWS.slice(0, 2) if bool(_shared_heat_cases.get(case_id, false)) else HEAT_VIEWS)
	return out


func _view_row(case_id: String, request: BuildingRequest, view: String,
		path: String, save_error: Error, details: Dictionary) -> Dictionary:
	if save_error != OK:
		_failed = true
		_errors.append("%s %s image save failed: %s" % [case_id, view, error_string(save_error)])
	var row := {"case": case_id, "request": request.to_dict(), "view": view,
		"image": path, "save_error": save_error}
	row.merge(details, true)
	return row


func _view_error(case_id: String, request: Dictionary, view: String, message: String) -> Dictionary:
	_failed = true
	_errors.append("%s %s: %s" % [case_id, view, message])
	return {"case": case_id, "request": request, "view": view,
		"image": "", "error": message}


func _camera_data(eye: Vector3, target: Vector3, description: String) -> Dictionary:
	return {"eye": _xyz(eye), "target": _xyz(target), "fov_degrees": _cam.fov,
		"description": description}


func _piece_summary(pieces: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for piece in pieces:
		var pos: Vector3 = piece.get("pos", Vector3.ZERO)
		out.append({"key": String(piece.get("key", "")), "category": String(piece.get("cat", "")),
			"activity_group": String(piece.get("activity_group", "")),
			"position": _xyz(pos), "rect": _rect_data(Rect2(piece.get("rect", Rect2())))})
	return out


func _xyz(v: Vector3) -> Array[float]:
	return [v.x, v.y, v.z]


func _rect_data(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _aabb_data(bounds: AABB) -> Array[float]:
	return [bounds.position.x, bounds.position.y, bounds.position.z,
		bounds.size.x, bounds.size.y, bounds.size.z]


func _save_image(path: String) -> Error:
	var image: Image = await _capture_view_image()
	return _save_captured_image(image, path)


func _capture_view_image() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	return _vp.get_texture().get_image()


func _save_captured_image(image: Image, path: String) -> Error:
	return image.save_jpg(ProjectSettings.globalize_path(path), 0.94)


func _compare_images(first: Image, second: Image) -> Dictionary:
	if first == null or second == null or first.is_empty() or second.is_empty() \
			or first.get_width() != second.get_width() or first.get_height() != second.get_height():
		return {"valid": false, "identical": true, "changed_pixel_count": 0,
			"absolute_rgb_difference": 0}
	var first_rgba: Image = first.duplicate()
	var second_rgba: Image = second.duplicate()
	first_rgba.convert(Image.FORMAT_RGBA8)
	second_rgba.convert(Image.FORMAT_RGBA8)
	var first_bytes := first_rgba.get_data()
	var second_bytes := second_rgba.get_data()
	if first_bytes.size() != second_bytes.size() or first_bytes.size() % 4 != 0:
		return {"valid": false, "identical": true, "changed_pixel_count": 0,
			"absolute_rgb_difference": 0}
	var changed_pixel_count := 0
	var absolute_rgb_difference := 0
	var max_channel_difference := 0
	for offset in range(0, first_bytes.size(), 4):
		var pixel_changed := false
		for channel in 3:
			var difference := absi(int(first_bytes[offset + channel]) - int(second_bytes[offset + channel]))
			if difference > 0:
				pixel_changed = true
				absolute_rgb_difference += difference
				max_channel_difference = maxi(max_channel_difference, difference)
		if pixel_changed:
			changed_pixel_count += 1
	return {"valid": true, "identical": changed_pixel_count == 0,
		"changed_pixel_count": changed_pixel_count,
		"absolute_rgb_difference": absolute_rgb_difference,
		"max_channel_difference": max_channel_difference,
		"width": first.get_width(), "height": first.get_height()}


func _load_cases() -> Array[Dictionary]:
	var parsed: Dictionary = _load_json(REQUESTS_PATH)
	var out: Array[Dictionary] = []
	for item in parsed.get("cases", []):
		if item is Dictionary:
			out.append(item)
	return out


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		_failed = true
		_errors.append("invalid/missing JSON source: " + path)
		return {}
	return parser.data


func _source_snapshot() -> Dictionary:
	var paths: Array[String] = []
	for root_path in ["res://src", "res://core", "res://qa"]:
		_collect_scripts(root_path, paths)
	_collect_all_files("res://assets/props", paths)
	for path in ["res://tools/render_shots.gd",
		"res://tools/render_activity_groups.gd", "res://tools/render_witch_personality.gd",
		REQUESTS_PATH, VIEW_REQUEST_PATH]:
		if FileAccess.file_exists(path):
			paths.append(path)
	paths.sort()
	var entries := PackedStringArray()
	var per_file: Dictionary = {}
	for path in paths:
		var digest := FileAccess.get_sha256(path)
		per_file[path] = digest
		entries.append(path + ":" + digest)
	return {"file_count": entries.size(), "aggregate_sha256": "\n".join(entries).sha256_text(),
		"files": per_file}


func _collect_scripts(path: String, paths: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for filename in directory.get_files():
		if filename.ends_with(".gd"):
			paths.append(path.path_join(filename))
	for child in directory.get_directories():
		_collect_scripts(path.path_join(child), paths)


func _collect_all_files(path: String, paths: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for filename in directory.get_files():
		paths.append(path.path_join(filename))
	for child in directory.get_directories():
		_collect_all_files(path.path_join(child), paths)

func _fit_camera_distance(bounds: AABB, target: Vector3, direction: Vector3,
		vertical_fov: float, aspect: float, margin: float) -> float:
	var forward := -direction.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()
	var tan_v := tan(deg_to_rad(vertical_fov * 0.5))
	var tan_h := tan_v * maxf(aspect, 0.1)
	var distance := 0.0
	for ix in 2:
		for iy in 2:
			for iz in 2:
				var corner := bounds.position + Vector3(bounds.size.x * float(ix), bounds.size.y * float(iy), bounds.size.z * float(iz))
				var rel := corner - target
				var depth := rel.dot(direction.normalized())
				distance = maxf(distance, depth + absf(rel.dot(right)) / tan_h)
				distance = maxf(distance, depth + absf(rel.dot(up)) / tan_v)
	return maxf(distance, 1.0) * margin
