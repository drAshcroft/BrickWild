extends SceneTree
## Native production-assembly review renders for the frozen Gothic chapel passage requests.
## Run without --headless. Example:
## godot --path . --script res://artifacts/personality/resumed/restart35_chapel_passage_renderer_20261009/render_chapel_passage_review.gd -- --out=res://visualqa/styles/church/gothic/renders/chapel_passage_review_20261009_01

const VIEW_SIZE := Vector2i(1600, 1000)
const GROUP_PATH := "groups/gothic_chevet/requests"
const DEFAULT_OUT := "res://visualqa/styles/church/gothic/renders/chapel_passage_review_20261009_01"
const SOURCE_PATHS := [
	"res://src/church/church_builder.gd",
	"res://src/church/church_geometry.gd",
	"res://src/church/church_assembler.gd",
	"res://src/church/church_furnisher.gd",
	"res://src/church/church_generator.gd",
	"res://core/shell_assembler.gd",
	"res://tests/chapel_passage_test.gd",
	"res://tests/suites/dressing_suite.gd",
	"res://src/church/church_spec.gd",
	"res://core/material_kit.gd",
	"res://core/mesh_kit.gd",
	"res://core/mass_builder.gd",
	"res://assets/props/catalog.json",
	"res://tests/suites/landmark_suite.gd",
	"res://tools/render_chapel_passage_review.gd",
	"res://tests/fixtures/chapel_review_camera_fixture.gd",
	"res://tests/chapel_review_camera_test.gd",
]
const ChapelCameraFixture = preload("res://tests/fixtures/chapel_review_camera_fixture.gd")

var _out: String = DEFAULT_OUT
var _vp: SubViewport
var _stage: Node3D
var _camera: Camera3D
var _key: DirectionalLight3D
var _manifest: Dictionary = {}
var _failures: Array[String] = []


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--out="):
			_out = String(arg).trim_prefix("--out=")
	if not _valid_output_path(_out):
		push_error("Chapel review renderer only writes below visualqa/styles/church/gothic/renders/")
		quit(2)
		return
	var absolute_out: String = ProjectSettings.globalize_path(_out)
	if DirAccess.dir_exists_absolute(absolute_out) or FileAccess.file_exists(absolute_out):
		push_error("Refusing to overwrite existing Chapel render run: " + _out)
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(absolute_out) != OK:
		push_error("Could not create Chapel render run: " + _out)
		quit(2)
		return

	var cases: Array[Dictionary] = _frozen_requests()
	var source_hashes_start: Dictionary = _source_fingerprint()
	_manifest = {
		"schema": "brickwild.chapel_passage_review_render",
		"schema_version": 1,
		"started_utc": Time.get_datetime_string_from_system(true),
		"finished_utc": "",
		"renderer": "Godot SubViewport with roof-on and chapel-detail cutaway ChurchAssembler builds",
		"headless": DisplayServer.get_name() == "headless",
		"props_enabled": true,
		"cutaway": true,
		"cutaway_scope": "chapel detail view only; context and ambulatory views retain the roof",
		"frozen_fixture": "tests/chapel_passage_test.gd",
		"live_fixture_path": "tests/chapel_passage_test.gd",
		"camera_fixture": "tests/fixtures/chapel_review_camera_fixture.gd",
		"camera_test": "tests/chapel_review_camera_test.gd",
		"frozen_fixture_sha256": source_hashes_start.get("res://tests/chapel_passage_test.gd", ""),
		"source_hashes_start": source_hashes_start,
		"source_hashes_end": {},
		"output_root": _out,
		"unique_output_refused_if_existing": true,
		"cases": [],
		"failures": _failures,
	}
	for request in cases:
		_manifest["cases"].append({
			"key": request["key"],
			"selection_reason": request["reason"],
			"spec": _spec_snapshot(request["spec"]),
			"spec_seed": int(request["spec"].seed),
			"views": [],
			"actual_prop_instances": 0,
		})
	_write_manifest()
	if cases.is_empty():
		_failures.append("no frozen Chapel request could be assembled")
		_finish(1)
		return
	if DisplayServer.get_name() == "headless":
		_failures.append("renderer was launched headless; no valid native image can be claimed")
		_finish(1)
		return

	_build_stage()
	await process_frame
	for index in range(cases.size()):
		await _render_case(cases[index], index)
	_finish(1 if not _failures.is_empty() else 0)


func _valid_output_path(path: String) -> bool:
	var prefix := "res://visualqa/styles/church/gothic/renders/"
	return path.begins_with(prefix) and not path.contains("..") \
		and not path.ends_with("/")


func _frozen_requests() -> Array[Dictionary]:
	var requests: Array[Dictionary] = []
	var chartres := ChurchSpec.new()
	chartres.style = &"gothic"
	chartres.width = 16.4
	chartres.length = 130.0
	chartres.height = 37.5
	ChurchGenerator.generate(chartres, 5003)
	LandmarkSuite._force_features("chartres", chartres)
	requests.append({"key": "chartres_seed5003", "reason": "exact frozen LandmarkSuite Chartres chapel-passage case", "spec": chartres})

	var generated := ChurchSpec.new()
	generated.style = &"gothic"
	generated.width = 12.0
	generated.length = 80.0
	generated.height = 24.0
	ChurchGenerator.generate(generated, 5001)
	if not _is_frozen_generated_case(generated):
		_failures.append("seed 5001 no longer produces the frozen ambulatory chevet request")
	else:
		requests.append({"key": "generated_gothic_seed5001", "reason": "exact frozen generated ambulatory chevet request", "spec": generated})

	var seam_count := _crossed_seam_count(chartres) + _crossed_seam_count(generated)
	if seam_count == 0:
		var small: ChurchSpec = _generated_small_multi_panel_case()
		if small == null:
			_failures.append("no frozen case crosses an annular seam and the fixture's small-radius fallback was not found")
		else:
			requests.append({"key": "small_radius_multi_panel_seed%d" % int(small.seed),
				"reason": "fixture fallback because neither main request crosses a panel seam",
				"spec": small})
	return requests


func _is_frozen_generated_case(spec: ChurchSpec) -> bool:
	return spec.apse and spec.ambulatory and spec.radiating_chapels > 0 \
		and spec.chapel_arrangement == &"chevet" and spec.chapel_radius >= 0.5


func _generated_small_multi_panel_case() -> ChurchSpec:
	for seed in range(5000, 5400):
		var candidate := ChurchSpec.new()
		candidate.style = &"gothic"
		candidate.width = 8.0
		candidate.length = 24.0
		candidate.height = 12.0
		ChurchGenerator.generate(candidate, seed)
		if not candidate.apse or not candidate.ambulatory \
				or candidate.radiating_chapels <= 0 \
				or candidate.chapel_arrangement != &"chevet":
			continue
		if _crossed_seam_count(candidate) > 0:
			return candidate
	return null


func _crossed_seam_count(spec: ChurchSpec) -> int:
	var wall_inner: float = ChurchGeometry.ambulatory_radius(spec) - ChurchBuilder.NAVE_WALL_T
	var crossed := 0
	for index in range(spec.radiating_chapels):
		var theta: float = PI * 0.5 - ChurchGeometry.chapel_angle(spec, index)
		var half: float = ChurchGeometry.chapel_mouth_half_angle(spec, index, wall_inner)
		for panel in range(1, 20):
			var seam: float = PI * float(panel) / 20.0
			if seam > theta - half + 0.00001 and seam < theta + half - 0.00001:
				crossed += 1
	return crossed


func _render_case(request: Dictionary, case_index: int) -> void:
	var spec: ChurchSpec = request["spec"]
	var assembled: Node3D = ChurchAssembler.build(spec, false)
	_stage.add_child(assembled)
	await process_frame
	var row: Dictionary = _manifest["cases"][case_index]
	var dressing := assembled.get_node_or_null("Dressing") as Node3D
	if dressing != null:
		row["actual_prop_instances"] = dressing.get_child_count()
	# The assembler above uses the real production prop placement and instancing path.
	# The explicit metadata records actual instantiated Dressing children.
	var context := ChapelCameraFixture.context_view(spec)
	var context_target: Vector3 = context["target"]
	var context_eye: Vector3 = context["eye"]
	await _capture(request, row, "views", "east_3q_context.png", context_eye,
		context_target, 46.0, "eastern apse, covered ambulatory, and radiating chapel context")

	var chapel_index := 0
	var ambulatory: Dictionary = ChapelCameraFixture.ambulatory_view(spec, chapel_index)
	var ambulatory_eye: Vector3 = ambulatory["eye"]
	var ambulatory_target: Vector3 = ambulatory["target"]
	await _capture(request, row, "rooms", "ambulatory_eye_toward_chapel_mouth.png",
		ambulatory_eye, ambulatory_target, 72.0,
		"roof-on eye-level view from ambulatory through the actual mouth",
		ambulatory["clearance"])

	await process_frame
	assembled.queue_free()
	await process_frame
	var measured_placements: Array[Dictionary] = ChurchFurnisher.dress(spec)
	var cutaway_assembled: Node3D = ChurchAssembler.build(spec, true)
	_stage.add_child(cutaway_assembled)
	await process_frame
	var camera_wall_clipped: bool = _clip_chapel_camera_side_wall(cutaway_assembled,
		spec, chapel_index)
	var cutaway_view: Dictionary = ChapelCameraFixture.chapel_cutaway_view(spec,
		chapel_index, measured_placements)
	var detail_clearance: Dictionary = cutaway_view["clearance"]
	detail_clearance["camera_side_wall_clipped"] = camera_wall_clipped
	var detail_eye: Vector3 = cutaway_view["eye"]
	var detail_target: Vector3 = cutaway_view["target"]
	if not bool(detail_clearance.get("cutaway_view", false)) or not camera_wall_clipped:
		_fail("chapel detail camera lacks a real camera-side wall clip for %s" % String(request["key"]))
	await _capture(request, row, "rooms", "chapel_cutaway_altar_benches.png",
		detail_eye, detail_target,
		float(detail_clearance["camera_fov_degrees"]),
		String(cutaway_view.get("purpose", "elevated chapel detail cutaway")),
		detail_clearance)
	await process_frame
	cutaway_assembled.queue_free()
	await process_frame


func _clip_chapel_camera_side_wall(assembly: Node3D, spec: ChurchSpec,
		chapel_index: int) -> bool:
	var shell := assembly.get_node_or_null("Shell") as MeshInstance3D
	if shell == null or shell.mesh == null:
		return false
	var stone_surface := -1
	for surface in range(shell.mesh.get_surface_count()):
		var surface_name: String = String(shell.mesh.surface_get_name(surface))
		var slot := surface
		if surface_name.begins_with("material_slot:"):
			slot = int(surface_name.trim_prefix("material_slot:"))
		if slot == ChurchBuilder.SURF_STONE:
			stone_surface = surface
			break
	if stone_surface < 0:
		return false
	var angle: float = ChurchGeometry.chapel_angle(spec, chapel_index)
	var center: Vector3 = ChurchGeometry.chapel_center(spec, chapel_index)
	var floor_y: float = ChurchGeometry.FLOOR_LIFT - ChurchGeometry.FLOOR_T * 0.5
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform vec3 chapel_center;
uniform vec3 chapel_tangent;
uniform float chapel_radius;
uniform float chapel_floor_y;
uniform float chapel_body_height;
uniform vec3 stone_color;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 delta = world_position - chapel_center;
	float side = abs(dot(delta, chapel_tangent));
	float radial = length(delta.xz);
	bool camera_side_wall = side > chapel_radius * 0.06
		&& radial < chapel_radius * 1.65
		&& world_position.y > chapel_floor_y + 0.14
		&& world_position.y < chapel_floor_y + chapel_body_height + 0.25;
	if (camera_side_wall) discard;
	ALBEDO = stone_color;
	ROUGHNESS = 0.88;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("chapel_center", center)
	material.set_shader_parameter("chapel_tangent",
		Vector3(cos(angle), 0.0, -sin(angle)))
	material.set_shader_parameter("chapel_radius", spec.chapel_radius)
	material.set_shader_parameter("chapel_floor_y", floor_y)
	material.set_shader_parameter("chapel_body_height",
		ChurchGeometry.chapel_body_height(spec, chapel_index))
	var active_material := shell.get_active_material(stone_surface) as StandardMaterial3D
	var stone_color: Color = active_material.albedo_color if active_material != null \
		else spec.stone_color
	material.set_shader_parameter("stone_color", Vector3(stone_color.r,
		stone_color.g, stone_color.b))
	shell.set_surface_override_material(stone_surface, material)
	return true


func _capture(request: Dictionary, row: Dictionary, group: String, filename: String,
		eye: Vector3, target: Vector3, fov: float, purpose: String,
		clearance: Dictionary = {}) -> void:
	var relative := "%s/%s/%s/%s" % [GROUP_PATH, String(request["key"]), group, filename]
	var absolute := ProjectSettings.globalize_path(_out + "/" + relative)
	var folder := absolute.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		_failures.append("could not create image directory: " + folder)
		return
	if FileAccess.file_exists(absolute):
		_failures.append("refusing to overwrite existing image: " + absolute)
		return
	_camera.fov = fov
	_camera.position = eye
	_camera.look_at(target, Vector3.UP)
	for frame in range(4):
		await process_frame
		await RenderingServer.frame_post_draw
	var image: Image = _vp.get_texture().get_image()
	var error: Error = image.save_png(absolute)
	if error != OK:
		_failures.append("image save failed (%s): %s" % [error_string(error), absolute])
	else:
		var cutaway: bool = bool(clearance.get("cutaway_view", false))
		row["views"].append({
			"file": relative,
			"purpose": purpose,
			"camera": {"eye": _vector3_json(eye), "target": _vector3_json(target), "fov_degrees": fov},
			"size": [VIEW_SIZE.x, VIEW_SIZE.y],
			"roof_on": not cutaway,
			"cutaway": cutaway,
			"camera_side_wall_clipped": bool(clearance.get("camera_side_wall_clipped", false)),
			"actual_production_assembly": true,
			"geometry_clearance": clearance,
		})
		print(relative)


func _build_stage() -> void:
	_vp = SubViewport.new()
	_vp.size = VIEW_SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(_vp)
	_stage = Node3D.new()
	_vp.add_child(_stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("5c7ea8")
	sky_material.sky_horizon_color = Color("cfd8e0")
	sky_material.ground_bottom_color = Color("52584a")
	sky_material.ground_horizon_color = Color("97a08c")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 1.25
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	_stage.add_child(world)
	_key = DirectionalLight3D.new()
	_key.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	_key.light_energy = 2.0
	_key.shadow_enabled = true
	_stage.add_child(_key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-17.0, 142.0, 0.0)
	fill.light_energy = 0.55
	_stage.add_child(fill)
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(500.0, 500.0)
	ground.mesh = ground_mesh
	ground.position.y = -0.075
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("707464")
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	_stage.add_child(ground)
	_camera = Camera3D.new()
	_camera.far = 3000.0
	_vp.add_child(_camera)


func _source_fingerprint() -> Dictionary:
	var out: Dictionary = {}
	for path in SOURCE_PATHS:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			out[path] = "MISSING"
			_failures.append("source hash could not open " + path)
			continue
		var hashing := HashingContext.new()
		if hashing.start(HashingContext.HASH_SHA256) != OK:
			out[path] = "HASH_ERROR"
			_failures.append("source hash could not start for " + path)
			file.close()
			continue
		hashing.update(file.get_buffer(file.get_length()))
		out[path] = hashing.finish().hex_encode()
		file.close()
	return out


func _spec_snapshot(spec: ChurchSpec) -> Dictionary:
	var out: Dictionary = {}
	var omitted_objects: Array[String] = []
	for property in spec.get_property_list():
		var name: String = String(property["name"])
		if name in ["resource_name", "resource_path", "script"]:
			continue
		var value: Variant = spec.get(name)
		if typeof(value) == TYPE_OBJECT:
			omitted_objects.append(name)
			continue
		out[name] = _json_safe(value)
	out["_omitted_object_fields"] = omitted_objects
	return out


func _json_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING_NAME:
			return String(value)
		TYPE_VECTOR2:
			return {"x": value.x, "y": value.y}
		TYPE_VECTOR3:
			return {"x": value.x, "y": value.y, "z": value.z}
		TYPE_COLOR:
			return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_ARRAY:
			var converted: Array = []
			for item in value:
				converted.append(_json_safe(item))
			return converted
		TYPE_DICTIONARY:
			var converted_dict: Dictionary = {}
			for key in value:
				converted_dict[String(key)] = _json_safe(value[key])
			return converted_dict
		TYPE_PACKED_STRING_ARRAY:
			return Array(value)
		TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
			return Array(value)
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			return Array(value)
		_:
			return value


func _vector3_json(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func _write_manifest() -> void:
	var file := FileAccess.open(_out + "/manifest.json", FileAccess.WRITE)
	if file == null:
		_failures.append("could not open run manifest for writing")
		return
	_manifest["failures"] = _failures
	file.store_string(JSON.stringify(_manifest, "\t") + "\n")
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		_failures.append("manifest write failed: " + error_string(error))


func _finish(exit_code: int) -> void:
	_manifest["finished_utc"] = Time.get_datetime_string_from_system(true)
	_manifest["source_hashes_end"] = _source_fingerprint()
	_manifest["status"] = "fail" if exit_code != 0 else "rendered"
	_manifest["image_count"] = 0
	for request in _manifest.get("cases", []):
		_manifest["image_count"] += request.get("views", []).size()
	for path in _manifest.get("source_hashes_start", {}):
		if _manifest["source_hashes_start"][path] != _manifest["source_hashes_end"].get(path, ""):
			_failures.append("source changed during render: " + path)
	if not _failures.is_empty():
		exit_code = 1
		_manifest["status"] = "fail"
	_write_manifest()
	print("Chapel review renderer: ", _manifest["image_count"], " images; ",
		_failures.size(), " failures; ", _out)
	quit(exit_code)


func _failures_has(text: String) -> bool:
	for failure in _failures:
		if failure.contains(text):
			return true
	return false


func _fail(message: String) -> void:
	_failures.append(message)
