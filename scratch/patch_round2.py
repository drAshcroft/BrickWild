import io

# ---- 1. a step that seats a row, and no row, seats nobody
p = 'src/house/house_furnisher.gd'
s = io.open(p, encoding='utf-8').read()
old = '''	var rows: Array[int] = []
	for f2 in pool:
		if String(plan.furniture[f2].get("row", "")) != "":
			rows.append(f2)
	if rows.is_empty():
		return pool[0]'''
new = '''	var rows: Array[int] = []
	for f2 in pool:
		if String(plan.furniture[f2].get("row", "")) != "":
			rows.append(f2)
	# A step that seats a ROW and finds no row seats nobody. Falling back to
	# the first table in the room put a bench in front of a great hall high
	# table on every hall too small for its trestles -- which is the one place
	# in the room nobody sits.
	if rows.is_empty():
		return -1'''
assert old in s, 'find_host'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('furnisher ok')

# ---- 2. a hall is long, and that is what a hall is
p = 'src/house/house_geometry.gd'
s = io.open(p, encoding='utf-8').read()
old = 'const ROOM_ASPECT_MAX := 3.4\n'
new = '''const ROOM_ASPECT_MAX := 3.4
## Except where length IS the room. A great hall is long on purpose --
## Westminster is 20.7 x 73 m, three and a half to one -- and a castle range is
## narrower than that again, so measuring one against a parlour reports every
## hall ever built as a corridor.
const ASPECT_MAX := {&"great_hall": 6.0}


## The longest a room of `kind` may be for its width before it stops being a
## room and starts being a passage.
static func aspect_max(kind: StringName) -> float:
	return float(ASPECT_MAX.get(kind, ROOM_ASPECT_MAX))
'''
assert old in s, 'aspect'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('geometry ok')

p = 'qa/house_plan_check.gd'
s = io.open(p, encoding='utf-8').read()
old = '''		if HouseGeometry.room_aspect(plan, i) > HouseGeometry.ROOM_ASPECT_MAX:'''
new = '''		if HouseGeometry.room_aspect(plan, i) > HouseGeometry.aspect_max(kind):'''
assert old in s, 'plan check aspect'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('plan check ok')

# ---- 3. a hall is lit by hall windows, not by arrow slits
p = 'src/castle/castle_generator.gd'
s = io.open(p, encoding='utf-8').read()
old = '''	var margin: float = HouseGeometry.DOOR_CORNER_MARGIN + HouseGeometry.WINDOW_W
	var usable: float = run - margin * 2.0
	if usable <= HouseGeometry.WINDOW_W:
		return
	var count: int = clampi(int(usable / 2.6), 1, 24)
	var head: float = minf(HouseGeometry.WINDOW_SILL + HouseGeometry.WINDOW_H,
		hs.height - 0.15)
	if head - HouseGeometry.WINDOW_SILL < 0.4:
		return'''
new = '''	var margin: float = HouseGeometry.DOOR_CORNER_MARGIN + WINDOW_W
	var usable: float = run - margin * 2.0
	if usable <= WINDOW_W:
		return
	var count: int = maxi(int(usable / WINDOW_PITCH), 1)
	var head: float = minf(WINDOW_SILL + WINDOW_H, hs.height - 0.2)
	if head - WINDOW_SILL < 0.4:
		return'''
assert old in s, 'hall windows head'
s = s.replace(old, new)

old = '''			plan.windows.append({"room": 0, "pos": pos, "normal": n,
				"width": HouseGeometry.WINDOW_W,
				"sill": HouseGeometry.WINDOW_SILL, "head": head, "storey": 0})'''
new = '''			plan.windows.append({"room": 0, "pos": pos, "normal": n,
				"width": WINDOW_W, "sill": WINDOW_SILL, "head": head,
				"storey": 0})'''
assert old in s, 'hall window record'
s = s.replace(old, new)

old = '''## And the strip inside the door that stays clear.
const SCREENS_SHARE := 0.18
const SCREENS_MAX := 2.4'''
new = '''## And the strip inside the door that stays clear.
const SCREENS_SHARE := 0.18
const SCREENS_MAX := 2.4
## A hall is lit by hall windows: tall, wide, and one to a bay. A cottage
## casement (0.95 x 1.05 m) in a room seventy metres long is an arrow slit --
## fifty of them still leave the floor under a twentieth of its area in glass,
## which is what the plan check calls too dark to live in.
const WINDOW_W := 1.4
const WINDOW_SILL := 1.1
const WINDOW_H := 3.4
const WINDOW_PITCH := 3.2'''
assert old in s, 'window consts'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('castle ok')
