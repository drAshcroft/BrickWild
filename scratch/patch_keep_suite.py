import io

p = 'tests/suites/castle_suite.gd'
s = io.open(p, encoding='utf-8').read()

old = '''	_great_hall(res)
	return res'''
new = '''	_great_hall(res)
	_keep(res)
	return res'''
assert old in s, 'call'
s = s.replace(old, new)

old = '''## How near the high table a seat has to be before it counts as being AT it.
const HIGH_TABLE_REACH := 2.5'''
new = '''## How near the high table a seat has to be before it counts as being AT it.
const HIGH_TABLE_REACH := 2.5


## The keep has an inside (CAS-011).
##
## Like the great hall it is a HousePlan, so the plan, furnishing and walking
## checks judge it and are not repeated here. What IS here is the handful of
## things that make it a keep rather than a tall house:
##
##   a blind foot -- no windows on storey 0, which is the point of a keep
##   the hall UP a stair over that store, which no dwelling is allowed
##   the lord at the top, with a bed and a fire of his own
##   one stairwell, against a wall, chaining every storey
static func _keep(res: SuiteResult) -> void:
	var built := 0
	var ranges: Array[Dictionary] = CastleSweep.each()
	for e in ranges:
		var spec: CastleSpec = CastleSweep.spec_at(e["style"], e["tier"], e["index"])
		var plan: HousePlan = CastleGenerator.keep_plan(spec)
		var who := "keep: %s %s %d" % [String(e["style"]), String(e["tier"]),
			int(e["index"])]
		res.checked += 1
		if plan.spec == null:
			continue                    # no keep, or too small to stack
		built += 1

		var levels: int = plan.spec.storeys
		if levels < 3 or levels > HouseGeometry.MAX_STOREYS:
			res.fail("%s: %d storeys -- a keep is three or four" % [who, levels])
			continue
		if plan.room_count() != levels:
			res.fail("%s: %d rooms over %d storeys -- one room to a storey"
				% [who, plan.room_count(), levels])
			continue
		if plan.kind_of(0) != &"store":
			res.fail("%s: the foot is a %s, not a store"
				% [who, String(plan.kind_of(0))])
		if plan.kind_of(1) != &"hall":
			res.fail("%s: the first floor is a %s, not the hall"
				% [who, String(plan.kind_of(1))])
		if plan.kind_of(levels - 1) != &"lords_chamber":
			res.fail("%s: the top is a %s, not the lord's chamber"
				% [who, String(plan.kind_of(levels - 1))])

		# blind at the foot, lit above
		for w in plan.windows:
			if HousePlan.record_storey(w) == 0:
				res.fail("%s: a window at the foot of a keep" % who)
				break
		for i in range(1, levels):
			if not HouseGeometry.is_habitable(plan.kind_of(i)):
				continue
			if plan.windows_of(i).is_empty():
				res.fail("%s: room %d (%s) has no window"
					% [who, i, String(plan.kind_of(i))])

		# one stairwell, chaining every storey, against a wall
		var joined := {}
		for st in plan.stairs:
			joined[int(st.get("storey", 0))] = true
			var rect: Rect2 = st["rect"]
			var f: Rect2 = HouseGeometry.room_floor_rect(plan, int(st["a"]))
			var touches: bool = absf(rect.position.x - f.position.x) < WALL_TOL \\
				or absf(rect.end.x - f.end.x) < WALL_TOL \\
				or absf(rect.position.y - f.position.y) < WALL_TOL \\
				or absf(rect.end.y - f.end.y) < WALL_TOL
			if not touches:
				res.fail("%s: the stair from storey %d stands off every wall"
					% [who, int(st.get("storey", 0))])
		for level in range(levels - 1):
			if not joined.has(level):
				res.fail("%s: nothing joins storey %d to %d"
					% [who, level, level + 1])

		# the lord has a bed and a fire, and the fire is on the flue's wall
		var top: int = levels - 1
		if plan.hearth_room() != top:
			res.fail("%s: the chimney serves room %d, not the lord's chamber"
				% [who, plan.hearth_room()])
		var beds := 0
		var fires := 0
		for f2 in plan.furniture_of(top):
			match PropCatalog.category(String(plan.furniture[f2]["key"])):
				"bed":
					beds += 1
				"hearth":
					fires += 1
		if beds == 0 and not plan.was_dropped(top, "bed"):
			res.fail("%s: nobody sleeps in the lord's chamber" % who)
		if fires == 0 and not plan.was_dropped(top, "hearth"):
			res.fail("%s: no fire in the lord's chamber" % who)

		# and the house harness has its say -- including that the walk from
		# the keep door reaches everything the lord uses
		var nav := HouseNavCheck.new()
		for rep in [HousePlanCheck.new().check(plan),
				HouseFurnishCheck.new().check(plan), nav.check(plan)]:
			for m in rep["failures"]:
				res.fail("%s: %s" % [who, str(m)])
			for w2 in rep["warnings"]:
				res.warn("%s: %s" % [who, str(w2)])
		if not nav.unreachable_items.is_empty():
			res.fail("%s: %d pieces cannot be reached from the keep door"
				% [who, nav.unreachable_items.size()])
	res.note("keep        %2d of %d castles have one" % [built, ranges.size()])


## How close a stairwell has to be to a wall to count as standing against it.
const WALL_TOL := 0.35'''
assert old in s, 'body'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('ok')
