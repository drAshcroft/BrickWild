import io

p = 'src/castle/castle_generator.gd'
lines = io.open(p, encoding='utf-8').read().split('\n')

# use the castle's own window size for the keep, not a cottage casement
for i, l in enumerate(lines):
    if 'var head: float = minf(HouseGeometry.WINDOW_SILL + HouseGeometry.WINDOW_H,' in l \
            and 'hs.height - 0.2' in lines[i + 1] and 'KeepSpec' in lines[i - 1]:
        lines[i] = '\tvar head: float = minf(WINDOW_SILL + WINDOW_H, hs.height - 0.2)'
        del lines[i + 1]
        break
else:
    raise SystemExit('head line not found')

src = '\n'.join(lines)
old = '''	if head - HouseGeometry.WINDOW_SILL < 0.4:
		return
	# One window to a bay down every wall, not one window to a wall. A keep
	# floor is twelve metres across at the least, and a single casement in each
	# side of it is a room the plan check rightly calls too dark to live in.
	var margin: float = HouseGeometry.DOOR_CORNER_MARGIN + HouseGeometry.WINDOW_W'''
new = '''	if head - WINDOW_SILL < 0.4:
		return
	# FEW AND TALL, not many and small. A keep floor is twelve metres across at
	# the least, so one cottage casement to a wall leaves it too dark to live
	# in -- but a ribbon of them along every wall is worse: it still does not
	# glaze the floor, and it leaves nowhere to put a bed that is not under a
	# window. Castle windows, five metres apart, do both jobs at once.
	var margin: float = HouseGeometry.DOOR_CORNER_MARGIN + WINDOW_W'''
assert old in src, 'head guard'
src = src.replace(old, new)

old = '''		if usable <= HouseGeometry.WINDOW_W:
			continue
		var count: int = maxi(int(usable / KEEP_WINDOW_PITCH), 1)'''
new = '''		if usable <= WINDOW_W:
			continue
		var count: int = maxi(int(usable / KEEP_WINDOW_PITCH), 1)'''
assert old in src, 'usable'
src = src.replace(old, new)

old = '''				plan.windows.append({"room": level, "pos": pos, "normal": n,
					"width": HouseGeometry.WINDOW_W,
					"sill": HouseGeometry.WINDOW_SILL, "head": head,
					"storey": level})'''
new = '''				plan.windows.append({"room": level, "pos": pos, "normal": n,
					"width": WINDOW_W, "sill": WINDOW_SILL, "head": head,
					"storey": level})'''
assert old in src, 'append'
src = src.replace(old, new)

old = '''## How far apart a keep sets its windows along a wall.
const KEEP_WINDOW_PITCH := 3.2'''
new = '''## How far apart a keep sets its windows along a wall. Wider than the hall
## pitch on purpose: the gap between two of them is where the bed goes.
const KEEP_WINDOW_PITCH := 5.0'''
assert old in src, 'pitch'
src = src.replace(old, new)

io.open(p, 'w', encoding='utf-8', newline='\n').write(src)
print('written')
