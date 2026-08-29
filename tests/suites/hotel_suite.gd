class_name HotelSuite
extends RefCounted
## Determinism and plan/build contract for the landmark hotel family.


static func run() -> SuiteResult:
	var res := SuiteResult.new("grand hotel")
	for style in HotelSpec.HOTEL_STYLES:
		for seed in [41001]:
			var spec := HotelSpec.new()
			spec.style = style
			var plan := HotelGenerator.generate(spec, seed)
			var builder := HotelBuilder.new()
			var before := plan.furniture.size()
			var mesh := builder.build(plan)
			res.checked += 1
			var where := "style=%s seed=%d" % [String(style), seed]
			if plan.spec != spec or spec.seed != seed or spec.storeys != 3:
				res.fail("identity or storeys changed, " + where)
			if plan.room_count() != 18 or plan.stairs.size() != 2:
				res.fail("expected 18 rooms and two stairs, " + where)
			if plan.furniture.size() != before:
				res.fail("build mutated furnishings, " + where)
			if mesh == null or mesh.get_surface_count() != 4:
				res.fail("bad four-surface hotel mesh, " + where)
			if builder.mass_log.is_empty() or builder.part_log.size() < 300:
				res.fail("hotel facade is structurally under-described, " + where)

	var a := HotelSpec.new()
	var b := HotelSpec.new()
	var pa := HotelGenerator.generate(a, 41999)
	var pb := HotelGenerator.generate(b, 41999)
	res.checked += 1
	if a.variant_name != b.variant_name or pa.rooms != pb.rooms or pa.doors != pb.doors \
			or pa.windows != pb.windows or pa.furniture != pb.furniture:
		res.fail("same hotel seed produced different plans")
	return res
