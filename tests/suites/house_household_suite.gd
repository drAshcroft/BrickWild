extends RefCounted
## The household brief, the fire in the living hall, and period seating
## (HOME-BRIEF, HOME-HEARTH, HouseSpec.period_seating; docs/INTERIOR_DESIGN.md).
##
##   request: period_seating is left out of to_dict() at its default, survives
##     JSON and copy(), an unknown value is refused, and a non-house kind may
##     not set it
##   HOME-HEARTH: a cottage, thatched cottage and farmhouse of 1200 have no
##     kitchen; the fire is in the hall, the hall cooks, and the household eats
##     there at a table laid for it. CONTROL: the same cottage dated 1800 keeps
##     its kitchen and its fire there (the period does it, nothing else); a
##     townhouse of 1200 keeps its shop-house kitchen
##   HOME-BRIEF: the brief is on the plan, the head-count follows the floor,
##     the table is laid for the household (places_laid == places), and the
##     witch hut has no brief (WITCH-SIZE)
##   R-17: no bedroom's only doors lead to sleeping rooms. CONTROL: a hand-made
##     bedroom-behind-a-bedroom plan is given its own door by open_up_privacy
##   period_seating with_table: the sitting parlour has a side table in the
##     `sitting` group with a seat drawn up to it, and the programme check
##     passes. CONTROL: the same table relabelled as dining fails it as a
##     second dining table. without_table: the parlour has no table

const W := 9.0
const L := 12.0


static func run() -> SuiteResult:
	var res := SuiteResult.new("hhousehold")
	_request_contract(res)
	var cottage := _plan(&"cottage", 1, 1200, &"with_table")
	_hearth(res, cottage, "cottage 1200")
	_brief(res, cottage, "cottage 1200")
	_no_bedroom_behind_bedroom(res, cottage, "cottage 1200")
	_side_table(res, cottage, "cottage 1200")
	for style in [&"thatch_cottage", &"farmhouse"]:
		var p := _plan(style, 1, 1200, &"with_table")
		_hearth(res, p, "%s 1200" % style)
		_brief(res, p, "%s 1200" % style)
		_no_bedroom_behind_bedroom(res, p, "%s 1200" % style)
	# CONTROL: the period is what moves the fire
	var late := _plan(&"cottage", 1, 1800, &"with_table")
	res.checked += 1
	if late == null or not late.has_kind(&"kitchen") or late.kind_of(late.hearth_room()) != &"kitchen":
		res.fail("control: a cottage of 1800 lost its kitchen or its kitchen fire")
	var town := _plan(&"townhouse", 1, 1200, &"with_table")
	res.checked += 1
	if town == null or not town.has_kind(&"kitchen"):
		res.fail("control: a townhouse of 1200 lost its shop-house kitchen")
	var witch := _plan(&"witch_hut", 1, 1200, &"with_table")
	res.checked += 1
	if witch == null or witch.domestic_layout.has("household"):
		res.fail("the witch hut was given a household brief (WITCH-SIZE keeps its own)")
	_bedroom_behind_bedroom_control(res)
	var strict := _plan(&"cottage", 1, 1200, &"without_table")
	_without_table(res, strict, "cottage 1200 without_table")
	return res


static func _plan(style: StringName, seed_value: int, period: int, seating: StringName) -> HousePlan:
	var req := BuildingRequest.house(seed_value, style, &"none", W, L, 2.6,
		2 if style == &"townhouse" else 1)
	req.period = period
	req.period_seating = seating
	var b := BrickWild.generate(req)
	return b.plan as HousePlan


static func _request_contract(res: SuiteResult) -> void:
	var req := BuildingRequest.house(1, &"cottage")
	res.checked += 1
	if req.to_dict().has("period_seating"):
		res.fail("request: period_seating is written at its default; old requests would change shape")
	req.period_seating = &"without_table"
	var back := BuildingRequest.from_json(req.to_json())
	res.checked += 1
	if back.period_seating != &"without_table" or req.copy().period_seating != &"without_table":
		res.fail("request: period_seating did not survive JSON or copy()")
	res.checked += 1
	if not BuildingLibrary.validate(req).is_empty():
		res.fail("request: a house with without_table was refused: %s" % [BuildingLibrary.validate(req)])
	var bad := BuildingRequest.house(1, &"cottage")
	bad.period_seating = &"sideways"
	res.checked += 1
	if not _has_code(BuildingLibrary.validate(bad), "unknown_option"):
		res.fail("request: an unknown period_seating was not refused")
	var shop := BuildingRequest.shop(4410, &"general_store", &"townhouse", 11.0, 14.0, 2.8, 1)
	shop.period_seating = &"without_table"
	res.checked += 1
	if not _has_code(BuildingLibrary.validate(shop), "unsupported_option"):
		res.fail("request: a shop was allowed to set period_seating")


static func _has_code(errors: Array, code: String) -> bool:
	for e in errors:
		if String(e.get("code", "")) == code:
			return true
	return false


static func _hearth(res: SuiteResult, p: HousePlan, label: String) -> void:
	res.checked += 1
	if p == null:
		res.fail("%s: no house plan" % label)
		return
	if p.has_kind(&"kitchen"):
		res.fail("%s: a living-hall house still has a separate kitchen" % label)
	var fire := p.hearth_room()
	res.checked += 1
	if fire < 0 or p.kind_of(fire) != &"hall":
		res.fail("%s: the fire is in room %d (%s), not the hall" % [label, fire,
			String(p.kind_of(fire)) if fire >= 0 else "none"])
		return
	res.checked += 1
	if not Array(p.rooms[fire].get("domestic_functions", [])).has(&"cooking"):
		res.fail("%s: the hall with the fire does not cook" % label)
	res.checked += 1
	if int(p.domestic_layout.get("dining_room", -1)) != fire:
		res.fail("%s: the household eats in room %d, not by its fire in room %d"
			% [label, int(p.domestic_layout.get("dining_room", -1)), fire])
	var tables := 0
	var seats := 0
	for f in p.furniture_of(fire):
		var piece: Dictionary = p.furniture[f]
		if String(piece.get("activity_group", "")) != "eating":
			continue
		if String(piece["cat"]) == "table":
			tables += 1
		elif String(piece["cat"]) == "seat":
			seats += 1
	res.checked += 1
	if tables != 1 or seats < 2:
		res.fail("%s: the fire room has %d meal table(s) and %d seat(s) -- the fire has nobody at it"
			% [label, tables, seats])


static func _brief(res: SuiteResult, p: HousePlan, label: String) -> void:
	if p == null:
		return
	var h: Dictionary = HouseHousehold.of(p)
	res.checked += 1
	if h.is_empty():
		res.fail("%s: no household brief on the plan" % label)
		return
	var expect: int = clampi(roundi(float(h.get("floor_m2", 0.0)) / HouseHousehold.M2_PER_HEAD),
		HouseHousehold.MIN_PEOPLE, HouseHousehold.MAX_PEOPLE)
	res.checked += 1
	if int(h.get("people", -1)) != expect:
		res.fail("%s: head-count %d does not follow the floor (%s m2 -> %d)"
			% [label, int(h.get("people", -1)), h.get("floor_m2"), expect])
	res.checked += 1
	if HouseFurnisher._household_seat_capacity(p) < int(h["places"]):
		res.fail("%s: the table asks for %d places for a household of %d"
			% [label, HouseFurnisher._household_seat_capacity(p), int(h["places"])])
	res.checked += 1
	if int(h.get("places_laid", -1)) != int(h["places"]):
		res.fail("%s: %d places laid for a household of %d (%s)" % [label,
			int(h.get("places_laid", -1)), int(h["places"]),
			String(p.domestic_layout.get("dining_selection_reason", ""))])
	res.checked += 1
	if int(h.get("beds_placed", 0)) < 1:
		res.fail("%s: nowhere to sleep" % label)


## No bedroom's every door leads to a sleeping room (design audit R-17).
static func _no_bedroom_behind_bedroom(res: SuiteResult, p: HousePlan, label: String) -> void:
	if p == null:
		return
	var graph: Dictionary = p.door_graph()
	for i in range(p.room_count()):
		if p.kind_of(i) != &"bedroom" or Array(graph.get(i, [])).is_empty():
			continue
		var polite := false
		for j in graph[i]:
			if int(j) >= 0 and not p.kind_of(int(j)) in HouseGeometry.SLEEPING:
				polite = true
		res.checked += 1
		if not polite:
			res.fail("%s: bedroom %d is reached only through another bedroom" % [label, i])


## CONTROL for R-17: hall | bed A | bed B in a row, B reached only through A,
## and B sharing a wall with the hall. open_up_privacy must cut B its own door.
static func _bedroom_behind_bedroom_control(res: SuiteResult) -> void:
	var p := HousePlan.new()
	p.spec = HouseSpec.new(77)
	p.rooms = [
		{"kind": &"hall", "rect": Rect2(0, 0, 8, 4), "storey": 0},
		{"kind": &"bedroom", "rect": Rect2(0, 4, 4, 4), "storey": 0},
		{"kind": &"bedroom", "rect": Rect2(4, 4, 4, 4), "storey": 0},
	]
	p.doors = [
		{"a": 0, "b": -1, "pos": Vector2(1.0, 0.0), "normal": Vector2(0, -1), "width": 0.9,
			"exterior": true, "front": true, "storey": 0},
		{"a": 0, "b": 1, "pos": Vector2(1.0, 4.0), "normal": Vector2(0, 1), "width": 0.8,
			"exterior": false, "storey": 0},
		{"a": 1, "b": 2, "pos": Vector2(4.0, 6.0), "normal": Vector2(1, 0), "width": 0.8,
			"exterior": false, "storey": 0},
	]
	var before := p.reachable_rooms(p.entrance_room(), HouseGeometry.SLEEPING).has(2)
	HousePlanOpenings.open_up_privacy(p)
	var after := p.reachable_rooms(p.entrance_room(), HouseGeometry.SLEEPING).has(2)
	res.checked += 1
	if before:
		res.fail("control: the bedroom-behind-a-bedroom fixture is not stranded; the control is void")
	elif not after:
		res.fail("control: open_up_privacy left bedroom 2 reachable only through bedroom 1")


static func _sitting_parlours(p: HousePlan) -> Array[int]:
	var out: Array[int] = []
	for room in p.rooms_of(&"parlour"):
		if HouseFurnishingRecipes.dines_elsewhere(p, room):
			out.append(room)
	return out


static func _side_table(res: SuiteResult, p: HousePlan, label: String) -> void:
	if p == null:
		return
	var parlours := _sitting_parlours(p)
	res.checked += 1
	if parlours.is_empty():
		res.fail("%s: no sitting parlour to hold a side table; the case is void" % label)
		return
	for room in parlours:
		var table := -1
		for f in p.furniture_of(room):
			if String(p.furniture[f]["cat"]) == "table":
				table = f
		res.checked += 1
		if table < 0:
			if not p.was_dropped(room, "activity:sitting"):
				res.fail("%s: with_table parlour %d has no table and records no shortfall" % [label, room])
			continue
		if String(p.furniture[table].get("activity_group", "")) != "sitting":
			res.fail("%s: parlour %d's table is not the sitting side table" % [label, room])
		var seated := false
		for f in p.furniture_of(room):
			if String(p.furniture[f]["cat"]) in ["seat", "bench"] and int(p.furniture[f].get("host", -1)) == table:
				seated = true
		res.checked += 1
		if not seated:
			res.fail("%s: parlour %d's side table has no seat drawn up to it" % [label, room])
		var rep := HouseFurnishCheck.new().check(p)
		res.checked += 1
		for m in rep["failures"]:
			if "second dining table" in String(m):
				res.fail("%s: the side table was taken for a second dining table: %s" % [label, m])
		# CONTROL: the same table, relabelled as a place to dine, is caught
		var group: String = String(p.furniture[table].get("activity_group", ""))
		p.furniture[table]["activity_group"] = "eating"
		var control := HouseFurnishCheck.new().check(p)
		p.furniture[table]["activity_group"] = group
		var caught := false
		for m in control["failures"]:
			if "second dining table" in String(m):
				caught = true
		res.checked += 1
		if not caught:
			res.fail("control: a dining table in sitting parlour %d escaped the programme check" % room)


static func _without_table(res: SuiteResult, p: HousePlan, label: String) -> void:
	res.checked += 1
	if p == null:
		res.fail("%s: no house plan" % label)
		return
	for room in _sitting_parlours(p):
		for f in p.furniture_of(room):
			if String(p.furniture[f]["cat"]) == "table":
				res.fail("%s: parlour %d has a table; strict history puts it away" % [label, room])
