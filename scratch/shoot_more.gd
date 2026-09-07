extends SceneTree
## Second pass: better framing for the castle openings and the church front.

const OUT := "res://artifacts/shots"
const SIZE := Vector2i(1200, 820)

var _vp: SubViewport
var _cam: Camera3D
var _root3d: Node3D
var _mesh_inst: MeshInstance3D


func _init() -> void:
	_stage()
	await process_frame

	var spec := CastleSpec.new()
	spec.style = &"edwardian"
	spec.width = 60.0
	spec.length = 90.0
	spec.height = 18.0
	CastleGenerator.generate(spec, 9001)
	_set_mesh(CastleBuilder.new().build(spec),
		[spec.stone_color, spec.trim_color, spec.roof_color, Color("15171b")])
	var rect: Rect2 = CastleGeometry.enceinte_rect(spec, 0)
	var gate := Vector3(rect.get_center().x, 0.0, rect.position.y)
	await _look(gate + Vector3(6.0, 14.0, -46.0), gate + Vector3(0.0, 7.0, 4.0),
		"castle_gate2.jpg")
	await _look(Vector3(rect.position.x - 46.0, 30.0, rect.position.y - 46.0),
		Vector3(rect.position.x + 6.0, 12.0, rect.position.y + 6.0),
		"castle_corner.jpg")
	if spec.hall:
		var box: AABB = CastleGeometry.hall_aabb(spec)
		var c: Vector3 = box.get_center()
		await _look(Vector3(c.x + 34.0, box.size.y + 22.0, c.z - 30.0),
			Vector3(c.x, box.size.y * 0.5, c.z), "castle_hall_roof2.jpg")
	_mesh_inst.mesh = null

	var ch := ChurchSpec.new()
	ch.style = &"gothic"
	ch.width = 12.0
	ch.length = 60.0
	ch.height = 22.0
	ChurchGenerator.generate(ch, 5001)
	var cm: ArrayMesh = ChurchBuilder.new().build(ch)
	_set_mesh(cm, [ch.stone_color, ch.trim_color, ch.roof_color, Color("15171b")])
	var ca: AABB = cm.get_aabb()
	await _look(Vector3(ca.get_center().x, 16.0, ca.position.z - 46.0),
		Vector3(ca.get_center().x, 14.0, ca.position.z + 6.0), "church_west2.jpg")
	await _look(Vector3(ca.get_center().x + 44.0, 20.0, ca.get_center().z - 14.0),
		Vector3(ca.get_center().x, 13.0, ca.get_center().z), "church_nave2.jpg")
	print("done")
	quit()


func _set_mesh(mesh: ArrayMesh, cols: Array) -> void:
	_mesh_inst.mesh = mesh
	for i in range(mesh.get_surface_count()):
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[i]
		m.roughness = 0.92
		_mesh_inst.set_surface_override_material(i, m)


func _look(eye: Vector3, at: Vector3, file: String) -> void:
	_cam.position = eye
	_cam.look_at(at, Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_jpg(OUT + "/" + file, 0.92)
	print("  ", file)


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
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("6b8cb5")
	sm.sky_horizon_color = Color("cfd8e0")
	sm.ground_bottom_color = Color("5b5b55")
	sm.ground_horizon_color = Color("9aa0a0")
	sky.sky_material = sm
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
	_cam.fov = 46.0
	_cam.far = 4000.0
	_vp.add_child(_cam)
