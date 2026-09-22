extends SceneTree
## INT-018 non-headless render gate. The first two frames show daylight/sky
## through actual emitted openings; the third shows the court from inside with
## the roof removed, useful for checking normals, doors and windows together.
##
##   godot --path . --script res://tools/render_house_sky_openings.gd

const OUT := "res://artifacts/renders/sky_openings"
const SIZE := Vector2i(1280, 860)

var _vp: SubViewport
var _cam: Camera3D
var _root3d: Node3D
var _mesh_inst: MeshInstance3D


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_stage()
	await process_frame
	await _domus()
	await _oculus()
	await _domus_sky()
	print("done")
	quit()


func _domus() -> void:
	var plan: HousePlan = CourtSuite.courtyard(17.0, 15.0, 2818)
	var court := Rect2(plan.courts[0]["rect"])
	plan.roof_openings = [{"id": "atrium_compluvium", "kind": &"compluvium",
		"storey": 0, "room": 0, "rect": court}]
	var builder := HouseBuilder.new()
	var mesh := builder.build(plan)
	_set_mesh(mesh, [Color("c8b89a"), Color("dfd2b8"), Color("8a7157"), Color("706653")])
	var c := Vector3(court.get_center().x, 0.0, court.get_center().y)
	var top := mesh.get_aabb().position.y + mesh.get_aabb().size.y
	await _look(c + Vector3(0.0, top + 15.0, 0.2),
		c + Vector3(0.0, 0.0, 0.0), "domus_overhead.png")


func _oculus() -> void:
	var spec := HouseSpec.new(2919)
	spec.width = 10.0
	spec.length = 14.0
	spec.height = 2.8
	spec.storeys = 1
	spec.room_count = 1
	spec.program = [&"hall"]
	spec.roof_type = &"gable"
	spec.roof_pitch = 1.0
	spec.chimney = false
	spec.porch = false
	spec.dormers = false
	var plan := HousePlanner.plan(spec)
	plan.roof_openings = [{"id": "hall_oculus", "kind": &"oculus",
		"storey": 0, "room": 0, "rect": Rect2(-1.5, -1.5, 3.0, 3.0)}]
	var builder := HouseBuilder.new()
	var mesh := builder.build(plan)
	_set_mesh(mesh, [Color("c4b391"), Color("e1d4b9"), Color("826a51"), Color("6e6557")])
	var box := mesh.get_aabb()
	var c := box.get_center()
	await _look(c + Vector3(11.0, 18.0, 11.0),
		Vector3(c.x, box.position.y + box.size.y * 0.38, c.z), "oculus_overhead.png")
	# The overhead image proves the roof silhouette; the under-roof image proves
	# the aperture is not painted on a solid ceiling by showing real sky behind
	# the cut from the room below.
	await _look(Vector3(0.0, 1.35, 0.0), Vector3(0.0, 4.6, 0.0),
		"oculus_sky.png")


func _domus_sky() -> void:
	var plan: HousePlan = CourtSuite.courtyard(17.0, 15.0, 4818)
	var court := Rect2(plan.courts[0]["rect"])
	plan.roof_openings = [{"id": "atrium_compluvium", "kind": &"compluvium",
		"storey": 0, "room": 0, "rect": court}]
	var builder := HouseBuilder.new()
	var mesh := builder.build(plan)
	_set_mesh(mesh, [Color("c8b89a"), Color("dfd2b8"), Color("8a7157"), Color("706653")])
	var c := Vector3(court.get_center().x, 1.35, court.get_center().y)
	_add_pool_witness(Vector3(court.get_center().x, 0.04, court.get_center().y))
	_cam.fov = 60.0
	await _look(c + Vector3(2.5, 1.4, -court.size.y * 0.45),
		c + Vector3(0.0, 2.15, 0.6), "domus_sky.png")


func _interior() -> void:
	var plan: HousePlan = CourtSuite.courtyard(17.0, 15.0, 3818)
	var court := Rect2(plan.courts[0]["rect"])
	var builder := HouseBuilder.new()
	var mesh := builder.build(plan, false)
	_set_mesh(mesh, [Color("c8b89a"), Color("dfd2b8"), Color("8a7157"), Color("706653")])
	var c := Vector3(court.get_center().x, 0.0, court.get_center().y)
	await _look(c + Vector3(0.0, 2.4, -court.size.y * 0.42),
		c + Vector3(0.0, 2.1, court.size.y * 0.18), "domus_interior.png")


func _set_mesh(mesh: ArrayMesh, colours: Array[Color]) -> void:
	_mesh_inst.mesh = mesh
	for i in range(mesh.get_surface_count()):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colours[i] if i < colours.size() else Color("888888")
		mat.roughness = 0.88
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mesh_inst.set_surface_override_material(i, mat)


func _look(eye: Vector3, at: Vector3, filename: String) -> void:
	_cam.position = eye
	var direction := (at - eye).normalized()
	var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.96 else Vector3.FORWARD
	_cam.look_at(at, up)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(OUT + "/" + filename)
	print("  ", filename)


func _add_pool_witness(at: Vector3) -> void:
	var pool := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 0.08
	cylinder.radial_segments = 24
	pool.mesh = cylinder
	pool.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("3e91c7")
	mat.metallic = 0.05
	mat.roughness = 0.2
	pool.material_override = mat
	_root3d.add_child(pool)


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
	sky_mat.sky_top_color = Color("4d78a4")
	sky_mat.sky_horizon_color = Color("d5dbe0")
	sky_mat.ground_bottom_color = Color("62635b")
	sky_mat.ground_horizon_color = Color("a2a49e")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.1
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	_root3d.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-45.0), deg_to_rad(-35.0), 0.0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	_root3d.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(120.0), 0.0)
	fill.light_energy = 0.5
	_root3d.add_child(fill)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("707461")
	ground_mat.roughness = 1.0
	ground.material_override = ground_mat
	_root3d.add_child(ground)
	_mesh_inst = MeshInstance3D.new()
	_root3d.add_child(_mesh_inst)
	_cam = Camera3D.new()
	_cam.fov = 44.0
	_cam.far = 4000.0
	_vp.add_child(_cam)
