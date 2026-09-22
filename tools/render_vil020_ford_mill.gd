extends "res://tools/render_shots.gd"
## VIL-020 actual Ford and Mill witnesses.  Plans come from the canonical
## VillageSpec -> VillageLotPlanner -> VillageAssembler path; no proxies.

const OUT := "res://artifacts/p1_acceptance/village_archetypes_ford_mill"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_stage()
	await process_frame
	var ford := _plan(45001, 60, &"frankish", &"crossroads", &"stream", &"none")
	await _shot(ford, "ford_roof.jpg", false, false)
	await _shot(ford, "ford_crossing_close.jpg", false, true)
	var mill := _plan(45002, 120, &"frankish", &"mill", &"river", &"hedge")
	await _shot(mill, "mill_roof.jpg", false, false)
	await _shot(mill, "mill_crossing_close.jpg", false, true)
	print("VIL-020 Ford/Mill renders complete")
	quit()


func _plan(seed: int, people: int, culture: StringName, purpose: StringName,
		water: StringName, enclosure: StringName) -> VillagePlan:
	var spec := VillageSpec.new(seed)
	spec.population = people
	spec.culture = culture
	spec.purpose = purpose
	spec.water = water
	spec.enclosure = enclosure
	spec.wealth = 0.6
	spec.generate(seed)
	var plan := VillageLotPlanner.plan(spec)
	var crossings := VillageEnclosurePlan.build(plan)["crossings"] as Array
	print("actual ", String(purpose), " lots=", plan.lots.size(),
		" buildings=", plan.buildings.size(), " water=", plan.water.size(),
		" crossings=", crossings.size())
	return plan


func _shot(plan: VillagePlan, file: String, cutaway: bool, close_crossing: bool) -> void:
	var node := VillageAssembler.build(plan, cutaway)
	_root3d.add_child(node)
	_colourize(node)
	await process_frame
	var centre := Vector2(plan.site.get_center())
	var crossings := VillageEnclosurePlan.build(plan)["crossings"] as Array
	if close_crossing:
		for crossing in crossings:
			var ri: int = int(crossing.get("road", -1))
			if ri >= 0 and plan.roads[ri]["class"] == &"through":
				centre = Vector2(crossing["pos"])
				break
	var target := Vector3(centre.x, 2.0, centre.y)
	var radius := 12.0 if close_crossing else maxf(plan.site.size.length() * 0.40, 24.0)
	var yaw := 0.0
	var pitch := -0.35
	if close_crossing:
		var water_centre := Poly.bounding_rect(plan.water[0]["poly"]).get_center()
		yaw = PI * 0.5 if water_centre.x > centre.x else -PI * 0.5
		pitch = -0.42
	var dist := radius / tan(deg_to_rad(_cam.fov) / 2.0) * 0.92
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	_cam.position = target + dir * dist
	_cam.look_at(target, Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_jpg(OUT + "/" + file, 0.92)
	print("  ", OUT + "/" + file)
	node.queue_free()


func _colourize(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null and node.name == "Ground":
		for i in range(node.mesh.get_surface_count()):
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(VillageBuilder.COLOURS.get(i, "808080"))
			mat.roughness = 0.88
			node.set_surface_override_material(i, mat)
	for child in node.get_children():
		_colourize(child)
