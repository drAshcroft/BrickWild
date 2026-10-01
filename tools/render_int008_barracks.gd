extends "res://tools/render_shots.gd"
## Fixed cutaway camera for INT-008's bed, armoury and mess acceptance.

func _init() -> void:
	_build_stage()
	await process_frame
	var spec := ShopSpec.new()
	spec.business = &"barracks"
	spec.style = &"longhall"
	spec.width = 18.0
	spec.length = 28.0
	spec.height = 2.9
	var plan: HousePlan = ShopGenerator.generate(spec, 43900)
	var model := HouseAssembler.build(plan, true)
	_root3d.add_child(model)
	_cam.position = Vector3(17.0, 17.0, -22.0)
	_cam.look_at(Vector3(0.0, 0.5, 0.0), Vector3.UP)
	for _frame in 5:
		await process_frame
		await RenderingServer.frame_post_draw
	var image := _vp.get_texture().get_image()
	var error := image.save_png("res://artifacts/int008/barracks_cutaway.png")
	print("INT008_RENDER path=res://artifacts/int008/barracks_cutaway.png error=%d" % error)
	_cam.position = Vector3(-17.0, 17.0, -22.0)
	_cam.look_at(Vector3(0.0, 0.5, 0.0), Vector3.UP)
	for _opposite_frame in 5:
		await process_frame
		await RenderingServer.frame_post_draw
	var opposite := _vp.get_texture().get_image()
	var opposite_error := opposite.save_png("res://artifacts/int008/barracks_cutaway_opposite.png")
	print("INT008_RENDER path=res://artifacts/int008/barracks_cutaway_opposite.png error=%d" % opposite_error)
	_cam.position = Vector3(13.0, 12.0, 27.0)
	_cam.look_at(Vector3(0.0, 0.6, 8.0), Vector3.UP)
	for _dorm_frame in 5:
		await process_frame
		await RenderingServer.frame_post_draw
	var dormitory := _vp.get_texture().get_image()
	var dormitory_error := dormitory.save_png("res://artifacts/int008/barracks_dormitory_detail.png")
	print("INT008_RENDER path=res://artifacts/int008/barracks_dormitory_detail.png error=%d" % dormitory_error)
	var assembled_beds := 0
	var furniture := model.get_node("Furniture")
	for item in plan.furniture:
		if String(item["key"]) != "Bed_Twin2":
			continue
		var expected_position := PropCatalog.house_origin(item)
		for prop in furniture.get_children():
			if prop is Node3D and (prop as Node3D).position.distance_to(expected_position) < 0.01:
				assembled_beds += 1
				break
	print("INT008_ASSEMBLED_BEDS count=%d planned=%d" % [assembled_beds,
		plan.furniture.filter(func(item: Dictionary) -> bool: return String(item["key"]) == "Bed_Twin2").size()])
	print("INT008_ROOMS ", str(plan.rooms.map(func(room: Dictionary) -> String:
		return "%s %s" % [String(room["kind"]), str(room["rect"])])))
	for room_index in range(plan.room_count()):
		var counts := {}
		var rows := {}
		for item_index in plan.furniture_of(room_index):
			var item: Dictionary = plan.furniture[item_index]
			var key := String(item["key"])
			counts[key] = int(counts.get(key, 0)) + 1
			var row := String(item.get("row", ""))
			if not row.is_empty():
				rows[row] = int(rows.get(row, 0)) + 1
		print("INT008_ROOM_CONTENT kind=%s counts=%s rows=%s" % [
			String(plan.kind_of(room_index)), str(counts), str(rows)])
	quit(1 if error != OK or opposite_error != OK or dormitory_error != OK or assembled_beds != 11 else 0)
