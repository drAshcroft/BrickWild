import io

p = 'src/castle/castle_generator.gd'
s = io.open(p, encoding='utf-8').read()

old = '''static func _place_in_yard(yard: Rect2, taken: Array[Rect2], row: Dictionary,
		r: RandomNumberGenerator) -> Dictionary:'''
new = '''static func _place_in_yard(spec: CastleSpec, yard: Rect2, taken: Array[Rect2],
		row: Dictionary, r: RandomNumberGenerator) -> Dictionary:'''
assert old in s, 'sig'
s = s.replace(old, new)

old = '''		var placed: Dictionary = _place_in_yard(yard, taken, row, r)'''
new = '''		var placed: Dictionary = _place_in_yard(spec, yard, taken, row, r)'''
assert old in s, 'call'
s = s.replace(old, new)

old = '''	for side in ([-1.0, 1.0] if r.randf() < 0.5 else [1.0, -1.0]):
		var x: float = (yard.end.x - YARD_MARGIN - w / 2.0) if side > 0.0 \\
			else (yard.position.x + YARD_MARGIN + w / 2.0)
		var z: float = yard.position.y + YARD_MARGIN + l / 2.0
		while z + l / 2.0 <= yard.end.y - YARD_MARGIN:
			var rect := Rect2(Vector2(x - w / 2.0, z - l / 2.0), Vector2(w, l))
			if not _hits(rect.grow(clear), taken):
				# The front is local -Z; turned a quarter, it looks ACROSS the
				# yard rather than up it, which is the way a building beside a
				# courtyard faces.
				return {"business": row["business"], "rect": rect,
					"yaw": PI / 2.0 if side > 0.0 else -PI / 2.0}
			z += 0.5
	return {}'''
new = '''	for side in ([-1.0, 1.0] if r.randf() < 0.5 else [1.0, -1.0]):
		var z: float = yard.position.y + YARD_MARGIN + l / 2.0
		while z + l / 2.0 <= yard.end.y - YARD_MARGIN:
			# The ward wall is where the WALL is, not where the inscribed
			# rectangle stops: a polygonal enceinte slants in, and a building
			# set against the box clipped the curtain behind it.
			var edge: float = CastleGeometry.ward_edge_x(spec, side,
				z - l / 2.0, z + l / 2.0)
			var x: float = edge - side * (YARD_MARGIN + w / 2.0)
			var rect := Rect2(Vector2(x - w / 2.0, z - l / 2.0), Vector2(w, l))
			if yard.grow(0.01).encloses(rect) and not _hits(rect.grow(clear), taken):
				# The front is local -Z; turned a quarter, it looks ACROSS the
				# yard rather than up it, which is the way a building beside a
				# courtyard faces.
				return {"business": row["business"], "rect": rect,
					"yaw": PI / 2.0 if side > 0.0 else -PI / 2.0}
			z += 0.5
	return {}'''
assert old in s, 'loop'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('written')
