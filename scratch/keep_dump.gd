extends SceneTree
## The keep plan for a few castles, in numbers.


func _init() -> void:
	for e in CastleSweep.each():
		if String(e["tier"]) != "castle" or int(e["index"]) != 1:
			continue
		var spec: CastleSpec = CastleSweep.spec_at(e["style"], e["tier"], int(e["index"]))
		var plan: HousePlan = CastleKeepPlan.generate(spec)
		print("=== %s keep %s" % [String(e["style"]),
			str(CastleGeometry.keep_aabb(spec).size.snappedf(0.01))])
		if plan.spec == null:
			print("  no keep plan")
			continue
		print("  storeys %d  height %.2f  interior %s"
			% [plan.spec.storeys, plan.spec.height,
				str(HouseGeometry.interior_rect(plan.spec))])
		for i in range(plan.room_count()):
			print("   room %d %-14s storey %d" % [i, String(plan.kind_of(i)),
				plan.storey_of_room(i)])
		print("  stairs %d  windows %d  hearth room %d wall %d"
			% [plan.stairs.size(), plan.windows.size(), plan.hearth_room(),
				plan.hearth_wall()])
		print("  compromises ", plan.compromises)
		print("  plan:    ", HousePlanCheck.new().check(plan)["failures"])
		print("  furnish: ", HouseFurnishCheck.new().check(plan)["failures"])
		print("  nav:     ", HouseNavCheck.new().check(plan)["failures"])
	quit()
