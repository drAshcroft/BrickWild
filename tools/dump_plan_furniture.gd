extends SceneTree
## Prints a plan-backed building's rooms, doors and furniture as plain rows,
## through the public path the walk rig uses, so a walk pin can be read
## against the records under it.
##   godot --headless --path . --script res://tools/dump_plan_furniture.gd -- kind=house style=cottage seed=1 [purpose=..] [room=2]


func _initialize() -> void:
	var a := {}
	for s in OS.get_cmdline_user_args():
		if "=" in s:
			a[s.get_slice("=", 0)] = s.get_slice("=", 1)
	var req := BrickWild.default_request(StringName(a.get("kind", "house")), int(a.get("seed", "1")))
	if a.has("style"):
		req.style = StringName(a["style"])
	if a.has("purpose"):
		req.purpose = StringName(a["purpose"])
	var b := BrickWild.generate(req)
	var plan := b.plan as HousePlan
	if plan == null:
		print("no house plan: ", b.errors)
		quit()
		return
	var only := int(a.get("room", "-1"))
	print("entrance door %d, room %d" % [plan.entrance(), plan.entrance_room()])
	for i in plan.room_count():
		if only >= 0 and i != only:
			continue
		var r: Dictionary = plan.rooms[i]
		print("room %d %s storey %d rect %s area %.1f" % [i, plan.kind_of(i),
			HousePlan.record_storey(r), r.get("rect"), HouseGeometry.room_area(plan, i)])
		for d in plan.doors_of(i):
			var door: Dictionary = plan.doors[d]
			print("   door %d pos %s n %s w %.2f ext %s front %s a %d b %d" % [d, door["pos"],
				door["normal"], float(door["width"]), door["exterior"], door.get("front", false),
				int(door["a"]), int(door["b"])])
		for f in plan.furniture_of(i):
			var p: Dictionary = plan.furniture[f]
			print("   f%-3d %-22s %-10s rect %s yaw %.2f host %d mounted %s zone %s" % [f, p["key"],
				PropCatalog.category(p["key"]), p["rect"], float(p["yaw"]), int(p.get("host", -1)),
				p.get("mounted", false), p.get("zone", Rect2())])
	quit()
