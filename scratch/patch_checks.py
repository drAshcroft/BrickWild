import io

# ---------------------------------------------------------------- geometry
p = 'src/house/house_geometry.gd'
s = io.open(p, encoding='utf-8').read()

old = '\t&"gallery": 8.0, &"laundry": 7.0,\n}'
new = '\t&"gallery": 8.0, &"laundry": 7.0, &"great_hall": 16.0,\n}'
assert old in s
s = s.replace(old, new)

old = '\t&"gallery": 2.4, &"laundry": 2.4,\n}'
new = '\t&"gallery": 2.4, &"laundry": 2.4, &"great_hall": 3.0,\n}'
assert old in s
s = s.replace(old, new)

old = '''	&"lounge", &"suite", &"gallery", &"laundry"]'''
new = '''	&"lounge", &"suite", &"gallery", &"laundry", &"great_hall"]'''
assert old in s
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('geometry ok')

# ---------------------------------------------------------------- nav check
p = 'qa/house_nav_check.gd'
s = io.open(p, encoding='utf-8').read()

old = '''##   ISLANDS      no stranded pocket of floor big enough to stand in'''
new = '''##   ISLANDS      no stranded pocket of floor big enough to stand in
##   STEPS        a dais is floor you walk onto, and the passages the plan
##                itself keeps clear are passages you can actually walk'''
assert old in s
s = s.replace(old, new)

old = '''	for d in _plan.doors:
		var level := HousePlan.record_storey(d)
		if _grids.has(level):
			_grids[level].add_floor(_door_gap(d))'''
new = '''	for d in _plan.doors:
		var level := HousePlan.record_storey(d)
		if _grids.has(level):
			_grids[level].add_floor(_door_gap(d))
	# A dais is laid down after the floor it stands on, and as a STEP: floor at
	# a different height. A rise a person can walk up joins the room; one they
	# cannot is cut off, and the walk says so rather than pretending. (CAS-010)
	var dais_room: int = _plan.dais_room()
	if dais_room >= 0 and dais_room < _plan.room_count():
		var dl := HousePlan.record_storey(_plan.rooms[dais_room])
		if _grids.has(dl):
			_grids[dl].add_step(_plan.dais_rect(), _plan.dais_rise())'''
assert old in s
s = s.replace(old, new)

old = '''	_check_rooms()
	_check_doors()
	_check_use_zones()
	_check_islands()
	return _report()'''
new = '''	_check_rooms()
	_check_doors()
	_check_use_zones()
	_check_steps()
	_check_islands()
	return _report()'''
assert old in s
s = s.replace(old, new)

old = '''## Floor a person can stand on, but cannot walk to. A pocket behind a table is'''
new = '''## The dais and every passage the plan keeps clear are places a person is meant
## to get to. The dais is the harder of the two: it is floor at another height,
## so reaching it proves the step is a step and not a wall the walk went round.
func _check_steps() -> void:
	var room: int = _plan.dais_room()
	if room >= 0 and room < _plan.room_count():
		var rect: Rect2 = _plan.dais_rect()
		var grid: WalkGrid = _grid_for(_plan.rooms[room])
		if not grid.reached(rect):
			if grid.standable(rect):
				failures.append("steps: the dais in room %d (%s) stands %.2fm up and nobody can walk onto it"
					% [room, String(_plan.kind_of(room)), _plan.dais_rise()])
			else:
				failures.append("steps: the dais in room %d (%s) is so full there is nowhere to stand on it"
					% [room, String(_plan.kind_of(room))])
	for z in _plan.zones:
		var zr: int = int(z.get("room", -1))
		if zr < 0 or zr >= _plan.room_count():
			continue
		if not _grid_for(_plan.rooms[zr]).reached(Rect2(z["rect"])):
			failures.append("steps: the %s in room %d cannot be walked"
				% [String(z.get("why", "clear floor")), zr])


## Floor a person can stand on, but cannot walk to. A pocket behind a table is'''
assert old in s
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('nav ok')

# ------------------------------------------------------------ furnish check
p = 'qa/house_furnish_check.gd'
s = io.open(p, encoding='utf-8').read()

old = '''	&"laundry": ["workbench"],
}'''
new = '''	&"laundry": ["workbench"],
	&"great_hall": ["table"],
}'''
assert old in s
s = s.replace(old, new)

old = '''	"arrangement": ["against", "seating", "row"],'''
new = '''	"arrangement": ["against", "seating", "row", "clear"],'''
assert old in s
s = s.replace(old, new)

old = '''const RULES: Array[StringName] = [&"placed", &"vertical", &"supported", &"doorway",
	&"daylight", &"programme", &"against", &"seating", &"light", &"density",
	&"command", &"hearth", &"row", &"workbench_daylight", &"bookcase_heat",'''
new = '''const RULES: Array[StringName] = [&"placed", &"vertical", &"supported", &"doorway",
	&"daylight", &"programme", &"against", &"seating", &"light", &"density",
	&"command", &"hearth", &"row", &"clear", &"workbench_daylight", &"bookcase_heat",'''
assert old in s
s = s.replace(old, new)

old = '''## Does a ray from `from` along `dir`, no longer than `reach`, cross `rect`?'''
new = '''## Floor the plan keeps clear stays clear.
##
## A screens passage is not furniture, and nothing about the pieces standing in
## a hall says where it was: only the plan does. So this is the one rule that
## reads a plan-level zone -- and it reads it against what was actually placed,
## which is the whole point. A passage the plan drew and the furnishing filled
## in is a passage that was never there.
func _check_clear(plan: HousePlan) -> void:
	for z in plan.zones:
		var rect: Rect2 = z["rect"]
		var why: String = String(z.get("why", "clear floor"))
		var room: int = int(z.get("room", -1))
		for f in range(plan.furniture.size()):
			var p: Dictionary = plan.furniture[f]
			if p.get("mounted", false) or int(p["host"]) >= 0:
				continue
			if int(p["room"]) != room:
				continue
			if not PropCatalog.blocks_floor(String(p["key"])):
				continue
			var r: Rect2 = p["rect"]
			if not r.intersects(rect):
				continue
			var over: Rect2 = r.intersection(rect)
			if over.size.x * over.size.y < TOL:
				continue
			failures.append("clear: %s stands in the %s" % [_who(plan, f), why])


## Does a ray from `from` along `dir`, no longer than `reach`, cross `rect`?'''
assert old in s
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('furnish ok')
