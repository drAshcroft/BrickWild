class_name ShopArchetypeSuite
extends RefCounted
## Occupational landmarks: each business must read through rooms and fixtures,
## then pass the same physical, daylight, furnishing, and walking rules as a house.

const REQUIRED := {
	&"blacksmith": ["workshop", "anvil", "workbench"],
	&"stable": ["stable", "stall"],
	&"restaurant": ["dining_room", "table", "seat"],
	&"tavern": ["dining_room", "table", "barrel", "counter"],
	&"inn": ["dining_room", "table", "bed"],
	&"bakery": ["sales_floor", "counter", "hearth"],
	&"butcher": ["sales_floor", "counter", "blade"],
	&"apothecary": ["sales_floor", "counter", "alchemy"],
	&"general_store": ["sales_floor", "counter", "crate"],
	&"tailor": ["sales_floor", "counter", "sack", "rack", "shelf", "workbench"],
	&"carpenter": ["workshop", "workbench", "rack", "bench"],
	&"town_hall": ["council_chamber", "table", "seat"],
	&"guildhall": ["meeting_hall", "table", "bench"],
}


static func run() -> SuiteResult:
	var res := SuiteResult.new("shop archetypes")
	for business in REQUIRED:
		var spec := ShopSpec.new()
		spec.business = business
		spec.style = &"longhall" if business in [&"blacksmith", &"stable", &"carpenter"] else &"townhouse"
		spec.width = 14.0
		spec.length = 18.0
		spec.height = 2.9
		var plan := ShopGenerator.generate(spec, 33000 + absi(String(business).hash()) % 900)
		var builder := HouseBuilder.new()
		builder.build(plan)
		res.checked += 1
		var wants: Array = REQUIRED[business]
		if not plan.has_kind(StringName(wants[0])):
			res.fail("%s has no defining %s room" % [String(business), wants[0]])
		for cat in wants.slice(1):
			if not _has_category(plan, String(cat)):
				res.fail("%s has no defining %s fitting" % [String(business), cat])
		var report: Dictionary = HouseQA.new().check(plan, builder)
		for failure in report["failures"]:
			res.fail("%s: %s" % [String(business), failure])
		for warning in report["warnings"]:
			res.warn("%s: %s" % [String(business), warning])
		for failure2 in shopfront_rules(spec, plan, builder):
			res.fail("%s: %s" % [String(business), failure2])
	_check_lodging(res)
	return res


## LAY-012: nobody walks through a guest room to reach a bed.
##
## Two halves, and the fixture is the point of the first. Proving that inns
## come out right today proves nothing unless the rule can be seen to fire --
## a check that never fails is a check that is not looking -- so the first
## half takes a real inn, CHAINS its guest rooms by hand, and asserts the
## privacy rule catches it and `_open_up_lodging` puts it right. The second
## half then holds every inn the generator makes to the invariant.
static func _check_lodging(res: SuiteResult) -> void:
	var chained: HousePlan = _chained_inn(res)
	if chained != null:
		res.checked += 1
		if not _privacy_failures(chained):
			res.fail("lodging: a plan whose only way to the far bed is through "
				+ "the near one passed the privacy rule")
		ShopPlanner._open_up_lodging(chained)
		res.checked += 1
		# The invariant the landing pass owns, and only that. Renaming two
		# ordinary rooms to guest rooms can leave a THIRD room behind one of
		# them, which is `HousePlanOpenings.open_up_privacy`'s job and not this
		# pass's; holding the pass to the whole privacy rule would be holding
		# it to somebody else's work.
		for i in range(chained.room_count()):
			if chained.kind_of(i) in HouseGeometry.SLEEPING \
					and not ShopPlanner._has_public_door(chained, i):
				res.fail("lodging: room %d (%s) still opens only onto other beds "
					% [i, String(chained.kind_of(i))]
					+ "after the landing pass")

	for size in [[11.0, 14.0], [14.0, 18.0], [18.0, 24.0]]:
		for storeys in [1, 2]:
			for s in range(6):
				var spec := ShopSpec.new()
				spec.business = &"inn"
				spec.style = &"townhouse"
				spec.width = size[0]
				spec.length = size[1]
				spec.height = 2.9
				spec.storeys = storeys
				var plan: HousePlan = ShopGenerator.generate(spec, 41000 + s * 37)
				var where := "inn %.0fx%.0f st%d seed %d" % [size[0], size[1], storeys, 41000 + s * 37]
				res.checked += 1
				for f in _privacy_failures(plan):
					res.fail("lodging: %s: %s" % [where, f])
				for i in range(plan.room_count()):
					if plan.kind_of(i) in HouseGeometry.SLEEPING \
							and not ShopPlanner._has_public_door(plan, i):
						res.fail("lodging: %s: room %d (%s) opens only onto other beds"
							% [where, i, String(plan.kind_of(i))])


## An inn whose guest rooms are in a chain, BUILT BY HAND: two adjoining
## rooms are named `guest_room`, and every door into the second is taken away
## except the one from the first.
##
## Constructed rather than searched for. The generator does not chain guest
## rooms any more -- that is the point of LAY-012 -- so a fixture that waits
## for one would never fire, and a check that never fails is a check that is
## not looking. The two rooms are real rooms of a real plan, so what is
## tested is the rule and the remedy, not a hand-drawn rectangle.
static func _chained_inn(res: SuiteResult) -> HousePlan:
	var spec := ShopSpec.new()
	spec.business = &"inn"
	spec.style = &"townhouse"
	spec.width = 16.0
	spec.length = 20.0
	spec.height = 2.9
	var plan: HousePlan = ShopGenerator.generate(spec, 41777)
	# two rooms that adjoin, are not the way in, and could hold a bed
	var entrance: int = plan.entrance_room()
	var pair: Array[int] = []
	for i in range(plan.room_count()):
		if i == entrance or not HouseGeometry.room_suits(plan, i, &"guest_room"):
			continue
		for j in range(i + 1, plan.room_count()):
			if j == entrance or not HouseGeometry.room_suits(plan, j, &"guest_room"):
				continue
			if not HousePlanOpenings.shared_edge(plan, i, j).is_empty():
				pair = [i, j]
				break
		if not pair.is_empty():
			break
	res.checked += 1
	if pair.is_empty():
		res.fail("lodging: the fixture inn has no two adjoining rooms that could "
			+ "be guest rooms; the privacy rule cannot be shown to fire")
		return null
	var near: int = pair[0]
	var far: int = pair[1]
	plan.rooms[near]["kind"] = &"guest_room"
	plan.rooms[far]["kind"] = &"guest_room"
	# the far bed keeps exactly one door, and it is the near bed's
	var kept: Array[Dictionary] = []
	for door in plan.doors:
		if int(door["a"]) != far and int(door["b"]) != far:
			kept.append(door)
	kept.append({"a": near, "b": far, "pos": plan.rooms[far]["rect"].get_center(),
		"normal": Vector2(1, 0), "width": HouseGeometry.INNER_DOOR_W,
		"exterior": false, "front": false, "storey": plan.storey_of_room(far)})
	plan.doors = kept
	return plan


static func _privacy_failures(plan: HousePlan) -> Array[String]:
	var out: Array[String] = []
	for f in HousePlanCheck.new().check(plan)["failures"]:
		if String(f).begins_with("privacy"):
			out.append(String(f))
	return out


## What a trade's front has to be (LAY-009), measured from the plan: the
## street door is in the front room and as wide as the trade needs; a stable
## has a door a horse fits through; a smithy opens to the street and its
## forge stands on the chimney wall under a real chimney; a shop with a
## shopfront has its hatch in the street wall; a tavern keeps its casks
## behind the bar.
static func shopfront_rules(spec: ShopSpec, plan: HousePlan, builder: HouseBuilder) -> Array[String]:
	var out: Array[String] = []
	var front: int = plan.entrance_room()
	var door: int = plan.entrance()
	if door < 0 or front < 0:
		return ["front: no street door"]
	var street_front: bool = spec.door_w() >= 1.2 or not spec.front_open().is_empty()
	if street_front and plan.kind_of(front) != spec.front_room():
		out.append("front: the street door opens into the %s, not the %s"
			% [String(plan.kind_of(front)), String(spec.front_room())])
	var w: float = float(plan.doors[door]["width"])
	if w < spec.door_w() - 0.01:
		out.append("door: the street door is %.2fm wide, the trade needs %.2fm" % [w, spec.door_w()])
	if spec.business == &"stable" and w < 1.2:
		out.append("door: a horse does not fit through a %.2fm door" % w)
	if spec.business == &"blacksmith":
		if w < 2.4:
			out.append("door: the forge opens to the street through %.2fm" % w)
		if plan.hearth_room() != front:
			out.append("forge: the chimney is in room %d, the forge room is %d" % [plan.hearth_room(), front])
		var stack := 0
		for m in builder.mass_log:
			if String(m["name"]).begins_with("chimney"):
				stack += 1
		if stack != 1:
			out.append("forge: %d chimneys" % stack)
	if not spec.front_open().is_empty():
		var hatch := false
		for win in plan.windows:
			if win.get("hatch", false) and int(win["room"]) == front:
				hatch = true
		if not hatch:
			out.append("shopfront: no hatch in the street wall of the %s" % String(spec.front_room()))
	if spec.business == &"tavern":
		var bar := Vector2(INF, INF)
		for p in plan.furniture:
			if int(p["room"]) == front and PropCatalog.category(p["key"]) == "counter":
				bar = Rect2(p["rect"]).get_center()
		if not bar.is_finite():
			out.append("bar: the tavern has no counter in its front room")
		else:
			var near := INF
			for p2 in plan.furniture:
				if int(p2["room"]) == front and PropCatalog.category(p2["key"]) == "barrel":
					near = minf(near, Rect2(p2["rect"]).get_center().distance_to(bar))
			if near > 3.5:
				out.append("bar: the nearest cask is %.2fm from the bar" % near)
	return out


static func _has_category(plan: HousePlan, category: String) -> bool:
	for placement in plan.furniture:
		if PropCatalog.category(placement["key"]) == category:
			return true
	return false
