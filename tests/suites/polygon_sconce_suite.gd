extends RefCounted
## Mounted lamps must pair on a real polygon edge, not a face of its AABB.

static func run() -> SuiteResult:
	var result := SuiteResult.new("polygon sconce pairs")
	_synthetic(result)
	for index in [1, 2]:
		var spec := CastleSweep.spec_at(&"crusader", &"castle", index)
		var plan := CastleGenerator.keep_plan(spec)
		var qa := HouseFurnishCheck.new()
		qa._check_sconce_pair(plan)
		_expect(result, qa.failures.is_empty(), "crusader castle%d: %s" % [index, str(qa.failures)])
		var room := plan.rooms_of(&"lords_chamber")[0]
		var lamps := _lamps(plan, room)
		result.note("crusader castle%d: %d lamps from the 1–2 lamp recipe" % [index, lamps.size()])
		if lamps.size() == 2 and HouseFurnishCheck._fs_pair_fits(plan, room):
			var first := _physical_wall(plan, room, plan.furniture[lamps[0]].rect.get_center())
			var second := _physical_wall(plan, room, plan.furniture[lamps[1]].rect.get_center())
			_expect(result, first >= 0 and first == second,
				"crusader castle%d: lamps do not share actual masonry edge (%d,%d)" % [index, first, second])
			_expect(result, qa.warnings.is_empty(), "crusader castle%d: pair fits but remains asymmetrical: %s" % [index, str(qa.warnings)])
	return result


static func _expect(result: SuiteResult, okay: bool, message: String) -> void:
	result.checked += 1
	if not okay:
		result.fail(message)


static func _physical_wall(plan: HousePlan, room: int, position: Vector2) -> int:
	var walls := HouseGeometry.room_walls(plan, room)
	for index in walls.size():
		var a: Vector2 = walls[index].from
		var b: Vector2 = walls[index].to
		var nearest := Geometry2D.get_closest_point_to_segment(position, a, b)
		if nearest.distance_to(position) < 0.02:
			return index
	return -1


static func _lamps(plan: HousePlan, room: int) -> Array[int]:
	var result: Array[int] = []
	for index in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[index].key) == "sconce":
			result.append(index)
	return result


static func _synthetic(result: SuiteResult) -> void:
	var plan := HousePlan.new()
	plan.spec = HouseSpec.new()
	plan.spec.material = &"stone"
	var outline := PackedVector2Array()
	for index in 14:
		var angle := TAU * float(index) / 14.0
		outline.append(Vector2(cos(angle), sin(angle)) * 10.0)
	plan.rooms.append({"kind": &"lords_chamber", "rect": Poly.bounding_rect(outline),
		"outline": outline, "storey": 0})
	var walls := HouseGeometry.room_walls(plan, 0)
	var edge: Dictionary = walls[2]
	var midpoint := (Vector2(edge.from) + Vector2(edge.to)) * 0.5
	var along := (Vector2(edge.to) - Vector2(edge.from)).normalized()
	var key: String = PropCatalog.of_category("sconce")[0]
	for side in [-1.0, 1.0]:
		var point: Vector2 = midpoint + along * side * 1.1
		plan.furniture.append({"room": 0, "key": key, "mounted": true,
			"rect": Rect2(point - Vector2.ONE * 0.05, Vector2.ONE * 0.1),
			"pos": Vector3(point.x, 1.8, point.y), "host": -1, "yaw": 0.0})
	_expect(result, _physical_wall(plan, 0, plan.furniture[0].rect.get_center()) == 2,
		"oblique fixture is not mounted on intended physical wall")
	var valid := HouseFurnishCheck.new()
	valid._check_sconce_pair(plan)
	_expect(result, valid.failures.is_empty() and valid.warnings.is_empty(),
		"symmetrical lamps on an oblique edge were rejected")
	var anchor := {"pos": midpoint, "normal": edge.normal, "dist": 1.1}
	var candidate: Dictionary = plan.furniture[1].duplicate(true)
	candidate.flank_anchor = anchor
	_expect(result, HouseFurnisher._flank_bonus(plan, 0, candidate) > 0,
		"placer gives no pairing score to a real oblique-wall pair")
	var adjacent: Dictionary = walls[3]
	var adjacent_point := (Vector2(adjacent.from) + Vector2(adjacent.to)) * 0.5
	var adjacent_candidate: Dictionary = candidate.duplicate(true)
	adjacent_candidate.rect = Rect2(adjacent_point - Vector2.ONE * 0.05, Vector2.ONE * 0.1)
	_expect(result, HouseFurnisher._flank_bonus(plan, 0, adjacent_candidate) < 0,
		"14-gon adjacent facet was mistaken for the anchor's own wall")
	var other: Dictionary = walls[6]
	var moved := (Vector2(other.from) + Vector2(other.to)) * 0.5
	plan.furniture[1].rect = Rect2(moved - Vector2.ONE * 0.05, Vector2.ONE * 0.1)
	plan.furniture[1].pos = Vector3(moved.x, 1.8, moved.y)
	var broken := HouseFurnishCheck.new()
	broken._check_sconce_pair(plan)
	_expect(result, not broken.failures.is_empty(), "sconce rule accepted lamps moved onto different physical walls")
	var narrow_anchor := {"pos": Vector2(edge.from).lerp(edge.to, 0.02),
		"normal": edge.normal, "reach": 0.0}
	_expect(result, HouseFurnisher._flank_station(plan, 0, narrow_anchor, 0.4, "sconce") == 0.0,
		"pair station extended beyond its host facet into the polygon AABB")
	# Exercise the real placer, independently of the recipe's one-or-two roll.
	plan.furniture.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7407
	HouseFurnisher._place_mounted(plan, 0, key, rng)
	HouseFurnisher._place_mounted(plan, 0, key, rng)
	_expect(result, plan.furniture.size() == 2, "polygon placer failed to hang two lamps on clear masonry")
	if plan.furniture.size() == 2:
		var first := _physical_wall(plan, 0, plan.furniture[0].rect.get_center())
		var second := _physical_wall(plan, 0, plan.furniture[1].rect.get_center())
		_expect(result, first >= 0 and first == second, "polygon placer selected different physical walls")
		var placed := HouseFurnishCheck.new()
		placed._check_sconce_pair(plan)
		_expect(result, placed.failures.is_empty() and placed.warnings.is_empty(), "polygon placer did not mirror its two lamps")
