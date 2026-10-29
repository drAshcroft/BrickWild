extends "res://tools/render_shots.gd"
## VTER-VISUAL: a planned, built village on real ground, from above and from a
## street. One overview and one eye-height view along the longest road per site.
## Must NOT be headless (the dummy renderer makes no image).
##
##   godot --path . --script res://tools/render_village_terrain_visual.gd [-- manarola hallstatt monpazier]
##
## Planned the way visualqa/walk --village-terrain does (population 40, auto
## form), seed 1, so the walk and the picture are of the same village.

const VISUAL_OUT := "res://artifacts/vter_visual"
const Surround := preload("res://tools/vter_surround.gd")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VISUAL_OUT))
	_build_stage()
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		args = PackedStringArray(["manarola", "hallstatt", "monpazier"])
	for site in args:
		var ground := VillageTerrain.from_file("res://tests/fixtures/terrain/real30/%s.json" % site)
		if not ground.valid():
			print("VISUAL_SKIP ", site)
			continue
		var spec := VillageSpec.new(1)
		spec.population = 40
		spec.terrain = ground
		spec.generate(1)
		var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(VillageProgrammer.programme(spec))
		var plan := VillageLotPlanner.plan_measured(spec, jobs)
		if plan.ground == null or plan.buildings.is_empty():
			print("VISUAL_NOT_PLANNED ", site)
			continue
		var model := VillageAssembler.build(plan)
		_root3d.add_child(model)
		# the ground beyond the site and the water, drawn by the stage (VTER-VISUAL-SURROUND)
		var surround := Surround.build(plan, model)
		for node in surround["nodes"]:
			_root3d.add_child(node)
		var stage_floor := _stage_floor()
		if stage_floor != null:
			stage_floor.position.y = float(surround["floor_y"]) - 1.0
		print("VISUAL_SURROUND ", site, " water_tris=", surround.get("water_tris", 0), " floor_y=", surround["floor_y"])
		var focus := Vector3.ZERO
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		for b in plan.buildings:
			var o: Vector3 = (b["transform"] as Transform3D).origin
			focus += o
			lo = Vector2(minf(lo.x, o.x), minf(lo.y, o.z))
			hi = Vector2(maxf(hi.x, o.x), maxf(hi.y, o.z))
		focus /= float(plan.buildings.size())
		focus.y = VillageBuilder.ground_height(plan, Vector2(focus.x, focus.z)) + 2.0
		var span := maxf(hi.x - lo.x, hi.y - lo.y)
		print("VISUAL_PLAN ", site, " form=", spec.form, " buildings=", plan.buildings.size(), " span=", span)
		# overview, from the south-east, high
		_cam.far = 3000.0
		_cam.position = focus + Vector3(0.7, 0.8, 0.9).normalized() * (span * 1.1 + 60.0)
		_cam.look_at(focus, Vector3.UP)
		await _shoot("%s/%s_overview.jpg" % [VISUAL_OUT, site])
		# street: along the longest road, a third of the way in, eye height
		var best: PackedVector2Array
		var best_len := 0.0
		for r in plan.roads:
			var pts: PackedVector2Array = r["points"]
			var l := 0.0
			for i in range(1, pts.size()):
				l += pts[i].distance_to(pts[i - 1])
			if l > best_len:
				best_len = l
				best = pts
		if best.size() >= 2:
			var i0 := best.size() / 3
			var i1 := mini(best.size() - 1, i0 + maxi(1, best.size() / 4))
			var a := best[i0]
			var b2 := best[i1]
			var p := Vector3(a.x, VillageBuilder.ground_height(plan, a) + 1.7, a.y)
			var t := Vector3(b2.x, VillageBuilder.ground_height(plan, b2) + 1.7, b2.y)
			_cam.position = p
			_cam.look_at(t, Vector3.UP)
			await _shoot("%s/%s_street.jpg" % [VISUAL_OUT, site])
		model.queue_free()
		for node in surround["nodes"]:
			node.queue_free()
		if stage_floor != null:
			stage_floor.position.y = 0.0
		await process_frame
	quit()


func _shoot(path: String) -> void:
	for i in 3:
		await process_frame
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_jpg(path, 0.9)
	print("VISUAL_SHOT ", path)


## The stage's big earth plane, which sits at y = 0: on a 500 m lake it is far
## below the village, so the surround's own floor height stands in for it.
func _stage_floor() -> MeshInstance3D:
	for c in _root3d.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is PlaneMesh:
			return c
	return null
