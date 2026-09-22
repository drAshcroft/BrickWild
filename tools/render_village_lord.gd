extends "res://tools/render_shots.gd"
const OUT := "res://artifacts/p1_acceptance/village_archetypes"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_stage()
	await process_frame
	var spec := VillageSpec.new(44003)
	spec.population = 70
	spec.culture = &"english"
	spec.purpose = &"garrison"
	spec.water = &"none"
	spec.enclosure = &"wall"
	spec.wealth = 0.6
	spec.generate(spec.seed)
	var plan := VillageLotPlanner.plan(spec)
	print("lord lots=", plan.lots.size(), " buildings=", plan.buildings.size())
	for cutaway in [false, true]:
		var node := VillageAssembler.build(plan, cutaway)
		_root3d.add_child(node)
		await process_frame
		var centre := Vector3(plan.site.get_center().x, 2.0, plan.site.get_center().y)
		var radius := maxf(plan.site.size.length() * 0.38, 24.0)
		var dist := radius / tan(deg_to_rad(_cam.fov) / 2.0) * 0.90
		_cam.position = centre + Vector3(0.65, 0.55, 0.65).normalized() * dist
		_cam.look_at(centre, Vector3.UP)
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		var name := "lord_cutaway.jpg" if cutaway else "lord_roof.jpg"
		_vp.get_texture().get_image().save_jpg(OUT + "/" + name, 0.92)
		print("  ", OUT + "/" + name)
		node.queue_free()
	print("lord render complete")
	quit()
