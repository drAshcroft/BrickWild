extends "res://tools/render_shots.gd"
## VIL-018: actual furnished shop/bakery, working race and wheel, from its
## measured lot through the same dresser and assembler as a complete village.

const MILL_OUT := "res://artifacts/p1p2_house/mill_renders"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MILL_OUT))
	_build_stage()
	await process_frame
	var request := BuildingRequest.shop(18550, &"bakery", &"farmhouse", 11, 14, 2.8, 1)
	var jobs := VillageLotPlanner.measure_all([request])
	for water in [&"pond", &"stream", &"river", &"coast"]:
		var s := VillageSpec.new(18500)
		s.population = 50
		s.purpose = &"mill"
		s.culture = &"english"
		s.enclosure = &"hedge"
		s.water = water
		s.wealth = 0.4
		s.generate(s.seed)
		var plan := VillageSitePlanner.plan(s)
		var left := VillageLotPlanner.cut_measured(plan, jobs)
		for attempt in VillageLotPlanner.RETRIES:
			if left == 0:
				break
			plan = VillageSitePlanner.plan(s, int(attempt[0]), float(attempt[1]))
			left = VillageLotPlanner.cut_measured(plan, jobs)
		if left > 0:
			push_error("mill render cannot fit " + String(water))
			quit(1)
			return
		VillageDresser.dress(plan)
		var race: Dictionary = plan.water.back()
		var n: Vector2 = race["normal"]
		var forward := VillageMeasure.front_dir(plan.buildings[0])
		var direction := (Vector3(n.x, 0.65, n.y) + Vector3(forward.x, 0, forward.y) * 0.55).normalized()
		var centre := VillageMeasure.centre(VillageMeasure.bounds_poly(plan.buildings[0]))
		for cutaway in [false, true]:
			var model := VillageAssembler.build(plan, cutaway)
			_root3d.add_child(model)
			var focus := Vector3(centre.x, 2.0, centre.y)
			_cam.position = focus + direction * 33.0 + Vector3.UP * (8.0 if cutaway else 0.0)
			_cam.look_at(focus, Vector3.UP)
			await process_frame
			await RenderingServer.frame_post_draw
			await process_frame
			await RenderingServer.frame_post_draw
			var suffix := "_cutaway" if cutaway else "_working"
			_vp.get_texture().get_image().save_jpg(MILL_OUT + "/" + String(water) + suffix + ".jpg", 0.94)
			model.queue_free()
			await process_frame
		print("MILL_RENDER ", water, " race=", race["poly"])
	print("Actual mill renders complete")
	quit()
