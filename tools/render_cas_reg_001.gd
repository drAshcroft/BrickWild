extends "res://tools/render_shots.gd"
## Locked views of the protected forebuilding at the reported Norman seed.
const REG_OUT := "res://artifacts/cas_reg_001/renders"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REG_OUT))
	_build_stage()
	await process_frame
	var spec := CastleSweep.spec_at(&"norman", &"fortress", 2)
	var scene := CastleAssembler.build(spec, false)
	var keep := CastleGeometry.keep_aabb(spec)
	var fore := CastleGeometry.forebuilding(spec)
	# The Norman 9119 entrance faces the negative Z side. Keep this literal in
	# both baseline and updated renderers so the camera cannot follow the fix.
	var normal := Vector2(0.0, -1.0)
	if not fore.is_empty() and not fore.normal.is_equal_approx(normal):
		push_error("fixed camera normal differs from Norman 9119 forebuilding")
	var face := Vector2(keep.get_center().x, keep.get_center().z) \
		+ normal * minf(keep.size.x, keep.size.z) * 0.5
	var focus := Vector3(face.x + normal.x * 2.5, 2.2, face.y + normal.y * 2.5)
	var yaw := atan2(normal.x, normal.y)
	var radius := 31.0
	await _shoot_scene(scene, REG_OUT + "/norman_9119_front.png",
		yaw, -0.12, 1.0, focus, radius)
	scene = CastleAssembler.build(spec, false)
	await _shoot_scene(scene, REG_OUT + "/norman_9119_raking.png",
		yaw + 0.48, -0.10, 1.0, focus, radius)
	quit()


func _capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _vp.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(file))
	print("CAS_REG_RENDER ", file)
