extends "res://tools/render_shots.gd"
## Matched views through the public BrickWild API. This is a visual baseline,
## not a quality check.
##
## Defaults: five established house styles, seed 1, descriptor-default scale.
## Exact request: request=path.json or request='{"schema":"brickwild.request",...}'
## Case list: cases=path.json where the file is {"cases":[{"id":"name",
## "request":{...}}, ...]}. Filter by id with select=id1,id2.

const DEFAULT_OUT := "res://artifacts/personality_baseline"
const HOUSE_STYLES: Array[StringName] = [&"cottage", &"farmhouse", &"townhouse",
	&"longhall", &"witch_hut"]
const SEED := 1
const ROOM_PRIORITY: Array[StringName] = [&"parlour", &"living_room", &"common_room",
	&"dining_room", &"mess", &"kitchen", &"hall", &"bedroom", &"guest_room",
	&"nave", &"sanctuary", &"gallery"]

var _failed := false
var _failures: Array[String] = []


func _init() -> void:
	_build_stage()
	await process_frame
	var options := _options(OS.get_cmdline_user_args())
	var source_start := _source_snapshot()
	var out_dir: String = String(options.get("out", DEFAULT_OUT)).replace("\\", "/")
	var is_windows_absolute := out_dir.length() >= 3 and out_dir.substr(1, 2) == ":/"
	if not out_dir.begins_with("res://") and not is_windows_absolute and not out_dir.begins_with("/"):
		out_dir = "res://" + out_dir.trim_prefix("/")
	var make_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	if make_err != OK:
		printerr("Could not create output directory %s: %s" % [out_dir, error_string(make_err)])
		quit(1)
		return

	var options_invalid := false
	if options.has("request") and options.has("cases"):
		_fail("Use request= or cases=, not both")
		options_invalid = true
	if (options.has("request") or options.has("cases")) and (
			options.has("family") or options.has("style") or options.has("scale") or options.has("size")):
		_fail("Full request/cases input carries its own options; omit family, style, and scale")
		options_invalid = true
	var seed := int(options.get("seed", SEED))
	var family := StringName(options.get("family", "house"))
	var style_filter := StringName(options.get("style", ""))
	var scale := String(options.get("scale", options.get("size", "default")))
	if scale not in ["small", "default", "large"]:
		_fail("Unknown scale '%s'. Choose small, default, or large." % scale)
		options_invalid = true

	var cases: Array[Dictionary] = []
	if not options_invalid:
		if options.has("request"):
			var request_data: Variant = _read_json_source(String(options["request"]))
			if request_data is Dictionary:
				cases.append_array(_parse_cases([{ "key": String(options.get("key", "request")), "request": request_data }]))
			else:
				_fail("request= must resolve to one request object")
		elif options.has("cases"):
			var cases_data: Variant = _read_json_source(String(options["cases"]))
			var rows: Array = []
			if cases_data is Array:
				rows = cases_data
			elif cases_data is Dictionary and cases_data.get("cases", null) is Array:
				rows = cases_data["cases"]
			else:
				_fail("cases= JSON must be an array or an object with a cases array")
			cases.append_array(_parse_cases(rows))
		else:
			cases = _make_selected_cases(family, style_filter, seed, scale)
	var selection := String(options.get("select", options.get("case", "")))
	if not selection.is_empty() and not cases.is_empty():
		cases = _select_cases(cases, selection)

	var rendered: Array[Dictionary] = []
	for item in cases:
		var request_to_render: BuildingRequest = item["request"]
		print("CASE_START id=%s kind=%s style=%s purpose=%s seed=%d size=%s" % [
			String(item.get("id", item["key"])), request_to_render.kind,
			request_to_render.style, request_to_render.purpose, request_to_render.seed,
			String(item.get("size", scale))])
		var row := await _render_request(request_to_render, String(item["key"]), out_dir)
		if not row.is_empty():
			row["id"] = item.get("id", item["key"])
			if item.has("size"):
				row["size"] = item["size"]
			rendered.append(row)
	if cases.is_empty() and not _failed:
		_fail("No render cases selected")
	var source_end := _source_snapshot()
	var source_changed: bool = source_start["script_sha256"] != source_end["script_sha256"] \
		or source_start["revision"] != source_end["revision"]
	var manifest := {"purpose": "visual baseline; no quality claim",
		"family_selector": String(family), "style_selector": String(style_filter),
		"seed_selector": seed, "scale_selector": scale, "output_dir": out_dir,
		"source_changed": source_changed,
		"provenance": {"revision": String(options.get("revision", source_start["revision"])),
			"change_fingerprint": String(options.get("fingerprint", source_start["script_sha256"])),
			"source_start": source_start, "source_end": source_end,
			"source_changed": source_changed},
		"failures": _failures, "cases": rendered}
	var manifest_path := out_dir + "/manifest.json"
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file == null:
		printerr("Could not write manifest: %s" % manifest_path)
		quit(1)
		return
	manifest_file.store_string(JSON.stringify(manifest, "\t", true, true) + "\n")
	var manifest_error := manifest_file.get_error()
	manifest_file.close()
	if manifest_error != OK:
		printerr("Could not finish writing manifest: %s" % error_string(manifest_error))
		quit(1)
		return
	print("Rendered %d baseline cases to %s" % [rendered.size(), out_dir])
	quit(1 if _failed else 0)


func _make_selected_cases(family: StringName, style_filter: StringName,
		seed: int, scale: String) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	if family == &"house":
		var published := _option_ids(&"house", &"style")
		var selected: Array[StringName] = []
		for style in HOUSE_STYLES:
			if published.has(style):
				selected.append(style)
		if style_filter != &"":
			if not published.has(style_filter):
				_fail("Unknown house style '%s'. Choose: %s" % [style_filter, _names(published)])
				return cases
			selected = [style_filter]
		for style in selected:
			var request := BrickWild.default_request(&"house", seed)
			request.style = style
			_apply_scale(request, _descriptor_for_request(&"house", request.style), scale)
			cases.append({"key": String(style), "id": String(style),
				"size": scale, "request": request})
		return cases

	if family == &"all" and style_filter != &"":
		_fail("Choose one family when setting style=")
		return cases
	var families: Array[StringName] = []
	if family == &"all":
		families = BrickWild.kinds()
	elif BrickWild.describe_kind(family).is_empty():
		_fail("Unknown family '%s'. Choose: %s or all." % [family, _names(BrickWild.kinds())])
		return cases
	else:
		families.append(family)
	for selected_family in families:
		var request := BrickWild.default_request(selected_family, seed)
		if style_filter != &"":
			var published := _option_ids(selected_family, &"style")
			if not published.has(style_filter):
				_fail("Unknown %s style '%s'. Choose: %s" % [selected_family, style_filter, _names(published)])
				return cases
			request.style = style_filter
		_apply_scale(request, _descriptor_for_request(selected_family, request.style), scale)
		if family == &"all" and selected_family == &"house":
			var published_house := _option_ids(&"house", &"style")
			for house_style in HOUSE_STYLES:
				if not published_house.has(house_style):
					continue
				var house_request := request.copy()
				house_request.style = house_style
				cases.append({"key": "house_" + String(house_style),
					"id": "house_" + String(house_style), "size": scale,
					"request": house_request})
		else:
			cases.append({"key": String(selected_family), "id": String(selected_family),
				"size": scale, "request": request})
	return cases


func _parse_cases(raw_cases: Array) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var seen_keys: Dictionary = {}
	for index in range(raw_cases.size()):
		var raw_case: Variant = raw_cases[index]
		if not raw_case is Dictionary:
			_fail("Case %d is not an object" % index)
			continue
		var case_data: Dictionary = raw_case
		var request_data: Variant = case_data.get("request", case_data)
		if not request_data is Dictionary:
			_fail("Case %d has no request object" % index)
			continue
		var request := BuildingRequest.from_dict(request_data)
		if not request._decode_errors.is_empty():
			_fail("Invalid request in case %d: %s" % [index, JSON.stringify(request._decode_errors)])
			continue
		var default_key := "case_%02d_%s" % [index + 1, request.kind]
		var identifier := String(case_data.get("id", case_data.get("key", default_key)))
		var key := _safe_key(String(case_data.get("key", identifier)))
		if key.is_empty():
			key = default_key
		if seen_keys.has(key):
			_fail("Duplicate case key/id after filename cleanup: %s" % key)
			continue
		seen_keys[key] = true
		var case_row := {"key": key, "id": identifier, "request": request}
		if case_data.has("size"):
			case_row["size"] = case_data["size"]
		cases.append(case_row)
	if cases.is_empty() and not _failed:
		_fail("JSON input contained no render cases")
	return cases


func _read_json_source(source: String) -> Variant:
	var stripped := source.strip_edges()
	var json_text := source
	if not stripped.begins_with("{") and not stripped.begins_with("["):
		var path := source.replace("\\", "/")
		if not path.begins_with("res://") and not path.begins_with("/") \
				and not (path.length() >= 3 and path.substr(1, 2) == ":/"):
			path = "res://" + path
		var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
		if file == null:
			_fail("Could not read JSON input: %s" % path)
			return null
		json_text = file.get_as_text()
		file.close()
	var parser := JSON.new()
	if parser.parse(json_text) != OK:
		_fail("Invalid JSON input: %s" % parser.get_error_message())
		return null
	return parser.data


func _option_ids(kind: StringName, field: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	var rows: Array = BrickWild.describe_kind(kind).get("%ss" % String(field), [])
	for raw_row in rows:
		var row: Dictionary = raw_row
		ids.append(StringName(row["id"]))
	return ids


func _select_cases(cases: Array[Dictionary], selection: String) -> Array[Dictionary]:
	var wanted: Array[String] = []
	for raw_id in selection.split(",", false):
		wanted.append(raw_id.strip_edges())
	var selected: Array[Dictionary] = []
	var found: Dictionary = {}
	for item in cases:
		var identifier := String(item.get("id", item["key"]))
		var key := String(item["key"])
		if identifier in wanted or key in wanted:
			selected.append(item)
			found[identifier] = true
			found[key] = true
	for wanted_id in wanted:
		if not found.has(wanted_id):
			_fail("Requested case id not found: %s" % wanted_id)
	return selected


func _descriptor_for_request(kind: StringName, style: StringName) -> Dictionary:
	var descriptor := BrickWild.describe_kind(kind)
	if kind == &"world":
		for option in descriptor.get("families", []):
			if StringName(option["id"]) == style:
				var family_descriptor: Dictionary = descriptor.duplicate(true)
				var envelope: Dictionary = option["envelope"]
				for field in [&"width", &"length", &"height"]:
					family_descriptor[field] = envelope[field]
				return family_descriptor
	return descriptor


func _apply_scale(request: BuildingRequest, descriptor: Dictionary, scale: String) -> void:
	for field in [&"width", &"length", &"height"]:
		if not descriptor.has(field):
			continue
		var envelope: Dictionary = descriptor[field]
		var minimum := float(envelope["min"])
		var maximum := float(envelope["max"])
		var normal := float(envelope.get("value", request.get(String(field))))
		var selected := normal
		if scale == "small":
			selected = lerpf(minimum, normal, 0.5)
		elif scale == "large":
			selected = lerpf(normal, maximum, 0.5)
		request.set(String(field), clampf(selected, minimum, maximum))
	if descriptor.has("storeys"):
		var envelope: Dictionary = descriptor["storeys"]
		var minimum := int(envelope["min"])
		var maximum := int(envelope["max"])
		var normal := int(envelope["value"])
		var selected := normal
		if scale == "small":
			selected = roundi(lerpf(minimum, normal, 0.5))
		elif scale == "large":
			selected = roundi(lerpf(normal, maximum, 0.5))
		request.storeys = clampi(selected, minimum, maximum)


func _render_request(request: BuildingRequest, key: String, out_dir: String) -> Dictionary:
	var building: GeneratedBuilding = BrickWild.generate(request)
	if not building.is_ok():
		_fail("Generation failed for %s: %s" % [key, JSON.stringify(building.errors)])
		return {}
	var placement := BrickWild.placement(building)
	if placement.is_empty() or not placement.has("bounds"):
		_fail("Placement measurement failed for %s" % key)
		return {}
	var bounds: AABB = placement["bounds"]
	var views: Array[Dictionary] = []
	var roof_on_node := BrickWild.instantiate(building, false)
	if roof_on_node == null:
		_fail("Assembly failed for %s (roof-on)" % key)
		return {}
	_root3d.add_child(roof_on_node)
	await process_frame
	var roof_bounds := _node_aabb(roof_on_node)
	var framed_bounds := roof_bounds if roof_bounds.size.length_squared() > 0.01 else bounds
	for view in [&"exterior", &"entry", &"activity"]:
		var roof_camera: Dictionary = _camera_for_view(view, building, placement, framed_bounds)
		var roof_result: Dictionary = await _capture_view(request, key, view, roof_camera,
			framed_bounds, out_dir, false)
		if not roof_result.is_empty():
			views.append(roof_result)
	roof_on_node.queue_free()
	await process_frame

	var cutaway_node := BrickWild.instantiate(building, true)
	if cutaway_node == null:
		_fail("Assembly failed for %s (cutaway)" % key)
	else:
		_root3d.add_child(cutaway_node)
		await process_frame
		var cutaway_bounds := _node_aabb(cutaway_node)
		if cutaway_bounds.size.length_squared() > 0.01:
			framed_bounds = cutaway_bounds
		var cutaway_camera: Dictionary = _camera_for_view(&"cutaway", building, placement, framed_bounds)
		var cutaway_result: Dictionary = await _capture_view(request, key, &"cutaway", cutaway_camera,
			framed_bounds, out_dir, true)
		if not cutaway_result.is_empty():
			views.append(cutaway_result)
		cutaway_node.queue_free()
		await process_frame
	if views.size() != 4:
		return {}
	return {"key": key, "request": request.to_dict(), "views": views}


func _capture_view(request: BuildingRequest, key: String, view: StringName,
		camera: Dictionary, bounds: AABB, out_dir: String, cutaway: bool) -> Dictionary:
	print("VIEW_START id=%s view=%s roof_on=%s" % [key, view, not cutaway])
	_cam.fov = float(camera.get("fov", 48.0))
	_cam.position = camera["position"]
	_cam.look_at(camera["target"], Vector3.UP)
	_family = &"house" if request.kind in [&"house", &"shop", &"hotel"] else request.kind
	var yaw := atan2(_cam.position.x - camera["target"].x,
		_cam.position.z - camera["target"].z)
	_set_shot_lighting(yaw, _cam.position.distance_to(camera["target"]) + bounds.size.length())
	var file := "%s_%s.jpg" % [_safe_key(key), view]
	var image_path := out_dir + "/" + file
	var saved: bool = await _capture_to(image_path)
	if not saved:
		return {}
	return {"view": String(view), "image": image_path, "roof_on": not cutaway,
		"cutaway": cutaway, "room": String(camera.get("room", "")),
		"camera": {"position": camera["position"], "target": camera["target"],
			"fov_degrees": _cam.fov, "pitch_degrees": _camera_pitch(camera),
			"mode": String(camera["mode"])}}


func _camera_for_view(view: StringName, building, placement: Dictionary,
		bounds: AABB) -> Dictionary:
	var centre := bounds.get_center()
	var door: Vector3 = placement.get("door", Vector3(centre.x, 1.0, bounds.position.z))
	if door == Vector3.ZERO:
		door = Vector3(centre.x, 1.0, bounds.position.z)
	if view == &"exterior":
		var target := centre
		var half_fov := _minimum_half_fov(48.0)
		var radius := maxf(bounds.size.length() * 0.5, 1.0)
		var distance := radius / sin(half_fov) * 1.12
		var yaw := PI - deg_to_rad(24.0)
		var pitch := -0.04
		var direction := Vector3(sin(yaw) * cos(pitch), -sin(pitch),
			cos(yaw) * cos(pitch))
		return {"mode": "front_three_quarter", "position": centre + direction * distance,
			"target": target, "fov": 48.0}
	if view == &"entry":
		var eye := Vector3(door.x, 1.58, door.z + 0.75)
		var target := Vector3(door.x, 1.42, door.z + 3.6)
		return {"mode": "first_person_entry_inside_threshold", "position": eye,
			"target": target, "fov": 74.0}
	if view == &"activity":
		if building.spec is ChurchSpec:
			var church: ChurchSpec = building.spec
			var nave := ChurchGeometry.nave_aabb(church)
			var eye_z := nave.position.z + minf(3.0, church.length * 0.2)
			var target_z := church.length * 0.5 - 1.0
			if church.transept:
				target_z = ChurchGeometry.crossing_center_z(church)
			elif church.apse:
				target_z = ChurchGeometry.apse_springing_z(church)
			return {"mode": "first_person_nave_axis", "position": Vector3(0.0, 1.58, eye_z),
				"target": Vector3(0.0, 1.3, target_z), "room": "nave", "fov": 74.0}
		if building.spec is TempleSpec:
			var temple: TempleSpec = building.spec
			var sight: Vector2 = TempleGeometry.sight_point(temple)
			var idol: Vector3 = TempleGeometry.idol_center(temple)
			return {"mode": "first_person_ritual_axis",
				"position": Vector3(sight.x, 1.75, sight.y + 0.2),
				"target": idol + Vector3.UP * temple.idol_height * 0.45,
				"room": "sanctuary", "fov": 74.0}
		return _activity_camera(building, bounds, door)
	var radius := maxf(bounds.size.length() * 0.5, 1.0)
	var cutaway_pitch := -0.72
	var cutaway_yaw := 0.85
	var distance := radius / sin(_minimum_half_fov(48.0)) * 1.12
	var direction := Vector3(sin(cutaway_yaw) * cos(cutaway_pitch),
		-sin(cutaway_pitch), cos(cutaway_yaw) * cos(cutaway_pitch))
	return {"mode": "aerial_cutaway", "position": centre + direction * distance,
		"target": centre, "fov": 48.0}


func _minimum_half_fov(fov_degrees: float) -> float:
	var vertical_half := deg_to_rad(fov_degrees * 0.5)
	var aspect := float(_vp.size.x) / maxf(float(_vp.size.y), 1.0)
	var horizontal_half := atan(tan(vertical_half) * aspect)
	return minf(vertical_half, horizontal_half)


func _activity_camera(building, bounds: AABB, door: Vector3) -> Dictionary:
	if building.plan is HousePlan:
		var plan: HousePlan = building.plan
		var room_index := _main_activity_room(plan)
		if room_index >= 0:
			var room: Dictionary = plan.rooms[room_index]
			var rect: Rect2 = room["rect"]
			var floor_y := float(HousePlan.record_storey(room)) * plan.spec.height
			var centroid := Vector2.ZERO
			var count := 0
			for furniture_index in plan.furniture_of(room_index):
				var piece: Dictionary = plan.furniture[furniture_index]
				if bool(piece.get("mounted", false)):
					continue
				var position: Vector3 = piece.get("pos", Vector3.ZERO)
				centroid += Vector2(position.x, position.z)
				count += 1
			if count > 0:
				centroid /= float(count)
			else:
				centroid = rect.get_center()
			var margin_x := minf(0.75, rect.size.x * 0.25)
			var margin_z := minf(0.75, rect.size.y * 0.25)
			var corners := [Vector2(rect.position.x + margin_x, rect.position.y + margin_z),
				Vector2(rect.end.x - margin_x, rect.position.y + margin_z),
				Vector2(rect.end.x - margin_x, rect.end.y - margin_z),
				Vector2(rect.position.x + margin_x, rect.end.y - margin_z)]
			var eye_2d: Vector2 = corners[0]
			for corner in corners:
				if corner.distance_squared_to(centroid) > eye_2d.distance_squared_to(centroid):
					eye_2d = corner
			var target := Vector3(centroid.x, floor_y + 1.12, centroid.y)
			var eye := Vector3(eye_2d.x, floor_y + 1.58, eye_2d.y)
			return {"mode": "first_person_activity_room", "position": eye,
				"target": target, "room": String(plan.kind_of(room_index)), "fov": 74.0}
	# No activity anchor is exposed for this representation; label the view honestly.
	var eye := Vector3(door.x, 1.58, door.z + 1.2)
	var target := Vector3(bounds.get_center().x, maxf(1.5, bounds.get_center().y * 0.45),
		bounds.get_center().z + 3.0)
	return {"mode": "front_threshold_fallback", "position": eye,
		"target": target, "fov": 74.0}


func _main_activity_room(plan: HousePlan) -> int:
	for wanted in ROOM_PRIORITY:
		for index in range(plan.rooms.size()):
			if plan.kind_of(index) == wanted and plan.storey_of_room(index) == 0:
				return index
	for index in range(plan.rooms.size()):
		if plan.storey_of_room(index) == 0:
			return index
	return -1


func _camera_pitch(camera: Dictionary) -> float:
	var delta: Vector3 = camera["target"] - camera["position"]
	return rad_to_deg(atan2(delta.y, Vector2(delta.x, delta.z).length()))


func _capture_to(path: String) -> bool:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _vp.get_texture().get_image()
	var save_error := image.save_jpg(ProjectSettings.globalize_path(path), 0.92)
	if save_error != OK:
		_fail("Could not save baseline image %s: %s" % [path, error_string(save_error)])
		return false
	print("  %s" % path)
	return true


func _options(args: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for arg in args:
		var pair := arg.split("=", false, 1)
		if pair.size() == 2:
			result[pair[0].trim_prefix("--")] = pair[1]
	return result


func _safe_key(value: String) -> String:
	var safe := value.strip_edges().to_lower()
	for character in [" ", "/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		safe = safe.replace(character, "_")
	while safe.contains("__"):
		safe = safe.replace("__", "_")
	return safe.trim_prefix("_").trim_suffix("_")


func _source_snapshot() -> Dictionary:
	var revision_lines: Array = []
	var revision_exit := OS.execute("git", ["rev-parse", "HEAD"], revision_lines)
	var revision := String(revision_lines[0]).strip_edges() if revision_exit == 0 and not revision_lines.is_empty() else "unknown"
	var paths: Array[String] = []
	for root_path in ["res://src", "res://core", "res://qa", "res://tools", "res://tests"]:
		_collect_scripts(root_path, paths)
	paths.sort()
	var fingerprints := PackedStringArray()
	for path in paths:
		fingerprints.append(path + ":" + FileAccess.get_sha256(path))
	return {"revision": revision, "script_sha256": "\n".join(fingerprints).sha256_text(),
		"script_count": paths.size()}


func _collect_scripts(path: String, paths: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file in directory.get_files():
		if file.ends_with(".gd"):
			paths.append(path.path_join(file))
	for child in directory.get_directories():
		_collect_scripts(path.path_join(child), paths)


func _fail(message: String) -> void:
	_failed = true
	_failures.append(message)
	printerr(message)


func _names(values: Array[StringName]) -> String:
	var labels: Array[String] = []
	for value in values:
		labels.append(String(value))
	return ", ".join(labels)
