extends "res://tools/render_shots.gd"
## Current-main assembled views for the original castle access feature.

const OUT := "res://artifacts/cas004_current/renders"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_stage()
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.has("arrival"):
		await _keep_arrival_view()
		quit()
		return
	var bridge_only := args.has("bridge")
	await _gate_views(bridge_only)
	if not bridge_only:
		await _keep_views()
	quit()


func _gate_views(bridge_only := false) -> void:
	var spec := CastleSpec.new()
	spec.style = &"crusader"
	spec.width = 90.0
	spec.length = 140.0
	spec.height = 20.0
	CastleGenerator.generate(spec, 9118)
	spec.ditch_width = 5.0
	var barbican := CastleGeometry.barbican_aabb(spec)
	var bridge := CastleGeometry.drawbridge_aabb(spec)
	if bridge.size.x <= 0.0:
		push_error("seed 9118 has no drawbridge with a 5m ditch")
		return
	var focus := Vector3(0.0, 4.5, bridge.get_center().z + 1.5)
	var shots := [
		{"name": "gate_front", "yaw": PI, "pitch": -0.16},
		{"name": "gate_raking", "yaw": PI - 0.50, "pitch": -0.24},
	]
	if bridge_only:
		shots = [{"name": "bridge_close", "yaw": PI - 0.30,
			"pitch": -0.48}]
		focus = Vector3(0.0, 1.0, bridge.get_center().z + 1.0)
	for shot in shots:
		await _shoot_scene(CastleAssembler.build(spec, false),
			OUT + "/%s.png" % shot.name,
			shot.yaw, shot.pitch, 1.0, focus, 10.0 if bridge_only else 28.0)
		print("CAS004_RENDER ", shot.name, " seed=9118 barbican=", barbican,
			" drawbridge=", bridge, " focus=", focus,
			" yaw=", shot.yaw, " pitch=", shot.pitch)


func _keep_views() -> void:
	var spec := CastleSweep.spec_at(&"norman", &"fortress", 2)
	var keep := CastleGeometry.keep_aabb(spec)
	var fore := CastleGeometry.forebuilding(spec)
	if fore.is_empty():
		push_error("Norman fortress seed 9119 has no forebuilding")
		return
	var normal: Vector2 = fore.normal
	var face := Vector2(keep.get_center().x, keep.get_center().z) \
		+ normal * minf(keep.size.x, keep.size.z) * 0.5
	var focus := Vector3(face.x + normal.x * 2.5, 2.2,
		face.y + normal.y * 2.5)
	var yaw := atan2(normal.x, normal.y)
	for shot in [
		{"name": "keep_front", "yaw": yaw, "pitch": -0.12,
			"focus": focus, "radius": 31.0},
		{"name": "keep_raking", "yaw": yaw + 0.48, "pitch": -0.10,
			"focus": focus, "radius": 31.0},
		{"name": "keep_stair_close", "yaw": yaw + 0.18, "pitch": -0.05,
			"focus": Vector3(fore.front.x, 1.4, fore.front.y + fore.run * 0.3),
			"radius": 6.0},
	]:
		await _shoot_scene(CastleAssembler.build(spec, false),
			OUT + "/%s.png" % shot.name,
			shot.yaw, shot.pitch, 1.0, shot.focus, shot.radius)
		print("CAS004_RENDER ", shot.name, " seed=9119 fore=", fore,
			" focus=", shot.focus, " yaw=", shot.yaw, " pitch=", shot.pitch)


func _keep_arrival_view() -> void:
	var spec := CastleSweep.spec_at(&"norman", &"fortress", 2)
	var fore := CastleGeometry.forebuilding(spec)
	var node := CastleAssembler.build(spec, false)
	_mesh_inst.mesh = null
	_root3d.add_child(node)
	await process_frame
	var at: Vector2 = fore.at
	var camera_at := Vector3(at.x, float(fore.height) + 1.45,
		at.y - 2.2)
	_cam.position = camera_at
	_cam.look_at(Vector3(at.x, float(fore.height) + 1.3,
		at.y + 0.5), Vector3.UP)
	_set_shot_lighting(PI)
	await _capture(OUT + "/keep_arrival.png")
	print("CAS004_RENDER keep_arrival seed=9119 camera=", camera_at,
		" door=", at)
	_root3d.remove_child(node)
	node.free()


func _capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _vp.get_texture().get_image()
	var err := image.save_png(ProjectSettings.globalize_path(file))
	print("CAS004_CAPTURE ", file, " error=", err)
