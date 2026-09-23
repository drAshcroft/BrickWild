extends SceneTree
## Roof and exterior dressing references, written to artifacts/roof_fix/.
## Use --full to include the slow interior furnishing decisions in the plan.
##
##   godot --path . --script res://tools/render_house_roofs.gd

const OUT := "res://artifacts/roof_fix"
const SIZE := Vector2i(1200, 820)

var _vp: SubViewport
var _cam: Camera3D
var _root3d: Node3D
var _mesh_inst: MeshInstance3D
var _evidence: Array[Dictionary] = []
var _directory := OUT


func _init() -> void:
	if OS.get_cmdline_user_args().has("--matrix"):
		_directory = "res://artifacts/p1p2_house/art_before" if OS.get_cmdline_user_args().has("--before-art") else "res://artifacts/p1p2_house/art_after"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_directory))
	_stage()
	await process_frame
	if OS.get_cmdline_user_args().has("--matrix"):
		for style in HouseSweep.styles():
			for i in HouseSweep.SIZES.size():
				for levels in [1, 2]:
					var size: Dictionary = HouseSweep.SIZES[i]
					await _roof_shots({"key": "%s_%d_%d" % [style, i, levels], "style": style,
						"w": size["w"], "l": size["l"], "h": size["h"], "storeys": levels,
						"seed": HouseSweep.seed_at(style, &"none", i), "matrix": true})
		_write_evidence()
		quit()
		return

	for row in [
			{"key": "town", "style": &"townhouse", "w": 9.0, "l": 12.0, "h": 2.7,
				"storeys": 2, "seed": 4411},
			{"key": "cottage", "style": &"cottage", "w": 7.0, "l": 9.0, "h": 2.5,
				"storeys": 1, "seed": 4412},
			{"key": "farm", "style": &"farmhouse", "w": 10.0, "l": 13.0, "h": 2.7,
				"storeys": 1, "seed": 4413},
			{"key": "hall", "style": &"longhall", "w": 12.0, "l": 16.0, "h": 2.7,
				"storeys": 1, "seed": 4414},
			{"key": "smith", "style": &"cottage", "trade": &"smith", "w": 9.0, "l": 11.0, "h": 2.7,
				"storeys": 1, "seed": 4415},
			{"key": "witch", "style": &"witch_hut", "trade": &"alchemist", "w": 6.0, "l": 8.0, "h": 2.6,
				"storeys": 1, "seed": 4416},
			{"key": "small", "style": &"cottage", "w": 4.0, "l": 5.0, "h": 2.5,
				"storeys": 1, "seed": 4412},
		]:
		await _roof_shots(row)
	print("done")
	_write_evidence()
	quit()


func _roof_shots(row: Dictionary) -> void:
	var spec := HouseSpec.new()
	spec.style = row["style"]
	spec.width = float(row["w"])
	spec.length = float(row["l"])
	spec.height = float(row["h"])
	spec.storeys = int(row["storeys"])
	spec.trade = row.get("trade", &"none")
	var plan: HousePlan = HouseGenerator.generate(spec, int(row["seed"]), OS.get_cmdline_user_args().has("--full"))
	if OS.get_cmdline_user_args().has("--before-art"):
		spec.roof_pitch /= HouseGeometry.art_pitch_scale(spec)
	var mesh: ArrayMesh = HouseBuilder.new().build(plan)
	_set_mesh(mesh, BuildingFamilyAdapter.colours(spec))
	ShellAssembler.house_materials(_mesh_inst, spec)
	var aabb: AABB = mesh.get_aabb()
	HouseAssembler.dress_exterior(_root3d, plan)
	for p in plan.exterior:
		aabb = aabb.merge(HouseExterior.bounds_of(p))
	print("  props=%d omissions=%s" % [plan.exterior.size(), plan.exterior_omissions])
	var c: Vector3 = aabb.get_center()
	var top: float = aabb.position.y + aabb.size.y
	var reach: float = maxf(aabb.size.x, aabb.size.z)
	var key: String = String(row["key"])
	_evidence.append({"key": key, "style": String(spec.style), "seed": spec.seed,
		"width": spec.width, "length": spec.length, "height": spec.height, "storeys": spec.storeys,
		"roof": String(spec.roof_type), "material": String(spec.roof_material),
		"rise": HouseGeometry.roof_rise(spec), "roof_to_wall": HouseGeometry.roof_rise(spec) / (spec.height * spec.storeys),
		"props": plan.exterior.size(), "omissions": plan.exterior_omissions})
	print("  %s  aabb %s  roof_type=%s bargeboards=%s truss=%s"
		% [key, str(aabb), String(spec.roof_type), str(spec.bargeboards),
			String(spec.gable_truss)])
	if row.get("matrix", false):
		await _look(Vector3(c.x - reach * 1.5, top * 1.45, aabb.position.z - reach * 1.5),
			Vector3(c.x, top * 0.55, c.z), key + ".jpg")
		_mesh_inst.mesh = null
		_root3d.get_node("Exterior").free()
		return

	# square on the gable, from far enough that the whole end reads
	await _look(Vector3(c.x, top * 0.72, aabb.position.z - reach * 2.1),
		Vector3(c.x, top * 0.62, aabb.position.z), "roof_%s_gable.jpg" % key)
	# three-quarter from above: ridge, both slopes, the verge and the eaves
	await _look(Vector3(c.x + reach * 1.5, top * 1.9, aabb.position.z - reach * 1.5),
		Vector3(c.x, top * 0.55, c.z), "roof_%s_three_quarter.jpg" % key)
	# straight down the ridge from just above it
	await _look(Vector3(c.x, top + reach * 0.28, aabb.position.z - reach * 0.85),
		Vector3(c.x, top - 0.4, c.z), "roof_%s_ridge.jpg" % key)
	await _look(Vector3(c.x - reach * 1.5, top * 1.45, aabb.position.z - reach * 1.5), Vector3(c.x, top * 0.55, c.z), "roof_%s_left.jpg" % key)
	await _look(Vector3(c.x - reach * 1.5, top * 1.45, aabb.end.z + reach * 1.5), Vector3(c.x, top * 0.55, c.z), "roof_%s_back.jpg" % key)
	_mesh_inst.mesh = null
	_root3d.get_node("Exterior").free()


# ------------------------------------------------------------------- rigging

func _set_mesh(mesh: ArrayMesh, cols: Array) -> void:
	_mesh_inst.mesh = mesh
	for i in range(mesh.get_surface_count()):
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[i] if i < cols.size() else Color("888888")
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
	img.save_jpg(_directory + "/" + file, 0.92)
	print("    ", file)


func _write_evidence() -> void:
	var f := FileAccess.open(_directory + "/evidence.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_evidence, "\t"))
	if not OS.get_cmdline_user_args().has("--matrix"):
		return
	var html := "<!doctype html><meta charset='utf-8'><title>House art direction</title><style>body{background:#242723;color:#f2efdc;font:16px sans-serif}main{display:grid;grid-template-columns:repeat(4,1fr);gap:12px}img{width:100%}figure{margin:0}figcaption{padding:8px}</style><h1>House silhouette matrix</h1><p>Fixed seeds, camera/light rig and canonical dimensions. Rise ratios are art-direction evidence, not structural limits.</p><main>"
	for row in _evidence:
		html += "<figure><img src='%s.jpg'><figcaption>%s | %.1f × %.1f m | %d floors<br>%s / %s | rise %.2f m | roof/wall %.2f</figcaption></figure>" % [row["key"], row["style"], row["width"], row["length"], row["storeys"], row["roof"], row["material"], row["rise"], row["roof_to_wall"]]
	html += "</main>"
	FileAccess.open(_directory + "/index.html", FileAccess.WRITE).store_string(html)


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
	env.ambient_light_energy = 1.1
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_root3d.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(-128.0), 0.0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	_root3d.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-14.0), deg_to_rad(62.0), 0.0)
	fill.light_energy = 0.5
	_root3d.add_child(fill)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
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
