extends SceneTree
## Renders reference images of the generator's output to artifacts/renders/.
##
## Must run WITHOUT --headless: the headless dummy renderer cannot produce an
## image. It draws into a SubViewport, so no window content is captured.
##
## Run: godot --path . --script res://tools/render_shots.gd

const OUT_DIR := "res://artifacts/renders"
const SHOT := Vector2i(1100, 760)
const SHEET := Vector2i(900, 1180)

var _vp: SubViewport
var _cam: Camera3D
var _root3d: Node3D
var _mesh_inst: MeshInstance3D


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_build_stage()
	await process_frame

	var manifest: Array[Dictionary] = []

	# ---- the landmark churches, three-quarter view ----
	for entry in _landmarks():
		var spec: ChurchSpec = _landmark_spec(entry)
		var file: String = "%s.jpg" % entry["key"]
		await _shoot_church(spec, file, 0.72, -0.28, 1.0)
		manifest.append(_describe(entry, spec, file))

	# ---- feature close-ups ----
	for shot in _detail_shots():
		var spec: ChurchSpec = _landmark_spec(shot["entry"])
		var f: Array = _focus_of(spec, shot["focus"])
		await _shoot_church(spec, shot["file"], shot["yaw"], shot["pitch"], 1.0,
			f[0], f[1])
		manifest.append({"key": shot["file"].get_basename(), "title": shot["title"],
			"caption": shot["caption"], "file": shot["file"], "kind": "detail"})

	# ---- blueprint sheets ----
	for entry in _landmarks():
		if not entry.get("sheet", false):
			continue
		var spec: ChurchSpec = _landmark_spec(entry)
		var file: String = "sheet_%s.jpg" % entry["key"]
		await _shoot_sheet(spec, file)
		manifest.append({"key": "sheet_" + entry["key"],
			"title": "%s — blueprint sheet" % entry["title"],
			"caption": "Plan and south elevation, drawn from the same ChurchGeometry the mesh uses.",
			"file": file, "kind": "sheet"})

	var f := FileAccess.open(OUT_DIR + "/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "\t"))
	f.close()
	print("wrote %d images to %s" % [manifest.size(), OUT_DIR])
	quit()


# ------------------------------------------------------------------ subjects

func _landmarks() -> Array[Dictionary]:
	return [
		{"key": "notre_dame", "style": &"gothic", "title": "Notre-Dame de Paris",
			"w": 12.0, "l": 127.0, "h": 33.0, "seed": 5001, "sheet": true,
			"feat": "flying buttresses, twin west towers, double aisles"},
		{"key": "cologne", "style": &"gothic", "title": "Cologne Cathedral",
			"w": 14.0, "l": 144.0, "h": 43.0, "seed": 5002,
			"feat": "five-aisled, twin spires, flying buttresses"},
		{"key": "chartres", "style": &"gothic", "title": "Chartres Cathedral",
			"w": 16.4, "l": 130.0, "h": 37.5, "seed": 5003, "sheet": true,
			"feat": "double ambulatory, seven radiating chapels"},
		{"key": "salisbury", "style": &"gothic", "title": "Salisbury Cathedral",
			"w": 12.0, "l": 135.0, "h": 26.0, "seed": 5004,
			"feat": "single dominant crossing spire"},
		{"key": "durham", "style": &"romanesque", "title": "Durham Cathedral",
			"w": 11.9, "l": 61.0, "h": 22.2, "seed": 5005,
			"feat": "central lantern tower plus twin west towers"},
		{"key": "hagia_sophia", "style": &"byzantine", "title": "Hagia Sophia",
			"w": 31.0, "l": 76.0, "h": 40.0, "seed": 5006, "sheet": true,
			"feat": "great dome on pendentives, braced by half-domes"},
		{"key": "florence_duomo", "style": &"renaissance", "title": "Florence Duomo",
			"w": 17.0, "l": 153.0, "h": 45.0, "seed": 5007,
			"feat": "octagonal drum, double-shell dome, lantern"},
		{"key": "st_basil", "style": &"russian", "title": "St Basil's Cathedral",
			"w": 12.0, "l": 46.0, "h": 30.0, "seed": 5008, "sheet": true,
			"feat": "onion domes over a cluster of chapels"},
	]


func _detail_shots() -> Array[Dictionary]:
	var lm: Array[Dictionary] = _landmarks()
	return [
		{"entry": lm[0], "file": "detail_flyers.jpg", "focus": "flyers",
			"yaw": 1.25, "pitch": -0.16, "title": "Flying buttresses",
			"caption": "Pier, parabolic flyer arch and pinnacle, sized to the wall they brace."},
		{"entry": lm[5], "file": "detail_dome.jpg", "focus": "dome",
			"yaw": 0.85, "pitch": -0.20, "title": "Dome on pendentives",
			"caption": "Pendentive course, the window corona round the drum, and the buttressing half-domes."},
		{"entry": lm[2], "file": "detail_chapels.jpg", "focus": "chevet",
			"yaw": 2.55, "pitch": -0.36, "title": "Radiating chapels",
			"caption": "Alcoves fanned off the ambulatory. The fan angle is solved from the geometry, not fixed."},
		{"entry": lm[7], "file": "detail_onion.jpg", "focus": "dome",
			"yaw": 0.70, "pitch": -0.14, "title": "Onion dome",
			"caption": "An ogee profile that bulges past its springing radius, then draws in to a point."},
		{"entry": lm[6], "file": "detail_lantern.jpg", "focus": "dome",
			"yaw": 1.05, "pitch": -0.18, "title": "Octagonal drum and lantern",
			"caption": "Eight-sided drum carrying the shell, capped by a lantern."},
		{"entry": lm[4], "file": "detail_crossing.jpg", "focus": "crossing",
			"yaw": 0.95, "pitch": -0.24, "title": "Crossing tower",
			"caption": "A lantern tower on the crossing bay, hipped to the rectangle it stands on."},
	]


## Where to point the camera, and how much around it to fit in frame.
func _focus_of(spec: ChurchSpec, kind: String) -> Array:
	match kind:
		"flyers":
			var mid: int = int(ChurchGeometry.flyer_count(spec) / 2)
			return [Vector3(ChurchGeometry.flyer_pier_x(spec, 1.0), spec.height * 0.5,
				ChurchGeometry.flyer_z(spec, mid)), spec.height * 0.62]
		"dome":
			return [Vector3(0.0, ChurchGeometry.dome_base_height(spec)
				+ spec.dome_drum_height * 0.5 + ChurchGeometry.dome_shell_rise(spec) * 0.45,
				ChurchGeometry.crossing_center_z(spec)),
				ChurchGeometry.dome_plan_radius(spec) * 1.9]
		"chevet":
			return [Vector3(0.0, spec.height * 0.28,
				ChurchGeometry.apse_springing_z(spec) + spec.apse_radius * 0.6),
				ChurchGeometry.ambulatory_radius(spec) * 2.1]
		"crossing":
			return [Vector3(0.0, spec.crossing_tower_height * 0.62,
				ChurchGeometry.crossing_center_z(spec)), spec.crossing_tower_height * 0.72]
	return [Vector3.ZERO, 20.0]


func _landmark_spec(entry: Dictionary) -> ChurchSpec:
	var spec := ChurchSpec.new()
	spec.style = entry["style"]
	spec.width = entry["w"]
	spec.length = entry["l"]
	spec.height = entry["h"]
	ChurchGenerator.generate(spec, entry["seed"])
	_force_features(spec, entry["key"])
	return spec


## The generator is probabilistic; these portraits must show the feature the
## church is famous for, so force it on and give it a size if it has none.
func _force_features(spec: ChurchSpec, key: String) -> void:
	match key:
		"notre_dame":
			spec.west_towers = 2
			spec.aisles = 2
			spec.flying_buttresses = true
			spec.apse = true
		"cologne":
			spec.west_towers = 2
			spec.aisles = 2
			spec.flying_buttresses = true
			spec.tower_roof = &"spire"
		"chartres":
			spec.flying_buttresses = true
			spec.apse = true
			spec.ambulatory = true
			spec.radiating_chapels = 7
		"salisbury":
			spec.transept = true
			spec.crossing_tower = true
			spec.tower_roof = &"spire"
		"durham":
			spec.west_towers = 2
			spec.transept = true
			spec.crossing_tower = true
		"hagia_sophia":
			spec.dome = true
			spec.dome_shape = &"hemisphere"
			spec.half_domes = true
			spec.exedrae = true
		"florence_duomo":
			spec.dome = true
			spec.dome_shape = &"octagonal"
			spec.dome_lantern = true
			spec.transept = true
		"st_basil":
			spec.dome = true
			spec.dome_shape = &"onion"
			spec.radiating_chapels = 8
			spec.chapel_arrangement = &"cluster"
	# backfill any size the generator left at zero, then re-settle the ring
	if spec.tower and spec.tower_width <= 0.0:
		spec.tower_width = spec.width * 0.55
		spec.tower_height = spec.height * 1.5
	if spec.west_towers >= 2:
		spec.tower_width = minf(spec.tower_width, ChurchGeometry.max_twin_tower_width(spec))
	if spec.aisles > 0 and spec.aisle_width <= 0.0:
		spec.aisle_width = spec.width * 0.28
	if spec.apse and spec.apse_radius <= 0.0:
		spec.apse_radius = spec.width * 0.42
	if spec.crossing_tower and spec.crossing_tower_height <= 0.0:
		spec.crossing_tower_height = spec.height * 1.7
	if spec.dome:
		if spec.dome_radius <= 0.0:
			spec.dome_radius = spec.width * 0.45
		if spec.dome_drum_height <= 0.0:
			spec.dome_drum_height = spec.dome_radius * ChurchGeometry.DOME_DRUM_RATIO
		spec.roof_pitch = minf(spec.roof_pitch, 0.40)
		spec.dome_drum_height = maxf(spec.dome_drum_height,
			ChurchGeometry.min_drum_height(spec))
	if spec.radiating_chapels > 0:
		if spec.chapel_radius <= 0.0:
			spec.chapel_radius = spec.width * 0.2
		ChurchGenerator._fit_chapels(spec)
	if spec.flying_buttresses:
		spec.buttresses = true
		spec.buttress_count_per_side = maxi(spec.buttress_count_per_side, 5)


# -------------------------------------------------------------------- stage

func _build_stage() -> void:
	_vp = SubViewport.new()
	_vp.size = SHOT
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
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	_root3d.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(-131.0), 0.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	_root3d.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-16.0), deg_to_rad(58.0), 0.0)
	fill.light_energy = 0.35
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
	_cam.fov = 48.0
	_cam.far = 4000.0
	_vp.add_child(_cam)


# -------------------------------------------------------------------- shoot

func _shoot_church(spec: ChurchSpec, file: String, yaw: float, pitch: float,
		zoom := 1.0, focus := Vector3.INF, frame_radius := 0.0) -> void:
	var builder := ChurchBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	_mesh_inst.mesh = mesh
	var cols := [spec.stone_color, spec.trim_color, spec.roof_color, Color("15171b")]
	for i in range(mesh.get_surface_count()):
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[i]
		m.roughness = 0.92
		_mesh_inst.set_surface_override_material(i, m)

	var aabb: AABB = mesh.get_aabb()
	var centre: Vector3 = aabb.get_center()
	var radius: float = maxf(aabb.size.length() / 2.0, 1.0)
	if focus.x != INF:
		centre = focus
		radius = maxf(frame_radius, 1.0)
	var dist: float = radius / tan(deg_to_rad(_cam.fov) / 2.0) * 1.12 * zoom
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	_cam.position = centre + dir * dist
	_cam.look_at(centre, Vector3.UP)
	await _capture(file)


func _shoot_sheet(spec: ChurchSpec, file: String) -> void:
	var vp := SubViewport.new()
	vp.size = SHEET
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var view := BlueprintView.new()
	view.size = Vector2(SHEET)
	vp.add_child(view)
	view.setup(spec)
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	img.save_jpg(OUT_DIR + "/" + file, 0.92)
	print("  ", file)
	vp.queue_free()


func _capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	img.save_jpg(OUT_DIR + "/" + file, 0.9)
	print("  ", file)


func _describe(entry: Dictionary, spec: ChurchSpec, file: String) -> Dictionary:
	var bits: Array[String] = []
	if spec.west_towers >= 2:
		bits.append("twin west towers")
	elif spec.west_towers == 1:
		bits.append("west tower")
	if spec.flying_buttresses:
		bits.append("%d flying buttresses/side%s"
			% [spec.buttress_count_per_side, ", 2 tiers" if spec.flyer_tiers > 1 else ""])
	if spec.aisles > 0:
		bits.append("%d aisle ring%s" % [spec.aisles, "s" if spec.aisles > 1 else ""])
	if spec.transept:
		bits.append("transept")
	if spec.crossing_tower:
		bits.append("crossing tower")
	if spec.dome:
		bits.append("%s dome%s" % [String(spec.dome_shape),
			" + lantern" if spec.dome_lantern else ""])
	if spec.half_domes:
		bits.append("half-domes")
	if spec.ambulatory:
		bits.append("ambulatory")
	if spec.radiating_chapels > 0:
		bits.append("%d chapels (%s)" % [spec.radiating_chapels,
			String(spec.chapel_arrangement)])
	if spec.narthex:
		bits.append("narthex")
	return {
		"key": entry["key"], "title": entry["title"], "file": file, "kind": "landmark",
		"famous_for": entry["feat"],
		"dims": "%.1f x %.0f x %.1f m" % [spec.width, spec.length, spec.height],
		"height": "%.1f m to the top" % ChurchGeometry.total_height(spec),
		"built": ", ".join(bits),
		"variant": spec.variant_name,
	}
