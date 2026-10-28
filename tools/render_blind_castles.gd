extends "res://tools/render_fantasy_castles.gd"
## VISUAL-BLIND-REVIEWS: one exterior per castle style, same camera rule
## (three-quarter, framed on the mesh bounds). Not headless.
##   godot --path . --script res://tools/render_blind_castles.gd
const OUT_DIR := "res://artifacts/blind_review/castles"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_stage()
	await process_frame
	for st in [&"norman", &"edwardian", &"crusader", &"french_chateau", &"bavarian", &"japanese", &"moorish", &"elven"]:
		var spec := CastleSpec.new()
		spec.style = st
		spec.width = 40.0
		spec.length = 55.0
		spec.height = 14.0
		spec.tier_override = &"castle"
		CastleGenerator.generate(spec, 8102)
		var mesh: ArrayMesh = CastleBuilder.new().build(spec)
		_set_mesh(mesh, [spec.stone_color, spec.trim_color, spec.roof_color, Color("11131c")])
		var bb := mesh.get_aabb()
		var c := bb.get_center()
		var r := bb.size.length() * 0.62
		await _capture(c + Vector3(0.75, 0.55, -0.9).normalized() * r * 1.7, c, "../blind_review/castles/%s.jpg" % String(st))
	print("blind castles done")
	quit()
