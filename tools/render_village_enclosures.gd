extends "res://tools/render_shots.gd"
## VIL-018 builder-level render matrix; planner-independent synthetic water fixtures.

const OUT := "res://artifacts/p1_acceptance/village_enclosures"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_stage()
	await process_frame
	var enclosures: Array[StringName] = [&"hedge", &"palisade", &"wall"]
	var waters: Array[StringName] = [&"none", &"stream", &"river", &"pond", &"coast"]
	var index := 0
	for enclosure in enclosures:
		for water in waters:
			var spec := VillageSpec.new(28000 + index)
			spec.population = 180 if enclosure == &"wall" else 90
			spec.purpose = &"garrison" if enclosure == &"wall" else (&"farming" if water == &"none" else &"mill")
			spec.culture = &"english"
			spec.enclosure = enclosure
			spec.water = water
			spec.wealth = 0.6
			spec.generate(28000 + index)
			var plan := VillageSitePlanner.plan(spec)
			_add_water_fixture(plan, water)
			await _shot(plan, "%s_%s.jpg" % [String(enclosure), String(water)])
			index += 1
	print("Village enclosure renders complete")
	quit()

func _add_water_fixture(plan: VillagePlan, kind: StringName) -> void:
	if kind == &"none" or not plan.water.is_empty():
		return
	var s := plan.site
	var poly: PackedVector2Array
	if kind == &"coast":
		poly = Poly.from_rect(Rect2(Vector2(s.position.x, s.end.y - 18.0), Vector2(s.size.x, 18.0)))
	elif kind == &"pond":
		poly = Poly.from_rect(Rect2(Vector2(s.get_center().x - 30.0, s.get_center().y - 14.0), Vector2(60.0, 28.0)))
	else:
		var width := 8.0 if kind == &"river" else 3.0
		poly = Poly.from_rect(Rect2(Vector2(s.get_center().x - width * 0.5, s.position.y), Vector2(width, s.size.y)))
	plan.water.append({"poly": poly, "kind": kind})

func _shot(plan: VillagePlan, file: String) -> void:
	var mesh := VillageBuilder.new().build(plan)
	_mesh_inst.mesh = mesh
	for i in range(mesh.get_surface_count()):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(VillageBuilder.COLOURS.get(i, "808080"))
		material.roughness = 0.9
		_mesh_inst.set_surface_override_material(i, material)
	var aabb := mesh.get_aabb()
	var centre := aabb.get_center()
	var radius := maxf(aabb.size.length() * 0.5, 10.0)
	var dist := radius / tan(deg_to_rad(_cam.fov) / 2.0) * 1.12
	var dir := Vector3(0.72, 0.68, 0.72).normalized()
	_cam.position = centre + dir * dist
	_cam.look_at(centre, Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_jpg(OUT + "/" + file, 0.92)
	print("  ", OUT + "/" + file)
	_mesh_inst.mesh = null
