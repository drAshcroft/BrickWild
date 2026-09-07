import io

# ------------------------------------------------------------- geometry
p = 'src/house/house_geometry.gd'
s = io.open(p, encoding='utf-8').read()

old = '''## Is this plan-space line (on a room's edge) an exterior wall?'''
new = '''## The wall centre-lines of a shell that is not a rectangle (GEO-002).
##
## Same shape of answer as `exterior_runs`, so the builder does not care which
## it got: from, to, an OUTWARD normal and a side name. The outline is the
## clear floor, so the centre-line is the outline pushed out by half a wall --
## exactly what `exterior_runs` does to the site rectangle.
static func polygon_runs(outline: PackedVector2Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if outline.size() < 3:
		return out
	var centre: PackedVector2Array = Poly.offset(outline, WALL_T / 2.0)
	if centre.size() < 3:
		centre = outline
	var turn: float = 1.0 if Poly.signed_area(centre) > 0.0 else -1.0
	for k in range(centre.size()):
		var a: Vector2 = centre[k]
		var b: Vector2 = centre[(k + 1) % centre.size()]
		var d: Vector2 = b - a
		if d.length() < 0.001:
			continue
		d = d.normalized()
		out.append({"from": a, "to": b,
			"normal": -Vector2(-d.y, d.x) * turn, "side": StringName("e%d" % k)})
	return out


## The shell runs for one storey of a plan: the polygon's edges when the storey
## is shaped, the site rectangle's four sides when it is not.
static func shell_runs(plan: HousePlan, level: int) -> Array[Dictionary]:
	for i in range(plan.room_count()):
		if HousePlan.record_storey(plan.rooms[i]) == level and plan.is_polygonal(i):
			return polygon_runs(plan.outline_of(i))
	return exterior_runs(plan.spec)


## Does any room of this plan carry an outline?
static func is_shaped(plan: HousePlan) -> bool:
	for i in range(plan.room_count()):
		if plan.is_polygonal(i):
			return true
	return false


## Is this plan-space line (on a room's edge) an exterior wall?'''
assert old in s, 'anchor'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('geometry ok')

# -------------------------------------------------------------- builder
p = 'src/house/house_builder.gd'
s = io.open(p, encoding='utf-8').read()

# walls: use the storey's own shell runs
old = '''		for run in HouseGeometry.exterior_runs(spec):
			var from: Vector2 = run["from"]
			var to: Vector2 = run["to"]
			var normal: Vector2 = run["normal"]
			var openings: Array[Dictionary] = _openings_on(from, to, normal, level)'''
new = '''		for run in HouseGeometry.shell_runs(plan, level):
			var from: Vector2 = run["from"]
			var to: Vector2 = run["to"]
			var normal: Vector2 = run["normal"]
			var openings: Array[Dictionary] = _openings_on(from, to, normal, level)'''
assert old in s, 'walls'
s = s.replace(old, new, 1)

# floor: a shaped storey gets a slab through its outline
old = '''		var opening := _stair_opening(level)
		if opening.size.x > 0.01 and opening.size.y > 0.01:
			_emit_floor_around(r, opening, y0, t, level)
		else:'''
new = '''		var shaped: int = _shaped_room(level)
		if shaped >= 0:
			# The floor of a shaped storey is the shape, pushed out to the
			# middle of its own wall so the slab and the masonry meet.
			var poly: PackedVector2Array = Poly.offset(plan.outline_of(shaped),
				HouseGeometry.WALL_T / 2.0)
			_kit.slab_poly(_lift(poly, y0 + t / 2.0), t, SURF_FLOOR)
			_log_mass("floor" if _levels().size() == 1 else "floor_%d" % level,
				AABB(Vector3(a.position.x, y0, a.position.z), a.size), y0)
			continue
		var opening := _stair_opening(level)
		if opening.size.x > 0.01 and opening.size.y > 0.01:
			_emit_floor_around(r, opening, y0, t, level)
		else:'''
assert old in s, 'floor'
s = s.replace(old, new, 1)

old = '''func _storeys() -> int:'''
new = '''## The shaped room on `level`, or -1 when that storey is rectangular.
func _shaped_room(level: int) -> int:
	for i in range(plan.room_count()):
		if HousePlan.record_storey(plan.rooms[i]) == level and plan.is_polygonal(i):
			return i
	return -1


## A plan polygon lifted to a height, for the slab emitters.
static func _lift(poly: PackedVector2Array, y: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in poly:
		out.append(Vector3(p.x, y, p.y))
	return out


func _storeys() -> int:'''
assert old in s, 'storeys'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('builder ok')
