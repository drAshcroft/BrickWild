import io

p = 'src/castle/castle_generator.gd'
s = io.open(p, encoding='utf-8').read()

old = '''static func _keep_windows(plan: HousePlan, floor_rect: Rect2, level: int,
		hs: KeepSpec) -> void:'''
new = '''static func _keep_windows(plan: HousePlan, floor_rect: Rect2, level: int,
		hs: KeepSpec, blind_wall := -1) -> void:'''
assert old in s, 'signature'
s = s.replace(old, new)

old = '''		var count: int = maxi(int(usable / KEEP_WINDOW_PITCH), 1)
		for k in range(count):
			var t: float = (float(k) + 0.5) / float(count)
			for side in [-1.0, 1.0]:'''
new = '''		var count: int = maxi(int(usable / KEEP_WINDOW_PITCH), 1)
		for k in range(count):
			var t: float = (float(k) + 0.5) / float(count)
			for side in [-1.0, 1.0]:
				# HouseGeometry.room_walls order: front, back, left, right
				var wall: int = (0 if side < 0.0 else 1) if axis == 0 \\
					else (2 if side < 0.0 else 3)
				if wall == blind_wall:
					continue'''
assert old in s, 'loop'
s = s.replace(old, new)

old = '''	for level2 in range(1, levels):
		if not HouseGeometry.is_habitable(hs.kind_on(level2)):
			continue
		_keep_windows(plan, floor_rect, level2, hs)'''
new = '''	for level2 in range(1, levels):
		if not HouseGeometry.is_habitable(hs.kind_on(level2)):
			continue
		# The lord's chamber keeps ONE WALL BLIND, the one facing the fire.
		# That is where the bed goes, and a bed wants solid wall over its head:
		# windows down all four sides left every keep in the sweep with its
		# lord sleeping under one, which the feng shui rule reports every time
		# and is right to.
		var blind: int = 3 if hs.kind_on(level2) == &"lords_chamber" else -1
		_keep_windows(plan, floor_rect, level2, hs, blind)'''
assert old in s, 'call'
s = s.replace(old, new)

io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('written')
