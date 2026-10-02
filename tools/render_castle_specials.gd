extends SceneTree
## Deterministic non-headless reference renders for the special castle plans.
##
## Run with the real renderer (the headless renderer writes no image):
##   godot --path . --script res://tools/render_castle_specials.gd
##
## Outputs are PNGs under artifacts/renders/specials/:
##   tower_house_{roof_on,roof_off,entrance,interior}.png
##   motte_{roof_on,roof_off,entrance,interior}.png

const OUT := "res://artifacts/renders/specials"
const SIZE := Vector2i(1400, 1000)
const Interiors = preload("res://src/castle/castle_interiors.gd")
const TowerPlan = preload("res://src/castle/castle_tower_plan.gd")
const MottePlan = preload("res://src/castle/castle_motte_plan.gd")

var _vp: SubViewport
var _cam: Camera3D
var _stage: Node3D


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_stage()
	await process_frame
	var options := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if "--motte-revision" in options:
		if not await _motte_revision_shots():
			quit(1)
			return
	elif "--motte-only" in options:
		await _motte_shots()
	else:
		await _tower_house_shots()
		await _motte_shots()
	print("Castle special renders complete: ", OUT)
	quit()


func _tower_house_spec() -> CastleSpec:
	var spec := CastleSpec.new()
	spec.style = &"wizard"
	spec.width = 9.0
	spec.length = 9.0
	spec.height = 45.0
	spec.plan_override = &"tower_house"
	CastleGenerator.generate(spec, 8803)
	return spec


func _motte_spec() -> CastleSpec:
	var spec := CastleSpec.new()
	spec.style = &"norman"
	spec.width = 90.0
	spec.length = 110.0
	spec.height = 12.0
	spec.plan_override = &"motte_bailey"
	CastleGenerator.generate(spec, 8806)
	return spec


## One assembled small fixture exposes the revised doorway and wall flue.
func _motte_revision_shots() -> bool:
	var spec := CastleSpec.new()
	spec.style = &"norman"
	spec.width = 45.0
	spec.length = 55.0
	spec.height = 6.0
	spec.plan_override = &"motte_bailey"
	CastleGenerator.generate(spec, 8856)
	# A README capture must pass the same physical contract as its fixture.
	# Refuse to replace the evidence image with a castle the rig rejects.
	var checked_builder := CastleBuilder.new()
	var checked_mesh := checked_builder.build(spec)
	var report := CastleQA.new().check(spec, checked_mesh, checked_builder)
	var report_path := OUT + "/motte_revision_qa.json"
	FileAccess.open(report_path, FileAccess.WRITE).store_string(JSON.stringify({
		"seed": 8856, "width": 45, "length": 55, "height": 6,
		"ok": report.ok, "failures": report.failures,
		"warnings": report.warnings, "stats": report.stats}, "  "))
	if not report.ok:
		push_error("README castle failed physical QA: " + str(report.failures))
		return false
	var castle := CastleAssembler.build(spec)
	_stage.add_child(castle)
	var keep := CastleGeometry.shell_keep_aabb(spec)
	var centre := keep.get_center()
	_cam.position = centre + Vector3(-30.0, 20.0, -34.0)
	_cam.look_at(centre + Vector3.DOWN * 3.0)
	await _save("motte_revision_hero.png")
	var pose := _door_pose(spec, "keep_shell")
	_cam.position = Vector3(pose.world) + Vector3(pose.normal) * 14.0 + Vector3(5.0, 4.0, 0.0)
	_cam.look_at(Vector3(pose.world) + Vector3.DOWN * 1.0)
	await _save("motte_revision_entrance.png")
	var plan := MottePlan.generate(spec, false)
	var flue := MottePlan.flue(plan, spec.merlon_h + 0.45)
	var at := MottePlan.origin(spec) + Transform3D(flue.transform).origin
	_cam.position = at + Vector3(-10.0, 6.0, -10.0)
	_cam.look_at(at)
	await _save("motte_revision_flue.png")
	_cam.position = Vector3(65.0, 65.0, -82.0)
	_cam.look_at(Vector3(0.0, 5.0, -6.0))
	await _save("motte_revision_ward.png")
	castle.free()
	return true


func _tower_house_shots() -> void:
	var entrances_only := "--entrances" in OS.get_cmdline_args()
	var spec := _tower_house_spec()
	var bounds: AABB = CastleGeometry.tower_house_aabb(spec)
	print("tower_house: ", spec.tower_storeys, " storeys, roof=", spec.tower_roof,
		" bounds=", bounds)
	if not entrances_only:
		for cutaway in [false, true]:
			var castle := CastleAssembler.build(spec, cutaway)
			_stage.add_child(castle)
			var centre := bounds.get_center()
			var span := maxf(bounds.size.x, bounds.size.z)
			_cam.position = centre + Vector3(span * 2.1, bounds.size.y * 0.95, -span * 2.1)
			_cam.look_at(centre + Vector3.UP * bounds.size.y * 0.22)
			await _save("tower_house_%s.png" % ("roof_off" if cutaway else "roof_on"))
			castle.free()

	var entrance := CastleAssembler.build(spec, true)
	_stage.add_child(entrance)
	var tower_door := _door_pose(spec, "tower_house")
	var door_target: Vector3 = tower_door.world
	var tower_tangent := Vector3(-tower_door.normal.z, 0.0, tower_door.normal.x).normalized()
	_cam.position = door_target + tower_door.normal * 16.0 + Vector3.UP * 3.0 + tower_tangent * 4.0
	_cam.look_at(door_target + Vector3.UP * 0.25)
	var tower_witness := _add_witness(tower_door)
	await _save("tower_house_entrance.png")
	tower_witness.queue_free()
	entrance.free()
	if entrances_only:
		return

	var interior := CastleAssembler.build(spec, true)
	_stage.add_child(interior)
	# Roof-off exposes the top platform; aim down at the upper windows and
	# balcony rings so this is a useful cutaway inspection angle even though the
	# tower's masonry walls remain closed.
	var upper := Vector3(bounds.position.x + bounds.size.x * 0.5,
		bounds.position.y + bounds.size.y * 0.72, bounds.position.z)
	_cam.position = upper + Vector3(bounds.size.x * 1.25, bounds.size.y * 0.68,
		-bounds.size.z * 1.25)
	_cam.look_at(upper)
	await _save("tower_house_interior.png")
	interior.free()


func _motte_shots() -> void:
	var entrances_only := "--entrances" in OS.get_cmdline_args()
	var spec := _motte_spec()
	var mound: AABB = CastleGeometry.motte_aabb(spec)
	var keep: AABB = CastleGeometry.shell_keep_aabb(spec)
	print("motte: mound=", mound, " keep=", keep)
	if not entrances_only:
		for cutaway in [false, true]:
			var castle := CastleAssembler.build(spec, cutaway)
			_stage.add_child(castle)
			var centre := mound.get_center()
			var span := maxf(mound.size.x, mound.size.z)
			_cam.position = centre + Vector3(span * 1.3, spec.motte_height * 1.9,
				-span * 1.3)
			_cam.look_at(Vector3(keep.get_center().x, spec.motte_height * 0.72,
				keep.get_center().z))
			await _save("motte_%s.png" % ("roof_off" if cutaway else "roof_on"))
			castle.free()

	var entrance := CastleAssembler.build(spec, true)
	_stage.add_child(entrance)
	var motte_door := _door_pose(spec, "keep_shell")
	var keep_door: Vector3 = motte_door.world
	var motte_tangent := Vector3(-motte_door.normal.z, 0.0, motte_door.normal.x).normalized()
	# Keep the doorway proof shot on the outward normal; a second profile shot
	# below makes the individual risers legible without sacrificing the cyan
	# opening witness in the first frame.
	_cam.position = keep_door + motte_door.normal * 24.0 + Vector3.UP * 5.0 + motte_tangent * 7.0
	_cam.look_at(keep_door + Vector3.UP * 0.35)
	var motte_witness := _add_witness(motte_door)
	await _save("motte_entrance.png")
	# Low raking view down the lane: aim below the door at the route midpoint so
	# the mound-side riser silhouette is visible rather than only its plateau.
	var approach_target: Vector3 = keep_door + motte_door.normal * 12.0 + Vector3.DOWN * 3.0
	_cam.position = keep_door + motte_door.normal * 24.0 + Vector3.UP * 5.0 + motte_tangent * 10.0
	_cam.look_at(approach_target)
	await _save("motte_approach.png")
	motte_witness.queue_free()
	entrance.free()
	if entrances_only:
		return

	var interior := CastleAssembler.build(spec, true)
	_stage.add_child(interior)
	# The motte cutaway has no roof surface to remove; aim at the keep shell,
	# parapet, and climb junction to make that contract explicit in the render.
	var motte_centre := CastleGeometry.motte_center(spec)
	var court_target := Vector3(motte_centre.x, spec.motte_height * 0.72,
		motte_centre.y + spec.length * 0.05)
	_cam.position = court_target + Vector3(0.0, spec.motte_height * 2.8,
		-spec.length * 0.78)
	_cam.look_at(court_target)
	await _save("motte_interior.png")
	interior.free()


func _save(file: String) -> void:
	for _f in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var result := _vp.get_texture().get_image().save_png(OUT + "/" + file)
	if result != OK:
		push_error("Could not save " + file)
	else:
		print("  ", file)


func _door_pose(spec: CastleSpec, id: String) -> Dictionary:
	var plan: HousePlan
	var bounds: AABB
	if id == "tower_house":
		plan = TowerPlan.generate(spec, false)
		bounds = CastleGeometry.tower_house_aabb(spec)
	else:
		plan = MottePlan.generate(spec, false)
		bounds = CastleGeometry.shell_keep_aabb(spec)
	var row := Interiors.record(id, plan, bounds)
	var door: Dictionary = plan.doors[plan.entrance()]
	var level := int(door.get("storey", 0))
	var sill := float(door.get("sill", 0.0))
	var head := float(door.get("head", HouseGeometry.DOOR_H))
	var y := float(level) * plan.spec.height + (sill + head) * 0.5
	var world: Vector3 = row.transform * Vector3(door.pos.x, y, door.pos.y)
	var normal: Vector3 = (row.transform.basis * Vector3(door.normal.x, 0.0, door.normal.y)).normalized()
	return {"world": world, "normal": normal, "width": float(door.width),
		"height": head - sill}


func _add_witness(pose: Dictionary) -> MeshInstance3D:
	var witness := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(maxf(float(pose.width) * 0.82, 0.8),
		maxf(float(pose.height) * 0.82, 1.2), 0.10)
	witness.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("25e5ff")
	material.emission_enabled = true
	material.emission = Color("25e5ff")
	material.emission_energy_multiplier = 3.0
	witness.material_override = material
	var normal: Vector3 = pose.normal
	_stage.add_child(witness)
	witness.position = pose.world - normal * 0.35
	witness.look_at(witness.position + normal, Vector3.UP)
	return witness


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
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	_stage.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -36, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	_stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-14, 140, 0)
	fill.light_energy = 0.4
	_stage.add_child(fill)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	ground.mesh = plane
	ground.position.y = -0.03
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("65705a")
	ground_mat.roughness = 1.0
	ground.material_override = ground_mat
	_stage.add_child(ground)

	_cam = Camera3D.new()
	_cam.fov = 48
	_cam.far = 2000
	_vp.add_child(_cam)
