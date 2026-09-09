extends SceneTree
## Church roof references: godot --path . --script res://tools/render_church_roofs.gd
const OUT := "res://artifacts/church_roofs"
const SIZE := Vector2i(1200, 820)
var _vp: SubViewport
var _cam: Camera3D
var _root3d: Node3D
var _mesh_inst: MeshInstance3D

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_stage()
	await process_frame
	for mode in ["crossing", "aisles", "tower", "dome", "onion", "octagonal"]:
		var s := ChurchSpec.new()
		s.style = &"gothic"
		ChurchGenerator.generate(s, 42)
		s.width = 10
		s.length = 26
		s.height = 12
		s.roof_pitch = 0.65
		s.transept = true
		s.transept_len = 24
		s.aisles = 2 if mode == "aisles" else 1
		s.aisle_width = 3.0
		s.crossing_tower = mode == "tower"
		s.crossing_tower_height = 25
		s.tower = false
		s.west_towers = 0
		s.dome = mode in ["dome", "onion", "octagonal"]
		s.dome_radius = 4.5
		s.dome_drum_height = 3.0
		s.dome_shape = StringName(mode) if mode in ["onion", "octagonal"] else &"hemisphere"
		s.dome_lantern = false
		s.half_domes = false
		s.roof_pitch = 0.32 if s.dome else 0.65
		s.buttresses = false
		s.flying_buttresses = false
		s.corner_turrets = false
		s.ambulatory = false
		s.radiating_chapels = 0
		s.narthex = false
		var mesh := ChurchBuilder.new().build(s)
		_set_mesh(mesh, [s.stone_color, s.trim_color, s.roof_color, Color("161a20")])
		await _look(Vector3(40, 39, -37), Vector3(0, 10, 2), mode + "_west.jpg")
		await _look(Vector3(-34, 33, 40), Vector3(0, 11, 6), mode + "_east.jpg")
		await _look(Vector3(23, 28, -4), Vector3(0, 15, 9), mode + "_joint.jpg")
	print("Church roof renders complete")
	quit()


func _set_mesh(mesh: ArrayMesh, cols: Array) -> void:
	_mesh_inst.mesh = mesh
	for i in range(mesh.get_surface_count()):
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[i] if i < cols.size() else Color("888888")
		m.roughness = 0.92
		m.cull_mode = BaseMaterial3D.CULL_BACK
		_mesh_inst.set_surface_override_material(i, m)


func _look(eye: Vector3, at: Vector3, file: String) -> void:
	_cam.position = eye
	_cam.look_at(at, Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	img.save_jpg(OUT + "/" + file, 0.92)
	print("    ", file)


func _stage() -> void:
	_vp = SubViewport.new()
	_vp.size = SIZE
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
	env.ambient_light_energy = 1.1
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_root3d.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(-128.0), 0.0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	_root3d.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-14.0), deg_to_rad(62.0), 0.0)
	fill.light_energy = 0.5
	_root3d.add_child(fill)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("6f7360")
	gm.roughness = 1.0
	ground.material_override = gm
	_root3d.add_child(ground)

	_mesh_inst = MeshInstance3D.new()
	_root3d.add_child(_mesh_inst)

	_cam = Camera3D.new()
	_cam.fov = 46.0
	_cam.far = 4000.0
	_vp.add_child(_cam)
