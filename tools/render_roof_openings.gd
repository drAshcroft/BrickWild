extends SceneTree
## HOUSE-EXT-007 reference renders, written to artifacts/renders/openings/.
##
##   *_house.jpg   the dormers as built, from the dormer side
##   *_holes.jpg   ONLY the main roof faces, so the dormer-shaped holes cut in
##                 them are visible. If the subtraction stopped happening this
##                 image would be a plain unbroken slope.
##   *_lifted.jpg  a cheek displaced 0.35 m off the slope: the slot of daylight
##                 down the side of the dormer that RoofOpeningCheck reports.
##   *_hip.jpg     a cheek slid 8.5 m along the ridge, past the hip line and
##                 clear of every face.
##
##   godot --path . --script res://tools/render_roof_openings.gd
## Must NOT be headless: the dummy renderer writes no image.

const Faulty := preload("res://tests/fixtures/faulty_house_builder.gd")
const OUT := "res://artifacts/renders/openings"
## HouseSpec leaves its colours unset; only HouseGenerator assigns a palette,
## and these fixtures are planned straight from a spec. Unset Colors are black,
## which renders a perfectly correct house as a silhouette.
const PALETTE: Array[Color] = [Color("d9cfb8"), Color("f2efe6"),
	Color("55617a"), Color("6b5a44")]
const SIZE := Vector2i(1280, 860)

var _vp: SubViewport
var _cam: Camera3D
var _root3d: Node3D
var _mesh_inst: MeshInstance3D


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_stage()
	await process_frame
	await _shots(&"gable", "gable")
	await _shots(&"hipped", "hipped")
	print("done")
	quit()


func _spec(kind: StringName) -> HouseSpec:
	var s := HouseSpec.new()
	s.width = 9.0
	s.length = 14.0
	s.height = 2.7
	s.storeys = 2
	s.roof_type = kind
	s.roof_pitch = 1.0
	s.room_count = 1
	s.program = [&"hall"]
	s.dormers = true
	s.dormer_count = 3
	s.chimney = false
	s.porch = false
	s.timber_frame = false
	s.bargeboards = false
	return s


func _shots(kind: StringName, key: String) -> void:
	var spec := _spec(kind)
	var plan := HousePlanner.plan(spec)
	var builder := HouseBuilder.new()
	var mesh := builder.build(plan)
	var openings := HouseGeometry.roof_openings(plan)
	print("  %s: %d dormers fitted, %d rejected"
		% [key, openings.size(), HouseGeometry.roof_opening_rejections(plan).size()])

	var aabb := mesh.get_aabb()
	_set_mesh(mesh, PALETTE)
	await _dormer_side(aabb, "%s_house.jpg" % key)

	# The main roof faces alone. The holes are the evidence.
	_set_mesh(_faces_only(builder), [Color("b8503c")])
	await _above(aabb, "%s_holes.jpg" % key)

	await _fault(plan, aabb, "dormer_0_cheek", Vector3(0, 0.35, 0),
		"%s_lifted.jpg" % key)
	# Sliding along the ridge only leaves the host on a roof that HAS a hip.
	# On a gable it stays on the same face and is correctly not a defect, so
	# there is nothing to photograph.
	if kind == &"hipped":
		await _fault(plan, aabb, "dormer_0_cheek", Vector3(0, 0, 8.5),
			"%s_hip.jpg" % key)
	_mesh_inst.mesh = null


func _fault(plan: HousePlan, aabb: AABB, role: String, by: Vector3,
		file: String) -> void:
	var broken = Faulty.new()
	broken.fault = Faulty.Fault.DISPLACE
	broken.fault_role = role
	broken.move_by = by
	var mesh: ArrayMesh = broken.build(plan)
	var report := RoofOpeningCheck.check(plan, broken, mesh)
	print("    %s -> ok=%s  %s" % [file, str(report["ok"]),
		", ".join(report["failures"])])
	_set_mesh(mesh, PALETTE)
	await _close(plan, file)


## Tight on the FIRST dormer, which is the one the fixtures break. A defect
## measured in centimetres is not legible in a whole-house elevation.
func _close(plan: HousePlan, file: String) -> void:
	var layout := HouseGeometry.roof_layout(plan)
	var dormers: Array = layout["dormers"]
	if dormers.is_empty():
		return
	var d: Dictionary = dormers[0]
	var xf: Transform3D = layout["transform"]
	var at: Vector3 = xf * Vector3(float(d["front"]), float(d["eave"]), float(d["z"]))
	await _look(at + Vector3(-4.2, 1.4, -3.4), at, file)


## Only the components that ARE the main roof: what the dormers were cut out of.
func _faces_only(builder: HouseBuilder) -> ArrayMesh:
	var kit := MeshKit.new(1)
	for c in builder.components("roof_face_"):
		kit.slab_poly(c["points"], float(c["depth"]), 0, bool(c["vertical"]))
	return kit.commit()


## The negative roof-local-X side, which is the side the dormers are on.
func _dormer_side(aabb: AABB, file: String) -> void:
	var c := aabb.get_center()
	var top: float = aabb.position.y + aabb.size.y
	var reach: float = maxf(aabb.size.x, aabb.size.z)
	await _look(Vector3(c.x - reach * 1.15, top * 1.02, aabb.position.z - reach * 0.75),
		Vector3(c.x, top * 0.74, c.z), file)


func _above(aabb: AABB, file: String) -> void:
	var c := aabb.get_center()
	var top: float = aabb.position.y + aabb.size.y
	var reach: float = maxf(aabb.size.x, aabb.size.z)
	await _look(Vector3(c.x - reach * 0.95, top * 1.75, aabb.position.z - reach * 0.55),
		Vector3(c.x, top * 0.80, c.z), file)


func _set_mesh(mesh: ArrayMesh, cols: Array) -> void:
	_mesh_inst.mesh = mesh
	for i in range(mesh.get_surface_count()):
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[i] if i < cols.size() else Color("888888")
		m.roughness = 0.9
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
	img.save_jpg(OUT + "/" + file, 0.93)
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
	env.ambient_light_energy = 1.05
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_root3d.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(-52.0), 0.0)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	_root3d.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-16.0), deg_to_rad(130.0), 0.0)
	fill.light_energy = 0.45
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
	_cam.fov = 44.0
	_cam.far = 4000.0
	_vp.add_child(_cam)
