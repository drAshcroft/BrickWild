import io

p = 'src/house/house_furnisher.gd'
s = io.open(p, encoding='utf-8').read()

old = 'static var _mandatory := false'
new = '''static var _mandatory := false
## The outline of the room being furnished, when it has one that a rectangle
## cannot say (GEO-002). Carried here rather than threaded through seven
## placers, the same way `_mandatory` is: every one of them already tests
## `_fits`, and this is one more thing `_fits` has to be true of. Empty for a
## rectangular room, which is every room in a house.
static var _outline := PackedVector2Array()'''
assert old in s, 'mandatory'
s = s.replace(old, new, 1)

old = '''	var blocked: Array[Rect2] = _initial_blocked(plan, room)'''
new = '''	_outline = plan.outline_of(room) if plan.is_polygonal(room) \\
		else PackedVector2Array()
	var blocked: Array[Rect2] = _initial_blocked(plan, room)'''
assert old in s, 'furnish_room'
s = s.replace(old, new, 1)

old = '''	var rect: Rect2 = cand["rect"]
	if not floor_rect.grow(0.01).encloses(rect):
		return false'''
new = '''	var rect: Rect2 = cand["rect"]
	if not floor_rect.grow(0.01).encloses(rect):
		return false
	# A bounding box is not the room when the room is an octagon: every corner
	# of the piece has to be inside the outline as well, or the wardrobe ends
	# up half through the chamfer.
	if not _inside_outline(rect):
		return false'''
assert old in s, 'fits head'
s = s.replace(old, new, 1)

old = '''	var zone: Rect2 = cand["zone"]
	if zone.size.x > 0.0:
		# the zone may overlap another zone -- two people can share a gangway --
		# but it may not be inside a wall or under other furniture
		if not floor_rect.grow(0.02).encloses(zone):
			return false'''
new = '''	var zone: Rect2 = cand["zone"]
	if zone.size.x > 0.0:
		# the zone may overlap another zone -- two people can share a gangway --
		# but it may not be inside a wall or under other furniture
		if not floor_rect.grow(0.02).encloses(zone):
			return false
		if not _inside_outline(zone):
			return false'''
assert old in s, 'fits zone'
s = s.replace(old, new, 1)

old = '''static func _commit(plan: HousePlan, room: int, cand: Dictionary,
		blocked: Array[Rect2], zones: Array[Rect2]) -> void:'''
new = '''## Are all four corners of `rect` inside the room being furnished? True when
## the room is a plain rectangle -- the enclosing test above has said so
## already.
static func _inside_outline(rect: Rect2) -> bool:
	if _outline.size() < 3:
		return true
	for p in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]:
		if not Poly.contains_point(_outline, p, 0.01):
			return false
	return true


static func _commit(plan: HousePlan, room: int, cand: Dictionary,
		blocked: Array[Rect2], zones: Array[Rect2]) -> void:'''
assert old in s, 'commit'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('furnisher ok')

# ------------------------------------------------------------------ nav check
p = 'qa/house_nav_check.gd'
s = io.open(p, encoding='utf-8').read()

old = '''	for i in range(_plan.room_count()):
		var level := HousePlan.record_storey(_plan.rooms[i])
		if _grids.has(level):
			_grids[level].add_floor(HouseGeometry.room_floor_rect(_plan, i))'''
new = '''	for i in range(_plan.room_count()):
		var level := HousePlan.record_storey(_plan.rooms[i])
		if not _grids.has(level):
			continue
		# A room shaped by an outline is rasterised as that outline, not as the
		# box round it: the corners a chamfer cuts off are wall, and a walker
		# that stood in them would be standing outside the building (GEO-002).
		if _plan.is_polygonal(i):
			_grids[level].add_floor_poly(_plan.outline_of(i))
		else:
			_grids[level].add_floor(HouseGeometry.room_floor_rect(_plan, i))'''
assert old in s, 'rasterize'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('nav ok')
