extends "res://tools/render_church_roofs.gd"
## Backface-culled roof references, including reverse views of every fixture.
const DEST := "res://artifacts/castle_temple_roofs"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	_stage()
	await process_frame
	for style in CastleSpec.STYLES:
		var s := CastleSpec.new()
		s.style = style
		s.width = 65
		s.length = 75
		s.plan_override = &"rect"
		CastleGenerator.generate(s, 42)
		s.keep_offset = 7
		var mesh := CastleBuilder.new().build(s)
		_set_mesh(mesh, [Color("aaa396"), Color("d2c8af"), Color("484f60"), Color("161a20")])
		await _capture(Vector3(100, 82, -105), Vector3(0, 12, 0), "castle_" + String(style) + "_front.jpg")
		await _capture(Vector3(-82, 64, 88), Vector3(0, 14, 4), "castle_" + String(style) + "_rear.jpg")
	# Close views of range gables and dormers.
	var s := CastleSpec.new()
	s.style = &"french_chateau"
	s.width = 24
	s.length = 30
	s.tier_override = &"manor"
	CastleGenerator.generate(s, 42)
	_set_mesh(CastleBuilder.new().build(s), [Color("aaa396"), Color("d2c8af"), Color("484f60"), Color("161a20")])
	await _capture(Vector3(38, 29, -40), Vector3(0, 10, 0), "castle_manor_front.jpg")
	await _capture(Vector3(-34, 24, 36), Vector3(0, 11, 2), "castle_manor_rear.jpg")
	for form in TempleSpec.FORMS:
		var t := TempleSpec.new()
		t.form = form
		TempleGenerator.generate(t, 42)
		t.spire = form in [&"basilica", &"rotunda"]
		_set_mesh(TempleBuilder.new().build(t), [Color("aaa396"), Color("b18a68"), Color("484f60"), Color("161a20")])
		await _capture(Vector3(49, 42, -61), Vector3(0, 10, 0), "temple_" + String(form) + "_front.jpg")
		await _capture(Vector3(-42, 35, 53), Vector3(0, 12, 4), "temple_" + String(form) + "_rear.jpg")
	print("Castle and temple roof renders complete")
	quit()

func _capture(eye: Vector3, at: Vector3, file: String) -> void:
	_cam.position = eye
	_cam.look_at(at, Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_jpg(DEST + "/" + file, 0.94)
	print(file)
