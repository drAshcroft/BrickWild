class_name HouseNavCheck
extends RefCounted
## Can a person actually walk through this house and use what is in it?
##
## Everything above this file argues from rectangles. This one puts a body in
## the building: it rasterizes the floor at 12 cm, blocks out the walls and the
## furniture, shrinks the free floor by a person's own half-width, and then
## walks -- from the doorstep, through the doors, into every room, and up to
## every piece of furniture somebody is meant to use.
##
##   REACH ROOMS  every room can be entered from the front door
##   REACH DOORS  both sides of every door are standable
##   REACH USE    the side of the bed, the pull-back space behind each chair,
##                the floor in front of the hearth -- all of them walkable and
##                all of them connected to the rest of the house
##   WIDTH        the route into each room is at least PATH_MIN wide, so a
##                house cannot pass by leaving a 20 cm gap between a barrel and
##                a wall
##   ISLANDS      no stranded pocket of floor big enough to stand in
##
## Erosion is what makes this honest. Testing bare cells would let a person
## walk through a 5 cm crack between two crates; testing cells that have a
## person's radius of clear floor around them will not.

## A stranded pocket smaller than this is a corner behind a barrel, not a room.
const ISLAND_MIN_AREA := 0.6
## How far into a room a person has to get before they count as being in it,
## rather than standing in its doorway.
const DOORWAY_LIP := 0.3

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}

var _plan: HousePlan
var _origin := Vector2.ZERO
var _nx := 0
var _nz := 0
var _cell: float = HouseGeometry.NAV_CELL
var _free: PackedByteArray = PackedByteArray()      # floor, before the body
var _walk: PackedByteArray = PackedByteArray()      # floor a person fits on
var _seen: PackedByteArray = PackedByteArray()      # reached from the doorstep

## Which rooms could not be walked to, and which pieces of furniture could not
## be reached. The furnisher reads these to thin a room out until it works, so
## they are part of the report rather than prose buried in a failure string.
var unreached_rooms: Array[int] = []
var unreachable_items: Array[int] = []


func check(plan: HousePlan) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	unreached_rooms.clear()
	unreachable_items.clear()
	_plan = plan

	_rasterize()
	_erode()
	var start: Vector2i = _start_cell()
	if start.x < 0:
		failures.append("nav: there is nowhere to stand inside the front door")
		return _report()
	_flood(start)

	_check_rooms()
	_check_doors()
	_check_use_zones()
	_check_islands()
	return _report()


func _report() -> Dictionary:
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats, "unreached_rooms": unreached_rooms,
		"unreachable_items": unreachable_items}


# -------------------------------------------------------------- rasterize

## Free floor is: inside some room, or inside a doorway. Then the furniture is
## subtracted. Building it this way round means a partition is blocked because
## it belongs to no room, which is exactly what a wall is.
func _rasterize() -> void:
	var inner: Rect2 = HouseGeometry.interior_rect(_plan.spec).grow(HouseGeometry.WALL_T)
	_origin = inner.position
	_nx = int(ceil(inner.size.x / _cell)) + 1
	_nz = int(ceil(inner.size.y / _cell)) + 1
	_free.resize(_nx * _nz)
	for i in range(_free.size()):
		_free[i] = 0

	for i in range(_plan.room_count()):
		_fill_rect(HouseGeometry.room_floor_rect(_plan, i), 1)
	for d in _plan.doors:
		_fill_rect(_door_gap(d), 1)
	for p in _plan.furniture:
		if p.get("mounted", false) or p["host"] >= 0:
			continue
		if not PropCatalog.blocks_floor(p["key"]):
			continue
		_fill_rect(p["rect"], 0)
	stats["free_cells"] = _count(_free)


## The hole a door makes: its width, right through the wall it is cut into.
static func _door_gap(d: Dictionary) -> Rect2:
	var n: Vector2 = d["normal"]
	var along := Vector2(n.y, -n.x).abs()
	var c: Vector2 = d["pos"]
	var half: Vector2 = along * (float(d["width"]) / 2.0)
	var deep: Vector2 = n.abs() * (HouseGeometry.WALL_T * 0.6 + 0.1)
	var a: Vector2 = c - half - deep
	var b: Vector2 = c + half + deep
	return Rect2(a.min(b), (b - a).abs())


func _fill_rect(rect: Rect2, value: int) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var x0: int = clampi(int(floor((rect.position.x - _origin.x) / _cell)), 0, _nx - 1)
	var x1: int = clampi(int(ceil((rect.end.x - _origin.x) / _cell)), 0, _nx - 1)
	var z0: int = clampi(int(floor((rect.position.y - _origin.y) / _cell)), 0, _nz - 1)
	var z1: int = clampi(int(ceil((rect.end.y - _origin.y) / _cell)), 0, _nz - 1)
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			# a cell counts as covered when its centre is inside the rectangle
			var c: Vector2 = _world_of(x, z)
			if rect.has_point(c):
				_free[x * _nz + z] = value


## Shrink the free floor by a person's half-width. What survives is where a
## person can actually stand, which is the only floor worth flood filling.
##
## Done with a two-pass chamfer distance transform rather than by testing a
## disc of cells around every cell. The disc is the obvious way and it is 25
## times the work; with the furnisher calling this check dozens of times per
## house to test what would happen if it moved something, the obvious way made
## generating a house take longer than everything else in the project put
## together.
func _erode() -> void:
	var n: int = _free.size()
	_walk.resize(n)
	# distance to the nearest blocked cell, in cell units, scaled by 10 so the
	# diagonal step (14/10 ~ sqrt 2) stays in integers
	var dist := PackedInt32Array()
	dist.resize(n)
	var far: int = 1 << 20
	for i in range(n):
		dist[i] = far if _free[i] == 1 else 0
	# forward pass: up-left neighbours
	for x in range(_nx):
		for z in range(_nz):
			var i2: int = x * _nz + z
			if dist[i2] == 0:
				continue
			var best: int = dist[i2]
			best = mini(best, _dist_at(dist, x - 1, z, far) + 10)
			best = mini(best, _dist_at(dist, x, z - 1, far) + 10)
			best = mini(best, _dist_at(dist, x - 1, z - 1, far) + 14)
			best = mini(best, _dist_at(dist, x + 1, z - 1, far) + 14)
			dist[i2] = best
	# backward pass: down-right neighbours
	for x in range(_nx - 1, -1, -1):
		for z in range(_nz - 1, -1, -1):
			var i3: int = x * _nz + z
			if dist[i3] == 0:
				continue
			var best2: int = dist[i3]
			best2 = mini(best2, _dist_at(dist, x + 1, z, far) + 10)
			best2 = mini(best2, _dist_at(dist, x, z + 1, far) + 10)
			best2 = mini(best2, _dist_at(dist, x + 1, z + 1, far) + 14)
			best2 = mini(best2, _dist_at(dist, x - 1, z + 1, far) + 14)
			dist[i3] = best2
	# a cell is standable when the nearest wall is at least a person's radius
	# away. The distance is to the nearest blocked CELL CENTRE, so half a cell
	# is added back: the blocked material starts half a cell further out.
	var need: int = int(round((HouseGeometry.PERSON_RADIUS / _cell + 0.5) * 10.0))
	for i4 in range(n):
		_walk[i4] = 1 if dist[i4] >= need else 0
	stats["walkable_cells"] = _count(_walk)


func _dist_at(dist: PackedInt32Array, x: int, z: int, far: int) -> int:
	if x < 0 or x >= _nx or z < 0 or z >= _nz:
		return 0        # outside the grid is solid
	return dist[x * _nz + z]


func _at(grid: PackedByteArray, x: int, z: int) -> int:
	if x < 0 or x >= _nx or z < 0 or z >= _nz:
		return 0
	return grid[x * _nz + z]


func _world_of(x: int, z: int) -> Vector2:
	return _origin + Vector2(x + 0.5, z + 0.5) * _cell


func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int((p.x - _origin.x) / _cell), int((p.y - _origin.y) / _cell))


static func _count(grid: PackedByteArray) -> int:
	var n := 0
	for b in grid:
		if b == 1:
			n += 1
	return n


# ------------------------------------------------------------------ walk

## Somewhere to stand just inside the front door.
func _start_cell() -> Vector2i:
	var d: int = _plan.entrance()
	if d < 0:
		return Vector2i(-1, -1)
	var door: Dictionary = _plan.doors[d]
	for step in range(1, 10):
		var p: Vector2 = Vector2(door["pos"]) - Vector2(door["normal"]) * (_cell * step)
		var c: Vector2i = _cell_of(p)
		if _at(_walk, c.x, c.y) == 1:
			return c
	return Vector2i(-1, -1)


func _flood(start: Vector2i) -> void:
	_seen.resize(_walk.size())
	for i in range(_seen.size()):
		_seen[i] = 0
	var stack: Array[Vector2i] = [start]
	_seen[start.x * _nz + start.y] = 1
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if n.x < 0 or n.x >= _nx or n.y < 0 or n.y >= _nz:
				continue
			var idx: int = n.x * _nz + n.y
			if _seen[idx] == 1 or _walk[idx] == 0:
				continue
			_seen[idx] = 1
			stack.append(n)
	stats["reached_cells"] = _count(_seen)


## Any cell inside `rect` (grown a little, since a person stands NEXT to a
## thing rather than on it) that was reached from the doorstep.
func _reached_in(rect: Rect2, grow := 0.0) -> bool:
	var r: Rect2 = rect.grow(grow)
	var x0: int = clampi(int(floor((r.position.x - _origin.x) / _cell)), 0, _nx - 1)
	var x1: int = clampi(int(ceil((r.end.x - _origin.x) / _cell)), 0, _nx - 1)
	var z0: int = clampi(int(floor((r.position.y - _origin.y) / _cell)), 0, _nz - 1)
	var z1: int = clampi(int(ceil((r.end.y - _origin.y) / _cell)), 0, _nz - 1)
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			if _at(_seen, x, z) == 1 and r.has_point(_world_of(x, z)):
				return true
	return false


## An ASCII picture of what the walker saw: '#' blocked, '.' free but too
## tight to stand in, ':' standable, ' ' reached. Kept because reading a
## reachability failure off a list of room numbers is guesswork, and reading it
## off the map takes a second.
func ascii_map() -> String:
	var doors := {}
	for d in range(_plan.doors.size()):
		var c: Vector2i = _cell_of(Vector2(_plan.doors[d]["pos"]))
		doors[c] = d
	var out := ""
	for z in range(_nz):
		var line := ""
		for x in range(_nx):
			if doors.has(Vector2i(x, z)):
				line += str(doors[Vector2i(x, z)])
				continue
			if _at(_free, x, z) == 0:
				line += "#"
			elif _at(_seen, x, z) == 1:
				line += " "
			elif _at(_walk, x, z) == 1:
				line += ":"
			else:
				line += "."
		out += line + "
"
	return out


## free / walkable / reached at a world point, for diagnosing a failure.
func probe(p: Vector2) -> String:
	var c: Vector2i = _cell_of(p)
	return "%s free=%d walk=%d seen=%d" % [p, _at(_free, c.x, c.y),
		_at(_walk, c.x, c.y), _at(_seen, c.x, c.y)]


# ---------------------------------------------------------------- checks

## The room proper, without the lip of floor its own doorways stand on.
##
## A doorway is inside the room it opens into, so a person standing IN the door
## counts as being in the room -- which let a room whose every last inch was
## blocked by a table against the door report itself as reached. Pulling the
## rectangle in by a stride fixes that: you have to be able to get INTO the
## room, not merely as far as its threshold.
func _room_body(i: int) -> Rect2:
	var f: Rect2 = HouseGeometry.room_floor_rect(_plan, i)
	var shrunk: Rect2 = f.grow(-DOORWAY_LIP)
	return shrunk if shrunk.size.x > 0.3 and shrunk.size.y > 0.3 else f


func _check_rooms() -> void:
	var reached := 0
	for i in range(_plan.room_count()):
		var f: Rect2 = _room_body(i)
		if _reached_in(f):
			reached += 1
			continue
		# say WHY: no standable floor at all, or standable but cut off
		var standable := false
		var x0: int = clampi(int((f.position.x - _origin.x) / _cell), 0, _nx - 1)
		var x1: int = clampi(int((f.end.x - _origin.x) / _cell), 0, _nx - 1)
		var z0: int = clampi(int((f.position.y - _origin.y) / _cell), 0, _nz - 1)
		var z1: int = clampi(int((f.end.y - _origin.y) / _cell), 0, _nz - 1)
		for x in range(x0, x1 + 1):
			for z in range(z0, z1 + 1):
				if _at(_walk, x, z) == 1:
					standable = true
					break
			if standable:
				break
		unreached_rooms.append(i)
		if standable:
			failures.append("nav: room %d (%s) has floor to stand on but no way to walk to it"
				% [i, String(_plan.kind_of(i))])
		else:
			failures.append("nav: room %d (%s) is so full there is nowhere to stand"
				% [i, String(_plan.kind_of(i))])
	stats["rooms_walkable"] = reached


func _check_doors() -> void:
	for d in range(_plan.doors.size()):
		var door: Dictionary = _plan.doors[d]
		var sides: Array = [-1.0, 1.0] if not door["exterior"] else [-1.0]
		for side in sides:
			var t: Vector2 = HouseGeometry.door_threshold(door, side)
			if not _reached_in(Rect2(t - Vector2.ONE * 0.05, Vector2.ONE * 0.1),
					HouseGeometry.PERSON_RADIUS):
				failures.append("nav: door %d cannot be used from its %s side"
					% [d, "inner" if side < 0.0 else "outer"])
		# and the doorway itself has to be wide enough to be a doorway
		if float(door["width"]) < HouseGeometry.PATH_MIN:
			failures.append("nav: door %d is only %.2fm wide"
				% [d, float(door["width"])])


## Every piece of furniture a person is meant to use has to be reachable at
## the place they would use it from.
func _check_use_zones() -> void:
	var checked := 0
	var reached := 0
	for f in range(_plan.furniture.size()):
		var p: Dictionary = _plan.furniture[f]
		if p.get("mounted", false) or p["host"] >= 0:
			continue
		var zone: Rect2 = p["zone"]
		if zone.size.x <= 0.0:
			continue
		checked += 1
		if _reached_in(zone, HouseGeometry.PERSON_RADIUS * 0.5):
			reached += 1
		else:
			unreachable_items.append(f)
			failures.append("nav: nobody can reach the %s in room %d (%s) to use it"
				% [p["key"], p["room"], String(_plan.kind_of(p["room"]))])
	stats["use_zones"] = checked
	stats["use_zones_reached"] = reached


## Floor a person can stand on, but cannot walk to. A pocket behind a table is
## a warning; a whole corner of a room is a failure, and _check_rooms will have
## said so already.
func _check_islands() -> void:
	var island_cells := 0
	for x in range(_nx):
		for z in range(_nz):
			if _at(_walk, x, z) == 1 and _at(_seen, x, z) == 0:
				island_cells += 1
	var area: float = float(island_cells) * _cell * _cell
	stats["stranded_area"] = snappedf(area, 0.01)
	if area > ISLAND_MIN_AREA:
		warnings.append("nav: %.1f m2 of floor is walkable but cut off from the rest of the house"
			% area)
