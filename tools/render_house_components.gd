extends SceneTree
## HOUSE-EXT-005 reference renders, written to artifacts/renders/components/.
##
## A logging change moves no vertices, so a photograph of the house proves
## nothing. These shots photograph the LOG instead:
##
##   *_actual.jpg      the house as the builder emits it
##   *_components.jpg  the same house rebuilt FROM component_log ALONE, with
##                     each host in its own colour. Where this is solid, the
##                     log knows what was emitted; where it is see-through,
##                     the log does not.
##   *_fault.jpg       the faulty fixture: one logged component emitted in the
##                     wrong place. The gap is what ComponentCheck catches.
##
##   godot --path . --script res://tools/render_house_components.gd
## Must NOT be headless: the dummy renderer writes no image.

const Faulty := preload("res://tests/fixtures/faulty_house_builder.gd")
const OUT := "res://artifacts/renders/components"
const SIZE := Vector2i(1280, 860)

## One surface per host family, so the render says WHOSE each piece is.
const GROUPS: Array[Dictionary] = [
	{"key": "roof", "color": Color("b8503c")},
	{"key": "dormer", "color": Color("e8a33d")},
	{"key": "porch", "color": Color("9b6bc4")},
	{"key": "frame", "color": Color("5a3d28")},
	{"key": "opening", "color": Color("3fa8c4")},
	{"key": "jetty", "color": Color("d8cf5a")},
]

var _vp: SubViewport
var _cam: Camera3D
var _root3d: Node3D
var _mesh_inst: MeshInstance3D
var _last_colors: Array = []


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_stage()
	await process_frame
	for row in [
			{"key": "town", "style": &"townhouse", "w": 9.0, "l": 12.0, "h": 2.7,
				"storeys": 2, "seed": 4411, "fault_role": "dormer_0_cheek"},
			{"key": "farm", "style": &"farmhouse", "w": 10.0, "l": 13.0, "h": 2.7,
				"storeys": 1, "seed": 4413, "fault_role": "roof_face_0"},
			{"key": "hall", "style": &"longhall", "w": 12.0, "l": 16.0, "h": 2.7,
				"storeys": 1, "seed": 4414, "fault_role": "verge_board"},
		]:
		await _shots(row)
	print("done")
	quit()


func _shots(row: Dictionary) -> void:
	var spec := HouseSpec.new()
	spec.style = row["style"]
	spec.width = float(row["w"])
	spec.length = float(row["l"])
	spec.height = float(row["h"])
	spec.storeys = int(row["storeys"])
	var plan: HousePlan = HouseGenerator.generate(spec, int(row["seed"]), false)
	var key: String = String(row["key"])

	var builder := HouseBuilder.new()
	var mesh: ArrayMesh = builder.build(plan)
	var aabb: AABB = mesh.get_aabb()
	var report := ComponentCheck.check(builder, mesh)
	var hosts := builder.component_hosts()
	print("  %s  roof=%s  components=%d  hosts=%d  measured=%d unverified=%d  ok=%s"
		% [key, String(spec.roof_type), builder.component_log.size(), hosts.size(),
			int(report["checked"]), int(report["unverified"]), str(report["ok"])])

	_set_mesh(mesh, [spec.wall_color, spec.trim_color, spec.roof_color,
		spec.floor_color])
	await _three_quarter(aabb, "house_%s_actual.jpg" % key)

	var log_mesh := _from_log(builder.component_log)
	_set_mesh(log_mesh, _last_colors)
	await _three_quarter(aabb, "house_%s_components.jpg" % key)

	var broken = Faulty.new()
	broken.fault = Faulty.Fault.MOVE
	broken.fault_role = String(row["fault_role"])
	broken.move_by = Vector3(0.0, 1.1, 1.1)
	var broken_mesh: ArrayMesh = broken.build(plan)
	var broken_report := ComponentCheck.check(broken, broken_mesh)
	print("    fault '%s' moved -> check ok=%s  %s" % [broken.fault_role,
		str(broken_report["ok"]), ", ".join(broken_report["failures"])])
	_set_mesh(broken_mesh, [spec.wall_color, spec.trim_color, spec.roof_color,
		spec.floor_color])
	await _three_quarter(aabb, "house_%s_fault.jpg" % key)
	_mesh_inst.mesh = null


## Rebuild a mesh out of the log and nothing else. This is the whole claim of
## HOUSE-EXT-005 made visible: if the log is honest and complete, the exterior
## comes back.
func _from_log(log: Array[Dictionary]) -> ArrayMesh:
	# A group with nothing in it must not get a surface: SurfaceTool.commit()
	# skips an empty surface, and every colour after the gap would then be
	# painted onto the wrong parts of the house.
	var used: Array[int] = []
	for r in log:
		var g := _group_of(String(r["host"]))
		# Only forms this tool can actually re-emit count as filling a group.
		# A component_note row (the porch roof) claims a group and draws
		# nothing, which is exactly the empty surface that shifts the colours.
		if not used.has(g) and ComponentCheck.MEASURABLE.has(r["form"]):
			used.append(g)
	used.sort()
	_last_colors = []
	for g in used:
		_last_colors.append(GROUPS[g]["color"])
	var kit := MeshKit.new(used.size())
	for r in log:
		var surf := used.find(_group_of(String(r["host"])))
		if surf < 0:
			continue
		match r["form"]:
			"box":
				kit.oriented_box(r["size"], r["xf"], surf)
			"slab":
				kit.slab_poly(r["points"], float(r["depth"]), surf,
					bool(r["vertical"]))
			_:
				pass    # component_note rows carry no reproducible shape
	var names := PackedStringArray()
	for g in used:
		names.append(String(GROUPS[g]["key"]))
	print("    groups drawn: %s" % ", ".join(names))
	return kit.commit()


static func _group_of(host: String) -> int:
	for i in range(GROUPS.size()):
		if host.begins_with(String(GROUPS[i]["key"])):
			return i
	for i in range(GROUPS.size()):
		if String(GROUPS[i]["key"]) == "opening":
			return i
	return 0


func _three_quarter(aabb: AABB, file: String) -> void:
	var c: Vector3 = aabb.get_center()
	var top: float = aabb.position.y + aabb.size.y
	var reach: float = maxf(aabb.size.x, aabb.size.z)
	await _look(Vector3(c.x + reach * 1.5, top * 1.9, aabb.position.z - reach * 1.5),
		Vector3(c.x, top * 0.55, c.z), file)


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
	img.save_jpg(OUT + "/" + file, 0.92)
	print("    ", file)


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
