extends SceneTree
## Photographs the crooked warp (HNT-040) to res://artifacts/haunt/renders/:
## each subject plumb and crooked from the same seed and the same camera, so
## the pair shows the warp and nothing else.
##
## Must run WITHOUT --headless: the dummy renderer makes no image.
##
##   godot --path . --script res://tools/render_crooked.gd
##
## The light is a first cut at the October dusk (HNT-000): a low cold moon as
## the key, a warm horizon behind, enough ambient to judge the geometry.

const OUT := "res://artifacts/haunt/renders"
const SHOT := Vector2i(1000, 900)

var _vp: SubViewport
var _cam: Camera3D
var _sun: DirectionalLight3D
var _root: Node3D


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_stage()
	await process_frame
	var subjects := [
		["house", BuildingRequest.house(8102, &"cottage", &"none", 8.0, 10.0, 2.6, 2), 0.7],
		["witch", BuildingRequest.house(3301, &"witch_hut", &"alchemist", 7.0, 8.0, 2.5, 2), 0.9],
		["rich", BuildingRequest.house(41, &"rich", &"none", 9.0, 11.0, 2.8, 3), 1.0],
		["church", BuildingRequest.church(977, &"gothic"), 1.0],
		["castle", BuildingRequest.castle(23001, &"dark"), 0.8],
	]
	for row in subjects:
		var request: BuildingRequest = row[1]
		for jank in [0.0, float(row[2])]:
			request.jank = jank
			await _shoot(request, "%s_%s.png" % [row[0], "plumb" if jank == 0.0 else "crooked"])
	print("done")
	quit()


func _shoot(request: BuildingRequest, file: String) -> void:
	var building := BrickWild.generate(request)
	if not building.is_ok():
		push_error("%s: %s" % [file, building.errors])
		return
	var node: Node3D = BrickWild.instantiate(building)
	_root.add_child(node)
	await process_frame
	# frame the PLUMB building, so plumb and crooked share one camera
	var plumb := request.copy()
	plumb.jank = 0.0
	var aabb: AABB = BrickWild.build_mesh(BrickWild.generate(plumb)).get_aabb()
	var centre := aabb.get_center()
	var radius := maxf(aabb.size.length() * 0.5, 2.0)
	var dist := radius / tan(deg_to_rad(_cam.fov) * 0.5) * 1.05
	var yaw := deg_to_rad(-32.0)
	var pitch := deg_to_rad(-12.0)
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), -cos(yaw) * cos(pitch))
	_cam.position = centre + dir * dist
	_cam.look_at(centre, Vector3.UP)
	_sun.directional_shadow_max_distance = dist + radius * 2.0
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(OUT + "/" + file)
	print("  ", file)
	node.queue_free()
	await process_frame


func _build_stage() -> void:
	_vp = SubViewport.new()
	_vp.size = SHOT
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(_vp)
	_root = Node3D.new()
	_vp.add_child(_root)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("1d1830")
	sm.sky_horizon_color = Color("a5675a")
	sm.ground_bottom_color = Color("15131a")
	sm.ground_horizon_color = Color("4a3a40")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("4b4560")
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	_root.add_child(we)

	_sun = DirectionalLight3D.new()     # the moon
	_sun.rotation = Vector3(deg_to_rad(-30.0), deg_to_rad(-140.0), 0.0)
	_sun.light_energy = 1.6
	_sun.light_color = Color("b8c8ff")
	_sun.shadow_enabled = true
	_root.add_child(_sun)
	var rim := DirectionalLight3D.new()   # what is left of the sunset
	rim.rotation = Vector3(deg_to_rad(-8.0), deg_to_rad(30.0), 0.0)
	rim.light_energy = 0.7
	rim.light_color = Color("ff9a6a")
	_root.add_child(rim)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("2b2a26")
	ground.material_override = gm
	ground.position.y = -0.02
	_root.add_child(ground)

	_cam = Camera3D.new()
	_cam.fov = 42.0
	_cam.far = 3000.0
	_vp.add_child(_cam)
