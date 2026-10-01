class_name CourtSuite
extends RefCounted
## 14a. Buildings round a yard (GEO-003).
##
## A courtyard is the oldest plan there is, and what makes one is not that it
## has a hole. `qa/court_check.gd` says what does, in four rules; this suite
## shows each of them FIRING, because a rule nobody has seen fail is a rule
## nobody has tested.
##
## Then it builds a hundred of them and asks the whole house harness -- plan,
## furnishing, walking -- and the court rules on top.

const SEEDS := 100
## The court is this share of the shorter side, so a big house gets a big yard.
const COURT_SHARE := 0.28
## A range longer than this many times its own depth is not one room, it is a
## corridor with a roof: it is cut into three along its length.
const RANGE_ASPECT := 2.4
## No piece of a cut range may be narrower than this: a parlour wants 2.6 m.
const PIECE_MIN := 3.0
## What a window onto the yard may be, so that the big rooms are still lit.
const YARD_WINDOW_MAX := 1.9


static func run() -> SuiteResult:
	var res := SuiteResult.new("courtyard")
	_fixtures(res)
	_sweep(res)
	return res


## Each rule, shown to fire on a plan that breaks it and to stay silent on one
## that does not.
static func _fixtures(res: SuiteResult) -> void:
	# a sound courtyard house says nothing
	var good: HousePlan = courtyard(17.0, 15.0, 7100)
	res.checked += 1
	for m in CourtCheck.new().check(good)["failures"]:
		res.fail("court fixture: a sound courtyard house was reported: %s" % str(m))

	# SKY: something built in the yard
	var sky: HousePlan = courtyard(17.0, 15.0, 7101)
	res.checked += 1
	if sky.furniture.is_empty():
		res.warn("court fixture: nothing was furnished to move into the yard")
	else:
		var piece: Dictionary = sky.furniture[0].duplicate()
		var c: Vector2 = Rect2(sky.courts[0]["rect"]).get_center()
		piece["rect"] = Rect2(c - Vector2(0.4, 0.4), Vector2(0.8, 0.8))
		piece["host"] = -1
		piece["mounted"] = false
		sky.furniture.append(piece)
		_expect(res, "sky", CourtCheck.new().check(sky))

	# INWARD: the windows turned to face the street instead of the yard
	var inward: HousePlan = courtyard(17.0, 15.0, 7102)
	res.checked += 1
	for i in range(inward.windows.size()):
		inward.windows[i]["normal"] = -Vector2(inward.windows[i]["normal"])
	_expect(res, "inward", CourtCheck.new().check(inward))

	# RING: no range opens onto the yard
	var ring: HousePlan = courtyard(17.0, 15.0, 7103)
	res.checked += 1
	var kept: Array[Dictionary] = []
	for d in ring.doors:
		if bool(d.get("front", false)):
			kept.append(d)
	ring.doors = kept
	_expect(res, "ring", CourtCheck.new().check(ring))

	# PROPORTION: a light well rather than a yard
	var thin: HousePlan = courtyard(17.0, 15.0, 7104)
	res.checked += 1
	var court: Rect2 = thin.courts[0]["rect"]
	thin.courts[0]["rect"] = Rect2(court.get_center() - Vector2(0.9, 0.9),
		Vector2(1.8, 1.8))
	_expect(res, "proportion", CourtCheck.new().check(thin))


static func _expect(res: SuiteResult, rule: String, report: Dictionary) -> void:
	for m in report["failures"]:
		if String(m).begins_with(rule + ":"):
			return
	res.fail("court fixture: the %s rule did not fire on a plan that breaks it"
		% rule)


## A hundred courtyard houses, judged by the whole harness.
static func _sweep(res: SuiteResult) -> void:
	var defects := 0
	var r := RandomNumberGenerator.new()
	r.seed = 20261201
	for i in range(SEEDS):
		var w: float = r.randf_range(13.0, 26.0)
		var l: float = w * r.randf_range(0.8, 1.25)
		var plan: HousePlan = courtyard(w, l, 7200 + i)
		res.checked += 1
		var who := "courtyard %.0f x %.0fm seed=%d" % [w, l, 7200 + i]
		var bad := false
		for rep in [HousePlanCheck.new().check(plan),
				HouseFurnishCheck.new().check(plan),
				HouseNavCheck.new().check(plan),
				CourtCheck.new().check(plan)]:
			for m in rep["failures"]:
				res.fail("%s: %s" % [who, str(m)])
				bad = true
			for wn in rep["warnings"]:
				res.warn("%s: %s" % [who, str(wn)])
		if bad:
			defects += 1
	res.note("courtyard   %d of %d houses with defects" % [defects, SEEDS])


## Four ranges round a yard: the plan a rectangle full of rooms cannot be.
##
## Built here rather than by HousePlanner, which partitions a rectangle and has
## no courtyard mode yet: what GEO-003 delivers is the representation and every
## rule that reads it, and this is the shape those rules are for.
static func courtyard(w: float, l: float, sd: int, with_furniture := true) -> HousePlan:
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
	var depth: float = clampf(minf(inner.size.x, inner.size.y) * COURT_SHARE,
		3.4, 5.0)
	var court := Rect2(inner.position + Vector2(depth, depth),
		inner.size - Vector2(depth, depth) * 2.0)
	plan.courts = [{"rect": court, "storey": 0}]
	_ring_of_rooms(plan, inner, court, depth)
	plan.hearth = {"room": 2, "wall": 2}
	if with_furniture:
		HouseFurnisher.furnish(plan, spec)
	return plan


## The cuts that divide the span lo..hi of a range of depth `depth` into rooms.
## One room when it is already room-shaped; three when it is a long gallery.
## ODD, never two, so a door in the middle of the range is never on a wall
## between rooms. Returned as the n + 1 boundaries, lo first, hi last.
static func _cuts(lo: float, hi: float, depth: float) -> Array[float]:
	var span := hi - lo
	var n := 1
	if span > RANGE_ASPECT * depth and span / 3.0 >= PIECE_MIN:
		n = 3
	var out: Array[float] = []
	for k in range(n + 1):
		out.append(lo + span * float(k) / float(n))
	return out


## A window wide enough that `panes` of them give `area` of floor its share of
## glass with a margin, and no wider than a wall of a yard house would carry.
static func _glass_width(area: float, panes: int) -> float:
	var need: float = area * HouseGeometry.GLAZING_MIN * 1.25
	return clampf(need / (float(panes) * HouseGeometry.WINDOW_H),
		HouseGeometry.WINDOW_W, YARD_WINDOW_MAX)


static func _window(room: int, pos: Vector2, n: Vector2, width: float) -> Dictionary:
	return {"room": room, "pos": pos, "normal": n, "width": width,
		"sill": HouseGeometry.WINDOW_SILL,
		"head": HouseGeometry.WINDOW_SILL + HouseGeometry.WINDOW_H, "storey": 0}


static func _internal_door(a: int, b: int, pos: Vector2, n: Vector2) -> Dictionary:
	return {"a": a, "b": b, "pos": pos, "normal": n,
		"width": HouseGeometry.INNER_DOOR_W, "exterior": false, "front": false,
		"storey": 0}


## The four ranges, each divided into rooms along its length, and the doors
## and windows that make them rooms.
##
## Front and back span the whole width, so they have a room at each corner and
## one or three on the yard between; the side ranges have only the yard run.
## Every room that stands on the yard has a door onto it and a pair of windows
## looking in. The corner rooms are not on the yard, so they open into their
## neighbour and look at the street. Rooms 0 to 3 stay the hall, the back
## bedroom, the kitchen and the store, as other fixtures index them.
static func _ring_of_rooms(plan: HousePlan, inner: Rect2, court: Rect2,
		depth: float) -> void:
	var fx: Array[float] = _cuts(court.position.x, court.end.x, depth)
	var fy: Array[float] = _cuts(court.position.y, court.end.y, depth)
	var split_x := fx.size() > 2
	var split_y := fy.size() > 2
	var front_kinds: Array[StringName] = [&"dining_room", &"hall", &"parlour"]
	var west_kinds: Array[StringName] = [&"parlour", &"kitchen", &"parlour"]
	var east_kinds: Array[StringName] = [&"parlour", &"store", &"parlour"]
	var keys: Array[StringName] = [&"front", &"back", &"west", &"east"]
	var rects: Dictionary = {&"front": [], &"back": [], &"west": [], &"east": []}
	var kinds: Dictionary = {&"front": [], &"back": [], &"west": [], &"east": []}
	for k in range(fx.size() - 1):
		rects[&"front"].append(Rect2(Vector2(fx[k], inner.position.y),
			Vector2(fx[k + 1] - fx[k], court.position.y - inner.position.y)))
		kinds[&"front"].append(front_kinds[k] if split_x else &"hall")
		rects[&"back"].append(Rect2(Vector2(fx[k], court.end.y),
			Vector2(fx[k + 1] - fx[k], inner.end.y - court.end.y)))
		kinds[&"back"].append(&"bedroom")
	for k in range(fy.size() - 1):
		rects[&"west"].append(Rect2(Vector2(inner.position.x, fy[k]),
			Vector2(court.position.x - inner.position.x, fy[k + 1] - fy[k])))
		kinds[&"west"].append(west_kinds[k] if split_y else &"kitchen")
		rects[&"east"].append(Rect2(Vector2(court.end.x, fy[k]),
			Vector2(inner.end.x - court.end.x, fy[k + 1] - fy[k])))
		kinds[&"east"].append(east_kinds[k] if split_y else &"store")
	# the corner rooms close the front and back ranges
	var corner_keys: Array[StringName] = [&"front_w", &"front_e", &"back_w", &"back_e"]
	var corner_kind := {&"front_w": &"parlour", &"front_e": &"parlour",
		&"back_w": &"parlour", &"back_e": &"store"}
	var corner_rect := {
		&"front_w": Rect2(inner.position,
			Vector2(court.position.x - inner.position.x, court.position.y - inner.position.y)),
		&"front_e": Rect2(Vector2(court.end.x, inner.position.y),
			Vector2(inner.end.x - court.end.x, court.position.y - inner.position.y)),
		&"back_w": Rect2(Vector2(inner.position.x, court.end.y),
			Vector2(court.position.x - inner.position.x, inner.end.y - court.end.y)),
		&"back_e": Rect2(court.end,
			Vector2(inner.end.x - court.end.x, inner.end.y - court.end.y))}
	# the principal room of a range is the middle piece; those are rooms 0..3
	var ids: Dictionary = {&"front": [], &"back": [], &"west": [], &"east": []}
	var principal: Dictionary = {}
	for key in keys:
		principal[key] = int(rects[key].size() / 2)
		ids[key].resize(rects[key].size())
		ids[key][principal[key]] = plan.rooms.size()
		plan.rooms.append({"kind": kinds[key][principal[key]], "storey": 0,
			"rect": rects[key][principal[key]]})
	for key in keys:
		for k in range(rects[key].size()):
			if k == principal[key]:
				continue
			ids[key][k] = plan.rooms.size()
			plan.rooms.append({"kind": kinds[key][k], "storey": 0, "rect": rects[key][k]})
	var corner_id: Dictionary = {}
	for key in corner_keys:
		corner_id[key] = plan.rooms.size()
		plan.rooms.append({"kind": corner_kind[key], "storey": 0, "rect": corner_rect[key]})

	# the street door, into the hall
	plan.doors.append({"a": ids[&"front"][principal[&"front"]], "b": -1,
		"pos": Vector2(inner.get_center().x, inner.position.y),
		"normal": Vector2(0, -1), "width": HouseGeometry.DOOR_W,
		"exterior": true, "front": true, "storey": 0})
	var normals := {&"front": Vector2(0, 1), &"back": Vector2(0, -1),
		&"west": Vector2(1, 0), &"east": Vector2(-1, 0)}
	for key in keys:
		var n: Vector2 = normals[key]
		var along := Vector2(n.y, -n.x)
		for k in range(rects[key].size()):
			var r: Rect2 = rects[key][k]
			var room: int = ids[key][k]
			# the yard face of this room, and the middle of it
			var at: Vector2
			var span: float
			if absf(n.y) > 0.5:
				at = Vector2(r.get_center().x, court.position.y if n.y > 0.0 else court.end.y)
				span = r.size.x
			else:
				at = Vector2(court.position.x if n.x > 0.0 else court.end.x, r.get_center().y)
				span = r.size.y
			var width := _glass_width(r.size.x * r.size.y, 2)
			var reach := maxf(span * 0.28, (width + HouseGeometry.DOOR_W) * 0.5 + 0.1)
			if key == &"back":
				# A bedroom's door is hung toward one end of its yard wall, not
				# in the middle: a bed never has to lie in the line of it, and
				# the two windows sit together on the long stretch beside it.
				var off := minf(span * 0.3, span * 0.5 - HouseGeometry.DOOR_W * 0.5 - 0.4)
				var door_at := at + along * off
				plan.doors.append({"a": room, "b": -1, "pos": door_at, "normal": n,
					"width": HouseGeometry.DOOR_W, "exterior": true, "front": false,
					"storey": 0})
				var stretch_lo := -span * 0.5
				var stretch_hi := off - (HouseGeometry.DOOR_W + width) * 0.5 - 0.1
				var stretch := stretch_hi - stretch_lo
				if stretch >= 2.0 * width + 0.3:
					for q in [0.25, 0.75]:
						plan.windows.append(_window(room,
							at + along * (stretch_lo + stretch * q), n, width))
				else:
					var one := minf(_glass_width(r.size.x * r.size.y, 1), stretch - 0.2)
					plan.windows.append(_window(room,
						at + along * (stretch_lo + stretch * 0.5), n, one))
			else:
				plan.doors.append({"a": room, "b": -1, "pos": at, "normal": n,
					"width": HouseGeometry.DOOR_W, "exterior": true, "front": false,
					"storey": 0})
				for t in [-1.0, 1.0]:
					plan.windows.append(_window(room, at + along * t * reach, n, width))
			# a room of a cut range opens into the next one along it -- except
			# the sleeping range, whose bedrooms each open on the yard alone
			if k + 1 < rects[key].size() and key != &"back":
				var edge: Vector2
				var dn: Vector2
				if absf(n.y) > 0.5:
					edge = Vector2(r.end.x, r.get_center().y)
					dn = Vector2(1, 0)
				else:
					edge = Vector2(r.get_center().x, r.end.y)
					dn = Vector2(0, 1)
				plan.doors.append(_internal_door(room, ids[key][k + 1], edge, dn))
	# each corner room opens into the room beside it and looks at the street
	# The back corners do NOT open into the back range, which sleeps: a room you
	# reach through a bedroom is a privacy failure. They open into the end of the
	# side range beside them (the kitchen side feeds the dining room).
	var beside := {&"front_w": [&"front", true, Vector2(1, 0), Vector2(0, -1)],
		&"front_e": [&"front", false, Vector2(-1, 0), Vector2(0, -1)],
		&"back_w": [&"west", false, Vector2(0, -1), Vector2(0, 1)],
		&"back_e": [&"east", false, Vector2(0, -1), Vector2(0, 1)]}
	for key in corner_keys:
		var row: Array = beside[key]
		var cr: Rect2 = corner_rect[key]
		var list: Array = ids[row[0]]
		var nid: int = int(list[0]) if bool(row[1]) else int(list[list.size() - 1])
		var dn2: Vector2 = row[2]
		var edge2 := Vector2(cr.end.x if dn2.x > 0.0 else cr.position.x, cr.get_center().y)
		if absf(dn2.y) > 0.5:
			edge2 = Vector2(cr.get_center().x, cr.position.y)
		plan.doors.append(_internal_door(corner_id[key], nid, edge2, dn2))
		var out_n: Vector2 = row[3]
		var wall_y: float = inner.position.y if out_n.y < 0.0 else inner.end.y
		plan.windows.append(_window(corner_id[key], Vector2(cr.get_center().x, wall_y),
			out_n, _glass_width(cr.size.x * cr.size.y, 1)))
	var hall_r: Rect2 = rects[&"front"][principal[&"front"]]
	plan.windows.append(_window(ids[&"front"][principal[&"front"]],
		Vector2(hall_r.get_center().x - hall_r.size.x * 0.3, inner.position.y),
		Vector2(0, -1), HouseGeometry.WINDOW_W))
