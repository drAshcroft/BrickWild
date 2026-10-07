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
		var arrival_satisfied := true
		if upper_hall >= 0:
			# A third flight has to share the compact middle-storey hall with the
			# incoming stair. Move that floor's hall doors to the far ends of
			# their actual shared walls before fitting it; the doors retain their
			# width, head and full swing clearance.
			if dwelling and _uses_domestic_stairs(p):
				_relocate_upper_hall_doors(p, lower_hall, storey - 1)
				_relocate_upper_hall_doors(p, upper_hall, storey)
			add_stair(p, lower_hall, upper_hall, storey - 1, storey)
			if not p.stairs.is_empty():
				var arriving_stair: Dictionary = p.stairs.back()
				if int(arriving_stair.get("to_storey", -1)) == storey \
						and int(arriving_stair.get("b", -1)) == upper_hall:
					arrival_satisfied = bool(arriving_stair.get("satisfied", true))

		if dwelling and upper_hall >= 0:
			if not arrival_satisfied:
				# Keep the cloned room programme as-is. Naming bedrooms around a
				# landing that does not exist would promise an arrival the plan
				# explicitly failed to fit.
				continue
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
	# Scope: this domestic stair profile applies only to the built-in, exact
	# HouseSpec. ShopSpec, HotelSpec, InsulaSpec, KeepSpec, world-family adapters,
	# and custom HouseSpec subclasses retain their family contracts. Churches
	# and temples use separate planners. Their stair work needs family-specific
	# fixtures; sharing HousePlan alone does not make their circulation domestic.
	if _uses_domestic_stairs(p):
		_add_domestic_stair(p, lower_room, upper_room, lower_storey, upper_storey)
		return
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
	var found: Dictionary = _stair_spot(p, lower_room, floor_rect, size, upper_room)
	var other: Dictionary = _stair_spot(p, lower_room, floor_rect, size2, upper_room)
	if int(other["strict"]) < int(found["strict"]):
		found = other
		run = run2
		width = width2
	# a hall too narrow for the stair to keep out of the door's line either
	# way moves the DOOR instead: to the end of its wall away from the stair
	if int(found["strict"]) >= 2 and _slide_front_door(p, lower_room, found["rect"]):
		var again: Dictionary = _stair_spot(p, lower_room, floor_rect, size, upper_room)
		var again2: Dictionary = _stair_spot(p, lower_room, floor_rect, size2, upper_room)
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


static func _is_plain_house_spec(spec: HouseSpec) -> bool:
	if spec == null or spec.get_script() == null:
		return false
	return (spec.get_script() as Script).resource_path.ends_with("/src/house/house_spec.gd")


## A human-scale domestic stair requires the matching household room grammar.
## Family adapters, trades, legacy fallback partitions, and custom world
## families keep their existing path until they have their own circulation
## contract; a shared HousePlan type is not evidence that their plans are alike.
static func _uses_domestic_stairs(p: HousePlan) -> bool:
	if p == null or not _is_plain_house_spec(p.spec) \
			or p.spec.trade != &"none" or p.world_family != &"":
		return false
	var style: Dictionary = HouseSpec.STYLES.get(p.spec.style, {})
	return style.has("domestic_program") \
		and p.domestic_layout.get("status", &"") == &"planned"


## Place middle-storey hall doorways at the far ends of their true shared
## spans. This opens the centre of a compact three-storey hall for the second
## flight. The doorway remains on its existing wall and keeps its full swing.
static func _relocate_upper_hall_doors(p: HousePlan, hall: int, storey: int) -> void:
	if hall < 0 or hall >= p.room_count():
		return
	var moves: Dictionary = {}
	for di in range(p.doors.size()):
		var door: Dictionary = p.doors[di]
		if bool(door.get("exterior", false)) or HousePlan.record_storey(door) != storey:
			continue
		var a := int(door.get("a", -1))
		var b := int(door.get("b", -1))
		if a != hall and b != hall:
			continue
		var other_room := b if a == hall else a
		if other_room < 0 or other_room >= p.room_count():
			continue
		var edge := HousePlanOpenings.shared_edge(p, hall, other_room)
		if edge.is_empty():
			continue
		var normal: Vector2 = edge[0]
		var t0 := float(edge[2])
		var t1 := float(edge[3])
		var width := float(door.get("width", HouseGeometry.INNER_DOOR_W))
		var margin := HouseGeometry.DOOR_CORNER_MARGIN + width * 0.5
		if t1 - t0 < margin * 2.0:
			continue
		var hall_c: Vector2 = Rect2(p.rooms[hall]["rect"]).get_center()
		var other_c: Vector2 = Rect2(p.rooms[other_room]["rect"]).get_center()
		var hall_axis := hall_c.y if normal.x > 0.5 else hall_c.x
		var other_axis := other_c.y if normal.x > 0.5 else other_c.x
		var t := t0 + margin if other_axis < hall_axis else t1 - margin
		var line := float(edge[1])
		moves[di] = Vector2(line, t) if normal.x > 0.5 else Vector2(t, line)

	# Validate proposed positions together. Do not partially move a door set if
	# a doorway, window or opening on the same wall would be crowded.
	for di in moves:
		var door: Dictionary = p.doors[int(di)]
		var pos: Vector2 = moves[di]
		var normal: Vector2 = door["normal"]
		var relocated := door.duplicate()
		relocated["pos"] = pos
		for stair in p.stairs:
			if not bool(stair.get("satisfied", true)):
				continue
			var stair_storey := int(stair.get("storey", 0))
			var stair_to := int(stair.get("to_storey", stair_storey + 1))
			var stair_room := int(stair.get("b", -1)) if stair_to == storey \
				else int(stair.get("a", -1)) if stair_storey == storey else -1
			if stair_room != hall:
				continue
			var stair_rect := Rect2(stair.get("upper_rect", stair.get("rect", Rect2()))) \
				if stair_to == storey else Rect2(stair.get("lower_rect", stair.get("rect", Rect2())))
			var landing_key := "head_landing" if stair_to == storey else "foot_landing"
			var stair_landing := Rect2(stair.get(landing_key, Rect2()))
			for side in [-1.0, 1.0]:
				var swing := HouseGeometry.door_clear_rect(relocated, side)
				if swing.intersects(stair_rect) or swing.intersects(stair_landing):
					return
		for dj in range(p.doors.size()):
			if dj == int(di) or HousePlan.record_storey(p.doors[dj]) != storey:
				continue
			var other: Dictionary = p.doors[dj]
			var other_normal: Vector2 = other.get("normal", Vector2.ZERO)
			if absf(normal.cross(other_normal)) > 0.01:
				continue
			var other_pos: Vector2 = moves.get(dj, Vector2(other["pos"]))
			var same_line := absf(pos.x - other_pos.x) < 0.03 \
				if absf(normal.x) > 0.5 else absf(pos.y - other_pos.y) < 0.03
			if same_line and pos.distance_to(other_pos) \
					< (float(door["width"]) + float(other["width"])) * 0.5 + 0.1:
				return
		for window in p.windows:
			if HousePlan.record_storey(window) != storey:
				continue
			var window_normal: Vector2 = window.get("normal", Vector2.ZERO)
			if absf(normal.cross(window_normal)) > 0.01:
				continue
			var window_pos: Vector2 = window["pos"]
			var same_window_wall := absf(pos.x - window_pos.x) < 0.03 \
				if absf(normal.x) > 0.5 else absf(pos.y - window_pos.y) < 0.03
			if same_window_wall and pos.distance_to(window_pos) \
					< (float(door["width"]) + float(window["width"])) * 0.5 \
					+ HouseGeometry.WINDOW_MIN_GAP:
				return
	for di in moves:
		p.doors[int(di)]["pos"] = Vector2(moves[di])


## Fit a human-scale domestic flight and both end landings before recording it.
## If the hall cannot carry that footprint, keep an explicit unsatisfied row;
## the emitter will not turn it into a shorter, steeper staircase.
static func _add_domestic_stair(p: HousePlan, lower_room: int, upper_room: int,
		lower_storey: int, upper_storey: int) -> void:
	var height := float(p.spec.height)
	var run := height / tan(deg_to_rad(HouseGeometry.STAIR_PITCH_MAX)) + 0.02
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(p, lower_room)
	var short_side := minf(floor_rect.size.x, floor_rect.size.y)
	var width := minf(HouseGeometry.STAIR_WIDTH_TARGET,
		short_side - HouseGeometry.PATH_MIN)
	var landing_depth := maxf(HouseGeometry.STAIR_LANDING, width)
	var failure := "no room for a %.2fm flight, %.2fm end landings and %.2fm clear width" \
		% [run, landing_depth, HouseGeometry.STAIR_WIDTH_MIN]
	if width < HouseGeometry.STAIR_WIDTH_MIN - 0.001:
		_record_unsatisfied_stair(p, lower_room, upper_room, lower_storey,
			upper_storey, run, failure)
		return
	var options: Array[Vector2] = [Vector2(run, width), Vector2(width, run)]
	var candidates := _domestic_stair_candidates(p, lower_room, floor_rect,
		options, upper_room, landing_depth)
	var found: Dictionary = candidates[0] if not candidates.is_empty() \
		else {"rect": Rect2(), "strict": 5}
	if int(found.get("strict", 5)) >= 2 and Rect2(found.get("rect", Rect2())).has_area() \
			and _slide_front_door(p, lower_room, Rect2(found["rect"])):
		candidates = _domestic_stair_candidates(p, lower_room, floor_rect,
			options, upper_room, landing_depth)
		found = candidates[0] if not candidates.is_empty() \
			else {"rect": Rect2(), "strict": 5}
	if not Rect2(found.get("rect", Rect2())).has_area():
		_record_unsatisfied_stair(p, lower_room, upper_room, lower_storey,
		upper_storey, run, failure)
		return
	if int(found.get("strict", 5)) >= 2:
		_record_unsatisfied_stair(p, lower_room, upper_room, lower_storey,
			upper_storey, run, _stair_failure_reason(int(found.get("strict", 5))))
		return
	var steps := HouseGeometry.stair_step_count(height, run)
	if steps <= 0:
		_record_unsatisfied_stair(p, lower_room, upper_room, lower_storey,
			upper_storey, run, "no whole-riser count meets rise, going and stride limits")
		return
	var access_room := lower_room
	var access_storey := lower_storey
	var access_is_foot := lower_storey >= 0
	if lower_storey < 0:
		# The cellar stair is entered from its upper landing; keep that route
		# clear on the ground floor rather than reserving an unreachable cellar
		# path from the front door.
		access_room = upper_room
		access_storey = upper_storey
	var selected: Dictionary = {}
	var access_route: Array[Rect2] = []
	for candidate in candidates:
		if int(candidate.get("strict", 5)) >= 2:
			continue
		var candidate_rect := Rect2(candidate["rect"])
		var access_landing := Rect2(candidate["foot_landing"] if access_is_foot \
			else candidate["head_landing"])
		var route := _domestic_stair_access_zones(p, access_room,
			access_storey, candidate_rect, access_landing)
		if not route.is_empty():
			selected = candidate
			access_route = route
			break
	if access_route.is_empty():
		_record_unsatisfied_stair(p, lower_room, upper_room, lower_storey,
			upper_storey, run, "no contiguous %.1f m route from the entry to the stair landing" \
			% HouseGeometry.STAIR_WIDTH_CLEAR_MIN)
		return
	found = selected
	var footprint: Rect2 = found["rect"]
	var centre := footprint.get_center()
	var foot: Rect2 = found["foot_landing"]
	var head: Rect2 = found["head_landing"]
	var stair := {
		"a": lower_room, "b": upper_room,
		"storey": lower_storey, "to_storey": upper_storey,
		"pos": centre, "lower_pos": centre, "upper_pos": centre,
		"rect": footprint, "lower_rect": footprint, "upper_rect": footprint,
		"width": minf(footprint.size.x, footprint.size.y), "run": run,
		"steps": steps, "climb": float(found["climb"]),
		"foot_landing": foot, "head_landing": head,
		"satisfied": true, "domestic_profile": true,
	}
	p.stairs.append(stair)
	p.zones.append({"room": lower_room, "rect": foot, "why": "stair foot landing"})
	p.zones.append({"room": upper_room, "rect": head, "why": "stair head landing"})
	for corridor in access_route:
		p.zones.append({"room": access_room, "rect": corridor,
			"why": "stair access route"})


## Keep route searches bounded: gather the best few legal placements from each
## orientation, then test access only for those placements.
static func _domestic_stair_candidates(p: HousePlan, lower_room: int,
		floor_rect: Rect2, options: Array[Vector2], upper_room: int,
		landing_depth: float) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for size in options:
		var result := _stair_spot(p, lower_room, floor_rect, size, upper_room,
			landing_depth)
		var rows: Array = result.get("alternatives", [])
		for row in rows:
			found.append(row)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_acceptable := int(a.get("strict", 5)) < 2
		var b_acceptable := int(b.get("strict", 5)) < 2
		if a_acceptable != b_acceptable:
			return a_acceptable
		var a_wall := float(a.get("wall_distance", INF))
		var b_wall := float(b.get("wall_distance", INF))
		if absf(a_wall - b_wall) > 0.01:
			return a_wall < b_wall
		if int(a.get("strict", 5)) != int(b.get("strict", 5)):
			return int(a.get("strict", 5)) < int(b.get("strict", 5))
		return float(a.get("score", -INF)) > float(b.get("score", -INF)))
	var bounded: Array[Dictionary] = []
	for row in found:
		var duplicate := false
		for prior in bounded:
			if Rect2(prior["rect"]).get_center().distance_to(
					Rect2(row["rect"]).get_center()) < 0.8:
				duplicate = true
				break
		if not duplicate:
			bounded.append(row)
		if bounded.size() >= 8:
			break
	return bounded


static func _record_unsatisfied_stair(p: HousePlan, lower_room: int,
		upper_room: int, lower_storey: int, upper_storey: int, required_run: float,
		reason: String) -> void:
	var empty := Rect2()
	p.stairs.append({
		"a": lower_room, "b": upper_room,
		"storey": lower_storey, "to_storey": upper_storey,
		"pos": Vector2.ZERO, "lower_pos": Vector2.ZERO, "upper_pos": Vector2.ZERO,
		"rect": empty, "lower_rect": empty, "upper_rect": empty,
		"width": 0.0, "run": 0.0, "steps": 0,
		"satisfied": false, "domestic_profile": true,
		"required_run": required_run, "reason": reason,
	})
	p.domestic_layout["stair_unsatisfied"] = true
	var notes: Array[String] = []
	for note in p.domestic_layout.get("stair_reasons", []):
		notes.append(String(note))
	notes.append("storey %d to %d: %s" % [lower_storey, upper_storey, reason])
	p.domestic_layout["stair_reasons"] = notes
	if lower_room >= 0 and lower_room < p.room_count():
		p.note_compromise(lower_room, "stair")


static func _stair_failure_reason(strict: int) -> String:
	if strict == 2:
		return "all fitting flights cross the front-door line after door relocation"
	if strict >= 3:
		return "all fitting flights cross the front-door line or a door swing after relocation"
	return "no flight candidate satisfies the domestic placement rules"


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


## Where the stair goes: legacy stairs use the two wall lanes; domestic flights
## also sample interior lanes when both wall lanes conflict with circulation.
## Candidates are clear of door swings, the front-door line and windows when
## possible, and are scored away from the entrance. Returns {"rect": Rect2,
## "strict": int}, the strictness level the spot was found at (0 = every rule
## held).
static func _stair_spot(p: HousePlan, room: int, f: Rect2, size: Vector2,
		upper_room := -1, landing_depth := 0.0) -> Dictionary:
	if landing_depth > 0.0 and (f.size.x < size.x - 0.001 or f.size.y < size.y - 0.001):
		return {"rect": Rect2(), "strict": 5}
	# The flight has a landing on BOTH storeys and a stair's rectangle serves
	# both, so it must stand on the floor of each and inside the interior the
	# plan checks it against. An upper storey's room can be wider than the
	# interior (a jetty, a banded storey): a well set against its back wall
	# is then outside it, however well it fits the room below.
	var bound: Rect2 = HouseGeometry.interior_rect(p.spec)
	if landing_depth > 0.0 and upper_room >= 0:
		# Two projecting upper storeys share their own supported floor envelope.
		# The ground footprint must not push their flight away from its wall.
		bound = HouseGeometry.interior_rect(p.spec, p.storey_of_room(room)).intersection(
			HouseGeometry.interior_rect(p.spec, p.storey_of_room(upper_room)))
	if upper_room >= 0:
		bound = bound.intersection(HouseGeometry.room_floor_rect(p, upper_room))
	var fit: Rect2 = bound.intersection(f)
	if bound.has_area() and fit.size.x >= size.x and fit.size.y >= size.y:
		f = fit
	else:
		bound = Rect2()
	var along_x: bool = size.x >= size.y
	var swings: Array[Rect2] = []
	var lines: Array[Rect2] = []
	var glass: Array[Rect2] = []
	var upper_door_aprons: Array[Rect2] = []
	var lower_floor_poly := PackedVector2Array()
	var upper_floor_poly := PackedVector2Array()
	if landing_depth > 0.0:
		lower_floor_poly = HouseGeometry.room_floor_poly(p, room)
		if upper_room >= 0:
			upper_floor_poly = HouseGeometry.room_floor_poly(p, upper_room)
	# Door/window clear rectangles reserve standing room for people and
	# furniture; they are not walls. A landing is also clear floor and may
	# serve the same approach. Keep the flight out of the front-door line and
	# real door-swing checks below; test the complete route after choosing it.
	if landing_depth > 0.0 and upper_room >= 0:
		var upper_storey := p.storey_of_room(upper_room)
		for d in p.doors_of(upper_room):
			var door: Dictionary = p.doors[d]
			if HousePlan.record_storey(door) != upper_storey:
				continue
			for side in [-1.0, 1.0]:
				# The approach rectangle already spans the walker's body path.
				# Add only the ~4 cm overhang of the guard post around the well.
				upper_door_aprons.append(
					HouseGeometry.door_clear_rect(door, side).grow(0.04))
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
	var reserved_access_routes: Array[Rect2] = []
	for zone in p.zones:
		if int(zone.get("room", -1)) == room \
				and String(zone.get("why", "")) == "stair access route":
			reserved_access_routes.append(Rect2(zone.get("rect", Rect2())))
	var lanes: Array[Rect2] = []
	if landing_depth <= 0.0:
		# Preserve the exact legacy two-wall-lane search for explicit family
		# adapters and custom stair contracts.
		if along_x:
			lanes.append(Rect2(Vector2(f.position.x, f.position.y), size))
			lanes.append(Rect2(Vector2(f.position.x, f.end.y - size.y), size))
		else:
			lanes.append(Rect2(Vector2(f.position.x, f.position.y), size))
			lanes.append(Rect2(Vector2(f.end.x - size.x, f.position.y), size))
	else:
		# Walk parallel runs across the whole usable floor, in bounded 0.25 m
		# offsets. Wall lanes are included and remain preferred, but a long flight
		# must be allowed to step off a wall lane when every wall placement crosses
		# the front-door line. The old two-lane search marked ordinary large halls
		# impossible even when their middle had a clean route.
		var cross_travel: float = (f.size.y - size.y) if along_x else (f.size.x - size.x)
		var lane_count: int = maxi(1, ceili(cross_travel / 0.25))
		for lane_index in range(lane_count + 1):
			var cross_offset := minf(float(lane_index) * 0.25, cross_travel)
			var lane := Rect2(Vector2(f.position.x, f.position.y + cross_offset), size) \
				if along_x else Rect2(Vector2(f.position.x + cross_offset, f.position.y), size)
			if lanes.is_empty() or not lanes.back().position.is_equal_approx(lane.position):
				lanes.append(lane)
	var travel: float = (f.size.x - size.x) if along_x else (f.size.y - size.y)
	var steps: int = maxi(int(travel / 0.1), 1)
	var viable: Array[Dictionary] = []
	# For a domestic flight, the front-door line and door approaches remain hard
	# limits. Examine both window-clearance tiers so a wall-side fit is not
	# discarded just because it shares open floor with the light apron. Tiers 2
	# and 3 are gathered only if no acceptable placement exists; the caller may
	# use them to relocate the front door, never to accept a compromised stair.
	for strict in range(4):
		var best := Rect2()
		var best_score := -INF
		var best_wall_distance := INF
		for base in lanes:
			for s in range(steps + 1):
				var t: float = travel * float(s) / float(steps)
				var rect := Rect2(base.position + (Vector2(t, 0.0) if along_x
					else Vector2(0.0, t)), size)
				# never at any strictness: see arriving_wells
				if hits_any(rect, wells):
					continue
				# Landings may share door approaches. The rising well may not: it
				# occupies vertical space across the upper door's body path.
				if landing_depth > 0.0 and hits_any(rect, upper_door_aprons):
					continue
				# A later flight must not cut through the clear path already
				# promised by an earlier stair. Landings may share that path.
				if landing_depth > 0.0 and hits_any(rect, reserved_access_routes):
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
				if bound.has_area() and not bound.grow(0.01).encloses(rect):
					continue
				var landing_choice: Dictionary = {}
				if landing_depth > 0.0:
					landing_choice = _domestic_landing_choice(p, room, upper_room,
						rect, landing_depth, wells, lower_floor_poly, upper_floor_poly)
					if landing_choice.is_empty():
						continue
				var score: float = rect.get_center().distance_to(front)
				var wall_distance := minf(rect.position.y - f.position.y,
					f.end.y - rect.end.y) if along_x else minf(
					rect.position.x - f.position.x, f.end.x - rect.end.x)
				# Wall position is the primary architecture criterion. The approach
				# distance breaks ties between legal wall-side candidates.
				# Preserve one contiguous path beside the flight. The total free
				# width can be misleading for an interior lane: two 0.5 m gaps do
				# not make a 1 m passage.
				var clear_a := rect.position.y - f.position.y if along_x else rect.position.x - f.position.x
				var clear_b := f.end.y - rect.end.y if along_x else f.end.x - rect.end.x
				var beside := f.size.y - size.y if along_x else f.size.x - size.x
				if landing_depth > 0.0 and wells.is_empty() \
						and maxf(clear_a, clear_b) \
						< HouseGeometry.STAIR_WIDTH_CLEAR_MIN - 0.01:
					continue
				if beside < HouseGeometry.PATH_MIN:
					score -= 100.0
				if wall_distance < best_wall_distance - 0.01 \
						or (absf(wall_distance - best_wall_distance) <= 0.01 \
						and score > best_score):
					best_wall_distance = wall_distance
					best_score = score
					best = rect
				if landing_depth > 0.0:
					viable.append({"rect": rect, "strict": strict, "score": score,
						"wall_distance": maxf(wall_distance, 0.0),
						"climb": float(landing_choice["climb"]),
						"foot_landing": Rect2(landing_choice["foot_landing"]),
						"head_landing": Rect2(landing_choice["head_landing"])})
		if best.size.x > 0.0:
			if landing_depth > 0.0:
				if strict >= 1 and not viable.is_empty():
					break
				continue
			return {"rect": best, "strict": strict}
	if landing_depth > 0.0:
		viable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var a_wall := float(a.get("wall_distance", INF))
			var b_wall := float(b.get("wall_distance", INF))
			if absf(a_wall - b_wall) > 0.01:
				return a_wall < b_wall
			if int(a.get("strict", 5)) != int(b.get("strict", 5)):
				return int(a["strict"]) < int(b["strict"])
			return float(a["score"]) > float(b["score"]))
		var alternatives: Array[Dictionary] = []
		for row in viable:
			if alternatives.size() >= 4:
				break
			var duplicate := false
			for prior in alternatives:
				if Rect2(prior["rect"]).get_center().distance_to(
						Rect2(row["rect"]).get_center()) < 0.8:
					duplicate = true
					break
			if not duplicate:
				alternatives.append(row)
		if not alternatives.is_empty():
			return {"rect": Rect2(alternatives[0]["rect"]),
				"strict": int(alternatives[0]["strict"]), "alternatives": alternatives}
		return {"rect": Rect2(), "strict": 5}
	return {"rect": Rect2(f.get_center() - size / 2.0, size), "strict": 4}


static func _domestic_landing_choice(p: HousePlan, lower_room: int,
		upper_room: int, flight: Rect2, depth: float, wells: Array[Rect2],
		lower_floor_poly: PackedVector2Array, upper_floor_poly: PackedVector2Array) -> Dictionary:
	for climb in [1.0, -1.0]:
		var foot := HouseGeometry.stair_approach(flight, climb, depth)
		var head := HouseGeometry.stair_approach(flight, -climb, depth)
		if not _poly_contains_rect(lower_floor_poly, foot) \
				or not _poly_contains_rect(upper_floor_poly, head):
			continue
		# A landing is an access surface. Door approaches and window-light
		# reservations may overlap that surface; only a stairwell/solid or an
		# unrelated reserved zone makes it unusable. The flight itself remains
		# subject to door-apron and front-door-line rules in _stair_spot().
		if hits_any(foot, wells) or hits_any(head, wells):
			continue
		var already_reserved := false
		for zone in p.zones:
			var why := String(zone.get("why", ""))
			if why == "stair foot landing" or why == "stair head landing" \
					or why == "stair access route":
				continue
			if int(zone.get("room", -1)) == lower_room \
					and Rect2(zone.get("rect", Rect2())).intersects(foot):
				already_reserved = true
			if int(zone.get("room", -1)) == upper_room \
					and Rect2(zone.get("rect", Rect2())).intersects(head):
				already_reserved = true
		if already_reserved:
			continue
		return {"climb": climb, "foot_landing": foot, "head_landing": head}
	return {}


## Trace a real body-width route before the furnisher runs. The resulting
## overlapping rectangles are clear-floor zones, so furniture can still fill
## the room while one continuous path remains from the entry to the flight.
static func _domestic_stair_access_zones(p: HousePlan, room: int, storey: int,
		flight: Rect2, landing: Rect2) -> Array[Rect2]:
	var empty: Array[Rect2] = []
	if room < 0 or room >= p.room_count() or not landing.has_area():
		return empty
	var start := Vector2.ZERO
	if storey == 0:
		var door_index: int = p.entrance()
		if door_index < 0 or HousePlan.record_storey(p.doors[door_index]) != storey:
			return empty
		var door: Dictionary = p.doors[door_index]
		start = Vector2(door["pos"]) - Vector2(door["normal"]) \
			* (HouseGeometry.wall_thickness(p.spec) * 0.5 + 0.2)
	else:
		var prior_landing_found := false
		for stair in p.stairs:
			if bool(stair.get("satisfied", true)) \
					and int(stair.get("to_storey", -1)) == storey:
				var prior_head := Rect2(stair.get("head_landing", Rect2()))
				if prior_head.has_area():
					start = prior_head.get_center()
					prior_landing_found = true
					break
		if not prior_landing_found:
			return empty

	var grid := WalkGrid.new()
	grid.setup(HouseGeometry.storey_rect(p, storey), HouseGeometry.NAV_CELL)
	if p.is_polygonal(room):
		grid.add_floor_poly(HouseGeometry.room_floor_poly(p, room))
	else:
		grid.add_floor(HouseGeometry.room_floor_rect(p, room))
	# This is a planning-time route. No furniture is expected yet, but keeping
	# the obstacle path complete makes the helper safe for later replanning.
	for piece in p.furniture:
		if HousePlan.record_storey(piece) != storey or int(piece.get("room", -1)) != room \
				or bool(piece.get("mounted", false)) or int(piece.get("host", -1)) >= 0:
			continue
		var key := String(piece.get("key", ""))
		if PropCatalog.blocks_floor(key):
			grid.add_obstacle(Rect2(piece.get("rect", Rect2())))
	for column in p.columns:
		if int(column.get("storey", 0)) != storey:
			continue
		var column_pos: Vector2 = column.get("pos", Vector2.ZERO)
		var column_size: Vector2 = column.get("size", Vector2.ZERO)
		if column_size.x > 0.0 and column_size.y > 0.0:
			grid.add_obstacle(Rect2(column_pos - column_size * 0.5, column_size))
	var breast := HouseGeometry.hearth_breast(p)
	if not breast.is_empty() and int(breast.get("room", -1)) == room:
		grid.add_obstacle_poly(breast["outline"])
	for stair in p.stairs:
		if not bool(stair.get("satisfied", true)):
			continue
		var lo := int(stair.get("storey", 0))
		var hi := int(stair.get("to_storey", lo + 1))
		var raw := Rect2()
		if lo == storey:
			raw = Rect2(stair.get("lower_rect", stair.get("rect", Rect2())))
		elif hi == storey:
			raw = Rect2(stair.get("upper_rect", stair.get("rect", Rect2())))
		if raw.has_area():
			grid.add_obstacle(raw)
	grid.add_obstacle(flight)
	grid.build(HouseGeometry.STAIR_WIDTH_CLEAR_MIN * 0.5)
	if not grid.flood_from(start):
		return empty

	var target := Vector2i(-1, -1)
	var target_steps := 1 << 30
	var min_cell := grid.cell_of(landing.position)
	var max_cell := grid.cell_of(landing.end)
	for x in range(maxi(0, min_cell.x), mini(grid.nx - 1, max_cell.x) + 1):
		for z in range(maxi(0, min_cell.y), mini(grid.nz - 1, max_cell.y) + 1):
			var index := x * grid.nz + z
			var steps: int = grid._walk_steps[index]
			if steps >= 0 and steps < target_steps:
				target = Vector2i(x, z)
				target_steps = steps
	if target.x < 0:
		return empty

	var reverse_path: Array[Vector2i] = [target]
	var cursor := target
	var backtrack_limit := grid.nx * grid.nz
	while backtrack_limit > 0:
		backtrack_limit -= 1
		var current_index := cursor.x * grid.nz + cursor.y
		var current_steps: int = grid._walk_steps[current_index]
		if current_steps <= 0:
			break
		var previous := Vector2i(-1, -1)
		for direction: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0),
				Vector2i(0, -1), Vector2i(0, 1)]:
			var candidate: Vector2i = cursor + direction
			if grid.at(grid._walk, candidate.x, candidate.y) != 1:
				continue
			var candidate_steps: int = grid._walk_steps[candidate.x * grid.nz + candidate.y] \
				if candidate.x >= 0 and candidate.x < grid.nx \
				and candidate.y >= 0 and candidate.y < grid.nz else -1
			if candidate_steps == current_steps - 1:
				previous = candidate
				break
		if previous.x < 0:
			return empty
		cursor = previous
		reverse_path.append(cursor)
	if backtrack_limit <= 0 or int(grid._walk_steps[cursor.x * grid.nz + cursor.y]) != 0:
		return empty
	reverse_path.reverse()
	return _compress_walk_path(grid, reverse_path)


static func _compress_walk_path(grid: WalkGrid, cells: Array[Vector2i]) -> Array[Rect2]:
	var zones: Array[Rect2] = []
	if cells.is_empty():
		return zones
	if cells.size() == 1:
		var point := grid.world_of(cells[0].x, cells[0].y)
		var half := HouseGeometry.STAIR_WIDTH_CLEAR_MIN * 0.5
		zones.append(Rect2(point - Vector2(half, half), Vector2(half * 2.0, half * 2.0)))
		return zones
	var first := 0
	var direction: Vector2i = cells[1] - cells[0]
	for i in range(2, cells.size()):
		var next_direction: Vector2i = cells[i] - cells[i - 1]
		if next_direction != direction:
			zones.append(_walk_run_rect(grid, cells[first], cells[i - 1]))
			first = i - 1
			direction = next_direction
	zones.append(_walk_run_rect(grid, cells[first], cells[-1]))
	return zones


static func _walk_run_rect(grid: WalkGrid, from: Vector2i, to: Vector2i) -> Rect2:
	var a: Vector2 = grid.world_of(from.x, from.y)
	var b: Vector2 = grid.world_of(to.x, to.y)
	var half := HouseGeometry.STAIR_WIDTH_CLEAR_MIN * 0.5
	return Rect2(a.min(b), (b - a).abs()).grow(half)


static func _poly_contains_rect(poly: PackedVector2Array, rect: Rect2) -> bool:
	if poly.size() < 3 or not rect.has_area():
		return false
	for point in Poly.from_rect(rect):
		if not Poly.contains_point(poly, point, 0.01):
			return false
	return true


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
