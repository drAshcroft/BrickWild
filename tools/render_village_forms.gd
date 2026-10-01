extends "res://tools/render_shots.gd"
## VIL-017 visual gate: actual generated buildings and catalogue dressing.
## Pass a form after -- to render one bounded case, e.g. -- planted.

const OUT := "res://artifacts/p1p2_village/form_renders"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_stage()
	# the stage floor sits at y = 0; a village with a river has land below it
	for child in _root3d.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is PlaneMesh:
			(child as Node3D).position.y = -1.2
	await process_frame
	var args := OS.get_cmdline_user_args()
	var selected: String = args[0] if not args.is_empty() else ""
	for row in VillageFormsSuite._cases():
		if not selected.is_empty() and String(row["name"]) != selected:
			continue
		var spec := VillageFormsSuite._spec(17017 + int(row["population"]), row)
		print("RENDER PLAN ",spec.form)
		var plan := VillageLotPlanner.plan(spec)
		var no_pure := func(_plan: VillagePlan) -> Array: return []
		var report := VillageQA.new().check(plan, {&"pure": no_pure}, false)
		print("RENDER QA ", JSON.stringify(report))
		print("RENDER ASSEMBLE ",spec.form," buildings=",plan.buildings.size())
		await _village_shot(plan, String(spec.form))
	print("Actual village form renders complete")
	quit()

func _village_shot(plan: VillagePlan, form: String) -> void:
	var village := VillageAssembler.build(plan)
	_root3d.add_child(village)
	await process_frame
	var centre := Vector3(plan.site.get_center().x, 2.0, plan.site.get_center().y)
	var radius := maxf(plan.site.size.length() * 0.42, 24.0)
	var distance := radius / tan(deg_to_rad(_cam.fov) / 2.0)
	var direction := Vector3(sin(0.78) * cos(-0.58), -sin(-0.58), cos(0.78) * cos(-0.58))
	_cam.position = centre + direction * distance
	_cam.look_at(centre, Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_jpg(OUT + "/" + form + "_actual.jpg", 0.94)
	# A second view makes the square's entrances and stall aisles readable.
	var common := VillageMeasure.common_centre(plan)
	var focus := Vector3(common.x, 2.0, common.y)
	_cam.position = focus + direction * 110.0
	_cam.look_at(focus, Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_jpg(OUT + "/" + form + "_common.jpg", 0.94)
	print("RENDER SAVED ",OUT,"/",form)
	village.queue_free()
