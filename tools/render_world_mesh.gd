extends SceneTree
## Portraits of the three world families whose emitted triangles are now
## probed (WORLD-MESH-VERIFY): stepwell, temple mountain, Dravida prakara.
## Public path: BrickWild.generate -> BrickWild.instantiate.
##
##   godot --path . --script res://tools/render_world_mesh.gd

const OUT := "res://artifacts/world_todo"
const SIZE := Vector2i(1200, 900)

## [file, style, purpose, seed, width, length, height, yaw, pitch, zoom, focus]
const SHOTS := [
	["stepwell", &"stepwell", &"queens_well", 1016, 65.0, 20.0, 28.0, 2.4, -0.55, 1.0, 0.35],
	["stepwell_tank", &"stepwell", &"queens_well", 1016, 65.0, 20.0, 28.0, 1.2, -0.75, 0.55, 0.2],
	["mountain", &"temple_mountain", &"angkor_mountain", 41011, 200.0, 200.0, 60.0, 2.5, -0.4, 1.0, 0.3],
	["mountain_axis", &"temple_mountain", &"angkor_mountain", 41011, 200.0, 200.0, 60.0, 3.14, -0.12, 0.7, 0.3],
	["dravida", &"dravida", &"god_kings_precinct", 14014, 240.0, 120.0, 63.0, 2.8, -0.45, 1.0, 0.35],
	["dravida_axis", &"dravida", &"god_kings_precinct", 14014, 240.0, 120.0, 63.0, 3.14, -0.1, 0.6, 0.15],
	["dravida_colonnade", &"dravida", &"god_kings_precinct", 14014, 240.0, 120.0, 63.0, 3.14, -0.9, 0.45, 0.0],
]

var _vp: SubViewport
var _cam: Camera3D
var _stage: Node3D
var _ground: MeshInstance3D


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_stage()
	await process_frame
	var only: PackedStringArray = OS.get_cmdline_user_args()
	for row in SHOTS:
		if not only.is_empty() and not (row[0] in only):
			continue
		await _shoot(row)
	print("world mesh renders done")
	quit()


func _shoot(row: Array) -> void:
	var request := BuildingRequest.new()
	request.kind = &"world"
	request.style = row[1]
	request.purpose = row[2]
	request.seed = int(row[3])
	request.width = float(row[4])
	request.length = float(row[5])
	request.height = float(row[6])
	if row[1] == &"dravida":
		request.period = 900
	var building := BrickWild.generate(request)
	if building == null or not building.is_ok():
		print("  ", row[0], " did not generate: ", building.errors)
		return
	# Stepwell and moat sit below grade: lift the ground out of the way.
	_ground.visible = row[1] == &"dravida"
	var node: Node3D = BrickWild.instantiate(building)
	if node == null:
		print("  ", row[0], " has no scene")
		return
	_stage.add_child(node)
	await process_frame
	var aabb: AABB = SceneBounds.of_node(node)
	var centre := aabb.get_center()
	var focus: float = float(row[10])
	centre.y = aabb.position.y + aabb.size.y * focus
	var radius := maxf(aabb.size.length() * 0.5, 1.0)
	var dist: float = radius / tan(deg_to_rad(_cam.fov) * 0.5) * 1.08 * float(row[9])
	var yaw: float = row[7]
	var pitch: float = row[8]
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	_cam.position = centre + dir * dist
	_cam.look_at(centre, Vector3.UP)
	for k in range(4):
		await process_frame
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png("%s/%s.png" % [OUT, row[0]])
	print("  ", row[0], " ", building.name(), " ", str(aabb.size.snapped(Vector3.ONE)))
	node.free()
	await process_frame


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
	sky_mat.sky_top_color = Color("3f6f9e")
	sky_mat.sky_horizon_color = Color("d9dee2")
	sky_mat.ground_bottom_color = Color("5e6058")
	sky_mat.ground_horizon_color = Color("9fa197")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	_stage.add_child(world)
	# A low sun from the front left: a mill's whole job is to be read against
	# the light, and a high sun flattens the sails into the sky behind them.
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-28.0), deg_to_rad(-38.0), 0.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 900.0
	_stage.add_child(sun)
	_ground = MeshInstance3D.new()
	var ground := _ground
	var plane := PlaneMesh.new()
	plane.size = Vector2(1400, 1400)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("6d7159")
	ground_mat.roughness = 1.0
	ground.material_override = ground_mat
	ground.position.y = -0.02
	_stage.add_child(ground)
	_cam = Camera3D.new()
	_cam.fov = 44.0
	_cam.far = 4000.0
	_vp.add_child(_cam)
	_cam.current = true