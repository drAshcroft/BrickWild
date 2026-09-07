extends SceneTree
## The exact hall the render shows, in numbers.


func _init() -> void:
	var spec := CastleSpec.new()
	spec.style = &"edwardian"
	spec.width = 60.0
	spec.length = 90.0
	spec.height = 18.0
	CastleGenerator.generate(spec, 9001)
	var plan: HousePlan = CastleGenerator.hall_plan(spec)
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, 0)
	print("room  ", f, "   dais ", plan.dais_rect(), " rise ", plan.dais_rise())
	print("door  ", plan.doors[0]["pos"], "  zones ", plan.zones)
	print("focus ", plan.focus_pos(), " placed=", plan.focus.get("placed", false))
	print("compromises ", plan.compromises)
	var strip: Rect2 = plan.zones[0]["rect"]
	for i in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[i]
		var r: Rect2 = p["rect"]
		var flag := ""
		if PropCatalog.blocks_floor(String(p["key"])) and int(p["host"]) < 0 \
				and not p.get("mounted", false) and r.intersects(strip):
			flag = "  <-- IN THE SCREENS PASSAGE"
		if plan.dais_rect().has_point(r.get_center()):
			flag += "  [on the dais]"
		print("  %2d %-18s %-10s at %s  z-span %.2f..%.2f%s"
			% [i, String(p["key"]), PropCatalog.category(String(p["key"])),
				str(r.get_center()), r.position.y, r.end.y, flag])
	print("furnish: ", HouseFurnishCheck.new().check(plan)["failures"])
	print("nav:     ", HouseNavCheck.new().check(plan)["failures"])
	quit()
