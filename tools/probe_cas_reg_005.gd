extends SceneTree
## CAS-REG-005: isolate the keep's front-door stair conflict before building
## either full Crusader enclosure.


func _initialize() -> void:
	var castle := CastleSweep.spec_at(&"crusader", &"castle", 1)
	var fortress := CastleSpec.new()
	fortress.style = &"crusader"
	fortress.width = 90.0
	fortress.length = 140.0
	fortress.height = 20.0
	CastleGenerator.generate(fortress, 9118)
	for spec in [castle, fortress]:
		var plan := CastleKeepPlan.generate(spec, false)
		print("CASE seed=", spec.seed, " tier=", spec.tier,
			" keep_shape=", spec.keep_shape, " rooms=", plan.room_count(),
			" stairs=", plan.stairs.size())
		if plan.room_count() == 0:
			continue
		var front := plan.entrance()
		var door: Dictionary = plan.doors[front]
		var entry := int(door.a)
		var line := HousePlanLevels.door_line(plan, entry, door)
		print("DOOR room=", entry, " pos=", door.pos, " normal=", door.normal,
			" line=", line, " room_rect=", plan.rooms[entry].rect)
		for index in range(plan.stairs.size()):
			var stair: Dictionary = plan.stairs[index]
			var rect: Rect2 = stair.lower_rect
			var hit := line.intersection(rect)
			print("STAIR index=", index, " a=", stair.a, " b=", stair.b,
				" rect=", rect, " hit=", hit, " wall_gap=",
				HousePlanCheck.stair_wall_gap(plan, stair))
		print("PLAN_FAILURES ", HousePlanCheck.new().check(plan).failures)
	quit()
