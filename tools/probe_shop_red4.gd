extends SceneTree
func _init() -> void:
	var spec := ShopSpec.new()
	spec.business = &"barracks"
	spec.style = &"longhall"
	spec.width = 18.0 * 1.4
	spec.length = 28.0 * 1.4
	spec.height = 2.9
	var plan: HousePlan = ShopGenerator.generate(spec, 43800 + 140)
	for r in plan.room_count():
		print("room ", r, " ", plan.kind_of(r), " ", HouseGeometry.room_floor_rect(plan, r))
	for i in plan.furniture.size():
		var f: Dictionary = plan.furniture[i]
		if plan.kind_of(int(f["room"])) == &"mess":
			print(i, " ", f["key"], " host=", f.get("host", -1), " rect=", f["rect"], " zone=", f.get("zone", Rect2()), " row=", f.get("row",""))
	quit()
