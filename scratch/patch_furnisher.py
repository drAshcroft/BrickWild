import io

p = 'src/house/house_furnisher.gd'
s = io.open(p, encoding='utf-8').read()
before = len(s)

# ---- 1. the great hall recipe, before guest_room
anchor = '\t&"guest_room": [\n\t\t{"cat": "bed", "rule": &"wall", "n": [1, 1], "opt": 1.0},'
assert anchor in s
recipe = '''	&"great_hall": [
		# In order, because in a hall the order IS the arrangement: the high
		# table takes the dais, the lord bench goes behind it, the fire takes
		# its wall, and only then do the trestles take what is left. Run the
		# other way round, the trestles have the wall the flue rises on.
		{"cat": "table", "rule": &"free", "n": [1, 1], "opt": 1.0},
		{"cat": "bench", "rule": &"behind", "n": [1, 2], "opt": 1.0},
		{"cat": "hearth", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "table", "rule": &"row", "n": [2, 8], "min_n": 2, "pitch": 2.4,
			"aisle": 1.0, "seat_clearance": 1.1, "along": "wall", "opt": 1.0},
		{"cat": "table", "rule": &"row", "n": [2, 8], "min_n": 2, "pitch": 2.4,
			"aisle": 1.0, "seat_clearance": 1.1, "along": "wall", "opt": 1.0},
		{"cat": "bench", "rule": &"around", "host": "row", "n": [2, 4], "opt": 1.0},
		{"cat": "storage", "rule": &"wall", "n": [0, 1], "opt": 0.5},
		{"cat": "barrel", "rule": &"corner", "n": [1, 2], "opt": 0.6},
		{"cat": "sconce", "rule": &"mounted", "n": [2, 4], "opt": 1.0},
		{"cat": "chandelier", "rule": &"ceiling", "n": [1, 2], "opt": 0.6},
		{"cat": "tableware", "rule": &"on", "n": [2, 6], "opt": 0.9},
		{"cat": "candle", "rule": &"on", "n": [1, 2], "opt": 0.85},
	],
'''
s = s.replace(anchor, recipe + anchor)

# ---- 2. plan zones are occupied ground before anything is placed
old = '''static func _initial_blocked(plan: HousePlan, room: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for d in plan.doors_of(room):'''
new = '''static func _initial_blocked(plan: HousePlan, room: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	# Floor the plan itself keeps clear -- a screens passage, a processional
	# aisle. It is occupied ground before the first piece is placed, so a
	# passage the plan drew is a passage the furnishing cannot fill in.
	out.append_array(plan.zones_of(room))
	for d in plan.doors_of(room):'''
assert old in s
s = s.replace(old, new)

# ---- 3. a piece standing on the dais stands ON it
old = '''	var pos: Vector3 = cand["pos"]
	# Candidates are planar (Y=0) while searching. Stamp world elevation only
	# after the placement is accepted, keeping all rectangle logic 2D.
	pos.y += _storey_base(plan, room)'''
new = '''	var pos: Vector3 = cand["pos"]
	# Candidates are planar (Y=0) while searching. Stamp world elevation only
	# after the placement is accepted, keeping all rectangle logic 2D. A dais
	# is part of that elevation: the high table stands ON the step, and
	# everything in plan still measures as though the step were flat floor.
	pos.y += _storey_base(plan, room)
	if plan.on_dais(room, Vector2(pos.x, pos.z)):
		pos.y += plan.dais_rise()'''
assert old in s
s = s.replace(old, new)

# ---- 4. the step reaches _place_one, so a rule can be told which host it wants
old = '\t\t\t_place_one(plan, spec, room, String(step["cat"]), step["rule"], blocked, zones, r)'
new = ('\t\t\t_place_one(plan, spec, room, String(step["cat"]), step["rule"],\n'
       '\t\t\t\tblocked, zones, r, step)')
assert old in s
s = s.replace(old, new)

old = '''static func _place_one(plan: HousePlan, spec: HouseSpec, room: int, cat: String,
		rule: StringName, blocked: Array[Rect2], zones: Array[Rect2],
		r: RandomNumberGenerator) -> void:'''
new = '''static func _place_one(plan: HousePlan, spec: HouseSpec, room: int, cat: String,
		rule: StringName, blocked: Array[Rect2], zones: Array[Rect2],
		r: RandomNumberGenerator, step: Dictionary = {}) -> void:'''
assert old in s
s = s.replace(old, new)

old = '''		&"around":
			_place_around(plan, room, key, blocked, zones, r)'''
new = '''		&"around":
			_place_around(plan, room, key, blocked, zones, r,
				String(step.get("host", "")) == "row")
		&"behind":
			_place_behind(plan, room, key, blocked, zones, r)'''
assert old in s
s = s.replace(old, new)

# ---- 5. _place_around learns which host it is seating
old = '''static func _place_around(plan: HousePlan, room: int, key: String,
		blocked: Array[Rect2], zones: Array[Rect2], r: RandomNumberGenerator) -> void:
	var host: int = _find_host(plan, room, ["table", "workbench", "counter"])'''
new = '''static func _place_around(plan: HousePlan, room: int, key: String,
		blocked: Array[Rect2], zones: Array[Rect2], r: RandomNumberGenerator,
		want_row := false) -> void:
	var host: int = _find_host(plan, room, ["table", "workbench", "counter"], want_row)'''
assert old in s
s = s.replace(old, new)

old = '''static func _find_host(plan: HousePlan, room: int, cats: Array) -> int:
	for f in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[f]["key"]) in cats:
			return f
	return -1'''
new = '''## Which piece a seat is drawn up to.
##
## The first one of the right kind, except when the step asks for a row: a
## great hall seats the trestles, not the high table, and among the trestles it
## seats whichever has the fewest people at it already, so a second bench goes
## to the next table rather than crowding the first.
static func _find_host(plan: HousePlan, room: int, cats: Array,
		want_row := false) -> int:
	var pool: Array[int] = []
	for f in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[f]["key"]) in cats:
			pool.append(f)
	if pool.is_empty():
		return -1
	if not want_row:
		return pool[0]
	var rows: Array[int] = []
	for f2 in pool:
		if String(plan.furniture[f2].get("row", "")) != "":
			rows.append(f2)
	if rows.is_empty():
		return pool[0]
	var best: int = rows[0]
	var fewest: int = 1 << 20
	for f3 in rows:
		var n := 0
		for g in plan.furniture_of(room):
			if int(plan.furniture[g]["host"]) == f3:
				n += 1
		if n < fewest:
			fewest = n
			best = f3
	return best


## The seat that belongs on the far side of its host, looking the same way it
## looks: the lord bench behind the high table, the clerk stool behind the
## counter.
##
## `around` puts a chair on whichever side of a table has room, which is right
## for a kitchen table and wrong for anything with a front and a back. Nobody
## sits between the high table and the hall. (CAS-010)
##
## The bench stands on its own feet -- no `host` -- because it is not drawn up
## to the table and pushed back in again: it is where the lord sits, the walk
## has to reach it, and a body crossing the dais has to go round it.
static func _place_behind(plan: HousePlan, room: int, key: String,
		blocked: Array[Rect2], zones: Array[Rect2], r: RandomNumberGenerator) -> void:
	var host: int = _find_host(plan, room, ["table", "workbench", "counter"])
	if host < 0:
		return
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var host_rect: Rect2 = plan.furniture[host]["rect"]
	var hc: Vector2 = host_rect.get_center()
	var yaw: float = float(plan.furniture[host]["yaw"])
	var back: Vector2 = -_facing_of(yaw)          # away from what the host faces
	var foot: Vector2 = PropCatalog.footprint_yawed(key, yaw)
	var half: Vector2 = host_rect.size / 2.0
	var out: float = absf(back.x) * (half.x + foot.x / 2.0) \\
		+ absf(back.y) * (half.y + foot.y / 2.0) + 0.04
	var along := Vector2(back.y, -back.x)
	var run: float = absf(along.x) * host_rect.size.x + absf(along.y) * host_rect.size.y
	var span: float = absf(along.x) * foot.x + absf(along.y) * foot.y
	var best: Dictionary = {}
	var best_score := -INF
	var steps: int = maxi(int(run / 0.45), 1)
	for si in range(steps + 1):
		var t: float = lerpf(-run / 2.0 + span / 2.0, run / 2.0 - span / 2.0,
			float(si) / float(steps))
		var centre: Vector2 = hc + back * out + along * t
		var cand: Dictionary = _candidate(key, centre, yaw)
		if not _fits(cand, floor_rect, blocked, zones, []):
			continue
		# the middle of the table first: that is where the lord sits
		var score: float = r.randf() * 0.2 - absf(t)
		if score > best_score:
			best_score = score
			best = cand
	_commit(plan, room, best, blocked, zones)'''
assert old in s
s = s.replace(old, new)

# ---- 6. dropping "the table" must not drop a trestle out of a row
old = '''	for f in range(plan.furniture.size() - 1, -1, -1):
		var p: Dictionary = plan.furniture[f]
		if int(p["room"]) != room or PropCatalog.category(p["key"]) != "table":
			continue'''
new = '''	for f in range(plan.furniture.size() - 1, -1, -1):
		var p: Dictionary = plan.furniture[f]
		if int(p["room"]) != room or PropCatalog.category(p["key"]) != "table":
			continue
		# a row is placed and judged as a row; taking one trestle out of the
		# middle of it would break the very thing the row rule measures
		if String(p.get("row", "")) != "":
			continue'''
assert old in s
s = s.replace(old, new)

assert len(s) > before
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('ok', before, '->', len(s))
