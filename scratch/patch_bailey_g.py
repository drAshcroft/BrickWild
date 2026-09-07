import io

p = 'src/castle/castle_generator.gd'
s = io.open(p, encoding='utf-8').read()

old = '''		while z + l / 2.0 <= yard.end.y - YARD_MARGIN:
			# The ward wall is where the WALL is, not where the inscribed
			# rectangle stops: a polygonal enceinte slants in, and a building
			# set against the box clipped the curtain behind it.
			var edge: float = CastleGeometry.ward_edge_x(spec, side,
				z - l / 2.0, z + l / 2.0)
			var x: float = edge - side * (YARD_MARGIN + w / 2.0)
			var rect := Rect2(Vector2(x - w / 2.0, z - l / 2.0), Vector2(w, l))
			if yard.grow(0.01).encloses(rect) and not _hits(rect.grow(clear), taken):'''
new = '''		while z + l / 2.0 <= yard.end.y - YARD_MARGIN:
			var x: float = (yard.end.x - YARD_MARGIN - w / 2.0) if side > 0.0 \\
				else (yard.position.x + YARD_MARGIN + w / 2.0)
			var rect := Rect2(Vector2(x - w / 2.0, z - l / 2.0), Vector2(w, l))
			if not _hits(rect.grow(clear), taken):'''
assert old in s, 'loop'
s = s.replace(old, new)

old = '''	var yard: Rect2 = CastleGeometry.bailey_rect(spec)
	if yard.size.x < 6.0 or yard.size.y < 6.0:
		return out'''
new = '''	var yard: Rect2 = _yard_rect(spec)
	if yard.size.x < 6.0 or yard.size.y < 6.0:
		return out'''
assert old in s, 'yard call a'
s = s.replace(old, new)

old = '''	var yard: Rect2 = CastleGeometry.bailey_rect(spec)
	var taken: Array[Rect2] = CastleGeometry.bailey_obstacles(spec)
	taken.append(CastleGeometry.gate_axis_strip(spec))
	for b in bailey_buildings(spec):'''
new = '''	var yard: Rect2 = _yard_rect(spec)
	var taken: Array[Rect2] = CastleGeometry.bailey_obstacles(spec)
	taken.append(CastleGeometry.gate_axis_strip(spec))
	for b in bailey_buildings(spec):'''
assert old in s, 'yard call b'
s = s.replace(old, new)

old = '''## The well: in the open yard, clear of everything built and off the way in.'''
new = '''## The ground a yard building may stand on.
##
## `bailey_rect` is the largest rectangle inside the ward, which is where a
## RANGE goes -- built against the wall on purpose. A free-standing building
## has to keep off the wall instead, and on a polygonal enceinte the curtain
## slants inside that rectangle by its own thickness, so the box is pulled in
## by a wall before anything is measured against it.
static func _yard_rect(spec: CastleSpec) -> Rect2:
	var yard: Rect2 = CastleGeometry.bailey_rect(spec)
	if CastleGeometry.is_polygonal(spec):
		var r: int = CastleGeometry.inner_ring(spec)
		yard = yard.grow(-CastleGeometry.wall_thickness(spec, r))
	return yard


## The well: in the open yard, clear of everything built and off the way in.'''
assert old in s, 'well anchor'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('written')
