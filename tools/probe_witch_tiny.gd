extends SceneTree
func _init() -> void:
	var spec := HouseSpec.new()
	spec.style = &"witch_hut"
	spec.width = 5.5
	spec.length = 7.0
	spec.height = 2.6
	var plan := HouseGenerator.generate(spec, 8102, true)
	for i in plan.rooms.size():
		print(i, " ", plan.kind_of(i), " floor=", HouseGeometry.room_floor_rect(plan, i), " fn=", plan.rooms[i].get("domestic_functions"), " role=", plan.rooms[i].get("domestic_role"), " shared=", plan.rooms[i].get("shared_witchwork"))
	print(JSON.stringify(plan.domestic_layout.get("added_activities")), " ", plan.domestic_layout.get("status"), plan.domestic_layout.get("reason", ""))
	for k in ["omitted_activities","merged_activities","rejected_candidates","dining_room","dining_selection","dining_group","shared_cooking","hall_role","ground_activities"]:
		print(k, " = ", var_to_str(plan.domestic_layout.get(k)).substr(0, 600))
	for f in plan.furniture:
		print(f.get("key"), " rect=", f.get("rect"), " room=", f.get("room"))
	print(plan.hearth_wall(), " breast=", plan.hearth.get("breast", {}).get("rect"))
	var nc := HouseNavCheck.new()
	nc.check(plan)
	print(nc.ascii_map(0))
	quit(0)
