extends SceneTree

func _initialize() -> void:
	for row in [
		{"name": "bologna-8803", "style": &"norman", "w": 8.0, "l": 8.0, "h": 45.0, "seed": 8803},
		{"name": "scottish-8804", "style": &"norman", "w": 14.0, "l": 12.0, "h": 34.0, "seed": 8804},
	]:
		var spec := CastleSpec.new()
		spec.style = row.style
		spec.width = row.w
		spec.length = row.l
		spec.height = row.h
		spec.plan_override = &"tower_house"
		CastleGenerator.generate(spec, int(row.seed))
		var bare_plan: HousePlan = CastleTowerPlan.generate(spec, false)
		print("FIXTURE ", row.name, " plan=", spec.plan_kind, " kind=", spec.tower_type,
			" levels=", spec.tower_storeys, " dimensions=", CastleGeometry.tower_house_aabb(spec),
			" window_dims=", spec.window_w, "x", spec.window_h,
			" planned_windows=", bare_plan.windows.size(), " plan_window=", bare_plan.windows[0] if not bare_plan.windows.is_empty() else {})
		var builder := CastleBuilder.new()
		builder.build(spec)
		var doors := builder.part_log.filter(func(p): return p.kind == "door")
		var windows := builder.part_log.filter(func(p): return p.kind == "window")
		print("LOG doors=", doors.size(), " windows=", windows.size(), " parts=", builder.part_log.size(),
			" interior_errors=", builder.interior_errors)
		if not builder.interiors.is_empty():
			var child: HouseBuilder = builder.interiors[0].builder
			var child_windows := child.part_log.filter(func(p): return p.kind == "window")
			var child_doors := child.part_log.filter(func(p): return p.kind == "window" and p.get("opening_kind", "") == "door")
			print("CHILD plan_windows=", child.plan.windows.size(), " child_windows=", child_windows.size(),
				" child_doors=", child_doors.size(), " room0_outline=", child.plan.outline_of(0))
		for part in doors + windows:
			print("OPENING ", part.kind, " tag=", part.tag, " pos=", part.pos,
				" size=", part.size, " facing=", part.facing)
		print("TOWER_CHECK ", TowerCheck.new().check(spec, builder).failures)
		print("MASSING_CHECK ", CastleMassingCheck.new().check(spec, builder).failures)
	quit()
