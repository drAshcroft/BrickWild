extends "res://tools/render_shots.gd"
## Roof-on task-wall and timber-bay review renders for the staged LIVE-SURFACES
## proposal. Uses public BrickWild requests and the actual assembled plan.
## Run without --headless after integrating the WIP source files:
## godot --path . --script res://tools/render_house_surfaces.gd
## Optional user args: out=res://artifacts/personality/surfaces_final/renders case=...

const DEFAULT_OUT := "res://artifacts/personality/resumed/surface_renders"
const ACTIVITY_VIEWS: Array[String] = ["cooking", "sleep", "witchwork"]
const SOURCE_ROOTS: Array[String] = ["res://src", "res://core", "res://qa"]

var _failed := false


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
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output)) != OK:
		printerr("Cannot create surfaces output directory: ", output)
		quit(1)
		return
	var source_start := _source_snapshot()
	var rows: Array[Dictionary] = []
	var request_rows: Array[Dictionary] = []
	var timber_bay_views := 0
	for entry in _request_matrix():
		var case_id := String(entry["id"])
		if not selected_case.is_empty() and case_id != selected_case:
			continue
		var request: BuildingRequest = entry["request"]
		request_rows.append({"id": case_id, "size": entry["size"],
			"request": request.to_dict()})
		print("SURFACES_CASE_START ", case_id)
		var building := BrickWild.generate(request)
		if not building.is_ok() or building.plan == null:
			_failed = true
			rows.append({"case": case_id, "size": entry["size"],
				"request": request.to_dict(), "error": "public BrickWild.generate failed",
				"errors": building.errors})
			continue
		var plan: HousePlan = building.plan
		var rendered := await _render_case(plan, request, case_id, String(entry["size"]), output)
		rows.append_array(rendered["rows"])
		timber_bay_views += int(rendered["timber_bay_views"])
	var image_count := _saved_image_count(rows)
	var error_row_count := 0
	var omitted_view_count := 0
	for row in rows:
		if row.has("error"):
			error_row_count += 1
		elif row.has("omission_reason"):
			omitted_view_count += 1
		elif int(row.get("save_error", -1)) != OK:
			error_row_count += 1
	if error_row_count > 0:
		_failed = true
	var source_end := _source_snapshot()
	var manifest := {"purpose": "roof-on eye-height task-wall portraits; return-wall cooking context; raking timber-bay views; cutaway context",
		"visual_review_status": "pending_human_review",
		"source_start": source_start, "source_end": source_end,
		"source_changed": source_start != source_end,
		"requests": request_rows, "renders": rows,
		"image_count": image_count, "error_row_count": error_row_count,
		"omitted_view_count": omitted_view_count,
		"timber_bay_view_count": timber_bay_views,
		"expected_case_count": _request_matrix().size() if selected_case.is_empty() else 1}
	var file := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	if file == null:
		_failed = true
	else:
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()
	if timber_bay_views == 0:
		_failed = true
		printerr("No timber-bay view was rendered; the requested raking view is missing.")
	print("SURFACES_RENDER cases=", request_rows.size(), " images=", image_count,
		" error_rows=", error_row_count, " timber_bay_views=", timber_bay_views,
		" source_changed=", source_start != source_end, " failed=", _failed)
	quit(1 if _failed or request_rows.is_empty() or source_start != source_end else 0)


func _saved_image_count(rows: Array[Dictionary]) -> int:
	var saved := 0
	for row in rows:
		if not row.has("image") or int(row.get("save_error", -1)) != OK:
			continue
		if not FileAccess.file_exists(ProjectSettings.globalize_path(String(row["image"]))):
			continue
		saved += 1
	return saved

func _request_matrix() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for style in [&"farmhouse", &"cottage", &"witch_hut"]:
		for size in ["small", "ample"]:
			var width := 9.0 if size == "small" else 11.0
			var length := 12.0 if size == "small" else 14.0
			var seed := 8102 if size == "small" else 1
			var request := BuildingRequest.house(seed, style, &"none",
				width, length, 2.6, 1)
			rows.append({"id": "%s_%s_%d" % [String(style), size, seed],
				"size": size, "request": request})
	return rows


func _render_case(plan: HousePlan, request: BuildingRequest, case_id: String,
		size_name: String, output: String) -> Dictionary:
	var rows: Array[Dictionary] = []
	var mechanical := _mechanical_report(plan)
	print("SURFACES_MECHANICAL ", case_id, " ", mechanical)
	var roof_on: Node3D = HouseAssembler.build(plan, false)
	if roof_on == null:
		_failed = true
		return {"rows": [{"case": case_id, "request": request.to_dict(),
			"error": "roof-on assembly failed", "mechanical_audit": mechanical}],
			"timber_bay_views": 0}
	_root3d.add_child(roof_on)
	await process_frame
	for activity in ACTIVITY_VIEWS:
		if activity == "witchwork" and request.style != &"witch_hut":
			continue
		var room := _activity_room(plan, activity)
		if room < 0:
			rows.append({"case": case_id, "size": size_name,
				"request": request.to_dict(), "view": activity,
				"error": "required activity group is absent", "mechanical_audit": mechanical,
				"required_roles_present": false})
			_failed = true
			continue
		var host := _activity_host(plan, room, activity)
		var room_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
		var floor_y := float(plan.storey_of_room(room)) * request.height + HouseGeometry.FLOOR_T
		var anchor := _activity_anchor(plan, room, activity)
		var has_activity_host := String(host.get("role", "")) == "activity_support"
		if not has_activity_host:
			_failed = true
			host = _fallback_activity_host(plan, room, activity)
		var camera := _task_wall_camera(plan, room, activity, host, anchor, floor_y, room_rect)
		if not bool(camera.get("body_clear", false)):
			_failed = true
		var camera_view := await _save_camera_view(plan, host, camera, room, activity, request,
			"%s_task_wall" % activity, size_name, case_id, output, 74.0, mechanical)
		if not has_activity_host:
			camera_view["view"] = "%s_unavailable_activity" % activity
			camera_view["activity_support_available"] = false
			camera_view["composition_status"] = "unavailable; inspect the roof-on room"
			camera_view["mechanical_composition_ok"] = false
		rows.append(camera_view)
		if int(camera_view.get("save_error", -1)) != OK:
			_failed = true
		# Keep the host portrait and add context when cooking support is on a return wall.
		var anchor_wall := HouseGeometry.backing_wall(plan, room, Rect2(anchor, Vector2.ZERO), 1000.0)
		var host_center := (Vector2(host.get("from", Vector2.ZERO)) + Vector2(host.get("to", Vector2.ZERO))) * 0.5
		if activity == "cooking" and has_activity_host and int(host.get("wall", -1)) != anchor_wall and host_center.distance_to(anchor) >= 0.8:
			var context_camera := _activity_context_camera(plan, room, host, anchor, floor_y, room_rect)
			if not bool(context_camera.get("body_clear", false)):
				_failed = true
			var context_view := await _save_camera_view(plan, host, context_camera, room, activity, request, "cooking_activity_context", size_name, case_id, output, 82.0, mechanical)
			rows.append(context_view)
			if int(context_view.get("save_error", -1)) != OK:
				_failed = true
	var timber_count := 0
	for host_variant in plan.wall_hosts:
		var timber_host: Dictionary = host_variant
		if String(timber_host.get("role", "")) != "timber_bay":
			continue
		var room := int(timber_host.get("room", -1))
		if room < 0 or room >= plan.room_count():
			_failed = true
			continue
		var room_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
		var floor_y := float(plan.storey_of_room(room)) * request.height + HouseGeometry.FLOOR_T
		var center: Vector2 = (Vector2(timber_host["from"]) + Vector2(timber_host["to"])) * 0.5
		var normal: Vector2 = Vector2(timber_host.get("normal", Vector2.ZERO)).normalized()
		var tangent := Vector2(-normal.y, normal.x)
		var desired := center + normal * 2.5 + tangent * 0.8
		var camera := _clear_camera_position(plan, room, desired, center, floor_y, room_rect,
			"__raking_timber_bay__")
		if not bool(camera.get("body_clear", false)):
			_failed = true
		var timber_view := await _save_camera_view(plan, timber_host, camera, room,
			String(timber_host.get("activity_group", "")), request, "raking_timber_bay",
			size_name, case_id, output, 62.0, mechanical)
		rows.append(timber_view)
		timber_count += 1
		if int(timber_view.get("save_error", -1)) != OK:
			_failed = true
	if timber_count == 0:
		rows.append({"case": case_id, "size": size_name,
			"request": request.to_dict(), "view": "raking_timber_bay",
			"omission_reason": "no safe clear timber bay in this plan; applicable bays reviewed in other cases",
			"timber_frame": plan.spec.timber_frame})
	# One assembled roof-off view provides spatial context for the same plan.
	roof_on.queue_free()
	await process_frame
	var cutaway: Node3D = HouseAssembler.build(plan, true)
	if cutaway == null:
		_failed = true
		rows.append({"case": case_id, "request": request.to_dict(),
			"view": "cutaway_context", "error": "cutaway assembly failed"})
		return {"rows": rows, "timber_bay_views": timber_count}
	_root3d.add_child(cutaway)
	await process_frame
	var bounds := SceneBounds.of_node(cutaway)
	var target := bounds.get_center()
	_cam.fov = 52.0
	var radius := maxf(bounds.size.length() * 0.5, 1.0)
	var distance := radius / tan(deg_to_rad(_cam.fov) * 0.5) * 1.15
	var yaw := 2.35
	var pitch := -0.5
	var direction := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	_cam.position = target + direction * distance
	_cam.look_at(target, Vector3.UP)
	_family = &"house"
	_set_shot_lighting(yaw, distance + radius)
	var context_path := output.path_join("%s_cutaway_context.jpg" % case_id)
	var context_error := await _save_image(context_path)
	if context_error != OK:
		_failed = true
	rows.append({"case": case_id, "size": size_name,
		"request": request.to_dict(), "view": "cutaway_context",
		"image": context_path, "roof_on": false, "cutaway": true,
		"mechanical_audit": mechanical,
		"mechanical_composition_ok": bool(mechanical.get("required_roles_present", false)),
		"visual_review_status": "pending_human_review",
		"camera": {"eye": _xyz(_cam.position), "target": _xyz(target),
			"fov_degrees": _cam.fov, "yaw": yaw, "pitch": pitch,
			"framing": "assembled cutaway bounds"}, "save_error": context_error})
	cutaway.queue_free()
	await process_frame
	return {"rows": rows, "timber_bay_views": timber_count}


func _save_camera_view(plan: HousePlan, host: Dictionary, camera: Dictionary,
	room: int, activity: String, request: BuildingRequest, view: String,
	size_name: String, case_id: String, output: String, fov: float,
	mechanical: Dictionary) -> Dictionary:
	var eye: Vector3 = camera["eye"]
	var target: Vector3 = camera["target"]
	_cam.fov = fov
	_cam.near = 0.05
	_cam.position = eye
	_cam.look_at(target, Vector3.UP)
	_family = &"house"
	var facing := Vector2(target.x - eye.x, target.z - eye.z).normalized()
	_set_shot_lighting(atan2(facing.x, facing.y), 18.0)
	var file_name := "%s_%s_room%d.jpg" % [case_id, view, room]
	var image_path := output.path_join(file_name)
	var save_error := await _save_image(image_path)
	var host_info := {"id": host.get("id", ""), "role": host.get("role", ""),
		"wall": host.get("wall", -1), "span": _v2(host.get("span", Vector2.ZERO)),
		"activity_group": host.get("activity_group", ""),
		"anchor_id": host.get("anchor_id", ""),
		"target_category": host.get("target_category", "")}
	var linked_items: Array[Dictionary] = []
	for piece in plan.furniture:
		if String(piece.get("wall_host_id", "")) != String(host.get("id", "")):
			continue
		linked_items.append({"key": piece.get("key", ""), "category": piece.get("cat", ""),
			"surface_anchor_id": piece.get("surface_anchor_id", ""),
			"activity_anchor_id": piece.get("activity_anchor_id", ""),
			"mount_relation": piece.get("mount_relation", ""),
			"position": _xyz(Vector3(piece.get("pos", Vector3.ZERO)))})
	host_info["linked_items"] = linked_items
	return {"case": case_id, "size": size_name, "request": request.to_dict(),
		"view": view, "image": image_path, "roof_on": true, "cutaway": false,
		"room_index": room, "room_kind": String(plan.kind_of(room)),
		"activity_group": activity, "wall_host": host_info,
		"camera": {"eye": _xyz(eye), "target": _xyz(target),
			"eye_height_above_storey_floor": 1.58,
			"fov_degrees": fov, "body_clear": camera.get("body_clear", false),
			"candidate_count": camera.get("candidate_count", 0),
			"occlusion_blockers": camera.get("occlusion_blockers", 999),
			"framing": camera.get("framing", "host-focused from human-height room interior"),
			"context_subjects": camera.get("context_subjects", []),
			"anchor_to_shelf_distance": camera.get("anchor_to_shelf_distance", -1.0)},
		"mechanical_audit": mechanical,
		"mechanical_composition_ok": bool(mechanical.get("required_roles_present", false)),
		"visual_review_status": "pending_human_review", "save_error": save_error}


func _activity_room(plan: HousePlan, group_name: String) -> int:
	for room in range(plan.room_count()):
		for piece in plan.furniture:
			if int(piece.get("room", -1)) == room \
					and String(piece.get("activity_group", "")) == group_name:
				return room
	return -1


func _activity_pieces(plan: HousePlan, room: int, group_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var bound_anchors: Dictionary = {}
	for host in plan.wall_hosts:
		if int(host.get("room", -1)) == room \
				and String(host.get("activity_group", "")) == group_name \
				and String(host.get("role", "")) == "activity_support":
			bound_anchors[String(host.get("anchor_id", ""))] = true
	for piece in plan.furniture:
		if int(piece.get("room", -1)) != room:
			continue
		var authored_group := String(piece.get("activity_group", "")) == group_name
		var derived_group := String(piece.get("activity_binding_group", "")) == group_name \
				and bound_anchors.has(String(piece.get("activity_anchor_id", "")))
		if authored_group or derived_group:
			out.append(piece)
	return out


func _activity_host(plan: HousePlan, room: int, group_name: String) -> Dictionary:
	for host in plan.wall_hosts:
		if int(host.get("room", -1)) == room \
				and String(host.get("activity_group", "")) == group_name \
				and String(host.get("role", "")) == "activity_support":
			return host
	return {"role": "missing_activity_support", "room": room,
		"activity_group": group_name, "from": Vector2.ZERO, "to": Vector2.ZERO,
		"normal": Vector2.ZERO, "span": Vector2.ZERO}


func _fallback_activity_host(plan: HousePlan, room: int, group_name: String) -> Dictionary:
	var walls := HouseGeometry.room_walls(plan, room)
	if walls.is_empty():
		return {"id": "unavailable:%d:%s" % [room, group_name], "room": room,
			"role": "unavailable_activity_support", "activity_group": group_name,
			"from": Vector2.ZERO, "to": Vector2.ZERO, "normal": Vector2.ZERO,
			"span": Vector2.ZERO, "anchor_id": ""}
	var wall: Dictionary = walls[0]
	var from: Vector2 = wall["from"]
	var to: Vector2 = wall["to"]
	var axis := Vector2.RIGHT if absf(Vector2(wall["normal"]).y) > 0.5 else Vector2.DOWN
	var lo := minf(from.dot(axis), to.dot(axis))
	var hi := maxf(from.dot(axis), to.dot(axis))
	return {"id": "unavailable:%d:%s" % [room, group_name], "room": room,
		"wall": 0, "role": "unavailable_activity_support", "activity_group": group_name,
		"from": from, "to": to, "normal": wall["normal"],
		"span": Vector2(lo, hi), "anchor_id": ""}


func _activity_anchor(plan: HousePlan, room: int, group_name: String) -> Vector2:
	var preferred := "workbench" if group_name in ["cooking", "witchwork"] else "bed"
	for piece in _activity_pieces(plan, room, group_name):
		if String(piece.get("cat", "")) == preferred:
			var preferred_position: Vector3 = piece.get("pos", Vector3.ZERO)
			return Vector2(preferred_position.x, preferred_position.z)
	var pieces := _activity_pieces(plan, room, group_name)
	var result := Vector2.ZERO
	for piece in pieces:
		var member_position: Vector3 = piece.get("pos", Vector3.ZERO)
		result += Vector2(member_position.x, member_position.z)
	return result / float(maxi(pieces.size(), 1))


func _task_wall_camera(plan: HousePlan, room: int, group_name: String,
		host: Dictionary, anchor: Vector2, floor_y: float, room_rect: Rect2) -> Dictionary:
	var center := (Vector2(host.get("from", Vector2.ZERO)) \
		+ Vector2(host.get("to", Vector2.ZERO))) * 0.5
	var normal := Vector2(host.get("normal", Vector2.ZERO)).normalized()
	if normal.length_squared() < 0.5:
		normal = (center - anchor).normalized()
	var desired := center + normal * 2.8
	var target_xz := center.lerp(anchor, 0.55) if group_name == "sleep" \
		else center.lerp(anchor, 0.3)
	var minimum_view_distance := minf(2.0,
		maxf(1.2, minf(room_rect.size.x, room_rect.size.y) * 0.60))
	var camera := _clear_camera_position(plan, room, desired, target_xz,
		floor_y, room_rect, group_name, minimum_view_distance)
	var target_height := floor_y + (1.45 if group_name == "sleep" else 1.30)
	camera["target"] = Vector3(target_xz.x, target_height, target_xz.y)
	camera["framing"] = "eye-height task context with minimum subject distance"
	camera["minimum_view_distance"] = minimum_view_distance
	return camera


func _activity_context_camera(plan: HousePlan, room: int, host: Dictionary,
		anchor: Vector2, floor_y: float, room_rect: Rect2) -> Dictionary:
	var center := (Vector2(host.get("from", Vector2.ZERO))
		+ Vector2(host.get("to", Vector2.ZERO))) * 0.5
	var normal := Vector2(host.get("normal", Vector2.ZERO)).normalized()
	var target_xz := center.lerp(anchor, 0.5)
	var desired := center + normal * 3.0
	var minimum_distance := minf(2.4, maxf(1.5, center.distance_to(anchor) * 0.65))
	var camera := _clear_camera_position(plan, room, desired, target_xz,
		floor_y, room_rect, "cooking", minimum_distance)
	camera["target"] = Vector3(target_xz.x, floor_y + 1.35, target_xz.y)
	camera["framing"] = "wide activity context centered between cooking prep anchor and return-wall shelf"
	camera["context_subjects"] = [{"name": "prep_anchor", "position": _v2(anchor)}, {"name": "activity_support_shelf", "position": _v2(center)}]
	camera["anchor_to_shelf_distance"] = center.distance_to(anchor)
	return camera

func _clear_camera_position(plan: HousePlan, room: int, desired: Vector2,
	target_xz: Vector2, floor_y: float, room_rect: Rect2,
	activity: String, minimum_view_distance := 0.0) -> Dictionary:
	var half_body := Vector2(0.26, 0.26)
	var step := 0.2
	var best_score := INF
	var best := Vector2(room_rect.get_center())
	var best_blockers := 999
	var candidate_count := 0
	var x := room_rect.position.x + half_body.x + 0.08
	while x <= room_rect.end.x - half_body.x - 0.08 + 0.001:
		var z := room_rect.position.y + half_body.y + 0.08
		while z <= room_rect.end.y - half_body.y - 0.08 + 0.001:
			var point := Vector2(x, z)
			var body := Rect2(point - half_body, half_body * 2.0)
			var clear := true
			for piece in plan.furniture:
				if int(piece.get("room", -1)) == room \
						and Rect2(piece.get("rect", Rect2())).intersects(body):
					clear = false
					break
			if clear and point.distance_to(target_xz) >= minimum_view_distance:
				candidate_count += 1
				var blockers := 0
				for piece in plan.furniture:
					if int(piece.get("room", -1)) != room \
							or String(piece.get("activity_group", "")) == activity:
						continue
					if PropCatalog.height(String(piece.get("key", ""))) < 1.0:
						continue
					if _segment_intersects_rect(point, target_xz, Rect2(piece.get("rect", Rect2()))):
						blockers += 1
				var score := float(blockers) * 100.0 + point.distance_to(desired)
				if score < best_score:
					best_score = score
					best = point
					best_blockers = blockers
			z += step
		x += step
	return {"eye": Vector3(best.x, floor_y + 1.58, best.y),
		"target": Vector3(target_xz.x, floor_y + 1.3, target_xz.y),
		"body_clear": candidate_count > 0, "candidate_count": candidate_count,
		"occlusion_blockers": best_blockers}


func _segment_intersects_rect(start: Vector2, finish: Vector2, rect: Rect2) -> bool:
	var samples := maxi(int(ceil(start.distance_to(finish) / 0.12)), 1)
	for index in range(1, samples):
		if rect.has_point(start.lerp(finish, float(index) / float(samples))):
			return true
	return false


func _mechanical_report(plan: HousePlan) -> Dictionary:
	var activity_reports: Array[Dictionary] = []
	var required_roles_present := true
	for activity in ACTIVITY_VIEWS:
		if activity == "witchwork" and plan.spec.style != &"witch_hut":
			continue
		var room := _activity_room(plan, activity)
		var required: Dictionary = {}
		match activity:
			"cooking": required = {"hearth": 1, "storage": 1, "workbench": 1,
				"bucket": 1, "cookware": 1}
			"sleep": required = {"bed": 1, "nightstand": 1, "chest": 1, "sconce": 1}
			"witchwork": required = {"hearth": 1, "workbench": 1, "shelf": 1,
				"alchemy": 2, "books": 1}
		var counts: Dictionary = {}
		if room >= 0:
			for piece in _activity_pieces(plan, room, activity):
				var category := String(piece.get("cat", ""))
				counts[category] = int(counts.get(category, 0)) + 1
		var group_roles_ok := room >= 0
		for category in required:
			if int(counts.get(String(category), 0)) < int(required[category]):
				group_roles_ok = false
		var hosts: Array[Dictionary] = []
		for host in plan.wall_hosts:
			if int(host.get("room", -1)) == room \
					and String(host.get("activity_group", "")) == activity:
				hosts.append({"id": host.get("id", ""), "role": host.get("role", ""),
					"anchor_id": host.get("anchor_id", ""),
					"target_category": host.get("target_category", ""),
					"span": _v2(host.get("span", Vector2.ZERO))})
		var support := false
		var lighting := false
		for host in hosts:
			support = support or String(host.get("role", "")) == "activity_support"
			lighting = lighting or String(host.get("role", "")) == "lighting"
		if room < 0 or not support or (activity in ["cooking", "witchwork"] and not lighting):
			group_roles_ok = false
		if not group_roles_ok:
			required_roles_present = false
		activity_reports.append({"activity_group": activity, "room_index": room,
			"room_kind": String(plan.kind_of(room)) if room >= 0 else "missing",
			"required_item_counts": required, "actual_item_counts": counts,
			"wall_hosts": hosts, "required_roles_present": group_roles_ok})
	var timber_hosts: Array[Dictionary] = []
	for host in plan.wall_hosts:
		if String(host.get("role", "")) == "timber_bay":
			timber_hosts.append({"id": host.get("id", ""), "room": host.get("room", -1),
				"span": _v2(host.get("span", Vector2.ZERO)),
				"source_host_id": host.get("source_host_id", "")})
	return {"required_roles_present": required_roles_present,
		"activity_groups": activity_reports,
		"timber_frame": plan.spec.timber_frame,
		"timber_bays": timber_hosts,
		"visual_review_status": "pending_human_review"}


func _source_snapshot() -> Dictionary:
	var paths: Array[String] = []
	for root in SOURCE_ROOTS:
		_collect_scripts(root, paths)
	for extra in ["res://assets/props/catalog.json", "res://tools/render_shots.gd",
		"res://tools/render_house_surfaces.gd"]:
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


func _v2(value: Variant) -> Array[float]:
	var vector: Vector2 = value
	return [vector.x, vector.y]


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
