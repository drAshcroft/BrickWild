import io

p = 'tests/suites/house_qa_suite.gd'
s = io.open(p, encoding='utf-8').read()

old = '''	_row_fixture(res)
	_upstairs_programme_fixture(res)'''
new = '''	_row_fixture(res)
	_step_fixture(res)
	_screens_fixture(res)
	_upstairs_programme_fixture(res)'''
assert old in s
s = s.replace(old, new)

old = '''static func _row_of(key: String, foot: Vector2, cat: String, base_z: float,'''
new = '''## A dais is a step, not a wall, and a drop is not a step (CAS-010).
##
## The walk grid gained a level per cell so a castle great hall could have a
## raised end its walker climbs onto. Shown both ways round, because a level
## that never blocks anything is the same as no level at all: at 0.4 m the
## walker gets up onto the platform, at 1.2 m it is floor it can stand on and
## cannot reach, which is what a check would have to say about a mezzanine
## somebody laid down without a stair.
static func _step_fixture(res: SuiteResult) -> void:
	var room := Rect2(Vector2.ZERO, Vector2(6.0, 6.0))
	var raised := Rect2(Vector2(0.0, 4.0), Vector2(6.0, 2.0))
	for rise in [0.4, 1.2]:
		var grid := WalkGrid.new()
		grid.setup(room, HouseGeometry.NAV_CELL)
		grid.add_floor(room)
		grid.add_step(raised, float(rise))
		grid.build(HouseGeometry.PERSON_RADIUS)
		res.checked += 1
		if not grid.flood_from(Vector2(3.0, 1.0)):
			res.fail("step fixture: nowhere to stand on a 6 x 6m floor")
			continue
		if not grid.standable(raised):
			res.fail("step fixture: a %.1fm platform is not standable floor" % rise)
		var got: bool = grid.reached(raised)
		var want: bool = float(rise) <= WalkGrid.MAX_STEP
		if got != want:
			res.fail("step fixture: a %.1fm step was %s, and MAX_STEP is %.2fm"
				% [rise, "walked onto" if got else "not walked onto", WalkGrid.MAX_STEP])


## Floor the plan keeps clear stays clear, and the rule says so when it does
## not. The screens passage of a great hall is the case it was written for.
static func _screens_fixture(res: SuiteResult) -> void:
	var choices: Array[String] = PropCatalog.of_category("table")
	if choices.is_empty():
		res.warn("screens fixture: no table prop in the catalogue to build it from")
		return
	var key: String = choices[0]
	var spec := HouseSpec.new(1)
	spec.width = 8.0
	spec.length = 12.0
	spec.height = 2.6
	var plan := HousePlan.new()
	plan.spec = spec
	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	plan.rooms = [{"kind": &"hall", "rect": inner, "storey": 0}]
	var strip := Rect2(inner.position, Vector2(inner.size.x, 2.2))
	plan.zones = [{"room": 0, "rect": strip, "why": "screens passage"}]

	var foot: Vector2 = PropCatalog.footprint_yawed(key, 0.0)
	var cat: String = PropCatalog.category(key)
	# clear of the passage: the far end of the hall
	var clear_z: float = inner.end.y - foot.y / 2.0 - 0.2
	plan.furniture = [_piece(key, cat, Vector2(0.0, clear_z), foot)]
	res.checked += 1
	for m in HouseFurnishCheck.new().check(plan)["failures"]:
		if String(m).begins_with("clear:"):
			res.fail("screens fixture: a table at the far end of the hall was flagged: %s"
				% str(m))

	# and standing in it
	plan.furniture = [_piece(key, cat, strip.get_center(), foot)]
	res.checked += 1
	var caught := false
	for m2 in HouseFurnishCheck.new().check(plan)["failures"]:
		if String(m2).begins_with("clear:"):
			caught = true
	if not caught:
		res.fail("screens fixture: a table standing in the screens passage was not caught")


static func _piece(key: String, cat: String, at: Vector2, foot: Vector2) -> Dictionary:
	return {"key": key, "room": 0, "storey": 0, "pos": Vector3(at.x, 0.0, at.y),
		"yaw": 0.0, "rect": Rect2(at - foot / 2.0, foot), "zone": Rect2(),
		"host": -1, "cat": cat, "mounted": false, "scale": 1.0}


static func _row_of(key: String, foot: Vector2, cat: String, base_z: float,'''
assert old in s
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('ok')
