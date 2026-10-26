extends SceneTree
## Probe: one shoptrade case's front room, customer lane and walk map.
## godot --headless --path . --script res://tools/probe_shop_lane.gd -- carpenter 11 15 1
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var business := StringName(a[0]) if a.size() > 0 else &"carpenter"
	var size := Vector2(float(a[1]), float(a[2])) if a.size() > 2 else Vector2(11, 15)
	var seed_ := int(a[3]) if a.size() > 3 else 1
	var plan := ShopTradeSuite._make(business, size, seed_)
	var room := plan.entrance_room()
	var focus: String = ShopTradeSuite.WORK_FRONT_TRADES.get(business, "counter")
	print("front room ", room, " ", plan.kind_of(room), " floor ", HouseGeometry.room_floor_rect(plan, room))
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		print("  ", PropCatalog.category(String(p["key"])), " ", p["key"], " ", p["rect"], " mounted=", p.get("mounted", false))
	var lane := ShopTradeSuite._lane(plan, focus)
	print("lane ", lane)
	print("contract ", ShopTradeSuite.trade_contract(plan, business))
	var nav := HouseNavCheck.new()
	nav.check(plan)
	print(nav.ascii_map())
	quit()
