import io

# ------------------------------------------------------------------ nav check
p = 'qa/house_nav_check.gd'
s = io.open(p, encoding='utf-8').read()

old = '''	for d in _plan.doors:
		var level := HousePlan.record_storey(d)
		if _grids.has(level):
			_grids[level].add_floor(_door_gap(d))'''
new = '''	# A court is FLOOR. You walk out of the hall into the yard and across it to
	# the kitchen door, and a walk that stopped at the threshold would report
	# every range round a courtyard as unreachable (GEO-003).
	for level2 in _levels():
		if not _grids.has(level2):
			continue
		for ci in _plan.courts_on(level2):
			if _plan.courts[ci].has("outline"):
				_grids[level2].add_floor_poly(_plan.court_outline(ci))
			else:
				_grids[level2].add_floor(Rect2(_plan.courts[ci]["rect"]))
	for d in _plan.doors:
		var level := HousePlan.record_storey(d)
		if _grids.has(level):
			_grids[level].add_floor(_door_gap(d))'''
assert old in s, 'nav courts'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('nav ok')

# ------------------------------------------------------- daylight / entrance
p = 'qa/house_plan_check.gd'
s = io.open(p, encoding='utf-8').read()

old = '''		var pos: Vector2 = w["pos"]
		var n: Vector2 = w["normal"]
		# A shaped room's outside walls are its own edges, and a window on a'''
new = '''		var pos: Vector2 = w["pos"]
		var n: Vector2 = w["normal"]
		# A window onto a COURT is a window: the court is open to the sky, so
		# the wall it is cut into is an outside wall however far inside the
		# footprint it stands (GEO-003).
		if _onto_court(plan, pos, n):
			continue
		# A shaped room's outside walls are its own edges, and a window on a'''
assert old in s, 'window court'
s = s.replace(old, new, 1)

old = '''		# an exterior door has to be ON an exterior wall
		var pos: Vector2 = d["pos"]
		var n: Vector2 = d["normal"]'''
new = '''		# a door onto the yard is an exterior door standing well inside the
		# footprint, and it is not the street door
		var pos: Vector2 = d["pos"]
		var n: Vector2 = d["normal"]
		if _onto_court(plan, pos, n):
			if d.get("front", false):
				failures.append("way in: the front door opens onto a court, not the street")
			continue'''
assert old in s, 'entrance court'
s = s.replace(old, new, 1)

old = '''## Does `p` sit on an edge of this outline?'''
new = '''## Does an opening at `pos`, facing `n`, look into a court?
##
## The step OUT of the wall is what decides it: a window's normal points out of
## the room it lights, so a pace that way lands in the yard when the yard is
## what it looks at.
static func _onto_court(plan: HousePlan, pos: Vector2, n: Vector2) -> bool:
	var outside: Vector2 = pos + n * (HouseGeometry.WALL_T + 0.05)
	for ci in range(plan.courts.size()):
		if Poly.contains_point(plan.court_outline(ci), outside, 0.01):
			return true
	return false


## Does `p` sit on an edge of this outline?'''
assert old in s, 'court helper'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('plan check ok')
