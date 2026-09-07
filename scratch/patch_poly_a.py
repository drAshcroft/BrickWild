import io

# ------------------------------------------------------------------ HousePlan
p = 'src/house/house_plan.gd'
s = io.open(p, encoding='utf-8').read()

old = '''## {"kind": StringName, "rect": Rect2, "storey": int}
var rooms: Array[Dictionary] = []'''
new = '''## {"kind": StringName, "rect": Rect2, "storey": int,
##  "outline": PackedVector2Array (optional)}
##
## `outline` is the TRUTH about a room's shape when it is there, and `rect`
## stays as its bounding box so every rectangle-shaped rule still has something
## to measure. A room WITHOUT one is the four-sided case, which is every room
## in every house: the outline exists for the shapes a rectangle cannot say --
## a round tower, an octagonal chapter house, a pagoda (GEO-002).
##
## An outline is the CLEAR FLOOR, not a partition centre-line. A rectangular
## room is cut out of the interior and shares half of each partition with its
## neighbour; a polygonal room is not produced by cutting, so there is no
## shared partition to give half of, and what you draw is what you walk on.
var rooms: Array[Dictionary] = []'''
assert old in s, 'rooms doc'
s = s.replace(old, new, 1)

old = '''func kind_of(i: int) -> StringName:
	return rooms[i]["kind"]'''
new = '''func kind_of(i: int) -> StringName:
	return rooms[i]["kind"]


## The room's shape in plan. A room with no `outline` is its rectangle, so
## every caller can ask for a polygon and never test for one.
func outline_of(i: int) -> PackedVector2Array:
	return room_outline(rooms[i])


## The same, for a room record that is not in a plan yet.
static func room_outline(room: Dictionary) -> PackedVector2Array:
	var o = room.get("outline")
	if o != null and (o as PackedVector2Array).size() >= 3:
		return o
	return Poly.from_rect(room["rect"])


## Is this room something a rectangle cannot describe?
func is_polygonal(i: int) -> bool:
	var o = rooms[i].get("outline")
	return o != null and (o as PackedVector2Array).size() >= 3'''
assert old in s, 'kind_of'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('plan ok')

# --------------------------------------------------------------- HouseGeometry
p = 'src/house/house_geometry.gd'
s = io.open(p, encoding='utf-8').read()

old = '''## The four walls of a room's clear floor, as
## {"from": Vector2, "to": Vector2, "normal": Vector2} with `normal` pointing
## INTO the room. This is what a piece of furniture puts its back against.
static func room_walls(plan: HousePlan, i: int) -> Array[Dictionary]:
	var f: Rect2 = room_floor_rect(plan, i)
	return ['''
new = '''## The walls of a room's clear floor, as
## {"from": Vector2, "to": Vector2, "normal": Vector2} with `normal` pointing
## INTO the room. This is what a piece of furniture puts its back against.
##
## Four of them for a rectangular room, in the order every table in this
## project indexes by -- front, back, left, right -- and ONE PER EDGE for a
## room that carries an outline (GEO-002). The four-sided order is a labelling,
## not a traversal, which is why the two paths are written out separately: a
## hearth on "wall 2" means the left wall, and it has to keep meaning that.
static func room_walls(plan: HousePlan, i: int) -> Array[Dictionary]:
	if plan.is_polygonal(i):
		return polygon_walls(plan.outline_of(i))
	var f: Rect2 = room_floor_rect(plan, i)
	return ['''
assert old in s, 'room_walls'
s = s.replace(old, new, 1)

old = '''static func room_area(plan: HousePlan, i: int) -> float:
	var f: Rect2 = room_floor_rect(plan, i)
	return f.size.x * f.size.y'''
new = '''## One wall per edge of an outline, wound so `normal` points into the polygon.
static func polygon_walls(poly: PackedVector2Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n: int = poly.size()
	if n < 3:
		return out
	# The inward normal of an edge depends on which way round the outline is
	# wound, and callers should not have to know or care which that was.
	var turn: float = 1.0 if Poly.signed_area(poly) > 0.0 else -1.0
	for k in range(n):
		var a: Vector2 = poly[k]
		var b: Vector2 = poly[(k + 1) % n]
		var d: Vector2 = b - a
		if d.length() < 0.001:
			continue
		d = d.normalized()
		out.append({"from": a, "to": b,
			"normal": Vector2(-d.y, d.x) * turn})
	return out


## The clear floor of a room as a polygon: its outline, or its floor rectangle
## when it has none. What furniture has to stay inside and what the walk grid
## rasterises.
static func room_floor_poly(plan: HousePlan, i: int) -> PackedVector2Array:
	if plan.is_polygonal(i):
		return plan.outline_of(i)
	return Poly.from_rect(room_floor_rect(plan, i))


static func room_area(plan: HousePlan, i: int) -> float:
	if plan.is_polygonal(i):
		return Poly.area(plan.outline_of(i))
	var f: Rect2 = room_floor_rect(plan, i)
	return f.size.x * f.size.y'''
assert old in s, 'room_area'
s = s.replace(old, new, 1)

old = '''static func room_floor_rect(plan: HousePlan, i: int) -> Rect2:
	var rect: Rect2 = plan.rooms[i]["rect"]'''
new = '''static func room_floor_rect(plan: HousePlan, i: int) -> Rect2:
	# An outline is the clear floor already: there is no partition to give half
	# of, so the floor rectangle is simply what the outline spans.
	if plan.is_polygonal(i):
		return Poly.bounding_rect(plan.outline_of(i))
	var rect: Rect2 = plan.rooms[i]["rect"]'''
assert old in s, 'room_floor_rect'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('geometry ok')
