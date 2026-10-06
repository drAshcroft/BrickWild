extends SceneTree
## Cutaway renders of a palazzo and an insula, for looking at where each flight
## arrives (HOUSE-STAIR-WELL-REGRESSION). Not headless.
##   godot --path . --script res://tools/render_stairwell.gd

const OUT := "res://artifacts/stairwell"
const SHOTS := [
	["palazzo", &"courtyard_house", &"palazzo", 30.0, 36.0, 4.2],
	["insula", &"insula", &"port_tenement", 30.0, 24.0, 15.0],
]
var _vp: SubViewport
var _cam: Camera3D
var _stage: Node3D

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1400, 1000)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_stage = Node3D.new()
	_vp.add_child(_stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9aa5ad")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	_stage.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(-30.0), 0.0)
	_stage.add_child(sun)
	_cam = Camera3D.new()
	_cam.far = 2000.0
	_vp.add_child(_cam)
	_cam.current = true
	await process_frame
	for row in SHOTS:
		var req := BrickWild.default_request(&"world", 828)
		req.style = row[1]
		req.purpose = row[2]
		req.width = row[3]
		req.length = row[4]
		req.height = row[5]
		var b := BrickWild.generate(req)
		if b == null or not b.is_ok():
			print(row[0], " failed: ", b.errors if b != null else "null")
			continue
		var node: Node3D = BrickWild.instantiate(b, true, false)
		_stage.add_child(node)
		await process_frame
		var aabb: AABB = SceneBounds.of_node(node)
		var c := aabb.get_center()
		var dist := aabb.size.length() * 0.9
		for view in [["iso", Vector3(0.5, 1.0, 0.8)], ["top", Vector3(0.01, 1.0, 0.02)]]:
			_cam.position = c + (view[1] as Vector3).normalized() * dist
			_cam.look_at(c, Vector3.UP if view[0] == "iso" else Vector3.FORWARD)
			for k in range(4):
				await process_frame
				await RenderingServer.frame_post_draw
			_vp.get_texture().get_image().save_png("%s/%s_%s.png" % [OUT, row[0], view[0]])
		print(row[0], " rendered ", aabb.size)
		node.free()
		await process_frame
	quit()
