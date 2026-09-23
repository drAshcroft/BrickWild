extends "res://tools/render_shots.gd"
## Actual mining camp and its working entrance, including rendered apron.
const OUT := "res://artifacts/p1p2_village/mine_renders"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_stage()
	await process_frame
	if "prop" in OS.get_cmdline_user_args():
		var preview_spec := VillageSpec.new(17)
		preview_spec.generate(17)
		var preview := VillagePlan.new(preview_spec)
		preview.site = Rect2(-10.0, -10.0, 20.0, 20.0)
		preview.props.append({"key": "adit", "pos": Vector2.ZERO, "yaw": 0.0,
			"built": true, "approach": Poly.from_rect(Rect2(-0.9, -4.0, 1.8, 4.5))})
		_root3d.add_child(VillageAssembler.build(preview))
		await _save(Vector3(0.0, 1.0, 0.5), Vector3(0.25, 0.35, -1.0).normalized(), 11.0, "adit_prop.jpg")
		quit()
		return
	var spec := VillageSpec.new(VillageArchetypeSuite._seed_for(&"mine_camp", 0, 1.0))
	spec.population = 70
	spec.culture = &"norse"
	spec.purpose = &"mining"
	spec.water = &"none"
	spec.enclosure = &"palisade"
	spec.wealth = 0.6
	spec.generate(spec.seed)
	print("MINE PLAN START ", spec.seed)
	var plan := VillageLotPlanner.plan(spec)
	var skip_pure := func(_p: VillagePlan) -> Array: return []
	print("MINE QA ", JSON.stringify(VillageQA.new().check(plan, {&"pure": skip_pure}, false)))
	print("MINE MUST ", VillageArchetypeSuite._must_failures(VillageArchetypeSuite.ARCHETYPES[6], plan, 1.0))
	var node := VillageAssembler.build(plan)
	_root3d.add_child(node)
	await process_frame
	var centre := Vector3(plan.site.get_center().x, 2.0, plan.site.get_center().y)
	var direction := Vector3(0.56, 0.60, 0.57).normalized()
	await _save(centre, direction, maxf(plan.site.size.length() * 0.75, 70.0), "camp.jpg")
	for prop in plan.props:
		if prop["key"] != "adit": continue
		var at: Vector2 = prop["pos"]
		var yaw: float = prop["yaw"]
		var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var side := Vector3(cos(yaw), 0.0, -sin(yaw))
		await _save(Vector3(at.x, 0.8, at.y), (forward + side * 0.3 + Vector3.UP * 0.45).normalized(), 10.0, "adit.jpg")
	quit()


func _save(focus: Vector3, direction: Vector3, distance: float, name: String) -> void:
	_cam.position = focus + direction * distance
	_cam.look_at(focus, Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_jpg(OUT + "/" + name, 0.95)
	print("MINE SAVED ", name)
