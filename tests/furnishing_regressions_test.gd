extends SceneTree
## Named backlog regressions, without an unrelated statistical sweep.

func _init() -> void:
	var result := SuiteResult.new("furnishing regressions")
	HouseQASuite._seed_60068_shelf_over(result)
	HouseQASuite._fs_bed_window(result)
	for scale in HouseArchetypeSuite.SCALES:
		var spec := HouseSpec.new()
		spec.style = &"cottage"
		spec.trade = &"none"
		spec.width = 5.5 * scale
		spec.length = 7.0 * scale
		spec.height = 2.4
		var seed_value := HouseArchetypeSuite._seed_for("one_room_cottage", scale)
		var plan := HouseGenerator.generate(spec, seed_value)
		var builder := HouseBuilder.new()
		builder.build(plan)
		var report := HouseQA.new().check(plan, builder)
		result.checked += 1
		for failure in report.failures:
			result.fail("cottage %.2f: %s" % [scale, failure])
		if scale >= 1.0 and not HouseArchetypeSuite._has_any_category(plan, "bed"):
			result.fail("cottage %.2f seed=%d has no bed; rooms=%s doors=%s windows=%s" % [scale, seed_value, plan.rooms, plan.doors, plan.windows])
		for piece in plan.furniture:
			if PropCatalog.category(piece.key) == "bed":
				var length: float = PropCatalog.footprint(piece.key).y * float(piece.get("scale", 1.0))
				if length < 2.0:
					result.fail("bed became shorter than two metres")
				result.checked += 1
		print("cottage %.2f seed=%d furniture=%s" % [scale, seed_value, plan.furniture.map(func(p): return p.key)])
	for scale in HouseArchetypeSuite.SCALES:
		var spec := HouseSpec.new()
		spec.style = &"cottage"
		spec.width = 8.0 * scale
		spec.length = 10.5 * scale
		spec.height = 2.6
		var plan := HouseGenerator.generate(spec, HouseArchetypeSuite._seed_for("family_cottage", scale))
		var builder := HouseBuilder.new()
		builder.build(plan)
		var report := HouseQA.new().check(plan, builder)
		result.checked += 1
		for failure in report.failures:
			result.fail("family cottage %.2f: %s" % [scale, failure])
		if scale >= 1.0:
			for category in ["table", "seat"]:
				result.checked += 1
				if not HouseArchetypeSuite._has_any_category(plan, category):
					result.fail("family cottage %.2f has no %s" % [scale, category])
		# A recovered dining group must remain physically usable. Moving its
		# chair outside the room must still fail the normal furnishing QA.
		if is_equal_approx(scale, 1.0):
			for piece in plan.furniture:
				if PropCatalog.category(piece.key) == "seat":
					piece.rect.position += Vector2(20, 0)
					piece.pos.x += 20
					result.checked += 1
					if HouseFurnishCheck.new().check(plan).ok:
						result.fail("displaced dining chair escaped furniture QA")
					break
	for failure in result.failures:
		print("FAIL: " + failure)
	print(result.summary())
	quit(0 if result.ok() else 1)
