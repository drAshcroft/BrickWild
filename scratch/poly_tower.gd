extends SceneTree
## A round tower: one octagonal room to a storey, three storeys. The demo
## GEO-002 asks for, and the first plan in this project a rectangle cannot say.


func _init() -> void:
	var plan: HousePlan = _tower(9.0, 3, 5150)
	print("rooms %d  storeys %d" % [plan.room_count(), plan.spec.storeys])
	for i in range(plan.room_count()):
		var poly: PackedVector2Array = plan.outline_of(i)
		print("  room %d %-12s storey %d  %d sides  area %.1f m2  walls %d"
			% [i, String(plan.kind_of(i)), plan.storey_of_room(i), poly.size(),
				Poly.area(poly), HouseGeometry.room_walls(plan, i).size()])
	print("  doors %d  windows %d  stairs %d  furniture %d"
		% [plan.doors.size(), plan.windows.size(), plan.stairs.size(),
			plan.furniture.size()])
	var outside := 0
	for f in plan.furniture:
		if f.get("mounted", false) or int(f["host"]) >= 0:
			continue
		var poly: PackedVector2Array = plan.outline_of(int(f["room"]))
		var r: Rect2 = f["rect"]
		for c in [r.position, Vector2(r.end.x, r.position.y), r.end,
				Vector2(r.position.x, r.end.y)]:
			if not Poly.contains_point(poly, c, 0.02):
				outside += 1
				break
	print("  furniture outside the outline: %d" % outside)
	print("  plan:    ", HousePlanCheck.new().check(plan)["failures"])
	print("  furnish: ", HouseFurnishCheck.new().check(plan)["failures"])
	print("  nav:     ", HouseNavCheck.new().check(plan)["failures"])
	var mesh: ArrayMesh = HouseBuilder.new().build(plan)
	print("  mesh surfaces %d verts %d" % [mesh.get_surface_count(),
		(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()])
	quit()


## One octagon to a storey, inscribed in the spec's own square.
static func _tower(across: float, storeys: int, sd: int) -> HousePlan:
	var spec := HouseSpec.new(sd)
	spec.style = &"townhouse"
	spec.width = across
	spec.length = across
	spec.height = 2.8
	spec.storeys = storeys
	spec.room_count = storeys
	spec.program = [] as Array[StringName]
	spec.variant_name = "Round Tower"
	spec.clutter = 0.5
	var plan := HousePlan.new()
	plan.spec = spec
	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	var poly: PackedVector2Array = _octagon(inner)
	var kinds: Array[StringName] = [&"hall", &"bedroom", &"bedroom"]
	for level in range(storeys):
		plan.rooms.append({"kind": kinds[level % kinds.size()],
			"rect": Poly.bounding_rect(poly), "outline": poly, "storey": level})
	# the way in, on the edge nearest the front
	var walls: Array[Dictionary] = HouseGeometry.polygon_walls(poly)
	var front := 0
	for k in range(walls.size()):
		if walls[k]["normal"].y > walls[front]["normal"].y:
			front = k
	var w: Dictionary = walls[front]
	plan.doors = [{"a": 0, "b": -1,
		"pos": (Vector2(w["from"]) + Vector2(w["to"])) / 2.0,
		"normal": -Vector2(w["normal"]), "width": HouseGeometry.DOOR_W,
		"exterior": true, "front": true, "storey": 0}]
	for level2 in range(storeys):
		for k2 in range(walls.size()):
			if level2 == 0 and k2 == front:
				continue
			if k2 % 2 != 0:
				continue
			var wall: Dictionary = walls[k2]
			plan.windows.append({"room": level2,
				"pos": (Vector2(wall["from"]) + Vector2(wall["to"])) / 2.0,
				"normal": -Vector2(wall["normal"]),
				"width": HouseGeometry.WINDOW_W,
				"sill": HouseGeometry.WINDOW_SILL,
				"head": HouseGeometry.WINDOW_SILL + HouseGeometry.WINDOW_H,
				"storey": level2})
	for level3 in range(storeys - 1):
		HousePlanLevels.add_stair(plan, level3, level3 + 1, level3, level3 + 1)
	HouseFurnisher.furnish(plan, spec)
	return plan


static func _octagon(inner: Rect2) -> PackedVector2Array:
	var c: Vector2 = inner.get_center()
	var rx: float = inner.size.x / 2.0
	var rz: float = inner.size.y / 2.0
	var out := PackedVector2Array()
	for k in range(8):
		var a: float = TAU * (float(k) + 0.5) / 8.0
		out.append(c + Vector2(cos(a) * rx / cos(PI / 8.0),
			sin(a) * rz / cos(PI / 8.0)))
	return out
