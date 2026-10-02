extends SceneTree
## EVAL-B04 non-headless render gate: every family of the wider world through the
## public path (BrickWild.generate -> BrickWild.instantiate), so the picture is the
## building in what it is made of -- the assembler's own materials, not a staged
## palette. One three-quarter portrait per family at its smallest size, to
## artifacts/renders/world_materials/.
##
##   godot --path . --script res://tools/render_world_materials.gd
##   godot --path . --script res://tools/render_world_materials.gd -- pagoda tulou

const OUT := "res://artifacts/renders/world_materials"
const SIZE := Vector2i(1100, 760)

## [file, style, purpose, seed, yaw, pitch, zoom]
const SHOTS := [
	["domus", &"courtyard_house", &"domus", 12001, 2.6, -0.42, 1.0],
	["riad", &"courtyard_house", &"riad", 12002, 2.6, -0.42, 1.0],
	["palazzo", &"courtyard_house", &"palazzo", 12003, 2.6, -0.32, 1.0],
	["insula", &"insula", &"port_tenement", 4101, 0.55, -0.4, 1.0],
	["han", &"caravanserai", &"sultan_han", 4101, 0.6, -0.5, 1.0],
	["hammam", &"hammam", &"steam_baths", 4101, 0.6, -0.45, 1.0],
	["mosque", &"mosque", &"hypostyle", 4101, 0.6, -0.55, 1.0],
	["tulou", &"tulou", &"clan_ring", 4101, 0.5, -0.45, 1.0],
	["pagoda", &"pagoda", &"square_pagoda", 4101, 0.6, -0.25, 1.0],
	["siheyuan", &"siheyuan", &"scholars_compound", 4101, 0.6, -0.5, 1.0],
	["haveli", &"vastu", &"merchants_haveli", 4101, 0.6, -0.45, 1.0],
	["vihara", &"vihara", &"monks_cloister", 4101, 0.6, -0.5, 1.0],
	["great_hall", &"timber_hall", &"great_hall", 4101, 2.6, -0.3, 1.0],
	["phoenix_pavilion", &"timber_hall", &"phoenix_pavilion", 4101, 2.6, -0.3, 1.0],
	["stupa", &"stupa", &"saints_mound", 4101, 0.6, -0.3, 1.0],
	["temple_of_four_winds", &"cruciform_temple", &"temple_of_four_winds", 4101, 0.6, -0.4, 1.0],
	["nagara", &"nagara", &"hundred_spires", 4101, 0.6, -0.3, 1.0],
	["dravida", &"dravida", &"god_kings_precinct", 4101, 0.6, -0.45, 1.0],
	["rock_cut", &"rock_cut_temple", &"quarried_temple", 4101, 0.6, -0.45, 1.0],
	["temple_mountain", &"temple_mountain", &"angkor_mountain", 4101, 0.6, -0.4, 1.0],
	["stepwell", &"stepwell", &"queens_well", 4101, 0.6, -0.5, 1.0],
]

var _vp: SubViewport
var _cam: Camera3D
var _stage: Node3D
var _ground: MeshInstance3D

## Carved below grade: the stage has no ground for these, or the rock is buried.
const NO_GROUND := ["rock_cut", "stepwell"]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_stage()
	await process_frame
	var only: PackedStringArray = OS.get_cmdline_user_args()
	for row in SHOTS:
		if not only.is_empty() and not (row[0] in only):
			continue
		await _shoot(row)
	print("world materials done")
	quit()


func _shoot(row: Array) -> void:
	var request := BuildingRequest.new()
	request.kind = &"world"
	request.style = row[1]
	request.purpose = row[2]
	request.seed = row[3]
	var envelope: Dictionary = WorldFamilies.envelope(row[1])
	request.width = float(envelope["width"]["min"])
	request.length = float(envelope["length"]["min"])
	request.height = float(envelope["height"]["min"])
	var building := BrickWild.generate(request)
	if building == null or not building.is_ok():
		print("  ", row[0], " did not generate")
		return
	_ground.visible = not (row[0] in NO_GROUND)
	var node: Node3D = BrickWild.instantiate(building)
	if node == null:
		print("  ", row[0], " has no scene")
		return
	_stage.add_child(node)
	await process_frame
	var aabb: AABB = SceneBounds.of_node(node)
	var centre := aabb.get_center()
	var radius := maxf(aabb.size.length() * 0.5, 1.0)
	var dist := radius / tan(deg_to_rad(_cam.fov) * 0.5) * 1.05 * float(row[6])
	var yaw: float = row[4]
	var pitch: float = row[5]
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	_cam.position = centre + dir * dist
	_cam.look_at(centre, Vector3.UP)
	for k in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png("%s/%s.png" % [OUT, row[0]])
	print("  ", row[0])
	node.free()
	if row[1] == &"courtyard_house" and building.plan != null:
		# These houses face inward. Keep their private outer walls, and show
		# the court rather than inventing street windows for a rear portrait.
		var court := HouseAssembler.build(building.plan, true)
		_stage.add_child(court)
		_cam.position = centre + Vector3(0.35, 1.0, -0.35).normalized() * dist
		_cam.look_at(centre, Vector3.UP)
		for k in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		_vp.get_texture().get_image().save_png("%s/%s_court.png" % [OUT, row[0]])
		court.free()
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
	_stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-45.0), deg_to_rad(-35.0), 0.0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 900.0
	_stage.add_child(sun)
	var ground := MeshInstance3D.new()
	_ground = ground
	var plane := PlaneMesh.new()
	plane.size = Vector2(1200, 1200)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("707461")
	ground_mat.roughness = 1.0
	ground.material_override = ground_mat
	ground.position.y = -0.02
	_stage.add_child(ground)
	_cam = Camera3D.new()
	_cam.fov = 44.0
	_cam.far = 4000.0
	_vp.add_child(_cam)
	_cam.current = true
