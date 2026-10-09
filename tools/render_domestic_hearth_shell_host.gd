extends "res://tools/render_shots.gd"
## Roof-on ordinary hearth and exterior review renders. Outputs are isolated by
## --out= so rejected/previous render evidence is never overwritten.
const CANONICAL_SIZES: Array[Dictionary] = [
	{"name": "small", "width": 7.0, "length": 9.0, "height": 2.6},
	{"name": "default", "width": 9.0, "length": 12.0, "height": 2.6},
	{"name": "large", "width": 17.0, "length": 18.0, "height": 2.8},
]
const ORIGINAL_REQUEST := {"name": "original_11x14", "width": 11.0,
	"length": 14.0, "height": 2.6}
const SOURCE_FILES: Array[String] = [
	"res://src/house/house_generator.gd",
	"res://src/house/house_builder.gd",
	"res://src/house/house_assembler.gd",
	"res://src/house/house_geometry.gd",
	"res://src/house/house_furnisher.gd",
	"res://src/house/house_furnishing_recipes.gd",
	"res://src/house/house_furnish_placement.gd",
	"res://src/house/house_furnish_score.gd",
	"res://src/house/house_plan_features.gd",
	"res://src/house/house_plan_openings.gd",
	"res://src/house/house_plan_rooms.gd",
	"res://src/house/house_spec.gd",
	"res://qa/house_furnish_programme_check.gd",
	"res://qa/house_furnish_spatial_check.gd",
	"res://qa/house_qa.gd",
]

func _init() -> void:
	_build_stage()
	await process_frame
	_cam.current = true
	var out := _output_dir()
	var output_path := ProjectSettings.globalize_path(out)
	if FileAccess.file_exists(out.path_join("manifest.json")):
		push_error("refusing to overwrite prior hearth render manifest: " + out.path_join("manifest.json"))
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_path)
	var fingerprints_start: Dictionary = _source_fingerprint()
	var rows: Array[Dictionary] = []
	var cases: Array[Dictionary] = []
	for style in [&"farmhouse", &"cottage", &"thatch_cottage"]:
		for size: Dictionary in CANONICAL_SIZES:
			cases.append({"style": String(style), "group": "canonical",
				"size": String(size["name"]), "width": float(size["width"]),
				"length": float(size["length"]), "height": float(size["height"]),
				"seed": 7441})
		cases.append({"style": String(style), "group": "original_request_control",
			"size": String(ORIGINAL_REQUEST["name"]),
			"width": float(ORIGINAL_REQUEST["width"]),
			"length": float(ORIGINAL_REQUEST["length"]),
			"height": float(ORIGINAL_REQUEST["height"]), "seed": 7441})
	if cases.size() != 12:
		push_error("expected 12 domestic hearth render requests, got %d" % cases.size())
		quit(1)
		return
	for case: Dictionary in cases:
		var spec := HouseSpec.new(int(case["seed"]))
		spec.style = StringName(case["style"])
		spec.width = float(case["width"])
		spec.length = float(case["length"])
		spec.height = float(case["height"])
		var plan: HousePlan = HouseGenerator.generate(spec, spec.seed, true)
		var breast: Dictionary = HouseGeometry.hearth_breast(plan)
		if breast.is_empty():
			push_error("missing ordinary hearth host for %s/%s seed=%d" % [
				String(case["style"]), String(case["size"]), spec.seed])
			quit(1)
			return
		var builder := HouseBuilder.new()
		builder.build(plan, true)
		var building: Node3D = HouseAssembler.build(plan, false)
		if building.find_child("DomesticHearthHeat", true, false) == null:
			push_error("assembled domestic firebox heat is missing for %s/%s" % [
				String(case["style"]), String(case["size"])])
			building.free()
			quit(1)
			return
		_root3d.add_child(building)
		await process_frame
		var request := {
			"kind": "house", "style": String(spec.style), "seed": spec.seed,
			"width": spec.width, "length": spec.length, "height": spec.height,
			"storeys": spec.storeys, "trade": String(spec.trade),
			"exterior_props": spec.exterior_props, "roof_on": true,
			"matrix_group": String(case["group"]), "size": String(case["size"])
		}
		var mouth_recess := HouseQA._hearth_opening_has_recess(plan, builder)
		var normal: Vector2 = breast["normal"]
		var centre: Vector2 = breast["centre"]
		var face: Vector2 = centre + normal * float(breast["depth"]) * 0.5
		var tangent := Vector2(normal.y, -normal.x)
		var hearth_eye_xz := face + normal * 2.2 + tangent * 0.45
		var hearth_eye := Vector3(hearth_eye_xz.x, 1.58, hearth_eye_xz.y)
		var hearth_target := Vector3(face.x, 0.95, face.y)
		_cam.fov = 66.0
		_cam.position = hearth_eye
		_cam.look_at(hearth_target, Vector3.UP)
		_family = &"house"
		var hearth_yaw := atan2(normal.x, normal.y)
		_set_shot_lighting(hearth_yaw, 8.0)
		var case_name := "%s_%s_%d" % [String(case["style"]),
			String(case["size"]), spec.seed]
		var hearth_path := out.path_join(case_name + "_hearth.jpg")
		var hearth_error: Error = await _save_review_image(hearth_path)
		rows.append({
			"request": request, "view": "hearth_portrait", "image": hearth_path,
			"save_error": int(hearth_error), "roof_on": true,
			"props_present": true, "exterior_prop_count": plan.exterior.size(),
			"yard_prop_count": plan.yard.size(), "mouth_recess": mouth_recess,
			"host_kind": String(plan.hearth.get("host_kind", "")),
			"ordinary_hearth_model_rows": _hearth_model_rows(plan),
			"pot_1_rows": _pot_rows(plan),
			"camera": _camera_record(hearth_eye, hearth_target, _cam.fov),
			"viewport": {"width": _vp.size.x, "height": _vp.size.y},
			"body_clearance": "unmeasured"
		})
		if hearth_error != OK:
			push_error("hearth image save failed: " + hearth_path)
			building.queue_free()
			quit(1)
			return

		var bounds: AABB = SceneBounds.of_node(building)
		var exterior_target := bounds.get_center()
		var diagonal := Vector3(1.0, 0.52, 1.25).normalized()
		var radius := maxf(bounds.size.length() * 0.5, 1.0)
		_cam.fov = 48.0
		var distance := radius / tan(deg_to_rad(_cam.fov) * 0.5) * 1.12
		var exterior_eye := exterior_target + diagonal * distance
		_cam.position = exterior_eye
		_cam.look_at(exterior_target, Vector3.UP)
		var exterior_yaw := atan2(-diagonal.x, -diagonal.z)
		_set_shot_lighting(exterior_yaw, distance + radius)
		var exterior_path := out.path_join(case_name + "_exterior.jpg")
		var exterior_error: Error = await _save_review_image(exterior_path)
		rows.append({
			"request": request, "view": "roof_on_exterior_control", "image": exterior_path,
			"save_error": int(exterior_error), "roof_on": true,
			"props_present": true, "exterior_prop_count": plan.exterior.size(),
			"yard_prop_count": plan.yard.size(),
			"scene_bounds": {"position": _vec3(bounds.position), "size": _vec3(bounds.size)},
			"camera": _camera_record(exterior_eye, exterior_target, _cam.fov),
			"viewport": {"width": _vp.size.x, "height": _vp.size.y},
			"body_clearance": "unmeasured"
		})
		if exterior_error != OK:
			push_error("exterior image save failed: " + exterior_path)
			building.queue_free()
			quit(1)
			return
		_root3d.remove_child(building)
		building.free()
		await process_frame

	if rows.size() != 24:
		push_error("expected 24 saved views from 12 requests, got %d" % rows.size())
		quit(1)
		return
	var fingerprints_end: Dictionary = _source_fingerprint()
	if fingerprints_start != fingerprints_end:
		push_error("source changed during renderer run")
		quit(1)
		return
	var manifest_path := out.path_join("manifest.json")
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file == null:
		push_error("could not write render manifest")
		quit(1)
		return
	manifest_file.store_string(JSON.stringify({
		"purpose": "9 canonical domestic hearth requests plus the 3 original 11x14 requests; each has hearth and roof-on exterior views",
		"renderer": "real SubViewport render; current production assemblers",
		"source_code_overrides": false,
		"source_fingerprints_start": fingerprints_start,
		"source_fingerprints_end": fingerprints_end,
		"clearance_claim": "unmeasured",
		"request_count": 12, "image_count": 24, "rows": rows
	}, "  "))
	print("DOMESTIC_HEARTH_RENDERS requests=12 images=24 manifest=", manifest_path)
	quit(0)


func _output_dir() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out=") and not arg.trim_prefix("--out=").is_empty():
			return arg.trim_prefix("--out=")
	return "res://artifacts/personality/resumed/domestic_hearth_shell_host_v1/renders_shell_host_v1"


func _source_fingerprint() -> Dictionary:
	var out: Dictionary = {}
	for path in SOURCE_FILES:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return {}
		var hashing := HashingContext.new()
		if hashing.start(HashingContext.HASH_SHA256) != OK:
			return {}
		hashing.update(file.get_buffer(file.get_length()))
		out[path] = hashing.finish().hex_encode()
	return out


func _hearth_model_rows(plan: HousePlan) -> int:
	var count := 0
	for row: Dictionary in plan.furniture:
		if PropCatalog.category(String(row.get("key", ""))) == "hearth":
			count += 1
	return count


func _pot_rows(plan: HousePlan) -> int:
	var count := 0
	for row: Dictionary in plan.furniture:
		if String(row.get("key", "")) == "Pot_1":
			count += 1
	return count


func _camera_record(eye: Vector3, target: Vector3, fov: float) -> Dictionary:
	return {"position": _vec3(eye), "target": _vec3(target), "fov_degrees": fov}


func _vec3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _save_review_image(path: String) -> Error:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered: Image = _vp.get_texture().get_image()
	return rendered.save_jpg(ProjectSettings.globalize_path(path), 0.94)


