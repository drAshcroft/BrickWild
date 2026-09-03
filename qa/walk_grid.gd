class_name WalkGrid
extends RefCounted
## Where a body can stand, and where it can get to.
##
## The floor is rasterized at a few centimetres, the walls and the furniture
## are cut out of it, and what is left is shrunk by a person's own half-width.
## Only what survives that is walkable: testing bare cells would let somebody
## through a 5 cm crack between two crates, and testing cells that have a
## person's radius of clear floor around them will not.
##
## Extracted from HouseNavCheck, which was the only place it existed, so the
## temple checks can put the same body in a different building. It knows
## nothing about rooms or altars -- it takes rectangles of floor, rectangles of
## obstruction, and a point to start walking from.

var origin := Vector2.ZERO
var nx := 0
var nz := 0
var cell := 0.12

var _free: PackedByteArray = PackedByteArray()   # floor, before the body
var _walk: PackedByteArray = PackedByteArray()   # floor a person fits on
var _seen: PackedByteArray = PackedByteArray()   # reached from the start


## Start a grid covering `bounds`. Everything is blocked until floor is added.
func setup(bounds: Rect2, cell_size := 0.12) -> void:
	cell = cell_size
	origin = bounds.position
	nx = int(ceil(bounds.size.x / cell)) + 1
	nz = int(ceil(bounds.size.y / cell)) + 1
	_free.resize(nx * nz)
	_walk.resize(nx * nz)
	_seen.resize(nx * nz)
	for i in range(_free.size()):
		_free[i] = 0
		_walk[i] = 0
		_seen[i] = 0


func add_floor(rect: Rect2) -> void:
	_fill(rect, 1)


func add_obstacle(rect: Rect2) -> void:
	_fill(rect, 0)


## Same as add_floor(Rect2), but for any polygon -- a round tower or an
## octagonal chapter house rasterises through here (GEO-001). One scanline
## loop over the polygon's bounding box, same shape as _fill: a cell counts
## as covered when its centre is inside the polygon.
func add_floor_poly(poly: PackedVector2Array) -> void:
	_fill_poly(poly, 1)


func add_obstacle_poly(poly: PackedVector2Array) -> void:
	_fill_poly(poly, 0)


## Shrink the free floor by `radius`, in one two-pass chamfer distance
## transform rather than by testing a disc of cells around every cell -- the
## disc is the obvious way and 25 times the work, which matters when a
## generator calls this dozens of times per building to test what would happen
## if it moved something.
func build(radius: float) -> void:
	var n: int = _free.size()
	var dist := PackedInt32Array()
	dist.resize(n)
	var far: int = 1 << 20
	for i in range(n):
		dist[i] = far if _free[i] == 1 else 0
	# distances are scaled by 10 so the diagonal step (14/10 ~ sqrt 2) is an int
	for x in range(nx):
		for z in range(nz):
			var i2: int = x * nz + z
			if dist[i2] == 0:
				continue
			var best: int = dist[i2]
			best = mini(best, _dist_at(dist, x - 1, z) + 10)
			best = mini(best, _dist_at(dist, x, z - 1) + 10)
			best = mini(best, _dist_at(dist, x - 1, z - 1) + 14)
			best = mini(best, _dist_at(dist, x + 1, z - 1) + 14)
			dist[i2] = best
	for x2 in range(nx - 1, -1, -1):
		for z2 in range(nz - 1, -1, -1):
			var i3: int = x2 * nz + z2
			if dist[i3] == 0:
				continue
			var best2: int = dist[i3]
			best2 = mini(best2, _dist_at(dist, x2 + 1, z2) + 10)
			best2 = mini(best2, _dist_at(dist, x2, z2 + 1) + 10)
			best2 = mini(best2, _dist_at(dist, x2 + 1, z2 + 1) + 14)
			best2 = mini(best2, _dist_at(dist, x2 - 1, z2 + 1) + 14)
			dist[i3] = best2
	# The distance is to the nearest blocked CELL CENTRE, so half a cell is
	# added back: the solid material starts half a cell further out than that.
	var need: int = int(round((radius / cell + 0.5) * 10.0))
	for i4 in range(n):
		_walk[i4] = 1 if dist[i4] >= need else 0


## Walk from the first standable cell at or near `from`. Returns false when
## there is nowhere to stand there at all.
func flood_from(from: Vector2, search := 0.6) -> bool:
	var start := Vector2i(-1, -1)
	var steps: int = maxi(int(search / cell), 1)
	for k in range(steps + 1):
		for dx in range(-k, k + 1):
			for dz in range(-k, k + 1):
				if maxi(absi(dx), absi(dz)) != k:
					continue
				var c: Vector2i = cell_of(from) + Vector2i(dx, dz)
				if at(_walk, c.x, c.y) == 1:
					start = c
					break
			if start.x >= 0:
				break
		if start.x >= 0:
			break
	if start.x < 0:
		return false
	for i in range(_seen.size()):
		_seen[i] = 0
	var stack: Array[Vector2i] = [start]
	_seen[start.x * nz + start.y] = 1
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + d
			if nb.x < 0 or nb.x >= nx or nb.y < 0 or nb.y >= nz:
				continue
			var idx: int = nb.x * nz + nb.y
			if _seen[idx] == 1 or _walk[idx] == 0:
				continue
			_seen[idx] = 1
			stack.append(nb)
	return true


## Was any cell inside `rect` (grown by `grow`, since a person stands NEXT to a
## thing rather than on it) reached from the start?
func reached(rect: Rect2, grow := 0.0) -> bool:
	return _any_in(_seen, rect, grow)


## Is there anywhere inside `rect` a person could stand at all, reached or not?
func standable(rect: Rect2, grow := 0.0) -> bool:
	return _any_in(_walk, rect, grow)


## The narrowest the FLOOR gets along a straight run between two points: how
## wide the way through actually is, measured across the run.
##
## Measured on the free floor rather than on the eroded walkable floor. A gap
## between two columns is as wide as the gap between the two columns; asking
## the eroded grid would answer "as wide as the gap, less a person", which is a
## different question and would make every stated width off by half a body.
func clearance_along(from: Vector2, to: Vector2, max_half := 3.0) -> float:
	var seg: Vector2 = to - from
	var length: float = seg.length()
	if length < 0.01:
		return 0.0
	var dir: Vector2 = seg / length
	var across := Vector2(-dir.y, dir.x)
	var narrowest := INF
	var steps: int = maxi(int(length / cell), 1)
	for i in range(steps + 1):
		var p: Vector2 = from + dir * (length * float(i) / float(steps))
		var width := 0.0
		for side in [-1.0, 1.0]:
			var reach := 0.0
			while reach < max_half:
				var q: Vector2 = p + across * (side * (reach + cell))
				var c: Vector2i = cell_of(q)
				if at(_free, c.x, c.y) == 0:
					break
				reach += cell
			width += reach
		narrowest = minf(narrowest, width)
	return narrowest if is_finite(narrowest) else 0.0


## Floor a person could stand on but never walked to.
func stranded_area() -> float:
	var n := 0
	for i in range(_walk.size()):
		if _walk[i] == 1 and _seen[i] == 0:
			n += 1
	return float(n) * cell * cell


func walkable_area() -> float:
	return float(_count(_walk)) * cell * cell


func reached_cells() -> int:
	return _count(_seen)


## A picture of what the walker saw: '#' blocked, '.' free but too tight to
## stand in, ':' standable but never reached, ' ' reached. Marks are world
## points to label, which is how a failure stops being a list of numbers.
func ascii_map(marks := {}) -> String:
	var flags := {}
	for key in marks:
		flags[cell_of(key)] = str(marks[key])
	var out := ""
	for z in range(nz):
		var line := ""
		for x in range(nx):
			var c := Vector2i(x, z)
			if flags.has(c):
				line += flags[c].substr(0, 1)
			elif at(_free, x, z) == 0:
				line += "#"
			elif at(_seen, x, z) == 1:
				line += " "
			elif at(_walk, x, z) == 1:
				line += ":"
			else:
				line += "."
		out += line + "\n"
	return out


# ----------------------------------------------------------------- internals

func at(grid: PackedByteArray, x: int, z: int) -> int:
	if x < 0 or x >= nx or z < 0 or z >= nz:
		return 0
	return grid[x * nz + z]


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int((p.x - origin.x) / cell), int((p.y - origin.y) / cell))


func world_of(x: int, z: int) -> Vector2:
	return origin + Vector2(x + 0.5, z + 0.5) * cell


func _dist_at(dist: PackedInt32Array, x: int, z: int) -> int:
	if x < 0 or x >= nx or z < 0 or z >= nz:
		return 0        # outside the grid is solid
	return dist[x * nz + z]


func _fill(rect: Rect2, value: int) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var x0: int = clampi(int(floor((rect.position.x - origin.x) / cell)), 0, nx - 1)
	var x1: int = clampi(int(ceil((rect.end.x - origin.x) / cell)), 0, nx - 1)
	var z0: int = clampi(int(floor((rect.position.y - origin.y) / cell)), 0, nz - 1)
	var z1: int = clampi(int(ceil((rect.end.y - origin.y) / cell)), 0, nz - 1)
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			# a cell counts as covered when its centre is inside the rectangle
			if rect.has_point(world_of(x, z)):
				_free[x * nz + z] = value


func _fill_poly(poly: PackedVector2Array, value: int) -> void:
	if poly.size() < 3:
		return
	var bounds: Rect2 = Poly.bounding_rect(poly)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var x0: int = clampi(int(floor((bounds.position.x - origin.x) / cell)), 0, nx - 1)
	var x1: int = clampi(int(ceil((bounds.end.x - origin.x) / cell)), 0, nx - 1)
	var z0: int = clampi(int(floor((bounds.position.y - origin.y) / cell)), 0, nz - 1)
	var z1: int = clampi(int(ceil((bounds.end.y - origin.y) / cell)), 0, nz - 1)
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			if Poly.contains_point(poly, world_of(x, z)):
				_free[x * nz + z] = value


func _any_in(grid: PackedByteArray, rect: Rect2, grow: float) -> bool:
	var r: Rect2 = rect.grow(grow)
	var x0: int = clampi(int(floor((r.position.x - origin.x) / cell)), 0, nx - 1)
	var x1: int = clampi(int(ceil((r.end.x - origin.x) / cell)), 0, nx - 1)
	var z0: int = clampi(int(floor((r.position.y - origin.y) / cell)), 0, nz - 1)
	var z1: int = clampi(int(ceil((r.end.y - origin.y) / cell)), 0, nz - 1)
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			if at(grid, x, z) == 1 and r.has_point(world_of(x, z)):
				return true
	return false


static func _count(grid: PackedByteArray) -> int:
	var n := 0
	for b in grid:
		if b == 1:
			n += 1
	return n
