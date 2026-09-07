import io

# ---- 1. once the dais group is placed, the dais is occupied ground
p = 'src/house/house_furnisher.gd'
s = io.open(p, encoding='utf-8').read()

old = '''	var zones: Array[Rect2] = []
	var r: RandomNumberGenerator = spec.rng
	for step in steps:
'''
new = '''	var zones: Array[Rect2] = []
	var r: RandomNumberGenerator = spec.rng
	# The dais belongs to the piece the room is arranged around and to whoever
	# sits behind it. Those two steps come first and stand ON it; everything
	# after them treats it as occupied ground, because a barrel on the dais is
	# a barrel on the lord's table and a row of trestles that runs up onto the
	# step is a row that has walked over the high table.
	var close_dais: int = _dais_closes_after(plan, room, steps)
	var dais_open: bool = close_dais >= 0
	for si in range(steps.size()):
		var step: Dictionary = steps[si]
		if dais_open and si > close_dais:
			blocked.append(plan.dais_rect())
			dais_open = false
'''
assert old in s, 'loop head'
s = s.replace(old, new)

old = '''	_ensure_seating(plan, room, blocked, zones, r)
	_ensure_light(plan, room, r)
	_keep_the_room_passable(plan, room, blocked, zones)'''
new = '''	if dais_open:
		blocked.append(plan.dais_rect())
	_ensure_seating(plan, room, blocked, zones, r)
	_ensure_light(plan, room, r)
	_keep_the_room_passable(plan, room, blocked, zones)


## The last step allowed to put something on the dais: the seat behind the
## focus if the recipe has one, else the focus itself. -1 when the room has no
## dais, in which case nothing is closed off at all.
static func _dais_closes_after(plan: HousePlan, room: int, steps: Array) -> int:
	if plan.dais_room() != room or plan.dais_rect().size.x <= 0.0:
		return -1
	for i in range(steps.size() - 1, -1, -1):
		if steps[i]["rule"] == &"behind":
			return i
	for i2 in range(steps.size()):
		if String(steps[i2]["cat"]) == plan.focus_cat():
			return i2
	return -1'''
assert old in s, 'loop tail'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('furnisher ok')

# ---- 2. the suite finds the high table the way the focus rule does
p = 'tests/suites/castle_suite.gd'
s = io.open(p, encoding='utf-8').read()
old = '''		var high := -1
		for f in range(plan.furniture.size()):
			var q: Dictionary = plan.furniture[f]
			if PropCatalog.category(String(q["key"])) != "table":
				continue
			if dais.has_point(Rect2(q["rect"]).get_center()):
				high = f
		if high < 0:
			if not plan.was_dropped(0, "table"):
				res.fail("%s: nothing stands on the dais" % who)
			continue'''
new = '''		# the high table is the piece the focus records, the same way
		# HouseFurnishCheck finds it: the nearest table to where the plan
		# pinned one. Picking "a table on the dais" would find a trestle.
		var high := -1
		var best := INF
		for f in range(plan.furniture.size()):
			var q: Dictionary = plan.furniture[f]
			if PropCatalog.category(String(q["key"])) != "table":
				continue
			var d: float = Rect2(q["rect"]).get_center().distance_to(plan.focus_pos())
			if d < best:
				best = d
				high = f
		if high < 0 or best > 0.3:
			if not plan.was_dropped(0, "table"):
				res.fail("%s: no high table where the plan pinned one" % who)
			continue
		if not dais.has_point(Rect2(plan.furniture[high]["rect"]).get_center()):
			res.fail("%s: the high table stands off the dais" % who)'''
assert old in s, 'high table'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('castle suite ok')
