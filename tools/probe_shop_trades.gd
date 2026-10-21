extends SceneTree
## Probe: what each trade's shop is made of, room by room, over the shoptrade
## matrix. One block per (trade, size, seed): rooms with kind/area/storey,
## interior doors, and the furniture categories (keys) in each room.
## godot --headless --path . --script res://tools/probe_shop_trades.gd -- butcher tailor
func _initialize() -> void:
	var wanted: Array = []
	for a in OS.get_cmdline_user_args():
		wanted.append(StringName(a))
	if wanted.is_empty():
		wanted = [&"butcher", &"apothecary", &"tailor", &"carpenter", &"blacksmith"]
	for business in wanted:
		for size in ShopTradeSuite.SIZES:
			for seed_ in ShopTradeSuite.SEEDS:
				var plan := ShopTradeSuite._make(business, size, seed_)
				print("=== %s %dx%d seed %d  entrance room %d (%s)" % [business, int(size.x), int(size.y),
					seed_, plan.entrance_room(), plan.kind_of(plan.entrance_room())])
				for r in range(plan.room_count()):
					var rect := HouseGeometry.room_floor_rect(plan, r)
					var items: PackedStringArray = []
					for f in plan.furniture_of(r):
						var p: Dictionary = plan.furniture[f]
						items.append("%s:%s%s" % [PropCatalog.category(String(p["key"])), p["key"],
							"(m)" if p.get("mounted", false) else ""])
					print("  room %d %s area %.1f storey %d: %s" % [r, plan.kind_of(r),
						rect.get_area(), plan.storey_of_room(r), ", ".join(items)])
				var doors: PackedStringArray = []
				for d in plan.doors:
					doors.append("%d-%d%s" % [int(d["a"]), int(d["b"]), "x" if d.get("exterior", false) else ""])
				print("  doors: ", " ".join(doors))
				print("  bakery contract: ", ShopTradeSuite.contract(plan))
	quit()
