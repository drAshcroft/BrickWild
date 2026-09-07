import io

# --------------------------------------------------------- furnish check
p = 'qa/house_furnish_check.gd'
s = io.open(p, encoding='utf-8').read()

old = '''## Distance from the back of a piece to the room wall behind it.
static func _back_gap(plan: HousePlan, p: Dictionary) -> float:
	var room_rect: Rect2 = HouseGeometry.room_floor_rect(plan, p["room"])
	var yaw: float = float(p["yaw"])
	var facing := Vector2(-sin(yaw), -cos(yaw))
	var back: Vector2 = -facing
	var rect: Rect2 = p["rect"]
	var c: Vector2 = rect.get_center()
	var half: Vector2 = rect.size / 2.0
	var edge: Vector2 = c + back * Vector2(absf(back.x) * half.x + absf(back.y) * half.y,
		absf(back.x) * half.x + absf(back.y) * half.y)
	if absf(back.x) > 0.5:
		var wall_x: float = room_rect.end.x if back.x > 0.0 else room_rect.position.x
		return absf(wall_x - edge.x)
	var wall_z: float = room_rect.end.y if back.y > 0.0 else room_rect.position.y
	return absf(wall_z - edge.y)'''
new = '''## Distance from the back of a piece to the room wall behind it.
##
## Measured against the room's OWN WALLS rather than against the box round
## them. For a rectangle the two are the same thing and the answer does not
## move; for an octagon the wall behind a cabinet is a diagonal, and measuring
## to the bounding box reported every piece in the room as standing a metre and
## a quarter off a wall it was flat against (GEO-002).
static func _back_gap(plan: HousePlan, p: Dictionary) -> float:
	var yaw: float = float(p["yaw"])
	var back := Vector2(sin(yaw), cos(yaw))          # the opposite of facing
	var rect: Rect2 = p["rect"]
	var half: Vector2 = rect.size / 2.0
	var reach: float = absf(back.x) * half.x + absf(back.y) * half.y
	var edge: Vector2 = rect.get_center() + back * reach
	var best := INF
	for w in HouseGeometry.room_walls(plan, int(p["room"])):
		var n: Vector2 = w["normal"]                 # points INTO the room
		if n.dot(back) > -0.5:
			continue                                 # not the wall behind it
		best = minf(best, absf((edge - Vector2(w["from"])).dot(n)))
	return best if is_finite(best) else 0.0'''
assert old in s, 'back_gap'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('furnish check ok')

# ------------------------------------------------------------ plan check
p = 'qa/house_plan_check.gd'
s = io.open(p, encoding='utf-8').read()

old = '''		var pos: Vector2 = w["pos"]
		var n: Vector2 = w["normal"]
		var on_wall: bool = (absf(n.x) > 0.5 and (absf(pos.x - inner.position.x) < TOL
				or absf(pos.x - inner.end.x) < TOL)) \\
			or (absf(n.y) > 0.5 and (absf(pos.y - inner.position.y) < TOL
				or absf(pos.y - inner.end.y) < TOL))
		if not on_wall:
			failures.append("window %d at %v is in a partition, not an outside wall"
				% [wi, pos])
			continue
		# and on the stretch of that wall its own room owns
		var rect: Rect2 = plan.rooms[w["room"]]["rect"]'''
new = '''		var pos: Vector2 = w["pos"]
		var n: Vector2 = w["normal"]
		# A shaped room's outside walls are its own edges, and a window on a
		# diagonal is on an outside wall even though it is nowhere near the
		# edge of the box round it (GEO-002).
		if plan.is_polygonal(int(w["room"])):
			if not _on_outline(plan.outline_of(int(w["room"])), pos):
				failures.append("window %d at %v is in a partition, not an outside wall"
					% [wi, pos])
			continue
		var on_wall: bool = (absf(n.x) > 0.5 and (absf(pos.x - inner.position.x) < TOL
				or absf(pos.x - inner.end.x) < TOL)) \\
			or (absf(n.y) > 0.5 and (absf(pos.y - inner.position.y) < TOL
				or absf(pos.y - inner.end.y) < TOL))
		if not on_wall:
			failures.append("window %d at %v is in a partition, not an outside wall"
				% [wi, pos])
			continue
		# and on the stretch of that wall its own room owns
		var rect: Rect2 = plan.rooms[w["room"]]["rect"]'''
assert old in s, 'window wall'
s = s.replace(old, new, 1)

old = '''## What is upstairs is not a copy of what is downstairs.'''
new = '''## Does `p` sit on an edge of this outline?
static func _on_outline(poly: PackedVector2Array, p: Vector2) -> bool:
	for k in range(poly.size()):
		var a: Vector2 = poly[k]
		var b: Vector2 = poly[(k + 1) % poly.size()]
		var d: Vector2 = b - a
		var len2: float = d.length_squared()
		if len2 < 1e-9:
			continue
		var t: float = clampf((p - a).dot(d) / len2, 0.0, 1.0)
		if (a + d * t).distance_to(p) < 0.05:
			return true
	return false


## What is upstairs is not a copy of what is downstairs.'''
assert old in s, 'helper'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('plan check ok')
