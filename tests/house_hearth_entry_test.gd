extends SceneTree
## Fixed bounded-furnishing hearth/daylight regressions and a real clear entry.
var failures: Array[String] = []

func _initialize() -> void:
	for n in [0, 6]:
		var spec := HouseSpec.new()
		spec.style = HouseSweep.styles()[n % HouseSweep.styles().size()]
		spec.trade = HouseSweep.trades()[n % HouseSweep.trades().size()]
		spec.width = 6.0 + float(n % 5) * 2.0
		spec.length = 7.0 + float(n % 7) * 1.8
		spec.storeys = 1 + (n % 2)
		var plan := HouseGenerator.generate(spec, 60000 + n)
		var where := "%s seed=%d" % [spec.style, 60000 + n]
		var report := HouseFurnishCheck.new().check(plan)
		for message: String in report["failures"]:
			failures.append(where + ": " + message)
		var nav := HouseNavCheck.new().check(plan)
		if not nav["ok"]:
			failures.append(where + ": " + str(nav["failures"]))
		if HouseGeometry.hearth_breast(plan).is_empty():
			failures.append(where + ": missing measured native hearth")
		var hearth_check := HouseFurnishSpatialCheck.new()
		var saved: Dictionary = plan.hearth["breast"]
		plan.hearth.erase("breast")
		hearth_check.check_hearth(plan)
		if hearth_check.failures.is_empty():
			failures.append(where + ": missing hearth negative passed")
		plan.hearth["breast"] = saved
		var entrance: Dictionary = plan.doors[plan.entrance()]
		var centre: Vector2 = entrance["pos"]
		var table := HouseFurnishGeometry.candidate("Table_Large", centre, 0.0)
		table["room"] = plan.entrance_room()
		table["storey"] = HousePlan.record_storey(entrance)
		plan.furniture.append(table)
		var entry_check := HouseFurnishWalkCheck.new()
		entry_check.check_front_door(plan)
		if entry_check.failures.is_empty():
			failures.append(where + ": table across entrance negative passed")
		plan.furniture.pop_back()
		if n == 0:
			var table_count := 0
			var seat_count := 0
			for piece: Dictionary in plan.furniture:
				if String(piece.get("cat", "")) == "table":
					table_count += 1
				if String(piece.get("cat", "")) in ["seat", "bench"] and int(piece.get("host", -1)) >= 0:
					seat_count += 1
			if table_count < 1 or seat_count < 2:
				failures.append(where + ": entry clearance cost the required dining group")
	for message in failures:
		push_error(message)
	print("hearth and entry: 2 exact households with physical negative controls, %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)
