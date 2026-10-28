extends SceneTree
## Probe: the hospice ward at a given scale -- doors, windows, beds, rows.
## godot --headless --path . --script res://tools/probe_ward.gd -- [scale] [seed]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var scale := float(a[0]) if a.size() > 0 else 0.7
	var spec := ShopArchetypeSuite._int013_spec(&"hospice", scale)
	var seed := int(a[1]) if a.size() > 1 else 71390
	var plan := ShopGenerator.generate(spec, seed)
	var ward := ShopArchetypeSuite._int013_contract_room(plan, &"hospice")
	print("ward room ", ward, " rect ", Rect2(plan.rooms[ward]["rect"]))
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, ward)
	print("floor ", floor_rect)
	var walls := HouseGeometry.room_walls(plan, ward)
	for wi in walls.size():
		print(" wall ", wi, " ", walls[wi]["from"], "->", walls[wi]["to"], " n=", walls[wi]["normal"], " lit=", HouseFurnishSpatialCheck.fs_wall_lit(plan, ward, wi))
	for d in plan.doors_of(ward):
		var dr: Dictionary = plan.doors[d]
		print(" door ", d, " pos=", dr["pos"], " n=", dr["normal"], " w=", dr["width"], " ext=", dr.get("exterior", false))
	for w in plan.windows:
		if int(w.get("room", -1)) == ward: print(" window ", w["pos"])
	for i in plan.furniture_of(ward):
		var f: Dictionary = plan.furniture[i]
		print(" ", f["key"], " ", Rect2(f["rect"]), " row=", f.get("row", ""))
	print(" compromises ", plan.compromises)
	for f in ShopArchetypeSuite._int013_failures(plan, &"hospice"): print("FAIL ", f)
	quit()
