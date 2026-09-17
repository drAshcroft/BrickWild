extends SceneTree
## Close-up references for the hotel dormer seating (ROOF-AUDIT-001), written
## to artifacts/renders/hotel_dormers/.
##
## The audit measures the gap in metres; these show what the gap looked like.
## Shoot the same three views on a checkout before and after the fix and the
## floating row is unmistakable.
##
##   godot --path . --script res://tools/render_hotel_dormers.gd -- --tag=before
## Must NOT be headless: the dummy renderer writes no image.

const OUT := "res://artifacts/renders/hotel_dormers"
const SIZE := Vector2i(1400, 900)

var _vp: SubViewport
var _cam: Camera3D
var _root3d: Node3D
var _mesh_inst: MeshInstance3D


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var tag := "now"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
	_stage()
	await process_frame
	for style in [&"grand_budapest", &"alpine_palace"]:
		await _shots(style, tag)
	print("done")
	quit()


func _shots(style: StringName, tag: String) -> void:
	var spec := HotelSpec.new()
	spec.style = style
	var plan := HotelGenerator.generate(spec, 42, false)
	var hs := plan.spec as HotelSpec
	var mesh: ArrayMesh = HotelBuilder.new().build(plan)
	_set_mesh(mesh, [hs.wall_color, hs.trim_color, hs.roof_color, hs.floor_color])
	var top: float = HotelGeometry.wall_top(hs)
	var rise: float = hs.roof_rise
	print("  %s  width=%.1f length=%.1f wall_top=%.2f rise=%.2f dormers=%d"
		% [String(style), hs.width, hs.length, top, rise, hs.dormer_count])

	# Along the eave, low and close: a floating body shows daylight under it.
	await _look(Vector3(-hs.width * 0.36, top + rise * 0.30, -hs.length * 1.05),
		Vector3(hs.width * 0.12, top + rise * 0.30, -hs.length * 0.5),
		"hotel_%s_eave_%s.jpg" % [String(style), tag])
	# Three-quarter from above the front slope: the whole row at once.
	await _look(Vector3(-hs.width * 0.30, top + rise * 1.7, -hs.length * 1.35),
		Vector3(-hs.width * 0.14, top + rise * 0.35, -hs.length * 0.36),
		"hotel_%s_row_%s.jpg" % [String(style), tag])
	# Square on one dormer, to read the rear join and the glazing behind it.
	await _look(Vector3(-hs.width * 0.20, top + rise * 0.62, -hs.length * 0.86),
		Vector3(-hs.width * 0.20, top + rise * 0.34, -hs.length * 0.42),
		"hotel_%s_single_%s.jpg" % [String(style), tag])
	_mesh_inst.mesh = null


func _set_mesh(mesh: ArrayMesh, cols: Array) -> void:
	_mesh_inst.mesh = mesh
	for i in range(mesh.get_surface_count()):
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[i] if i < cols.size() else Color("888888")
		m.roughness = 0.9
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mesh_inst.set_surface_override_material(i, m)


func _look(eye: Vector3, at: Vector3, file: String) -> void:
	_cam.position = eye
	_cam.look_at(at, Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	img.save_jpg(OUT + "/" + file, 0.93)
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
	sky_mat.sky_top_color = Color("5f83b0")
	sky_mat.sky_horizon_color = Color("d4dce4")
	sky_mat.ground_bottom_color = Color("5b5b55")
	sky_mat.ground_horizon_color = Color("9aa0a0")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.05
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_root3d.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-34.0), deg_to_rad(-142.0), 0.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	_root3d.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-12.0), deg_to_rad(54.0), 0.0)
	fill.light_energy = 0.45
	_root3d.add_child(fill)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("6f7360")
	gm.roughness = 1.0
	ground.material_override = gm
	_root3d.add_child(ground)

	_mesh_inst = MeshInstance3D.new()
	_root3d.add_child(_mesh_inst)

	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.far = 4000.0
	_vp.add_child(_cam)
