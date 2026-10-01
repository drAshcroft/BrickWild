extends "res://tools/render_shots.gd"
## Non-headless INT-010 views of the actual furnished prison and cellar hatch.

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/int010"))
	_build_stage()
	await process_frame
	var spec := ShopSpec.new()
	spec.business = &"prison"
	spec.style = &"longhall"
	spec.width = 15.8
	spec.length = 22.0
	spec.height = 2.9
	var plan := ShopGenerator.generate(spec, 61110)
	for cutaway in [false, true]:
		var model := HouseAssembler.build(plan, cutaway)
		_root3d.add_child(model)
		_cam.position = Vector3(20.0, 28.0, -20.0)
		_cam.look_at(Vector3(0.0, -0.1, 0.0), Vector3.UP)
		for _frame in 6:
			await process_frame
			await RenderingServer.frame_post_draw
		var image := _vp.get_texture().get_image()
		var path := "res://artifacts/int010/prison_%s.png" % ("cutaway" if cutaway else "assembled")
		var error := image.save_png(path)
		print("INT010_RENDER path=%s error=%d" % [path, error])
		_root3d.remove_child(model)
		model.queue_free()
	# The wide cutaway contains the whole cellar plan. This close view names the
	# sealed lower room through the same measured hatch used by the plan checks.
	var cutaway_model := HouseAssembler.build(plan, true)
	_root3d.add_child(cutaway_model)
	if not plan.trapdoors.is_empty():
		var hatch: Dictionary = plan.trapdoors[0]
		var hatch_rect: Rect2 = hatch["rect"]
		var hatch_centre := hatch_rect.get_center()
		_cam.position = Vector3(hatch_centre.x + 5.0, 13.0, hatch_centre.y - 6.0)
		_cam.look_at(Vector3(hatch_centre.x, 0.2, hatch_centre.y), Vector3.UP)
		for _hatch_frame in 6:
			await process_frame
			await RenderingServer.frame_post_draw
		var hatch_image := _vp.get_texture().get_image()
		var hatch_path := "res://artifacts/int010/prison_oubliette_hatch.png"
		var hatch_error := hatch_image.save_png(hatch_path)
		print("INT010_RENDER path=%s error=%d" % [hatch_path, hatch_error])
		var lower := int(hatch["lower_room"])
		print("INT010_TRAPDOOR upper=%d lower=%d lower_kind=%s lower_sealed=%s rect=%s" % [
			int(hatch["upper_room"]), lower, String(plan.kind_of(lower)),
			str(bool(plan.rooms[lower].get("sealed", false))), str(hatch_rect)])
	_root3d.remove_child(cutaway_model)
	cutaway_model.queue_free()
	print("INT010_LAYOUT rooms=%d doors=%d trapdoors=%s" % [plan.room_count(), plan.doors.size(), str(plan.trapdoors)])
	for room in range(plan.room_count()):
		if plan.storey_of_room(room) < 0 or plan.kind_of(room) in [&"guardroom", &"corridor", &"cell", &"oubliette"]:
			var items := {}
			for fi in plan.furniture_of(room):
				var key := String(plan.furniture[fi]["key"])
				items[key] = int(items.get(key, 0)) + 1
			print("INT010_ROOM index=%d level=%d kind=%s rect=%s items=%s" % [room, plan.storey_of_room(room), String(plan.kind_of(room)), str(HouseGeometry.room_floor_rect(plan, room)), str(items)])
	quit(1 if plan.trapdoors.is_empty() else 0)
