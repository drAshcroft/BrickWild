extends "res://tools/render_shots.gd"
## Actual assembled castle and close-ups of its access structures.
const ACCESS_OUT := "res://artifacts/p1p2_castle_access/renders"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ACCESS_OUT))
	_build_stage()
	await process_frame
	var spec := CastleSpec.new(42)
	spec.style = &"norman"
	spec.width = 40
	spec.length = 55
	spec.height = 14
	CastleGenerator.generate(spec, spec.seed)
	spec.ditch_width = 5.0
	var castle := CastleAssembler.build(spec)
	_root3d.add_child(castle)
	var fore := CastleGeometry.forebuilding(spec)
	var stairs := CastleGeometry.wall_stairs(spec)
	var bridge := CastleGeometry.drawbridge_aabb(spec)
	var views := [
		{"name": "castle", "target": Vector3(0, 6, 0), "camera": Vector3(52, 55, -68)},
		{"name": "forebuilding", "target": Vector3(fore.front.x, fore.height * 0.5, fore.front.y + fore.run * 0.5),
			"camera": Vector3(fore.front.x + 14, fore.height + 6, fore.front.y - 12)},
		{"name": "entrance_stair", "target": Vector3(fore.at.x, fore.height + 1.2, fore.at.y),
			"camera": Vector3(fore.front.x, 1.7, fore.front.y - 0.6)},
		{"name": "drawbridge", "target": bridge.get_center() + Vector3.UP * 1.0,
			"camera": bridge.get_center() + Vector3(9, 7, -11)}]
	if not stairs.is_empty():
		var stair: Dictionary = stairs[0]
		var at := Vector3(stair.at.x, stair.height * 0.5, stair.at.y)
		views.append({"name": "wall_stair", "target": at,
			"camera": at + Vector3(stair.inside.x * 14 + stair.along.x * 9, 5, stair.inside.y * 14 + stair.along.y * 9)})
	for view in views:
		_cam.position = view.camera
		_cam.look_at(view.target)
		for frame in 3:
			await process_frame
			await RenderingServer.frame_post_draw
		var path := ACCESS_OUT + "/" + String(view.name) + ".jpg"
		_vp.get_texture().get_image().save_jpg(path, 0.94)
		print("CASTLE_ACCESS_RENDER ", path)
	castle.queue_free()
	quit()
