extends SceneTree
## Buildings on falling ground (VTER-HOUSE-SLOPE), each standing on its own
## ground: the same GroundFall plane the builder met, drawn as terrain, so a
## foundation that floats or a flight that stops short shows at a glance.
##
##   godot --path . --script res://tools/render_slopes.gd
##   godot --path . --script res://tools/render_slopes.gd -- house_side_25

const OUT := "res://artifacts/renders/slopes"
const SIZE := Vector2i(1200, 900)

## [file, kind, fall, downhill deg, camera yaw, pitch, zoom]
const SHOTS := [
	["house_side_10", &"house", 1.0, 90.0, 0.6, -0.25, 1.0],
	["house_side_25", &"house", 2.5, 90.0, 0.6, -0.25, 1.0],
	["house_side_40", &"house", 4.0, 90.0, 0.9, -0.2, 1.0],
	["house_front_25", &"house", 2.5, 0.0, 2.6, -0.2, 1.0],
	["house_front_40", &"house", 4.0, 0.0, 2.6, -0.2, 1.0],
	["shop_side_40", &"shop", 4.0, 90.0, 0.9, -0.2, 1.0],
	["church_side_25", &"church", 2.5, 90.0, 0.7, -0.22, 1.0],
	["church_front_40", &"church", 4.0, 0.0, 2.7, -0.2, 1.0],
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
	print("slope renders done")
	quit()


static func _request(kind: StringName) -> BuildingRequest:
	match kind:
		&"house":
			return BuildingRequest.house(8102, &"cottage", &"none", 8.0, 10.0, 2.6, 1)
		&"shop":
			return BuildingRequest.shop(4410, &"general_store", &"townhouse", 11.0, 14.0, 2.8, 1)
	return BuildingRequest.church(77, &"romanesque", 10.0, 20.0, 12.0)


func _shoot(row: Array) -> void:
	var request := _request(row[1])
	request.ground_fall_m = float(row[2])
	request.ground_downhill_deg = float(row[3])
	var building := BrickWild.generate(request)
	if not building.is_ok():
		print("  ", row[0], " did not generate: ", building.errors)
		return
	var node: Node3D = BrickWild.instantiate(building)
	_stage.add_child(node)
	var ground := MeshInstance3D.new()
	ground.mesh = _ground_mesh(GroundFall.of_spec(building.spec))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("6d7159")
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ground.material_override = mat
	_stage.add_child(ground)
	await process_frame
	var aabb: AABB = SceneBounds.of_node(node)
	var centre := aabb.get_center()
	var radius := maxf(aabb.size.length() * 0.5, 1.0)
	var dist: float = radius / tan(deg_to_rad(_cam.fov) * 0.5) * 1.05 * float(row[6])
	var yaw: float = row[4]
	var pitch: float = row[5]
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	# the camera stands downhill-ish of the front: -Z is the front
	dir.z = -dir.z
	_cam.position = centre + dir * dist
	_cam.look_at(centre, Vector3.UP)
	for k in range(4):
		await process_frame
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png("%s/%s.png" % [OUT, row[0]])
	print("  ", row[0], " ", str(aabb.size.snapped(Vector3.ONE * 0.1)))
	node.free()
	ground.free()
	await process_frame


static func _ground_mesh(g: GroundFall) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 60
	var cell := 1.0
	var h := func(x: float, z: float) -> Vector3:
		return Vector3(x, (g.ground_y(Vector2(x, z)) if g != null else 0.0) - 0.01, z)
	for i in n:
		for j in n:
			var x0 := -30.0 + i * cell
			var z0 := -30.0 + j * cell
			var a: Vector3 = h.call(x0, z0)
			var b: Vector3 = h.call(x0 + cell, z0)
			var c: Vector3 = h.call(x0 + cell, z0 + cell)
			var d: Vector3 = h.call(x0, z0 + cell)
			for p in [a, b, c, a, c, d]:
				st.add_vertex(p)
	st.generate_normals()
	return st.commit()


func _build_stage() -> void:
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(_vp)
	_stage = Node3D.new()
	_vp.add_child(_stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("c9d3da")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b8bcc0")
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	_stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(-30.0), 0.0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	_stage.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 44.0
	_cam.far = 2000.0
	_vp.add_child(_cam)
	_cam.current = true
