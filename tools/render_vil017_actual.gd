extends "res://tools/render_shots.gd"
## VIL-017 visual gate: real generated plans, models and roofs.
##
## This renderer deliberately goes through VillageLotPlanner and
## VillageAssembler.  It never invents building transforms or proxy boxes.

const OUT := "res://artifacts/p1_acceptance/village_forms_actual"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_stage()
	await process_frame
	var cases: Array[Dictionary] = [
		{"name": &"crossroads", "seed": 17017, "population": 40,
			"purpose": &"crossroads", "culture": &"english", "water": &"none"},
		{"name": &"round", "seed": 17018, "population": 30,
			"purpose": &"forest", "culture": &"blighted", "water": &"none"},
		{"name": &"strand", "seed": 17019, "population": 30,
			"purpose": &"fishing", "culture": &"english", "water": &"coast"},
	]
	var only := ""
	for arg in OS.get_cmdline_args():
		if String(arg).begins_with("form="):
			only = String(arg).trim_prefix("form=")
	for entry in cases:
		if not only.is_empty() and String(entry["name"]) != only:
			continue
		var plan := _plan(entry)
		await _render_plan(plan, String(entry["name"]))
	print("VIL-017 actual-plan renders complete")
	quit()


func _plan(entry: Dictionary) -> VillagePlan:
	var seed: int = int(entry["seed"])
	var spec := VillageSpec.new(seed)
	spec.population = int(entry["population"])
	spec.purpose = entry["purpose"]
	spec.culture = entry["culture"]
	spec.water = entry["water"]
	spec.wealth = 0.4
	spec.enclosure = &"none"
	spec.generate(seed)
	var plan := VillageLotPlanner.plan(spec)
	print("actual VIL-017 ", String(entry["name"]), ": roads=", plan.roads.size(),
		" lots=", plan.lots.size(), " buildings=", plan.buildings.size(),
		" water=", plan.water.size())
	return plan


func _render_plan(plan: VillagePlan, name: String) -> void:
	print("render begin ", name)
	var node := VillageAssembler.build(plan, false)
	print("assembled ", name)
	_root3d.add_child(node)
	_colourize(node)
	await process_frame

	# Wide roof-on site view: the actual generated models are small at village
	# scale, but the road/common/coast relationship remains visible.
	var centre := plan.site.get_center()
	var radius: float = maxf(plan.site.size.length() * 0.55, 28.0)
	print("capture overview ", name)
	await _capture_actual(node, name + "_roof_overview.jpg", Vector3(centre.x, 2.0, centre.y),
		radius, 0.72, -0.48)

	# A generated house's actual door anchors the close view.  The landmark is
	# intentionally skipped: its apse is useful in the overview, but it does
	# not prove the ordinary house door/window surface placement.  The camera
	# uses the lot transform's real outward (-Z) direction, so this cannot drift
	# into a side or rear wall when a form rotates its frontage.
	for building in plan.buildings:
		if StringName(building["kind"]) == &"church":
			continue
		await _capture_house(node, name + "_door_window.jpg", building)
		break

	if not plan.water.is_empty():
		var shore := Poly.bounding_rect(plan.water[0]["poly"]).get_center()
		await _capture_actual(node, name + "_shore_roof.jpg", Vector3(shore.x, 1.4, shore.y),
			28.0, 0.84, -0.30)
	node.queue_free()


func _capture_actual(_node: Node3D, file: String, focus: Vector3, radius: float,
		yaw: float, pitch: float) -> void:
	var dist: float = radius / tan(deg_to_rad(_cam.fov) / 2.0) * 1.08
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	_cam.position = focus + dir * dist
	_cam.look_at(focus, Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_jpg(OUT + "/" + file, 0.92)
	print("  ", OUT + "/" + file)


func _capture_house(_node: Node3D, file: String, building: Dictionary) -> void:
	var door: Vector3 = building["door"]
	var xf: Transform3D = building["transform"]
	var outward := (xf.basis * Vector3(0.0, 0.0, -1.0)).normalized()
	var side := (xf.basis * Vector3(1.0, 0.0, 0.0)).normalized()
	var focus := door + Vector3.UP * 2.5
	_cam.position = door + outward * 12.0 + side * 4.0 + Vector3.UP * 5.0
	_cam.look_at(focus, Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_jpg(OUT + "/" + file, 0.92)
	print("  ", OUT + "/" + file)


func _colourize(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null and node.name == "Ground":
		var mesh: ArrayMesh = node.mesh
		for i in range(mesh.get_surface_count()):
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(VillageBuilder.COLOURS.get(i, "808080"))
			mat.roughness = 0.88
			node.set_surface_override_material(i, mat)
	for child in node.get_children():
		_colourize(child)
