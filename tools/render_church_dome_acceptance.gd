extends SceneTree

const OUT_DEFAULT := "res://artifacts/vis008/after"
const SIZE := Vector2i(1200, 1400)
const CAMERA_YAW := 0.78
const CAMERA_PITCH := -0.24
const CAMERA_FOV := 38.0
var _out := OUT_DEFAULT
var _vp: SubViewport
var _cam: Camera3D
var _stage: Node3D
var _key: DirectionalLight3D

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if String(arg).begins_with("--out="):
			_out = String(arg).trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_build_stage()
	await process_frame
	for row in _entries():
		var spec: ChurchSpec = _spec(row)
		var scene := ChurchAssembler.build(spec, false)
		_stage.add_child(scene)
		await process_frame
		var focus := Vector3(0.0,
			ChurchGeometry.dome_base_height(spec) + ChurchGeometry.PENDENTIVE_H
			+ spec.dome_drum_height * 0.5 + ChurchGeometry.dome_shell_rise(spec) * 0.36,
			ChurchGeometry.crossing_center_z(spec))
		var radius := ChurchGeometry.dome_plan_radius(spec) * 1.45
		var distance := radius / tan(deg_to_rad(CAMERA_FOV) * 0.5) * 1.08
		var dir := Vector3(sin(CAMERA_YAW) * cos(CAMERA_PITCH),
			-sin(CAMERA_PITCH), cos(CAMERA_YAW) * cos(CAMERA_PITCH))
		_cam.fov = CAMERA_FOV
		_cam.position = focus + dir * distance
		_cam.look_at(focus, Vector3.UP)
		_key.rotation.y = CAMERA_YAW
		await _save("%s_front.png" % row.key)
		_key.rotation.y = CAMERA_YAW + deg_to_rad(-70.0)
		await _save("%s_raking.png" % row.key)
		scene.queue_free()
		await process_frame
	print("Church dome acceptance renders complete: ", _out)
	quit()

func _entries() -> Array[Dictionary]:
	return [
		{"key": "hagia", "style": &"byzantine", "w": 31.0, "l": 76.0,
			"h": 40.0, "seed": 5006, "shape": &"hemisphere"},
		{"key": "florence", "style": &"renaissance", "w": 17.0, "l": 153.0,
			"h": 45.0, "seed": 5007, "shape": &"octagonal"},
	]

func _spec(row: Dictionary) -> ChurchSpec:
	var spec := ChurchSpec.new()
	spec.style = row.style
	spec.width = row.w
	spec.length = row.l
	spec.height = row.h
	ChurchGenerator.generate(spec, row.seed)
	LandmarkSuite._force_dome(spec, row.shape)
	if row.key == "hagia":
		spec.half_domes = true
		spec.exedrae = true
	else:
		spec.dome_lantern = true
		spec.transept = true
	if spec.transept and spec.transept_len <= 0.0:
		spec.transept_len = spec.width * 2.4
	return spec

func _save(file: String) -> void:
	for i in range(4):
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
	_key = DirectionalLight3D.new()
	_key.light_energy = 2.0
	_key.shadow_enabled = true
	_stage.add_child(_key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-14.0, 140.0, 0.0)
	fill.light_energy = 0.65
	_stage.add_child(fill)
	_cam = Camera3D.new()
	_cam.far = 3000.0
	_vp.add_child(_cam)
