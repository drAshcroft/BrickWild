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

	# --- controls: each wrong answer is refused
	var walled := _walled_row(wiz_plan)
	_want(result, not CastleWalkAccessCheck.stair_head_failures([walled]).is_empty(),
		"a stair into a wall was accepted")
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
