extends "res://tools/render_shots.gd"
## WLD-008 roof-on exterior and roof-off interior references.

const HALL_OUT := "res://artifacts/p1_acceptance/timber_halls"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(HALL_OUT))
	_build_stage()
	await process_frame
	var east := TimberHallGenerator.generate(&"great_hall", 8108, 34.0, 18.0, 20.0)
	await _hall_shot(east, true, "great_hall_roof_on.jpg", PI, -0.30)
	await _hall_shot(east, false, "great_hall_interior.jpg", 0.55, -1.15)
	var phoenix := TimberHallGenerator.generate(&"phoenix_pavilion", 8109, 60.0, 12.0, 14.0)
	await _hall_shot(phoenix, true, "phoenix_roof_on.jpg", PI, -0.28)
	await _hall_shot(phoenix, false, "phoenix_interior.jpg", 0.55, -1.15)
	await _hall_shot(phoenix, true, "phoenix_roof_3q.jpg", 2.35, -0.30)
	await _hall_shot(phoenix, true, "phoenix_side_windows.jpg", 2.05, -0.18)
	await _hall_shot(phoenix, true, "phoenix_water_front.jpg", PI + 0.25, -0.42)
	await _hall_shot(phoenix, false, "phoenix_entrance_witness.jpg", PI - 0.45, -0.10, true)
	print("Timber hall renders complete")
	quit()

func _hall_shot(spec: TimberHallSpec, roof: bool, file: String, yaw: float, pitch: float, witness: bool = false) -> void:
	var builder := TimberHallBuilder.new()
	var mesh := builder.build(spec, roof)
	_mesh_inst.mesh = mesh
	# the hall in what it is built of: timber, plaster, stone, grey tile (EVAL-B04)
	MaterialKit.apply(_mesh_inst, WorldAssembler.hall_palette(spec))
	var witness_node: MeshInstance3D = null
	if witness:
		var h := TimberHallGeometry.hall_rect(spec)
		witness_node = MeshInstance3D.new()
		var witness_box := BoxMesh.new()
		witness_box.size = Vector3(2.4, 3.4, 0.08)
		witness_node.mesh = witness_box
		witness_node.position = Vector3(0.0, spec.platform_h + 1.8, h.position.y + 1.1)
		var witness_mat := StandardMaterial3D.new()
		witness_mat.albedo_color = Color("fff4b0")
		witness_mat.emission_enabled = true
		witness_mat.emission = Color("ffcc66")
		witness_mat.emission_energy_multiplier = 3.0
		witness_node.set_surface_override_material(0, witness_mat)
		_root3d.add_child(witness_node)
	var aabb: AABB = mesh.get_aabb()
	var centre := aabb.get_center()
	var target := centre
	if file == "phoenix_water_front.jpg":
		var pond := TimberHallGeometry.water_rect(spec)
		var stair := TimberHallGeometry.front_stair_rect(spec)
		target = Vector3(0.0, spec.platform_h * 0.4, (pond.get_center().y + stair.get_center().y) * 0.5)
	var radius := maxf(aabb.size.length() / 2.0, 1.0)
	var zoom := 0.68 if file == "phoenix_interior.jpg" else (1.0 if file == "phoenix_water_front.jpg" else (0.52 if witness else (0.92 if file == "phoenix_side_windows.jpg" else 1.12)))
	var dist := radius / tan(deg_to_rad(_cam.fov) / 2.0) * zoom
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	_cam.position = centre + dir * dist
	_cam.look_at(target, Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _vp.get_texture().get_image()
	image.save_jpg(HALL_OUT + "/" + file, 0.92)
	if witness_node != null:
		witness_node.queue_free()
	print("  ", HALL_OUT + "/" + file)
