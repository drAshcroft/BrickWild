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

	_check_expected_privacy_failure(res)
	return res


## EXPECTED-FAIL (LAY-007 proof / LAY-008 tracker): the current
## `HotelPlanner._connect_level` hard-codes doors 0<->3 and 2<->5 on every
## level, so guest room 3 is reachable only through guest room 0, and room 5
## only through suite 2 -- both sleeping rooms under LAY-007's
## `HouseGeometry.SLEEPING`. `HousePlanCheck._check_privacy` now catches this;
## until LAY-008 replaces the fixed 6-room level with a gallery corridor, the
## failure below is EXPECTED. If it stops appearing, LAY-008 has landed --
## delete this block (and the plain "expects" comment) rather than leaving a
## check that always trivially passes.
static func _check_expected_privacy_failure(res: SuiteResult) -> void:
	var spec := HotelSpec.new()
	var plan := HotelGenerator.generate(spec, 41001)
	var report: Dictionary = HousePlanCheck.new().check(plan)
	res.checked += 1
	var saw_room_3 := false
	var saw_room_5 := false
	for f in report["failures"]:
		var msg: String = str(f)
		if not msg.begins_with("privacy:"):
			continue
		for storey in range(1, spec.storeys):
			var room3 := storey * 6 + 3
			var room5 := storey * 6 + 5
			if ("room %d " % room3) in msg:
				saw_room_3 = true
			if ("room %d " % room5) in msg:
				saw_room_5 = true
	if not (saw_room_3 and saw_room_5):
		res.fail("LAY-007 proof: expected the CURRENT hotel planner to fail " +
			"privacy on upper-level guest rooms 3 and 5 (LAY-008 not yet " +
			"landed); it did not -- if LAY-008 landed, delete this expected-fail check")
	else:
		res.note("expected-fail confirmed: hotel privacy fails on rooms 3 and 5 " +
			"per level until LAY-008 (see qa/house_plan_check.gd _check_privacy)")
