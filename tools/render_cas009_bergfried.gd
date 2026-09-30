extends "res://tools/render_shots.gd"
## Fixed-camera assembled views for CAS-009's compact Bergfried and Palas.

const CAS009_OUT := "res://artifacts/cas009_bergfried/renders"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAS009_OUT))
	_build_stage()
	await process_frame
	var spec := CastleSpec.new(918009)
	spec.style = &"norman"
	spec.width = 46.0
	spec.length = 46.0
	spec.height = 10.0
	spec.tier_override = &"castle"
	spec.plan_override = &"bergfried"
	spec.sides_override = 5
	CastleGenerator.generate(spec, spec.seed)
	var keep := CastleGeometry.keep_aabb(spec)
	var hall := CastleGeometry.hall_aabb(spec)
	var fore: Dictionary = CastleGeometry.forebuilding(spec)
	var pair_centre := (keep.get_center() + hall.get_center()) * 0.5
	var stair_focus := Vector3(keep.end.x + float(fore.run) * 0.5,
		float(fore.height) * 0.55, keep.get_center().z)
	print("CAS-009 render: keep %s, Palas %s, door stair %s" % [keep, hall, fore.footprint])
	for row in [
		{"name": "bergfried_palas_assembled", "cutaway": false,
			"camera": pair_centre + Vector3(46.0, 37.0, -52.0), "target": Vector3(0, 8, 0)},
		{"name": "bergfried_access_assembled", "cutaway": false,
			"camera": stair_focus + Vector3(15.0, 18.0, -20.0), "target": stair_focus},
		{"name": "bergfried_palas_cutaway", "cutaway": true,
			"camera": pair_centre + Vector3(27.0, 58.0, -30.0), "target": Vector3(0, 2, 0)}]:
		var castle := CastleAssembler.build(spec, bool(row.cutaway))
		_root3d.add_child(castle)
		_cam.position = row.camera
		_cam.look_at(row.target)
		for _frame in range(4):
			await process_frame
			await RenderingServer.frame_post_draw
		var path := CAS009_OUT + "/" + String(row.name) + ".jpg"
		_vp.get_texture().get_image().save_jpg(path, 0.94)
		print("CAS-009 assembled render: ", path)
		castle.queue_free()
		await process_frame
	quit()
