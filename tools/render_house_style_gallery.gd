extends "res://tools/render_shots.gd"
## Public-path visual reference for the eight house styles without a current
## comparable gallery. One style per invocation keeps the native render batch
## bounded and the output immutable.
##
## Run without --headless:
## godot --path . --script res://tools/render_house_style_gallery.gd -- style=townhouse
## Optional: run=<unique-name>

const GALLERY_SCRIPT_PATH := "res://tools/render_house_style_gallery.gd"
const MATRIX_PATH := "res://tools/house_style_visual_matrix.json"
const OUTPUT_ROOT := "res://visualqa/styles/house"
const GALLERY_STYLES: Array[StringName] = [&"townhouse", &"longhall", &"rich",
	&"mediterranean", &"asian", &"african", &"mud_hut", &"pueblo"]
const SCALE_NAMES: Array[String] = ["small", "default", "large"]
const FIXED_SEED := 8102
const ROOM_GROUPS: Array[Dictionary] = [
	{"group": "living", "kinds": [&"parlour", &"living_room", &"common_room", &"dining_room", &"mess", &"hall"]},
	{"group": "cooking", "kinds": [&"kitchen"]},
	{"group": "work", "kinds": [&"workshop", &"office"]},
	{"group": "sleeping", "kinds": [&"bedroom", &"guest_room"]},
	{"group": "storage", "kinds": [&"store", &"cellar"]},
]

var _failed := false
var _errors: Array[String] = []
var _asset_hash_cache: Dictionary = {}


func _init() -> void:
	_build_stage()
	await process_frame
	var args := _gallery_args(OS.get_cmdline_user_args())
	var style_id := StringName(args.get("style", ""))
	if style_id not in GALLERY_STYLES:
		printerr("Choose one gallery style: ", _style_names())
		quit(1)
		return
	var run_id := String(args.get("run", _new_run_id()))
	if not _safe_run_id(run_id):
		printerr("run= must be one path component containing only letters, digits, '_' or '-'")
		quit(1)
		return
	var out_root := "%s/%s/renders/%s" % [OUTPUT_ROOT, String(style_id), run_id]
	var absolute_root := ProjectSettings.globalize_path(out_root)
	if DirAccess.dir_exists_absolute(absolute_root) or FileAccess.file_exists(absolute_root):
		printerr("Refusing to overwrite existing gallery run: ", out_root)
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(absolute_root) != OK:
		printerr("Could not create gallery output: ", out_root)
		quit(1)
		return

	var source_start := _gallery_source_snapshot()
	var requests: Array[Dictionary] = []
	var case_rows: Array[Dictionary] = []
	var required_style_ids := _public_style_ids()
	if style_id not in required_style_ids:
		_failed = true
		_errors.append("selected house style is not published by BrickWild: " + String(style_id))
	else:
		for scale in SCALE_NAMES:
			var request := BrickWild.default_request(&"house", FIXED_SEED)
			request.style = style_id
			_apply_public_scale(request, scale)
			var request_id := "%s_%s_%d" % [String(style_id), scale, FIXED_SEED]
			var request_dir := out_root.path_join(request_id)
			var views_dir := request_dir.path_join("views")
			var rooms_dir := request_dir.path_join("rooms")
			if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(views_dir)) != OK \
					or DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(rooms_dir)) != OK:
				_failed = true
				_errors.append("could not create request image directories: " + request_id)
				continue
			var request_file := FileAccess.open(request_dir.path_join("request.json"), FileAccess.WRITE)
			if request_file == null:
				_failed = true
				_errors.append("could not write request snapshot: " + request_id)
			else:
				request_file.store_string(request.to_json())
				request_file.close()
			requests.append({"id": request_id, "scale": scale, "request": request.to_dict()})
			case_rows.append(await _render_public_case(request, request_id, scale,
				request_dir, views_dir, rooms_dir))
	var source_end := _gallery_source_snapshot()
	var source_changed: bool = source_start.get("aggregate_sha256", "") != source_end.get("aggregate_sha256", "")
	if source_changed:
		_failed = true
		_errors.append("source files changed while the gallery was rendering")
	var image_rows: Array[Dictionary] = []
	for row in case_rows:
		for view_row in row.get("renders", []):
			image_rows.append(view_row)
	var manifest := {
		"purpose": "public BuildingRequest comparison gallery for house styles; the full HouseStyles acceptance matrix is a separate gate",
		"gallery_state": "failed" if _failed else "rendered_not_visually_assessed",
		"visual_review_state": "not_assessed",
		"style": String(style_id), "seed": FIXED_SEED,
		"sizes": SCALE_NAMES, "expected_request_count": 3,
		"actual_request_count": requests.size(), "request_factory": "BrickWild.default_request(&house, 8102), style set, descriptor-based scale",
		"scale_method": "small/default/large use the public house descriptor min/default/max envelopes with midpoint interpolation, matching render_personality_baseline.gd",
		"output_root": out_root, "source_matrix": MATRIX_PATH,
		"source_start": source_start, "source_end": source_end,
		"source_changed": source_changed,
		"requests": requests, "cases": case_rows, "renders": image_rows,
		"errors": _errors,
	}
	var manifest_file := FileAccess.open(out_root.path_join("manifest.json"), FileAccess.WRITE)
	if manifest_file == null:
		_failed = true
		printerr("Could not write gallery manifest: ", out_root)
	else:
		manifest_file.store_string(JSON.stringify(manifest, "\t", true, true) + "\n")
		manifest_file.close()
	print("HOUSE_STYLE_GALLERY style=", style_id, " cases=", requests.size(),
		" images=", image_rows.size(), " source_changed=", source_changed,
		" failed=", _failed, " output=", out_root)
	quit(1 if _failed else 0)


func _render_public_case(request: BuildingRequest, request_id: String, scale: String,
		request_dir: String, views_dir: String, rooms_dir: String) -> Dictionary:
	var case_row: Dictionary = {"id": request_id, "scale": scale,
		"request": request.to_dict(), "generation_state": "not_attempted",
		"navigation_qa_state": "not_run", "assembly_state": "not_attempted",
		"render_state": "not_attempted", "visual_review_state": "not_assessed",
		"renders": [], "errors": []}
	var generated: GeneratedBuilding = BrickWild.generate(request)
	if not generated.is_ok() or generated.plan == null or not (generated.plan is HousePlan):
		case_row["generation_state"] = "failed"
		var generation_error := "public BrickWild.generate failed: %s" % str(generated.errors)
		case_row["errors"].append(generation_error)
		_errors.append(request_id + ": " + generation_error)
		_failed = true
		return case_row
	var plan: HousePlan = generated.plan
	case_row["generation_state"] = "passed"
	case_row["plan"] = _plan_summary(plan)
	var placement: Dictionary = BrickWild.placement(generated)
	if placement.is_empty():
		case_row["generation_state"] = "failed"
		case_row["errors"].append("public placement measurement returned no result")
		_errors.append(request_id + ": public placement measurement returned no result")
		_failed = true
		return case_row
	case_row["placement"] = _placement_summary(placement)
	var nav_checker := HouseNavCheck.new()
	var nav_report: Dictionary = nav_checker.check(plan)
	var nav_grids: Dictionary = nav_checker._grids
	case_row["navigation_qa"] = nav_report
	case_row["navigation_qa_state"] = "passed" if bool(nav_report.get("ok", false)) else "failed"
	if not bool(nav_report.get("ok", false)):
		var nav_error := "HouseNavCheck failures: " + str(nav_report.get("failures", []))
		case_row["errors"].append(nav_error)
		_errors.append(request_id + ": " + nav_error)
		_failed = true

	var roof_on: Node3D = BrickWild.instantiate(generated, false)
	if roof_on == null:
		case_row["assembly_state"] = "failed"
		case_row["render_state"] = "failed"
		var assembly_error := "public BrickWild.instantiate could not assemble the roof-on house"
		case_row["errors"].append(assembly_error)
		_errors.append(request_id + ": " + assembly_error)
		_failed = true
		return case_row
	case_row["assembly_state"] = "passed"
	case_row["assembler"] = "BrickWild.instantiate -> HouseFamilyAdapter -> HouseAssembler; measured catalogue assets"
	_root3d.add_child(roof_on)
	await process_frame
	var bounds: AABB = SceneBounds.of_node(roof_on)
	var prop_inventory: Dictionary = _prop_inventory(plan, roof_on)
	if not bool(prop_inventory.get("all_planned_nodes_present", false)):
		case_row["assembly_state"] = "failed"
		var prop_error := "public assembled scene is missing one or more planned prop instances"
		case_row["errors"].append(prop_error)
		_errors.append(request_id + ": " + prop_error)
		_failed = true
	case_row["assembled_scene"] = {"meta_brick_wild": bool(roof_on.get_meta(&"brick_wild", false)),
		"kind": String(roof_on.get_meta(&"brick_wild_kind", "")),
		"seed": int(roof_on.get_meta(&"brick_wild_seed", -1)),
		"bounds": _aabb_data(bounds),
		"prop_inventory": prop_inventory}
	case_row["renders"].append(await _render_exterior(plan, request, request_id,
		views_dir, bounds))
	var room_data: Dictionary = _room_gallery(plan)
	case_row["room_coverage"] = room_data.get("coverage", [])
	for room_view in room_data.get("views", []):
		var row: Dictionary = await _render_room_view(plan, request, request_id,
			room_view, rooms_dir, nav_grids)
		case_row["renders"].append(row)
	var missing_required_arrival: bool = plan.entrance_room() < 0
	if missing_required_arrival:
		_failed = true
		var arrival_error := "generated plan has no entrance room for the arrival-eye view"
		case_row["errors"].append(arrival_error)
		_errors.append(request_id + ": " + arrival_error)
	roof_on.queue_free()
	await process_frame
	var cutaway: Node3D = BrickWild.instantiate(generated, true)
	if cutaway == null:
		_failed = true
		case_row["renders"].append(_view_error(request_id, request.to_dict(),
			"cutaway_context", "public cutaway assembly failed"))
	else:
		_root3d.add_child(cutaway)
		await process_frame
		case_row["renders"].append(await _render_cutaway(plan, request, request_id,
			views_dir, cutaway))
		cutaway.queue_free()
		await process_frame
	var saved := 0
	for row in case_row["renders"]:
		if not row.has("error") and int(row.get("save_error", 1)) == 0:
			saved += 1
	case_row["rendered_image_count"] = saved
	case_row["render_state"] = "passed" if saved == case_row["renders"].size() \
		and case_row["errors"].is_empty() else "failed"
	case_row["generation_request_path"] = request_dir.path_join("request.json")
	return case_row


func _room_gallery(plan: HousePlan) -> Dictionary:
	var coverage: Array[Dictionary] = []
	var views: Array[Dictionary] = []
	var by_room: Dictionary = {}
	var arrival_room: int = plan.entrance_room()
	if arrival_room >= 0:
		_add_room_group(plan, coverage, views, by_room, "arrival", arrival_room, [arrival_room])
	else:
		coverage.append({"group": "arrival", "state": "required_room_missing", "candidate_rooms": []})
	for definition in ROOM_GROUPS:
		var group_name: String = String(definition["group"])
		var kinds: Array = definition["kinds"]
		var candidates: Array[int] = []
		for room_index in range(plan.room_count()):
			if plan.kind_of(room_index) in kinds:
				candidates.append(room_index)
		if candidates.is_empty():
			coverage.append({"group": group_name, "state": "absent_from_generated_plan",
				"candidate_kinds": _string_names(kinds), "candidate_rooms": []})
			continue
		var selected_room: int = candidates[0]
		for candidate_room in candidates:
			if not plan.furniture_of(candidate_room).is_empty():
				selected_room = candidate_room
				break
		_add_room_group(plan, coverage, views, by_room, group_name,
			selected_room, candidates)
	return {"coverage": coverage, "views": views}


func _add_room_group(plan: HousePlan, coverage: Array[Dictionary],
		views: Array[Dictionary], by_room: Dictionary, group_name: String,
		room_index: int, candidates: Array[int]) -> void:
	var state := "present" if not plan.furniture_of(room_index).is_empty() else "room_present_without_furniture"
	coverage.append({"group": group_name, "state": state, "selected_room": room_index,
		"room_kind": String(plan.kind_of(room_index)), "candidate_rooms": candidates})
	if by_room.has(room_index):
		var existing_index: int = int(by_room[room_index])
		var existing: Dictionary = views[existing_index]
		var existing_groups: Array = existing["activity_groups"]
		existing_groups.append(group_name)
		existing["activity_groups"] = existing_groups
		var represented: Dictionary = existing["represented_candidate_rooms"]
		represented[group_name] = candidates
		existing["represented_candidate_rooms"] = represented
		views[existing_index] = existing
		return
	var room_view: Dictionary = {"room_index": room_index,
		"room_kind": String(plan.kind_of(room_index)), "activity_groups": [group_name],
		"represented_candidate_rooms": {group_name: candidates}}
	by_room[room_index] = views.size()
	views.append(room_view)


func _render_room_view(plan: HousePlan, request: BuildingRequest,
		request_id: String, room_view: Dictionary, rooms_dir: String,
		nav_grids: Dictionary) -> Dictionary:
	var room: int = int(room_view["room_index"])
	var room_kind: String = String(room_view["room_kind"])
	var groups: Array = room_view["activity_groups"]
	var view_name: String = _joined(groups, "_")
	var view_id := "room_%s_%s_%d" % [view_name, room_kind, room]
	var pieces: Array[Dictionary] = []
	for piece in plan.furniture:
		if int(piece.get("room", -1)) == room:
			pieces.append(piece)
	var room_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var floor_y: float = HouseFurnishGeometry.storey_base(plan, room) + HouseGeometry.FLOOR_T
	var anchor: Vector2 = room_rect.get_center()
	var station: Dictionary = {}
	if not pieces.is_empty():
		anchor = _pieces_anchor(pieces)
		for piece in pieces:
			if String(piece.get("cat", "")) in ["workbench", "table", "hearth", "bed", "loom"]:
				station = piece
				var rect: Rect2 = piece.get("rect", Rect2())
				if rect.has_area():
					anchor = rect.get_center()
				break
	if groups.has("arrival"):
		station = {}
		var entrance_index: int = plan.entrance()
		if entrance_index >= 0:
			var door: Dictionary = plan.doors[entrance_index]
			var door_pos: Vector2 = door.get("pos", Vector2.ZERO)
			var normal: Vector2 = door.get("normal", Vector2.UP)
			anchor = door_pos - normal * 0.75
	var focus_pieces: Array[Dictionary] = []
	if not station.is_empty():
		focus_pieces.append(station)
	elif not pieces.is_empty():
		var nearest_distance: float = INF
		var nearest_piece: Dictionary = {}
		for piece in pieces:
			var piece_pos: Vector3 = PropCatalog.house_origin(piece)
			var distance: float = Vector2(piece_pos.x, piece_pos.z).distance_to(anchor)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_piece = piece
		if not nearest_piece.is_empty():
			focus_pieces.append(nearest_piece)
	var grid: WalkGrid = nav_grids.get(plan.storey_of_room(room))
	var camera: Dictionary = _find_eye_camera(plan, room, focus_pieces, anchor,
		floor_y, room_rect, station, grid)
	if not bool(camera.get("body_clear", false)) or not bool(camera.get("reachable", false)):
		var reason := "no reachable, clear human-height camera station in actual room grid"
		_failed = true
		return _view_error(request_id, request.to_dict(), view_id, reason)
	var eye: Vector3 = camera["eye"]
	var target: Vector3 = camera["target"]
	_cam.fov = 72.0
	var camera_yaw: float = atan2(target.x - eye.x, target.z - eye.z)
	_set_camera(eye, target, camera_yaw, 24.0)
	var path := rooms_dir.path_join(view_id + ".jpg")
	var save_error: Error = await _save_image(path)
	var row := _view_row(request_id, request, view_id, path, save_error, {
		"priority": "primary", "actual_room": {"index": room,
			"kind": room_kind, "storey": plan.storey_of_room(room),
			"floor_rect": _rect_data(room_rect)},
		"activity_groups": groups,
		"represented_candidate_rooms": room_view.get("represented_candidate_rooms", {}),
		"camera": _camera_data(eye, target,
			"1.58 m eye height from an entrance-reachable WalkGrid cell; actual assembled furnishings remain visible"),
		"camera_focus_prop_ids": _piece_ids(focus_pieces),
		"light": _light_metadata(camera_yaw),
		"camera_body_clear": bool(camera.get("body_clear", false)),
		"camera_reachable": bool(camera.get("reachable", false)),
		"camera_candidate_count": int(camera.get("candidate_count", 0)),
		"occlusion_blocker_count": int(camera.get("occlusion_blockers", 0)),
		"visible_room_props": _placement_inventory(pieces)})
	return row


func _render_exterior(plan: HousePlan, request: BuildingRequest, case_id: String,
		output: String, bounds: AABB) -> Dictionary:
	var target := Vector3(0.0, bounds.position.y + bounds.size.y * 0.46, 0.0)
	var horizontal := Vector3(0.72, 0.0, -1.0).normalized()
	var radius := maxf(Vector3(request.width, bounds.size.y, request.length).length() * 0.5, 2.0)
	_cam.fov = 46.0
	var distance := radius / sin(deg_to_rad(_cam.fov * 0.5)) * 1.08
	var direction := Vector3(horizontal.x, 0.22, horizontal.z).normalized()
	var eye := target + direction * distance
	var camera_yaw: float = atan2(direction.x, direction.z)
	_set_camera(eye, target, camera_yaw, distance + radius)
	var view := "roof_on_exterior"
	var path := output.path_join(view + ".jpg")
	var save_error: Error = await _save_image(path)
	return _view_row(case_id, request, view, path, save_error, {
		"priority": "primary", "roof_on": true, "cutaway": false,
		"camera": _camera_data(eye, target, "front -Z three-quarter; full roof-on assembly"),
		"light": _light_metadata(camera_yaw),
		"scene_bounds": _aabb_data(bounds), "visible_front": "-Z"})


func _render_cutaway(plan: HousePlan, request: BuildingRequest, case_id: String,
		output: String, node: Node3D) -> Dictionary:
	var bounds := SceneBounds.of_node(node)
	var target := bounds.get_center()
	_cam.fov = 48.0
	var radius := maxf(bounds.size.length() * 0.5, 1.0)
	var distance := radius / sin(deg_to_rad(_cam.fov * 0.5)) * 1.08
	var direction := Vector3(0.78, 0.62, -0.72).normalized()
	var eye := target + direction * distance
	var camera_yaw: float = atan2(direction.x, direction.z)
	_set_camera(eye, target, camera_yaw, distance + radius)
	var view := "cutaway_context"
	var path := output.path_join(view + ".jpg")
	var save_error: Error = await _save_image(path)
	return _view_row(case_id, request, view, path, save_error, {
		"priority": "secondary", "roof_on": false, "cutaway": true,
		"camera": _camera_data(eye, target, "assembled cutaway context; secondary to all roof-on views"),
		"light": _light_metadata(camera_yaw),
		"scene_bounds": _aabb_data(bounds), "room_count": plan.room_count(),
		"furniture_count": plan.furniture.size()})


func _find_eye_camera(plan: HousePlan, room: int, pieces: Array[Dictionary],
		anchor: Vector2, floor_y: float, room_rect: Rect2,
		station: Dictionary, grid: WalkGrid) -> Dictionary:
	var breast: Dictionary = HouseGeometry.hearth_breast(plan)
	var breast_rect: Rect2 = breast.get("rect", Rect2()) if int(breast.get("room", -1)) == room else Rect2()
	var half_body := Vector2(0.26, 0.26)
	var best_score: float = INF
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
				var candidate: Vector2 = grid.world_of(ix, iz)
				if candidate.x < min_x or candidate.x > max_x \
						or candidate.y < min_z or candidate.y > max_z:
					continue
				var body := Rect2(candidate - half_body, half_body * 2.0)
				var body_clear := not (breast_rect.has_area() and breast_rect.intersects(body))
				for piece in plan.furniture:
					if int(piece.get("room", -1)) != room:
						continue
					var obstruction := _camera_obstruction_rect(piece, floor_y)
					if obstruction.has_area() and obstruction.intersects(body):
						body_clear = false
						break
				if not body_clear:
					continue
				candidate_count += 1
				var distance: float = candidate.distance_to(anchor)
				var blockers := 0
				for piece in plan.furniture:
					if int(piece.get("room", -1)) != room or _is_gallery_focus_piece(piece, pieces):
						continue
					if PropCatalog.placement_height(piece) < 1.0:
						continue
					if _segment_intersects_rect(candidate, anchor, Rect2(piece.get("rect", Rect2()))):
						blockers += 1
				if breast_rect.has_area() and _segment_intersects_rect(candidate, anchor, breast_rect):
					blockers += 1
				var score: float = float(blockers) * 100.0 + absf(distance - 2.8)
				if not station.is_empty():
					var facing: Vector2 = HouseFurnishScore._facing_of(float(station.get("yaw", 0.0)))
					var front_amount: float = (candidate - anchor).normalized().dot(facing)
					score += (1.0 - front_amount) * 4.0
				if score < best_score:
					best_score = score
					best_eye = Vector3(candidate.x, floor_y + 1.58, candidate.y)
					blocker_best = blockers
	var target := Vector3(anchor.x, floor_y + 0.95, anchor.y)
	return {"eye": best_eye, "target": target,
		"body_clear": candidate_count > 0, "reachable": candidate_count > 0,
		"occlusion_blockers": blocker_best, "candidate_count": candidate_count}


func _camera_obstruction_rect(piece: Dictionary, floor_y: float) -> Rect2:
	var key := String(piece.get("key", ""))
	if PropCatalog.has_tag(key, PropCatalog.GROUND):
		return Rect2()
	var origin: Vector3 = PropCatalog.house_origin(piece)
	var height_scale: float = PropCatalog.placement_height_scale(piece)
	var bottom: float = origin.y + PropCatalog.floor_offset(key) * height_scale
	var top: float = bottom + PropCatalog.placement_height(piece)
	if top <= floor_y + 0.03 or bottom >= floor_y + 1.80:
		return Rect2()
	var scale: float = float(piece.get("scale", 1.0))
	var yaw: float = float(piece.get("yaw", 0.0)) + PropCatalog.face_offset(key)
	var centre: Vector2 = PropCatalog.plan_centre(key, origin, yaw, scale)
	var footprint: Vector2 = PropCatalog.footprint_rotated(key, yaw) * scale
	return Rect2(centre - footprint * 0.5, footprint)


func _is_gallery_focus_piece(candidate: Dictionary, pieces: Array[Dictionary]) -> bool:
	for piece in pieces:
		if piece == candidate:
			return true
	return false


func _segment_intersects_rect(start: Vector2, finish: Vector2, rect: Rect2) -> bool:
	var length: float = start.distance_to(finish)
	var samples: int = maxi(int(ceil(length / 0.12)), 1)
	for index in range(1, samples):
		if rect.has_point(start.lerp(finish, float(index) / float(samples))):
			return true
	return false


func _set_camera(eye: Vector3, target: Vector3, yaw: float, reach: float) -> void:
	_cam.position = eye
	_cam.look_at(target, Vector3.UP)
	_family = &"house"
	_set_shot_lighting(yaw, reach)


func _apply_public_scale(request: BuildingRequest, scale: String) -> void:
	var descriptor: Dictionary = BrickWild.describe_kind(&"house")
	for field in [&"width", &"length", &"height"]:
		var envelope: Dictionary = descriptor.get(String(field), {})
		if envelope.is_empty():
			continue
		var minimum: float = float(envelope["min"])
		var maximum: float = float(envelope["max"])
		var normal: float = float(envelope["value"])
		var selected: float = normal
		if scale == "small":
			selected = lerpf(minimum, normal, 0.5)
		elif scale == "large":
			selected = lerpf(normal, maximum, 0.5)
		request.set(String(field), clampf(selected, minimum, maximum))
	var storeys: Dictionary = descriptor.get("storeys", {})
	if not storeys.is_empty():
		var minimum_storeys: int = int(storeys["min"])
		var maximum_storeys: int = int(storeys["max"])
		var normal_storeys: int = int(storeys["value"])
		var selected_storeys: int = normal_storeys
		if scale == "small":
			selected_storeys = roundi(lerpf(float(minimum_storeys), float(normal_storeys), 0.5))
		elif scale == "large":
			selected_storeys = roundi(lerpf(float(normal_storeys), float(maximum_storeys), 0.5))
		request.storeys = clampi(selected_storeys, minimum_storeys, maximum_storeys)


func _public_style_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for row_variant in BrickWild.describe_kind(&"house").get("styles", []):
		var row: Dictionary = row_variant
		result.append(StringName(row.get("id", "")))
	return result


func _plan_summary(plan: HousePlan) -> Dictionary:
	var rooms: Array[Dictionary] = []
	for room in range(plan.room_count()):
		var rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
		rooms.append({"index": room, "kind": String(plan.kind_of(room)),
			"storey": plan.storey_of_room(room), "floor_rect": _rect_data(rect),
			"furniture_count": plan.furniture_of(room).size()})
	return {"style": String(plan.spec.style), "trade": String(plan.spec.trade),
		"variant": plan.spec.variant_name, "width": plan.spec.width,
		"length": plan.spec.length, "height_per_storey": plan.spec.height,
		"storeys": plan.spec.storeys, "rooms": rooms,
		"doors": plan.doors.size(), "windows": plan.windows.size(),
		"furniture_count": plan.furniture.size(), "exterior_prop_count": plan.exterior.size(),
		"yard_prop_count": plan.yard.size(), "yard_piece_count": plan.yard_pieces.size()}


func _placement_summary(placement: Dictionary) -> Dictionary:
	var out := placement.duplicate(true)
	for key in ["bounds"]:
		if out.get(key) is AABB:
			out[key] = _aabb_data(out[key])
	for key in ["footprint", "yard", "yard_extent"]:
		if out.get(key) is Rect2:
			out[key] = _rect_data(out[key])
	if out.get("yard_categories") is Array:
		out["yard_categories"] = _string_names(out["yard_categories"])
	if out.get("door") is Vector3:
		out["door"] = _xyz(out["door"])
	if out.get("front") is Vector3:
		out["front"] = _xyz(out["front"])
	if out.get("north") is Vector3:
		out["north"] = _xyz(out["north"])
	if out.get("yard_blocks") is Array:
		var blocks: Array = []
		for block in out["yard_blocks"]:
			blocks.append(_rect_data(block) if block is Rect2 else block)
		out["yard_blocks"] = blocks
	return out


func _prop_inventory(plan: HousePlan, assembled: Node3D) -> Dictionary:
	var tree_names: Dictionary = {}
	_collect_node_names(assembled, tree_names)
	var furniture_rows := _placement_inventory(plan.furniture)
	var exterior_rows := _placement_inventory(plan.exterior, true)
	var yard_rows := _placement_inventory(plan.yard, true)
	var missing_nodes: Array[String] = []
	_match_assembled_placements(plan.furniture, assembled.get_node_or_null("Furniture"), true, missing_nodes)
	_match_assembled_placements(plan.exterior + plan.yard, assembled.get_node_or_null("Exterior"), false, missing_nodes)
	if not missing_nodes.is_empty():
		_failed = true
		_errors.append("assembled public scene is missing planned prop nodes: " + str(missing_nodes))
	return {"furniture": furniture_rows, "exterior": exterior_rows,
		"yard": yard_rows, "assembled_node_names": tree_names,
		"missing_planned_nodes": missing_nodes,
		"all_planned_nodes_present": missing_nodes.is_empty(),
		"prop_catalog_root": PropCatalog.asset_root(),
		"prop_catalog_sha256": _asset_sha256(PropCatalog.catalog_path())}


## Godot uniquifies sibling names. Match real model roots and their planned
## transforms one-to-one instead of requiring duplicate children to share a name.
func _match_assembled_placements(placements: Array, container: Node,
		centred: bool, missing: Array[String]) -> void:
	var used: Array[Node] = []
	for piece: Dictionary in placements:
		var key: String = piece["key"]
		var path: String = PropCatalog.scene_path(key)
		var scale_value: float = float(piece.get("scale", 1.0))
		var height_scale: float = PropCatalog.placement_height_scale(piece)
		var expected_position: Vector3 = PropCatalog.house_origin(piece)
		if not centred:
			var drop: float = PropCatalog.seat_offset(key) * height_scale
			if PropCatalog.has_tag(key, PropCatalog.WALL_MOUNTED) or PropCatalog.has_tag(key, PropCatalog.CEILING):
				drop = 0.0
			expected_position = Vector3(piece["pos"]) - Vector3.UP * drop
		var expected_scale := Vector3(scale_value, height_scale, scale_value)
		var expected_basis := Basis(Vector3.UP, float(piece["yaw"]) + PropCatalog.face_offset(key)).scaled(expected_scale)
		var found := false
		if container != null:
			for candidate: Node in container.get_children():
				if candidate in used or not candidate is Node3D or candidate.scene_file_path != path:
					continue
				var model := candidate as Node3D
				if model.position.distance_to(expected_position) > 0.002:
					continue
				if model.basis.x.distance_to(expected_basis.x) > 0.002 or model.basis.y.distance_to(expected_basis.y) > 0.002 or model.basis.z.distance_to(expected_basis.z) > 0.002:
					continue
				used.append(candidate)
				found = true
				break
		if not found:
			missing.append("%s model root or planned transform missing at %s" % [key, str(expected_position)])


func _placement_inventory(placements: Array, exterior := false) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for variant in placements:
		var piece: Dictionary = variant
		var key: String = String(piece.get("key", ""))
		var path: String = PropCatalog.scene_path(key) if not key.is_empty() else ""
		var size: Vector3 = PropCatalog.size(key) if not key.is_empty() else Vector3.ZERO
		var pos: Vector3 = piece.get("pos", Vector3.ZERO)
		rows.append({"id": String(piece.get("id", key)), "key": key,
			"category": String(piece.get("cat", "")), "room": int(piece.get("room", -1)),
			"position": _xyz(pos), "scale": float(piece.get("scale", 1.0)),
			"height_scale": PropCatalog.placement_height_scale(piece),
			"yaw": float(piece.get("yaw", 0.0)), "measured_catalog_size": _xyz(size),
			"measured_plan_footprint": _v2(PropCatalog.footprint_rotated(key,
				float(piece.get("yaw", 0.0))) * float(piece.get("scale", 1.0))) if not key.is_empty() else [],
			"asset_path": path, "asset_exists": not path.is_empty() and FileAccess.file_exists(path),
			"asset_sha256": _asset_sha256(path),
			"assembler_node_name": String(piece.get("id", key)) if exterior else key})
	return rows


func _asset_sha256(path: String) -> String:
	if path.is_empty() or not FileAccess.file_exists(path):
		return ""
	if not _asset_hash_cache.has(path):
		_asset_hash_cache[path] = FileAccess.get_sha256(path)
	return String(_asset_hash_cache[path])


func _collect_node_names(node: Node, counts: Dictionary) -> void:
	for child in node.get_children():
		var name := String(child.name)
		counts[name] = int(counts.get(name, 0)) + 1
		_collect_node_names(child, counts)


func _gallery_source_snapshot() -> Dictionary:
	var paths: Array[String] = []
	for root_path in ["res://src", "res://core", "res://qa"]:
		_collect_gallery_scripts(root_path, paths)
	if FileAccess.file_exists(PropCatalog.catalog_path()):
		paths.append(PropCatalog.catalog_path())
	for path in ["res://tools/render_shots.gd", "res://tools/render_witch_personality.gd",
		"res://tools/render_personality_baseline.gd", GALLERY_SCRIPT_PATH, MATRIX_PATH]:
		if FileAccess.file_exists(path):
			paths.append(path)
	paths.sort()
	var files: Dictionary = {}
	for path in paths:
		files[path] = FileAccess.get_sha256(path)
	files[GALLERY_SCRIPT_PATH] = FileAccess.get_sha256(GALLERY_SCRIPT_PATH)
	files[MATRIX_PATH] = FileAccess.get_sha256(MATRIX_PATH)
	paths.clear()
	for path_variant in files.keys():
		paths.append(String(path_variant))
	paths.sort()
	var entries := PackedStringArray()
	for path in paths:
		entries.append(path + ":" + String(files[path]))
	return {"file_count": files.size(), "aggregate_sha256": "\n".join(entries).sha256_text(),
		"files": files}


func _collect_gallery_scripts(path: String, paths: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for filename in directory.get_files():
		if filename.ends_with(".gd"):
			paths.append(path.path_join(filename))
	for child in directory.get_directories():
		_collect_gallery_scripts(path.path_join(child), paths)


func _gallery_args(args: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for arg in args:
		var text := String(arg)
		if not text.contains("="):
			continue
		var split := text.split("=", false, 1)
		if split.size() == 2:
			result[String(split[0])] = String(split[1])
	return result


func _new_run_id() -> String:
	var timestamp := Time.get_datetime_string_from_system(true).replace("-", "").replace(":", "").replace("T", "_").replace("Z", "")
	return "run_%s_%d" % [timestamp, Time.get_ticks_usec()]


func _safe_run_id(value: String) -> bool:
	if value.is_empty():
		return false
	for character in value:
		var code: int = character.unicode_at(0)
		var allowed := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) \
			or (code >= 97 and code <= 122) or character == "_" or character == "-"
		if not allowed:
			return false
	return true


func _joined(values: Array, separator: String) -> String:
	var parts := PackedStringArray()
	for value in values:
		parts.append(String(value))
	return separator.join(parts)


func _style_names() -> String:
	var names: PackedStringArray = []
	for style in GALLERY_STYLES:
		names.append(String(style))
	return ", ".join(names)


func _string_names(values: Array) -> Array[String]:
	var out: Array[String] = []
	for value in values:
		out.append(String(value))
	return out


func _pieces_anchor(pieces: Array[Dictionary]) -> Vector2:
	var result := Vector2.ZERO
	for piece in pieces:
		var pos: Vector3 = piece.get("pos", Vector3.ZERO)
		result += Vector2(pos.x, pos.z)
	return result / float(maxi(pieces.size(), 1))


func _piece_ids(pieces: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for piece in pieces:
		out.append(String(piece.get("id", piece.get("key", ""))))
	return out


func _camera_data(eye: Vector3, target: Vector3, description: String) -> Dictionary:
	return {"eye": _xyz(eye), "target": _xyz(target), "fov_degrees": _cam.fov,
		"description": description}


func _xyz(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _v2(value: Vector2) -> Array[float]:
	return [value.x, value.y]


func _rect_data(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _aabb_data(bounds: AABB) -> Array[float]:
	return [bounds.position.x, bounds.position.y, bounds.position.z,
		bounds.size.x, bounds.size.y, bounds.size.z]


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
	return {"case": case_id, "request": request, "view": view, "image": "", "error": message}


func _save_image(path: String) -> Error:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _vp.get_texture().get_image()
	return image.save_jpg(ProjectSettings.globalize_path(path), 0.94)
