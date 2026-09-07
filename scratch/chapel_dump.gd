extends SceneTree
func _init() -> void:
	for e in CastleSweep.each():
		if int(e["index"]) != 1 or String(e["style"]) != "edwardian":
			continue
		var spec: CastleSpec = CastleSweep.spec_at(e["style"], e["tier"], 1)
		var plan: HousePlan = CastleGenerator.chapel_plan(spec)
		print("=== %s  chapel %s" % [String(e["tier"]),
			str(CastleGeometry.chapel_aabb(spec).size.snappedf(0.01))])
		if plan.spec == null:
			print("  no chapel plan")
			continue
		var f: Rect2 = HouseGeometry.room_floor_rect(plan, 0)
		var rows := {}
		for p in plan.furniture:
			var g: String = String(p.get("row", ""))
			if g != "":
				rows[g] = int(rows.get(g, 0)) + 1
		print("  nave %s  focus %s  rows %s  furniture %d"
			% [str(f.size.snappedf(0.01)), str(plan.focus_pos().snappedf(0.01)),
				str(rows), plan.furniture.size()])
		for i in range(plan.furniture.size()):
			var q: Dictionary = plan.furniture[i]
			print("    %2d %-18s %-12s at %s row %s" % [i, String(q["key"]),
				PropCatalog.category(String(q["key"])),
				str(Rect2(q["rect"]).get_center().snappedf(0.01)),
				String(q.get("row", "-"))])
		print("  compromises ", plan.compromises)
		print("  plan:    ", HousePlanCheck.new().check(plan)["failures"])
		print("  furnish: ", HouseFurnishCheck.new().check(plan)["failures"])
		print("  nav:     ", HouseNavCheck.new().check(plan)["failures"])
	quit()
