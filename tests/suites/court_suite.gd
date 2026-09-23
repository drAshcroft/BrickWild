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
	plan.rooms = [
		{"kind": &"hall", "storey": 0,
			"rect": Rect2(inner.position, Vector2(inner.size.x, depth))},
		# the back range sleeps: a four-range house with nowhere to sleep puts
		# the bed in its hall, and the hall here is a narrow range with windows
		# on both of its long walls -- street on one side, yard on the other --
		# so the bed ends up under one whichever wall it takes
		{"kind": &"bedroom", "storey": 0,
			"rect": Rect2(Vector2(inner.position.x, court.end.y),
				Vector2(inner.size.x, inner.end.y - court.end.y))},
		{"kind": &"kitchen", "storey": 0,
			"rect": Rect2(Vector2(inner.position.x, court.position.y),
				Vector2(depth, court.size.y))},
		{"kind": &"store", "storey": 0,
			"rect": Rect2(Vector2(court.end.x, court.position.y),
				Vector2(inner.end.x - court.end.x, court.size.y))},
	]
	plan.doors = [{"a": 0, "b": -1,
		"pos": Vector2(inner.get_center().x, inner.position.y),
		"normal": Vector2(0, -1), "width": HouseGeometry.DOOR_W,
		"exterior": true, "front": true, "storey": 0}]
	var onto := [
		[0, Vector2(court.get_center().x, court.position.y), Vector2(0, 1)],
		[1, Vector2(court.get_center().x, court.end.y), Vector2(0, -1)],
		[2, Vector2(court.position.x, court.get_center().y), Vector2(1, 0)],
		[3, Vector2(court.end.x, court.get_center().y), Vector2(-1, 0)],
	]
	for row in onto:
		plan.doors.append({"a": int(row[0]), "b": -1, "pos": row[1],
			"normal": Vector2(row[2]), "width": HouseGeometry.DOOR_W,
			"exterior": true, "front": false, "storey": 0})
		var n: Vector2 = row[2]
		var along := Vector2(n.y, -n.x)
		var reach: float = (court.size.x if absf(n.y) > 0.5 else court.size.y) * 0.3
		for t in [-1.0, 1.0]:
			plan.windows.append({"room": int(row[0]),
				"pos": Vector2(row[1]) + along * t * reach, "normal": n,
				"width": HouseGeometry.WINDOW_W,
				"sill": HouseGeometry.WINDOW_SILL,
				"head": HouseGeometry.WINDOW_SILL + HouseGeometry.WINDOW_H,
				"storey": 0})
	plan.windows.append({"room": 0,
		"pos": Vector2(inner.get_center().x - inner.size.x * 0.25, inner.position.y),
		"normal": Vector2(0, -1), "width": HouseGeometry.WINDOW_W,
		"sill": HouseGeometry.WINDOW_SILL,
		"head": HouseGeometry.WINDOW_SILL + HouseGeometry.WINDOW_H, "storey": 0})
	plan.hearth = {"room": 2, "wall": 2}
	if with_furniture:
		HouseFurnisher.furnish(plan, spec)
	return plan
