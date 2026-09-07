extends SceneTree
func _init() -> void:
	var spec: CastleSpec = CastleSweep.spec_at(&"edwardian", &"castle", 1)
	var box: AABB = CastleGeometry.chapel_aabb(spec)
	var hs := HouseSpec.new(1)
	hs.style = &"longhall"
	hs.width = box.size.x
	hs.length = box.size.z
	hs.height = clampf(box.size.y, 2.6, 6.0)
	hs.storeys = 1
	var plan := HousePlan.new()
	plan.spec = hs
	var f: Rect2 = HouseGeometry.interior_rect(hs)
	plan.rooms = [{"kind": &"nave", "rect": f, "storey": 0}]
	plan.doors = [{"a": 0, "b": -1, "pos": Vector2(f.get_center().x, f.position.y),
		"normal": Vector2(0, -1), "width": HouseGeometry.DOOR_W,
		"exterior": true, "front": true, "storey": 0}]
	var sanct := Rect2(f.position.x, f.end.y - 3.0, f.size.x, 3.0)
	print("floor ", f, "  sanctuary ", sanct)
	print("NO DAIS  nav: ", HouseNavCheck.new().check(plan)["failures"])
	plan.dais = {"room": 0, "rect": sanct, "rise": 0.15}
	print("WITH DAIS nav: ", HouseNavCheck.new().check(plan)["failures"])
	# furnish twice: with the dais, and without
	for use_dais in [true, false]:
		var q := HousePlan.new()
		q.spec = hs
		q.rooms = plan.rooms.duplicate(true)
		q.doors = plan.doors.duplicate(true)
		q.focus = {"room": 0, "cat": "table",
			"pos": Vector2(f.get_center().x, f.end.y - 1.4),
			"facing": 0.0, "faces_door": true}
		if use_dais:
			q.dais = {"room": 0, "rect": sanct, "rise": 0.15}
		HouseFurnisher.furnish(q, hs)
		var names: Array[String] = []
		for piece in q.furniture:
			names.append(String(piece["key"]))
		print("dais=%s  furniture %d %s  compromises %s"
			% [use_dais, q.furniture.size(), str(names.slice(0, 6)),
				str(q.compromises)])
	quit()
