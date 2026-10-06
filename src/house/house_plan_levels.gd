class_name HousePlanLevels
extends RefCounted
## Cellars, upper storeys, stairs, and circulation geometry.

# ------------------------------------------------------------------ cellars

## Storeys below the ground (INT-016): the ground partition again, dug down,
## every room a store, joined by the ground floor's interior doors and by a
## stair down from the hall. No windows, no exterior doors: a cellar is
## entered from the house.
static func dig_cellars(p: HousePlan, spec: HouseSpec) -> void:
	var base_rooms: Array[int] = p.rooms_on_storey(0)
	var base_doors: Array[Dictionary] = []
	for door in p.doors:
		if not door["exterior"] and p.storey_of_room(int(door["a"])) == 0:
			base_doors.append(door)
	var hall: int = base_rooms[0]
	for room in base_rooms:
		if p.kind_of(room) == &"hall":
			hall = room
			break
	for storey in range(-1, -spec.cellars - 1, -1):
		var remap: Dictionary = {}
		var under_hall := -1
		for source in base_rooms:
			var room := p.rooms[source].duplicate()
			room["storey"] = storey
			room["kind"] = &"store"
			var target: int = p.rooms.size()
			p.rooms.append(room)
			remap[source] = target
			if source == hall:
				under_hall = target
		for source_door in base_doors:
			var door := source_door.duplicate()
			door["a"] = remap[int(source_door["a"])]
			door["b"] = remap[int(source_door["b"])]
			door["storey"] = storey
			p.doors.append(door)
		# the stair down: from the room above (the hall, or the cellar room
		# above this one) into the cellar under it
		var above: int = hall
		if storey < -1:
			for s in p.stairs:
				if int(s.get("storey", 0)) == storey + 1:
					above = int(s.get("a", hall))
		add_stair(p, under_hall, above, storey, storey + 1)


# ---------------------------------------------------------- stacked storeys

## The first storey is deliberately planned by the original path above. Higher
## storeys reuse that finished partition -- the walls have to line up, a
## partition cannot start in mid-air -- but NOT its programme. A cloned kitchen
## upstairs is a second fire with no flue and a hall with no front door; what
## belongs up a stair is where the household sleeps.
##
## So each upper storey keeps the cloned rectangles and the cloned interior
## doors, and is then NAMED afresh from the stair landing outwards, private
## programme first, and GLAZED afresh by those new kinds. Exterior doors stay
## on the ground floor; the stair is the only way between levels.
static func clone_upper_storeys(p: HousePlan, spec: HouseSpec) -> void:
	var base_rooms: Array[int] = p.rooms_on_storey(0)
	var base_doors: Array[Dictionary] = []
	for door in p.doors:
		if not door["exterior"] and p.storey_of_room(int(door["a"])) == 0:
			base_doors.append(door)
	var base_windows: Array[Dictionary] = p.windows.duplicate()
	var dwelling: bool = has_upstairs(spec)
	var hall_by_storey: Dictionary = {}
	for room in base_rooms:
		if p.kind_of(room) == &"hall":
			hall_by_storey[0] = room
			break
	if not hall_by_storey.has(0) and not base_rooms.is_empty():
		hall_by_storey[0] = base_rooms[0]

	for storey in range(1, spec.storeys):
		var remap: Dictionary = {}
		var mine: Array[int] = []
		for source in base_rooms:
			var room := p.rooms[source].duplicate()
			room["storey"] = storey
			var rect: Rect2 = room["rect"]
			var ground := HouseGeometry.interior_rect(spec)
			var upper := HouseGeometry.interior_rect(spec, storey)
			if absf(rect.position.y - ground.position.y) < 0.01:
				var extra := ground.position.y - upper.position.y
				rect.position.y -= extra
				rect.size.y += extra
				room["rect"] = rect
			var target: int = p.rooms.size()
			p.rooms.append(room)
			remap[source] = target
			mine.append(target)
			if p.kind_of(source) == &"hall":
				hall_by_storey[storey] = target

		for source_door in base_doors:
			var door := source_door.duplicate()
			door["a"] = remap[int(source_door["a"])]
			door["b"] = remap[int(source_door["b"])]
			door["storey"] = storey
			p.doors.append(door)

		# Link adjacent levels so every upper floor has a real route from the
		# front door, including the third storey, without treating a stair as a
		# horizontal door.
		var lower_hall: int = int(hall_by_storey.get(storey - 1,
			hall_by_storey[0]))
		var upper_hall: int = int(hall_by_storey.get(storey, -1))
		if upper_hall >= 0:
			add_stair(p, lower_hall, upper_hall, storey - 1, storey)

		if dwelling and upper_hall >= 0:
			_name_upstairs(p, mine, upper_hall)
			HousePlanOpenings.place_windows(p, spec, mine)
			HousePlanOpenings.glaze_remaining(p, spec, mine)
			HousePlanner.demote_unlit(p, mine)
		else:
			# A shop or any other building that brought its own room programme
			# keeps the old copy-the-ground-floor behaviour.
			for source_window in base_windows:
				var window := source_window.duplicate()
				window["room"] = remap[int(source_window["room"])]
				window["storey"] = storey
				p.windows.append(window)

	if dwelling:
		# The upper floors are full of bedrooms now, so the privacy rules have
		# to be re-run over the whole house: a store you can only reach across
		# somebody's bed is the same defect upstairs as down.
		HousePlanOpenings.open_up_privacy(p)
		_ensure_bedrooms_upstairs(p, spec)
		HousePlanOpenings.demote_through_bedrooms(p)
		_ensure_a_bed(p)


## Would the upper storey be able to hold a bedroom at all?
##
## The upper floors are clones of the ground partition, so this is the same
## question asked of the rooms in front of us. A narrow cottage whose rooms are
## all too thin for a bed does not get its bedrooms deferred upstairs -- it
## would end up with nowhere at all to sleep, and a house with no bedroom puts
## the bed in the hall.
static func can_sleep_upstairs(p: HousePlan) -> bool:
	for i in range(p.rooms.size()):
		if HouseGeometry.room_suits(p, i, &"bedroom"):
			return true
	return false


## Is this a plain dwelling, the kind that sleeps upstairs?
##
## A ShopSpec (and anything else that hands the planner its own programme
## through `room_program`) means the storeys were asked for by a building that
## already knows what goes on each of them, so leave its floors alone. Duck
## typing rather than a class test, so the house package keeps no dependency on
## the shop package.
static func has_upstairs(spec: HouseSpec) -> bool:
	return int(spec.storeys) > 1 and not spec.has_method("room_program")


## Name one upper storey, private-first, with the stair landing as its pole.
##
## Downstairs the front door is the public end of the house and the plan is
## ordered away from it. Upstairs the stair is the front door: the room you
## step off it into is the one everybody crosses, so it takes the most public
## kind the floor has, and the rooms nobody crosses -- the leaves of the door
## tree, which was cloned from the ground floor along with the walls -- are
## where the household sleeps.
##
## Naming by the tree rather than by distance alone is what keeps the privacy
## rule true by construction: a bedroom is only ever a leaf, so no room is ever
## put behind a bed.
static func _name_upstairs(p: HousePlan, mine: Array[int], landing: int) -> void:
	var order: Array[int] = _upstairs_order(p, mine, landing)
	var leaf: Dictionary = _leaves(p, mine, landing)
	for i in order:
		# the landing, and any room crossed to reach another, is public ground;
		# only a dead end is somebody's own
		var private: bool = i != landing and bool(leaf.get(i, false))
		var kind: StringName = &"bedroom" if private else &"parlour"
		if not HouseGeometry.room_suits(p, i, kind):
			kind = &"store"
		p.rooms[i]["kind"] = kind


## The rooms of one upper storey, most public first: by how far they sit from
## the stairwell, which is the same measure `_name_rooms` takes from the front
## door downstairs.
static func _upstairs_order(p: HousePlan, mine: Array[int], landing: int) -> Array[int]:
	var pole: Vector2 = HouseGeometry.room_floor_rect(p, landing).get_center()
	for stair in p.stairs:
		if int(stair.get("b", -1)) == landing:
			pole = Rect2(stair["upper_rect"]).get_center()
			break
	var dist := {}
	for i in mine:
		dist[i] = HouseGeometry.room_floor_rect(p, i).get_center().distance_to(pole)
	var order: Array[int] = mine.duplicate()
	order.sort_custom(func(a: int, b: int) -> bool: return dist[a] < dist[b])
	return order


## Which rooms of one storey are dead ends -- reached from the landing and
## leading nowhere further. Those, and only those, may be bedrooms.
static func _leaves(p: HousePlan, mine: Array[int], landing: int) -> Dictionary:
	var adj := {}
	for i in mine:
		adj[i] = []
	for d in p.doors:
		var a: int = int(d["a"])
		var b: int = int(d["b"])
		if b < 0 or not adj.has(a) or not adj.has(b):
			continue
		adj[a].append(b)
		adj[b].append(a)
	var seen := {landing: true}
	var queue: Array[int] = [landing]
	var children := {landing: 0}
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for nb in adj[cur]:
			if seen.has(nb):
				continue
			seen[nb] = true
			children[cur] = int(children.get(cur, 0)) + 1
			children[nb] = int(children.get(nb, 0))
			queue.append(nb)
	var out := {}
	for i in mine:
		# a room the tree never reached is nobody's route either
		out[i] = int(children.get(i, 0)) == 0
	return out


## An upper storey with nobody sleeping on it is not what the stair was for.
##
## `_name_upstairs` will only make a dead end a bedroom, and on a narrow plan
## every dead end is too thin for a bed while the landing is not. Rather than
## leave the floor as a parlour and a cupboard, try the rooms again from the
## far end: take the first one that can hold a bed AND still leaves every other
## room reachable without crossing it. On a two-room floor whose only bedroom
## candidate is the landing itself that finds nothing, which is the right
## answer -- a bedroom you have to walk through to reach the back room is the
## defect this whole pass exists to avoid.
static func _ensure_bedrooms_upstairs(p: HousePlan, spec: HouseSpec) -> void:
	var start: int = p.entrance_room()
	for storey in range(1, int(spec.storeys)):
		var mine: Array[int] = p.rooms_on_storey(storey)
		var slept := false
		for i in mine:
			if p.kind_of(i) in HouseGeometry.SLEEPING:
				slept = true
				break
		if slept:
			continue
		var landing: int = _landing_of(p, storey)
		var order: Array[int] = _upstairs_order(p, mine, landing)
		order.reverse()               # furthest from the stair first
		for i in order:
			if not HouseGeometry.room_suits(p, i, &"bedroom"):
				continue
			var was: StringName = p.kind_of(i)
			p.rooms[i]["kind"] = &"bedroom"
			HousePlanOpenings.open_up_privacy(p)
			if _privacy_holds(p, start):
				break
			p.rooms[i]["kind"] = was


## The room an upper storey is entered into: the top of its stair.
static func _landing_of(p: HousePlan, storey: int) -> int:
	for stair in p.stairs:
		if int(stair.get("to_storey", -1)) == storey:
			return int(stair.get("b", -1))
	var mine: Array[int] = p.rooms_on_storey(storey)
	return mine[0] if not mine.is_empty() else -1


## A house has to have somewhere to sleep.
##
## The programme sends the bedrooms upstairs, and a floor of rooms too thin for
## a bed can send none of them back. Rather than leave a dwelling with no bed
## at all -- which the furnisher then has to squeeze into the hall, and often
## cannot -- promote the best candidate: the highest, most private room that
## can hold a bed and that nobody has to walk through to get anywhere.
static func _ensure_a_bed(p: HousePlan) -> void:
	for i in range(p.rooms.size()):
		if p.kind_of(i) in HouseGeometry.SLEEPING:
			return
	var start: int = p.entrance_room()
	var order: Array[int] = HousePlanRooms.all_rooms(p)
	order.sort_custom(func(a: int, b: int) -> bool:
		if p.storey_of_room(a) != p.storey_of_room(b):
			return p.storey_of_room(a) > p.storey_of_room(b)
		return HouseGeometry.room_area(p, a) > HouseGeometry.room_area(p, b))
	for i in order:
		if i == start or p.kind_of(i) == &"hall":
			continue
		if not HouseGeometry.room_suits(p, i, &"bedroom"):
			continue
		var was: StringName = p.kind_of(i)
		p.rooms[i]["kind"] = &"bedroom"
		if _privacy_holds(p, start):
			return
		p.rooms[i]["kind"] = was


## Can every room still be reached without crossing somewhere somebody sleeps?
static func _privacy_holds(p: HousePlan, start: int) -> bool:
	if start < 0:
		return true
	var polite: Dictionary = p.reachable_rooms(start, HouseGeometry.SLEEPING)
	for i in range(p.rooms.size()):
		if p.kind_of(i) == &"bedroom":
			continue
		if not polite.has(i):
			return false
	return true


## Add one stair in the hall equivalent on each of two adjacent levels. The
## landing is kept as an explicit rectangle so layered navigation and a future
## builder can agree on the opening without deriving it from the mesh.
##
## The stairwell runs along the room's LONG axis. Laid the other way it spans
## the short one and walls the room in half: a 4.9 x 3.0 m hall with a 2.4 m
## well across it has two 2 m stubs either side of the well and no way past the
## table, which is how a smith's workshop ended up unreachable from his own
## front door.
##
## And it stands AGAINST A WALL, out of the line of the front door (LAY-005).
## The middle of the hall is the one place a stair should never take: it faces
## whoever comes in head-on -- the oldest fault in the feng shui of a house,
## and the oldest complaint of an estate agent -- and it stands where the
## table would have stood. So the well is slid along each wall that runs the
## room's long way, and the spot is chosen that keeps clear of every door's
## swing, of the strip the front door opens onto, and of the windows, and is
## furthest from the front door among those. HousePlanCheck's `stair_line`
## rule measures the result.
static func add_stair(p: HousePlan, lower_room: int, upper_room: int,
		lower_storey: int, upper_storey: int) -> void:
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(p, lower_room)
	var along_x: bool = floor_rect.size.x > floor_rect.size.y
	var long_side: float = maxf(floor_rect.size.x, floor_rect.size.y)
	var short_side: float = minf(floor_rect.size.x, floor_rect.size.y)
	var run: float = minf(2.4, maxf(HouseGeometry.PATH_MIN, long_side - 0.3))
	var width: float = minf(1.0, maxf(HouseGeometry.PATH_MIN, short_side - 0.3))
	var size := Vector2(run, width) if along_x else Vector2(width, run)
	# the long way first; across the room only if the long way has no spot
	# that keeps out of the front door's line -- a stair along the front wall
	# of a narrow hall cannot help crossing it
	var run2: float = minf(2.4, maxf(HouseGeometry.PATH_MIN, short_side - 0.3))
	var width2: float = minf(1.0, maxf(HouseGeometry.PATH_MIN, long_side - 0.3))
	var size2 := Vector2(width2, run2) if along_x else Vector2(run2, width2)
	var found: Dictionary = _stair_spot(p, lower_room, floor_rect, size)
	var other: Dictionary = _stair_spot(p, lower_room, floor_rect, size2)
	if int(other["strict"]) < int(found["strict"]):
		found = other
		run = run2
		width = width2
	# a hall too narrow for the stair to keep out of the door's line either
	# way moves the DOOR instead: to the end of its wall away from the stair
	if int(found["strict"]) >= 2 and _slide_front_door(p, lower_room, found["rect"]):
		var again: Dictionary = _stair_spot(p, lower_room, floor_rect, size)
		var again2: Dictionary = _stair_spot(p, lower_room, floor_rect, size2)
		if int(again2["strict"]) < int(again["strict"]):
			again = again2
			run = run2
			width = width2
		else:
			run = minf(2.4, maxf(HouseGeometry.PATH_MIN, long_side - 0.3))
			width = minf(1.0, maxf(HouseGeometry.PATH_MIN, short_side - 0.3))
		found = again
	if int(found["strict"]) >= 2:
		# nowhere in this hall keeps the stair out of the door's line, and
		# the door could not move: written down, so the check reports a
		# compromise rather than a defect
		p.note_compromise(lower_room, "stair")
	var footprint: Rect2 = found["rect"]
	var centre: Vector2 = footprint.get_center()
	p.stairs.append({
		"a": lower_room, "b": upper_room,
		"storey": lower_storey, "to_storey": upper_storey,
		"pos": centre, "lower_pos": centre, "upper_pos": centre,
		"rect": footprint, "lower_rect": footprint, "upper_rect": footprint,
		"width": width, "run": run,
	})


## Slide the front door along its wall to the end away from `stair`, when
## that end is clear of windows and would not put it in line with the back
## door. True when the door moved.
static func _slide_front_door(p: HousePlan, room: int, stair: Rect2) -> bool:
	var d: int = p.entrance()
	if d < 0 or int(p.doors[d]["a"]) != room:
		return false
	var door: Dictionary = p.doors[d]
	if absf(float(door["normal"].y)) < 0.5:
		return false
	var rect: Rect2 = p.rooms[room]["rect"]
	var w: float = float(door["width"])
	var m: float = HouseGeometry.DOOR_CORNER_MARGIN + w / 2.0
	var lo: float = rect.position.x + m
	var hi: float = rect.end.x - m
	if hi <= lo:
		return false
	var far: float = lo if stair.get_center().x > rect.get_center().x else hi
	var near: float = hi if far == lo else lo
	for x in [far, near]:
		if absf(x - float(door["pos"].x)) < 0.3:
			continue
		# not in line with the back door
		var lined := false
		for od in p.doors:
			if od == door or not od["exterior"]:
				continue
			if Vector2(od["normal"]).dot(Vector2(door["normal"])) > -0.9:
				continue
			if absf(float(od["pos"].x) - x) < (w + float(od["width"])) / 2.0 + 0.05:
				lined = true
		if lined:
			continue
		# a window in the way slides to where the door was, if that is clear
		var blocked := false
		var moves := {}
		for wi in p.windows_of(room):
			var win: Dictionary = p.windows[wi]
			if absf(float(win["normal"].y)) < 0.5 or absf(float(win["pos"].y) - float(door["pos"].y)) > 0.5:
				continue
			var reach: float = (w + float(win["width"])) / 2.0 + 0.15
			if absf(float(win["pos"].x) - x) >= reach:
				continue
			var wx: float = float(door["pos"].x)
			var ok: bool = wx - float(win["width"]) / 2.0 >= rect.position.x + HouseGeometry.WINDOW_CORNER_MARGIN \
				and wx + float(win["width"]) / 2.0 <= rect.end.x - HouseGeometry.WINDOW_CORNER_MARGIN \
				and absf(wx - x) >= reach
			for wj in p.windows_of(room):
				if wj == wi:
					continue
				var o: Dictionary = p.windows[wj]
				if absf(float(o["normal"].y)) < 0.5 or absf(float(o["pos"].y) - float(win["pos"].y)) > 0.5:
					continue
				if absf(float(o["pos"].x) - wx) < (float(o["width"]) + float(win["width"])) / 2.0 + HouseGeometry.WINDOW_MIN_GAP:
					ok = false
			if not ok:
				blocked = true
				break
			moves[wi] = wx
		if blocked:
			continue
		for wi2 in moves:
			p.windows[wi2]["pos"] = Vector2(float(moves[wi2]), float(p.windows[wi2]["pos"].y))
		door["pos"] = Vector2(x, float(door["pos"].y))
		return true
	return false


## The strip of floor a door opens onto, its own width, straight across the
## room to the far wall. Both the planner and HousePlanCheck measure the
## stair against it.
static func door_line(p: HousePlan, room: int, door: Dictionary) -> Rect2:
	var f: Rect2 = HouseGeometry.room_floor_rect(p, room)
	var pos: Vector2 = door["pos"]
	var n: Vector2 = door["normal"]
	var half: float = float(door["width"]) / 2.0
	if absf(n.y) > 0.5:
		return Rect2(Vector2(pos.x - half, f.position.y), Vector2(half * 2.0, f.size.y))
	return Rect2(Vector2(f.position.x, pos.y - half), Vector2(f.size.x, half * 2.0))


## Where the stair goes: against one of the walls its run lies along, at the
## spot that is clear of the doors' swings, the front door's line and the
## windows and, of those, furthest from the front door. Each rule is dropped
## in turn only if nothing satisfies it, and a wall is never given up -- the
## last resort is the wall with the fewest openings, at the end furthest from
## the door. Returns {"rect": Rect2, "strict": int}, the strictness level the
## spot was found at (0 = every rule held).
static func _stair_spot(p: HousePlan, room: int, f: Rect2, size: Vector2) -> Dictionary:
	var along_x: bool = size.x >= size.y
	var swings: Array[Rect2] = []
	var lines: Array[Rect2] = []
	var glass: Array[Rect2] = []
	var front := Vector2(f.get_center().x, f.position.y)
	var storey: int = p.storey_of_room(room)
	var entrance: int = p.entrance()
	for d in p.doors_of(room):
		var door: Dictionary = p.doors[d]
		if HousePlan.record_storey(door) != storey:
			continue
		for side in [-1.0, 1.0]:
			swings.append(HouseGeometry.door_clear_rect(door, side))
		if d == entrance:
			lines.append(door_line(p, room, door))
			front = door["pos"]
	for w in p.windows_of(room):
		glass.append(HouseGeometry.window_clear_rect(p.windows[w]))
	var wells: Array[Rect2] = arriving_wells(p, storey)
	# the two walls the run lies along; the stair's long edge is on one of them
	var walls: Array[Rect2] = []
	if along_x:
		walls.append(Rect2(Vector2(f.position.x, f.position.y), size))
		walls.append(Rect2(Vector2(f.position.x, f.end.y - size.y), size))
	else:
		walls.append(Rect2(Vector2(f.position.x, f.position.y), size))
		walls.append(Rect2(Vector2(f.end.x - size.x, f.position.y), size))
	var travel: float = (f.size.x - size.x) if along_x else (f.size.y - size.y)
	var steps: int = maxi(int(travel / 0.1), 1)
	# strictness falls away one rule at a time: swings, then the door lines,
	# then the windows
	for strict in range(4):
		var best := Rect2()
		var best_score := -INF
		for base in walls:
			for s in range(steps + 1):
				var t: float = travel * float(s) / float(steps)
				var rect := Rect2(base.position + (Vector2(t, 0.0) if along_x
					else Vector2(0.0, t)), size)
				# never at any strictness: see arriving_wells
				if hits_any(rect, wells):
					continue
				if strict < 3 and hits_any(rect, swings):
					continue
				if strict < 2 and hits_any(rect, lines):
					continue
				if strict < 1 and hits_any(rect, glass):
					continue
				# A stairwell has to be ON THE FLOOR. In a shaped room the
				# corners of the bounding box are masonry, and a well set down
				# in one is a landing nobody can walk to (GEO-002).
				if not _inside_room(p, room, rect):
					continue
				var score: float = rect.get_center().distance_to(front)
				# a well must leave the way past it: the short way across the
				# room, beside the stair, has to stay a path wide
				var beside: float = (f.size.y - size.y) if along_x else (f.size.x - size.x)
				if beside < HouseGeometry.PATH_MIN:
					score -= 100.0
				if score > best_score:
					best_score = score
					best = rect
		if best.size.x > 0.0:
			return {"rect": best, "strict": strict}
	return {"rect": Rect2(f.get_center() - size / 2.0, size), "strict": 4}


## Is every corner of `rect` inside the room? True for a rectangular room --
## the caller has already kept it inside the floor rectangle.
static func _inside_room(p: HousePlan, room: int, rect: Rect2) -> bool:
	if not p.is_polygonal(room):
		return true
	var poly: PackedVector2Array = p.outline_of(room)
	for c in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]:
		if not Poly.contains_point(poly, c, 0.01):
			return false
	return true


## How far a new flight keeps from the well of the flight arriving beside it.
const WELL_CLEAR := 0.3


## The wells that open in `storey`'s floor: where the flight from the storey
## below comes up, grown by WELL_CLEAR.
##
## A flight may not stand in one. Every planner used to choose the next storey's
## stair by the same rules from the same doors, so it chose the same rectangle:
## the upper flight sat on top of the lower one, the lower flight climbed
## straight into the solid foot of the upper, and nothing arrived anywhere
## (WALK-QA, 6 Oct, hotel pin 9 "stairway to nowhere"; 110 of 120 three-storey
## house plans did the same). HousePlanCheck's `stairs` rule now refuses it.
##
## And the other way round, for a flight planned after the ones above it (a
## cellar stair is): the flights that LEAVE the storey the new one arrives on
## stand where it would come up.
static func arriving_wells(p: HousePlan, storey: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for stair in p.stairs:
		var lo := int(stair.get("storey", 0))
		var hi := int(stair.get("to_storey", lo + 1))
		var well := Rect2()
		if hi == storey:
			well = Rect2(stair.get("upper_rect", stair.get("rect", Rect2())))
		elif lo == storey + 1:
			well = Rect2(stair.get("lower_rect", stair.get("rect", Rect2())))
		if well.has_area():
			out.append(well.grow(WELL_CLEAR))
	return out


static func hits_any(rect: Rect2, others: Array[Rect2]) -> bool:
	for o in others:
		var over: Rect2 = rect.intersection(o)
		if over.size.x > 0.02 and over.size.y > 0.02:
			return true
	return false

