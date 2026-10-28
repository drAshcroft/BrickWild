extends RefCounted
## CASTLE-WALK-ACCESS: stairs that land on floor, towers with a way out, and a
## placement door that is the entrance. Seeds are the 26 Oct walk's own
## (visualqa/walk_pins.jsonl, WALK-1a17b2b3-3 and -6): Norman seed 1 at the
## default castle site, and the wizard's tower house. Each rule is shown a wrong
## answer too, so a rule that goes quiet is caught.

const NORMAN_SITE := Vector3(55.0, 50.0, 18.0)


static func run() -> SuiteResult:
	var result := SuiteResult.new("castle walk access")
	# --- Norman seed 1, the walled castle of the pins
	var norman := _norman(1)
	var towers: Dictionary = preload("res://src/castle/castle_mural_plan.gd").records(norman)
	var rows := towers.values()
	_want(result, rows.size() >= 4, "norman seed 1 produced %d tower plans" % rows.size())
	_clean(result, CastleWalkAccessCheck.stair_head_failures(rows), "norman 1 tower stairs")
	_clean(result, CastleWalkAccessCheck.tower_exit_failures(rows, norman), "norman 1 tower exits")
	_clean(result, CastleWalkAccessCheck.walkway_failures(rows), "norman 1 tower walkways")
	# --- edwardian seed 1: a 3.5 m hall range was a passage with no fire
	var edwardian := _edwardian_rows(1)
	_want(result, edwardian.has("hall") and edwardian["hall"].plan.kind_of(0) == &"great_hall",
		"edwardian seed 1 has no great hall")
	_clean(result, CastleWalkAccessCheck.hall_fire_failures(edwardian), "edwardian 1 hall")
	_clean(result, CastleWalkAccessCheck.walkway_failures(edwardian.values()
		.filter(func(r): return bool(r.get("mural_tower", false)))), "edwardian 1 tower walkways")
	# --- CASTLE-STAIR-PITCH: as gentle as the room allows, nothing over a tread
	var edwardian_rows := edwardian.values()
	# the bergfried keep of norman seed 1: slender, 3.8 m clear, and once a stair into a wall
	var norman_keep: Dictionary = preload("res://src/castle/castle_interiors.gd").primary(norman)
	_clean(result, CastleWalkAccessCheck.stair_head_failures(norman_keep.values()), "norman 1 keep stairs")
	_clean(result, CastleWalkAccessCheck.headroom_failures(norman_keep.values()), "norman 1 keep headroom")
	_clean(result, CastleWalkAccessCheck.avoidable_pitch_failures(rows), "norman 1 stair pitch")
	_clean(result, CastleWalkAccessCheck.avoidable_pitch_failures(edwardian_rows), "edwardian 1 stair pitch")
	_clean(result, CastleWalkAccessCheck.headroom_failures(rows), "norman 1 stair headroom")
	_clean(result, CastleWalkAccessCheck.headroom_failures(edwardian_rows), "edwardian 1 stair headroom")
	# --- CASTLE-NEWEL-STAIR: no flight at all is a ladder. The 4.7 m mural towers
	# and the slender keep were 56-70 degrees; they take a newel stair now.
	_clean(result, CastleWalkAccessCheck.pitch_failures(rows), "norman 1 tower flights climbable")
	_clean(result, CastleWalkAccessCheck.pitch_failures(norman_keep.values()), "norman 1 keep flights climbable")
	# (edwardian 1's 3.83 m octagons with 4.7 m storeys still hold a straight flight:
	# a 1.9 m well pinches the way shut there; see CASTLE-NEWEL-STAIR in the todo.)
	_want(result, CastleWalkAccessCheck.newel_count(rows) > 0,
		"norman 1 mural towers drew no newel stair")
	_want(result, CastleWalkAccessCheck.newel_count(norman_keep.values()) > 0,
		"the norman 1 keep drew no newel stair")
	# --- the wizard tower house, and a norman one with a jog
	var wiz := BrickWild.generate(BrickWild.default_request(&"castle", 1, &"wizard"))
	var wiz_plan: HousePlan = CastleTowerPlan.generate(wiz.spec as CastleSpec, false)
	_clean(result, CastleWalkAccessCheck.stair_head_failures(
		[{"id": "tower_house", "plan": wiz_plan}]), "wizard tower house stairs")
	_door(result, wiz, "wizard seed 1")
	var norman_house := _tower_house(&"norman", 12.0, 30.0, 1)
	_clean(result, CastleWalkAccessCheck.stair_head_failures(
		[{"id": "tower_house", "plan": CastleTowerPlan.generate(norman_house, false)}]),
		"norman tower house stairs")
	for house in [{"id": "wizard", "plan": CastleTowerPlan.generate(wiz.spec as CastleSpec)},
			{"id": "norman", "plan": CastleTowerPlan.generate(norman_house)}]:
		_clean(result, CastleWalkAccessCheck.headroom_failures([house]),
			"%s tower house headroom" % house.id)

	# --- controls: each wrong answer is refused
	var walled := _walled_row(wiz_plan)
	_want(result, not CastleWalkAccessCheck.stair_head_failures([walled]).is_empty(),
		"a stair into a wall was accepted")
	var ladder := _short_flights(edwardian_rows)
	if ladder.is_empty():
		_want(result, false, "no roomy tower to draw a ladder flight in")
	else:
		_want(result, not CastleWalkAccessCheck.avoidable_pitch_failures([ladder]).is_empty(),
			"a 2.4 m flight up a 3.6 m storey in a roomy tower was accepted")
	var straight := _newel_variant(rows, "straight")
	if straight.is_empty():
		_want(result, false, "no newel tower to draw a straight ladder in")
	else:
		_want(result, not CastleWalkAccessCheck.pitch_failures([straight]).is_empty(),
			"a straight flight in the newel's square well was accepted")
	var flat := _newel_variant(rows, "half_turn")
	if not flat.is_empty():
		_want(result, not CastleWalkAccessCheck.pitch_failures([flat]).is_empty(),
			"a newel turned only half way up a storey was accepted")
	var crossed := _table_across(rows)
	if crossed.is_empty():
		# a newel tower's two landings are one place: the control needs a straight pair
		crossed = _table_across(edwardian_rows)
	if crossed.is_empty():
		crossed = _table_between_landings(rows)
	if crossed.is_empty():
		_want(result, false, "no tower storey to put a table across")
	else:
		_want(result, not CastleWalkAccessCheck.walkway_failures([crossed]).is_empty(),
			"a table across the way between two flights was accepted")
	var cold: Dictionary = edwardian["hall"].plan.hearth.duplicate()
	edwardian["hall"].plan.hearth = {}
	_want(result, not CastleWalkAccessCheck.hall_fire_failures(edwardian).is_empty(),
		"a great hall with no hearth was accepted")
	edwardian["hall"].plan.hearth = cold
	var blind := _blind_row(rows)
	if blind.is_empty():
		_want(result, false, "no raised tower to build the no-exit control from")
	else:
		_want(result, not CastleWalkAccessCheck.tower_exit_failures([blind]).is_empty(),
			"a tower with no way out was accepted")
	var box := AABB(Vector3(-5, 0, -5), Vector3(10, 28, 10))
	_want(result, not CastleWalkAccessCheck.door_failures(Vector3.ZERO, box, "control").is_empty(),
		"a door at the origin was accepted")
	_want(result, not CastleWalkAccessCheck.door_failures(Vector3(50, 3, 50), box, "control").is_empty(),
		"a door far from the building was accepted")
	return result


static func _norman(seed: int) -> CastleSpec:
	return BrickWild.generate(_request(&"norman", seed, NORMAN_SITE)).spec as CastleSpec


static func _edwardian_rows(seed: int) -> Dictionary:
	var spec := BrickWild.generate(_request(&"edwardian", seed, NORMAN_SITE)).spec as CastleSpec
	return preload("res://src/castle/castle_interiors.gd").primary(spec)


## A copy of the first tower storey that has a flight each way, with a trestle
## table laid across the middle of it.
static func _table_across(rows: Array) -> Dictionary:
	for row in rows:
		var plan: HousePlan = row.plan
		for room in plan.room_count():
			var floor := HouseGeometry.room_floor_rect(plan, room)
			var arrives := false
			var leaves := false
			for st in plan.stairs:
				arrives = arrives or int(st.get("b", -1)) == room
				leaves = leaves or int(st.get("a", -1)) == room
			if not (arrives and leaves) or minf(floor.size.x, floor.size.y) > CastleKeepPlan.WALKWAY_ROOM_MAX:
				continue
			var copy := HousePlan.new()
			copy.spec = plan.spec
			copy.rooms = plan.rooms
			copy.doors = plan.doors
			copy.stairs = plan.stairs
			# a table across the line between a flight's landing and the next foot
			var rect := Rect2()
			for st in plan.stairs:
				if int(st.get("b", -1)) != room or not Rect2(st.get("head_landing", Rect2())).has_area():
					continue
				var head := Rect2(st["head_landing"]).get_center()
				for out in plan.stairs:
					if int(out.get("a", -1)) != room or not Rect2(out.get("foot_landing", Rect2())).has_area():
						continue
					var foot := Rect2(out["foot_landing"]).get_center()
					if head.distance_to(foot) >= 2.2:
						var mid := (head + foot) * 0.5
						rect = Rect2(mid - Vector2(0.6, 0.6), Vector2(1.2, 1.2))
			if not rect.has_area():
				continue
			copy.furniture = [{"key": "Table_Large", "rect": rect, "room": room, "storey": room,
				"host": -1, "mounted": false, "cat": "table"}]
			return {"id": "crossed", "plan": copy}
	return {}


## The newel towers have one landing a floor, so the control draws two: a head
## landing and a foot landing 3 m apart in a tower room, a table between them.
static func _table_between_landings(rows: Array) -> Dictionary:
	for row in rows:
		var plan: HousePlan = row.plan
		if plan == null or plan.room_count() < 2:
			continue
		var room := 1
		var floor := HouseGeometry.room_floor_rect(plan, room)
		if minf(floor.size.x, floor.size.y) > CastleKeepPlan.WALKWAY_ROOM_MAX:
			continue
		var c := floor.get_center()
		var copy := HousePlan.new()
		copy.spec = plan.spec
		copy.rooms = plan.rooms
		copy.doors = []
		copy.stairs = [
			{"b": room, "head_landing": Rect2(c + Vector2(-1.8, -0.4), Vector2(0.7, 0.8))},
			{"a": room, "foot_landing": Rect2(c + Vector2(1.1, -0.4), Vector2(0.7, 0.8))}]
		copy.furniture = [{"key": "Table_Large", "rect": Rect2(c - Vector2(0.6, 0.6), Vector2(1.2, 1.2)),
			"room": room, "storey": room, "host": -1, "mounted": false, "cat": "table"}]
		return {"id": "crossed", "plan": copy}
	return {}


## A copy of the first roomy tower plan with every flight cut back to the old
## 2.4 m run: a ladder where the room could have had a stair.
static func _short_flights(rows: Array) -> Dictionary:
	for row in rows:
		if not bool(row.get("mural_tower", false)):
			continue
		var plan: HousePlan = row.plan
		var roomy := plan.stairs.size() > 0 and plan.stairs.any(func(st: Dictionary) -> bool:
			var floor := HouseGeometry.room_floor_rect(plan, int(st["b"]))
			return maxf(floor.size.x, floor.size.y) - 0.3 - CastleKeepPlan.LANDING_ALLOWANCE >= plan.spec.height / tan(deg_to_rad(CastleKeepPlan.PITCH_TARGET)))
		if not roomy:
			continue
		var copy := HousePlan.new()
		copy.spec = plan.spec
		copy.rooms = plan.rooms
		copy.doors = plan.doors
		copy.stairs = []
		for st in plan.stairs:
			var cut: Dictionary = st.duplicate(true)
			var r := Rect2(st["rect"])
			var along_x := r.size.x > r.size.y
			var short := Rect2(r.position, Vector2(2.4, r.size.y) if along_x else Vector2(r.size.x, 2.4))
			for key in ["rect", "lower_rect", "upper_rect"]:
				cut[key] = short
			cut.erase("steps")
			copy.stairs.append(cut)
		return {"id": "ladder", "plan": copy}
	return {}


## A copy of the first newel tower with its flights drawn the wrong way: as
## straight flights in the same wells ("straight"), or as newels turned only a
## half circle ("half_turn"), both too steep for a person to climb.
static func _newel_variant(rows: Array, how: String) -> Dictionary:
	for row in rows:
		var plan: HousePlan = row.plan
		if plan == null or plan.stairs.is_empty() or not HouseNewel.is_newel(plan.stairs[0]):
			continue
		var copy := HousePlan.new()
		copy.spec = plan.spec
		copy.rooms = plan.rooms
		copy.doors = plan.doors
		copy.stairs = []
		for st in plan.stairs:
			var cut: Dictionary = st.duplicate(true)
			if how == "straight":
				for key in ["kind", "centre", "radius", "hub", "sweep", "spin", "steps"]:
					cut.erase(key)
				cut["run"] = float(cut["rect"].size.x)
			else:
				cut["sweep"] = 180.0
			copy.stairs.append(cut)
		return {"id": how, "plan": copy}
	return {}


static func _request(style: StringName, seed: int, site: Vector3) -> BuildingRequest:
	var req := BuildingRequest.castle(seed, style)
	req.width = site.x
	req.length = site.y
	req.height = site.z
	return req


static func _tower_house(style: StringName, width: float, height: float, seed: int) -> CastleSpec:
	var spec := CastleSpec.new()
	spec.style = style
	spec.width = width
	spec.length = width
	spec.height = height
	spec.plan_override = &"tower_house"
	CastleGenerator.generate(spec, seed)
	return spec


static func _door(result: SuiteResult, building, who: String) -> void:
	var placement := BrickWild.placement(building)
	_clean(result, CastleWalkAccessCheck.door_failures(placement["door"],
		placement["bounds"], who), who + " placement door")


## The tower house's first flight pushed hard against the room's far edge, with
## its landing record dropped: its top step meets the wall.
static func _walled_row(plan: HousePlan) -> Dictionary:
	var copy := HousePlan.new()
	copy.spec = plan.spec
	copy.rooms = plan.rooms
	copy.doors = plan.doors
	var stair: Dictionary = plan.stairs[0].duplicate(true)
	var floor := HouseGeometry.room_floor_rect(plan, int(stair.b))
	var r := Rect2(stair.rect)
	var along_x := r.size.x > r.size.y
	var moved := Rect2(Vector2(floor.end.x - r.size.x if along_x else r.position.x,
		floor.end.y - r.size.y if not along_x else r.position.y), r.size)
	for key in ["rect", "lower_rect", "upper_rect"]:
		stair[key] = moved
	stair["climb"] = 1.0
	stair.erase("head_landing")
	stair.erase("foot_landing")
	copy.stairs = [stair]
	return {"id": "walled", "plan": copy}


## A copy of a raised tower's plan without its door at the foot.
static func _blind_row(rows: Array) -> Dictionary:
	for row in rows:
		if not bool(row.get("mural_tower", false)) or bool(row.get("ground_entry", false)):
			continue
		var plan: HousePlan = row.plan
		if HousePlan.record_storey(plan.doors[plan.entrance()]) <= 0:
			continue
		var copy := HousePlan.new()
		copy.spec = plan.spec
		copy.rooms = plan.rooms
		copy.doors = [plan.doors[plan.entrance()]]
		copy.stairs = plan.stairs
		return {"id": String(row.id), "plan": copy, "mural_tower": true}
	return {}


static func _want(result: SuiteResult, ok: bool, why: String) -> void:
	result.checked += 1
	if not ok:
		result.fail(why)


static func _clean(result: SuiteResult, failures: Array[String], who: String) -> void:
	result.checked += 1
	for failure in failures:
		result.fail("%s: %s" % [who, failure])
