import io

# ---- the court joins the rooms that open onto it
p = 'src/house/house_plan.gd'
s = io.open(p, encoding='utf-8').read()

old = '''	for stair in stairs:
		var a: int = int(stair["a"])
		var b: int = int(stair["b"])
		if a < 0 or b < 0 or a >= rooms.size() or b >= rooms.size():
			continue
		g[a].append(b)'''
new = '''	# A COURT is a way through. Two ranges that both open onto the same yard
	# are joined by it: you walk out of one door, across the paving and in at
	# the other, which is how a cloister works and the only reason a plan of
	# four ranges round a hole is a building rather than four buildings.
	for ci in range(courts.size()):
		var onto: Array[int] = rooms_onto_court(ci)
		for x in onto:
			for y in onto:
				if x != y:
					g[x].append(y)
	for stair in stairs:
		var a: int = int(stair["a"])
		var b: int = int(stair["b"])
		if a < 0 or b < 0 or a >= rooms.size() or b >= rooms.size():
			continue
		g[a].append(b)'''
assert old in s, 'graph'
s = s.replace(old, new, 1)

old = '''## Is any part of this plan open to the sky?'''
new = '''## Which rooms have a door onto court `ci`.
func rooms_onto_court(ci: int) -> Array[int]:
	var out: Array[int] = []
	var poly: PackedVector2Array = court_outline(ci)
	for d in doors:
		var room: int = int(d["a"])
		if room < 0 or room >= rooms.size() or room in out:
			continue
		if record_storey(d) < record_storey(courts[ci]):
			continue
		var pos: Vector2 = d["pos"]
		var n: Vector2 = d["normal"]
		for side in [1.0, -1.0]:
			if Poly.contains_point(poly,
					pos + n * side * (HouseGeometry.WALL_T + 0.05), 0.01):
				out.append(room)
				break
	return out


## Is any part of this plan open to the sky?'''
assert old in s, 'rooms_onto_court'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('plan ok')

# ---- doors facing each other ACROSS A YARD are not the defect this rule means
p = 'qa/house_plan_check.gd'
s = io.open(p, encoding='utf-8').read()
i = s.index('doors_in_line')
head = s.rindex('func ', 0, i)
seg = s[head:head + 2000]
anchor = None
for line in seg.split('\n'):
    if 'doors_in_line:' in line and 'failures.append' in line:
        anchor = line
        break
assert anchor, seg[:400]
s = s.replace(anchor, anchor.replace('failures.append',
    'failures.append' , 1), 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('located:', anchor.strip()[:80])
