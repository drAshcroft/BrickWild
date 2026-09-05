class_name HouseQASuite
extends RefCounted
## 12. The house harness over the whole sweep: is the plan a plan, does the
##     furnishing make sense, and can a person walk through the result.
##
## Every check reads the plan the mesh was built from, so a pass here means the
## house you would walk into is the house that was measured.

static func run() -> SuiteResult:
	var res := SuiteResult.new("house QA")
	for style in HouseSweep.styles():
		var defects := 0
		var variants := 0
		for trade in HouseSweep.trades():
			for i in range(HouseSweep.COUNT):
				var made: Array = HouseSweep.at(style, trade, i)
				var spec: HouseSpec = made[0]
				var plan: HousePlan = made[1]
				var builder := HouseBuilder.new()
				builder.build(plan)
				var rep: Dictionary = HouseQA.new().check(plan, builder)
				res.checked += 1
				variants += 1
				var who := "%s %s seed=%d" % [String(style), String(trade), spec.seed]
				if not rep["ok"]:
					defects += 1
					for f in rep["failures"]:
						res.fail("%s: %s" % [who, str(f)])
				for w in rep["warnings"]:
					res.warn("%s: %s" % [who, str(w)])
		res.note("%-11s %2d/%d houses with defects" % [String(style), defects, variants])
	_hearth_fixture(res)
	_hearth_sweep(res)
	_row_fixture(res)
	_upstairs_programme_fixture(res)
	_stair_fixture(res)
	_stair_sweep(res)
	_doors_in_line_fixture(res)
	_poles_sweep(res)
	_rule_override_fixture(res)
	_affinity_sweep(res)
	_affinity_variety(res)
	_affinity_fixture(res)
	_feng_shui_fixtures(res)
	_feng_shui_sweep(res)
	return res


## The upstairs_programme rule, shown to fire. A two-storey house is planned
## properly -- the plan check must not complain about its upper floor -- and
## then one room upstairs is renamed the kitchen by hand. A rule that does not
## notice a second kitchen over the first one is measuring nothing.
static func _upstairs_programme_fixture(res: SuiteResult) -> void:
	var spec := HouseSpec.new()
	spec.style = &"townhouse"
	spec.width = 11.0
	spec.length = 13.0
	spec.height = 2.7
	spec.storeys = 2
	var plan: HousePlan = HouseGenerator.generate(spec, 5119)
	res.checked += 1
	for f in HousePlanCheck.new().check(plan)["failures"]:
		if str(f).begins_with("upstairs_programme:"):
			res.fail("upstairs fixture: a planned two-storey house was reported: %s" % str(f))

	var upstairs: Array[int] = plan.rooms_on_storey(1)
	if upstairs.is_empty():
		res.fail("upstairs fixture: the planner gave a two-storey house no upper rooms")
		return
	var room: int = upstairs[0]
	plan.rooms[room]["kind"] = &"kitchen"
	res.checked += 1
	var want := "upstairs_programme: room %d is a kitchen on storey 1 -- that belongs on the ground floor" % room
	if not want in HousePlanCheck.new().check(plan)["failures"]:
		res.fail("upstairs fixture: a kitchen on the first floor was not reported (%s)" % want)

	# and the hearth may not follow it up the stair
	plan.rooms[room]["kind"] = &"bedroom"
	plan.hearth = {"room": room, "wall": 0}
	res.checked += 1
	var caught := false
	for f in HousePlanCheck.new().check(plan)["failures"]:
		if str(f).begins_with("upstairs_programme: the hearth"):
			caught = true
	if not caught:
		res.fail("upstairs fixture: a hearth on the first floor was not reported")


## The hearth rule, shown to fire. A house is planned properly, its furniture
## thrown away and one hearth stood against a wall the chimney is NOT on: if
## the rule does not complain about that, it is not measuring anything.
## Rule replacement, shown to work (INT-020): the furnishing check with its
## daylight rule replaced by a no_windows rule fails a plan that has a window
## and passes one that has none, reports the replacement by name, and refuses
## a rule switched off with nothing in its place.
static func _rule_override_fixture(res: SuiteResult) -> void:
	var no_windows := {"name": "no_windows", "call": func(p: HousePlan) -> Array:
		var out: Array = []
		for w in range(p.windows.size()):
			out.append("room %d has a window" % int(p.windows[w]["room"]))
		return out}
	var lit := _fs_plan(&"hall", 75001)
	res.checked += 1
	var rep: Dictionary = HouseFurnishCheck.new().check(lit, {"daylight": no_windows})
	if not "daylight -> no_windows: room 0 has a window" in rep["failures"]:
		res.fail("override fixture: the replaced daylight rule did not fail a lit room: %s" % str(rep["failures"]))
	if String(rep.get("replaced", {}).get("daylight", "")) != "no_windows":
		res.fail("override fixture: the report does not say daylight was replaced")
	var dark := _fs_plan(&"hall", 75002)
	dark.windows = []
	res.checked += 1
	var rep2: Dictionary = HouseFurnishCheck.new().check(dark, {"daylight": no_windows})
	for f in rep2["failures"]:
		if String(f).begins_with("daylight"):
			res.fail("override fixture: the replaced daylight rule failed a dark room: %s" % String(f))
	res.checked += 1
	var rep3: Dictionary = HouseFurnishCheck.new().check(lit, {"daylight": null})
	if not "rules: daylight was switched off with no replacement" in rep3["failures"]:
		res.fail("override fixture: switching a rule off was not refused")
	res.checked += 1
	var qa: Dictionary = HouseQA.new().check(lit, null, {"no_such_rule": no_windows})
	if not "rules: no house rule is called no_such_rule" in qa["failures"]:
		res.fail("override fixture: an override for a rule nobody has was not refused")


## The doors_in_line rule, shown to fire (LAY-006): one room, a front door
## and a back door cut into opposite walls at the same x.
static func _doors_in_line_fixture(res: SuiteResult) -> void:
	var plan := _fs_plan(&"hall", 73001)
	var inner: Rect2 = HouseGeometry.interior_rect(plan.spec)
	plan.doors.append({"a": 0, "b": -1, "pos": Vector2(inner.get_center().x + 0.3, inner.position.y),
		"normal": Vector2(0, -1), "width": 0.9, "exterior": true, "front": false,
		"storey": 0})
	res.checked += 1
	var rep: Dictionary = HousePlanCheck.new().check(plan)
	var want := "doors_in_line: doors 0 and 1 face each other across the house, 0.60m of them in line"
	if not want in rep["failures"]:
		res.fail("doors in line fixture: wanted\n    %s\n  got: %s" % [want, str(rep["failures"])])


## Two hundred one-storey houses with a back door, every style: the back door
## is on the kitchen four times in five and never on a bedroom or a parlour,
## the kitchen touches the back wall four times in five, and no house has its
## two doors in line (LAY-006).
static func _poles_sweep(res: SuiteResult) -> void:
	var styles: Array = HouseSweep.styles()
	var trades: Array = HouseSweep.trades()
	var houses := 0
	var on_kitchen := 0
	var on_store := 0
	var on_other := 0
	var kitchens := 0
	var kitchens_back := 0
	var in_line := 0
	for n in range(200):
		var spec := HouseSpec.new()
		spec.style = styles[n % styles.size()]
		spec.trade = trades[n % trades.size()]
		spec.width = 8.0 + float(n % 5) * 1.5
		spec.length = 9.0 + float(n % 7) * 1.5
		spec.storeys = 1
		HouseGenerator.generate(spec, 74000 + n)
		if spec.room_count < 3:
			continue
		spec.back_door = true
		var plan: HousePlan = HousePlanner.plan(spec)
		res.checked += 1
		houses += 1
		var back := -1
		for d in range(plan.doors.size()):
			if plan.doors[d]["exterior"] and not plan.doors[d].get("front", false):
				back = d
		if back >= 0:
			var kind: StringName = plan.kind_of(int(plan.doors[back]["a"]))
			if kind == &"kitchen":
				on_kitchen += 1
			elif kind == &"store":
				on_store += 1
			else:
				on_other += 1
				res.fail("poles sweep: seed=%d the back door opens out of the %s" % [spec.seed, String(kind)])
		var inner: Rect2 = HouseGeometry.interior_rect(spec)
		for i in plan.rooms_of(&"kitchen"):
			kitchens += 1
			if absf(Rect2(plan.rooms[i]["rect"]).end.y - inner.end.y) < 0.01:
				kitchens_back += 1
		var rep: Dictionary = HousePlanCheck.new().check(plan)
		for m in rep["failures"]:
			if String(m).begins_with("doors_in_line:"):
				in_line += 1
				res.fail("poles sweep: seed=%d %s" % [spec.seed, String(m)])
	res.note("poles       %d houses: back door on kitchen %d, store %d, other %d; kitchen on back wall %d/%d"
		% [houses, on_kitchen, on_store, on_other, kitchens_back, kitchens])
	if houses > 0 and float(on_kitchen) / float(houses) < 0.8:
		res.fail("poles sweep: the back door is on the kitchen in only %d of %d houses" % [on_kitchen, houses])
	if kitchens > 0 and float(kitchens_back) / float(kitchens) < 0.8:
		res.fail("poles sweep: the kitchen touches the back wall in only %d of %d houses" % [kitchens_back, kitchens])


## The stair_line rule, shown to fire (LAY-005): a two-storey house is planned
## properly, then its stair is dragged back to the middle of the hall, in the
## line of the front door, where it used to stand.
static func _stair_fixture(res: SuiteResult) -> void:
	var spec := HouseSpec.new()
	spec.style = HouseSweep.styles()[0]
	spec.width = 8.0
	spec.length = 9.0
	spec.storeys = 2
	var plan: HousePlan = HouseGenerator.generate(spec, 71001)
	res.checked += 1
	if plan.stairs.is_empty():
		res.fail("stair fixture: a two-storey house was planned with no stair")
		return
	var stair: Dictionary = plan.stairs[0]
	var room: int = int(stair["a"])
	var front: int = plan.entrance()
	var in_hall: bool = front >= 0 and int(plan.doors[front]["a"]) == room
	if not in_hall:
		res.warn("stair fixture: the stair rises from room %d and the front door opens into another; the door-line half of the fixture cannot run" % room)
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var size: Vector2 = Rect2(stair["rect"]).size
	var centred := Rect2(f.get_center() - size / 2.0, size)
	if in_hall:
		var line: Rect2 = HousePlanner.door_line(plan, room, plan.doors[front])
		centred.position.x = clampf(line.get_center().x - size.x / 2.0,
			f.position.x, f.end.x - size.x)
	for key in ["rect", "lower_rect", "upper_rect"]:
		stair[key] = centred
	stair["pos"] = centred.get_center()
	stair["lower_pos"] = centred.get_center()
	stair["upper_pos"] = centred.get_center()
	var rep: Dictionary = HousePlanCheck.new().check(plan)
	var saw_wall := false
	var saw_line := false
	for m in rep["failures"]:
		if String(m).begins_with("stair_line:") and "off every wall" in String(m):
			saw_wall = true
		if String(m).begins_with("stair_line:") and "line of the front door" in String(m):
			saw_line = true
	if not saw_wall:
		res.fail("stair fixture: a stair in the middle of the hall was not reported off the walls")
	if in_hall and not saw_line:
		res.fail("stair fixture: a stair in the line of the front door was not reported")


## Two hundred two-storey houses: the stair touches a wall and keeps out of the
## front door's line in every one, and the hall still has its table in almost
## every one -- the stair against the wall is what leaves the middle free.
static func _stair_sweep(res: SuiteResult) -> void:
	var styles: Array = HouseSweep.styles()
	var trades: Array = HouseSweep.trades()
	var on_wall := 0
	var off_line := 0
	var halls := 0
	var tables := 0
	var n_stairs := 0
	for n in range(200):
		var spec := HouseSpec.new()
		spec.style = styles[n % styles.size()]
		spec.trade = trades[n % trades.size()]
		spec.width = 6.0 + float(n % 5) * 2.0
		spec.length = 7.0 + float(n % 7) * 1.8
		spec.storeys = 2
		var plan: HousePlan = HouseGenerator.generate(spec, 72000 + n)
		res.checked += 1
		var rep: Dictionary = HousePlanCheck.new().check(plan)
		for si in range(plan.stairs.size()):
			n_stairs += 1
			var wall_ok := true
			var line_ok := true
			for m in rep["failures"]:
				if not String(m).begins_with("stair_line: ") or not ("stair %d " % si) in String(m):
					continue
				if "off every wall" in String(m):
					wall_ok = false
				if "line of the front door" in String(m):
					line_ok = false
			if wall_ok:
				on_wall += 1
			if line_ok:
				off_line += 1
		for i in plan.rooms_of(&"hall"):
			if plan.storey_of_room(i) != 0:
				continue
			halls += 1
			for fi in plan.furniture_of(i):
				if PropCatalog.category(plan.furniture[fi]["key"]) == "table":
					tables += 1
					break
	res.note("stair       %d/%d against a wall, %d/%d out of the door line, %d/%d halls with a table"
		% [on_wall, n_stairs, off_line, n_stairs, tables, halls])
	if on_wall < n_stairs:
		res.fail("stair sweep: %d of %d stairs stand off every wall" % [n_stairs - on_wall, n_stairs])
	if off_line < n_stairs:
		res.fail("stair sweep: %d of %d stairs stand in the line of the front door" % [n_stairs - off_line, n_stairs])
	if halls > 0 and float(tables) / float(halls) < 0.95:
		res.fail("stair sweep: only %d of %d two-storey halls have a table" % [tables, halls])


static func _hearth_fixture(res: SuiteResult) -> void:
	var spec := HouseSpec.new()
	spec.width = 11.0
	spec.length = 14.0
	spec.height = 2.7
	var plan: HousePlan = HouseGenerator.generate(spec, 4711)
	res.checked += 1
	if plan.hearth.is_empty():
		res.fail("hearth fixture: the planner gave a %d-room house no hearth"
			% plan.room_count())
		return
	var room: int = plan.hearth_room()
	var wrong: int = (plan.hearth_wall() + 1) % 4
	plan.furniture.clear()
	plan.furniture.append(_hearth_on(plan, room, wrong))
	var rep: Dictionary = HouseFurnishCheck.new().check(plan)
	var msg := "hearth: the hearth in room %d stands on wall %d but the chimney is on wall %d"
	var want: String = msg % [room, wrong, plan.hearth_wall()]
	if not want in rep["failures"]:
		res.fail("hearth fixture: a hearth on the wrong wall was not reported (%s)" % want)

	# and the same house with the hearth where the planner put it must pass
	plan.furniture.clear()
	plan.furniture.append(_hearth_on(plan, room, plan.hearth_wall()))
	res.checked += 1
	for f in HouseFurnishCheck.new().check(plan)["failures"]:
		if str(f).begins_with("hearth:"):
			res.fail("hearth fixture: a hearth on the chimney wall was reported: %s" % str(f))


## A hearth placement stood against wall `wi` of `room`, by hand: backed onto
## it and facing into the room, the way the furnisher would have left it.
static func _hearth_on(plan: HousePlan, room: int, wi: int) -> Dictionary:
	var key: String = PropCatalog.of_category("hearth")[0]
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var yaw: float = [PI, 0.0, -PI / 2.0, PI / 2.0][wi]
	var foot: Vector2 = PropCatalog.footprint_yawed(key, yaw)
	var c: Vector2 = f.get_center()
	match wi:
		0: c.y = f.position.y + foot.y / 2.0 + HouseGeometry.WALL_GAP
		1: c.y = f.end.y - foot.y / 2.0 - HouseGeometry.WALL_GAP
		2: c.x = f.position.x + foot.x / 2.0 + HouseGeometry.WALL_GAP
		_: c.x = f.end.x - foot.x / 2.0 - HouseGeometry.WALL_GAP
	return {
		"key": key, "room": room, "storey": plan.storey_of_room(room),
		"pos": Vector3(c.x, 0.0, c.y), "yaw": yaw,
		"rect": Rect2(c - foot / 2.0, foot), "zone": Rect2(), "host": -1,
		"cat": "hearth", "mounted": false, "scale": 1.0, "must": true,
	}


## Two hundred generated houses, every style, one and two storeys: no hearth
## complaint anywhere, and exactly one chimney in the mass log however many
## floors the house has.
static func _hearth_sweep(res: SuiteResult) -> void:
	var styles: Array = HouseSweep.styles()
	var bad := 0
	var stacks := 0
	for n in range(200):
		var spec := HouseSpec.new()
		spec.style = styles[n % styles.size()]
		spec.width = 6.0 + float(n % 5) * 2.0
		spec.length = 7.0 + float(n % 7) * 1.8
		spec.storeys = 1 + (n % 2)
		var plan: HousePlan = HouseGenerator.generate(spec, 30000 + n)
		res.checked += 1
		var rep: Dictionary = HouseFurnishCheck.new().check(plan)
		for f in rep["failures"]:
			if str(f).begins_with("hearth:"):
				bad += 1
				res.fail("hearth sweep: seed=%d %s: %s" % [spec.seed, String(spec.style), str(f)])
		if not spec.chimney:
			continue
		var builder := HouseBuilder.new()
		builder.build(plan)
		var stack := 0
		for m in builder.mass_log:
			if String(m.get("name", "")) == "chimney":
				stack += 1
		stacks += 1
		if stack != 1:
			res.fail("hearth sweep: seed=%d has %d chimneys over %d storeys"
				% [spec.seed, stack, spec.storeys])
	res.note("hearth      200 houses, %d complaints, %d with a single stack" % [bad, stacks])


## The row rule, shown to fire. Three tables stood by hand, straight, evenly
## pitched, sharing one aisle: the check must pass that clean. Then one of
## them pushed 0.3m off the line the other two define: the check must not.
static func _row_fixture(res: SuiteResult) -> void:
	var choices: Array[String] = PropCatalog.of_category("table")
	if choices.is_empty():
		res.warn("row fixture: no table prop in the catalogue to build it from")
		return
	var key: String = choices[0]
	var spec := HouseSpec.new(1)
	spec.width = 8.0
	spec.length = 10.0
	spec.height = 2.6
	var plan := HousePlan.new()
	plan.spec = spec
	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	plan.rooms = [{"kind": &"dining_room", "rect": inner, "storey": 0}]

	var foot: Vector2 = PropCatalog.footprint_yawed(key, 0.0)
	var zone := Rect2(Vector2(-1.0, 1.0), Vector2(2.0, 1.0))
	var base_z: float = inner.position.y + foot.y / 2.0 + HouseGeometry.WALL_GAP
	var pitch: float = foot.x + 0.3
	var cat: String = PropCatalog.category(key)

	res.checked += 1
	plan.furniture = _row_of(key, foot, cat, base_z, pitch, zone)
	var good: Dictionary = HouseFurnishCheck.new().check(plan)
	for m in good["failures"]:
		if String(m).begins_with("row:"):
			res.fail("row fixture: a straight, evenly pitched row was flagged: %s" % str(m))

	plan.furniture = _row_of(key, foot, cat, base_z, pitch, zone)
	var pushed: Rect2 = plan.furniture[1]["rect"]
	pushed.position.y += 0.3
	plan.furniture[1]["rect"] = pushed
	var bad: Dictionary = HouseFurnishCheck.new().check(plan)
	var caught := false
	for m in bad["failures"]:
		if String(m).begins_with("row:"):
			caught = true
	if not caught:
		res.fail("row fixture: a row with one piece pushed 0.3m out was not caught")


static func _row_of(key: String, foot: Vector2, cat: String, base_z: float,
		pitch: float, zone: Rect2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for x in [-pitch, 0.0, pitch]:
		out.append({
			"key": key, "room": 0, "storey": 0,
			"pos": Vector3(x, 0.0, base_z), "yaw": 0.0,
			"rect": Rect2(Vector2(x - foot.x / 2.0, base_z - foot.y / 2.0), foot),
			"zone": zone, "host": -1, "cat": cat, "mounted": false, "scale": 1.0,
			"row": "fixture",
		})
	return out


# --------------------------------------------------------- affinity (LAY-002)

## How many of these houses does each affinity actually decide?
##
## LAY-002 replaced "does it fit, plus a random number" with a scorer, and the
## only honest way to show a scorer works is to count. Every rate below is
## re-derived from the finished plan -- which wall a piece has its back to,
## which corner it stands in, how far a pair of lamps sit either side of the
## door -- so a placer that stopped consulting the affinity block in
## PropCatalog would show up here as a rate falling, not as a test that had
## quietly stopped measuring anything.
##
## The thresholds are the ones LAY-002 was accepted against. They are not 100%
## on purpose: a room can be too small, a wall too short or an opening too near
## a corner for the arrangement a rule asks for, and a generator that forced
## one anyway would be lying about the room.
const AFFINITY_WANT := {
	"corner_clutter": 0.90, "sconce_pair": 0.90, "chandelier_over": 0.98,
	"workbench_daylight": 0.98, "bed_window": 0.98, "table_focus": 0.75,
	"shelf_over": 0.70, "table_face": 0.90,
}


static func _affinity_sweep(res: SuiteResult) -> void:
	var styles: Array = HouseSweep.styles()
	var trades: Array = HouseSweep.trades()
	var tally := {}
	for n in range(200):
		var spec := HouseSpec.new()
		spec.style = styles[n % styles.size()]
		spec.trade = trades[n % trades.size()]
		spec.width = 6.0 + float(n % 5) * 2.0
		spec.length = 7.0 + float(n % 7) * 1.8
		spec.storeys = 1 + (n % 2)
		var plan: HousePlan = HouseGenerator.generate(spec, 50000 + n)
		res.checked += 1
		_affinity_measure(plan, tally)
	for rule in AFFINITY_WANT:
		var v: Array = tally.get(rule, [0, 0])
		if int(v[1]) == 0:
			res.warn("affinity: no house in the sweep exercised %s" % rule)
			continue
		var rate: float = float(v[0]) / float(v[1])
		res.note("affinity    %-18s %3d/%-4d %5.1f%% (want %.0f%%)"
			% [rule, int(v[0]), int(v[1]), rate * 100.0,
			float(AFFINITY_WANT[rule]) * 100.0])
		if rate < float(AFFINITY_WANT[rule]):
			res.fail("affinity: %s holds in only %.1f%% of %d cases, wanted %.0f%%"
				% [rule, rate * 100.0, int(v[1]), float(AFFINITY_WANT[rule]) * 100.0])


static func _aff_hit(tally: Dictionary, rule: String, ok: bool) -> void:
	if not tally.has(rule):
		tally[rule] = [0, 0]
	tally[rule][1] += 1
	if ok:
		tally[rule][0] += 1


static func _aff_wall_normal(wi: int) -> Vector2:
	return [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)][wi]


## Which wall a rectangle has its back to, or -1 when it stands free. Derived
## from the finished plan, the way a check has to derive it.
static func _aff_back_wall(plan: HousePlan, room: int, rect: Rect2) -> int:
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var gaps := [rect.position.y - f.position.y, f.end.y - rect.end.y,
		rect.position.x - f.position.x, f.end.x - rect.end.x]
	var best := -1
	var best_gap := 0.14
	for i in range(4):
		if float(gaps[i]) < best_gap:
			best_gap = float(gaps[i])
			best = i
	return best


static func _aff_wall_lit(plan: HousePlan, room: int, wi: int) -> bool:
	for w in plan.windows_of(room):
		if Vector2(plan.windows[w]["normal"]).dot(_aff_wall_normal(wi)) < -0.9:
			return true
	return false


static func _aff_nearest_corner(corners: Array, c: Vector2) -> int:
	var best := 0
	var best_d := INF
	for i in range(4):
		var d: float = c.distance_to(Vector2(corners[i]))
		if d < best_d:
			best_d = d
			best = i
	return best


static func _affinity_measure(plan: HousePlan, tally: Dictionary) -> void:
	for room in range(plan.room_count()):
		var f: Rect2 = HouseGeometry.room_floor_rect(plan, room)
		var corners := [f.position, Vector2(f.end.x, f.position.y),
			Vector2(f.position.x, f.end.y), f.end]
		_aff_corners(plan, room, corners, tally)
		_aff_sconces(plan, room, tally)
		_aff_chandelier(plan, room, tally)
		_aff_walls(plan, room, tally)
		_aff_table(plan, room, f, tally)


## The clutter goes where nobody walks: the corner furthest from every door of
## the room holds one of the barrels, crates or sacks the room was given.
static func _aff_corners(plan: HousePlan, room: int, corners: Array,
		tally: Dictionary) -> void:
	if plan.doors_of(room).is_empty():
		return
	var clutter: Array[int] = []
	for i in plan.furniture_of(room):
		if PropCatalog.has_tag(plan.furniture[i]["key"], PropCatalog.CORNER):
			clutter.append(i)
	if clutter.is_empty():
		return
	var want := 0
	var want_d := -1.0
	for ci in range(4):
		var m := INF
		for d in plan.doors_of(room):
			m = minf(m, Vector2(corners[ci]).distance_to(Vector2(plan.doors[d]["pos"])))
		if m > want_d:
			want_d = m
			want = ci
	var there := false
	for i2 in clutter:
		if _aff_nearest_corner(corners, Rect2(plan.furniture[i2]["rect"]).get_center()) == want:
			there = true
	_aff_hit(tally, "corner_clutter", there)


## Two lamps in a room are a pair: one wall, and the same distance either side
## of the door, the fire, or -- when neither has wall to spare on both sides --
## the middle of the wall they share.
static func _aff_sconces(plan: HousePlan, room: int, tally: Dictionary) -> void:
	var sc: Array[int] = []
	for i in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[i]["key"]) == "sconce":
			sc.append(i)
	if sc.size() != 2:
		return
	var w1: int = _aff_back_wall(plan, room, plan.furniture[sc[0]]["rect"])
	var w2: int = _aff_back_wall(plan, room, plan.furniture[sc[1]]["rect"])
	if w1 < 0 or w1 != w2:
		_aff_hit(tally, "sconce_pair", false)
		return
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var n: Vector2 = _aff_wall_normal(w1)
	var along := Vector2(n.y, -n.x)
	var anchors: Array[Vector2] = [(f.position + f.end) / 2.0]
	for i2 in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[i2]["key"]) == "hearth":
			anchors.append(Rect2(plan.furniture[i2]["rect"]).get_center())
	for d in plan.doors_of(room):
		anchors.append(plan.doors[d]["pos"])
	var t1: float = Rect2(plan.furniture[sc[0]]["rect"]).get_center().dot(along)
	var t2: float = Rect2(plan.furniture[sc[1]]["rect"]).get_center().dot(along)
	var mirrored := false
	for a in anchors:
		if absf(t1 + t2 - 2.0 * a.dot(along)) <= 0.15:
			mirrored = true
	_aff_hit(tally, "sconce_pair", mirrored)


## The chandelier hangs over the table, not over the middle of a room that has
## a table standing somewhere else in it.
static func _aff_chandelier(plan: HousePlan, room: int, tally: Dictionary) -> void:
	var tables: Array[int] = []
	for i in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[i]
		if PropCatalog.category(p["key"]) == "table" and not p.get("mounted", false):
			tables.append(i)
	if tables.is_empty():
		return
	for i2 in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[i2]["key"]) != "chandelier":
			continue
		var c := Vector2(plan.furniture[i2]["pos"].x, plan.furniture[i2]["pos"].z)
		var near := INF
		for t in tables:
			near = minf(near, c.distance_to(Rect2(plan.furniture[t]["rect"]).get_center()))
		_aff_hit(tally, "chandelier_over", near <= 0.3)


## Which wall each piece chose: the bench takes the one with the window in it,
## the bed takes any wall but that one, the bookcase keeps off the chimney
## wall, and the shelf takes the stretch over the bench or counter it serves.
static func _aff_walls(plan: HousePlan, room: int, tally: Dictionary) -> void:
	var lit: bool = not plan.windows_of(room).is_empty()
	var best_shelf := -1.0
	for i in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[i]
		var cat: String = PropCatalog.category(p["key"])
		var wi: int = _aff_back_wall(plan, room, p["rect"])
		if wi < 0:
			continue
		if cat == "workbench" and lit:
			_aff_hit(tally, "workbench_daylight", _aff_wall_lit(plan, room, wi))
		if cat == "bed" and lit:
			_aff_hit(tally, "bed_window", not _aff_wall_lit(plan, room, wi))
		if cat == "bookcase" and plan.hearth_room() == room and plan.hearth_wall() >= 0:
			_aff_hit(tally, "bookcase_heat", wi != plan.hearth_wall())
		if cat != "shelf":
			continue
		for h in plan.furniture_of(room):
			if not PropCatalog.category(plan.furniture[h]["key"]) in ["workbench", "counter"]:
				continue
			var host: Rect2 = plan.furniture[h]["rect"]
			var hw: int = _aff_back_wall(plan, room, host)
			if hw < 0:
				continue
			best_shelf = maxf(best_shelf, 0.0)
			if hw != wi:
				continue
			var axis := Vector2(_aff_wall_normal(hw).y, -_aff_wall_normal(hw).x).abs()
			var width: float = maxf(PropCatalog.size(p["key"]).x, 0.05)
			var span: float = maxf(host.end.dot(axis) - host.position.dot(axis), 0.05)
			var c: float = Rect2(p["rect"]).get_center().dot(axis)
			var over: float = minf(c + width / 2.0, host.end.dot(axis)) \
				- maxf(c - width / 2.0, host.position.dot(axis))
			best_shelf = maxf(best_shelf, over / minf(width, span))
	# per room rather than per shelf: a room given two shelves hangs the second
	# one somewhere else, because two shelves in the same place is one shelf
	if best_shelf >= 0.0:
		_aff_hit(tally, "shelf_over", best_shelf >= 0.5)


## A table in the room with the fire in it draws up toward the fire: its
## centre is off the middle of the room, toward the hearth wall, by getting on
## for a sixth of the room's depth.
static func _aff_table(plan: HousePlan, room: int, f: Rect2, tally: Dictionary) -> void:
	if plan.hearth_room() != room or plan.hearth_wall() < 0:
		return
	var focus := Vector2(INF, INF)
	for i in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[i]["key"]) == "hearth":
			focus = Rect2(plan.furniture[i]["rect"]).get_center()
	if not focus.is_finite():
		var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, room)
		focus = (Vector2(walls[plan.hearth_wall()]["from"])
			+ Vector2(walls[plan.hearth_wall()]["to"])) / 2.0
	var mid: Vector2 = f.get_center()
	var dir: Vector2 = focus - mid
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var half: float = absf(dir.x) * f.size.x / 2.0 + absf(dir.y) * f.size.y / 2.0
	for i2 in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[i2]
		if PropCatalog.category(p["key"]) != "table" or p.get("mounted", false):
			continue
		if String(p.get("row", "")) != "":
			continue
		_aff_hit(tally, "table_focus",
			(Rect2(p["rect"]).get_center() - mid).dot(dir) >= 0.30 * half)
		# and it lies broadside to the focus: long axis at right angles to
		# the line the fire looks along, within 20 degrees (INT-002)
		var size: Vector2 = Rect2(p["rect"]).size
		if plan.focus_room() == room and absf(size.x - size.y) >= 0.1:
			var axis := Vector2(1, 0) if size.x > size.y else Vector2(0, 1)
			var yaw: float = plan.focus_facing()
			var look := Vector2(-sin(yaw), -cos(yaw))
			_aff_hit(tally, "table_face", absf(axis.dot(look)) <= sin(deg_to_rad(20.0)))


## Two different seeds must still furnish a room differently. The whole point
## of LAY-002 is that the dice no longer decide; the point of this is that they
## have not stopped being rolled.
static func _affinity_variety(res: SuiteResult) -> void:
	var styles: Array = HouseSweep.styles()
	var rooms := 0
	var moved := 0
	# forty pairs is a couple of thousand pieces of furniture; the house
	# suites are the slow ones and this question does not need more
	for n in range(40):
		var a := HouseSpec.new()
		a.style = styles[n % styles.size()]
		a.width = 7.0 + float(n % 4) * 1.5
		a.length = 8.0 + float(n % 5) * 1.5
		var b := HouseSpec.new()
		b.style = a.style
		b.width = a.width
		b.length = a.length
		var pa: HousePlan = HouseGenerator.generate(a, 70000 + n)
		var pb: HousePlan = HouseGenerator.generate(b, 90000 + n)
		res.checked += 1
		for room in range(mini(pa.room_count(), pb.room_count())):
			if pa.kind_of(room) != pb.kind_of(room):
				continue
			rooms += 1
			if _aff_layout(pa, room) != _aff_layout(pb, room):
				moved += 1
	var rate: float = float(moved) / maxf(float(rooms), 1.0)
	res.note("affinity    %-18s %3d/%-4d %5.1f%% (want 95%%)"
		% ["seeds differ", moved, rooms, rate * 100.0])
	if rate < 0.95:
		res.fail("affinity: two seeds furnish the same room identically in %.1f%% of %d rooms"
			% [(1.0 - rate) * 100.0, rooms])


static func _aff_layout(plan: HousePlan, room: int) -> String:
	var out := ""
	for i in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[i]
		out += "%s@%.2f,%.2f;" % [p["key"], p["pos"].x, p["pos"].z]
	return out


## The bookcase rule, shown to decide something. No generated house puts a
## bookcase in the room the chimney serves, so the one place the rule can be
## seen working is a room built to make it choose: a records room whose fire is
## on a named wall, tried with the fire on each wall in turn.
static func _affinity_fixture(res: SuiteResult) -> void:
	for wall in range(4):
		var spec := HouseSpec.new(9001 + wall)
		spec.width = 9.0
		spec.length = 9.0
		spec.height = 2.7
		var plan := HousePlan.new()
		plan.spec = spec
		var inner: Rect2 = HouseGeometry.interior_rect(spec)
		plan.rooms = [{"kind": &"records", "rect": inner, "storey": 0}]
		plan.doors = [{"a": 0, "b": -1, "pos": Vector2(inner.get_center().x, inner.end.y),
			"normal": Vector2(0, 1), "width": 0.9, "exterior": true, "front": true,
			"storey": 0}]
		plan.hearth = {"room": 0, "wall": wall}
		HouseFurnisher.furnish(plan, spec)
		res.checked += 1
		var seen := false
		for i in plan.furniture_of(0):
			if PropCatalog.category(plan.furniture[i]["key"]) != "bookcase":
				continue
			seen = true
			var wi: int = _aff_back_wall(plan, 0, plan.furniture[i]["rect"])
			if wi == wall:
				res.fail("affinity fixture: the bookcase stands on wall %d, which is the chimney wall"
					% wi)
		if not seen:
			res.warn("affinity fixture: no bookcase was placed with the fire on wall %d" % wall)


# ------------------------------------------------- feng shui (LAY-003)

## Every affinity in PropCatalog now has a rule in HouseFurnishCheck, and a
## rule nobody has ever seen fail is a rule that measures nothing. So each one
## gets a room built by hand to break exactly it, and the exact sentence the
## rule would say is the thing asserted -- not a prefix, not a count.
##
## The rooms are deliberately generous (11 x 11 m, one door, one window), so
## that none of the tolerances the rules carry for cramped rooms can be what
## made the message appear.
static func _feng_shui_fixtures(res: SuiteResult) -> void:
	_fs_workbench_daylight(res)
	_fs_bookcase_heat(res)
	_fs_bed_window(res)
	_fs_table_focus(res)
	_fs_sconce_pair(res)
	_fs_shelf_over(res)
	_fs_chandelier_over(res)
	_fs_corner_clutter(res)
	_fs_focus_pos(res)
	_fs_focus_door(res)


## One room, one front door in the far wall (wall 1) and one window in the near
## wall (wall 0), indexed the way HouseGeometry.room_walls() indexes them.
static func _fs_plan(kind: StringName, seed: int) -> HousePlan:
	var spec := HouseSpec.new(seed)
	spec.width = 11.0
	spec.length = 11.0
	spec.height = 2.7
	var plan := HousePlan.new()
	plan.spec = spec
	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	plan.rooms = [{"kind": kind, "rect": inner, "storey": 0}]
	plan.doors = [{"a": 0, "b": -1, "pos": Vector2(inner.get_center().x, inner.end.y),
		"normal": Vector2(0, 1), "width": 0.9, "exterior": true, "front": true,
		"storey": 0}]
	plan.windows = [{"room": 0, "pos": Vector2(inner.get_center().x, inner.position.y),
		"normal": Vector2(0, -1), "width": HouseGeometry.WINDOW_W,
		"sill": HouseGeometry.WINDOW_SILL,
		"head": HouseGeometry.WINDOW_SILL + HouseGeometry.WINDOW_H, "storey": 0}]
	return plan


## A placement made by hand, at the centre asked for.
static func _fs_piece(key: String, c: Vector2, yaw := 0.0, y := 0.0) -> Dictionary:
	var foot: Vector2 = PropCatalog.footprint_yawed(key, yaw)
	var mounted: bool = PropCatalog.has_tag(key, PropCatalog.WALL_MOUNTED) \
		or PropCatalog.has_tag(key, PropCatalog.CEILING)
	return {
		"key": key, "room": 0, "storey": 0,
		"pos": Vector3(c.x, y, c.y), "yaw": yaw,
		"rect": Rect2(c - foot / 2.0, foot), "zone": Rect2(), "host": -1,
		"cat": PropCatalog.category(key), "mounted": mounted, "scale": 1.0,
		"must": true,
	}


## The centre a piece would have if it were pushed back against wall `wi`.
static func _fs_against(plan: HousePlan, key: String, wi: int, along: float,
		yaw := 0.0) -> Vector2:
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, 0)
	var foot: Vector2 = PropCatalog.footprint_yawed(key, yaw)
	var c: Vector2 = f.get_center()
	match wi:
		0:
			c = Vector2(f.get_center().x + along, f.position.y + foot.y / 2.0)
		1:
			c = Vector2(f.get_center().x + along, f.end.y - foot.y / 2.0)
		2:
			c = Vector2(f.position.x + foot.x / 2.0, f.get_center().y + along)
		_:
			c = Vector2(f.end.x - foot.x / 2.0, f.get_center().y + along)
	return c


static func _fs_expect(res: SuiteResult, plan: HousePlan, want: String) -> void:
	res.checked += 1
	var rep: Dictionary = HouseFurnishCheck.new().check(plan)
	if want in rep["failures"]:
		return
	var same := []
	var prefix: String = want.split(":")[0] + ":"
	for f in rep["failures"]:
		if String(f).begins_with(prefix):
			same.append(String(f))
	for w in rep["warnings"]:
		if String(w).begins_with(prefix):
			same.append("(warning) " + String(w))
	res.fail("feng shui fixture: wanted the failure\n    %s\n  got instead: %s"
		% [want, "nothing at all" if same.is_empty() else str(same)])


## A bench with its back to a blind wall, on the far side of the room from the
## only window in it.
static func _fs_workbench_daylight(res: SuiteResult) -> void:
	var key: String = PropCatalog.of_category("workbench")[0]
	var plan := _fs_plan(&"workshop", 8101)
	var c: Vector2 = _fs_against(plan, key, 1, -3.0)
	plan.furniture = [_fs_piece(key, c)]
	var near: float = c.distance_to(Vector2(plan.windows[0]["pos"]))
	_fs_expect(res, plan,
		"workbench_daylight: %s in room 0 (workshop) works %.2fm from the nearest window, with its back to a blind wall"
		% [key, near])


## Books against the chimney breast.
static func _fs_bookcase_heat(res: SuiteResult) -> void:
	var key: String = PropCatalog.of_category("bookcase")[0]
	var plan := _fs_plan(&"records", 8102)
	plan.hearth = {"room": 0, "wall": 0}
	plan.furniture = [_fs_piece(key, _fs_against(plan, key, 0, -2.0))]
	_fs_expect(res, plan,
		"bookcase_heat: %s in room 0 (records) stands against wall 0, which is the chimney wall"
		% key)


## A bed with its head under the window.
static func _fs_bed_window(res: SuiteResult) -> void:
	var key: String = PropCatalog.of_category("bed")[0]
	var plan := _fs_plan(&"bedroom", 8103)
	plan.furniture = [_fs_piece(key, _fs_against(plan, key, 0, 0.0))]
	_fs_expect(res, plan,
		"bed_window: the head of %s in room 0 (bedroom) is under the window in wall 0" % key)


## A table retreating from the fire: the chimney is in wall 0 and the table
## stands two metres past the middle of the room on the other side of it.
static func _fs_table_focus(res: SuiteResult) -> void:
	var key: String = PropCatalog.of_category("table")[0]
	var plan := _fs_plan(&"hall", 8104)
	plan.hearth = {"room": 0, "wall": 0}
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, 0)
	plan.furniture = [_fs_piece(key, f.get_center() + Vector2(0.0, 2.0))]
	_fs_expect(res, plan,
		"table_focus: %s in room 0 (hall) stands 2.00m on the far side of the room from the fire" % key)


## Two lamps on two different walls, and not mirrored about anything.
static func _fs_sconce_pair(res: SuiteResult) -> void:
	var key: String = PropCatalog.of_category("sconce")[0]
	var plan := _fs_plan(&"hall", 8105)
	plan.furniture = [
		_fs_piece(key, _fs_against(plan, key, 0, -3.0), 0.0, 1.8),
		_fs_piece(key, _fs_against(plan, key, 2, 1.5), PI / 2.0, 1.8),
	]
	_fs_expect(res, plan, "sconce_pair: the two lamps in room 0 (hall) are on walls 0 and 2")


## A shelf hung on the opposite wall from the bench it is supposed to serve.
static func _fs_shelf_over(res: SuiteResult) -> void:
	var bench: String = PropCatalog.of_category("workbench")[0]
	var shelf: String = PropCatalog.of_category("shelf")[0]
	var plan := _fs_plan(&"workshop", 8106)
	# wall 2, not the window wall: the rule forgives a bench whose wall has
	# glass or fittings over it, and this fixture is about neither
	var bc: Vector2 = _fs_against(plan, bench, 2, 0.0)
	var sc: Vector2 = _fs_against(plan, shelf, 3, 0.0)
	plan.furniture = [_fs_piece(bench, bc), _fs_piece(shelf, sc, 0.0, 1.6)]
	var host: Rect2 = plan.furniture[0]["rect"]
	var near: float = sc.distance_to(Vector2(clampf(sc.x, host.position.x, host.end.x),
		clampf(sc.y, host.position.y, host.end.y)))
	_fs_expect(res, plan,
		"shelf_over: no shelf in room 0 (workshop) hangs over the bench it serves (0%% cover, %.2fm away)"
		% near)


## A chandelier hanging over the middle of a room whose table is elsewhere.
static func _fs_chandelier_over(res: SuiteResult) -> void:
	var table: String = PropCatalog.of_category("table")[0]
	var lamp: String = PropCatalog.of_category("chandelier")[0]
	var plan := _fs_plan(&"dining_room", 8107)
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, 0)
	var tc: Vector2 = f.get_center() + Vector2(2.0, 0.0)
	plan.furniture = [_fs_piece(table, tc), _fs_piece(lamp, f.get_center(), 0.0, 2.4)]
	_fs_expect(res, plan,
		"chandelier_over: %s in room 0 (dining_room) hangs 2.00m from the nearest table" % lamp)


## A barrel dropped in the doorway of a room with three corners to spare.
static func _fs_corner_clutter(res: SuiteResult) -> void:
	var key: String = PropCatalog.of_category("barrel")[0]
	var plan := _fs_plan(&"kitchen", 8108)
	var door: Vector2 = plan.doors[0]["pos"]
	var c := Vector2(door.x, door.y - 0.5)
	plan.furniture = [_fs_piece(key, c)]
	_fs_expect(res, plan,
		"corner_clutter: %s in room 0 (kitchen) stands 0.50m from a door, in the traffic" % key)


## The fire two metres from where the plan said the room was arranged around.
static func _fs_focus_pos(res: SuiteResult) -> void:
	var key: String = PropCatalog.of_category("hearth")[0]
	var plan := _fs_plan(&"hall", 8109)
	plan.hearth = {"room": 0, "wall": 0}
	var at: Vector2 = _fs_against(plan, key, 0, 0.0)
	plan.focus = {"room": 0, "cat": "hearth", "pos": at, "facing": 0.0,
		"faces_door": false}
	plan.furniture = [_fs_piece(key, _fs_against(plan, key, 0, 2.0))]
	_fs_expect(res, plan,
		"focus: %s in room 0 (hall) stands 2.00m from the focus the plan recorded" % key)


## A counter with its back to the door it is supposed to serve: the plan says
## the counter must face the entrance, and this one stands against the door's
## own wall looking into the room.
static func _fs_focus_door(res: SuiteResult) -> void:
	var key: String = PropCatalog.of_category("counter")[0]
	var plan := _fs_plan(&"sales_floor", 8110)
	var at: Vector2 = _fs_against(plan, key, 1, 3.0)
	plan.focus = {"room": 0, "cat": "counter", "pos": at, "facing": 0.0,
		"faces_door": true}
	plan.furniture = [_fs_piece(key, at)]
	_fs_expect(res, plan, "focus: the counter in room 0 faces away from the door")


## The whole feng shui section over 200 generated houses, every style, one and
## two storeys: no rule may fail on a house the generator meant to build. The
## warnings the tolerances produce are the rooms too small or too odd to obey
## a rule, and are counted rather than hidden.
const FENG_SHUI_RULES := ["workbench_daylight", "bookcase_heat", "bed_window",
	"table_focus", "sconce_pair", "shelf_over", "chandelier_over",
	"corner_clutter", "command", "hearth", "focus"]

static func _feng_shui_sweep(res: SuiteResult) -> void:
	var styles: Array = HouseSweep.styles()
	var trades: Array = HouseSweep.trades()
	var warned := {}
	var bad := 0
	for n in range(200):
		var spec := HouseSpec.new()
		spec.style = styles[n % styles.size()]
		spec.trade = trades[n % trades.size()]
		spec.width = 6.0 + float(n % 5) * 2.0
		spec.length = 7.0 + float(n % 7) * 1.8
		spec.storeys = 1 + (n % 2)
		var plan: HousePlan = HouseGenerator.generate(spec, 60000 + n)
		res.checked += 1
		var rep: Dictionary = HouseFurnishCheck.new().check(plan)
		for f in rep["failures"]:
			for rule in FENG_SHUI_RULES:
				if String(f).begins_with(rule + ":"):
					bad += 1
					res.fail("feng shui sweep: seed=%d %s: %s"
						% [spec.seed, String(spec.style), str(f)])
		for w in rep["warnings"]:
			for rule in FENG_SHUI_RULES:
				if String(w).begins_with(rule + ":"):
					warned[rule] = int(warned.get(rule, 0)) + 1
	for rule in FENG_SHUI_RULES:
		res.note("feng shui   %-18s %3d warnings" % [rule, int(warned.get(rule, 0))])
	res.note("feng shui   200 houses, %d failures" % bad)
