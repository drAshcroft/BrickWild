extends "res://tools/render_shots.gd"
## Fixed-camera assembled evidence for CAS-013's bowed Elven curtain walls.

const CAS013_OUT := "res://artifacts/renders"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAS013_OUT))
	_build_stage()
	await process_frame
	var spec := CastleSpec.new(13013)
	spec.style = &"elven"
	spec.width = 60.0
	spec.length = 70.0
	spec.height = 20.0
	spec.tier_override = &"castle"
	CastleGenerator.generate(spec, spec.seed)
	var centre := Vector3(0.0, 11.0, 0.0)
	for row in [
		{"name": "cas013_elven_curved_walls", "camera": centre + Vector3(76.0, 52.0, -82.0)},
		{"name": "cas013_elven_curved_walls_high", "camera": centre + Vector3(54.0, 88.0, -62.0)},
	]:
		var castle := CastleAssembler.build(spec, false)
		_root3d.add_child(castle)
		_cam.position = row.camera
		_cam.look_at(centre)
		for _frame in range(5):
			await process_frame
			await RenderingServer.frame_post_draw
		var path := CAS013_OUT + "/" + String(row.name) + ".jpg"
		_vp.get_texture().get_image().save_jpg(path, 0.94)
		print("CAS-013 assembled render: ", path)
		castle.queue_free()
		await process_frame
	quit()
