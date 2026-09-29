extends SceneTree
## Scratch: print one hall in full -- dimensions, dais, furniture, walk map.
##
##   godot --headless --path . --script res://scratch/hall_dump.gd -- 83 148


func _init() -> void:
	var want := {}
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			want[a.to_int()] = true
	var styles: Array = CastleSpec.STYLES.keys()
	var r := RandomNumberGenerator.new()
	r.seed = 20261001
	for i in range(HallSuite.COUNT):
		var spec := CastleSpec.new()
		spec.style = styles[i % styles.size()]
		spec.width = r.randf_range(8.0, 80.0)
		spec.length = spec.width * r.randf_range(1.0, 2.0)
		spec.height = r.randf_range(5.0, 20.0)
		if not want.has(i):
			continue
		CastleGenerator.generate(spec, 31000 + i)
		_dump("%s %.0f x %.0f seed=%d" % [String(spec.style), spec.width,
			spec.length, 31000 + i], spec)
	quit()


func _dump(who: String, spec: CastleSpec) -> void:
	var plan: HousePlan = CastleInteriorPlans.hall_plan(spec)
	print("=== ", who)
	if plan.spec == null:
		print("  no hall plan")
		return
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, 0)
	print("  room  %s" % str(f))
	print("  dais  %s rise %.2f" % [str(plan.dais_rect()), plan.dais_rise()])
	print("  door  %s" % str(plan.doors[0]["pos"]))
	print("  focus %s facing %.2f placed=%s" % [str(plan.focus_pos()),
		plan.focus_facing(), str(plan.focus.get("placed", false))])
	print("  hearth wall %d, compromises %s" % [plan.hearth_wall(),
		str(plan.compromises)])
	for i in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[i]
		print("   %2d %-16s cat=%-10s at %s yaw %.2f host %d row %s"
			% [i, String(p["key"]), PropCatalog.category(String(p["key"])),
				str(Rect2(p["rect"]).get_center()), float(p["yaw"]),
				int(p["host"]), String(p.get("row", "-"))])
	print("  furnish: ", HouseFurnishCheck.new().check(plan)["failures"])
	print("  nav:     ", HouseNavCheck.new().check(plan)["failures"])
