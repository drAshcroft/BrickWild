extends SceneTree
## A house round a yard: four ranges, a court in the middle, a street door on
## the front and a door from every range onto the yard.


func _init() -> void:
	for across in [16.0, 22.0]:
		var plan: HousePlan = build(across, across * 0.9, 6100 + int(across))
		print("=== courtyard %.0f x %.0f" % [plan.spec.width, plan.spec.length])
		print("  rooms %d  courts %d  doors %d  windows %d  furniture %d"
			% [plan.room_count(), plan.courts.size(), plan.doors.size(),
				plan.windows.size(), plan.furniture.size()])
		print("  plan:    ", HousePlanCheck.new().check(plan)["failures"])
		print("  furnish: ", HouseFurnishCheck.new().check(plan)["failures"])
		print("  nav:     ", HouseNavCheck.new().check(plan)["failures"])
		var court: Dictionary = CourtCheck.new().check(plan)
		print("  court:   ", court["failures"], " stats ", court["stats"])
		var mesh: ArrayMesh = HouseBuilder.new().build(plan)
		print("  mesh verts %d" % (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			as PackedVector3Array).size())
	quit()


## Four ranges round a yard. The ranges are rooms; the yard is a court.
static func build(w: float, l: float, sd: int) -> HousePlan:
	var spec := HouseSpec.new(sd)
	spec.style = &"townhouse"
	spec.width = w
	spec.length = l
	spec.height = 2.8
	spec.storeys = 1
	spec.room_count = 4
	spec.variant_name = "Courtyard House"
	spec.clutter = 0.5
	var plan := HousePlan.new()
	plan.spec = spec
	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	var depth: float = clampf(minf(inner.size.x, inner.size.y) * 0.28, 3.2, 5.0)
	var court := Rect2(inner.position + Vector2(depth, depth),
		inner.size - Vector2(depth, depth) * 2.0)
	plan.courts = [{"rect": court, "storey": 0}]

	# four ranges: front, back, left, right -- the left and right ones stop
	# short so the four rectangles tile the interior with the yard in the hole
	plan.rooms = [
		{"kind": &"hall", "storey": 0,
			"rect": Rect2(inner.position, Vector2(inner.size.x, depth))},
		{"kind": &"parlour", "storey": 0,
			"rect": Rect2(Vector2(inner.position.x, court.end.y),
				Vector2(inner.size.x, inner.end.y - court.end.y))},
		{"kind": &"kitchen", "storey": 0,
			"rect": Rect2(Vector2(inner.position.x, court.position.y),
				Vector2(depth, court.size.y))},
		{"kind": &"store", "storey": 0,
			"rect": Rect2(Vector2(court.end.x, court.position.y),
				Vector2(inner.end.x - court.end.x, court.size.y))},
	]

	# the street door, on the front wall of the front range
	plan.doors = [{"a": 0, "b": -1,
		"pos": Vector2(inner.get_center().x, inner.position.y),
		"normal": Vector2(0, -1), "width": HouseGeometry.DOOR_W,
		"exterior": true, "front": true, "storey": 0}]
	# and one from each range onto the yard
	var onto := [
		[0, Vector2(court.get_center().x, court.position.y), Vector2(0, -1)],
		[1, Vector2(court.get_center().x, court.end.y), Vector2(0, 1)],
		[2, Vector2(court.position.x, court.get_center().y), Vector2(-1, 0)],
		[3, Vector2(court.end.x, court.get_center().y), Vector2(1, 0)],
	]
	for row in onto:
		plan.doors.append({"a": int(row[0]), "b": -1, "pos": row[1],
			"normal": -Vector2(row[2]), "width": HouseGeometry.DOOR_W,
			"exterior": true, "front": false, "storey": 0})
	# windows: two onto the yard from each range, one onto the street
	for row2 in onto:
		var n: Vector2 = -Vector2(row2[2])
		var along := Vector2(n.y, -n.x)
		for t in [-1.0, 1.0]:
			plan.windows.append({"room": int(row2[0]),
				"pos": Vector2(row2[1]) + along * t * 2.0, "normal": n,
				"width": HouseGeometry.WINDOW_W,
				"sill": HouseGeometry.WINDOW_SILL,
				"head": HouseGeometry.WINDOW_SILL + HouseGeometry.WINDOW_H,
				"storey": 0})
	plan.windows.append({"room": 0,
		"pos": Vector2(inner.get_center().x - 3.0, inner.position.y),
		"normal": Vector2(0, -1), "width": HouseGeometry.WINDOW_W,
		"sill": HouseGeometry.WINDOW_SILL,
		"head": HouseGeometry.WINDOW_SILL + HouseGeometry.WINDOW_H, "storey": 0})
	plan.hearth = {"room": 2, "wall": 2}
	HouseFurnisher.furnish(plan, spec)
	return plan
