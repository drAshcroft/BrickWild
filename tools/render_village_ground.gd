extends "res://tools/render_shots.gd"
## VTER-GROUND-MESH: a small village on falling ground, assembled, from two
## sides -- lots on their platforms, terrace and retaining walls, road beds.
## Must NOT be headless (the dummy renderer makes no image).
##
##   godot --path . --script res://tools/render_village_ground.gd [-- plane_30 street real30/hallstatt green]

const GROUND_OUT := "res://artifacts/vter_ground_mesh/renders"
const VT := preload("res://tests/suites/village_terrain_plan_suite.gd")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GROUND_OUT))
	_build_stage()
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		args = PackedStringArray(["plane_30", "street", "real30/hallstatt", "green"])
	for k in range(0, args.size() - 1, 2):
		var spec := VillageSpec.new(4242)
		spec.population = 20
		spec.generate(4242)
		spec.form = StringName(args[k + 1])
		spec.terrain = VT.terrain(args[k])
		var plan := VillageLotPlanner.plan(spec)
		var model := VillageAssembler.build(plan)
		_root3d.add_child(model)
		var focus3 := Vector3.ZERO
		for b in plan.buildings:
			focus3 += (b["transform"] as Transform3D).origin
		focus3 /= float(maxi(1, plan.buildings.size()))
		var surface := VillageGroundSurface.of(plan)
		focus3.y = surface.height_at(Vector2(focus3.x, focus3.z)) + 2.0
		var name := String(args[k]).replace("/", "_")
		for view in [[Vector3(1.0, 0.75, 1.1), "a"], [Vector3(-1.1, 0.6, -0.9), "b"], [Vector3(0.05, 1.6, 0.4), "top"]]:
			var dir: Vector3 = (view[0] as Vector3).normalized()
			_cam.position = focus3 + dir * 70.0
			_cam.look_at(focus3, Vector3.UP)
			await process_frame
			await RenderingServer.frame_post_draw
			await process_frame
			await RenderingServer.frame_post_draw
			_vp.get_texture().get_image().save_jpg("%s/%s_%s.jpg" % [GROUND_OUT, name, view[1]], 0.92)
		model.queue_free()
		await process_frame
		print("GROUND_RENDER ", name)
	quit()
