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
			var want_rooms := 0
			for storey in range(3):
				want_rooms += HotelPlanner.rooms_on_level(spec, storey)
			if plan.room_count() != want_rooms or plan.stairs.size() != 2:
				res.fail("expected %d rooms (from %d bays) and two stairs, got %d and %d, %s"
					% [want_rooms, spec.facade_bays, plan.room_count(),
					plan.stairs.size(), where])
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

	_check_gallery_plan(res)
	return res


## The gallery plan (LAY-008), measured: the privacy rule that used to fail on
## the fixed six-room level is silent, every level has one gallery down its
## length, every sleeping room has one door and it opens onto the gallery or
## the lobby, and the room count follows the facade's bays.
static func _check_gallery_plan(res: SuiteResult) -> void:
	for seed in [41001, 41002, 41003]:
		var spec := HotelSpec.new()
		spec.width = 30.0 + float(seed % 3) * 12.0
		spec.length = 16.0 + float(seed % 3) * 8.0
		var plan := HotelGenerator.generate(spec, seed)
		var report: Dictionary = HousePlanCheck.new().check(plan)
		res.checked += 1
		for f in report["failures"]:
			if str(f).begins_with("privacy:"):
				res.fail("seed=%d %s" % [seed, str(f)])
		var builder := HotelBuilder.new()
		builder.build(plan)
		var qa: Dictionary = HotelQA.new().check(plan, builder)
		for f in qa["failures"]:
			if str(f).begins_with("gallery:") or str(f).begins_with("bays:"):
				res.fail("seed=%d %s" % [seed, str(f)])
