extends SceneTree
## A portrait of each of the five mills, through the PUBLIC path
## (BrickWild.generate -> BrickWild.instantiate), so what is photographed is the
## assembled mill in its own five materials -- stone or board, iron, cloth or
## thatch, race water, and the dark of its own doorways -- not a staged palette.
##
## One three-quarter portrait per type, plus a second view of the tower mill
## from further off, because a mill is mostly read as a SILHOUETTE and a
## silhouette is the one thing a headless test cannot check.
##
##   godot --path . --script res://tools/render_windmills.gd
##   godot --path . --script res://tools/render_windmills.gd -- post paddle

const OUT := "res://artifacts/renders/windmills"
const SIZE := Vector2i(1200, 900)

## [file, type, seed, sail span, body, height, yaw, pitch, zoom, focus]
## `focus` is where up the mill's own height the camera looks: 0.5 is its
## centre, 0.94 is a windpump's head, 0.13 is a polder mill's wheel.
const SHOTS := [
	["tower", &"tower", 9118, 13.0, 6.5, 14.0, 2.55, -0.22, 1.0, 0.5],
	["tower_far", &"tower", 4409, 13.0, 6.5, 14.0, 2.2, -0.12, 2.1, 0.5],
	["tower_rear", &"tower", 9118, 13.0, 6.5, 14.0, 0.55, -0.18, 1.0, 0.55],
	["smock", &"smock", 1207, 11.0, 6.0, 13.0, 2.35, -0.24, 1.0, 0.5],
	["smock_rear", &"smock", 1207, 11.0, 6.0, 13.0, 0.5, -0.2, 1.0, 0.55],
	["post", &"post", 551, 9.0, 5.0, 3.6, 2.05, -0.34, 1.0, 0.5],
	["post_ladder", &"post", 551, 9.0, 5.0, 3.6, 1.25, -0.26, 0.95, 0.5],
	["windpump", &"windpump", 3301, 5.0, 3.6, 12.0, 2.45, -0.2, 1.0, 0.5],
	["windpump_head", &"windpump", 3301, 5.0, 3.6, 12.0, 2.45, -0.08, 0.45, 0.94],
	["paddle", &"paddle", 7702, 10.0, 6.5, 12.0, 2.3, -0.3, 1.0, 0.5],
	["paddle_wheel", &"paddle", 7702, 10.0, 6.5, 12.0, 1.1, -0.14, 0.42, 0.13],
]

var _vp: SubViewport
var _cam: Camera3D
var _stage: Node3D


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_stage()
	await process_frame
	var only: PackedStringArray = OS.get_cmdline_user_args()
	for row in SHOTS:
		if not only.is_empty() and not (row[0] in only):
			continue
		await _shoot(row)
	print("windmill renders done")
	quit()


func _shoot(row: Array) -> void:
	var request := BuildingRequest.windmill(int(row[2]), row[1], float(row[3]),
		float(row[4]), float(row[5]))
	var building := BrickWild.generate(request)
	if building == null or not building.is_ok():
		print("  ", row[0], " did not generate: ", building.errors)
		return
	var node: Node3D = BrickWild.instantiate(building)
	if node == null:
		print("  ", row[0], " has no scene")
		return
	_stage.add_child(node)
	await process_frame
	var aabb: AABB = SceneBounds.of_node(node)
	var centre := aabb.get_center()
	var focus: float = float(row[9]) if row.size() > 9 else 0.5
	centre.y = aabb.position.y + aabb.size.y * focus
	var radius := maxf(aabb.size.length() * 0.5, 1.0)
	var dist: float = radius / tan(deg_to_rad(_cam.fov) * 0.5) * 1.08 * float(row[8])
	var yaw: float = row[6]
	var pitch: float = row[7]
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
	var ground := MeshInstance3D.new()
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