extends "res://tools/render_shots.gd"
## Non-headless cutaway views of the INT-009 library's real furnished rooms.

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/int009"))
	_build_stage()
	await process_frame
	var spec := ShopSpec.new()
	spec.business = &"library"
	spec.style = &"longhall"
	spec.width = 18.0
	spec.length = 28.0
	spec.height = 3.1
	var plan := ShopGenerator.generate(spec, 61100)
	var model := HouseAssembler.build(plan, true)
	_root3d.add_child(model)
	_cam.position = Vector3(22.0, 36.0, -24.0)
	_cam.look_at(Vector3(0.0, 0.5, 0.0), Vector3.UP)
	for _frame in 5:
		await process_frame
		await RenderingServer.frame_post_draw
	var first := _vp.get_texture().get_image()
	var first_error := first.save_png("res://artifacts/int009/library_cutaway.png")
	print("INT009_RENDER path=res://artifacts/int009/library_cutaway.png error=%d" % first_error)
	_cam.position = Vector3(-22.0, 36.0, -24.0)
	_cam.look_at(Vector3(0.0, 0.5, 0.0), Vector3.UP)
	for _opposite_frame in 5:
		await process_frame
		await RenderingServer.frame_post_draw
	var opposite := _vp.get_texture().get_image()
	var opposite_error := opposite.save_png("res://artifacts/int009/library_cutaway_opposite.png")
	print("INT009_RENDER path=res://artifacts/int009/library_cutaway_opposite.png error=%d" % opposite_error)
	# A tighter overhead oblique view makes both facing banks and their shared
	# aisle legible. The wide views are useful for room sequence; this one is
	# deliberately composed around the stacks instead.
	_cam.position = Vector3(9.5, 19.0, 13.5)
	_cam.look_at(Vector3(4.0, 0.8, 5.8), Vector3.UP)
	for _stack_frame in 5:
		await process_frame
		await RenderingServer.frame_post_draw
	var stacks_image := _vp.get_texture().get_image()
	var stacks_error := stacks_image.save_png("res://artifacts/int009/library_stacks_detail.png")
	print("INT009_RENDER path=res://artifacts/int009/library_stacks_detail.png error=%d" % stacks_error)
	_cam.position = Vector3(-1.5, 19.0, -1.9)
	_cam.look_at(Vector3(4.0, 0.8, 5.8), Vector3.UP)
	for _opposite_stack_frame in 5:
		await process_frame
		await RenderingServer.frame_post_draw
	var opposite_stacks_image := _vp.get_texture().get_image()
	var opposite_stacks_error := opposite_stacks_image.save_png(
		"res://artifacts/int009/library_stacks_detail_opposite.png")
	print("INT009_RENDER path=res://artifacts/int009/library_stacks_detail_opposite.png error=%d" % opposite_stacks_error)
	# Show the programme rooms that are hard to identify in the whole-building
	# views: the reading hearth and lecterns, plus the scriptorium workbench.
	_cam.position = Vector3(15.0, 22.0, -17.0)
	_cam.look_at(Vector3(-1.0, 0.6, -1.0), Vector3.UP)
	for _programme_frame in 5:
		await process_frame
		await RenderingServer.frame_post_draw
	var programme_image := _vp.get_texture().get_image()
	var programme_error := programme_image.save_png(
		"res://artifacts/int009/library_reading_scriptorium_detail.png")
	print("INT009_RENDER path=res://artifacts/int009/library_reading_scriptorium_detail.png error=%d" % programme_error)
	print("INT009_ROOMS ", str(plan.rooms.map(func(room: Dictionary) -> String:
		return "%s %s" % [String(room["kind"]), str(room["rect"])])))
	for room in range(plan.room_count()):
		var counts := {}
		var rows := {}
		for fi in plan.furniture_of(room):
			var item: Dictionary = plan.furniture[fi]
			var key := String(item["key"])
			counts[key] = int(counts.get(key, 0)) + 1
			var row := String(item.get("row", ""))
			if not row.is_empty():
				rows[row] = {"rect": item["rect"], "zone": item["zone"],
					"key": item["key"], "count": int(rows.get(row, {}).get("count", 0)) + 1}
		print("INT009_ROOM_CONTENT kind=%s counts=%s" % [String(plan.kind_of(room)), str(counts)])
		for fi2 in plan.furniture_of(room):
			var item2: Dictionary = plan.furniture[fi2]
			var category := PropCatalog.category(item2["key"])
			if category in ["hearth", "lectern", "workbench"]:
				print("INT009_PROGRAMME kind=%s category=%s key=%s rect=%s" % [
					String(plan.kind_of(room)), category, String(item2["key"]), str(item2["rect"])])
		if not rows.is_empty():
			print("INT009_ROWS kind=%s rows=%s" % [String(plan.kind_of(room)), str(rows)])
	quit(1 if first_error != OK or opposite_error != OK or stacks_error != OK \
		or opposite_stacks_error != OK or programme_error != OK else 0)
