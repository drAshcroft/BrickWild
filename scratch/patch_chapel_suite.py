import io

p = 'tests/suites/castle_suite.gd'
s = io.open(p, encoding='utf-8').read()

old = '''	_great_hall(res)
	_keep(res)
	return res'''
new = '''	_great_hall(res)
	_keep(res)
	_chapel(res)
	return res'''
assert old in s, 'call'
s = s.replace(old, new, 1)

old = '''## How close a stairwell has to be to a wall to count as standing against it.
const WALL_TOL := 0.35'''
new = '''## How close a stairwell has to be to a wall to count as standing against it.
const WALL_TOL := 0.35


## The chapel has an inside (CAS-014).
##
## A chapel is a hall with one thing at the end of it, so the plan, furnishing
## and walking checks judge it exactly as they judge the great hall and are not
## repeated here. What IS here is the AXIS -- the way in, the aisle and the
## altar on one line -- which is the temple's own question asked of a nave
## (`TempleRiteCheck.plan_axis_faults`), and the pews either side of it.
static func _chapel(res: SuiteResult) -> void:
	var built := 0
	var ranges: Array[Dictionary] = CastleSweep.each()
	for e in ranges:
		var spec: CastleSpec = CastleSweep.spec_at(e["style"], e["tier"], e["index"])
		var plan: HousePlan = CastleGenerator.chapel_plan(spec)
		var who := "chapel: %s %s %d" % [String(e["style"]), String(e["tier"]),
			int(e["index"])]
		res.checked += 1
		if plan.spec == null:
			continue
		built += 1

		if plan.room_count() != 1 or plan.kind_of(0) != &"nave":
			res.fail("%s: %d rooms, first is %s -- a chapel is one nave"
				% [who, plan.room_count(), String(plan.kind_of(0))])
			continue
		# the altar and the way in on one line, and the altar down the nave
		for m in TempleRiteCheck.plan_axis_faults(plan, 0, plan.entrance()):
			res.fail("%s: %s" % [who, str(m)])
		# the sanctuary is a step, and the altar stands on it
		var sanct: Rect2 = plan.dais_rect()
		if sanct.size.x <= 0.0:
			res.fail("%s: no sanctuary at the altar end" % who)
		var altar := -1
		var best := INF
		for f in range(plan.furniture.size()):
			if PropCatalog.category(String(plan.furniture[f]["key"])) != "table":
				continue
			var d: float = Rect2(plan.furniture[f]["rect"]).get_center() \\
				.distance_to(plan.focus_pos())
			if d < best:
				best = d
				altar = f
		if altar < 0 or best > 0.3:
			if not plan.was_dropped(0, "table"):
				res.fail("%s: no altar where the plan pinned one" % who)
		elif sanct.size.x > 0.0 \\
				and not sanct.has_point(Rect2(plan.furniture[altar]["rect"]).get_center()):
			res.fail("%s: the altar stands off the sanctuary" % who)

		# the pews: rows either side, with an aisle between them
		var rows := {}
		for q in plan.furniture:
			var g: String = String(q.get("row", ""))
			if g != "":
				rows[g] = int(rows.get(g, 0)) + 1
		if rows.size() < 2 and not plan.was_dropped(0, "bench"):
			res.fail("%s: %d pew rows -- a nave has one each side of the aisle"
				% [who, rows.size()])
		for g2 in rows:
			if int(rows[g2]) < 2:
				res.fail("%s: row %s is one pew -- that is not a row" % [who, g2])

		for rep in [HousePlanCheck.new().check(plan),
				HouseFurnishCheck.new().check(plan), HouseNavCheck.new().check(plan)]:
			for m2 in rep["failures"]:
				res.fail("%s: %s" % [who, str(m2)])
			for w in rep["warnings"]:
				res.warn("%s: %s" % [who, str(w)])
	res.note("chapel      %2d of %d castles have one" % [built, ranges.size()])'''
assert old in s, 'body'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('written')
