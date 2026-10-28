extends SceneTree
func _init() -> void:
	var spec := ShopArchetypeSuite._int013_spec(&"hospice", 0.7)
	var plan := ShopGenerator.generate(spec, 71300 + 2 * 10 + 70)
	for r in plan.room_count():
		print("room ", r, " ", plan.kind_of(r), " ", HouseGeometry.room_area(plan, r), " ", HouseGeometry.room_floor_rect(plan, r))
	for i in plan.furniture.size():
		var f: Dictionary = plan.furniture[i]
		if int(f["room"]) >= 0:
			print(i, " ", f["key"], " host=", f.get("host", -1), " ", f["rect"], " row=", f.get("row",""), " ", f.get("compromise",""))
	print(plan.compromises)
	quit()
