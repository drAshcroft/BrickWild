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

var _failed := false
var _errors: Array[String] = []


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


func _render_exterior(plan: HousePlan, request: BuildingRequest, case_id: String,
		output: String, bounds: AABB) -> Dictionary:
	var target := Vector3(0.0, bounds.position.y + bounds.size.y * 0.46, 0.0)
	var horizontal := Vector3(0.72, 0.0, -1.0).normalized() # front -Z, three-quarter
	var radius := maxf(Vector3(request.width, bounds.size.y, request.length).length() * 0.5, 2.0)
	_cam.fov = 46.0
	var distance := radius / sin(deg_to_rad(_cam.fov * 0.5)) * 1.08
	var direction := Vector3(horizontal.x, 0.22, horizontal.z).normalized()
	var eye := target + direction * distance
	_set_camera(eye, target, atan2(direction.x, direction.z), distance + radius)
	var view := "roof_on_exterior"
	var path := output.path_join(case_id + "_" + view + ".jpg")
	var save_error := await _save_image(path)
	return _view_row(case_id, request, view, path, save_error, {
		"roof_on": true, "cutaway": false, "camera": _camera_data(eye, target, "front -Z three-quarter; shell envelope framing"),
		"scene_bounds": _aabb_data(bounds), "visible_front": "-Z"})


func _render_service_yard(plan: HousePlan, request: BuildingRequest,
		case_id: String, output: String) -> Dictionary:
	var extent: Rect2 = HouseYard.extent(plan)
	if not extent.has_area():
		return _view_error(case_id, request.to_dict(), "service_yard",
			"generated plan has no yard extent to frame")
	var focus := _service_focus(plan, extent)
	var frame_rect := _service_frame_rect(plan, extent)
	var house_centre := Vector2.ZERO
	var away := (focus - house_centre).normalized()
	if away.length_squared() < 0.01:
		away = Vector2.RIGHT
	var radius := maxf(frame_rect.size.length() * 0.5, 1.6)
	var distance := maxf(4.4, radius / tan(deg_to_rad(36.0)) * 1.08)
	var eye_xz := focus + away * distance
	var eye := Vector3(eye_xz.x, HouseGeometry.FLOOR_T + 1.58, eye_xz.y)
	var target := Vector3(focus.x, HouseGeometry.FLOOR_T + 0.85, focus.y)
	_cam.fov = 72.0
	_set_camera(eye, target, atan2(-away.x, -away.y), distance + radius)
	var path := output.path_join(case_id + "_service_yard.jpg")
	var save_error := await _save_image(path)
	return _view_row(case_id, request, "service_yard", path, save_error, {
		"roof_on": true, "cutaway": false,
		"camera": _camera_data(eye, target, "eye height looking from yard toward attached service side"),
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
	var room_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var floor_y: float = HouseFurnishGeometry.storey_base(plan, room) + HouseGeometry.FLOOR_T
	var camera := _find_eye_camera(plan, room, pieces, anchor, floor_y, room_rect, station)
	if not bool(camera.get("body_clear", false)):
		return _view_error(case_id, request.to_dict(), view,
			"no clear human-height camera location")
	var eye: Vector3 = camera["eye"]
	var target: Vector3 = camera["target"]
	_cam.fov = 76.0
	_set_camera(eye, target, atan2(target.x - eye.x, target.z - eye.z), 24.0)
	var path := output.path_join(case_id + "_" + view + ".jpg")
	var save_error := await _save_image(path)
	return _view_row(case_id, request, view, path, save_error, {
		"roof_on": true, "cutaway": false, "room_index": room,
		"room_kind": String(plan.kind_of(room)), "activity_group": "witchwork" if witch_case else "ordinary_control",
		"members": _piece_summary(pieces), "camera": _camera_data(eye, target,
			"reachable floor at 1.58m eye height; facing actual workbench when present"),
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
		anchor: Vector2, floor_y: float, room_rect: Rect2, station: Dictionary = {}) -> Dictionary:
	var nav := HouseNavCheck.new()
	nav.check(plan)
	var grid: WalkGrid = nav._grids.get(plan.storey_of_room(room))
	var breast := HouseGeometry.hearth_breast(plan)
	var breast_rect: Rect2 = breast.get("rect", Rect2()) if int(breast.get("room", -1)) == room else Rect2()
	var half_body := Vector2(0.26, 0.26)
	var best_score := INF
	var best_eye := Vector3(room_rect.get_center().x, floor_y + 1.58, room_rect.get_center().y)
	var blocker_best := 999
	var candidate_count := 0
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
					if breast_rect.has_area() and _segment_intersects_rect(candidate, anchor, breast_rect):
						blockers += 1
					var score := float(blockers) * 100.0 + absf(distance - 2.8)
					if not station.is_empty():
						var facing: Vector2 = HouseFurnishScore._facing_of(float(station.get("yaw", 0.0)))
						var front_amount := (candidate - anchor).normalized().dot(facing)
						score += (1.0 - front_amount) * 4.0
					if score < best_score:
						best_score = score
						best_eye = Vector3(candidate.x, floor_y + 1.58, candidate.y)
						blocker_best = blockers
	var target := Vector3(anchor.x, floor_y + 0.95, anchor.y)
	return {"eye": best_eye, "target": target, "body_clear": candidate_count > 0,
		"reachable": candidate_count > 0, "occlusion_blockers": blocker_best, "candidate_count": candidate_count}


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


func _service_focus_role(plan: HousePlan) -> String:
	for piece in plan.yard_pieces:
		if String(piece.get("role", "")) == "witch_work_shelter":
			return "witch_work_shelter"
	return "yard_cluster"


func _service_frame_rect(plan: HousePlan, fallback: Rect2) -> Rect2:
	for piece in plan.yard_pieces:
		if String(piece.get("role", "")) == "witch_work_shelter":
			return Rect2(piece.get("rect", fallback))
	return fallback


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


func _required_views(case_id: String) -> Array[String]:
	var source: Array[String] = COTTAGE_VIEWS if case_id.begins_with("control_cottage") else WITCH_VIEWS
	var out: Array[String] = []
	for view in source:
		out.append(view)
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
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _vp.get_texture().get_image()
	return image.save_jpg(ProjectSettings.globalize_path(path), 0.94)


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
