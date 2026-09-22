extends "res://tools/render_shots.gd"
## Non-headless cutaway references for INT-019's authored column plans.
## Run without --headless; this deliberately frames the roof-off interior.

const COLUMN_OUT := "res://artifacts/p1_acceptance/temple_columns"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(COLUMN_OUT))
	_build_stage()
	await process_frame
	var basilica := TempleSpec.new()
	basilica.form = &"basilica"
	TempleGenerator.generate(basilica, 42)
	await _column_shot(basilica, "temple_basilica_columns.jpg", 0.58)
	var rotunda := TempleSpec.new()
	rotunda.form = &"rotunda"
	TempleGenerator.generate(rotunda, 42)
	await _column_shot(rotunda, "temple_rotunda_ring.jpg", 0.52)
	print("Temple column cutaway renders complete")
	quit()


func _column_shot(spec: TempleSpec, file: String, yaw: float) -> void:
	_mesh_inst.mesh = null
	var node: Node3D = TempleAssembler.build(spec, true)
	_root3d.add_child(node)
	_dim(true)
	var extent: Rect2 = TempleGeometry.plan_extent(spec)
	var span: float = maxf(extent.size.x, extent.size.y)
	# High enough to see the authored grid/ring through the removed roof, with
	# a shallow yaw so the individual shafts and their symmetry remain legible.
	_cam.position = Vector3(span * sin(yaw), span * 1.08, -span * cos(yaw))
	_cam.look_at(Vector3(0.0, 0.0, extent.get_center().y), Vector3.UP)
	await _capture_column(COLUMN_OUT + "/" + file)
	node.queue_free()
	_dim(false)


func _capture_column(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	img.save_jpg(path, 0.92)
	print("  ", path)
