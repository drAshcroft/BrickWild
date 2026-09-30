extends "res://tools/render_shots.gd"
## Assembled water-castle acceptance views for CAS-008.

const OUT := "res://artifacts/cas008/renders"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_stage()
	await process_frame
	await _render_bodiam()
	await _render_caerphilly()
	quit()


func _render_bodiam() -> void:
	var spec := _water_spec("bodiam", 55.0, 50.0, 18.0)
	var focus := Vector3(0.0, 5.0, 0.0)
	await _shoot_scene(CastleAssembler.build(spec, false),
		OUT + "/bodiam_gate_water.png", 2.65, -0.38, 1.0, focus, 78.0)
	print("CAS008_RENDER bodiam_gate_water plan=", spec.plan_kind,
		" moat=", spec.ditch_width, " causeway=", CastleGeometry.causeway_aabb(spec))


func _render_caerphilly() -> void:
	var spec := _water_spec("caerphilly", 240.0, 200.0, 12.0)
	var focus := Vector3(0.0, 5.0, 0.0)
	await _shoot_scene(CastleAssembler.build(spec, false),
		OUT + "/caerphilly_two_moats.png", 2.6, -0.58, 1.0, focus, 230.0)
	print("CAS008_RENDER caerphilly_two_moats plan=", spec.plan_kind,
		" rings=", spec.moat_count, " inner_ward=", spec.inner_ward)


func _water_spec(key: String, width: float, length: float,
		height: float) -> CastleSpec:
	var spec := CastleSpec.new()
	spec.style = &"edwardian"
	spec.tier_override = &"fortress" if key == "caerphilly" else &"castle"
	spec.width = width
	spec.length = length
	spec.height = height
	CastleGenerator.generate(spec,
		CastleLandmarkSuite._seed_for(key, 1.0))
	CastleLandmarkSuite._force_features(key, spec)
	return spec


func _capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _vp.get_texture().get_image()
	var err := image.save_png(ProjectSettings.globalize_path(file))
	print("CAS008_CAPTURE ", file, " error=", err)
