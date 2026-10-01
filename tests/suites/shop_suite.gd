class_name ShopSuite
extends RefCounted
## Contract for the shared plan-first commercial/civic pipeline.


static func run() -> SuiteResult:
	var res := SuiteResult.new("shops")
	for business in ShopSpec.BUSINESSES:
		var spec := ShopSpec.new()
		spec.business = business
		spec.style = &"longhall" if business in [&"blacksmith", &"stable", &"carpenter"] else &"townhouse"
		spec.width = 12.0
		spec.length = 16.0
		spec.height = 2.8
		var seed := 31000 + absi(String(business).hash()) % 900
		var plan: HousePlan = ShopGenerator.generate(spec, seed)
		res.checked += 1
		var where := "business=%s seed=%d" % [String(business), seed]
		if spec.business != business or plan.spec != spec:
			res.fail("user inputs or plan identity changed, " + where)
			continue
		if not plan.has_kind(spec.front_room()):
			res.fail("no public/work room '%s', %s" % [String(spec.front_room()), where])
		if plan.furniture.is_empty():
			res.fail("nothing was furnished, " + where)
		var builder := HouseBuilder.new()
		var mesh: ArrayMesh = builder.build(plan)
		if mesh == null or mesh.get_surface_count() != 4 or builder.mass_log.is_empty():
			res.fail("bad shell, " + where)

	var a := ShopSpec.new()
	a.business = &"blacksmith"
	a.style = &"longhall"
	a.width = 12.0
	a.length = 16.0
	var b := ShopSpec.new()
	b.business = a.business
	b.style = a.style
	b.width = a.width
	b.length = a.length
	var pa := ShopGenerator.generate(a, 31991)
	var pb := ShopGenerator.generate(b, 31991)
	res.checked += 1
	if pa.rooms != pb.rooms or pa.doors != pb.doors or pa.windows != pb.windows \
			or pa.furniture != pb.furniture:
		res.fail("the same shop request produced two different plans")
	_internal_room_focus(res)
	return res


## A narrow stone stable enters through its tack room. The stall must face
## the stable's actual internal doorway, not an imagined centred street door.
static func _internal_room_focus(res: SuiteResult) -> void:
	var spec := ShopSpec.new()
	spec.business = &"stable"
	spec.style = &"longhall"
	spec.material = &"stone"
	spec.width = 7.0
	spec.length = 8.0
	spec.height = 3.2
	var plan := ShopGenerator.generate(spec, 478822315)
	res.checked += 1
	if plan.focus_room() == plan.entrance_room():
		res.fail("internal stable focus fixture no longer exercises an indirect entrance")
	for report in [HousePlanCheck.new().check(plan), HouseFurnishCheck.new().check(plan),
			HouseNavCheck.new().check(plan)]:
		res.checked += 1
		for failure in report.failures:
			res.fail("internal stable focus: " + String(failure))
	var stall := -1
	for index in plan.furniture_of(plan.focus_room()):
		if PropCatalog.category(plan.furniture[index].key) == plan.focus_cat():
			stall = index
			break
	res.checked += 1
	if stall < 0:
		res.fail("internal stable focus: the stall was removed instead of facing its door")
		return
	plan.furniture[stall].yaw += PI
	var check := HouseFurnishAffinityCheck.new()
	check.check_focus(plan)
	res.checked += 1
	if check.failures.is_empty():
		res.fail("internal stable focus: turning the stall away from its door was not detected")
