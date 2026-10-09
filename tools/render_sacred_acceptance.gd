extends "res://tools/render_shots.gd"
## Bounded non-headless reference renders through the public BrickWild API.
## Example: --family=church --size=all --style=gothic --view=all
## Run without --headless; this renders assembled scenes, including props.

const OUT_DEFAULT := "res://artifacts/personality/sacred_acceptance/renders"
const MATRIX_PATH := "res://tests/fixtures/sacred_structure_requests.json"
const BATCHES_PATH := "res://tests/fixtures/sacred_structure_batches.json"
const CHURCH_STYLES: Array[StringName] = [&"romanesque", &"gothic", &"byzantine",
	&"nordic_stave", &"renaissance", &"russian"]
const TEMPLE_FORMS: Array[StringName] = [&"basilica", &"pylon", &"ziggurat", &"rotunda"]
const SIZE_CASES := {
	"small": {"church": Vector3(8.0, 14.0, 7.0),
		"temple": Vector3(18.0, 24.0, 8.0)},
	"default": {"church": Vector3(10.0, 22.0, 12.0),
		"temple": Vector3(26.0, 44.0, 12.0)},
	"large": {"church": Vector3(16.0, 48.0, 24.0),
		"temple": Vector3(48.0, 80.0, 20.0)},
}
const SEEDS := [1, 8102, 21325]
const SIZE_ORDER := ["small", "default", "large"]
const CASE_BATCH_SIZE := 10
const FULL_REQUEST_COUNT := 234
const MAX_CASES_PER_INVOCATION := 10
const VIEWS: Array[String] = ["exterior", "axis", "cutaway"]

var _out_dir := OUT_DEFAULT
var _family_filter := "all"
var _size_filter := "default"
var _seed_filter := "all"
var _style_filter := ""
var _case_filter := ""
var _batch_filter := -1
var _view_filter := "all"
var _cult_filter := &"all"
var _records: Array[Dictionary] = []
var _errors: Array[String] = []
var _source_start: Dictionary = {}
var _source_end: Dictionary = {}


func _init() -> void:
	if not _parse_args(OS.get_cmdline_user_args()):
		return
	if not _validate_frozen_matrix():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_absolute_out())
	_build_stage()
	await process_frame
	_source_start = _source_snapshot()
	var selected_cases := _selected_cases()
	if _family_filter in ["all", "church"]:
		await _render_churches(selected_cases)
	if _family_filter in ["all", "temple"]:
		await _render_temples(selected_cases)
	_source_end = _source_snapshot()
	_write_manifest()
	print("Sacred public-API renders complete: ", _out_dir)
	if not _errors.is_empty() or _records.size() != _planned_image_count() \
			or _source_start.get("sha256", "") != _source_end.get("sha256", ""):
		quit(1)
		return
	quit(0)


func _parse_args(args: PackedStringArray) -> bool:
	for arg in args:
		var text := String(arg)
		if text.begins_with("--family="):
			_family_filter = text.trim_prefix("--family=")
		elif text.begins_with("--size="):
			_size_filter = text.trim_prefix("--size=")
		elif text.begins_with("--seed="):
			_seed_filter = text.trim_prefix("--seed=")
		elif text.begins_with("--style="):
			_style_filter = text.trim_prefix("--style=")
		elif text.begins_with("--case="):
			_case_filter = text.trim_prefix("--case=")
		elif text.begins_with("--batch="):
			var batch_text := text.trim_prefix("--batch=")
			if not batch_text.is_valid_int():
				push_error("--batch requires a zero-based integer")
				quit(2)
				return false
			_batch_filter = int(batch_text)
		elif text.begins_with("--view="):
			_view_filter = text.trim_prefix("--view=")
		elif text.begins_with("--cult="):
			_cult_filter = StringName(text.trim_prefix("--cult="))
		elif text.begins_with("--out="):
			_out_dir = text.trim_prefix("--out=")
	if _cult_filter not in [&"all", &"blood", &"void", &"flame", &"bone", &"serpent"]:
		push_error("--cult must select all or a published cult")
		quit(2)
		return false
	if _family_filter not in ["all", "church", "temple"]:
		push_error("--family must be all, church or temple")
		quit(2)
		return false
	if _size_filter != "all" and not SIZE_CASES.has(_size_filter):
		push_error("--size must be all, small, default or large")
		quit(2)
		return false
	if _seed_filter != "all":
		var chosen_seeds := _seed_filter.split(",", false)
		var seen_seeds: Dictionary = {}
		for value in chosen_seeds:
			if seen_seeds.has(value):
				push_error("--seed values must be unique")
				quit(2)
				return false
			seen_seeds[value] = true
		for value in chosen_seeds:
			if not value.is_valid_int() or not SEEDS.has(int(value)):
				push_error("--seed must be all or a comma-separated subset of 1,8102,21325")
				quit(2)
				return false
	if _batch_filter < -1 or _batch_filter >= int(ceil(float(FULL_REQUEST_COUNT) / CASE_BATCH_SIZE)):
		push_error("--batch must be omitted or a zero-based index from 0 through 23")
		quit(2)
		return false
	if _view_filter != "all":
		if _view_filter.is_empty():
			push_error("--view must select at least one view")
			quit(2)
			return false
		var chosen_views := _view_filter.split(",", false)
		var seen_views: Dictionary = {}
		for view in chosen_views:
			if seen_views.has(view):
				push_error("--view values must be unique")
				quit(2)
				return false
			seen_views[view] = true
		for view in chosen_views:
			if view not in VIEWS:
				push_error("--view must be all or a comma-separated subset of exterior,axis,cutaway")
				quit(2)
				return false
	if _cult_filter != &"all" and _cult_filter not in TempleSpec.CULTS:
		push_error("--cult is not a published TempleSpec cult")
		quit(2)
		return false
	if _style_filter != "" and _style_filter != "all":
		var has_valid_style := false
		for selected in _style_filter.split(",", false):
			var name := StringName(selected)
			if _family_filter in ["all", "church"] and name in CHURCH_STYLES:
				has_valid_style = true
			if _family_filter in ["all", "temple"] and name in TEMPLE_FORMS:
				has_valid_style = true
		if not has_valid_style:
			push_error("--style has no published style/form for the selected family")
			quit(2)
			return false
	if not _case_filter.is_empty():
		for case_id in _case_filter.split(",", false):
			if not _all_case_ids().has(case_id):
				push_error("--case is not a published sacred request ID: " + case_id)
				quit(2)
				return false
	var selected_cases := _selected_cases()
	if selected_cases.is_empty():
		push_error("Selectors matched no sacred requests")
		quit(2)
		return false
	var default_profile := _family_filter == "all" and _size_filter == "default" \
		and _seed_filter == "all" and _style_filter.is_empty() and _case_filter.is_empty() \
		and _batch_filter < 0
	if selected_cases.size() > MAX_CASES_PER_INVOCATION and _batch_filter < 0 \
			and not default_profile:
		push_error("Selectors over ten requests require --batch=0..23")
		quit(2)
		return false
	return true


func _planned_request_count() -> int:
	return _selected_cases().size()


func _planned_image_count() -> int:
	return _planned_request_count() * _selected_views().size()


func _all_cases() -> Array[Dictionary]:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MATRIX_PATH))
	if not parsed is Dictionary or not parsed.get("cases", []) is Array:
		return []
	var out: Array[Dictionary] = []
	for raw in parsed["cases"]:
		if raw is Dictionary:
			out.append(raw)
	return out


func _validate_frozen_matrix() -> bool:
	var cases := _all_cases()
	var batch_doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(BATCHES_PATH))
	if cases.size() != FULL_REQUEST_COUNT or not batch_doc is Dictionary:
		push_error("frozen sacred matrix or batch map is missing or malformed")
		return false
	var ids: Dictionary = {}
	var coverage_counts := {"church": 0, "blood": 0, "additional": 0}
	var tuples: Dictionary = {}
	for case in cases:
		var case_id := String(case.get("id", ""))
		var family := String(case.get("family", ""))
		var style := String(case.get("style", ""))
		var size_name := String(case.get("size", ""))
		var seed_value := int(case.get("seed", -1))
		var request_data: Dictionary = case.get("request", {})
		if case_id.is_empty() or ids.has(case_id) or request_data.is_empty():
			push_error("frozen sacred matrix contains duplicate or malformed request")
			return false
		if family not in ["church", "temple"] or size_name not in SIZE_ORDER \
				or not SEEDS.has(seed_value):
			push_error("sacred request has an unknown family, size or seed")
			return false
		var targets: Array[StringName] = CHURCH_STYLES if family == "church" else TEMPLE_FORMS
		if not targets.has(StringName(style)) or String(request_data.get("kind", "")) != family \
				or String(request_data.get("style", "")) != style \
				or String(request_data.get("seed", "")) != str(seed_value):
			push_error("sacred request does not match its family/style/seed key")
			return false
		var expected_dims: Vector3 = SIZE_CASES[size_name][family]
		if not is_equal_approx(float(request_data.get("width", -1.0)), expected_dims.x) \
				or not is_equal_approx(float(request_data.get("length", -1.0)), expected_dims.y) \
				or not is_equal_approx(float(request_data.get("height", -1.0)), expected_dims.z):
			push_error("sacred request dimensions drifted from frozen size profile")
			return false
		var cult := String(request_data.get("cult", "")) if family == "temple" else ""
		if family == "temple" and (cult not in ["blood", "void", "flame", "bone", "serpent"] \
				or String(request_data.get("form", "")) != style):
			push_error("temple request is missing a published form or cult")
			return false
		var key := "%s/%s/%s/%s/%d" % [family, style, cult, size_name, seed_value]
		if tuples.has(key):
			push_error("sacred matrix repeats a semantic request")
			return false
		tuples[key] = true
		var expected_id := "%s/%s/%s/%d" % [family, style, size_name, seed_value]
		var coverage := String(case.get("coverage", ""))
		if family == "temple" and cult != "blood":
			expected_id = "%s/%s/%s/%s/%d" % [family, style, cult, size_name, seed_value]
			coverage_counts["additional"] += 1
			if coverage != "additional_cult":
				push_error("non-blood temple request is not marked as added cult coverage")
				return false
		elif family == "church":
			coverage_counts["church"] += 1
			if coverage != "original_church_geometry_case":
				push_error("original church request lost its coverage marker")
				return false
		else:
			coverage_counts["blood"] += 1
			if coverage != "original_blood_control":
				push_error("original blood request lost its coverage marker")
				return false
		if case_id != expected_id:
			push_error("sacred request id changed: " + case_id)
			return false
		ids[case_id] = true
	if coverage_counts != {"church": 54, "blood": 36, "additional": 144}:
		push_error("sacred coverage must remain 90 expanded core-grid requests plus 144 added non-blood cult requests")
		return false
	var seen: Dictionary = {}
	var batches: Array = batch_doc.get("batches", [])
	if batches.size() != int(ceil(float(FULL_REQUEST_COUNT) / MAX_CASES_PER_INVOCATION)):
		push_error("frozen sacred batch count is incorrect")
		return false
	for batch in batches:
		var members: Array = batch.get("case_ids", [])
		if members.is_empty() or members.size() > MAX_CASES_PER_INVOCATION:
			push_error("sacred render batch is empty or exceeds selector bound")
			return false
		for value in members:
			var batch_id := String(value)
			if not ids.has(batch_id) or seen.has(batch_id):
				push_error("sacred batch map contains unknown or repeated request")
				return false
			seen[batch_id] = true
	if seen.size() != ids.size():
		push_error("sacred batches omit one or more frozen requests")
		return false
	return true

func _all_case_ids() -> Array[String]:
	var ids: Array[String] = []
	for case in _all_cases():
		ids.append(String(case["id"]))
	return ids


func _selected_cases() -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for case in _all_cases():
		var family := String(case["family"])
		var target: StringName = case["style"]
		if _family_filter != "all" and family != _family_filter: continue
		if family == "temple" and _cult_filter != &"all" \
				and StringName(case["request"].get("cult", "blood")) != _cult_filter: continue
		if _size_filter != "all" and String(case["size"]) != _size_filter: continue
		if _seed_filter != "all" and not _seed_filter.split(",", false).has(str(case["seed"])): continue
		if not _selected_style(target): continue
		if not _case_filter.is_empty() and not _case_filter.split(",", false).has(String(case["id"])): continue
		filtered.append(case)
	if _batch_filter < 0:
		return filtered
	var batch_doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BATCHES_PATH))
	var batch_rows: Array = batch_doc.get("batches", [])
	if _batch_filter >= batch_rows.size():
		return []
	var wanted: Dictionary = {}
	for case_id in batch_rows[_batch_filter].get("case_ids", []):
		wanted[String(case_id)] = true
	var out: Array[Dictionary] = []
	for case in filtered:
		if wanted.has(String(case["id"])):
			out.append(case)
	return out


func _selected_views() -> Array[String]:
	if _view_filter == "all":
		return VIEWS.duplicate()
	var out: Array[String] = []
	for view in _view_filter.split(",", false):
		out.append(view)
	return out


func _render_churches(cases: Array[Dictionary]) -> void:
	for case in cases:
		if String(case["family"]) != "church":
			continue
		var size_name := String(case["size"])
		var style: StringName = case["style"]
		var seed := int(case["seed"])
		var req_data: Dictionary = case["request"]
		var dims := Vector3(float(req_data["width"]), float(req_data["length"]), float(req_data["height"]))
		var request := BuildingRequest.church(seed, style, dims.x, dims.y, dims.z)
		var made := BrickWild.generate(request)
		if not made.is_ok():
			var reason := "public church generation failed: %s: %s" % [case["id"], str(made.errors)]
			push_error(reason)
			_errors.append(reason)
			continue
		for view in _selected_views():
			await _render_subject(made, "church", String(style), size_name, view, String(case["id"]))


func _render_temples(cases: Array[Dictionary]) -> void:
	for case in cases:
		if String(case["family"]) != "temple":
			continue
		var size_name := String(case["size"])
		var form: StringName = case["style"]
		var seed := int(case["seed"])
		var req_data: Dictionary = case["request"]
		var dims := Vector3(float(req_data["width"]), float(req_data["length"]), float(req_data["height"]))
		var request := BuildingRequest.temple(seed, form, StringName(req_data.get("cult", _cult_filter)),
			dims.x, dims.y, dims.z)
		var made := BrickWild.generate(request)
		if not made.is_ok():
			var reason := "public temple generation failed: %s: %s" % [case["id"], str(made.errors)]
			push_error(reason)
			_errors.append(reason)
			continue
		for view in _selected_views():
			await _render_subject(made, "temple", String(form), size_name, view, String(case["id"]))


func _selected_style(style: StringName) -> bool:
	if _style_filter.is_empty() or _style_filter == "all":
		return true
	for selected in _style_filter.split(",", false):
		if selected == String(style):
			return true
	return false


func _render_subject(made: GeneratedBuilding, family: String, style: String,
		size_name: String, view: String, case_id: String) -> void:
	var cutaway: bool = view == "cutaway"
	var scene: Node3D = BrickWild.instantiate(made, cutaway, false)
	if scene == null:
		var reason := "public scene instantiation failed: %s: %s/%s/%s" % [case_id, family, style, view]
		push_error(reason)
		_errors.append(reason)
		return
	_mesh_inst.mesh = null
	_root3d.add_child(scene)
	await process_frame
	var bounds: AABB = SceneBounds.of_node(scene)
	var centre := bounds.get_center()
	var radius := maxf(bounds.size.length() * 0.5, 1.0)
	_cam.fov = 48.0
	var yaw := 2.45
	var focus := centre
	var reach := radius * 3.0
	var camera_record: Dictionary = {"roof_on": not cutaway,
		"entrance_connected": false, "body_clear": false}
	if family == "church":
		_family = &"church"
		var spec: ChurchSpec = made.spec
		match view:
			"axis":
				var station: Dictionary = _church_axis_station(spec)
				if not bool(station.get("ok", false)):
					var reason := "no entrance-connected church nave-axis camera station: " + case_id
					push_error(reason)
					_errors.append(reason)
					_root3d.remove_child(scene)
					scene.free()
					return
				var station_xz: Vector2 = station["position"]
				var floor_y: float = float(station["floor_y"])
				_cam.fov = 62.0
				_cam.position = Vector3(station_xz.x, floor_y + 1.65, station_xz.y)
				focus = Vector3(0.0, floor_y + 2.0, spec.length * 0.32)
				camera_record = {"roof_on": true, "entrance_connected": true,
					"body_clear": false, "clearance_status": "not measured against shell and props", "floor_y": floor_y,
					"station_xz": [station_xz.x, station_xz.y],
					"route_distance": float(station["route_distance"]),
					"body_radius": TempleGeometry.PERSON_RADIUS}
			"cutaway":
				_cam.fov = 52.0
				var cutaway_direction := Vector3(sin(yaw), 1.0, cos(yaw)).normalized()
				var cutaway_distance: float = radius / sin(deg_to_rad(_cam.fov * 0.5)) * 1.12
				_cam.position = centre + cutaway_direction * cutaway_distance
				focus = centre
			_:
				var exterior_direction := Vector3(sin(yaw), 0.45, cos(yaw)).normalized()
				var exterior_distance: float = radius / sin(deg_to_rad(_cam.fov * 0.5)) * 1.12
				_cam.position = centre + exterior_direction * exterior_distance
		_cam.look_at(focus, Vector3.UP)
		reach = _cam.position.distance_to(focus) + radius
	else:
		var spec: TempleSpec = made.spec
		_family = &"temple_dark" if view in ["axis", "cutaway"] else &"temple_dusk"
		var idol: Vector3 = TempleGeometry.idol_center(spec)
		match view:
			"axis":
				var station: Dictionary = _temple_axis_station(spec)
				if not bool(station.get("ok", false)):
					var reason := "no entrance-connected clear temple axis camera station: " + case_id
					push_error(reason)
					_errors.append(reason)
					_root3d.remove_child(scene)
					scene.free()
					return
				var eye: Vector2 = station["position"]
				var floor_y: float = float(station["floor_y"])
				_cam.fov = 60.0
				_cam.position = Vector3(eye.x, floor_y + 1.65, eye.y)
				focus = Vector3(idol.x, idol.y + spec.idol_height * 0.55,
					idol.z - spec.idol_width * 0.5 - 0.05)
				camera_record = {"roof_on": true, "entrance_connected": true,
					"body_clear": false, "clearance_status": "not measured against shell and props", "floor_y": floor_y,
					"station_xz": [eye.x, eye.y],
					"route_distance": float(station["route_distance"]),
					"body_radius": TempleGeometry.PERSON_RADIUS}
			"cutaway":
				var extent: Rect2 = TempleGeometry.plan_extent(spec)
				var span := maxf(extent.size.x, extent.size.y)
				_cam.fov = 55.0
				_cam.position = Vector3(span * 0.4, span * 0.8,
					extent.position.y - span * 0.45)
				focus = Vector3(0.0, spec.height * 0.25, extent.get_center().y)
			_:
				_cam.position = centre + Vector3(sin(yaw) * radius * 1.8,
					radius * 0.65, cos(yaw) * radius * 1.8)
		_cam.look_at(focus, Vector3.UP)
		reach = _cam.position.distance_to(focus) + radius
	camera_record["camera_position"] = [_cam.position.x, _cam.position.y, _cam.position.z]
	camera_record["focus_position"] = [focus.x, focus.y, focus.z]
	camera_record["cutaway"] = cutaway
	var key_yaw := atan2(-_cam.global_transform.basis.z.x,
		-_cam.global_transform.basis.z.z)
	_set_shot_lighting(key_yaw, reach)
	var cult_token := "_%s" % String(made.request.purpose) if family == "temple" else ""
	var filename := "%s/%s/%s%s_%s_%s.jpg" % [family, size_name, style, cult_token, view, str(made.request.seed)]
	if not await _capture_to(filename):
		_errors.append("image save failed: %s: %s" % [case_id, filename])
		_root3d.remove_child(scene)
		scene.free()
		return
	_records.append({"kind": family, "style_or_form": style, "size": size_name,
		"seed": made.request.seed, "request": made.request.to_dict(), "view": view,
		"path": filename, "case_id": case_id, "camera": camera_record,
		"render_path": "BrickWild.generate + BrickWild.instantiate"})
	_root3d.remove_child(scene)
	scene.free()


func _church_axis_station(spec: ChurchSpec) -> Dictionary:
	var floor_y: float = ChurchGeometry.podium_height(spec)
	var floors: Array[Rect2] = ChurchGeometry.floor_rects(spec)
	if floors.is_empty() and floor_y > 0.0:
		var podium: AABB = ChurchGeometry.podium_aabb(spec)
		floors.append(Rect2(Vector2(podium.position.x, podium.position.z),
			Vector2(podium.size.x, podium.size.z)))
	if floors.is_empty():
		return {"ok": false}
	if floor_y <= 0.0:
		floor_y = ChurchGeometry.FLOOR_LIFT
	var bounds: Rect2 = floors[0]
	for index in range(1, floors.size()):
		bounds = bounds.merge(floors[index])
	var grid := WalkGrid.new()
	grid.setup(bounds.grow(1.0), TempleGeometry.NAV_CELL)
	for floor_rect in floors:
		grid.add_floor(floor_rect, floor_y)
	grid.build(TempleGeometry.PERSON_RADIUS)
	var doors: Array[Dictionary] = ChurchGeometry.west_door_layout(spec)
	if doors.is_empty():
		return {"ok": false}
	var door_z: float = -spec.length * 0.5 - ChurchGeometry.OPENING_EPS
	if spec.tower and spec.west_towers == 1:
		door_z = -spec.length * 0.5 + ChurchBuilder.TOWER_EMBED \
			- spec.tower_width - ChurchGeometry.OPENING_EPS
	var door_x: float = float(doors[0].get("x", 0.0))
	var entry := Vector2(door_x, door_z + ChurchBuilder.NAVE_WALL_T + 0.45)
	if not grid.flood_from(entry, 1.2):
		return {"ok": false}
	var nave: AABB = ChurchGeometry.nave_aabb(spec)
	# Select a centerline station well past the west facade and tower vestibule.
	# This records floor connectivity only; shell/prop capsule clearance remains
	# explicitly unmeasured until a triangle-level body probe exists.
	for fraction in [0.34, 0.43, 0.28, 0.52]:
		var candidate := Vector2(0.0, nave.position.z + nave.size.z * float(fraction))
		var cell: Vector2i = grid.cell_of(candidate)
		var station: Vector2 = grid.world_of(cell.x, cell.y)
		var route_distance: float = grid.distance_to(station, 0.0)
		if route_distance < INF:
			return {"ok": true, "position": station, "floor_y": floor_y,
				"route_distance": route_distance, "body_clear": false,
				"clearance_status": "not measured against shell and props"}
	return {"ok": false}

func _temple_axis_station(spec: TempleSpec) -> Dictionary:
	var floors: Array[Rect2] = TempleGeometry.floor_rects(spec)
	if floors.is_empty():
		return {"ok": false}
	var bounds: Rect2 = TempleGeometry.plan_extent(spec)
	var forecourt: Rect2 = TempleGeometry.forecourt_rect(spec)
	if forecourt.size.x > 0.0 and forecourt.size.y > 0.0:
		bounds = bounds.merge(forecourt)
	var floor_y: float = -TempleGeometry.FLOOR_T * 0.5 + 0.001 \
		+ TempleGeometry.FLOOR_T * 0.5
	var grid := WalkGrid.new()
	grid.setup(bounds.grow(1.0), TempleGeometry.NAV_CELL)
	for floor_rect in floors:
		grid.add_floor(floor_rect, floor_y)
	for obstacle in TempleGeometry.obstacle_rects(spec):
		grid.add_obstacle(obstacle)
	grid.build(TempleGeometry.PERSON_RADIUS)
	var entry: Vector2 = TempleGeometry.entry_point(spec)
	if not grid.flood_from(entry, 1.2):
		return {"ok": false}
	var candidates: Array[Vector2] = []
	if spec.form == &"ziggurat":
		var sight: Vector2 = TempleGeometry.sight_point(spec)
		var reached_station := _nearest_reached_station(grid, sight,
			TempleGeometry.PERSON_RADIUS + TempleGeometry.NAV_CELL)
		if not reached_station.is_empty():
			return reached_station
	else:
		var offsets: Array[float] = [0.5, 0.8, 1.1, 1.5, 2.0]
		for offset in offsets:
			candidates.append(entry + Vector2(0.0, offset))
	for candidate in candidates:
		var cell: Vector2i = grid.cell_of(candidate)
		var station: Vector2 = grid.world_of(cell.x, cell.y)
		var route_distance: float = grid.distance_to(station, 0.0)
		if route_distance < INF:
			return {"ok": true, "position": station, "floor_y": grid.level_at(station),
				"route_distance": route_distance}
	return {"ok": false}


## Pick a cell the existing body-eroded WalkGrid says is both standable and
## reached. This keeps the ziggurat sight station inside paving at a human
## body margin when the nominal sight point itself is too close to its edge.
func _nearest_reached_station(grid: WalkGrid, target: Vector2,
		max_distance: float) -> Dictionary:
	var center: Vector2i = grid.cell_of(target)
	var radius: int = maxi(int(ceil(max_distance / grid.cell)), 1)
	var best := Vector2.ZERO
	var best_distance := INF
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			var x: int = center.x + dx
			var z: int = center.y + dz
			if grid.at(grid._walk, x, z) == 0 or grid.at(grid._seen, x, z) == 0:
				continue
			var station: Vector2 = grid.world_of(x, z)
			var distance: float = station.distance_to(target)
			if distance > max_distance or distance >= best_distance:
				continue
			best = station
			best_distance = distance
	if best_distance == INF:
		return {}
	return {"ok": true, "position": best, "floor_y": grid.level_at(best),
		"route_distance": grid.distance_to(best, 0.0), "station_offset": best_distance}


func _capture_to(relative_file: String) -> bool:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var target := _absolute_out().path_join(relative_file)
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var err: Error = _vp.get_texture().get_image().save_jpg(target, 0.92)
	if err != OK:
		push_error("Could not save sacred reference: " + target)
		return false
	print("  ", target)
	return true


func _absolute_out() -> String:
	return ProjectSettings.globalize_path(_out_dir) if _out_dir.begins_with("res://") else _out_dir


func _source_snapshot() -> Dictionary:
	var paths: Array[String] = []
	for root_path in ["res://src", "res://core", "res://qa", "res://tests"]:
		_collect_scripts(root_path, paths)
	for extra in ["res://project.godot", "res://tools/render_shots.gd",
			"res://tools/render_sacred_acceptance.gd", MATRIX_PATH, BATCHES_PATH]:
		if FileAccess.file_exists(extra):
			paths.append(extra)
	paths.sort()
	var items := PackedStringArray()
	for path in paths:
		items.append(path + ":" + FileAccess.get_sha256(path))
	return {"file_count": items.size(), "sha256": "\n".join(items).sha256_text(),
		"files": items}


func _collect_scripts(path: String, paths: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file in directory.get_files():
		if file.ends_with(".gd"):
			paths.append(path.path_join(file))
	for child in directory.get_directories():
		_collect_scripts(path.path_join(child), paths)

func _write_manifest() -> void:
	var revision := "unknown"
	var output: Array = []
	var code: int = OS.execute("git", ["rev-parse", "HEAD"], output)
	if code == 0 and not output.is_empty():
		revision = String(output[0]).strip_edges()
	var selected := _selected_cases()
	var expected_requests := selected.size()
	var expected_images := _planned_image_count()
	var rendered_cases: Dictionary = {}
	for record in _records:
		var case_id := String(record.get("case_id", ""))
		if not rendered_cases.has(case_id):
			rendered_cases[case_id] = []
		(rendered_cases[case_id] as Array).append(String(record.get("view", "")))
	var case_statuses: Array[Dictionary] = []
	for case in selected:
		var case_id := String(case["id"])
		var views: Array = rendered_cases.get(case_id, [])
		var status := "rendered" if views.size() == _selected_views().size() else "incomplete"
		for error in _errors:
			if String(error).contains(case_id):
				status = "failed"
				break
		var details := {"id": case_id, "family": case["family"],
			"style_or_form": case["style"], "size": case["size"],
			"seed": case["seed"], "status": status,
			"expected_views": _selected_views(), "rendered_views": views}
		if String(case["family"]) == "temple":
			details["cult"] = String(case["request"].get("cult", "blood"))
		case_statuses.append(details)
	var rendered_requests := 0
	for row in case_statuses:
		if row["status"] == "rendered":
			rendered_requests += 1
	var source_changed: bool = _source_start.get("sha256", "") != _source_end.get("sha256", "")
	var complete := _errors.is_empty() and not source_changed \
		and rendered_requests == expected_requests and _records.size() == expected_images
	var payload := {"base_revision": revision, "working_tree": true,
		"source_fingerprint_start": _source_start, "source_fingerprint_end": _source_end,
		"source_changed_during_render": source_changed,
		"render_path": "BrickWild.generate + BrickWild.instantiate",
		"matrix": {"target_styles_and_forms": 10, "sizes": SIZE_ORDER,
			"seeds": SEEDS, "legacy_original_requests": 30, "legacy_original_images": 90,
			"expanded_core_grid_requests": 90, "additional_full_cult_requests": 144,
			"full_requests": FULL_REQUEST_COUNT,
			"temple_forms": TEMPLE_FORMS, "temple_cults": ["blood", "void", "flame", "bone", "serpent"],
			"views": VIEWS, "full_images": FULL_REQUEST_COUNT * VIEWS.size()},
		"expected_requests": expected_requests, "rendered_requests": rendered_requests,
		"expected_images": expected_images, "rendered_images": _records.size(),
		"complete": complete,
		"acceptance_status": "pending_visual_review", "accepted_images": 0,
		"errors": _errors,
		"utc": Time.get_datetime_string_from_system(true),
		"filters": {"family": _family_filter, "size": _size_filter,
			"seed": _seed_filter, "style": _style_filter, "case": _case_filter,
			"batch": _batch_filter, "batch_size": CASE_BATCH_SIZE,
			"view": _view_filter, "cult": String(_cult_filter)},
		"cases": case_statuses, "images": _records}
	var file := FileAccess.open(_absolute_out().path_join("manifest.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t", true, true) + "\n")
		file.close()
