class_name HouseNavCheck
extends RefCounted
## Can a person actually walk through this house and use what is in it?
##
## Everything above this file argues from rectangles. This one puts a body in
## the building: WalkGrid rasterizes the floor, blocks out the walls and the
## furniture, shrinks the free floor by a person own half-width, and walks it.
## What lives here is the house rules that walk is judged by:
##
##   REACH ROOMS  every room can be entered from the front door
##   REACH DOORS  both sides of every door are standable
##   REACH USE    the side of the bed, the pull-back space behind each chair,
##                the floor in front of the hearth -- all of them walkable and
##                all of them connected to the rest of the house
##   ISLANDS      no stranded pocket of floor big enough to stand in

## A stranded pocket smaller than this is a corner behind a barrel, not a room.
const ISLAND_MIN_AREA := 0.6
## How far into a room a person has to get before they count as being in it,
## rather than standing in its doorway.
const DOORWAY_LIP := 0.3

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}

var _plan: HousePlan
var _grid: WalkGrid
var _grids: Dictionary = {}

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
	var door: int = _plan.entrance()
	if door < 0:
		failures.append("nav: no front door to start from")
		return _report()
	# a step inside the front door: where somebody stands having just come in
	var inside: Vector2 = Vector2(_plan.doors[door]["pos"]) \
		- Vector2(_plan.doors[door]["normal"]) * (HouseGeometry.WALL_T * 0.5 + 0.2)
	if not _grid.flood_from(inside):
		failures.append("nav: there is nowhere to stand inside the front door")
		return _report()
	# Propagate walkability through stair landings. Each level keeps its own
	# WalkGrid (the distance transform remains shared and 2D); a stair is the
	# explicit edge between those grids.
	_flood_storeys(inside)
	stats["walkable_area"] = snappedf(_grid.walkable_area(), 0.1)
	stats["reached_cells"] = _grid.reached_cells()

	_check_rooms()
	_check_doors()
	_check_use_zones()
	_check_islands()
	return _report()


func _report() -> Dictionary:
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats, "unreached_rooms": unreached_rooms,
		"unreachable_items": unreachable_items}


## Free floor is: inside some room, or inside a doorway. Then the furniture is
## subtracted. Building it this way round means a partition is blocked because
## it belongs to no room, which is exactly what a wall is.
func _rasterize() -> void:
	var bounds: Rect2 = HouseGeometry.interior_rect(_plan.spec).grow(HouseGeometry.WALL_T)
	_grids.clear()
	for level in _levels():
		var grid := WalkGrid.new()
		grid.setup(bounds, HouseGeometry.NAV_CELL)
		_grids[level] = grid
	_grid = _grids[0]
	for i in range(_plan.room_count()):
		var level := HousePlan.record_storey(_plan.rooms[i])
		if _grids.has(level):
			_grids[level].add_floor(HouseGeometry.room_floor_rect(_plan, i))
	for d in _plan.doors:
		var level := HousePlan.record_storey(d)
		if _grids.has(level):
			_grids[level].add_floor(_door_gap(d))
	for p in _plan.furniture:
		if p.get("mounted", false) or p["host"] >= 0:
			continue
		if not PropCatalog.blocks_floor(p["key"]):
			continue
		var level := HousePlan.record_storey(p)
		if _grids.has(level):
			_grids[level].add_obstacle(p["rect"])
	for level in _grids:
		_grids[level].build(HouseGeometry.PERSON_RADIUS)


func _flood_storeys(inside: Vector2) -> void:
	var reachable_levels := {}
	var seeds := {0: inside}
	var pending: Array[int] = [0]
	while not pending.is_empty():
		var level: int = pending.pop_front()
		var grid: WalkGrid = _grids[level]
		if not grid.flood_from(seeds[level]):
			continue
		reachable_levels[level] = true
		# a stair is walked both ways: up from its lower landing, and down
		# from its upper one into a cellar (INT-016)
		for stair in _plan.stairs:
			var lo: int = int(stair.get("storey", 0))
			var hi: int = int(stair.get("to_storey", lo + 1))
			if hi != lo + 1:
				continue
			var other := -999
			var here: Rect2
			var there: Rect2
			if lo == level and _grids.has(hi):
				other = hi
				here = _stair_rect(stair, false)
				there = _stair_rect(stair, true)
			elif hi == level and _grids.has(lo):
				other = lo
				here = _stair_rect(stair, true)
				there = _stair_rect(stair, false)
			else:
				continue
			if not grid.reached(here):
				continue
			if not seeds.has(other):
				seeds[other] = there.get_center()
				pending.append(other)
		if level == 0:
			_grid = grid
	for level in _levels():
		if not reachable_levels.has(level):
			failures.append("nav: storey %d cannot be reached through stairs" % level)


## Every level the plan has, cellars included (INT-016).
func _levels() -> Array[int]:
	var out: Array[int] = []
	var lowest := 0
	if _plan.spec.has_method("lowest_storey"):
		lowest = int(_plan.spec.lowest_storey())
	for level in range(lowest, clampi(int(_plan.spec.storeys), 1, 3)):
		out.append(level)
	return out


static func _stair_rect(stair: Dictionary, upper: bool) -> Rect2:
	var key := "upper_rect" if upper else "lower_rect"
	if stair.has(key):
		return Rect2(stair[key])
	return Rect2(stair.get("rect", Rect2()))


func _grid_for(record: Dictionary) -> WalkGrid:
	var level := HousePlan.record_storey(record)
	return _grids.get(level, _grid)


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


## A picture of what the walker saw, for diagnosing a reachability failure.
func ascii_map(storey := 0) -> String:
	var marks := {}
	for d in range(_plan.doors.size()):
		if HousePlan.record_storey(_plan.doors[d]) == storey:
			marks[Vector2(_plan.doors[d]["pos"])] = str(d)
	var grid: WalkGrid = _grids.get(storey, _grid)
	return grid.ascii_map(marks)


# ---------------------------------------------------------------- checks

func _check_rooms() -> void:
	var reached := 0
	for i in range(_plan.room_count()):
		var f: Rect2 = _room_body(i)
		if _grid_for(_plan.rooms[i]).reached(f):
			reached += 1
			continue
		# say WHY: no standable floor at all, or standable but cut off
		unreached_rooms.append(i)
		if _grid_for(_plan.rooms[i]).standable(f):
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
			if not _grid_for(door).reached(Rect2(t - Vector2.ONE * 0.05, Vector2.ONE * 0.1),
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
		if _grid_for(p).reached(zone, HouseGeometry.PERSON_RADIUS * 0.5):
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
	var area := 0.0
	for grid in _grids.values():
		area += grid.stranded_area()
	stats["stranded_area"] = snappedf(area, 0.01)
	if area > ISLAND_MIN_AREA:
		warnings.append("nav: %.1f m2 of floor is walkable but cut off from the rest of the house"
			% area)
