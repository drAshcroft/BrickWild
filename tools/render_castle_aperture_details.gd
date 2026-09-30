extends SceneTree
## Fixed-camera, non-headless close renders of the apertures changed by VIS-006.
## Run with the regular Godot executable; the dummy headless renderer has no image.

const DEFAULT_OUT := "res://artifacts/vis006/renders"
const SIZE := Vector2i(1400, 960)
var _vp: SubViewport
var _cam: Camera3D
var _stage: Node3D
var _out := DEFAULT_OUT


func _init() -> void:
	_build_stage()
	await process_frame
	var user_args := OS.get_cmdline_user_args()
	var only := ""
	var keep_only := false
	for name in ["bodiam", "krak"]:
		if user_args.has("--" + name + "-only"):
			only = name
	keep_only = user_args.has("--keep-only")
	for arg in user_args:
		if String(arg).begins_with("--out="):
			_out = String(arg).trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	if user_args.has("--square-keep-fixture"):
		await _render_square_keep_fixture()
		print("Square keep shell fixture renders complete: ", _out)
		quit()
		return
	for entry in _entries():
		if not only.is_empty() and entry.name != only:
			continue
		var spec := _spec(entry)
		var builder := CastleBuilder.new()
		var mesh: ArrayMesh = builder.build(spec)
		var castle := ShellAssembler.build("Castle", mesh,
			[spec.stone_color, spec.trim_color, spec.roof_color, Color("1a1c20")],
			builder.prop_log, CastleBuilder.SURF_ROOF, false, LightKit.FLAME, true)
		_stage.add_child(castle)
		for focus in ["curtain", "tower", "keep"]:
			if keep_only and focus != "keep":
				continue
			var part := _opening_for(builder.part_log, focus)
			if part.is_empty():
				push_error("No %s window found for %s" % [focus, entry.name])
				continue
			var target: Vector3 = part.pos
			var normal: Vector3 = part.facing.normalized()
			if focus == "keep":
				var fixed_target := _changed_keep_target(entry.name)
				target = fixed_target.position
				normal = fixed_target.facing
			var tangent := Vector3(-normal.z, 0.0, normal.x).normalized()
			_cam.position = target + normal * 4.0 + Vector3.UP * 0.25 + tangent * 0.7
			_cam.look_at(target + Vector3.UP * 0.05)
			await _save("%s_%s.png" % [entry.name, focus])
			if focus == "curtain":
				_cam.position = target + normal * 3.2 + Vector3.UP * 0.15 + tangent * 2.4
				_cam.look_at(target + Vector3.UP * 0.05)
				await _save("%s_curtain_oblique.png" % entry.name)
			if focus == "tower":
				_cam.position = target + normal * 4.0 + Vector3.UP * 0.15 + tangent * 2.7
				_cam.look_at(target + Vector3.UP * 0.05)
				await _save("%s_tower_oblique.png" % entry.name)
			_vp.size = Vector2i(960, 1400)
			_cam.fov = 45.0
			_cam.position = target + normal * 15.0 + Vector3.UP * 4.0 + tangent * 3.0
			_cam.look_at(target + Vector3.UP * 0.1)
			await _save("%s_%s_context.png" % [entry.name, focus])
			_vp.size = SIZE
			_cam.fov = 28.0
		castle.queue_free()
		await process_frame
	print("Castle aperture detail renders complete: ", _out)
	quit()


func _entries() -> Array[Dictionary]:
	return [
		{"name": "bodiam", "style": &"edwardian", "tier": &"castle",
			"width": 55.0, "length": 50.0, "height": 18.0, "seed": 6001},
		{"name": "krak", "style": &"crusader", "tier": &"fortress",
			"width": 300.0, "length": 140.0, "height": 20.0, "seed": 6002},
	]


func _spec(entry: Dictionary) -> CastleSpec:
	var spec := CastleSpec.new()
	spec.style = entry.style
	spec.tier_override = entry.tier
	spec.width = entry.width
	spec.length = entry.length
	spec.height = entry.height
	CastleGenerator.generate(spec, entry.seed)
	CastleLandmarkSuite._force_features(entry.name, spec)
	# Both landmarks default to a round or shell keep. VIS-006's new shell
	# window cut is square-only, so fix the render fixture to a square keep.
	spec.keep_shape = &"square"
	return spec


func _opening_for(parts: Array, focus: String) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for row in parts:
		if row.get("kind") == "window" and String(row.get("tag", "")) == focus:
			candidates.append(row)
	if candidates.is_empty():
		return {}
	if focus == "keep":
		for row in candidates:
			if Vector3(row.facing).z < -0.8:
				return row
	return candidates[0]


func _save(file: String) -> void:
	for i in range(4):
		await process_frame
		await RenderingServer.frame_post_draw
	var result := _vp.get_texture().get_image().save_png(_out + "/" + file)
	if result != OK:
		push_error("Could not save " + file)
	else:
		print("  ", file)


## These positions and face normals come from the changed build's chosen keep
## openings. Both baseline and changed scenes use them, so image composition
## does not move when the number/order of logged windows changes.
func _changed_keep_target(name: String) -> Dictionary:
	if name == "bodiam":
		return {"position": Vector3(0.0, 21.16103, 10.94883),
			"facing": Vector3(0.0, 0.0, -1.0)}
	return {"position": Vector3(-5.191888, 13.82884, 27.54433),
		"facing": Vector3(0.0, 0.0, -1.0)}


## Isolated fixture keeps the comparison readable when landmark foreground
## masses hide the shell. Baseline is a solid box with the old recessed face
## opening; current geometry removes the box at the window and adds returns.
func _render_square_keep_fixture() -> void:
	var spec := CastleSpec.new()
	spec.window_w = 2.0
	spec.window_h = 2.5
	spec.wall_thickness = 1.0
	spec.window_style = &"slit"
	var bounds := AABB(Vector3(-5.0, 0.0, -5.0), Vector3(10.0, 12.0, 10.0))
	var target := Vector3(0.0, 6.0, -5.0 - CastleGeometry.OPENING_EPS)
	var normal := Vector3(0.0, 0.0, -1.0)
	var tangent := Vector3(1.0, 0.0, 0.0)
	for state in ["before", "after"]:
		var builder := CastleBuilder.new()
		builder.begin_metric(4)
		builder.spec = spec
		if state == "before":
			builder._box_aabb(bounds, CastleBuilder.SURF_STONE)
			builder._face_openings(bounds, 6.0, spec.window_style, [], 20.0)
		else:
			builder._cut_keep_shell(bounds, 6.0)
			builder._keep_windows(bounds, 6.0, spec.window_style)
		var mesh: ArrayMesh = builder.commit()
		var keep := ShellAssembler.build("KeepFixture", mesh,
			[spec.stone_color, spec.trim_color, spec.roof_color, Color("1a1c20")],
			builder.prop_log, CastleBuilder.SURF_ROOF, false, LightKit.FLAME, false)
		_stage.add_child(keep)
		_vp.size = SIZE
		_cam.fov = 28.0
		_cam.position = target + normal * 4.0 + Vector3.UP * 0.25 + tangent * 0.7
		_cam.look_at(target + Vector3.UP * 0.05)
		await _save("square_keep_%s_front.png" % state)
		_cam.position = target + normal * 4.0 + Vector3.UP * 0.15 + tangent * 2.7
		_cam.look_at(target + Vector3.UP * 0.05)
		await _save("square_keep_%s_raking.png" % state)
		keep.queue_free()
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
	sky_mat.sky_top_color = Color("5c7ea8")
	sky_mat.sky_horizon_color = Color("cfd8e0")
	sky_mat.ground_bottom_color = Color("52584a")
	sky_mat.ground_horizon_color = Color("97a08c")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	_stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -36, 0)
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	_stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-14, 140, 0)
	fill.light_energy = 0.8
	_stage.add_child(fill)
	_cam = Camera3D.new()
	_cam.fov = 28.0
	_cam.far = 4000.0
	_vp.add_child(_cam)
