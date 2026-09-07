import io

# ------------------------------------------------------------------ HousePlan
p = 'src/house/house_plan.gd'
s = io.open(p, encoding='utf-8').read()

old = '''## Vertical circulation. `a`/`b` are the lower/upper room IDs;'''
new = '''## The holes in the plan: {"rect": Rect2, "storey": int,
##  "outline": PackedVector2Array (optional)}.
##
## A court is FLOOR to the walk grid, SKY to the roof, and OUTSIDE to the
## daylight rule -- a window onto a courtyard is a window. The rooms and the
## courts together tile the footprint: what a court takes is not floor nobody
## owns, it is floor that belongs to the weather (GEO-003).
##
## It is what a monastery, an inn with a yard and a caravanserai are, and none
## of them can be said with rooms alone.
var courts: Array[Dictionary] = []
## Vertical circulation. `a`/`b` are the lower/upper room IDs;'''
assert old in s, 'courts field'
s = s.replace(old, new, 1)

old = '''## Is this room something a rectangle cannot describe?'''
new = '''## The court's shape in plan, its rectangle when it has no outline.
func court_outline(i: int) -> PackedVector2Array:
	return room_outline(courts[i])


## The courts open on one storey. A court is open from its own storey up: a
## range round a yard has the yard on every floor it rises through.
func courts_on(storey: int) -> Array[int]:
	var out: Array[int] = []
	for i in range(courts.size()):
		if record_storey(courts[i]) <= storey:
			out.append(i)
	return out


## Is any part of this plan open to the sky?
func has_court() -> bool:
	return not courts.is_empty()


## Is this room something a rectangle cannot describe?'''
assert old in s, 'court accessors'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('plan ok')

# ------------------------------------------------------------------ tiling
p = 'qa/house_plan_check.gd'
s = io.open(p, encoding='utf-8').read()

old = '''	var want: float = inner.size.x * inner.size.y
	stats["interior_area"] = snappedf(want, 0.01)'''
new = '''	# A court is a hole in the plan, and the hole is part of the tiling: the
	# rooms and the courts together fill the interior, and nothing may be built
	# in a court (GEO-003).
	for ci in range(plan.courts.size()):
		var court: Rect2 = plan.courts[ci]["rect"]
		if not inner.grow(TOL).encloses(court):
			failures.append("tiling: court %d sticks out of the interior" % ci)
		var clevel: int = HousePlan.record_storey(plan.courts[ci])
		for i2 in range(n):
			if HousePlan.record_storey(plan.rooms[i2]) < clevel:
				continue
			var lap: float = Poly.intersection_area(plan.outline_of(i2),
				plan.court_outline(ci))
			if lap > TOL:
				failures.append("tiling: room %d (%s) is built in court %d, by %.2f m2"
					% [i2, String(plan.kind_of(i2)), ci, lap])
	var courts_by_level := {}
	for ci2 in range(plan.courts.size()):
		var lv: int = HousePlan.record_storey(plan.courts[ci2])
		var a2: Rect2 = plan.courts[ci2]["rect"]
		courts_by_level[lv] = float(courts_by_level.get(lv, 0.0)) \\
			+ a2.size.x * a2.size.y

	var want: float = inner.size.x * inner.size.y
	stats["interior_area"] = snappedf(want, 0.01)
	stats["courts"] = plan.courts.size()'''
assert old in s, 'tiling courts'
s = s.replace(old, new, 1)

old = '''		if shaped.has(level):
			continue
		var sum: float = float(sums[level])
		if absf(sum - want) > 0.05 * want:'''
new = '''		if shaped.has(level):
			continue
		var sum: float = float(sums[level]) + float(courts_by_level.get(level, 0.0))
		if absf(sum - want) > 0.05 * want:'''
assert old in s, 'tiling sum'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('plan check ok')
