class_name CastleWalkAccessCheck
extends RefCounted
## CASTLE-WALK-ACCESS. Three things the 26 Oct walk found a person could not do
## in a castle that every lane called green:
##
##   stair_head   a flight lets its walker off onto floor, not into a wall
##                (HouseStairCheck's own rule, run over the castle's occupied
##                rooms: the tower plans placed a flight by wall support alone)
##   tower_exit   a tower entered up on the wall walk, with storeys BELOW that
##                doorway, also has a door onto the ward at its foot; otherwise
##                whoever stands in its lower rooms has no way out
##   placement    `BrickWild.placement(...).door` is the real entrance, on or
##                beside the building, not the origin
##   walkway      no table (or its chairs) across the way from where the flight
##                below lets a walker off to the foot of the next, in a tight
##                tower storey (CASTLE-FURNISH-WALK, WALK-1a17b2b3-4)
##   hall_fire    a castle's great hall has a hearth (WALK-1a17b2f2-1)
##
## Each takes plain rows ({id, plan, mural_tower, ground_entry}) or a door and
## a box, so a fixture can hand it a wrong answer and see it refused.


## The `stair_head` complaints of every row's plan, prefixed with the row.
static func stair_head_failures(rows: Array) -> Array[String]:
	var out: Array[String] = []
	for row in rows:
		var plan: HousePlan = row.plan
		if plan == null or plan.spec == null or plan.stairs.is_empty():
			continue
		for failure in HouseStairCheck.check(plan):
			if String(failure).begins_with("stair_head:"):
				out.append("%s: %s" % [row.id, failure])
	return out


## Floor furniture standing across a tight room's way from the arrival to the
## next flight.
static func walkway_failures(rows: Array) -> Array[String]:
	var out: Array[String] = []
	for row in rows:
		var plan: HousePlan = row.plan
		if plan == null or plan.spec == null or plan.stairs.is_empty():
			continue
		for room in plan.room_count():
			for index in CastleKeepPlan.walkway_blockers(plan, room):
				out.append("%s: %s stands across the way through room %d (%s)"
					% [row.id, String(plan.furniture[index]["key"]), room, String(plan.kind_of(room))])
	return out


## A hall range that is a great hall has a fire on its long wall.
static func hall_fire_failures(rows: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if not rows.has("hall"):
		return out
	var plan: HousePlan = rows["hall"].plan
	if plan != null and plan.spec != null and plan.kind_of(0) == &"great_hall" and plan.hearth.is_empty():
		out.append("hall: a great hall with no hearth")
	return out


## A mural tower with storeys below its entrance and no door at ground level.
static func tower_exit_failures(rows: Array, spec: CastleSpec = null) -> Array[String]:
	var out: Array[String] = []
	# a battered foot buries a ground door: only the raised one is cut there
	if spec != null and spec.batter > preload("res://src/castle/castle_mural_plan.gd").FOOT_DOOR_BATTER_MAX:
		return out
	for row in rows:
		# a gate tower is entered through its own gate passage
		if not bool(row.get("mural_tower", false)) or bool(row.get("ground_entry", false)) \
				or String(row.get("id", "")).contains("_gate_"):
			continue
		var plan: HousePlan = row.plan
		if plan == null or plan.spec == null or plan.entrance() < 0:
			continue
		var entry: Dictionary = plan.doors[plan.entrance()]
		if HousePlan.record_storey(entry) <= 0:
			continue
		var has_foot := false
		for door in plan.doors:
			if bool(door.get("exterior", false)) and HousePlan.record_storey(door) == 0:
				has_foot = true
		if not has_foot:
			out.append("%s: storeys 0..%d lie below its only door and none opens on the ward"
				% [row.id, HousePlan.record_storey(entry) - 1])
	return out


## The published door must be a place: not the origin, and touching the
## building's own bounds.
static func door_failures(door: Vector3, bounds: AABB, who: String) -> Array[String]:
	var out: Array[String] = []
	if door.length() < 0.01:
		out.append("%s: placement door is the origin" % who)
	elif not bounds.grow(1.0).has_point(door):
		out.append("%s: placement door %s lies outside the bounds %s" % [who, door, bounds])
	return out
