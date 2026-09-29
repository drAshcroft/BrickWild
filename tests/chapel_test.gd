extends SceneTree
## INT-005: real furnished chapel, complete shell QA, and negative mutations.

func _init() -> void:
	var failures: Array[String] = []
	var checked := 0
	for shape in [Vector2(60, 90), Vector2(80, 110)]:
		var spec := CastleSpec.new()
		spec.style = &"edwardian"
		spec.width = shape.x
		spec.length = shape.y
		spec.height = 18
		CastleGenerator.generate(spec, 1)
		spec.chapel = true
		var plan := CastleInteriorPlans.chapel_plan(spec)
		if plan.spec == null:
			failures.append("no chapel at %s" % shape)
			continue
		var builder := HouseBuilder.new()
		builder.build(plan)
		var report := HouseQA.new().check(plan, builder)
		for failure in report.failures:
			failures.append("%s: %s" % [shape, failure])
		checked += 1
		var altar := -1
		var rows := {}
		for i in range(plan.furniture.size()):
			var item: Dictionary = plan.furniture[i]
			if PropCatalog.category(String(item.key)) == "table" \
					and Rect2(item.rect).get_center().distance_to(plan.focus_pos()) < 0.3:
				altar = i
			var row: String = item.get("row", "")
			if row != "":
				rows[row] = int(rows.get(row, 0)) + 1
		if altar < 0 or rows.size() < 2:
			failures.append("%s: altar=%d pew rows=%s" % [shape, altar, rows])
		checked += 1
		for zone in plan.zones:
			if zone.get("why", "") == "chapel centre aisle":
				var aisle: Rect2 = zone.rect
				if minf(aisle.size.x, aisle.size.y) < 1.2 - 0.001:
					failures.append("chapel aisle narrower than 1.2m")
				checked += 1
		failures.append_array(TempleRiteCheck.plan_axis_faults(plan, 0, plan.entrance()))
		failures.append_array(TempleRiteCheck.plan_sightline_faults(plan, altar, plan.entrance()))
		checked += 2
		var nav := HouseNavCheck.new()
		nav.check(plan)
		var old_focus: Vector2 = plan.focus.pos
		plan.focus.pos += Vector2(2, 2)
		if TempleRiteCheck.plan_axis_faults(plan, 0, plan.entrance()).is_empty():
			failures.append("axis mutation was not detected")
		plan.focus.pos = old_focus
		checked += 1
		if altar >= 0:
			var blocker: Dictionary = plan.furniture[altar].duplicate(true)
			var midway: Vector2 = (plan.focus_pos() + Vector2(plan.doors[plan.entrance()].pos)) * 0.5
			blocker.rect = Rect2(midway - Vector2(1, 1), Vector2(2, 2))
			blocker.scale = 8.0
			blocker.host = -1
			plan.furniture.append(blocker)
			if TempleRiteCheck.plan_sightline_faults(plan, altar, plan.entrance()).is_empty():
				failures.append("sightline mutation was not detected")
			plan.furniture.pop_back()
			checked += 1
		print("chapel %s: altar=%d rows=%s warnings=%s" % [shape, altar, rows, report.warnings])
	for failure in failures:
		print("FAIL: " + failure)
	print("chapel: %d checks, %d failures" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)
