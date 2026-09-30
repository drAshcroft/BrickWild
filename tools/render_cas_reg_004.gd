extends SceneTree

const SHOT := Vector2i(1100, 760)
const OUT_DIR := "res://artifacts/cas_reg_004/renders"
const FRAME_CENTER := Vector3(0.0, 10.0, 0.0)
const FRAME_RADIUS := 65.0

var _vp: SubViewport
var _root3d: Node3D
var _camera: Camera3D
var _mesh_instance: MeshInstance3D
var _key: DirectionalLight3D
var _fill: DirectionalLight3D


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_build_stage()
	await process_frame
	var args := OS.get_cmdline_user_args()
	var label := args[0] if not args.is_empty() else "after"
	var spec := CastleSpec.new()
	spec.style = &"bavarian"
	spec.width = 120.0
	spec.length = 40.0
	spec.height = 20.0
	spec.plan_override = &"ridge"
	CastleGenerator.generate(spec, 8805)
	var mesh := CastleBuilder.new().build(spec)
	for view in ["front", "raking"]:
		var yaw := PI if view == "front" else 2.3
		var pitch := -0.20 if view == "front" else -0.27
		await _shoot(mesh, spec, "%s_%s.jpg" % [label, view], yaw, pitch)
	print("rendered seed=8805 label=", label, " center=", FRAME_CENTER,
		" radius=", FRAME_RADIUS, " cameras=front,raking")
	quit()


func _build_stage() -> void:
	_vp = SubViewport.new()
	_vp.size = SHOT
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(_vp)
	_root3d = Node3D.new()
	_vp.add_child(_root3d)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("6b8cb5")
	sky_mat.sky_horizon_color = Color("cfd8e0")
	sky_mat.ground_bottom_color = Color("5b5b55")
	sky_mat.ground_horizon_color = Color("9aa0a0")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	_root3d.add_child(world)
	_key = DirectionalLight3D.new()
	_key.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(-131.0), 0.0)
	_key.light_energy = 1.8
	_key.shadow_enabled = true
	_root3d.add_child(_key)
	_fill = DirectionalLight3D.new()
	_fill.rotation = Vector3(deg_to_rad(-16.0), deg_to_rad(58.0), 0.0)
	_fill.light_energy = 0.45
	_root3d.add_child(_fill)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(900.0, 900.0)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("6f7360")
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	_root3d.add_child(ground)
	_mesh_instance = MeshInstance3D.new()
	_root3d.add_child(_mesh_instance)
	_camera = Camera3D.new()
	_camera.fov = 48.0
	_camera.far = 4000.0
	_vp.add_child(_camera)


func _shoot(mesh: ArrayMesh, spec: CastleSpec, file: String,
		yaw: float, pitch: float) -> void:
	_mesh_instance.mesh = mesh
	var colors: Array[Color] = [spec.stone_color, spec.trim_color,
		spec.roof_color, Color("15171b")]
	for i in range(mesh.get_surface_count()):
		var material := StandardMaterial3D.new()
		material.albedo_color = colors[i]
		material.roughness = 0.92
		_mesh_instance.set_surface_override_material(i, material)
	var dist := FRAME_RADIUS / tan(deg_to_rad(_camera.fov) / 2.0) * 1.12
	var direction := Vector3(sin(yaw) * cos(pitch), -sin(pitch),
		cos(yaw) * cos(pitch))
	_camera.position = FRAME_CENTER + direction * dist
	_camera.look_at(FRAME_CENTER, Vector3.UP)
	_key.rotation = Vector3(deg_to_rad(-30.0), yaw + deg_to_rad(-62.0), 0.0)
	_fill.rotation = Vector3(deg_to_rad(-18.0), yaw + deg_to_rad(120.0), 0.0)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _vp.get_texture().get_image()
	var result := image.save_jpg(OUT_DIR + "/" + file, 0.94)
	print("  ", file, " save_error=", result, " yaw=", yaw,
		" pitch=", pitch, " camera=", _camera.position)
