import io

p = 'src/castle/castle_generator.gd'
src = io.open(p, encoding='utf-8').read()
lines = src.split('\n')

start = next(i for i, l in enumerate(lines)
             if l.startswith('static func _keep_windows('))
# the body runs to the next blank-blank + top-level line
end = start
while end < len(lines) and not (lines[end] == '' and lines[end + 1] == ''):
    end += 1

body = '''static func _keep_windows(plan: HousePlan, floor_rect: Rect2, level: int,
		hs: KeepSpec) -> void:
	var head: float = minf(HouseGeometry.WINDOW_SILL + HouseGeometry.WINDOW_H,
		hs.height - 0.2)
	if head - HouseGeometry.WINDOW_SILL < 0.4:
		return
	# One window to a bay down every wall, not one window to a wall. A keep
	# floor is twelve metres across at the least, and a single casement in each
	# side of it is a room the plan check rightly calls too dark to live in.
	var margin: float = HouseGeometry.DOOR_CORNER_MARGIN + HouseGeometry.WINDOW_W
	for axis in [0, 1]:
		var run: float = floor_rect.size.x if axis == 0 else floor_rect.size.y
		var usable: float = run - margin * 2.0
		if usable <= HouseGeometry.WINDOW_W:
			continue
		var count: int = maxi(int(usable / KEEP_WINDOW_PITCH), 1)
		for k in range(count):
			var t: float = (float(k) + 0.5) / float(count)
			for side in [-1.0, 1.0]:
				var pos: Vector2
				var n: Vector2
				if axis == 0:
					pos = Vector2(lerpf(floor_rect.position.x + margin,
							floor_rect.end.x - margin, t),
						floor_rect.position.y if side < 0.0 else floor_rect.end.y)
					n = Vector2(0.0, side)
				else:
					pos = Vector2(
						floor_rect.position.x if side < 0.0 else floor_rect.end.x,
						lerpf(floor_rect.position.y + margin,
							floor_rect.end.y - margin, t))
					n = Vector2(side, 0.0)
				plan.windows.append({"room": level, "pos": pos, "normal": n,
					"width": HouseGeometry.WINDOW_W,
					"sill": HouseGeometry.WINDOW_SILL, "head": head,
					"storey": level})'''.split('\n')

lines[start:end] = body

ci = next(i for i, l in enumerate(lines) if l.startswith('const MAX_KEEP_SIDE'))
lines[ci + 1:ci + 1] = [
    '## How far apart a keep sets its windows along a wall.',
    'const KEEP_WINDOW_PITCH := 3.2',
]

io.open(p, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines))
print('written')
