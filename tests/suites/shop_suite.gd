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
	return res
