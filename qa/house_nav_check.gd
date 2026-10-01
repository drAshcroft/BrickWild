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
##   STEPS        a dais is floor you walk onto, and the passages the plan
##                itself keeps clear are passages you can actually walk

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
var _omit_secret_doors := false

## Which rooms could not be walked to, and which pieces of furniture could not
## be reached. The furnisher reads these to thin a room out until it works, so
## they are part of the report rather than prose buried in a failure string.
var unreached_rooms: Array[int] = []
var unreachable_items: Array[int] = []


func check(plan: HousePlan, omit_secret_doors := false) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	unreached_rooms.clear()
	unreachable_items.clear()
	_plan = plan
	_omit_secret_doors = omit_secret_doors

	_rasterize()
	var door: int = _plan.entrance()
	if door < 0:
		failures.append("nav: no front door to start from")
		return _report()
	# a step inside the front door: where somebody stands having just come in
	var entry_level := HousePlan.record_storey(_plan.doors[door])
	if not _grids.has(entry_level):
		failures.append("nav: front door is on missing storey %d" % entry_level)
		return _report()
	var inside: Vector2 = Vector2(_plan.doors[door]["pos"]) \
		- Vector2(_plan.doors[door]["normal"]) * (HouseGeometry.wall_thickness(_plan.spec) * 0.5 + 0.2)
	_grid = _grids[entry_level]
	if not _grid.flood_from(inside):
		failures.append("nav: there is nowhere to stand inside the front door")
		return _report()
	# Propagate walkability through stair landings. Each level keeps its own
	# WalkGrid (the distance transform remains shared and 2D); a stair is the
	# explicit edge between those grids.
	_flood_storeys(inside, entry_level)
	_grid = _grids[0]
	stats["walkable_area"] = snappedf(_grid.walkable_area(), 0.1)
	stats["reached_cells"] = _grid.reached_cells()

	_check_rooms()
	_check_doors()
	_check_use_zones()
	_check_steps()
	_check_islands()
	if not _omit_secret_doors and not _plan.secret_room_indices().is_empty():
		var ordinary := HouseNavCheck.new()
		ordinary.check(_plan, true)
		var hidden_reached: Array[int] = []
		for room in _plan.secret_room_indices():
			if not ordinary.unreached_rooms.has(room):
				hidden_reached.append(room)
		if not hidden_reached.is_empty():
			failures.append("nav: hidden rooms %s remain reachable without secret doors" % [str(hidden_reached)])
		stats["secret_doors_omitted"] = true
		stats["hidden_rooms_unreached_without_secrets"] = _plan.secret_room_indices().size() - hidden_reached.size()
	return _report()


func _report() -> Dictionary:
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats, "unreached_rooms": unreached_rooms,
		"unreachable_items": unreachable_items}


## Free floor is: inside some room, or inside a doorway. Then the furniture is
## subtracted. Building it this way round means a partition is blocked because
## it belongs to no room, which is exactly what a wall is.
func _rasterize() -> void:
	_grids.clear()
	for level in _levels():
		var bounds := HouseGeometry.storey_rect(_plan, level)
		var grid := WalkGrid.new()
		grid.setup(bounds, HouseGeometry.NAV_CELL)
		_grids[level] = grid
	_grid = _grids[0]
	for i in range(_plan.room_count()):
		var level := HousePlan.record_storey(_plan.rooms[i])
		if not _grids.has(level):
			continue
		# A room shaped by an outline is rasterised as that outline, not as the
		# box round it: the corners a chamfer cuts off are wall, and a walker
		# that stood in them would be standing outside the building (GEO-002).
		if _plan.is_polygonal(i):
			_grids[level].add_floor_poly(_plan.outline_of(i))
		else:
			_grids[level].add_floor(HouseGeometry.room_floor_rect(_plan, i))
	# A court is FLOOR. You walk out of the hall into the yard and across it to
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
		if _omit_secret_doors and bool(d.get("secret", false)):
			continue
		var level := HousePlan.record_storey(d)
		if _grids.has(level):
			_grids[level].add_floor(_door_gap(d))
	# A dais is laid down after the floor it stands on, and as a STEP: floor at
	# a different height. A rise a person can walk up joins the room; one they
	# cannot is cut off, and the walk says so rather than pretending. (CAS-010)
	var dais_room: int = _plan.dais_room()
	if dais_room >= 0 and dais_room < _plan.room_count():
		var dl := HousePlan.record_storey(_plan.rooms[dais_room])
		if _grids.has(dl):
			_grids[dl].add_step(_plan.dais_rect(), _plan.dais_rise())
	for p in _plan.furniture:
		if p.get("mounted", false) or p["host"] >= 0:
			continue
		if not PropCatalog.blocks_floor(p["key"]):
			continue
		var level := HousePlan.record_storey(p)
		if _grids.has(level):
			_grids[level].add_obstacle(p["rect"])
	for column in _plan.columns:
		var level := int(column.get("storey", 0))
		if not _grids.has(level):
			continue
		var pos: Vector2 = column.get("pos", Vector2.ZERO)
		var size: Vector2 = column.get("size", Vector2.ZERO)
		if size.x > 0.0 and size.y > 0.0:
			_grids[level].add_obstacle(Rect2(pos - size * 0.5, size))
	var breast := HouseGeometry.hearth_breast(_plan)
	if not breast.is_empty() and _grids.has(int(breast["storey"])):
		_grids[int(breast["storey"])].add_obstacle_poly(breast["outline"])
	for level in _grids:
		_grids[level].build(HouseGeometry.PERSON_RADIUS)


func _flood_storeys(inside: Vector2, start_level := 0) -> void:
	var reachable_levels := {}
	var seeds := {start_level: inside}
	var pending: Array[int] = [start_level]
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
		if level == start_level:
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
	for level in range(lowest, clampi(int(_plan.spec.storeys), 1, _plan.spec.max_storeys())):
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
		if _world_shop_has_street_opening(i):
			continue
		if _plan.kind_of(i) == &"oubliette" and bool(_plan.rooms[i].get("sealed", false)):
			# A sealed cellar is intentionally outside the ordinary walking graph.
			# HousePlanCheck verifies its trapdoor record and keyed graph exception.
			continue
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
		if _omit_secret_doors and bool(door.get("secret", false)):
			continue
		if _world_shop_door(door):
			continue
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
		if _world_shop_has_street_opening(int(p.get("room", -1))):
			continue
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


func _world_shop_door(door: Dictionary) -> bool:
	if _plan.world_family not in [&"courtyard_house", &"insula"] or not bool(door.get("exterior", false)):
		return false
	if bool(door.get("front", false)):
		return false
	var room := int(door.get("a", -1))
	return room >= 0 and room < _plan.rooms.size() \
		and String(_plan.rooms[room].get("role", "")).begins_with("taberna")


func _world_shop_has_street_opening(room: int) -> bool:
	if _plan.world_family not in [&"courtyard_house", &"insula"] or room < 0 or room >= _plan.rooms.size():
		return false
	if not String(_plan.rooms[room].get("role", "")).begins_with("taberna"):
		return false
	for d in _plan.doors:
		if int(d.get("a", -1)) == room and bool(d.get("exterior", false)) \
				and not bool(d.get("front", false)):
			return true
	return false


## The dais and every passage the plan keeps clear are places a person is meant
## to get to. The dais is the harder of the two: it is floor at another height,
## so reaching it proves the step is a step and not a wall the walk went round.
func _check_steps() -> void:
	var room: int = _plan.dais_room()
	if room >= 0 and room < _plan.room_count():
		var rect: Rect2 = _plan.dais_rect()
		var grid: WalkGrid = _grid_for(_plan.rooms[room])
		if not grid.reached(rect):
			if grid.standable(rect):
				failures.append("steps: the dais in room %d (%s) stands %.2fm up and nobody can walk onto it"
					% [room, String(_plan.kind_of(room)), _plan.dais_rise()])
			else:
				failures.append("steps: the dais in room %d (%s) is so full there is nowhere to stand on it"
					% [room, String(_plan.kind_of(room))])
	for z in _plan.zones:
		var zr: int = int(z.get("room", -1))
		if zr < 0 or zr >= _plan.room_count():
			continue
		if not _grid_for(_plan.rooms[zr]).reached(Rect2(z["rect"])):
			failures.append("steps: the %s in room %d cannot be walked"
				% [String(z.get("why", "clear floor")), zr])


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
