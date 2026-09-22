extends "res://tools/render_shots.gd"
## VIL-020 representative render gate: real LotPlanner/VillageAssembler scenes.

const OUT := "res://artifacts/p1_acceptance/village_archetypes"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_stage()
	await process_frame
	var cases: Array[Dictionary] = [
		{"key": "thorpe", "seed": 44001, "people": 18, "culture": &"english", "purpose": &"farming", "water": &"none", "edge": &"hedge"},
		{"key": "strand", "seed": 44002, "people": 45, "culture": &"norse", "purpose": &"fishing", "water": &"coast", "edge": &"none"},
		{"key": "lord", "seed": 44003, "people": 70, "culture": &"english", "purpose": &"garrison", "water": &"none", "edge": &"wall"}]
	for item in cases:
		var plan := _plan(item)
		await _shot(plan, "%s_roof.jpg" % item["key"], false, 0.78, -0.46)
		await _shot(plan, "%s_cutaway.jpg" % item["key"], true, 0.78, -0.62)
	print("VIL-020 archetype renders complete")
	quit()


func _plan(item: Dictionary) -> VillagePlan:
	var spec := VillageSpec.new(item["seed"])
	spec.population = item["people"]
	spec.culture = item["culture"]
	spec.purpose = item["purpose"]
	spec.water = item["water"]
	spec.enclosure = item["edge"]
	spec.wealth = 0.6
	spec.generate(spec.seed)
	var plan := VillageLotPlanner.plan(spec)
	print("render ", item["key"], " lots=", plan.lots.size(), " buildings=", plan.buildings.size(), " water=", plan.water.size())
	return plan


func _shot(plan: VillagePlan, file: String, cutaway: bool, yaw: float, pitch: float) -> void:
	var node := VillageAssembler.build(plan, cutaway)
	_root3d.add_child(node)
	_colourize(node)
	await process_frame
	var centre := Vector3(plan.site.get_center().x, 2.0, plan.site.get_center().y)
	var radius := maxf(plan.site.size.length() * 0.40, 24.0)
	var dist := radius / tan(deg_to_rad(_cam.fov) / 2.0) * 0.92
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	_cam.position = centre + dir * dist
	_cam.look_at(centre, Vector3.UP)
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
