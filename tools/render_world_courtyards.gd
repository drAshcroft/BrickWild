extends SceneTree
## WLD-001 non-headless render gate.  The roof-on frames show each public
## street face; the roof-off court frames show the inward ranges, sky and the
## diagnostic water witness; the palazzo close frame proves the canal door.

const OUT := "res://artifacts/renders/world_courtyards"
const SIZE := Vector2i(1280, 860)

var _vp: SubViewport
var _cam: Camera3D
var _root3d: Node3D
var _mesh_inst: MeshInstance3D
var _witness: MeshInstance3D
var _canal_witness: MeshInstance3D
var _small_palazzo := false


func _init() -> void:
	_small_palazzo = "--small-palazzo" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_stage()
	await process_frame
	if not _small_palazzo:
		await _domus()
		await _riad()
	await _palazzo()
	print("done")
	quit()


func _domus() -> void:
	var b := _generate(&"domus", 12001, 22.0, 40.0, 6.0)
	await _street(b, "domus_roof_on.png")
	await _court(b, "domus_court_roof_off.png")


func _riad() -> void:
	var b := _generate(&"riad", 12002, 18.0, 24.0, 7.0)
	await _street(b, "riad_roof_on.png")
	await _court(b, "riad_court_roof_off.png")


func _palazzo() -> void:
	var width := 14.0 if _small_palazzo else 20.0
	var length := 21.0 if _small_palazzo else 30.0
	var suffix := "_small" if _small_palazzo else ""
	var b := _generate(&"palazzo", 12003, width, length, 18.0)
	await _street(b, "palazzo%s_roof_on.png" % suffix)
	await _court(b, "palazzo%s_court_roof_off.png" % suffix)
	await _court(b, "palazzo%s_water_gate.png" % suffix, true)


func _generate(kind: StringName, seed: int, width: float, length: float,
		height: float) -> GeneratedBuilding:
	var request := BuildingRequest.new()
	request.kind = &"world"
	request.style = &"courtyard_house"
	request.purpose = kind
	request.seed = seed
	request.width = width
	request.length = length
	request.height = height
	return BrickWild.generate(request)


func _street(building: GeneratedBuilding, filename: String) -> void:
	var builder := HouseBuilder.new()
	var mesh := builder.build(building.plan, true)
	_set_mesh(mesh, building.plan)
	_clear_witness()
	var site := HouseGeometry.site_rect(building.plan.spec)
	_cam.fov = 58.0 if int(building.plan.spec.storeys) >= 3 else 46.0
	# Keep the eye above the eaves: the first diagnostic camera sat under the
	# roof and read as a black slab instead of a facade/roof silhouette.
	var wall_top: float = building.plan.spec.height * int(building.plan.spec.storeys)
	var eye := Vector3(site.get_center().x + site.size.x * 0.78,
		building.plan.spec.height + 8.0,
		site.position.y - maxf(24.0, site.size.y * 0.72))
	var target_y: float = building.plan.spec.height * 0.65
	if int(building.plan.spec.storeys) >= 3:
		# A tall palazzo's shallow ring is hidden behind the front wall from a
		# low eye; lift and pull back this diagnostic view to expose the roof.
		eye = Vector3(site.get_center().x + site.size.x * 0.92,
			wall_top + 24.0, site.position.y - maxf(42.0, site.size.y * 1.05))
		target_y = wall_top * 0.9
	await _look(eye, Vector3(site.get_center().x, target_y,
		site.get_center().y), filename)


func _court(building: GeneratedBuilding, filename: String, gate := false) -> void:
	var builder := HouseBuilder.new()
	var mesh := builder.build(building.plan, false)
	_set_mesh(mesh, building.plan)
	_clear_witness()
	var court := Rect2(building.plan.world_meta["court_rect"])
	var centre := Vector3(court.get_center().x, 0.0, court.get_center().y)
	_add_water_witness(centre + Vector3.UP * 0.04)
	# A near-vertical cutaway sees the whole court, its four inward ranges and
	# the water witness. The earlier diagonal eye was still outside the ranges.
	var court_eye_y: float = maxf(18.0, building.plan.spec.height * 1.25)
	var eye := centre + Vector3(court.size.x * 0.28, court_eye_y,
		-court.size.y * 0.28)
	if gate:
		var door: Vector2 = building.plan.world_meta["street_door"]
		_add_canal_witness(building)
		eye = Vector3(door.x + 8.0, building.plan.spec.height * 0.9, door.y - 18.0)
		await _look(eye, Vector3(door.x, building.plan.spec.height * 0.55, door.y), filename)
	else:
		var court_target_y: float = 0.8
		await _look(eye, centre + Vector3.UP * court_target_y, filename)


func _set_mesh(mesh: ArrayMesh, plan: HousePlan = null) -> void:
	_mesh_inst.mesh = mesh
	for i in range(mesh.get_surface_count()):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = [Color("b9a98e"), Color("665340"), Color("4b3d32"), Color("88785d")][mini(i, 3)]
		mat.roughness = 0.86
		mat.cull_mode = BaseMaterial3D.CULL_BACK
		_mesh_inst.set_surface_override_material(i, mat)
	if plan != null:
		# the real thing: what the family is built of (EVAL-B04)
		WorldAssembler.dress_house(_mesh_inst, plan)


func _add_water_witness(at: Vector3) -> void:
	_witness = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.15
	cylinder.bottom_radius = 1.15
	cylinder.height = 0.12
	cylinder.radial_segments = 32
	_witness.mesh = cylinder
	_witness.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("3e91c7")
	mat.emission_enabled = true
	mat.emission = Color("1d7db5")
	mat.emission_energy_multiplier = 0.7
	mat.metallic = 0.05
	mat.roughness = 0.2
	_witness.material_override = mat
	_root3d.add_child(_witness)


func _add_canal_witness(building: GeneratedBuilding) -> void:
	_canal_witness = MeshInstance3D.new()
	var water := BoxMesh.new()
	var site := HouseGeometry.site_rect(building.plan.spec)
	water.size = Vector3(site.size.x + 4.0, 0.08, 5.0)
	_canal_witness.mesh = water
	_canal_witness.position = Vector3(site.get_center().x,
		building.plan.water_plane, site.position.y - 2.6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("2b9ad0")
	mat.metallic = 0.1
	mat.roughness = 0.16
	_canal_witness.material_override = mat
	_root3d.add_child(_canal_witness)


func _clear_witness() -> void:
	if is_instance_valid(_witness):
		_witness.queue_free()
		_witness = null
	if is_instance_valid(_canal_witness):
		_canal_witness.queue_free()
		_canal_witness = null


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
