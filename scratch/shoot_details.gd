extends SceneTree
## Close-ups for eyeballing WINDOWS, DOORS and ROOFS.
##
## The reference renders in tools/render_shots.gd frame whole buildings, which
## is the wrong distance to judge a reveal, a door head or an eaves overhang.
## This aims the camera at one opening at a time, from a named eye point, and
## writes to artifacts/shots/.
##
##   godot --path . --script res://scratch/shoot_details.gd

const OUT := "res://artifacts/shots"
const SIZE := Vector2i(1200, 820)

var _vp: SubViewport
var _cam: Camera3D
var _root3d: Node3D
var _mesh_inst: MeshInstance3D


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_stage()
	await process_frame

	await _house_shots()
	await _castle_shots()
	await _hall_shots()
	await _church_shots()
	print("done")
	quit()


# ------------------------------------------------------------------- houses

func _house_shots() -> void:
	var spec := HouseSpec.new()
	spec.style = &"townhouse"
	spec.width = 9.0
	spec.length = 12.0
	spec.height = 2.7
	spec.storeys = 2
	var plan: HousePlan = HouseGenerator.generate(spec, 4411)
	var node: Node3D = HouseAssembler.build(plan, false)
	_root3d.add_child(node)
	await process_frame

	var door: Dictionary = plan.doors[plan.entrance()]
	var d: Vector2 = door["pos"]
	var n: Vector2 = door["normal"]
	# straight at the front door, from a person's height two metres out
	await _look(Vector3(d.x + n.x * 3.2, 1.6, d.y + n.y * 3.2),
		Vector3(d.x, 1.2, d.y), "house_door.jpg")
	# the same wall from the side, so the porch and the reveals read in depth
	await _look(Vector3(d.x + n.x * 4.0 + 3.5, 2.0, d.y + n.y * 4.0),
		Vector3(d.x, 1.4, d.y), "house_door_oblique.jpg")

	# a first-floor window, square on
	var up := -1
	for w in range(plan.windows.size()):
		if HousePlan.record_storey(plan.windows[w]) == 1:
			up = w
			break
	if up >= 0:
		var wp: Vector2 = plan.windows[up]["pos"]
		var wn: Vector2 = plan.windows[up]["normal"]
		var sill: float = float(plan.windows[up]["sill"]) + spec.height
		await _look(Vector3(wp.x + wn.x * 3.0, sill + 0.6, wp.y + wn.y * 3.0),
			Vector3(wp.x, sill + 0.5, wp.y), "house_window.jpg")

	# the eaves and the verge, from below and outside the long wall
	var site: Rect2 = HouseGeometry.site_rect(spec)
	var top: float = spec.height * spec.storeys
	await _look(Vector3(site.end.x + 6.0, top - 1.0, site.get_center().y),
		Vector3(site.end.x, top + 1.2, site.get_center().y), "house_eaves.jpg")
	# and the gable end, square on: verge, king post, and where the roof lands
	await _look(Vector3(site.get_center().x, top * 0.8, site.position.y - 14.0),
		Vector3(site.get_center().x, top * 0.8, site.position.y), "house_gable.jpg")
	# the chimney where it meets the roof
	if plan.hearth_room() >= 0:
		await _look(Vector3(site.position.x - 9.0, top + 3.0, site.get_center().y - 3.0),
			Vector3(site.position.x, top + 1.0, site.get_center().y), "house_chimney.jpg")
	node.queue_free()


# ------------------------------------------------------------------ castles

func _castle_shots() -> void:
	var spec := CastleSpec.new()
	spec.style = &"edwardian"
	spec.width = 60.0
	spec.length = 90.0
	spec.height = 18.0
	CastleGenerator.generate(spec, 9001)
	var mesh: ArrayMesh = CastleBuilder.new().build(spec)
	_set_mesh(mesh, [spec.stone_color, spec.trim_color, spec.roof_color,
		Color("15171b")])

	var rect: Rect2 = CastleGeometry.enceinte_rect(spec, 0)
	var gate := Vector3(rect.get_center().x, 0.0, rect.position.y)
	# the gate passage, from outside, at head height
	await _look(gate + Vector3(0.0, 3.0, -22.0), gate + Vector3(0.0, 4.0, 0.0),
		"castle_gate.jpg")
	# a corner tower cap and the wall walk behind it
	await _look(Vector3(rect.position.x - 24.0, spec.height + 10.0,
			rect.position.y - 24.0),
		Vector3(rect.position.x, spec.height, rect.position.y),
		"castle_tower.jpg")
	# the hall range roof, from inside the bailey
	if spec.hall:
		var box: AABB = CastleGeometry.hall_aabb(spec)
		var c: Vector3 = box.get_center()
		await _look(c + Vector3(box.size.x * 2.2, box.size.y * 1.4, -box.size.z * 0.55),
			c + Vector3(0.0, box.size.y * 0.7, 0.0), "castle_hall_roof.jpg")
	# the curtain wall slits and the crenellations, square on
	await _look(Vector3(rect.get_center().x + rect.size.x * 0.5 + 26.0,
			spec.height * 0.65, rect.get_center().y),
		Vector3(rect.end.x, spec.height * 0.6, rect.get_center().y),
		"castle_wall.jpg")
	_mesh_inst.mesh = null


# --------------------------------------------------------------- great hall

func _hall_shots() -> void:
	var spec := CastleSpec.new()
	spec.style = &"edwardian"
	spec.width = 60.0
	spec.length = 90.0
	spec.height = 18.0
	CastleGenerator.generate(spec, 9001)
	var plan: HousePlan = CastleGenerator.hall_plan(spec)
	if plan.spec == null:
		print("  (no hall plan for this castle)")
		return
	var node: Node3D = HouseAssembler.build(plan, true)
	_root3d.add_child(node)
	await process_frame
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, 0)
	var door: Vector2 = plan.doors[plan.entrance()]["pos"]
	var dais: Rect2 = plan.dais_rect()
	# standing in the doorway, looking up the hall at the high table
	await _look(Vector3(door.x, 1.7, door.y - 1.5),
		Vector3(dais.get_center().x, 1.2, dais.get_center().y), "hall_from_door.jpg")
	# and from above, so the dais, the rows and the screens passage read
	await _look(Vector3(f.get_center().x, f.size.y * 0.9, f.position.y - f.size.y * 0.35),
		Vector3(f.get_center().x, 0.0, f.get_center().y), "hall_plan.jpg")
	node.queue_free()


# ------------------------------------------------------------------ church

func _church_shots() -> void:
	var spec := ChurchSpec.new()
	spec.style = &"gothic"
	spec.width = 12.0
	spec.length = 60.0
	spec.height = 22.0
	ChurchGenerator.generate(spec, 5001)
	var mesh: ArrayMesh = ChurchBuilder.new().build(spec)
	_set_mesh(mesh, [spec.stone_color, spec.trim_color, spec.roof_color,
		Color("15171b")])
	var aabb: AABB = mesh.get_aabb()
	var c: Vector3 = aabb.get_center()
	# the west front, square on: the great door and the window over it
	await _look(Vector3(c.x, aabb.size.y * 0.35, aabb.position.z - aabb.size.y * 0.9),
		Vector3(c.x, aabb.size.y * 0.32, aabb.position.z), "church_west.jpg")
	# the nave wall: aisle windows, clerestory, buttresses, roof line
	await _look(Vector3(c.x + aabb.size.y * 1.1, aabb.size.y * 0.45, c.z),
		Vector3(c.x, aabb.size.y * 0.4, c.z), "church_nave.jpg")
	_mesh_inst.mesh = null


# ------------------------------------------------------------------- rigging

func _set_mesh(mesh: ArrayMesh, cols: Array) -> void:
	_mesh_inst.mesh = mesh
	for i in range(mesh.get_surface_count()):
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[i]
		m.roughness = 0.92
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
	img.save_jpg(OUT + "/" + file, 0.92)
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
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("6b8cb5")
	sky_mat.sky_horizon_color = Color("cfd8e0")
	sky_mat.ground_bottom_color = Color("5b5b55")
	sky_mat.ground_horizon_color = Color("9aa0a0")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	_root3d.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(-125.0), 0.0)
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
