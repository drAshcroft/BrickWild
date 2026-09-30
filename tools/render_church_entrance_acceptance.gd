extends SceneTree
## Same-seed, fixed-camera entrance route comparisons for VIS-014.

const SIZE := Vector2i(1200, 960)
var _out := "res://artifacts/vis014/after"
var _vp: SubViewport
var _stage: Node3D
var _cam: Camera3D


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--out="):
			_out = String(arg).trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_build_stage()
	await process_frame
	for mode in ["narthex", "tower"]:
		var spec := _spec(mode)
		var builder := ChurchBuilder.new()
		var mesh: ArrayMesh = builder.build(spec)
		var church := ShellAssembler.build("Church", mesh,
			[spec.stone_color, spec.trim_color, spec.roof_color,
				Color("1a1c20")], [], ChurchBuilder.SURF_ROOF,
			false, LightKit.FLAME, true)
		_stage.add_child(church)
		var front: float = ChurchGeometry.narthex_aabb(spec).position.z \
			if mode == "narthex" else ChurchGeometry.tower_aabb(spec).position.z
		_cam.fov = 38.0
		_cam.position = Vector3(2.8, 5.3, front - 18.0)
		_cam.look_at(Vector3(0.0, 2.6, front))
		await _save(mode + "_front.png")
		_cam.fov = 42.0
		_cam.position = Vector3(5.5, 4.2, front - 8.0)
		_cam.look_at(Vector3(0.0, 1.8, front))
		await _save(mode + "_raking.png")
		var route_x: float = 0.8 if mode == "narthex" else 0.0
		_cam.fov = 52.0
		_cam.position = Vector3(route_x, 1.55, -spec.length * 0.5 + 2.5)
		_cam.look_at(Vector3(route_x, 1.55, front - 2.0))
		await _save(mode + "_inside.png")
		church.queue_free()
		await process_frame
	print("Church entrance acceptance renders complete: ", _out)
	quit()


func _spec(mode: String) -> ChurchSpec:
	var spec := ChurchSpec.new()
	spec.style = &"romanesque"
	spec.width = 12.0
	spec.length = 62.0
	spec.height = 22.0
	ChurchGenerator.generate(spec, 8120 if mode == "narthex" else 8111)
	spec.narthex = mode == "narthex"
	spec.tower = mode == "tower"
	spec.west_towers = 1 if mode == "tower" else 0
	if spec.tower:
		spec.tower_width = 10.0
		spec.tower_height = 32.0
	return spec


func _save(file: String) -> void:
	for i in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var err := _vp.get_texture().get_image().save_png(_out + "/" + file)
	if err != OK:
		push_error("Could not save " + file)
	else:
		print("  ", file)


func _build_stage() -> void:
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(_vp)
	_stage = Node3D.new()
	_vp.add_child(_stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("5c7ea8")
	sky_mat.sky_horizon_color = Color("cfd8e0")
	sky_mat.ground_bottom_color = Color("52584a")
	sky_mat.ground_horizon_color = Color("97a08c")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	_stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -35, 0)
	key.light_energy = 2.3
	key.shadow_enabled = true
	_stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, 135, 0)
	fill.light_energy = 0.65
	_stage.add_child(fill)
	var interior := OmniLight3D.new()
	interior.position = Vector3(0, 2.2, -27.8)
	interior.light_energy = 1.5
	interior.omni_range = 10.0
	_stage.add_child(interior)
	_cam = Camera3D.new()
	_cam.far = 2000.0
	_vp.add_child(_cam)
