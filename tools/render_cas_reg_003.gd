extends "res://tools/render_shots.gd"
## Fixed-camera production render for CAS-REG-003. Run from the baseline or
## repaired worktree with the same `before` / `after` argument.

func _init() -> void:
	_build_stage()
	await process_frame
	var label := "after"
	var args := OS.get_cmdline_user_args()
	if args.has("before"):
		label = "before"
	var spec := CastleSpec.new()
	spec.style = &"norman"
	spec.width = 8.0
	spec.length = 8.0
	spec.height = 45.0
	spec.plan_override = &"tower_house"
	CastleGenerator.generate(spec, 8803)
	var mesh := CastleBuilder.new().build(spec)
	var colours := [spec.stone_color, spec.trim_color, spec.roof_color, Color("15171b")]
	var focus := Vector3(0.0, 22.5, 0.0)
	var frame := 27.0
	await _shoot_mesh(mesh, colours, "cas_reg_003_%s_front.jpg" % label,
		PI, -0.15, 1.0, focus, frame)
	await _shoot_mesh(mesh, colours, "cas_reg_003_%s_raking.jpg" % label,
		2.35, -0.15, 1.0, focus, frame)
	quit()
