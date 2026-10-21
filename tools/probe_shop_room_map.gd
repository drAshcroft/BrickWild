extends SceneTree
## Probe: one sarchetype business built exactly as that suite builds it; prints
## a room's furniture, the furnish-check failures and the walk map.
## godot --headless --path . --script res://tools/probe_shop_room_map.gd -- guildhall meeting_hall
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var business := StringName(a[0]) if a.size() > 0 else &"guildhall"
	var kind := StringName(a[1]) if a.size() > 1 else &"meeting_hall"
	var spec := ShopSpec.new()
	spec.business = business
	spec.style = &"longhall" if business in [&"blacksmith", &"stable", &"carpenter", &"library", &"prison"] else &"townhouse"
	spec.width = 14.0
	spec.length = 18.0
	spec.height = 2.9
	var plan := ShopGenerator.generate(spec, 33000 + absi(String(business).hash()) % 900)
	for r in range(plan.room_count()):
		if plan.kind_of(r) != kind:
			continue
		print("room ", r, " floor ", HouseGeometry.room_floor_rect(plan, r), " storey ", plan.storey_of_room(r))
		for d in plan.doors_of(r):
			print("  door ", plan.doors[d]["a"], "-", plan.doors[d]["b"], " pos ", plan.doors[d]["pos"], " w ", plan.doors[d]["width"])
		for f in plan.furniture_of(r):
			var p: Dictionary = plan.furniture[f]
			print("  [", f, "] ", p["key"], " ", p["rect"], " host ", p.get("host", -1), " mounted ", p.get("mounted", false))
	print("compromises ", plan.compromises)
	var rep: Dictionary = HouseFurnishCheck.new().check(plan)
	print("furnish failures ", rep["failures"])
	var nav := HouseNavCheck.new()
	nav.check(plan)
	print(nav.ascii_map())
	quit()
