extends "res://tools/render_shots.gd"
## Ordinary domestic plans, photographed at the actual activity groups.
## Run without --headless. Optional user args: out=... case=<case_id>.

const DEFAULT_OUT := "res://artifacts/personality/groups_wip/renders"
const ROOM_VIEWS: Array[String] = ["cooking", "sleep", "eating"]

var _failed := false
var _include_stress := false


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
		elif String(arg) == "stress":
			_include_stress = true
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output)) != OK:
		printerr("Cannot create activity-group output directory: ", output)
		quit(1)
		return
	var source_start := _source_snapshot()
	var rows: Array[Dictionary] = []
	var request_rows: Array[Dictionary] = []
	var chosen_requests: Array[BuildingRequest] = []
	for request in _requests():
		var case_id := "%s_%d_%dX%d" % [String(request.style), request.seed,
			int(request.width), int(request.length)]
		if not selected_case.is_empty() and selected_case != case_id:
			continue
		chosen_requests.append(request)
		request_rows.append({"id": case_id, "request": request.to_dict()})
		var building := BrickWild.generate(request)
		if not building.is_ok() or building.plan == null:
			_failed = true
			rows.append({"case": case_id, "request": request.to_dict(),
				"error": "public BrickWild.generate failed", "errors": building.errors})
			continue
		var plan: HousePlan = building.plan
		rows.append_array(await _render_case(plan, request, case_id, output))
	var source_end := _source_snapshot()
	var expected_render_count: int = chosen_requests.size() * (ROOM_VIEWS.size() + 1)
	var manifest := {"purpose": "actual furnished cooking, sleeping and eating groups at human eye height; roof-on interior views plus cutaway context",
		"source_start": source_start, "source_end": source_end,
		"source_changed": source_start != source_end,
		"case_filter": selected_case,
		"expected_case_count": chosen_requests.size(),
		"expected_render_count": expected_render_count,
		"requests": request_rows, "renders": rows}
	var manifest_path := output.path_join("manifest.json")
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		_failed = true
	else:
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()
	print("ACTIVITY_GROUP_RENDER cases=", request_rows.size(), " images=", rows.size(),
		" source_changed=", source_start != source_end, " failed=", _failed)
	quit(1 if _failed or chosen_requests.is_empty() \
		or request_rows.size() != chosen_requests.size() \
		or rows.size() != expected_render_count else 0)


func _requests() -> Array[BuildingRequest]:
	var requests: Array[BuildingRequest] = [
		BuildingRequest.house(8102, &"farmhouse", &"none", 9.0, 12.0, 2.6, 1),
		BuildingRequest.house(1, &"cottage", &"none", 7.0, 9.0, 2.6, 1),
		BuildingRequest.house(8102, &"cottage", &"none", 9.0, 12.0, 2.6, 1),
		BuildingRequest.house(8102, &"witch_hut", &"none", 9.0, 12.0, 2.6, 1),
	]
	if _include_stress:
		requests.append(BuildingRequest.house(1, &"cottage", &"none", 7.0, 7.0, 2.6, 1))
	return requests


func _render_case(plan: HousePlan, request: BuildingRequest, case_id: String,
		output: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var composition: Dictionary = _composition_report(plan)
	var mechanical_composition_ok := bool(composition.get("mechanical_composition_ok", false))
	print("ACTIVITY_COMPOSITION ", case_id, " mechanical_composition_ok=", mechanical_composition_ok,
		" groups=", JSON.stringify(composition.get("groups", [])))
	_mesh_inst.mesh = null
	var roof_on: Node3D = HouseAssembler.build(plan, false)
	if roof_on == null:
		_failed = true
		return [{"case": case_id, "request": request.to_dict(), "error": "roof-on assembly failed"}]
	_root3d.add_child(roof_on)
	await process_frame
	for activity in ROOM_VIEWS:
		var room := _activity_room(plan, activity)
		if room < 0:
			_failed = true
			rows.append({"case": case_id, "request": request.to_dict(),
				"view": activity, "mechanical_group_audit": composition,
				"mechanical_composition_ok": false,
				"error": "generated plan has no tagged activity group"})
			continue
		var members := _group_pieces(plan, room, activity)
		var anchor := _group_anchor(members)
		var floor: float = float(plan.storey_of_room(room)) * request.height + HouseGeometry.FLOOR_T
		var rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
		var camera: Dictionary = _find_activity_camera(plan, room, activity,
			members, anchor, floor, rect)
		var eye: Vector3 = camera["eye"]
		var target: Vector3 = camera["target"]
		_cam.fov = 76.0
		_cam.near = 0.05
		_cam.position = eye
		_cam.look_at(target, Vector3.UP)
		_family = &"house"
		var facing: Vector2 = Vector2(anchor.x - eye.x, anchor.y - eye.z).normalized()
		_set_shot_lighting(atan2(facing.x, facing.y), 24.0)
		var file_name := "%s_%s_roof_on.jpg" % [case_id, activity]
		var image_path := output.path_join(file_name)
		var save_error := await _save_image(image_path)
		if save_error != OK:
			_failed = true
		rows.append({"case": case_id, "request": request.to_dict(), "view": activity,
			"image": image_path, "roof_on": true, "cutaway": false,
			"room_index": room, "room_kind": String(plan.kind_of(room)),
			"activity_group": activity, "member_count": members.size(),
			"members": _member_summary(plan, members), "camera": {"eye": _xyz(eye),
				"target": _xyz(target), "fov_degrees": _cam.fov,
				"eye_height_above_storey_floor": 1.58,
				"aim": "horizontal centroid of actual placed activity_group furniture",
				"activity_anchor_xz": [anchor.x, anchor.y],
				"body_clear": camera["body_clear"],
				"occlusion_blockers": camera["occlusion_blockers"],
				"candidate_count": camera["candidate_count"]},
			"mechanical_group_audit": composition,
			"mechanical_composition_ok": mechanical_composition_ok,
			"save_error": save_error})
		print("ACTIVITY_VIEW ", file_name, " room=", room, " members=", members.size(),
			" saved=", save_error)
	roof_on.queue_free()
	await process_frame
	var cutaway: Node3D = HouseAssembler.build(plan, true)
	if cutaway == null:
		_failed = true
		rows.append({"case": case_id, "request": request.to_dict(),
			"view": "cutaway_context", "mechanical_group_audit": composition,
			"mechanical_composition_ok": mechanical_composition_ok,
			"error": "cutaway assembly failed"})
		return rows
	_root3d.add_child(cutaway)
	await process_frame
	var bounds := SceneBounds.of_node(cutaway)
	var target := bounds.get_center()
	_cam.fov = 52.0
	var radius := maxf(bounds.size.length() * 0.5, 1.0)
	var distance := radius / tan(deg_to_rad(_cam.fov) * 0.5) * 1.1
	var yaw := 2.4
	var pitch := -0.58
	var direction := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	_cam.position = target + direction * distance
	_cam.look_at(target, Vector3.UP)
	_family = &"house"
	_set_shot_lighting(yaw, distance + radius)
	var context_file := "%s_cutaway_context.jpg" % case_id
	var context_path := output.path_join(context_file)
	var context_error := await _save_image(context_path)
	if context_error != OK:
		_failed = true
	rows.append({"case": case_id, "request": request.to_dict(),
		"view": "cutaway_context", "image": context_path,
		"roof_on": false, "cutaway": true,
		"camera": {"eye": _xyz(_cam.position), "target": _xyz(target),
			"fov_degrees": _cam.fov, "yaw": yaw, "pitch": pitch,
			"framing": "assembled cutaway bounds"}, "save_error": context_error})
	rows.back()["mechanical_group_audit"] = composition
	rows.back()["mechanical_composition_ok"] = mechanical_composition_ok
	cutaway.queue_free()
	await process_frame
	return rows


func _composition_report(plan: HousePlan) -> Dictionary:
	var reports: Array[Dictionary] = []
	var required_roles_present := true
	var minimum_heights_ok := true
	for activity in ROOM_VIEWS:
		var room := _activity_room(plan, activity)
		var required: Dictionary = {}
		match activity:
			"cooking": required = {"hearth": 1, "storage": 1, "workbench": 1, "bucket": 1, "cookware": 1}
			"sleep": required = {"bed": 1, "chest": 2, "sconce": 1}
			"eating": required = {"table": 1, "seat": HouseFurnisher._household_seat_capacity(plan)}
		var counts: Dictionary = {}
		var dropped := false
		if room >= 0:
			for piece in _group_pieces(plan, room, activity):
				var category := String(piece.get("cat", ""))
				counts[category] = int(counts.get(category, 0)) + 1
			dropped = plan.was_dropped(room, "activity:" + activity)
		var group_ok := room >= 0 and not dropped
		for category in required:
			if int(counts.get(String(category), 0)) < int(required[category]):
				group_ok = false
		if not group_ok:
			required_roles_present = false
		var height_checks: Array[Dictionary] = []
		var group_heights_ok := true
		if room >= 0:
			for piece in _group_pieces(plan, room, activity):
				var category := String(piece.get("cat", ""))
				var minimum_height: float = 0.0
				if activity == "cooking" and category == "workbench":
					minimum_height = 0.75
				elif activity == "eating" and category == "table":
					minimum_height = 0.70
				if minimum_height <= 0.0:
					continue
				var key: String = String(piece.get("key", ""))
				var scale: float = float(piece.get("scale", 1.0))
				var catalog_height: float = PropCatalog.height(key)
				var measured_height: float = PropCatalog.placement_height(piece)
				var meets_minimum: bool = measured_height >= minimum_height
				if not meets_minimum:
					group_heights_ok = false
				height_checks.append({"category": category, "key": key,
					"scale": scale, "height_scale": PropCatalog.placement_height_scale(piece),
					"catalog_height_m": catalog_height,
					"measured_height_m": measured_height,
					"minimum_height_m": minimum_height,
					"meets_minimum": meets_minimum})
		if not group_heights_ok:
			minimum_heights_ok = false
		reports.append({"activity_group": activity, "room_index": room,
			"room_kind": String(plan.kind_of(room)) if room >= 0 else "missing",
			"required": required, "actual": counts, "dropped": dropped,
			"required_roles_present": group_ok,
			"minimum_height_checks": height_checks,
			"minimum_heights_ok": group_heights_ok})
	return {"required_roles_present": required_roles_present,
		"minimum_heights_ok": minimum_heights_ok,
		"mechanical_composition_ok": required_roles_present and minimum_heights_ok,
		"groups": reports}


func _find_activity_camera(plan: HousePlan, room: int, activity: String,
		members: Array[Dictionary], anchor: Vector2, floor_y: float,
		room_rect: Rect2) -> Dictionary:
	var half_body := Vector2(0.26, 0.26)
	var step := 0.25
	var best_score := INF
	var best_eye := Vector3(room_rect.get_center().x, floor_y + 1.58, room_rect.get_center().y)
	var blocker_best := 999
	var candidate_count := 0
	var min_x := room_rect.position.x + half_body.x + 0.08
	var max_x := room_rect.end.x - half_body.x - 0.08
	var min_z := room_rect.position.y + half_body.y + 0.08
	var max_z := room_rect.end.y - half_body.y - 0.08
	var x := min_x
	while x <= max_x + 0.001:
		var z := min_z
		while z <= max_z + 0.001:
			var candidate := Vector2(x, z)
			var body := Rect2(candidate - half_body, half_body * 2.0)
			var body_clear := true
			for piece in plan.furniture:
				if int(piece.get("room", -1)) == room \
						and Rect2(piece.get("rect", Rect2())).intersects(body):
					body_clear = false
					break
			if body_clear:
				candidate_count += 1
				var distance := candidate.distance_to(anchor)
				var blockers := 0
				for piece in plan.furniture:
					if int(piece.get("room", -1)) != room \
							or String(piece.get("activity_group", "")) == activity:
						continue
					if PropCatalog.placement_height(piece) < 1.0:
						continue
					if _segment_intersects_rect(candidate, anchor, Rect2(piece.get("rect", Rect2()))):
						blockers += 1
				var score := float(blockers) * 100.0 - distance
				if score < best_score:
					best_score = score
					best_eye = Vector3(candidate.x, floor_y + 1.58, candidate.y)
					blocker_best = blockers
			z += step
		x += step
	var target := Vector3(anchor.x, floor_y + 0.95, anchor.y)
	return {"eye": best_eye, "target": target, "body_clear": candidate_count > 0,
		"occlusion_blockers": blocker_best, "candidate_count": candidate_count}


func _segment_intersects_rect(start: Vector2, finish: Vector2, rect: Rect2) -> bool:
	var length := start.distance_to(finish)
	var samples := maxi(int(ceil(length / 0.12)), 1)
	for index in range(1, samples):
		var point := start.lerp(finish, float(index) / float(samples))
		if rect.has_point(point):
			return true
	return false


func _activity_room(plan: HousePlan, group: String) -> int:
	var preferred: Array[StringName] = []
	match group:
		"cooking": preferred = [&"kitchen", &"hall"]
		"sleep": preferred = [&"bedroom", &"hall"]
		"eating": preferred = [&"dining_room", &"dining", &"hall", &"parlour"]
	for preferred_kind in preferred:
		for room in range(plan.room_count()):
			if plan.kind_of(room) == preferred_kind and not _group_pieces(plan, room, group).is_empty():
				return room
	for room in range(plan.room_count()):
		if not _group_pieces(plan, room, group).is_empty():
			return room
	return -1


func _group_pieces(plan: HousePlan, room: int, group: String) -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	for piece in plan.furniture:
		if int(piece.get("room", -1)) == room \
				and String(piece.get("activity_group", "")) == group:
			pieces.append(piece)
	return pieces


func _group_anchor(pieces: Array[Dictionary]) -> Vector2:
	var anchor := Vector2.ZERO
	for piece in pieces:
		var pos: Vector3 = piece.get("pos", Vector3.ZERO)
		anchor += Vector2(pos.x, pos.z)
	return anchor / float(maxi(pieces.size(), 1))


func _member_summary(plan: HousePlan, pieces: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for piece in pieces:
		var position: Vector3 = piece.get("pos", Vector3.ZERO)
		var key: String = String(piece.get("key", ""))
		var scale: float = float(piece.get("scale", 1.0))
		var host_index: int = int(piece.get("host", -1))
		var host_key := ""
		var host_category := ""
		if host_index >= 0 and host_index < plan.furniture.size():
			var host: Dictionary = plan.furniture[host_index]
			host_key = String(host.get("key", ""))
			host_category = String(host.get("cat", ""))
		out.append({"cat": String(piece.get("cat", "")), "key": key,
			"scale": scale, "catalog_height_m": PropCatalog.height(key),
			"height_scale": PropCatalog.placement_height_scale(piece),
			"measured_height_m": PropCatalog.placement_height(piece),
			"pos": _xyz(position), "rect": _rect_json(Rect2(piece.get("rect", Rect2()))),
			"zone": _rect_json(Rect2(piece.get("zone", Rect2()))),
			"host_index": host_index, "host_key": host_key,
			"host_category": host_category,
			"activity_group": String(piece.get("activity_group", "")),
			"activity_host_cat": String(piece.get("activity_host_cat", "")),
			"surface_anchor_id": String(piece.get("surface_anchor_id", "")),
			"wall_host_id": String(piece.get("wall_host_id", ""))})
	return out


func _rect_json(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _xyz(value: Vector3) -> Array[float]:
	var out: Array[float] = [value.x, value.y, value.z]
	return out


func _save_image(path: String) -> Error:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _vp.get_texture().get_image()
	return image.save_jpg(ProjectSettings.globalize_path(path), 0.94)


func _source_snapshot() -> Dictionary:
	var paths: Array[String] = []
	for root_path in ["res://src", "res://core", "res://qa"]:
		_collect_scripts(root_path, paths)
	for extra in ["res://assets/props/catalog.json", "res://tools/render_shots.gd",
		"res://tools/render_activity_groups.gd",
		"res://artifacts/personality/groups_wip/tools/render_activity_groups.gd"]:
		if FileAccess.file_exists(extra):
			paths.append(extra)
	paths.sort()
	var items := PackedStringArray()
	for path in paths:
		items.append(path + ":" + FileAccess.get_sha256(path))
	return {"file_count": items.size(), "sha256": "\n".join(items).sha256_text()}


func _collect_scripts(path: String, paths: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file in directory.get_files():
		if file.ends_with(".gd"):
			paths.append(path.path_join(file))
	for child in directory.get_directories():
		_collect_scripts(path.path_join(child), paths)
