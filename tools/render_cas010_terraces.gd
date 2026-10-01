extends "res://tools/render_shots.gd"
## Non-headless assembled Himeji view for CAS-010.

const OUT := "res://artifacts/cas010/renders"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_stage()
	await process_frame
	if OS.get_cmdline_user_args().has("edinburgh-only"):
		await _render_edinburgh()
		quit()
		return
	var spec := CastleSpec.new(6005)
	spec.style = &"japanese"
	spec.width = 60.0
	spec.length = 50.0
	spec.height = 15.0
	spec.tier_override = &"castle"
	spec.plan_override = &"terraced"
	spec.sides_override = 5
	CastleGenerator.generate(spec, spec.seed)
	spec.keep_shape = &"tiered"
	spec.tower_roof = &"tiered"
	spec.corner_towers = true
	CastleGenerator.refit(spec)
	var keep: AABB = CastleGeometry.keep_aabb(spec)
	var stair_builder := CastleBuilder.new()
	stair_builder.build(spec)
	var stair: AABB = stair_builder.mass_aabb("terrace_stair_1")
	var stair_target := stair.get_center()
	var centre := Vector3(0.0, 11.0, 0.0)
	var rows := [
		{"name": "himeji_terraced_assembled", "cutaway": false,
			"camera": centre + Vector3(78.0, 59.0, -86.0), "target": centre},
		{"name": "himeji_terraced_cutaway", "cutaway": true,
			"camera": centre + Vector3(48.0, 77.0, -61.0), "target": centre},
		{"name": "himeji_tenshu_and_stair", "cutaway": false,
			"camera": keep.get_center() + Vector3(22.0, 30.0, -32.0), "target": keep.get_center()},
		{"name": "himeji_terrace_stair_close", "cutaway": true,
			# Eye-level on the gate axis. The high overhead angle hid the treads
			# behind the gate parapet; this line looks through the passage uphill.
			"camera": stair_target + Vector3(0.0, 9.5, -24.0), "target": stair_target},
	]
	for row in rows:
		var castle := CastleAssembler.build(spec, bool(row.cutaway))
		_root3d.add_child(castle)
		_cam.position = row.camera
		_cam.look_at(row.target)
		for _frame in range(5):
			await process_frame
			await RenderingServer.frame_post_draw
		var path := OUT + "/" + String(row.name) + ".jpg"
		_vp.get_texture().get_image().save_jpg(path, 0.94)
		print("CAS-010 assembled render: ", path)
		castle.queue_free()
		await process_frame

	await _render_edinburgh()
	quit()


func _render_edinburgh() -> void:
	# A larger, six-sided terrace example. The closer views keep both rings
	# legible; the Himeji close view carries the stair detail.
	var edinburgh := CastleSpec.new()
	edinburgh.style = &"edwardian"
	edinburgh.width = 200.0
	edinburgh.length = 100.0
	edinburgh.height = 15.0
	edinburgh.tier_override = &"castle"
	CastleGenerator.generate(edinburgh, CastleLandmarkSuite._seed_for("edinburgh", 1.0))
	CastleLandmarkSuite._force_features("edinburgh", edinburgh)
	CastleGenerator.refit(edinburgh)
	var edinburgh_centre := Vector3(0.0, 13.0, 0.0)
	var edinburgh_rows := [
		{"name": "edinburgh_terraced_assembled", "cutaway": false,
			"camera": edinburgh_centre + Vector3(125.0, 95.0, -140.0),
			"target": edinburgh_centre},
		{"name": "edinburgh_terraced_cutaway", "cutaway": true,
			"camera": edinburgh_centre + Vector3(105.0, 135.0, -120.0),
			"target": edinburgh_centre},
	]
	for row in edinburgh_rows:
		var castle := CastleAssembler.build(edinburgh, bool(row.cutaway))
		_root3d.add_child(castle)
		_cam.position = row.camera
		_cam.look_at(row.target)
		for _frame in range(5):
			await process_frame
			await RenderingServer.frame_post_draw
		var path := OUT + "/" + String(row.name) + ".jpg"
		_vp.get_texture().get_image().save_jpg(path, 0.94)
		print("CAS-010 assembled render: ", path)
		castle.queue_free()
		await process_frame
