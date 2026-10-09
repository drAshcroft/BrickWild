extends "res://tools/render_shots.gd"
## Supplementary real-render review of ordinary domestic hearth assemblies.
## The public house plan, roof, furniture, facade and yard props remain enabled.
func _init() -> void:
	_build_stage()
	await process_frame
	_cam.current = true
	var out := "res://artifacts/personality/resumed/domestic_hearth_roof_on_views_v1/renders"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var rows: Array[Dictionary] = []
	for style in [&"farmhouse", &"cottage", &"thatch_cottage"]:
		var spec := HouseSpec.new(7441)
		spec.style = style
		spec.width = 11.0
		spec.length = 14.0
		var plan: HousePlan = HouseGenerator.generate(spec, 7441, true)
		var breast: Dictionary = HouseGeometry.hearth_breast(plan)
		if breast.is_empty():
			push_error("missing ordinary hearth for " + String(style))
			quit(1)
			return
		var builder := HouseBuilder.new()
		builder.build(plan, true)
		var building: Node3D = HouseAssembler.build(plan, false)
		_root3d.add_child(building)
		await process_frame
		var request := {
			"kind": "house", "style": String(spec.style), "seed": 7441,
			"width": spec.width, "length": spec.length, "height": spec.height,
			"storeys": spec.storeys, "trade": String(spec.trade),
			"exterior_props": spec.exterior_props, "roof_on": true
		}
		var mouth_recess := HouseQA._hearth_opening_has_recess(plan, builder)
		var normal: Vector2 = breast.normal
		var centre: Vector2 = breast.centre
		var face: Vector2 = centre + normal * float(breast.depth) * 0.5
		var tangent := Vector2(normal.y, -normal.x)
		var eye_xz := face + normal * 2.2 + tangent * 0.45
		var hearth_eye := Vector3(eye_xz.x, 1.58, eye_xz.y)
		var hearth_target := Vector3(face.x, 0.95, face.y)
		_cam.fov = 66.0
		_cam.position = hearth_eye
		_cam.look_at(hearth_target, Vector3.UP)
		_family = &"house"
		var hearth_yaw := atan2(normal.x, normal.y)
		_set_shot_lighting(hearth_yaw, 8.0)
		var hearth_path := out.path_join(String(style) + "_hearth.jpg")
		var hearth_error: Error = await _save_review_image(hearth_path)
		rows.append({
			"request": request, "view": "hearth_portrait", "image": hearth_path,
			"save_error": int(hearth_error), "roof_on": true,
			"props_present": true, "exterior_prop_count": plan.exterior.size(),
			"yard_prop_count": plan.yard.size(), "mouth_recess": mouth_recess,
			"camera": _camera_record(hearth_eye, hearth_target, _cam.fov),
			"body_clearance": "unmeasured"
		})
		if hearth_error != OK:
			push_error("hearth image save failed: " + hearth_path)
			building.queue_free()
			quit(1)
			return

		# The paired control is the same assembled roof-on building and request.
		# It shows the whole exterior; it does not hide models or alter geometry.
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
		var exterior_path := out.path_join(String(style) + "_exterior.jpg")
		var exterior_error: Error = await _save_review_image(exterior_path)
		rows.append({
			"request": request, "view": "roof_on_exterior_control", "image": exterior_path,
			"save_error": int(exterior_error), "roof_on": true,
			"props_present": true, "exterior_prop_count": plan.exterior.size(),
			"yard_prop_count": plan.yard.size(),
			"scene_bounds": {"position": _vec3(bounds.position), "size": _vec3(bounds.size)},
			"camera": _camera_record(exterior_eye, exterior_target, _cam.fov),
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

	if rows.size() != 6:
		push_error("expected six saved views, got %d" % rows.size())
		quit(1)
		return

	var manifest_path := out.path_join("manifest.json")
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file == null:
		push_error("could not write render manifest")
		quit(1)
		return
	manifest_file.store_string(JSON.stringify({
		"purpose": "six supplementary ordinary-house hearth and roof-on exterior views",
		"renderer": "real SubViewport render; current production assemblers",
		"source_code_overrides": false,
		"clearance_claim": "unmeasured",
		"rows": rows
	}, "  "))
	print("DOMESTIC_HEARTH_RENDERS images=", rows.size(), " manifest=", manifest_path)
	quit(0)


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
